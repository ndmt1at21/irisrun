import Foundation
import IrisHost

/// A scrolling view of lines of text, edited as a text field is, Return making a new line. The
/// text lays out in its text container, 8 points from the top and bottom and 5 from the sides
/// by default, and the view scrolls to keep the caret in view.
// ponytail: no TextKit (layoutManager, textStorage, exclusion paths), link taps, data detectors,
// find, copy and paste or edit menu; selectable text that isn't editable can't be selected.
@preconcurrency @MainActor
open class UITextView: UIScrollView, UITextInput, IrisTextEditing {
    let editor = IrisTextEditor(isMultiline: true)
    /// Scroll to the caret at the next layout, after an edit.
    private var revealsCaret = false

    public init(frame: CGRect, textContainer: NSTextContainer?) {
        self.textContainer = textContainer ?? NSTextContainer(size: .zero)
        super.init(frame: frame)
        setUp()
    }

    public override convenience init(frame: CGRect) {
        self.init(frame: frame, textContainer: nil)
    }

    public required init?(coder: NSCoder) {
        textContainer = NSTextContainer(size: .zero)
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = .systemBackground
        addSubview(editor.canvas)
        editor.shouldChange = { [unowned self] range, text in
            textViewDelegate?.textView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
        editor.didChange = { [unowned self] range, text in
            if let storage {
                let attributed = NSMutableAttributedString(attributedString: storage)
                attributed.replaceCharacters(in: range, with: text)
                self.storage = attributed
            }
            revealsCaret = true
            setNeedsLayout()
            textViewDelegate?.textViewDidChange(self)
            NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)
        }
        editor.didChangeSelection = { [unowned self] in
            revealsCaret = true
            setNeedsLayout()
            textViewDelegate?.textViewDidChangeSelection(self)
        }
    }

    private var textViewDelegate: (any UITextViewDelegate)? {
        delegate as? any UITextViewDelegate
    }

    // MARK: Text

    /// Attributes the app gave the text, which edits keep around their change.
    private var storage: NSAttributedString?

    /// Setting it puts the caret at the end and tells the delegate nothing.
    open var text: String! {
        get { editor.state.text }
        set {
            storage = nil
            editor.state = TextEditingState(text: newValue ?? "")
            setNeedsLayout()
        }
    }

    open var attributedText: NSAttributedString! {
        get { storage ?? NSAttributedString(string: editor.state.text, attributes: [.font: shownFont, .foregroundColor: textColor ?? .label]) }
        set {
            text = newValue?.string
            storage = newValue.map { NSAttributedString(attributedString: $0) }
        }
    }

    /// Nil draws text in the 12-point system font, as UIKit does.
    open var font: UIFont? {
        didSet { setNeedsLayout() }
    }

    open var textColor: UIColor? {
        didSet { setNeedsLayout() }
    }

    open var textAlignment = NSTextAlignment.natural {
        didSet { setNeedsLayout() }
    }

    private var shownFont: UIFont {
        font ?? .systemFont(ofSize: 12)
    }

    open var selectedRange: NSRange {
        get { NSRange(location: editor.state.selection.lowerBound, length: editor.state.selection.count) }
        set {
            let start = min(max(newValue.location, 0), editor.state.length)
            editor.state.selection = start ..< min(start + max(newValue.length, 0), editor.state.length)
            editor.didChangeSelection()
        }
    }

    open var isEditable = true {
        didSet {
            if !isEditable, isFirstResponder {
                resignFirstResponder()
            }
        }
    }

    open var isSelectable = true
    open var dataDetectorTypes: UIDataDetectorTypes = []
    open var allowsEditingTextAttributes = false
    open var typingAttributes: [NSAttributedString.Key: Any] = [:]
    open var linkTextAttributes: [NSAttributedString.Key: Any]! = [:]
    open var clearsOnInsertion = false

