import Foundation
import IrisHost

/// A control for one line of text. A tap gives it the keyboard; the person types with the
/// host's input method, marked text underlined, into text that scrolls sideways to keep the
/// caret in view. The delegate may refuse edits, and Return ends editing.
// ponytail: no copy and paste, edit menu, selection handles or loupe; Shift with the arrows
// doesn't select. Secure fields don't show the last character typed for a moment.
@preconcurrency @MainActor
open class UITextField: UIControl, UITextInput, IrisTextEditing {
    let editor = IrisTextEditor(isMultiline: false)
    private let border = CALayer()
    private let placeholderLabel = UILabel()
    private let clearButton = ClearButton()
    /// How far the text has scrolled sideways while editing.
    private var scrollX: CGFloat = 0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        layer.insertSublayer(border, at: 0)
        addSubview(editor.canvas)
        placeholderLabel.textColor = .placeholderText
        addSubview(placeholderLabel)
        clearButton.isHidden = true
        clearButton.addAction(UIAction { [unowned self] _ in clear() }, for: .touchUpInside)
        addSubview(clearButton)
        editor.shouldChange = { [unowned self] range, string in
            delegate?.textField(self, shouldChangeCharactersIn: range, replacementString: string) ?? true
        }
        editor.didChange = { [unowned self] range, string in
            if let storage {
                let text = NSMutableAttributedString(attributedString: storage)
                text.replaceCharacters(in: range, with: string)
                self.storage = text
            }
            textChanged()
        }
        editor.didChangeSelection = { [unowned self] in
            setNeedsLayout()
            delegate?.textFieldDidChangeSelection(self)
        }
    }

    // MARK: Text

    /// Attributes the app gave the text, which edits keep around their change.
    private var storage: NSAttributedString?

    /// Setting it puts the caret at the end, sends no events and calls no delegate methods.
    open var text: String? {
        get { editor.state.text }
        set {
            storage = nil
            editor.state = TextEditingState(text: newValue ?? "")
            editor.replacesAllOnNextEdit = false
            setNeedsLayout()
        }
    }

    open var attributedText: NSAttributedString? {
        get { storage ?? NSAttributedString(string: editor.state.text, attributes: defaultTextAttributes) }
        set {
            text = newValue?.string
            storage = newValue.map { NSAttributedString(attributedString: $0) }
        }
    }

    open var font: UIFont? = .systemFont(ofSize: 17) {
        didSet { setNeedsLayout() }
    }

    open var textColor: UIColor? = .label {
        didSet { setNeedsLayout() }
    }

    open var textAlignment = NSTextAlignment.natural {
        didSet { setNeedsLayout() }
    }

    /// The font, color and alignment as text attributes.
    open var defaultTextAttributes: [NSAttributedString.Key: Any] {
        get {
            let style = NSMutableParagraphStyle()
            style.alignment = textAlignment
            return [.font: shownFont, .foregroundColor: textColor ?? .label, .paragraphStyle: style]
        }
        set {
            font = newValue[.font] as? UIFont ?? font
            textColor = newValue[.foregroundColor] as? UIColor ?? textColor
            textAlignment = (newValue[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? textAlignment
        }
    }

    open var typingAttributes: [NSAttributedString.Key: Any]?
    open var allowsEditingTextAttributes = false

    open var placeholder: String? {
        get { placeholderLabel.text }
        set {
            placeholderLabel.text = newValue
            setNeedsLayout()
        }
    }

    open var attributedPlaceholder: NSAttributedString? {
        get { placeholderLabel.attributedText }
        set {
            placeholderLabel.attributedText = newValue
            setNeedsLayout()
        }
    }

    private var shownFont: UIFont {
        font ?? .systemFont(ofSize: 17)
    }

    // MARK: Appearance

    open var borderStyle = UITextField.BorderStyle.none {
        didSet { setNeedsLayout() }
    }

    /// Drawn in the bounds, stretched, in place of a border.
    open var background: UIImage? {
        didSet { setNeedsLayout() }
    }

    open var disabledBackground: UIImage? {
        didSet { setNeedsLayout() }
    }

    open var clearsOnBeginEditing = false
    open var clearsOnInsertion = false

    /// Shrinks text that doesn't fit, down to `minimumFontSize` (6 points when that is 0).
    open var adjustsFontSizeToFitWidth = false {
        didSet { setNeedsLayout() }
    }

    open var minimumFontSize: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    open var clearButtonMode = UITextField.ViewMode.never {
        didSet { setNeedsLayout() }
    }

    open var leftView: UIView? {
        didSet { replace(oldValue, with: leftView) }
    }

    open var leftViewMode = UITextField.ViewMode.never {
        didSet { setNeedsLayout() }
    }

    open var rightView: UIView? {
        didSet { replace(oldValue, with: rightView) }
    }

    open var rightViewMode = UITextField.ViewMode.never {
        didSet { setNeedsLayout() }
    }

    private func replace(_ old: UIView?, with new: UIView?) {
        if old !== new {
            old?.removeFromSuperview()
        }
        if let new {
            addSubview(new)
        }
        setNeedsLayout()
    }

    override open var isEnabled: Bool {
        didSet {
            if !isEnabled, isFirstResponder {
                resignFirstResponder()
            }
            setNeedsLayout()
        }
    }

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
    open var textContentType: UITextContentType!

    /// Shows a bullet for each character. Editing again after the field lost the keyboard
    /// replaces all the text, as on iOS.
    open var isSecureTextEntry = false {
        didSet { setNeedsLayout() }
    }

    // MARK: Editing

    open weak var delegate: (any UITextFieldDelegate)?

    open private(set) var isEditing = false

    override open var canBecomeFirstResponder: Bool {
        isEnabled
    }

    /// Asks the delegate, then takes the keyboard: the delegate hears of it, then the targets
    /// of `editingDidBegin`, then observers of `textDidBeginEditingNotification`.
    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !isFirstResponder else { return true }
        guard canBecomeFirstResponder, window != nil, delegate?.textFieldShouldBeginEditing(self) ?? true,
              super.becomeFirstResponder() else { return false }
        if clearsOnBeginEditing {
            text = ""
        }
        editor.replacesAllOnNextEdit = isSecureTextEntry && hasText
        editor.state.caret(at: editor.state.length)
        isEditing = true
        setNeedsLayout()
        delegate?.textFieldDidBeginEditing(self)
        sendActions(for: .editingDidBegin)
        NotificationCenter.default.post(name: UITextField.textDidBeginEditingNotification, object: self)
        return true
    }

    /// Asks the delegate, unless forced by `endEditing(true)`, then gives the keyboard up,
    /// keeping marked text.
    @discardableResult
    override open func resignFirstResponder() -> Bool {
        guard isFirstResponder else { return super.resignFirstResponder() }
        guard UIResponder.isForcingResign || delegate?.textFieldShouldEndEditing(self) ?? true,
              super.resignFirstResponder() else { return false }
        editor.state.unmark()
        isEditing = false
        setNeedsLayout()
        delegate?.textFieldDidEndEditing(self, reason: .committed)
        sendActions(for: .editingDidEnd)
        NotificationCenter.default.post(name: UITextField.textDidEndEditingNotification, object: self, userInfo: [
            UITextField.didEndEditingReasonUserInfoKey: UITextField.DidEndEditingReason.committed.rawValue,
        ])
        return true
    }

    private func textChanged() {
        setNeedsLayout()
        sendActions(for: .editingChanged)
        NotificationCenter.default.post(name: UITextField.textDidChangeNotification, object: self)
    }

    /// Return: the delegate decides; then `editingDidEndOnExit` goes out, and if anything listens
    /// for it the field gives the keyboard up, as on iOS.
    private func returnKeyPressed() {
        editor.edit { $0.unmark() }
        guard delegate?.textFieldShouldReturn(self) ?? true else { return }
        sendActions(for: .editingDidEndOnExit)
        if allControlEvents.contains(.editingDidEndOnExit) {
            resignFirstResponder()
        }
    }

    private func clear() {
        guard delegate?.textFieldShouldClear(self) ?? true else { return }
        guard isFirstResponder || becomeFirstResponder() else { return }
        storage = nil
        editor.state = TextEditingState(text: "")
        editor.replacesAllOnNextEdit = false
        textChanged()
    }

    /// A tap takes the keyboard and puts the caret at the nearest character boundary; a
    /// double tap selects the word there.
    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isEnabled, let touch = touches.first, bounds.contains(touch.location(in: self)) else { return }
        let offset = stateOffset(editor.canvas.offset(at: touch.location(in: editor.canvas)))
        guard isFirstResponder || becomeFirstResponder() else { return }
        editor.edit { state in
            state.unmark()
            state.selection = touch.tapCount == 2 ? editor.word(at: offset) : offset ..< offset
        }
    }

    // MARK: UIKeyInput

    open var hasText: Bool {
        !editor.state.text.isEmpty
    }

    /// Typed text, in place of the marked text or the selection; a line break is Return.
    open func insertText(_ text: String) {
        guard text != "\n" else { return returnKeyPressed() }
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

    /// Where the caret goes at a position, in the field's coordinates.
    open func caretRect(for position: UITextPosition) -> CGRect {
        layoutIfNeeded()
        return editor.canvas.convert(editor.canvas.caretRect(at: shownOffset(editor.offset(position))), to: self)
    }

    open func firstRect(for range: UITextRange) -> CGRect {
        selectionRects(for: range).first?.rect ?? .zero
    }

    open func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        layoutIfNeeded()
        let range = editor.range(range)
        let rects = editor.canvas.rects(for: shownOffset(range.lowerBound) ..< shownOffset(range.upperBound))
        return rects.enumerated().map { index, rect in
            IrisSelectionRect(editor.canvas.convert(rect, to: self), containsStart: index == 0, containsEnd: index == rects.count - 1)
        }
    }

    open func closestPosition(to point: CGPoint) -> UITextPosition? {
        layoutIfNeeded()
        return IrisTextPosition(stateOffset(editor.canvas.offset(at: convert(point, to: editor.canvas))))
    }

    // MARK: Layout

    open func borderRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }

    /// The text's area: inside the border, between the left view and the right view or the
    /// clear button.
    open func textRect(forBounds bounds: CGRect) -> CGRect {
        let inset: CGFloat = switch borderStyle {
        case .none: 0
        case .roundedRect: 7
        default: 8
        }
        var left = bounds.minX + inset
        var right = bounds.maxX - inset
        if leftView != nil, shows(leftViewMode) {
            left = max(left, leftViewRect(forBounds: bounds).maxX)
        }
        if showsClearButton {
            right = min(right, clearButtonRect(forBounds: bounds).minX)
        } else if rightView != nil, shows(rightViewMode) {
            right = min(right, rightViewRect(forBounds: bounds).minX)
        }
        return CGRect(x: left, y: bounds.minY, width: max(right - left, 0), height: bounds.height)
    }

    open func editingRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }

    open func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        textRect(forBounds: bounds)
    }

    /// A 19-point button at the trailing end, left of the right view if that shows.
    open func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        var right = bounds.maxX - 6
        if rightView != nil, shows(rightViewMode) {
            right = rightViewRect(forBounds: bounds).minX
        }
        return CGRect(x: right - 19, y: bounds.midY - 9.5, width: 19, height: 19)
    }

    open func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        let size = leftView?.frame.size ?? .zero
        return CGRect(x: bounds.minX, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    open func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        let size = rightView?.frame.size ?? .zero
        return CGRect(x: bounds.maxX - size.width, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }

    // ponytail: the canvas draws the text and a label the placeholder; these draw nothing, so
    // subclasses that draw in them with Core Graphics show the default instead.
    open func drawText(in rect: CGRect) {}
    open func drawPlaceholder(in rect: CGRect) {}

    private func shows(_ mode: ViewMode) -> Bool {
        switch mode {
        case .never: false
        case .whileEditing: isEditing
        case .unlessEditing: !isEditing
        case .always: true
        }
    }

    private var showsClearButton: Bool {
        hasText && shows(clearButtonMode)
    }

    /// A roundedRect field is as tall as its text with 7 points above and below.
    /// The text's line is centered vertically.
    override var irisBaselineOffsets: (first: CGFloat, last: CGFloat)? {
        let baseline = (font ?? .systemFont(ofSize: 17)).irisCenteredBaseline
        return (baseline, baseline)
    }

    override open var intrinsicContentSize: CGSize {
        let height = ceil(shownFont.lineHeight) + (borderStyle == .roundedRect ? 14 : 0)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: intrinsicContentSize.height)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        drawBorder()
        if let leftView {
            leftView.isHidden = !shows(leftViewMode)
            leftView.frame = leftViewRect(forBounds: bounds)
        }
        if let rightView {
            rightView.isHidden = !shows(rightViewMode)
            rightView.frame = rightViewRect(forBounds: bounds)
        }
        clearButton.isHidden = !showsClearButton
        clearButton.frame = clearButtonRect(forBounds: bounds)
        placeholderLabel.font = shownFont
        placeholderLabel.textAlignment = textAlignment
        placeholderLabel.frame = placeholderRect(forBounds: bounds)
        placeholderLabel.isHidden = hasText
        editor.canvas.frame = isEditing ? editingRect(forBounds: bounds) : textRect(forBounds: bounds)
        layOutText()
    }

    private func drawBorder() {
        border.frame = borderRect(forBounds: bounds)
        let shown = isEnabled ? background : disabledBackground ?? background
        layer.contents = shown?.cgImage
        let style = shown == nil ? borderStyle : .none
        border.isHidden = style == .none
        border.borderWidth = style == .roundedRect ? 0.5 : 1
        border.borderColor = switch style {
        case .line: UIColor.black.cgColor
        case .bezel: UIColor.gray.cgColor
        default: UIColor(red: 0.8, green: 0.8, blue: 0.82, alpha: 1).cgColor
        }
        border.cornerRadius = style == .roundedRect ? 5 : 0
        border.backgroundColor = style == .roundedRect ? UIColor.systemBackground.cgColor : nil
    }

    /// Lays the text out in the canvas: truncated with "…" when it doesn't fit and the field
    /// isn't editing; scrolled to keep the caret in view while it is; centered vertically.
    private func layOutText() {
        let canvas = editor.canvas
        let width = canvas.bounds.width
        let shown = isSecureTextEntry ? String(repeating: "•", count: editor.state.text.count) : editor.state.text
        let content = !isSecureTextEntry ? storage.map { NSAttributedString(attributedString: $0) } : nil
        var text = IrisText(content ?? NSAttributedString(string: shown), font: shownFont, color: textColor ?? .label, alignment: textAlignment)
        canvas.lineHeight = shownFont.lineHeight
        canvas.maxWidth = .infinity
        canvas.text = text
        canvas.textOrigin = .zero
        if adjustsFontSizeToFitWidth, canvas.textSize.width > width, width > 0 {
            let minimum = (minimumFontSize > 0 ? minimumFontSize : 6) / shownFont.pointSize
            text = text.scaled(by: max(width / canvas.textSize.width, min(minimum, 1)))
            canvas.text = text
        }
        let size = canvas.textSize
        var x: CGFloat = 0
        if isEditing, size.width + 2 > width {
            let caret = canvas.caretRect(at: shownOffset(editor.state.cursor)).midX
            scrollX = min(max(scrollX, caret + 2 - width), caret - 1)
            scrollX = min(max(scrollX, 0), size.width + 2 - width)
            x = -scrollX
        } else if isEditing {
            scrollX = 0
            let fraction: CGFloat = switch textAlignment {
            case .center: 0.5
            case .right: 1
            default: 0
            }
            x = (width - size.width) * fraction
        } else {
            // Not editing, the paragraph aligns the text and cuts what doesn't fit.
            scrollX = 0
            text.paragraph.maxLines = 1
            canvas.text = text
            canvas.maxWidth = width
        }
        let y: CGFloat = switch contentVerticalAlignment {
        case .top: 0
        case .bottom: canvas.bounds.height - size.height
        default: (canvas.bounds.height - size.height) / 2
        }
        canvas.textOrigin = CGPoint(x: x, y: y)
        let state = editor.state
        canvas.selection = isEditing ? shownOffset(state.selection.lowerBound) ..< shownOffset(state.selection.upperBound) : nil
        canvas.marked = isEditing ? state.marked.map { shownOffset($0.lowerBound) ..< shownOffset($0.upperBound) } : nil
        canvas.update()
    }

    /// An offset in the text as shown: bullets stand one for each character.
    private func shownOffset(_ offset: Int) -> Int {
        guard isSecureTextEntry else { return offset }
        return editor.state.text[..<editor.state.index(offset)].count
    }

    private func stateOffset(_ shown: Int) -> Int {
        guard isSecureTextEntry else { return editor.state.boundary(atOrBefore: shown) }
        let text = editor.state.text
        return editor.state.offset(text.index(text.startIndex, offsetBy: min(shown, text.count)))
    }

    // MARK: Accessibility

    /// The text, as VoiceOver reads it: bullets for a secure field.
    override open var accessibilityValue: String? {
        get { super.accessibilityValue ?? (isSecureTextEntry ? String(repeating: "•", count: editor.state.text.count) : editor.state.text) }
        set { super.accessibilityValue = newValue }
    }
}

