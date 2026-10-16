import Foundation

/// What UIKit makes by name or by class: the classes that adopt the delegate protocols it
/// instantiates, and subclasses of UIApplication.
private let madeByUIKit: Set<Substring> = ["UIApplicationDelegate", "UISceneDelegate", "UIWindowSceneDelegate", "UIApplication"]

/// Rewrites what a UIKit app needs on Linux, keeping every line of the app where it was, so
/// that compile errors and stack traces still point at its code:
///
/// - `@UIApplicationMain`, which the compiler implements with Objective-C, becomes `@main`;
///   OpenUIKit's `UIApplicationDelegate` has a `main()`, as UIKit's has.
/// - `import UIKit.UIGestureRecognizerSubclass` and other submodules become `import UIKit`.
/// - Top-level classes that UIKit makes by name or by class get an `_IrisInstantiable` factory
///   at the end of their file: Swift can't call the `init()` of a class known only at run time
///   unless it is `required`. `made` has the classes given one already, by any file.
// ponytail: a scan of top-level lines, enough for delegates as Xcode's templates declare them;
// ObjCRewriter's syntax tree can find nested ones and conformances that subclasses inherit.
func adaptingForUIKit(_ source: String, made: inout Set<String>) -> String {
    var lines = source.components(separatedBy: "\n")
    var factories: [String] = []
    for index in lines.indices {
        let line = lines[index]
        let code = line.drop(while: { $0 == " " || $0 == "\t" })
        if code.hasPrefix("@UIApplicationMain") {
            lines[index] = line.replacingOccurrences(of: "@UIApplicationMain", with: "@main")
        }
        // OpenUIKit is one Swift module, without UIKit's Clang submodules.
        if code.hasPrefix("import UIKit.") {
            lines[index] = line.replacingOccurrences(of: #"import UIKit\.\w+"#, with: "import UIKit", options: .regularExpression)
        }
        guard let (name, inheritance, isPublic) = declaration(at: index, in: lines),
              inheritance.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }).contains(where: madeByUIKit.contains),
              made.insert(name).inserted
        else { continue }
        let access = isPublic ? "public " : ""
        // UIKit makes these first; storyboards' actions then find the method tables ready.
        factories.append("extension \(name): UIKit._IrisInstantiable { \(access)static func _irisMake() -> AnyObject { _ = _irisMethodsRegistered; return \(name)() } }")
    }
    guard !factories.isEmpty else { return lines.joined(separator: "\n") }
    return (lines + ["import UIKit"] + factories).joined(separator: "\n") + "\n"
}

/// The name, inheritance clause and whether it is public of a top-level class or extension that
/// starts on line `index`.
private func declaration(at index: Int, in lines: [String]) -> (String, Substring, Bool)? {
    var words = lines[index].split(separator: " ", omittingEmptySubsequences: true)
    guard lines[index].first?.isWhitespace == false else { return nil }
    let modifiers: Set<Substring> = ["public", "open", "internal", "fileprivate", "private", "final"]
    var isPublic = false
    while let first = words.first, first.hasPrefix("@") || modifiers.contains(first) {
        isPublic = isPublic || first == "public" || first == "open"
        words.removeFirst()
    }
    guard words.count >= 2, words[0] == "class" || words[0] == "extension" else { return nil }
    // The name ends at the colon of the inheritance clause; generic classes are left out.
    let rest = words.dropFirst().joined(separator: " ")
    guard let colon = rest.firstIndex(of: ":") else { return nil }
    let name = rest[..<colon].trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
    // The clause can go on over a few lines, up to the opening brace.
    var clause = Substring(rest[rest.index(after: colon)...])
    var next = index + 1
    while !clause.contains("{"), next < min(index + 5, lines.count) {
        clause += " " + lines[next]
        next += 1
    }
    return (name, clause.prefix { $0 != "{" }, isPublic)
}
