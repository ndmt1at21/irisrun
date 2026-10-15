#!/bin/sh
# Fetches libobjc2 and builds it with the Swift toolchain's clang against the
# toolchain's libBlocksRuntime, then builds and runs the demo: demo.m, which
# also runs the Swift checks in Interop.swift.
# usage: [JOBS=n] native/objc/build.sh [build-dir]   (default: ~/.cache/irisrun/objc, outside the repo)
set -eu

LIBOBJC2_TAG=v2.3
LIBOBJC2_COMMIT=e877e782fb965c4e870d2ecf6aff58dddc6290ae

here=$(cd "$(dirname "$0")" && pwd)
out=${1:-${XDG_CACHE_HOME:-$HOME/.cache}/irisrun/objc}
swiftc=$(command -v swiftc) || { echo "swiftc not found: install a Swift toolchain from swift.org" >&2; exit 1; }
toolchain=$(dirname "$(dirname "$swiftc")")
swift_lib=$toolchain/lib/swift
swift_version=$("$swiftc" --version 2>&1 | sed -n 's/^Swift version \([0-9.]*\) .*/\1/p')
mkdir -p "$out"
# Keeps tool output in $out/log; shows it only on failure.
quiet() { "$@" >"$out/log" 2>&1 || { cat "$out/log" >&2; exit 1; }; }

if [ ! -d "$out/libobjc2" ]; then
  git clone -q -c advice.detachedHead=false --depth 1 -b "$LIBOBJC2_TAG" \
    https://github.com/gnustep/libobjc2.git "$out/libobjc2"
fi
[ "$(git -C "$out/libobjc2" rev-parse HEAD)" = "$LIBOBJC2_COMMIT" ] || { echo "libobjc2 is not at $LIBOBJC2_COMMIT" >&2; exit 1; }

# libobjc2 needs libdispatch's Block_private.h, which the toolchain does not ship,
# to hook into the toolchain's libBlocksRuntime. Using that runtime keeps one
# blocks runtime in a process that also loads libdispatch.
dispatch=$out/libdispatch
if [ ! -d "$dispatch" ]; then
  git clone -q -c advice.detachedHead=false --depth 1 --filter=blob:none --sparse \
    -b "swift-$swift_version-RELEASE" https://github.com/swiftlang/swift-corelibs-libdispatch.git "$dispatch"
  git -C "$dispatch" sparse-checkout set src/BlocksRuntime
fi

generator="Unix Makefiles"
command -v ninja >/dev/null && generator=Ninja
inc="-I$dispatch/src/BlocksRuntime"
quiet cmake -S "$out/libobjc2" -B "$out/build" -G "$generator" -DCMAKE_BUILD_TYPE=Release -DTESTS=OFF \
  -DCMAKE_C_COMPILER="$toolchain/bin/clang" -DCMAKE_CXX_COMPILER="$toolchain/bin/clang++" \
  -DEMBEDDED_BLOCKS_RUNTIME=OFF -DCMAKE_LIBRARY_PATH="$swift_lib/linux" \
  -DCMAKE_REQUIRED_INCLUDES="$dispatch/src/BlocksRuntime" \
  -DCMAKE_C_FLAGS="$inc" -DCMAKE_CXX_FLAGS="$inc" -DCMAKE_OBJC_FLAGS="$inc" -DCMAKE_OBJCXX_FLAGS="$inc" \
  -DCMAKE_INSTALL_PREFIX="$out/prefix" -DCMAKE_INSTALL_RPATH="$swift_lib/linux"
quiet cmake --build "$out/build" -j "${JOBS:-$(nproc)}"
quiet cmake --install "$out/build"

cc() {
  "$toolchain/bin/clang" -fobjc-runtime=gnustep-2.0 -fblocks -fobjc-exceptions -O1 -Wall \
    -I"$out/prefix/include" -I"$swift_lib" "$@"
}
cc -c "$here/MiniFoundation.m" -o "$out/MiniFoundation.o"
cc -fobjc-arc -c "$here/demo.m" -o "$out/demo.o"
# swiftc links, so the Swift runtime comes along; the module map lets
# Interop.swift import libobjc2's headers as ObjCRuntime.
cp "$here/module.modulemap" "$out/prefix/include/"
"$swiftc" -parse-as-library -O -I "$out/prefix/include" "$here/Interop.swift" "$out/demo.o" "$out/MiniFoundation.o" \
  -o "$out/demo" -L"$out/prefix/lib" -ldispatch -Xlinker -rpath -Xlinker "$out/prefix/lib"
"$out/demo"
