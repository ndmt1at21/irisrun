# ios-corpus

The iOS compatibility corpus (task P0-08) and the tool that measures which SwiftUI and UIKit
APIs it uses. Results: [docs/reports/p0-08-ios-corpus.md](../../docs/reports/p0-08-ios-corpus.md).

- `corpus.json`: 65 apps from [open-source-ios-apps](https://github.com/dkhamsing/open-source-ios-apps)
  (50 SwiftUI, 15 UIKit), each pinned to a commit, with license, tags and why it was picked.
- `ios-corpus`: a SwiftPM tool that fetches the apps, parses their Swift sources with SwiftSyntax
  604 (the Swift 6.4 release) and writes the rankings and the build inventory.

## Run

You need Swift 6.4 and git 2.27 or newer. Keep checkouts and build products outside the repo:

```sh
W=/tmp/ios-corpus   # any scratch directory
cd tools/ios-corpus
swift build -c release --scratch-path $W/build
ios=$W/build/release/ios-corpus

$ios fetch corpus.json $W/apps
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md
swift test --scratch-path $W/build   # scanner check
```

`fetch` makes shallow, blobless, sparse checkouts of the pinned commits: source and project files
only, no images, fonts, archives or framework binaries. Re-running it skips apps that are already
at their commit.

`analyze` writes `$W/out/results.json` (inventory and usage counts per app) and
`$W/out/tables.md` (every table). With `--report` it also rewrites the blocks between
`<!-- generated:name -->` and `<!-- /generated:name -->` in the report; the prose around them is
written by hand and has to be reread when the numbers move.

## Compile rate (hook for P0-05)

There is no OpenKit yet, so the report has a build inventory instead of a compile rate. Once
P0-05 can compile an app, give `compile` a script that builds one app directory:

```sh
$ios compile corpus.json $W/apps $W/out ./compile-app.sh   # runs ./compile-app.sh <app-dir> per app
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md
```

Exit status 0 counts as compiled. Output goes to `$W/out/compile/<id>.log`, the summary to
`$W/out/compile.json`, which `analyze` turns into the report's compile section. The script owns
the build: collect the app's Swift files, generate a SwiftPM package that depends on OpenKit,
pass `-module-alias SwiftUI=…`, strip `#Preview`, run `swift build`.

## How names are attributed

The tool parses, it does not type-check. Per file it collects imports, capitalized names in type
and expression position, method calls, attributes, macros, `@Environment` keys, Objective-C
constructs, SF Symbol names and `Type.member` uses. Then, per app:

- A name is SwiftUI when the file imports SwiftUI, the name is in `Catalog.swift` and the app does
  not declare a type with that name. Modifiers are calls on a value (`x.padding()`) or on implicit
  self. UIKit is any `UI…` type plus a few `NS…` layout types.
- UIKit members get their receiver type from declarations (`let label = UILabel()`,
  `tableView: UITableView!`), from `self`, `super` and implicit self inside subclasses (walking the
  app's class hierarchy), and from static access. Members the app declares itself, including in
  extensions of UIKit types, are left out.
- Limits: every non-test Swift file in the repo counts, including macOS and watchOS targets, since
  target membership is P1-12's job. Variable types are not inferred beyond their declarations.

The catalog is hand-written from public documentation, not from SDK files. The `unattributed`
block in `tables.md` lists frequent names the catalog does not cover; add real SwiftUI or UIKit
names from there to `Catalog.swift`.

To move an app to a newer commit, edit `commit` in `corpus.json` (`git ls-remote <repo> HEAD`
prints the current one) and run `fetch` again.
