/// Removes previews from Swift source: `#Preview` blocks and types that
/// conform to `PreviewProvider`, with attributes on the lines just above them.
///
/// Previews are not part of the app and often use APIs OpenKit lacks. A block
/// runs from its first line to the line where its braces balance. Braces in
/// string literals on one line and after `//` don't count; multi-line strings
/// and block comments are not understood, which is enough for previews as
/// Xcode writes them.
public func strippingPreviews(_ source: String) -> String {
    var out: [Substring] = []
    var depth = 0
    var opened = false
    var inPreview = false
    for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
        if !inPreview {
            guard startsPreview(line) else {
                out.append(line)
                continue
            }
            while let last = out.last, isAttribute(last) { out.removeLast() }
            (inPreview, depth, opened) = (true, 0, false)
        }
        let code = withoutStringsAndComment(line)
        depth += code.count { $0 == "{" } - code.count { $0 == "}" }
        opened = opened || code.contains("{")
        inPreview = !(opened && depth <= 0)
    }
    return out.joined(separator: "\n")
}

private func startsPreview(_ line: Substring) -> Bool {
    let trimmed = line.drop { $0 == " " || $0 == "\t" }
    if trimmed.hasPrefix("#Preview") { return true }
    // struct Foo_Previews: PreviewProvider {, with any modifiers before it.
    let words = trimmed.prefix { $0 != "{" }.split { !$0.isLetter && !$0.isNumber && $0 != "_" }
    guard let kind = words.firstIndex(where: { ["struct", "class", "enum"].contains($0) }) else { return false }
    return words[..<kind].allSatisfy { modifiers.contains($0) } && words[(kind + 1)...].contains("PreviewProvider")
}

private let modifiers: Set<Substring> = ["public", "internal", "fileprivate", "private", "final"]

/// A line with nothing but an attribute, such as `@available(iOS 17, *)`.
private func isAttribute(_ line: Substring) -> Bool {
    let trimmed = line.drop { $0 == " " || $0 == "\t" }
    return trimmed.hasPrefix("@") && !trimmed.contains(" ") || trimmed.hasPrefix("@available(")
}

private func withoutStringsAndComment(_ line: Substring) -> String {
    var code = ""
    var inString = false
    var escaped = false
    var previous: Character = " "
    for character in line {
        if inString {
            if escaped { escaped = false } else if character == "\\" { escaped = true } else if character == "\"" { inString = false }
        } else if character == "\"" {
            inString = true
        } else if character == "/", previous == "/" {
            code.removeLast()
            break
        } else {
            code.append(character)
        }
        previous = character
    }
    return code
}
