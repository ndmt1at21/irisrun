import Foundation

/// Text being edited, its selection, and the text an input method is composing in it (marked
/// text), as the text controls of both UI frameworks keep it. The marked text is part of the
/// text, as in UIKit's UITextInput, until the input method commits it or editing moves on;
/// SwiftUI's bindings get the text without it (`committedText`). Offsets count UTF-16 code
/// units, as input methods and the Device Protocol do, and edits never split a character.
public struct TextEditingState: Equatable, Sendable {
    public var text: String
    /// The selected range; an empty one is the caret.
    public var selection: Range<Int>
    /// Where the marked text is in `text`, while the input method composes.
    public var marked: Range<Int>?

    /// `text` with the caret at its end, or with `selection`.
    public init(text: String, selection: Range<Int>? = nil) {
        self.text = text
        let length = text.utf16.count
        let selection = selection ?? length ..< length
        self.selection = min(max(selection.lowerBound, 0), length) ..< min(max(selection.upperBound, 0), length)
    }

    public var length: Int {
        text.utf16.count
    }

    /// Where the caret is: the end of the selection.
    public var cursor: Int {
        selection.upperBound
    }

    /// The text without the marked text.
    public var committedText: String {
        guard let marked else { return text }
        let utf16 = Array(text.utf16)
        return String(decoding: utf16[..<marked.lowerBound] + utf16[marked.upperBound...], as: UTF16.self)
    }

    // MARK: Input method

    /// Inserts `string` in place of the marked text, or of the selection, with the caret after it.
    public mutating func commit(_ string: String) {
        replace(marked ?? selection, with: string)
        marked = nil
    }

    /// Sets the marked text in place of the old one, or of the selection, with the caret at its
    /// end or at `selectedRange` in it; an empty string removes it.
    public mutating func compose(_ string: String, selectedRange: Range<Int>? = nil) {
        let range = marked ?? selection
        replace(range, with: string)
        let start = range.lowerBound
        marked = string.isEmpty ? nil : start ..< start + string.utf16.count
        if let selectedRange, !string.isEmpty {
            let count = string.utf16.count
            selection = start + min(max(selectedRange.lowerBound, 0), count) ..< start + min(max(selectedRange.upperBound, 0), count)
        }
    }

    /// Keeps the marked text, as typed text.
    public mutating func unmark() {
        marked = nil
    }

    /// Deletes code units before and after the marked text, or else the selection, as an input
    /// method's correction does. A range that ends inside a character takes the whole character.
    public mutating func deleteSurrounding(before: Int, after: Int) {
        let around = marked ?? selection
        let end = boundary(atOrAfter: around.upperBound + max(after, 0))
        if end > around.upperBound {
            remove(around.upperBound ..< end)
        }
        let start = boundary(atOrBefore: around.lowerBound - max(before, 0))
        if start < around.lowerBound {
            remove(start ..< around.lowerBound)
        }
    }

    // MARK: Editing

    /// Replaces a range with `string`, putting the caret after it. Marked text the range
    /// touches stops being marked; marked text elsewhere moves with the text around it.
    public mutating func replace(_ range: Range<Int>, with string: String) {
        let start = boundary(atOrBefore: range.lowerBound)
        let range = start ..< max(start, boundary(atOrAfter: range.upperBound))
        let utf16 = Array(text.utf16)
        text = String(decoding: utf16[..<range.lowerBound] + Array(string.utf16) + utf16[range.upperBound...], as: UTF16.self)
        let caret = range.lowerBound + string.utf16.count
        selection = caret ..< caret
        if let marked, marked.upperBound > range.lowerBound {
            let delta = string.utf16.count - range.count
            self.marked = marked.lowerBound >= range.upperBound ? marked.lowerBound + delta ..< marked.upperBound + delta : nil
        }
    }

    /// Backspace: deletes the selection, or the character before the caret.
    public mutating func deleteBackward() {
        marked = nil
        guard selection.isEmpty else { return replace(selection, with: "") }
        guard cursor > 0 else { return }
        replace(boundary(atOrBefore: cursor - 1) ..< cursor, with: "")
    }

    /// Delete: deletes the selection, or the character after the caret.
    public mutating func deleteForward() {
        marked = nil
        guard selection.isEmpty else { return replace(selection, with: "") }
        guard cursor < length else { return }
        replace(cursor ..< boundary(atOrAfter: cursor + 1), with: "")
    }

