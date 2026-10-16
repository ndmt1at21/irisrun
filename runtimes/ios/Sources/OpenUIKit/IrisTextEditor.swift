import Foundation
import IrisHost
import IrisRender

/// Iris: what UITextField and UITextView share to edit text: IrisHost's editing state (SwiftUI's
/// text fields edit with it too), the person's edits, which the control's delegate may refuse,
/// and the canvas that draws them.
@MainActor
final class IrisTextEditor {
    var state = TextEditingState(text: "")
    let canvas = TextCanvasView()
    let isMultiline: Bool
    /// Asks the control's delegate whether the person may replace a range of the text, in UTF-16
    /// code units, with a string.
    var shouldChange: (NSRange, String) -> Bool = { _, _ in true }
    /// After an edit of the person's changed the text, with the range it replaced and the new text.
    var didChange: (NSRange, String) -> Void = { _, _ in }
    /// After an edit moved only the selection or the marked text.
    var didChangeSelection: () -> Void = {}
    /// A secure text field starts over when the person edits it again.
    var replacesAllOnNextEdit = false

    init(isMultiline: Bool) {
        self.isMultiline = isMultiline
    }

    /// Applies an edit the person made, if the delegate lets it; false if it didn't or nothing changed.
    @discardableResult
    func edit(_ body: (inout TextEditingState) -> Void) -> Bool {
        var new = state
        body(&new)
        if replacesAllOnNextEdit, new.text != state.text {
            new = TextEditingState(text: "")
            body(&new)
        }
        guard new != state else { return false }
        guard new.text != state.text else {
            // Committing marked text as it is changes the text as UIKit counts changes.
            let markedChanged = new.marked != state.marked
            state = new
            markedChanged ? didChange(NSRange(location: new.cursor, length: 0), "") : didChangeSelection()
            return true
        }
        let (range, string) = Self.change(from: state, to: new)
        guard shouldChange(range, string) else { return false }
        replacesAllOnNextEdit = false
        state = new
        didChange(range, string)
        return true
    }

    /// An editing key other than Backspace and Return, which come through UIKeyInput.
    func press(_ code: String, command: Bool) {
        edit { _ = $0.press(code, command: command, multiline: isMultiline) }
    }

    /// The change from one state to the next as UIKit's delegates get it: the range of the old
    /// text it replaced and what replaced it. The range starts no later than the old selection
    /// or marked text, where edits happen, and keeps characters whole.
    static func change(from old: TextEditingState, to new: TextEditingState) -> (NSRange, String) {
        let a = Array(old.text.utf16)
        let b = Array(new.text.utf16)
        let limit = min(old.selection.lowerBound, old.marked?.lowerBound ?? .max, a.count, b.count)
        var prefix = 0
        while prefix < limit, a[prefix] == b[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] {
            suffix += 1
        }
        let start = old.boundary(atOrBefore: prefix)
        let end = old.boundary(atOrAfter: a.count - suffix)
        let replacement = String(decoding: b[start ..< b.count - (a.count - end)], as: UTF16.self)
        return (NSRange(location: start, length: end - start), replacement)
    }

    /// The word around an offset, for a double tap: letters and digits, or the one character there.
    func word(at offset: Int) -> Range<Int> {
        let text = state.text
        var words: [(range: Range<Int>, isWord: Bool)] = []
        var position = 0
        for character in text {
            let length = character.utf16.count
            let isWord = character.isLetter || character.isNumber
            if let last = words.last, last.isWord, isWord {
                words[words.count - 1].range = last.range.lowerBound ..< position + length
            } else {
                words.append((position ..< position + length, isWord))
            }
            position += length
        }
        return words.first { $0.range.contains(offset) }?.range ?? words.last?.range ?? 0 ..< 0
    }

    // MARK: UITextInput

    func offset(_ position: UITextPosition) -> Int {
        min(max((position as? IrisTextPosition)?.offset ?? 0, 0), state.length)
    }

    func range(_ range: UITextRange) -> Range<Int> {
        let (start, end) = (offset(range.start), offset(range.end))
        return min(start, end) ..< max(start, end)
    }

    func text(in range: UITextRange) -> String {
        let utf16 = Array(state.text.utf16)
        return String(decoding: utf16[self.range(range)], as: UTF16.self)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        let target = self.offset(position) + offset
        return (0 ... state.length).contains(target) ? IrisTextPosition(target) : nil
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        let (a, b) = (offset(position), offset(other))
        return a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
    }
}

/// Iris: draws the text of a text field or text view, as UIKit's text canvas does: the text,
/// the selection over it, the marked text underlined, and the caret, which blinks on a device.
/// Offsets are in UTF-16 code units of the text shown.
@MainActor
final class TextCanvasView: UIView {
    /// The text as it shows, laid out from `textOrigin` in lines up to `maxWidth` wide.
    var text: IrisText?
    var maxWidth = CGFloat.infinity
    var textOrigin = CGPoint.zero
    /// The height of a line, for the caret in empty text.
    var lineHeight: CGFloat = 0
    /// Nil shows no caret or selection.
    var selection: Range<Int>?
    var marked: Range<Int>?