extension UITextField {
    public enum BorderStyle: Int, Sendable {
        case none = 0, line, bezel, roundedRect
    }

    public enum ViewMode: Int, Sendable {
        case never = 0, whileEditing, unlessEditing, always
    }

    public enum DidEndEditingReason: Int, Sendable {
        case committed = 0, cancelled
    }

    public static let textDidBeginEditingNotification = Notification.Name("UITextFieldTextDidBeginEditingNotification")
    public static let textDidChangeNotification = Notification.Name("UITextFieldTextDidChangeNotification")
    public static let textDidEndEditingNotification = Notification.Name("UITextFieldTextDidEndEditingNotification")
    public static let didEndEditingReasonUserInfoKey = "UITextFieldDidEndEditingReasonKey"
}

/// What a text field asks and tells as the person edits. Every method is optional.
@preconcurrency @MainActor
public protocol UITextFieldDelegate: NSObjectProtocol {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool
    func textFieldDidBeginEditing(_ textField: UITextField)
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool
    func textFieldDidEndEditing(_ textField: UITextField)
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason)
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    func textFieldDidChangeSelection(_ textField: UITextField)
    func textFieldShouldClear(_ textField: UITextField) -> Bool
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
}

extension UITextFieldDelegate {
    public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool { true }
    public func textFieldDidBeginEditing(_ textField: UITextField) {}
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool { true }
    public func textFieldDidEndEditing(_ textField: UITextField) {}
    /// UIKit calls this one in place of `textFieldDidEndEditing(_:)` when it is implemented.
    public func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        textFieldDidEndEditing(textField)
    }
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { true }
    public func textFieldDidChangeSelection(_ textField: UITextField) {}
    public func textFieldShouldClear(_ textField: UITextField) -> Bool { true }
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool { true }
}

/// Iris: the gray circle with a cross that clears a text field.
@MainActor
private final class ClearButton: UIControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
        let circle = CALayer()
        circle.backgroundColor = UIColor.systemGray3.cgColor
        circle.frame = CGRect(x: 1, y: 1, width: 17, height: 17)
        circle.cornerRadius = 8.5
        layer.addSublayer(circle)
        let cross = UIImageView(image: UIImage(systemName: "xmark"))
        cross.frame = CGRect(x: 4.5, y: 4.5, width: 10, height: 10)
        cross.tintColor = .white
        cross.isUserInteractionEnabled = false
        addSubview(cross)
        accessibilityLabel = "Clear text"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