    /// Space between the view's edges and its text container.
    open var textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0) {
        didSet { setNeedsLayout() }
    }

    open private(set) var textContainer: NSTextContainer

    override open var inputView: UIView? {
        get { ownInputView }
        set { ownInputView = newValue }
    }

    override open var inputAccessoryView: UIView? {
        get { ownInputAccessoryView }
        set { ownInputAccessoryView = newValue }
    }

    private var ownInputView: UIView?
    private var ownInputAccessoryView: UIView?

    // MARK: Text input traits

    open var autocapitalizationType = UITextAutocapitalizationType.sentences
    open var autocorrectionType = UITextAutocorrectionType.default
    open var spellCheckingType = UITextSpellCheckingType.default
    open var smartQuotesType = UITextSmartQuotesType.default
    open var smartDashesType = UITextSmartDashesType.default
    open var smartInsertDeleteType = UITextSmartInsertDeleteType.default
    open var keyboardType = UIKeyboardType.default
    open var keyboardAppearance = UIKeyboardAppearance.default
    open var returnKeyType = UIReturnKeyType.default
    open var enablesReturnKeyAutomatically = false
    open var isSecureTextEntry = false
    open var textContentType: UITextContentType!

    // MARK: Editing

    override open var canBecomeFirstResponder: Bool {
        isEditable
    }

    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !isFirstResponder else { return true }
        guard canBecomeFirstResponder, window != nil, textViewDelegate?.textViewShouldBeginEditing(self) ?? true,
              super.becomeFirstResponder() else { return false }
        revealsCaret = true
        setNeedsLayout()
        textViewDelegate?.textViewDidBeginEditing(self)
        NotificationCenter.default.post(name: UITextView.textDidBeginEditingNotification, object: self)
        return true
    }

    @discardableResult
    override open func resignFirstResponder() -> Bool {
        guard isFirstResponder else { return super.resignFirstResponder() }
        guard UIResponder.isForcingResign || textViewDelegate?.textViewShouldEndEditing(self) ?? true,
              super.resignFirstResponder() else { return false }
        editor.state.unmark()
        setNeedsLayout()
        textViewDelegate?.textViewDidEndEditing(self)
        NotificationCenter.default.post(name: UITextView.textDidEndEditingNotification, object: self)
        return true
    }

    /// Taps edit: one puts the caret at the nearest character boundary, two select a word.
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditable else { return super.touchesBegan(touches, with: event) }
    }

    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditable else { return super.touchesMoved(touches, with: event) }
    }

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditable, let touch = touches.first else { return super.touchesEnded(touches, with: event) }
        let offset = editor.state.boundary(atOrBefore: editor.canvas.offset(at: touch.location(in: editor.canvas)))
        guard isFirstResponder || becomeFirstResponder() else { return }
        editor.edit { state in
            state.unmark()
            state.selection = touch.tapCount == 2 ? editor.word(at: offset) : offset ..< offset
        }
    }

    override open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEditable else { return super.touchesCancelled(touches, with: event) }
    }

    open func scrollRangeToVisible(_ range: NSRange) {
        layoutIfNeeded()
        let start = editor.canvas.caretRect(at: range.location)
        let end = editor.canvas.caretRect(at: range.location + range.length)
        scrollRectToVisible(editor.canvas.convert(start.union(end), to: self), animated: false)
    }

    // MARK: UIKeyInput

    open var hasText: Bool {
        !editor.state.text.isEmpty
    }

    /// Typed text, in place of the marked text or the selection; Return makes a new line.
    open func insertText(_ text: String) {
        editor.edit { state in
            if clearsOnInsertion {
                state.selection = 0 ..< state.length
            }
            state.commit(text)
        }
    }

    open func deleteBackward() {
        editor.edit { $0.deleteBackward() }
    }

    // MARK: UITextInput

    open func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        editor.edit { $0.compose(markedText ?? "", selectedRange: selectedRange.location ..< selectedRange.location + selectedRange.length) }
    }

    open func unmarkText() {
        editor.edit { $0.unmark() }
    }

    open var markedTextRange: UITextRange? {
        editor.state.marked.map(IrisTextRange.init)
    }

    open var markedTextStyle: [NSAttributedString.Key: Any]?

    open var selectedTextRange: UITextRange? {
        get { IrisTextRange(editor.state.selection) }
        set {
            guard let newValue else { return }
            editor.state.selection = editor.range(newValue)
            editor.didChangeSelection()
        }
    }

    open func text(in range: UITextRange) -> String? {
        editor.text(in: range)
    }

    open func replace(_ range: UITextRange, withText text: String) {
        let range = editor.range(range)
        editor.edit { $0.replace(range, with: text) }
    }

    open var beginningOfDocument: UITextPosition {
        IrisTextPosition(0)
    }

    open var endOfDocument: UITextPosition {
        IrisTextPosition(editor.state.length)
    }

    open func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        let (a, b) = (editor.offset(fromPosition), editor.offset(toPosition))
        return IrisTextRange(min(a, b) ..< max(a, b))
    }

    open func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        editor.position(from: position, offset: offset)
    }

    open func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        editor.compare(position, to: other)
    }

    open func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        editor.offset(toPosition) - editor.offset(from)
    }

    open func caretRect(for position: UITextPosition) -> CGRect {
        layoutIfNeeded()
        return editor.canvas.convert(editor.canvas.caretRect(at: editor.offset(position)), to: self)
    }

    open func firstRect(for range: UITextRange) -> CGRect {
        selectionRects(for: range).first?.rect ?? .zero
    }

    open func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        layoutIfNeeded()
        let rects = editor.canvas.rects(for: editor.range(range))
        return rects.enumerated().map { index, rect in
            IrisSelectionRect(editor.canvas.convert(rect, to: self), containsStart: index == 0, containsEnd: index == rects.count - 1)
        }
    }

    open func closestPosition(to point: CGPoint) -> UITextPosition? {
        layoutIfNeeded()
        return IrisTextPosition(editor.state.boundary(atOrBefore: editor.canvas.offset(at: convert(point, to: editor.canvas))))
    }

    // MARK: Layout

    override open func layoutSubviews() {
        super.layoutSubviews()
        let inset = textContainerInset
        let padding = textContainer.lineFragmentPadding
        let canvas = editor.canvas
        var text = IrisText(storage ?? NSAttributedString(string: editor.state.text), font: shownFont, color: textColor ?? .label, alignment: textAlignment)
        text.paragraph.maxLines = UInt32(max(textContainer.maximumNumberOfLines, 0))
        canvas.lineHeight = shownFont.lineHeight
        canvas.maxWidth = max(bounds.width - inset.left - inset.right - 2 * padding, 1)
        canvas.text = text
        canvas.textOrigin = .zero
        // The caret's line counts, as an empty one after a last line break.
        let height = max(canvas.textSize.height, canvas.caretRect(at: editor.state.length).maxY, shownFont.lineHeight)
        canvas.frame = CGRect(x: inset.left + padding, y: inset.top, width: canvas.maxWidth, height: height)
        let size = CGSize(width: bounds.width, height: inset.top + height + inset.bottom)
        if contentSize != size {
            contentSize = size
        }
        let editing = isFirstResponder
        canvas.selection = editing ? editor.state.selection : nil
        canvas.marked = editing ? editor.state.marked : nil
        canvas.update()
        if editing, revealsCaret, isScrollEnabled {
            revealsCaret = false
            let caret = canvas.caretRect(at: editor.state.cursor)
            scrollRectToVisible(canvas.convert(caret, to: self).insetBy(dx: 0, dy: -inset.bottom / 2), animated: false)
        }
    }

    /// Without scrolling, a text view is as tall as its text.
    override open var intrinsicContentSize: CGSize {
        guard !isScrollEnabled else { return super.intrinsicContentSize }
        return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(bounds.size).height)
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        let inset = textContainerInset
        let padding = textContainer.lineFragmentPadding
        let text = IrisText(storage ?? NSAttributedString(string: editor.state.text), font: shownFont, color: textColor ?? .label, alignment: textAlignment)
        let width = max(size.width - inset.left - inset.right - 2 * padding, 1)
        let height = editor.state.text.isEmpty ? shownFont.lineHeight : CGFloat(text.measure(maxWidth: width).height)
        return CGSize(width: size.width, height: ceil(inset.top + height + inset.bottom))
    }

    /// The text, as VoiceOver reads it.
    override open var accessibilityValue: String? {
        get { super.accessibilityValue ?? editor.state.text }
        set { super.accessibilityValue = newValue }
    }
}

