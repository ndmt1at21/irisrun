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
    "P1-17": "P1-17", "E2-05": "E2-05", "E2-10": "overlay adapter (E2-10)", "Charts": "hướng 4, chưa có task",
    "none": "chưa có kế hoạch",
]

/// Generated report sections, keyed by the marker name used in the report.
func reportSections(corpus: Corpus, results: [AppResult], compiled: [String: CompileResult]?) -> [(String, String)] {
    let total = results.count
    let swiftUIApps = results.filter { $0.ui == "swiftui" }
    let uiKitApps = results.filter { $0.ui == "uikit" }
    func used(_ result: AppResult, _ category: String, _ name: String) -> Bool { result.usage[category]?[name] != nil }
    func files(_ result: AppResult, _ kinds: String...) -> Int { kinds.reduce(0) { $0 + (result.inventory.files[$1] ?? 0) } }
    func objcInSwift(_ result: AppResult) -> Bool { !(result.usage["objc"] ?? [:]).isEmpty }
    func objcAny(_ result: AppResult) -> Bool { objcInSwift(result) || files(result, "m", "mm") > 0 || result.inventory.bridgingHeader }
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

    // SwiftUI: views, types, modifiers, wrappers and #Preview in one ranking.
    let swiftUIAttribute = { (name: String) in ["SwiftUI", "Observation"].contains(Catalog.attributes[name]) }
    let swiftUI: [(Rank, String, String)] =
        rank(results, "swiftui.view").map { ($0, "view", $0.name) }
        + rank(results, "swiftui.type").map { ($0, "kiểu", $0.name) }
        + rank(results, "swiftui.modifier").map { ($0, "modifier", "." + $0.name) }
        + rank(results, "attribute", where: swiftUIAttribute).map { ($0, "thuộc tính", "@" + $0.name) }
        + rank(results, "macro", where: { $0 == "Preview" }).map { ($0, "macro", "#" + $0.name) }
    let swiftUITable = table(
        ["#", "API", "Loại", "App", "% app", "Lần dùng"],
        swiftUI.sorted { higher($0.0, $1.0) }.prefix(40).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.2)`", $0.element.1, "\($0.element.0.apps)", percent($0.element.0.apps, total), "\($0.element.0.uses)"]
        })
    let swiftUIByKind = ["swiftui.view": "view", "swiftui.type": "kiểu", "swiftui.modifier": "modifier"].sorted { $0.key < $1.key }
        .map { "- \($0.value): \(rank(results, $0.key).count) API khác nhau" }.joined(separator: "\n")

    // Property wrappers, attached and freestanding macros, result builders (not language or ObjC attributes).
    let wrappers =
        rank(results, "attribute", where: { !["Swift", "ObjC"].contains(Catalog.attributes[$0]) }).map { ($0, "@" + $0.name, Catalog.attributes[$0.name] ?? "bên thứ ba/app") }
        + rank(results, "macro", where: { !Catalog.builtinMacros.contains($0) }).map { ($0, "#" + $0.name, $0.name == "Preview" ? "SwiftUI" : $0.name == "Predicate" ? "Foundation" : "bên thứ ba/app") }
    let wrappersTable = table(
        ["#", "Thuộc tính / macro", "Module", "App", "% app", "Lần dùng"],
        wrappers.sorted { higher($0.0, $1.0) }.prefix(30).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.1)`", $0.element.2, "\($0.element.0.apps)", percent($0.element.0.apps, total), "\($0.element.0.uses)"]
        })
    let environment = table(["#", "Khoá `@Environment`", "App", "% app", "Lần dùng"], rankRows(rank(results, "swiftui.environment"), limit: 15))

    // UIKit, with the count among the UIKit apps of the corpus.
    func uiKitTable(_ category: String, limit: Int) -> String {
        let inUIKitApps = Dictionary(uniqueKeysWithValues: rank(uiKitApps, category).map { ($0.name, $0.apps) })
        return table(
            ["#", "API", "App", "% app", "App UIKit (/\(uiKitApps.count))", "Lần dùng"],
            rank(results, category).prefix(limit).enumerated().map {
                ["\($0.offset + 1)", "`\($0.element.name)`", "\($0.element.apps)", percent($0.element.apps, total), "\(inUIKitApps[$0.element.name] ?? 0)", "\($0.element.uses)"]
            })
    }

    // Apple frameworks by plan coverage; other imports are app modules or third-party libraries.
    let frameworks = table(
        ["#", "Module", "Kế hoạch", "App", "% app", "File import"],
        rank(results, "import", where: { Catalog.appleModules[$0] != nil }).filter { $0.apps > 1 }.enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.name)`", planGroups[Catalog.appleModules[$0.element.name]!]!, "\($0.element.apps)", percent($0.element.apps, total), "\($0.element.uses)"]
        })
    let singleFrameworks = rank(results, "import", where: { Catalog.appleModules[$0] != nil }).filter { $0.apps == 1 }.map(\.name)
    let otherImports = rank(results, "import", where: { Catalog.appleModules[$0] == nil })
    let frameworksNote = """
        Module Apple chỉ 1 app dùng: \(singleFrameworks.map { "`\($0)`" }.joined(separator: ", ")).

        Module không thuộc SDK Apple (module của chính app hoặc thư viện): \(otherImports.count) module; nhiều app nhất: \
        \(otherImports.prefix(12).map { "`\($0.name)` \($0.apps)" }.joined(separator: ", ")).
        """

    // Objective-C dependence: constructs in Swift (no ObjC runtime on Linux) and ObjC sources.
    func split(_ predicate: (AppResult) -> Bool) -> [String] {
        let count = results.filter(predicate).count
        return ["\(count)", percent(count, total), "\(swiftUIApps.filter(predicate).count)", "\(uiKitApps.filter(predicate).count)"]
    }
    let objcRows =
        rank(results, "objc").map { construct in ["`\(construct.name)`"] + split { used($0, "objc", construct.name) } + ["\(construct.uses)"] }
        + [
            ["Bất kỳ cấu trúc nào ở trên"] + split(objcInSwift) + [""],
            ["File Objective-C (`.m`, `.mm`)"] + split { files($0, "m", "mm") > 0 } + ["\(results.reduce(0) { $0 + files($1, "m", "mm") })"],
            ["Bridging header"] + split { $0.inventory.bridgingHeader } + [""],
            ["**Phụ thuộc ObjC bất kỳ** (cấu trúc, file `.m`/`.mm` hoặc bridging header)"] + split(objcAny) + [""],
            ["File C/C++ (`.c`, `.cc`, `.cpp`)"] + split { files($0, "c", "cc", "cpp") > 0 } + ["\(results.reduce(0) { $0 + files($1, "c", "cc", "cpp") })"],
        ]
    let objc = table(["Cấu trúc", "App", "% app", "SwiftUI (/\(swiftUIApps.count))", "UIKit (/\(uiKitApps.count))", "Lần dùng / số file"], objcRows)

    // Build inventory: what share of the corpus each gap touches.
    let inventory = table(["Khoảng trống", "App", "% app", "Task trong plan"], [
        countRow("Có `.xcodeproj` (phải đọc `.pbxproj`)", "P1-12") { $0.inventory.xcodeProjects > 0 },
        countRow("Không commit `.xcodeproj`, sinh bằng XcodeGen/Tuist", "P1-12") { $0.inventory.xcodeProjects == 0 && $0.inventory.generator != nil },
        countRow("Chỉ có `Package.swift` (không `.xcodeproj`)", "P1-12") { $0.inventory.xcodeProjects == 0 && $0.inventory.generator == nil && $0.inventory.rootPackage },
        countRow("Local package (app chia nhiều module)", "P1-12") { $0.inventory.localPackages > 0 || $0.inventory.packageManifests > ($0.inventory.rootPackage ? 1 : 0) },
        countRow("Gói SPM bên thứ ba", "P1-12, E2-04") { !$0.inventory.spm.isEmpty },
        countRow("CocoaPods", "chưa có task") { !$0.inventory.pods.isEmpty },
        countRow("Carthage", "chưa có task") { !$0.inventory.carthage.isEmpty },
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
        countRow("Widget (`import WidgetKit`)", "chưa có kế hoạch") { used($0, "import", "WidgetKit") },
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
    let dependencies = table(
        ["#", "Gói", "Qua", "App"],
        dependencyApps.sorted { ($1.value, $0.key) < ($0.value, $1.key) }.prefix(25).enumerated().map {
            ["\($0.offset + 1)", "`\($0.element.key)`", managers[$0.element.key]!.sorted().joined(separator: ", "), "\($0.element.value)"]
        })

    // Upper bound for a compile rate: apps whose Apple imports are all covered by the plan up to a step.
    let steps: [(String, Set<String>)] = [
        ("1. Chỉ SwiftUI/UIKit, Foundation và shim nhỏ (OS log, CryptoKit…)", ["toolchain", "OpenKit", "shim"]),
        ("2. + framework đợt 1 (P1-17: Combine, StoreKit, PhotosUI, CoreLocation…)", ["P1-17"]),
        ("3. + SwiftData/Core Data (E2-05), overlay adapter (E2-10), Charts", ["E2-05", "E2-10", "Charts"]),
    ]
    func appleGroups(_ result: AppResult) -> Set<String> { Set((result.usage["import"] ?? [:]).keys.compactMap { Catalog.appleModules[$0] }) }
    let unblocked = results.filter { !objcAny($0) && $0.inventory.pods.isEmpty && $0.inventory.carthage.isEmpty }
    var covered: Set<String> = []
    let readiness = table(["Mức OpenKit phủ đủ", "App", "% app", "Trong đó có gói SPM bên thứ ba"], steps.map { step in
        covered.formUnion(step.1)
        let ready = unblocked.filter { appleGroups($0).isSubset(of: covered) }
        return [step.0, "\(ready.count)", percent(ready.count, total), "\(ready.filter { !$0.inventory.spm.isEmpty }.count)"]
    } + [["Còn lại: phụ thuộc ObjC, CocoaPods/Carthage hoặc framework chưa có kế hoạch", "\(total - unblocked.filter { appleGroups($0).isSubset(of: covered) }.count)", "", ""]])

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
        compile = "_Chưa có số: bước compile chờ OpenKit (P0-05). Cách chạy ở mục \"Tỉ lệ compile\"._"
    }

    let apps = table(
        ["App", "UI", "File", "Dòng", "Project", "iOS", "Swift", "SPM", "Pods/Carthage", "`.m`/`.mm`", "Storyboard/XIB", "`.xcassets`", "`.xcstrings`"],
        results.map { result in
            let inventory = result.inventory
            let project =
                inventory.xcodeProjects > 0 ? "xcodeproj" : inventory.generator ?? (inventory.rootPackage ? "Package.swift" : "?")
            return [
                result.id, result.ui, "\(result.swiftFiles)", "\(result.swiftLines)", project,
                newest(inventory.deploymentTargets) ?? "-", newest(inventory.swiftVersions) ?? newest(inventory.toolsVersions) ?? "-",
                "\(inventory.spm.count)", "\(inventory.pods.count + inventory.carthage.count)", "\(files(result, "m", "mm"))",
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
        ("swiftui", swiftUITable + "\n\n" + swiftUIByKind),
        ("swiftui-wrappers", wrappersTable),
        ("swiftui-environment", environment),
        ("uikit", uiKitTable("uikit.type", limit: 25)),
        ("uikit-members", uiKitTable("uikit.member", limit: 25)),
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
