import Foundation

struct Rank {
    let name: String
    let apps: Int
    let uses: Int
}

/// Names in a usage category, ranked by number of apps using them, then by occurrences.
func rank(_ results: [AppResult], _ category: String, where include: (String) -> Bool = { _ in true }) -> [Rank] {
    var apps: [String: Int] = [:]
    var uses: [String: Int] = [:]
    for result in results {
        for (name, count) in result.usage[category] ?? [:] where include(name) {
            apps[name, default: 0] += 1
            uses[name, default: 0] += count
        }
    }
    return apps.map { Rank(name: $0.key, apps: $0.value, uses: uses[$0.key] ?? 0) }.sorted(by: higher)
}

private func higher(_ a: Rank, _ b: Rank) -> Bool { (b.apps, b.uses, a.name) < (a.apps, a.uses, b.name) }

private func table(_ header: [String], _ rows: [[String]]) -> String {
    ([header, header.map { _ in "---" }] + rows).map { "| \($0.joined(separator: " | ")) |" }.joined(separator: "\n")
}

private func percent(_ count: Int, _ total: Int) -> String {
    "\(Int((Double(count) * 100 / Double(max(total, 1))).rounded()))%"
}

private let planGroups = [
    "toolchain": "có sẵn trong toolchain", "OpenKit": "OpenKit (P1-13, P1-16)", "shim": "shim nhỏ, chưa có task",
    "other-platform": "macOS/watchOS/tvOS, không build cho iOS", "P1-17": "P1-17", "E2-05": "E2-05",
    "E2-10": "overlay adapter (E2-10)", "Charts": "hướng 4, chưa có task", "none": "chưa có kế hoạch, stub ở P1-18",
]

private let objcStatus = ["error": "lỗi compile", "link": "lỗi link", "ok": "compile được"]

