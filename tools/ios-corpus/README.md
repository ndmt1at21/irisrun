# ios-corpus

The iOS compatibility corpus (task P0-08) and the tool that measures which SwiftUI and UIKit
APIs it uses. Results: [docs/reports/p0-08-ios-corpus.md](../../docs/reports/p0-08-ios-corpus.md).

- `corpus.json`: 65 apps from [open-source-ios-apps](https://github.com/dkhamsing/open-source-ios-apps)
  (50 SwiftUI, 15 UIKit), each pinned to a commit, with license, tags and why it was picked.
- `ios-corpus`: a SwiftPM tool that fetches the apps, parses their Swift sources with SwiftSyntax
  604 (the Swift 6.4 release) and writes the rankings and the build inventory.

## Run

You need Swift 6.4 and git 2.27 or newer. Keep checkouts and build products outside the repo, in a
directory that survives reboots (the 65 sparse checkouts take about 520 MB):

```sh
W=~/.cache/irisrun/ios-corpus
cd tools/ios-corpus
swift build -c release --scratch-path $W/build
ios=$W/build/release/ios-corpus

$ios fetch corpus.json $W/apps
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md
swift test --scratch-path $W/build-test   # scanner check; its own path, or the release build starts over
```

`fetch` makes shallow, blobless, sparse checkouts of the pinned commits: source and project files
only, no images, fonts, archives or framework binaries. Re-running it skips apps that are already
at their commit, so after a network error just run it again. On a host whose Swift or git is too
old (Ubuntu 20.04), run all of the above in the `swift:6.4.1-noble` image, `fetch` included.

`analyze` writes `$W/out/results.json` (inventory and usage counts per app) and
`$W/out/tables.md` (every table). With `--report` it also rewrites the blocks between
`<!-- generated:name -->` and `<!-- /generated:name -->` in the report; the prose around them is
written by hand and has to be reread when the numbers move.

## Compile rate (hook for P0-05)

Until `compile` has run, the report has a build inventory and an import-based ceiling instead of
a compile rate. P0-05's `runtimes/ios/Scripts/compile-app.sh` builds one app directory against
OpenKit (it needs that task's checkouts, plus P0-06's render core and fonts; see the P0-05
report):

```sh
$ios compile corpus.json $W/apps $W/out ../../runtimes/ios/Scripts/compile-app.sh   # runs <script> <app-dir> per app
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md
```

The app directory is appended as the last argument, so pass no options after the script. Exit
status 0 counts as compiled. Output goes to `$W/out/compile/<id>.log`, the summary to
`$W/out/compile.json`, which `analyze` turns into the report's compile section. The script owns
the build: collect the app's Swift files, generate a SwiftPM package that depends on OpenKit,
pass `-module-alias SwiftUI=…`, strip `#Preview`, run `swift build`.

## How names are attributed

The tool parses, it does not type-check. Per file it collects imports, capitalized names in type
and expression position, method calls, attributes, macros, `@Environment` keys, Objective-C
constructs, SF Symbol names and `Type.member` uses. Conditions of `#if` are skipped; the code in
every branch counts. Then, per app:

- A name is SwiftUI when the file imports SwiftUI, the name is in `Catalog.swift` and the app does
  not declare a type with that name. Modifiers are calls on a value (`x.padding()`) or on implicit
  self. UIKit is any `UI…` type plus a few `NS…` layout and text types.
- Objective-C constructs carry the status measured with Swift 6.4.1 on Linux
  (`Catalog.objcOnLinux`). An app needs nothing, a SwiftSyntax rewrite (only `@objc`,
  `#selector`, `#keyPath`, `@IBOutlet`, `Selector` fail), or an ObjC runtime (KVO, `@NSManaged`,
  `.m` files, a bridging header).
- UIKit members get their receiver type from declarations (`let label = UILabel()`,
  `tableView: UITableView!`), from `self`, `super` and implicit self inside subclasses (walking the
  app's class hierarchy), and from static access. Members the app declares itself, including in
  extensions of UIKit types, are left out.
- Limits: every Swift file in the repo counts except tests and build scripts, including widget,
  macOS and watchOS targets, since target membership is P1-12's job. Variable types are not
  inferred beyond their declarations, and leading-dot members (`.font(.title)`) are not counted.
  `Catalog.devPackages` lists build and test tools, which the dependency counts leave out.

The catalog is hand-written from public documentation, not from SDK files. The `unattributed`
block in `tables.md` lists frequent names the catalog does not cover; add real SwiftUI or UIKit
names from there to `Catalog.swift`.

To move an app to a newer commit, edit `commit` in `corpus.json` (`git ls-remote <repo> HEAD`
prints the current one) and run `fetch` again.
