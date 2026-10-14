# Objective-C on Linux (P0-07 demo)

Plain Objective-C compiled with the Swift toolchain's clang and run on
[libobjc2](https://github.com/gnustep/libobjc2) 2.3 (MIT), without GNUstep Base or any other
Foundation. Findings, numbers and the go/no-go are in
[docs/reports/p0-07-objc-linux.md](../../docs/reports/p0-07-objc-linux.md).

| File | What |
| --- | --- |
| `build.sh` | Fetches libobjc2 v2.3 (pinned commit) and libdispatch's `Block_private.h`, builds libobjc2 against the toolchain's `libBlocksRuntime`, then builds and runs the demo |
| `MiniFoundation.h`, `MiniFoundation.m` | The least a Foundation has to provide on libobjc2: a root `NSObject`, the classes clang emits for `@"..."` literals, blocks as objects, and the forwarding hook that calls `+resolveInstanceMethod:` |
| `demo.m` | Classes, properties, categories, protocols, blocks, ARC with weak references, `@autoreleasepool`, exceptions, target/action through selectors, method resolution, associated objects, swizzling, GCD |

## Run

Needs a Swift 6.x toolchain from swift.org on Linux (its clang, `libBlocksRuntime` and
`libdispatch` are used), CMake 3.16+, Ninja or Make, and git.

```sh
native/objc/build.sh /tmp/objc    # build directory, outside the repo; default ~/.cache/irisrun/objc
```

It prints `all checks passed` and exits 0; a clean run takes about 40 s. Tool output goes to
`<build directory>/log` and is shown only on failure.

Swift 6.4.1 has no build for Ubuntu 20.04: there, run the script inside an Ubuntu 24.04
container or rootfs that has the toolchain.
