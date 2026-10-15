# Iris

Iris (`irisrun`) runs Android and iOS apps straight from source, with no phone,
Android Studio or Xcode: one command, like `npm start`. The plan and roadmap
live in [docs/plan-and-stack.md](docs/plan-and-stack.md) and
[docs/tasks.md](docs/tasks.md).

## Layout

| Path | What | Language |
| --- | --- | --- |
| `proto/` | Device Protocol, shared by every component | Protobuf (buf) |
| `crates/` | CLI, local engine and shared libraries | Rust |
| `apps/web/` | Device UI and Console | TypeScript, React |
| `runtimes/android/` | Android runtime on Robolectric | Kotlin |
| `runtimes/ios/` | iOS runtime (OpenKit) | Swift |
| `examples/` | Sample apps, also the compatibility suite | Kotlin, Swift |
| `cloud/` | Images for the cloud tier, such as the Android emulator | Docker |

## Development

You need Rust (rustup), Node.js 22+ with pnpm (`corepack enable`), JDK 21 and
Swift 6.4.1. On Linux the render core also needs `libfontconfig1-dev` and
`libfreetype-dev`, and its tests need the fonts from
`crates/render/fetch-fonts.sh`. Each part builds on its own:

```sh
pnpm install
pnpm proto:lint             # buf lint + format check
pnpm proto:generate         # regenerate bindings after editing proto/, then commit them

cargo test --workspace      # Rust
pnpm lint && pnpm typecheck && pnpm test   # TypeScript
(cd runtimes/android && ./gradlew build)   # Kotlin
(cd runtimes/ios && swift test)            # Swift
cargo build -p irisrun-render --release    # render core for Swift, then:
(cd crates/render/swift && swift build -Xlinker -L"$PWD/../../../target/release")
```

CI (`.github/workflows/ci.yml`) runs the same checks on Linux and macOS, plus
`buf breaking` against the base branch on pull requests.