extension UITextView {
    public static let textDidBeginEditingNotification = Notification.Name("UITextViewTextDidBeginEditingNotification")
    public static let textDidChangeNotification = Notification.Name("UITextViewTextDidChangeNotification")
    public static let textDidEndEditingNotification = Notification.Name("UITextViewTextDidEndEditingNotification")
}

/// What a text view asks and tells as the person edits, and as it scrolls. Every method is
/// optional. A text view's `delegate` is its scroll view's, which this protocol extends.
@preconcurrency @MainActor
public protocol UITextViewDelegate: UIScrollViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool
    func textViewDidBeginEditing(_ textView: UITextView)
    func textViewDidEndEditing(_ textView: UITextView)
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textViewDidChange(_ textView: UITextView)
    func textViewDidChangeSelection(_ textView: UITextView)
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
}

extension UITextViewDelegate {
    public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool { true }
    public func textViewShouldEndEditing(_ textView: UITextView) -> Bool { true }
    public func textViewDidBeginEditing(_ textView: UITextView) {}
    public func textViewDidEndEditing(_ textView: UITextView) {}
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { true }
    public func textViewDidChange(_ textView: UITextView) {}
    public func textViewDidChangeSelection(_ textView: UITextView) {}
    public func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool { true }
}

public enum UITextItemInteraction: Int, Sendable {
    case invokeDefaultAction = 0, presentActions, preview
}

/// Kinds of data a text view could turn into links.
public struct UIDataDetectorTypes: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let phoneNumber = UIDataDetectorTypes(rawValue: 1 << 0)
    public static let link = UIDataDetectorTypes(rawValue: 1 << 1)
    public static let address = UIDataDetectorTypes(rawValue: 1 << 2)
    public static let calendarEvent = UIDataDetectorTypes(rawValue: 1 << 3)
    public static let shipmentTrackingNumber = UIDataDetectorTypes(rawValue: 1 << 4)
    public static let flightNumber = UIDataDetectorTypes(rawValue: 1 << 5)
    public static let lookupSuggestion = UIDataDetectorTypes(rawValue: 1 << 6)
    public static let all = UIDataDetectorTypes(rawValue: .max)
}

/// The area a text view's text lays out in, its width the view's less the insets.
// ponytail: read when the text view lays out; changes don't lay it out again by themselves.
open class NSTextContainer: NSObject {
    public init(size: CGSize) {
        self.size = size
        super.init()
    }

    public override convenience init() {
        self.init(size: .zero)
    }

    open var size: CGSize
    /// Space at both ends of each line.
    open var lineFragmentPadding: CGFloat = 5
    /// 0 for any number.
    open var maximumNumberOfLines = 0
    open var lineBreakMode = NSLineBreakMode.byWordWrapping
    open var widthTracksTextView = true
    open var heightTracksTextView = false
}
