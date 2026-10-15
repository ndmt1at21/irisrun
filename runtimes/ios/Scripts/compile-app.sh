#!/usr/bin/env bash
# Compiles one iOS app, unchanged, against OpenKit (the patched OpenSwiftUI checkout).
# irisrun-ios-build reads the app's Xcode project, picks its iOS app target and writes a SwiftPM
# package to $IRISRUN_IOS_WORK/apps/<name>: the target's Swift files without previews, its Swift
# packages and resources, with SwiftUI aliased to OpenSwiftUI and Observation to OpenObservation.
# A directory with no Xcode project counts as one target of all its Swift files but tests. This
# script then builds the package. On success it prints the path of the executable, linked into a
# directory with the app's resources, or the module's name when the app has no entry point; what
# the tool found goes to stderr.
#
#   Scripts/compile-app.sh <app-dir> [swift build options...]
#
# Needs Swift 6.4.1 and Scripts/fetch-openswiftui.sh, and to link an app, the render core that
# OpenSwiftUI draws with: `cargo build -p irisrun-render --release` in the repo. All apps share
# one build directory per configuration, so OpenSwiftUI is compiled once. This is the compile
# step that tools/ios-corpus calls per app.
set -euo pipefail

ios="$(cd "$(dirname "$0")/.." && pwd)"
source "$ios/Scripts/env.sh"
app="$(cd "$1" && pwd)"
shift
name="$(basename "$app" | tr -c 'A-Za-z0-9_\n' '_')"
[[ "$name" =~ ^[A-Za-z_] ]] || name="App_$name"
pkg="$IRISRUN_IOS_WORK/apps/$name"
render_lib="${CARGO_TARGET_DIR:-$ios/../../target}/release"

tool="$IRISRUN_IOS_WORK/build/tool"
swift build --package-path "$ios" --scratch-path "$tool" --product irisrun-ios-build -q >&2
summary="$("$tool/debug/irisrun-ios-build" "$app" --out "$pkg" \
    --openswiftui "$IRISRUN_IOS_WORK/checkouts/OpenSwiftUI" --render-lib "$render_lib")"
echo "$summary" >&2
module="$(sed -n 's/^ *"module" : "\(.*\)",$/\1/p' <<< "$summary")"
if grep -q '"executable" : true' <<< "$summary" && [ ! -f "$render_lib/libirisrun_render.a" ]; then
    echo "error: no $render_lib/libirisrun_render.a; run: cargo build -p irisrun-render --release" >&2
    exit 1
fi

# Switching between debug and release in one build directory rebuilds the macro tools and then
# everything that uses them, so each configuration gets its own directory.
config=debug
case " $* " in *" release "* | *"=release "*) config=release ;; esac
build=(swift build --package-path "$pkg" --scratch-path "$IRISRUN_IOS_WORK/build/apps-$config" -j 6 "$@")
"${build[@]}" >&2
if grep -q '"executable" : true' <<< "$summary"; then
    # The app runs from a directory of its own, with its resources next to the executable,
    # where Bundle.main finds them: asset catalogs, .lproj folders and the rest.
    run="$pkg/run"
    rm -rf "$run"
    mkdir -p "$run"
    cp -R "$pkg/Resources/." "$run/"
    ln -f "$("${build[@]}" --show-bin-path)/$module" "$run/$module"
    echo "$run/$module"
else
    echo "$module"
fi
