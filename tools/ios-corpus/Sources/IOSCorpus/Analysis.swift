import Foundation

struct AppResult: Codable, Sendable {
    let id: String
    let ui: String
    let swiftFiles: Int
    let swiftLines: Int
    let inventory: Inventory
    /// Category -> name -> occurrences. Categories: import (files), swiftui.view, swiftui.type,
    /// swiftui.modifier, swiftui.environment, attribute, macro, uikit.type, uikit.member,
    /// quartzcore.type, objc, sfsymbol, entry, and other.type / other.call for catalog review.
    let usage: [String: [String: Int]]
}

/// Attributes one app's file facts to frameworks, using what the app declares itself.
func analyze(id: String, ui: String, files: [FileFacts], inventory: Inventory) -> AppResult {
    var declaredTypes: Set<String> = []
    var declaredMembers: Set<String> = []
    var declaredLocals: Set<String> = []
    var superclasses: [String: String] = [:]
    for file in files {
        declaredTypes.formUnion(file.declaredTypes)
        declaredMembers.formUnion(file.declaredMembers)
        declaredLocals.formUnion(file.declaredLocals)
        superclasses.merge(file.superclasses) { first, _ in first }
    }
    let declaredNames = declaredLocals.union(declaredMembers.map { String($0.split(separator: ".").last ?? "") })

    var usage: [String: [String: Int]] = [:]
    func add(_ category: String, _ name: String, _ count: Int) {
        usage[category, default: [:]][name, default: 0] += count
    }

    /// "MyCell.textLabel" -> "UITableViewCell.textLabel": the first UIKit type up the app's class
    /// hierarchy, unless the app itself declares the member on the way (including in extensions).
    func uiKitMember(_ key: String) -> String? {
        let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        var type = parts[0]
        for _ in 0..<32 {
            if declaredMembers.contains("\(type).\(parts[1])") { return nil }
            if Catalog.isUIKitType(type), !declaredTypes.contains(type) {
                return type.hasSuffix("Delegate") || type.hasSuffix("DataSource") ? nil : "\(type).\(parts[1])"
            }
            guard let superclass = superclasses[type] else { return nil }
            type = superclass
        }
        return nil
    }

    for file in files {
        for module in file.imports { add("import", module, 1) }
        let swiftUI = file.imports.contains("SwiftUI")
        for (name, count) in file.identifiers where !declaredTypes.contains(name) && !file.imports.contains(name) {
            let category =
                if swiftUI && Catalog.swiftUIViews.contains(name) { "swiftui.view" }
                else if swiftUI && Catalog.swiftUITypes.contains(name) { "swiftui.type" }
                else if Catalog.isUIKitType(name) { "uikit.type" }
                else if Catalog.isQuartzCoreType(name) { "quartzcore.type" }
                else { "other.type" }
            add(category, name, count)
        }
        if swiftUI {
            for (name, count) in file.calls {
                if Catalog.swiftUIModifiers.contains(name) {
                    add("swiftui.modifier", name, count)
                } else if !declaredNames.contains(name) {
                    add("other.call", name, count)
                }
            }
        }
        for (key, count) in file.typedMembers.merging(file.selfMembers, uniquingKeysWith: +).merging(file.overrides, uniquingKeysWith: +) {
            if let api = uiKitMember(key) { add("uikit.member", api, count) }
        }
        for (key, count) in file.implicitMembers {
            let member = String(key.split(separator: ".").last ?? "")
            if !declaredLocals.contains(member), !Catalog.swiftGlobals.contains(member), let api = uiKitMember(key) {
                add("uikit.member", api, count)
            }
        }
        for (name, count) in file.attributes { add("attribute", name, count) }
        for (name, count) in file.macros { add("macro", name, count) }
        for (name, count) in file.environmentKeys { add("swiftui.environment", name, count) }
        for (name, count) in file.objc { add("objc", name, count) }
        for (name, count) in file.sfSymbols { add("sfsymbol", name, count) }
        for name in file.entryPoints { add("entry", name, 1) }
    }
    return AppResult(
        id: id, ui: ui, swiftFiles: files.count, swiftLines: files.reduce(0) { $0 + $1.lines },
        inventory: inventory, usage: usage)
}
