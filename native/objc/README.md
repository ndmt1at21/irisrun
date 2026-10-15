# Objective-C on Linux (P0-07 demo)

Plain Objective-C compiled with the Swift toolchain's clang and run on
[libobjc2](https://github.com/gnustep/libobjc2) 2.3 (MIT), without GNUstep Base or any other
Foundation. In the same process, Swift code built by the stock toolchain (ObjC interop off)
calls those classes and is called back by them through libobjc2's C API. Findings, numbers and
the go/no-go are in [docs/reports/p0-07-objc-linux.md](../../docs/reports/p0-07-objc-linux.md).

| File | What |
| --- | --- |
| `build.sh` | Fetches libobjc2 v2.3 (pinned commit) and libdispatch's `Block_private.h`, builds libobjc2 against the toolchain's `libBlocksRuntime`, then builds and runs the demo |
| `MiniFoundation.h`, `MiniFoundation.m` | The least a Foundation has to provide on libobjc2: a root `NSObject`, the classes clang emits for `@"..."` literals, blocks as objects, and the forwarding hook that calls `+resolveInstanceMethod:` |
| `demo.m` | Classes, properties, categories, protocols, blocks, ARC with weak references, `@autoreleasepool`, exceptions, target/action through selectors, method resolution, associated objects, swizzling, KVO-style isa swizzling, GCD with `@synchronized`; then calls `Interop.swift` |
| `Interop.swift` | Swift sends ObjC messages, installs a closure as an ObjC method that ObjC target/action calls, and passes a closure as an ObjC block |
| `module.modulemap` | Makes libobjc2's headers importable from Swift as `ObjCRuntime`; `build.sh` installs it next to them |

## Run

Needs a Swift 6.x toolchain from swift.org on Linux (its clang, `libBlocksRuntime` and
`libdispatch` are used), CMake 3.16+, Ninja or Make, git, and network access (libobjc2's CMake
also fetches robin-map).

```sh
native/objc/build.sh            # build directory: ~/.cache/irisrun/objc
JOBS=6 native/objc/build.sh /path/outside/the/repo
```

It prints `all checks passed` and exits 0. A clean run took 22–46 s here, mostly downloading
about 4 MB; a re-run takes under 10 s. Tool output goes to `<build directory>/log` and is shown
only on failure.

Swift 6.4.1 has no build for Ubuntu 20.04: there, run the script inside an Ubuntu 24.04
container or rootfs that has the toolchain.