/// Generated report sections, keyed by the marker name used in the report.
func reportSections(corpus: Corpus, results: [AppResult], compiled: [String: CompileResult]?) -> [(String, String)] {
    let total = results.count
    let swiftUIApps = results.filter { $0.ui == "swiftui" }
    let uiKitApps = results.filter { $0.ui == "uikit" }
    func used(_ result: AppResult, _ category: String, _ name: String) -> Bool { result.usage[category]?[name] != nil }
    func files(_ result: AppResult, _ kinds: String...) -> Int { kinds.reduce(0) { $0 + (result.inventory.files[$1] ?? 0) } }
    /// Third-party packages the app runs with; build and test tools are left out.
    func packages(_ result: AppResult) -> (spm: [String], pods: [String]) {
        let inventory = result.inventory
        let pods = inventory.pods.map { $0.lowercased() } + inventory.carthage
        return (inventory.spm.filter { !Catalog.devPackages.contains($0) }, pods.filter { !Catalog.devPackages.contains($0) })
    }
    func countRow(_ label: String, _ task: String? = nil, _ predicate: (AppResult) -> Bool) -> [String] {
        let count = results.filter(predicate).count
        return [label, "\(count)", percent(count, total)] + (task.map { [$0] } ?? [])
    }
    func rankRows(_ ranks: [Rank], limit: Int, name: (Rank) -> String = { "`\($0.name)`" }) -> [[String]] {
        ranks.prefix(limit).enumerated().map { ["\($0.offset + 1)", name($0.element), "\($0.element.apps)", percent($0.element.apps, total), "\($0.element.uses)"] }
    }

    // Corpus summary.
    let lines = results.map(\.swiftLines).sorted()
    let ids = Set(results.map(\.id))
    let licenses = Dictionary(grouping: corpus.apps.filter { ids.contains($0.id) }, by: \.license).mapValues(\.count)
        .sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map { "\($0.key) \($0.value)" }
    let summary = table(["Chỉ số", "Giá trị"], [
        ["App", "\(total) (SwiftUI \(swiftUIApps.count), UIKit \(uiKitApps.count))"],
        ["File Swift (không tính test)", "\(results.reduce(0) { $0 + $1.swiftFiles })"],
        ["Dòng Swift", "\(lines.reduce(0, +))"],
        ["Dòng Swift mỗi app: trung vị (nhỏ nhất–lớn nhất)", lines.isEmpty ? "-" : "\(lines[lines.count / 2]) (\(lines.first!)–\(lines.last!))"],
        ["License", licenses.joined(separator: ", ")],
        ["Điểm vào (`@main`)", rank(results, "entry").map { "\($0.name) \($0.apps)" }.joined(separator: ", ")],
    ])

    // SwiftUI rankings.
    let views = rank(results, "swiftui.view")
    let types = rank(results, "swiftui.type")
    let modifiers = rank(results, "swiftui.modifier")
    let swiftUIViews = table(["#", "View", "App", "% app", "Lần dùng"], rankRows(views, limit: 40)) + """


        Số API khác nhau: \(views.count) view, \(types.count) kiểu, \(modifiers.count) modifier. Hàm tự do: \
        \(rank(results, "swiftui.function").map { "`\($0.name)` \($0.apps) app" }.joined(separator: ", ")).
        """
    let swiftUIModifiers = table(["#", "Modifier hoặc method", "App", "% app", "Lần dùng"], rankRows(modifiers, limit: 60) { "`.\($0.name)`" })
    let swiftUITypes = table(["#", "Kiểu", "App", "% app", "Lần dùng"], rankRows(types, limit: 30))

    // Property wrappers, attached and freestanding macros, result builders (not language or ObjC attributes).
    let wrappers =
        rank(results, "attribute", where: { !["Swift", "ObjC"].contains(Catalog.attributes[$0]) }).map { ($0, "@" + $0.name, Catalog.attributes[$0.name] ?? "bên thứ ba/app") }
        + rank(results, "macro", where: { !Catalog.builtinMacros.contains($0) }).map { ($0, "#" + $0.name, Catalog.macros[$0.name] ?? "bên thứ ba/app") }
    let wrappersTable = table(
        ["#", "Thuộc tính / macro", "Module", "App", "% app", "Lần dùng"],
        wrappers.sorted { higher($0.0, $1.0) }.prefix(30).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.1)`", $0.element.2, "\($0.element.0.apps)", percent($0.element.0.apps, total), "\($0.element.0.uses)"]
        })
    let environment = table(["#", "Khoá `@Environment`", "App", "% app", "Lần dùng"], rankRows(rank(results, "swiftui.environment"), limit: 15))

    // How much UIKit the SwiftUI apps need: none, non-view types only, or views and view controllers.
    func hasUIKit(_ result: AppResult) -> Bool { !(result.usage["uikit.type"] ?? [:]).isEmpty }
    func wrapsUIKit(_ result: AppResult) -> Bool { used(result, "swiftui.type", "UIViewRepresentable") || used(result, "swiftui.type", "UIViewControllerRepresentable") }
    func usesUIKitViews(_ result: AppResult) -> Bool {
        wrapsUIKit(result) || used(result, "swiftui.type", "UIHostingController")
            || (result.usage["uikit.type"] ?? [:]).keys.contains { $0.contains("View") || $0.contains("Controller") }
    }
    func swiftUIRow(_ label: String, _ predicate: (AppResult) -> Bool) -> [String] {
        let count = swiftUIApps.filter(predicate).count
        return [label, "\(count)", percent(count, swiftUIApps.count)]
    }
    let uiKitInSwiftUI = table(["\(swiftUIApps.count) app SwiftUI", "App", "%"], [
        swiftUIRow("Không dùng tên UIKit nào") { !hasUIKit($0) },
        swiftUIRow("Chỉ dùng kiểu UIKit không phải view (vòng đời app, `UIDevice`, `UIPasteboard`…)") { hasUIKit($0) && !usesUIKitViews($0) },
        swiftUIRow("Dùng view hoặc view controller UIKit") { usesUIKitViews($0) },
        swiftUIRow("Trong đó bọc view UIKit (`UIViewRepresentable`, `UIViewControllerRepresentable`)", wrapsUIKit),
        swiftUIRow("Trong đó đặt SwiftUI vào UIKit (`UIHostingController`)") { used($0, "swiftui.type", "UIHostingController") },
    ]) + "\n\nApp UIKit có import SwiftUI: \(uiKitApps.filter { used($0, "import", "SwiftUI") }.count)/\(uiKitApps.count)."

    // UIKit, with the count among the SwiftUI and the UIKit apps of the corpus.
    func uiKitTable(_ category: String, limit: Int) -> String {
        let inSwiftUIApps = Dictionary(uniqueKeysWithValues: rank(swiftUIApps, category).map { ($0.name, $0.apps) })
        let inUIKitApps = Dictionary(uniqueKeysWithValues: rank(uiKitApps, category).map { ($0.name, $0.apps) })
        return table(
            ["#", "API", "App", "% app", "App SwiftUI (/\(swiftUIApps.count))", "App UIKit (/\(uiKitApps.count))", "Lần dùng"],
            rank(results, category).prefix(limit).enumerated().map {
                let name = $0.element.name
                return ["\($0.offset + 1)", "`\(name)`", "\($0.element.apps)", percent($0.element.apps, total), "\(inSwiftUIApps[name] ?? 0)", "\(inUIKitApps[name] ?? 0)", "\($0.element.uses)"]
            })
    }

    // Apple frameworks by plan coverage; other imports are app modules or third-party libraries.
    let appleImports = rank(results, "import", where: { Catalog.appleModules[$0] != nil })
    let frameworks = table(
        ["#", "Module", "Kế hoạch", "App", "% app", "File import"],
        appleImports.prefix(40).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.name)`", planGroups[Catalog.appleModules[$0.element.name]!]!, "\($0.element.apps)", percent($0.element.apps, total), "\($0.element.uses)"]
        })
    let otherImports = rank(results, "import", where: { Catalog.appleModules[$0] == nil })
    let frameworksNote = """
        Module Apple khác (\(appleImports.count - min(40, appleImports.count)) module, kèm số app): \
        \(appleImports.dropFirst(40).map { "`\($0.name)` \($0.apps)" }.joined(separator: ", ")).

        Module không thuộc SDK Apple (module của chính app hoặc thư viện): \(otherImports.count) module; nhiều app nhất: \
        \(otherImports.prefix(12).map { "`\($0.name)` \($0.apps)" }.joined(separator: ", ")).
        """

    // Objective-C: Swift constructs with their measured status on Linux, then ObjC sources.
    func split(_ predicate: (AppResult) -> Bool) -> [String] {
        let count = results.filter(predicate).count
        return ["\(count)", percent(count, total), "\(swiftUIApps.filter(predicate).count)", "\(uiKitApps.filter(predicate).count)"]
    }
    func failsOnLinux(_ result: AppResult) -> Bool { (result.usage["objc"] ?? [:]).keys.contains { Catalog.objcOnLinux[$0] != "ok" } }
    let objcRows =
        rank(results, "objc").map { construct in
            ["`\(construct.name)`", objcStatus[Catalog.objcOnLinux[construct.name] ?? "error"]!] + split { used($0, "objc", construct.name) } + ["\(construct.uses)"]
        }
        + [
            ["Có cấu trúc lỗi trên Linux", ""] + split(failsOnLinux) + [""],
            ["File Objective-C (`.m`, `.mm`)", ""] + split { files($0, "m", "mm") > 0 } + ["\(results.reduce(0) { $0 + files($1, "m", "mm") })"],
            ["Bridging header", ""] + split { $0.inventory.bridgingHeader } + [""],
            ["**Không cần ObjC**", ""] + split { $0.objcNeed == .none } + [""],
            ["**Chỉ cần viết lại bằng SwiftSyntax** (`@objc`, `@objcMembers`, `#selector`, `#keyPath`, `Selector`, `@IBOutlet`)", ""] + split { $0.objcNeed == .rewrite } + [""],
            ["**Cần ObjC runtime hoặc Core Data** (KVO, `@NSManaged`, file `.m`/`.mm`, bridging header)", ""] + split { $0.objcNeed == .runtime } + [""],
            ["File C/C++ (`.c`, `.cc`, `.cpp`)", ""] + split { files($0, "c", "cc", "cpp") > 0 } + ["\(results.reduce(0) { $0 + files($1, "c", "cc", "cpp") })"],
        ]
    let objc = table(["Cấu trúc", "Linux (Swift 6.4.1)", "App", "% app", "SwiftUI (/\(swiftUIApps.count))", "UIKit (/\(uiKitApps.count))", "Lần dùng / số file"], objcRows)

    // Build inventory: what share of the corpus each gap touches.
    let inventory = table(["Khoảng trống", "App", "% app", "Task trong plan"], [
        countRow("Có `.xcodeproj` (phải đọc `.pbxproj`)", "P1-12") { $0.inventory.xcodeProjects > 0 },
        countRow("Không commit `.xcodeproj`, sinh bằng XcodeGen/Tuist", "P1-12") { $0.inventory.xcodeProjects == 0 && $0.inventory.generator != nil },
        countRow("Chỉ có `Package.swift` (không `.xcodeproj`)", "P1-12") { $0.inventory.xcodeProjects == 0 && $0.inventory.generator == nil && $0.inventory.rootPackage },
        countRow("Local package (app chia nhiều module)", "P1-12") { $0.inventory.localPackages > 0 || $0.inventory.packageManifests > ($0.inventory.rootPackage ? 1 : 0) },
        countRow("Gói SPM bên thứ ba (không tính công cụ build/test)", "P1-12, E2-04") { !packages($0).spm.isEmpty },
        countRow("CocoaPods hoặc Carthage (không tính công cụ build/test)", "chưa có task") { !packages($0).pods.isEmpty },
        countRow("Binary vendored (`.xcframework`, `.framework`)", "P0-09, P1-05") { files($0, "xcframework", "framework") > 0 },
        countRow("File Objective-C (`.m`, `.mm`) hoặc bridging header", "P0-07, E2-03") { files($0, "m", "mm") > 0 || $0.inventory.bridgingHeader },
        countRow("File C/C++", "clang trong P1-12") { files($0, "c", "cc", "cpp") > 0 },
        countRow("Storyboard/XIB giao diện (không tính launch screen)", "P1-16") { files($0, "storyboard", "xib") > 0 },
        countRow("Chỉ có launch screen storyboard", "P1-12 (bỏ qua được)") { files($0, "launch-storyboard") > 0 && files($0, "storyboard", "xib") == 0 },
        countRow("Asset catalog (`.xcassets`)", "P1-12") { files($0, "xcassets") > 0 },
        countRow("String Catalog (`.xcstrings`)", "P1-12") { files($0, "xcstrings") > 0 },
        countRow("Bản địa hoá kiểu cũ (`.strings`)", "P1-12") { files($0, "strings") > 0 },
        countRow("Core Data model (`.xcdatamodeld`)", "E2-05") { files($0, "xcdatamodeld") > 0 },
        countRow("Cấu hình StoreKit (`.storekit`)", "P1-17") { files($0, "storekit") > 0 },
        countRow("Metal shader (`.metal`)", "chưa có kế hoạch") { files($0, "metal") > 0 },
        countRow("`#Preview`", "P1-12, P1-19") { used($0, "macro", "Preview") },
        countRow("`PreviewProvider` (kiểu cũ)", "P1-12, P1-19") { used($0, "swiftui.type", "PreviewProvider") },
        countRow("SF Symbols (`systemName:`, `systemImage:`)", "bộ icon thay thế") { !($0.usage["sfsymbol"] ?? [:]).isEmpty },
        countRow("Widget extension (`@main` trên `WidgetBundle`/`Widget`)", "chưa có kế hoạch") { used($0, "entry", "WidgetKit") },
        countRow("Code macOS/watchOS trong cùng repo (import AppKit, WatchKit…)", "P1-12 (chọn target iOS)") { result in
            (result.usage["import"] ?? [:]).keys.contains { Catalog.appleModules[$0] == "other-platform" }
        },
    ])

    func distribution(_ label: String, _ value: (AppResult) -> String?) -> String {
        let counts = Dictionary(grouping: results) { value($0) ?? "không rõ" }.mapValues(\.count)
        return table([label, "App"], counts.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }.map { [$0.key, "\($0.value)"] })
    }
    func newest(_ versions: Set<String>) -> String? { versions.max { $0.localizedStandardCompare($1) == .orderedAscending } }
    let deployment = distribution("iOS deployment target cao nhất") { newest($0.inventory.deploymentTargets).map { "iOS \($0.split(separator: ".")[0])" } }
    let swiftVersion = distribution("Swift language mode (`SWIFT_VERSION` cao nhất, hoặc tools-version)") { result in
        (newest(result.inventory.swiftVersions) ?? newest(result.inventory.toolsVersions)).map { "Swift \($0.split(separator: ".")[0])" }
    }

    // Third-party dependencies across package managers.
    var managers: [String: Set<String>] = [:]
    var dependencyApps: [String: Int] = [:]
    for result in results {
        let names = result.inventory.spm.map { ($0, "SPM") } + result.inventory.pods.map { ($0.lowercased(), "CocoaPods") } + result.inventory.carthage.map { ($0, "Carthage") }
        for (name, manager) in names { managers[name, default: []].insert(manager) }
        for name in Set(names.map(\.0)) { dependencyApps[name, default: 0] += 1 }
    }
    let dependencyRanks = dependencyApps.sorted { ($1.value, $0.key) < ($0.value, $1.key) }
    let runtimeDependencies = dependencyRanks.filter { !Catalog.devPackages.contains($0.key) }
    let dependencies = table(
        ["#", "Gói", "Qua", "App"],
        runtimeDependencies.prefix(25).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.key)`", managers[$0.element.key]!.sorted().joined(separator: ", "), "\($0.element.value)"]
        }) + """


        \(runtimeDependencies.count) gói khác nhau, \(runtimeDependencies.filter { $0.value == 1 }.count) gói chỉ 1 app dùng. \
        Công cụ build/test, không tính ở bảng này và ở các bảng khác: \
        \(dependencyRanks.filter { Catalog.devPackages.contains($0.key) }.map { "`\($0.key)` \($0.value)" }.joined(separator: ", ")).
        """

    // Upper bound for a compile rate: apps whose every blocker is covered once the plan reaches a step.
    // Modules of macOS, watchOS and tvOS targets never block, because the iOS build leaves them out.
    func appleGroups(_ result: AppResult) -> Set<String> { Set((result.usage["import"] ?? [:]).keys.compactMap { Catalog.appleModules[$0] }) }
    func ready(_ groups: Set<String>, _ objc: Set<ObjCNeed>) -> [AppResult] {
        results.filter { packages($0).pods.isEmpty && objc.contains($0.objcNeed) && appleGroups($0).isSubset(of: groups) }
    }
    func readinessRow(_ label: String, _ apps: [AppResult]) -> [String] {
        [label, "\(apps.count)", percent(apps.count, total), "\(apps.filter { !packages($0).spm.isEmpty }.count)"]
    }
    let steps: [(String, Set<String>, Set<ObjCNeed>)] = [
        ("1. SwiftUI, UIKit, Foundation và shim nhỏ (os, CryptoKit, UTType…), không dùng ObjC", ["toolchain", "OpenKit", "shim", "other-platform"], [.none]),
        ("2. + framework đợt 1 (P1-17: Combine, StoreKit, PhotosUI, CoreLocation…)", ["P1-17"], []),
        ("3. + stub cho mọi framework Apple còn lại (P1-18), kể cả SwiftData, MapKit, WebKit", ["E2-05", "E2-10", "Charts", "none"], []),
        ("4. + viết lại `@objc`, `#selector`, `#keyPath`, `@IBOutlet` bằng SwiftSyntax", [], [.rewrite]),
    ]
    var groups: Set<String> = []
    var objcAllowed: Set<ObjCNeed> = []
    var covered: [AppResult] = []
    let readinessRows = steps.map { step in
        groups.formUnion(step.1)
        objcAllowed.formUnion(step.2)
        covered = ready(groups, objcAllowed)
        return readinessRow(step.0, covered)
    }
    let readiness = table(
        ["Mức phủ (cộng dồn)", "App", "% app", "Trong đó cần gói SPM bên thứ ba"],
        readinessRows + [
            ["Còn lại: cần ObjC runtime/Core Data (KVO, `@NSManaged`, file `.m`) hoặc CocoaPods/Carthage", "\(total - covered.count)", percent(total - covered.count, total), ""],
            readinessRow("Đối chiếu: như mức 4 nhưng không có stub, E2-05, E2-10 và Charts làm thật", ready(groups.subtracting(["none"]), objcAllowed)),
        ])

    // SF Symbols: Apple's license rules them out, so the replacement icon set needs these names.
    let symbols = rank(results, "sfsymbol", where: { $0 != "(dynamic)" })
    let symbolApps = results.filter { !($0.usage["sfsymbol"] ?? [:]).isEmpty }.count
    let sfSymbols = table(["Chỉ số", "Giá trị"], [
        ["App dùng SF Symbols", "\(symbolApps) (\(percent(symbolApps, total)))"],
        ["Tên symbol khác nhau (chuỗi literal)", "\(symbols.count)"],
        ["Lần gọi với tên không phải literal", "\(rank(results, "sfsymbol", where: { $0 == "(dynamic)" }).first?.uses ?? 0)"],
        ["Phổ biến nhất (số app)", symbols.prefix(15).map { "`\($0.name)` \($0.apps)" }.joined(separator: ", ")],
    ])

    let compile: String
    if let compiled {
        let attempted = compiled.filter { ids.contains($0.key) }
        let passed = attempted.filter(\.value.ok).keys.sorted()
        compile = table(["Chỉ số", "Giá trị"], [
            ["App đã thử compile", "\(attempted.count)"],
            ["Compile được", "\(passed.count) (\(percent(passed.count, attempted.count)))"],
            ["App compile được", passed.joined(separator: ", ")],
        ])
    } else {
        compile = "_Chưa có số: `ios-corpus compile` chưa được chạy với OpenKit (chờ P0-05)._"
    }

    let objcNeeds: [ObjCNeed: String] = [.none: "không", .rewrite: "viết lại", .runtime: "runtime"]
    let apps = table(
        ["App", "UI", "File", "Dòng", "Project", "iOS", "Swift", "SPM", "Pods/Carthage", "ObjC", "`.m`/`.mm`", "Storyboard/XIB", "`.xcassets`", "`.xcstrings`"],
        results.map { result in
            let inventory = result.inventory
            let project =
                inventory.xcodeProjects > 0 ? "xcodeproj" : inventory.generator ?? (inventory.rootPackage ? "Package.swift" : "?")
            return [
                result.id, result.ui, "\(result.swiftFiles)", "\(result.swiftLines)", project,
                newest(inventory.deploymentTargets) ?? "-", newest(inventory.swiftVersions) ?? newest(inventory.toolsVersions) ?? "-",
                "\(packages(result).spm.count)", "\(packages(result).pods.count)", objcNeeds[result.objcNeed]!, "\(files(result, "m", "mm"))",
                "\(files(result, "storyboard", "xib"))", "\(files(result, "xcassets"))", "\(files(result, "xcstrings"))",
            ]
        })

    // For catalog maintenance only: frequent names the catalog does not attribute.
    let unattributed = """
        Kiểu không quy được về SwiftUI/UIKit (nhiều app nhất): \(rank(results, "other.type").prefix(80).map { "\($0.name) \($0.apps)" }.joined(separator: ", "))

        Lời gọi method trong file SwiftUI không có trong danh mục modifier: \(rank(results, "other.call").prefix(80).map { "\($0.name) \($0.apps)" }.joined(separator: ", "))
        """

    return [
        ("summary", summary),
        ("swiftui-views", swiftUIViews),
        ("swiftui-modifiers", swiftUIModifiers),
        ("swiftui-types", swiftUITypes),
        ("swiftui-wrappers", wrappersTable),
        ("swiftui-environment", environment),
        ("uikit-in-swiftui", uiKitInSwiftUI),
        ("uikit", uiKitTable("uikit.type", limit: 40)),
        ("uikit-members", uiKitTable("uikit.member", limit: 30)),
        ("quartzcore", uiKitTable("quartzcore.type", limit: 10)),
        ("frameworks", frameworks + "\n\n" + frameworksNote),
        ("objc", objc),
        ("inventory", inventory + "\n\n" + deployment + "\n\n" + swiftVersion),
        ("dependencies", dependencies),
        ("readiness", readiness),
        ("sfsymbols", sfSymbols),
        ("compile", compile),
        ("apps", apps),
        ("unattributed", unattributed),
    ]
}

/// Replaces the text between `<!-- generated:key -->` and `<!-- /generated:key -->` in the report.
func splice(_ sections: [(String, String)], into report: URL) throws {
    var text = try String(contentsOf: report, encoding: .utf8)
    for (key, body) in sections {
        guard let start = text.range(of: "<!-- generated:\(key) -->"),
            let end = text.range(of: "<!-- /generated:\(key) -->", range: start.upperBound..<text.endIndex)
        else { continue }
        text.replaceSubrange(start.upperBound..<end.lowerBound, with: "\n\(body)\n")
    }
    try text.write(to: report, atomically: true, encoding: .utf8)
}
