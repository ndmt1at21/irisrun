import Foundation
@testable import IrisBuild
import Testing

@Test func namesSelectorsAsSwiftDoes() {
    #expect(objcSelector("tapped", []) == "tapped")
    #expect(objcSelector("tapped", [nil]) == "tapped:")
    #expect(objcSelector("tapped", ["sender"]) == "tappedWithSender:")
    #expect(objcSelector("do", ["with", "and"]) == "doWith:and:")
    #expect(objcSelector("insert", [nil, "at"]) == "insert:at:")
    #expect(objcSelector("move", ["to"]) == "moveTo:")
    #expect(objcSelector("scrollTo", ["item"]) == "scrollToItem:")
    #expect(objcSelector("init", ["name"]) == "initWithName:")
    #expect(objcSetter("title") == "setTitle:")
}

/// The fixture app as irisrun-ios-build rewrites it, which Tests/ObjCRewriteTests builds and runs.
/// After a change, write it there with the tool, which takes the folder for an app:
///
///     swift run irisrun-ios-build Tests/IrisBuildTests/Fixtures --out <dir> --openswiftui - --runtime - --render-lib -
///     cp <dir>/Sources/Fixtures/{ObjCApp.swift,_IrisMethodTables.swift} Tests/ObjCRewriteTests
@Test func rewritesObjectiveCOnTheSameLines() throws {
    let tests = URL(filePath: #filePath).deletingLastPathComponent()
    let input = try String(contentsOf: tests.appending(path: "Fixtures/ObjCApp.swift"), encoding: .utf8)
    let rewriter = ObjCRewriter(files: [("ObjCApp.swift", input)])
    let (files, registration) = rewriter.rewrite()
    let built = tests.appending(path: "../ObjCRewriteTests")
    #expect(files[0] == (try String(contentsOf: built.appending(path: "ObjCApp.swift"), encoding: .utf8)))
    #expect(registration == (try String(contentsOf: built.appending(path: "_IrisMethodTables.swift"), encoding: .utf8)))

    // Lines without Objective-C come out as they were, on their numbers; the rest changes in place.
    let lines = files[0].components(separatedBy: "\n")
    let markers = ["@", "#", "?.", "Selector", "removeObserver", "dynamic", "didSet", "protocol", "resignFirstResponder", "),"]
    for (index, line) in input.components(separatedBy: "\n").dropLast().enumerated() where !markers.contains(where: line.contains) {
        #expect(lines[index] == line, "line \(index + 1)")
    }
    #expect(lines[26] == "     func move(to point: CGPoint) {")
    #expect(lines[32 ... 34] == [#"            _irisSelector("increment"),"#, #"            _irisSelector("reset:"),"#, #"            _irisSelector("addAmount:times:"),"#])
    // A selector over three lines takes the first; the line breaks follow it.
    #expect(lines[38 ... 40] == [#"            _irisSelector("resignFirstResponder")"#, "", ","])
    #expect(lines[118] == #"        _irisOptional(delegate, _irisSelector("picker:didPick:"))?.picker(self, didPick: .systemRed)"#)
    #expect(lines[175] == #"let titleKey = "title""#)
    #expect(rewriter.counts["#selector named from declarations"] == 9)
    #expect(rewriter.counts["#selector named by syntax"] == 1, "UIResponder.resignFirstResponder")
    #expect(rewriter.counts["left over: members of generic, local or nested private classes"] == 1, "Box<Value>.open")
}

@Test func addsAttributesThroughIrisObjC() {
    let source = """
    let text = NSMutableAttributedString(string: "Hi")
    text.addAttribute(.font, value: font, range: NSRange(location: 0, length: 2))
    text.addAttributes([.foregroundColor: color], range: range)
    store.addAttribute(name)
    """
    let (files, _) = ObjCRewriter(files: [("Text.swift", source)]).rewrite()
    #expect(files[0].hasPrefix("""
    let text = NSMutableAttributedString(string: "Hi")
    text._irisAddAttribute(.font, value: font, range: NSRange(location: 0, length: 2))
    text._irisAddAttributes([.foregroundColor: color], range: range)
    store.addAttribute(name)
    """))
}

@Test func keepsConditionsAndClassBoundsOfObjectiveCDeclarations() {
    let source = """
    @objc public protocol Feed: NSObjectProtocol {
        @objc optional var title: String { get }
    }
    #if os(iOS)
    class Reader: NSObject {
        #if DEBUG
        @objc func debug() {}
        #else
        @objc func release() {}
        #endif
    }
    #endif
    """
    let (files, _) = ObjCRewriter(files: [("Feed.swift", source)]).rewrite()
    #expect(files[0].hasPrefix("""
     public protocol Feed: NSObjectProtocol, AnyObject {
          var title: String { get }
    }
    """))
    #expect(files[0].hasSuffix("""
    #endif
    extension Feed { public var title: String { get { _IrisMethods.send(_irisSelector("title"), to: self, with: []) as! String } } }
    #if os(iOS)
    #if DEBUG
    extension Reader { static func _irisMethods_Feed_swift_0() { _IrisMethods.register(Reader.self, [
        "debug": .init { (o: Reader) in { o.debug() } },
    ]) } }
    #endif
    #endif
    #if os(iOS)
    #if DEBUG
    #else
    extension Reader { static func _irisMethods_Feed_swift_1() { _IrisMethods.register(Reader.self, [
        "release": .init { (o: Reader) in { o.release() } },
    ]) } }
    #endif
    #endif
    func _irisRegisterMethods_Feed_swift() {
    #if os(iOS)
    #if DEBUG
        _irisRegister { Reader._irisMethods_Feed_swift_0() }
    #endif
    #endif
    #if os(iOS)
    #if DEBUG
    #else
        _irisRegister { Reader._irisMethods_Feed_swift_1() }
    #endif
    #endif
    }

    """))
}