    private let caret = CALayer()
    private var highlights: [CALayer] = []
    private var underlines: [CALayer] = []
    private var blink: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        caret.cornerRadius = 1
        caret.isHidden = true
        layer.addSublayer(caret)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// The text's size as it lays out.
    var textSize: CGSize {
        guard let text, !text.string.isEmpty else { return CGSize(width: 0, height: lineHeight) }
        let metrics = text.measure(maxWidth: maxWidth)
        return CGSize(width: CGFloat(metrics.width), height: CGFloat(metrics.height))
    }

    /// Draws the text and places the caret, the selection and the underlines, after a change.
    func update() {
        setNeedsDisplay()
        caret.backgroundColor = tintColor.cgColor
        let caretRect = selection.map { self.caretRect(at: $0.upperBound) }
        caret.frame = caretRect ?? .zero
        let selected = selection.flatMap { $0.isEmpty ? nil : rects(for: $0) } ?? []
        highlights = layers(highlights, for: selected, color: tintColor.withAlphaComponent(0.2))
        let marks = (marked.map { rects(for: $0) } ?? []).map { CGRect(x: $0.minX, y: $0.maxY - 1, width: max($0.width, 1), height: 1) }
        underlines = layers(underlines, for: marks, color: .label)
        restartBlink()
    }

    override func draw(_ rect: CGRect) {
        guard let text, !text.string.isEmpty else {
            layer.irisDrawing = nil
            return
        }
        var size = textSize
        // One line keeps to one line, however wide.
        size.width = maxWidth.isFinite ? maxWidth : ceil(size.width) + 1
        layer.irisDrawing = IrisDrawing(content: .text(text), frame: CGRect(origin: textOrigin, size: size))
    }

    /// The caret before the character at an offset, in the canvas's coordinates.
    func caretRect(at offset: Int) -> CGRect {
        guard let text, !text.string.isEmpty else {
            let fraction: CGFloat = switch text?.paragraph.alignment {
            case .center?: 0.5
            case .trailing?: 1
            default: 0
            }
            let x = maxWidth.isFinite ? maxWidth * fraction : 0
            return CGRect(x: textOrigin.x + x - 1, y: textOrigin.y, width: 2, height: lineHeight)
        }
        let string = text.string
        let index = String.Index(utf16Offset: min(max(offset, 0), string.utf16.count), in: string)
        let caret = irisScene.caret(in: string, runs: text.runs, paragraph: text.paragraph, maxWidth: Float(maxWidth), at: index)
        return CGRect(x: textOrigin.x + CGFloat(caret.x) - 1, y: textOrigin.y + CGFloat(caret.y), width: 2, height: CGFloat(caret.height))
    }

    /// The character boundary nearest to a point in the canvas's coordinates.
    func offset(at point: CGPoint) -> Int {
        guard let text, !text.string.isEmpty else { return 0 }
        let string = text.string
        let index = irisScene.index(
            in: string, runs: text.runs, paragraph: text.paragraph, maxWidth: Float(maxWidth),
            x: Float(point.x - textOrigin.x), y: Float(point.y - textOrigin.y)
        )
        return string.utf16.distance(from: string.startIndex, to: index)
    }

    /// The rectangles a range covers, a line at a time.
    func rects(for range: Range<Int>) -> [CGRect] {
        let start = caretRect(at: range.lowerBound).offsetBy(dx: 1, dy: 0)
        let end = caretRect(at: range.upperBound).offsetBy(dx: 1, dy: 0)
        if abs(start.minY - end.minY) < 1 {
            return [CGRect(x: start.minX, y: start.minY, width: end.minX - start.minX, height: start.height)]
        }
        let right = textOrigin.x + (maxWidth.isFinite ? maxWidth : textSize.width)
        var rects = [CGRect(x: start.minX, y: start.minY, width: right - start.minX, height: start.height)]
        if end.minY > start.maxY + 0.5 {
            rects.append(CGRect(x: textOrigin.x, y: start.maxY, width: right - textOrigin.x, height: end.minY - start.maxY))
        }
        rects.append(CGRect(x: textOrigin.x, y: end.minY, width: end.minX - textOrigin.x, height: end.height))
        return rects
    }

    private func layers(_ layers: [CALayer], for rects: [CGRect], color: UIColor) -> [CALayer] {
        var layers = layers
        while layers.count > rects.count {
            layers.removeLast().removeFromSuperlayer()
        }
        while layers.count < rects.count {
            let added = CALayer()
            layer.insertSublayer(added, below: caret)
            layers.append(added)
        }
        for (layer, rect) in zip(layers, rects) {
            layer.frame = rect
            layer.backgroundColor = color.cgColor
        }
        return layers
    }

    /// The caret shows while there is no selection, steady after each change; on a device it
    /// then blinks every half second, as on iOS.
    private func restartBlink() {
        blink?.invalidate()
        blink = nil
        caret.isHidden = selection?.isEmpty != true
        guard !caret.isHidden, irisAnimates, window != nil else { return }
        // Foundation on Linux fires Timer(timeInterval:repeats:block:) at once; this one waits.
        let timer = Timer(fire: Date(timeIntervalSinceNow: 0.5), interval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.caret.isHidden.toggle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blink = timer
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            blink?.invalidate()
            blink = nil
        }
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        caret.backgroundColor = tintColor.cgColor
    }
}