    /// Runs an editing key from a hardware keyboard, by W3C `KeyboardEvent.code`: Backspace and
    /// Delete, the arrows, Home and End, Command with them for the ends of lines and of the
    /// text, Command-A to select all, and Return in `multiline` text. Marked text left by the
    /// input method is kept first. False for keys that don't edit text, Return in one line
    /// included: submitting is the control's to do.
    public mutating func press(_ code: String, command: Bool, multiline: Bool) -> Bool {
        let keys = ["Backspace", "Delete", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"]
        guard keys.contains(code) || multiline && (code == "Enter" || code == "NumpadEnter") || command && code == "KeyA" else {
            return false
        }
        marked = nil
        switch code {
        case "Backspace" where command:
            let start = offset(lineStart(index(cursor)))
            replace(selection.isEmpty ? start ..< cursor : selection, with: "")
        case "Backspace": deleteBackward()
        case "Delete": deleteForward()
        case "ArrowLeft":
            if command {
                moveToStart(wholeText: false)
            } else {
                caret(at: selection.isEmpty ? boundary(atOrBefore: cursor - 1) : selection.lowerBound)
            }
        case "ArrowRight":
            if command {
                moveToEnd(wholeText: false)
            } else {
                caret(at: selection.isEmpty ? boundary(atOrAfter: cursor + 1) : selection.upperBound)
            }
        case "ArrowUp": multiline && !command ? moveLine(by: -1) : moveToStart(wholeText: true)
        case "ArrowDown": multiline && !command ? moveLine(by: 1) : moveToEnd(wholeText: true)
        case "Home": moveToStart(wholeText: command)
        case "End": moveToEnd(wholeText: command)
        case "KeyA": selection = 0 ..< length
        default: commit("\n")
        }
        return true
    }

    // MARK: Caret

    public mutating func caret(at offset: Int) {
        let offset = min(max(offset, 0), length)
        selection = offset ..< offset
    }

    /// To the start of the line, or of the text with `wholeText`.
    public mutating func moveToStart(wholeText: Bool) {
        caret(at: wholeText ? 0 : offset(lineStart(index(cursor))))
    }

    public mutating func moveToEnd(wholeText: Bool) {
        caret(at: wholeText ? length : offset(lineEnd(index(cursor))))
    }

    /// To the same character of the line above or below, or the end of a shorter line.
    public mutating func moveLine(by step: Int) {
        let caret = index(cursor)
        let start = lineStart(caret)
        let column = text.distance(from: start, to: caret)
        let target: String.Index
        if step < 0 {
            guard start > text.startIndex else { return moveToStart(wholeText: true) }
            target = lineStart(text.index(before: start))
        } else {
            let end = lineEnd(caret)
            guard end < text.endIndex else { return moveToEnd(wholeText: true) }
            target = text.index(after: end)
        }
        let lineLength = text.distance(from: target, to: lineEnd(target))
        self.caret(at: offset(text.index(target, offsetBy: min(column, lineLength))))
    }

    // MARK: Offsets

    /// The character boundary at or before a UTF-16 offset.
    public func index(_ offset: Int) -> String.Index {
        let target = text.utf16.index(text.startIndex, offsetBy: min(max(offset, 0), length))
        var index = text.startIndex
        while index < target {
            let next = text.index(after: index)
            guard next <= target else { break }
            index = next
        }
        return index
    }

    public func offset(_ index: String.Index) -> Int {
        text.utf16.distance(from: text.startIndex, to: index)
    }

    public func boundary(atOrBefore offset: Int) -> Int {
        self.offset(index(offset))
    }

    public func boundary(atOrAfter offset: Int) -> Int {
        let before = boundary(atOrBefore: offset)
        guard before < min(max(offset, 0), length) else { return before }
        return self.offset(text.index(after: index(before)))
    }

    /// Removes a range, moving the selection and the marked text with the text around them.
    private mutating func remove(_ range: Range<Int>) {
        let utf16 = Array(text.utf16)
        text = String(decoding: utf16[..<range.lowerBound] + utf16[range.upperBound...], as: UTF16.self)
        func shift(_ offset: Int) -> Int {
            offset <= range.lowerBound ? offset : max(offset - range.count, range.lowerBound)
        }
        selection = shift(selection.lowerBound) ..< shift(selection.upperBound)
        if let marked {
            let moved = shift(marked.lowerBound) ..< shift(marked.upperBound)
            self.marked = moved.isEmpty ? nil : moved
        }
    }

    private func lineStart(_ index: String.Index) -> String.Index {
        text[..<index].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
    }

    private func lineEnd(_ index: String.Index) -> String.Index {
        text[index...].firstIndex(of: "\n") ?? text.endIndex
    }
}
