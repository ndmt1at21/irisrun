import Foundation
import IrisHost

// Text input: the traits a keyboard adapts to, the protocols that take keyboard input, the
// keyboard's notifications, and how the host's input method and keys reach the first responder.

// MARK: Traits

/// The kind of keyboard a text input asks for.
public enum UIKeyboardType: Int, Sendable {
    case `default` = 0
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad

    public static var alphabet: UIKeyboardType {
        .asciiCapable
    }
}

public enum UIReturnKeyType: Int, Sendable {
    case `default` = 0, go, google, join, next, route, search, send, yahoo, done, emergencyCall, `continue`
}

public enum UITextAutocapitalizationType: Int, Sendable {
    case none = 0, words, sentences, allCharacters
}

public enum UITextAutocorrectionType: Int, Sendable {
    case `default` = 0, no, yes
}

public enum UITextSpellCheckingType: Int, Sendable {
    case `default` = 0, no, yes
}

public enum UITextSmartQuotesType: Int, Sendable {
    case `default` = 0, no, yes
}

public enum UITextSmartDashesType: Int, Sendable {
    case `default` = 0, no, yes
}

public enum UITextSmartInsertDeleteType: Int, Sendable {
    case `default` = 0, no, yes
}

public enum UIKeyboardAppearance: Int, Sendable {
    case `default` = 0, dark, light

    public static var alert: UIKeyboardAppearance {
        .dark
    }
}

/// What a text input holds, for autofill and the keyboard's suggestions.
public struct UITextContentType: RawRepresentable, Hashable, Sendable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let name = UITextContentType("name")
    public static let namePrefix = UITextContentType("honorific-prefix")
    public static let givenName = UITextContentType("given-name")
    public static let middleName = UITextContentType("additional-name")
    public static let familyName = UITextContentType("family-name")
    public static let nameSuffix = UITextContentType("honorific-suffix")
    public static let nickname = UITextContentType("nickname")
    public static let jobTitle = UITextContentType("organization-title")
    public static let organizationName = UITextContentType("organization")
    public static let location = UITextContentType("location")
    public static let fullStreetAddress = UITextContentType("street-address")
    public static let streetAddressLine1 = UITextContentType("address-line1")
    public static let streetAddressLine2 = UITextContentType("address-line2")
    public static let addressCity = UITextContentType("address-level2")
    public static let addressState = UITextContentType("address-level1")
    public static let addressCityAndState = UITextContentType("address-level1+2")
    public static let sublocality = UITextContentType("address-level3")
    public static let countryName = UITextContentType("country-name")
    public static let postalCode = UITextContentType("postal-code")
    public static let telephoneNumber = UITextContentType("tel")
    public static let emailAddress = UITextContentType("email")
    public static let URL = UITextContentType("url")
    public static let creditCardNumber = UITextContentType("cc-number")
    public static let username = UITextContentType("username")
    public static let password = UITextContentType("password")
    public static let newPassword = UITextContentType("new-password")
    public static let oneTimeCode = UITextContentType("one-time-code")
    public static let shipmentTrackingNumber = UITextContentType("shipment-tracking-number")
    public static let flightNumber = UITextContentType("flight-number")
    public static let dateTime = UITextContentType("date-time")
}

/// What the keyboard of a text input adapts to. The Device UI types with the computer's own
/// keyboard and input method, so these are kept for the app and change nothing about input.
@preconcurrency @MainActor
public protocol UITextInputTraits: NSObjectProtocol {
    var autocapitalizationType: UITextAutocapitalizationType { get set }
    var autocorrectionType: UITextAutocorrectionType { get set }
    var spellCheckingType: UITextSpellCheckingType { get set }
    var smartQuotesType: UITextSmartQuotesType { get set }
    var smartDashesType: UITextSmartDashesType { get set }
    var smartInsertDeleteType: UITextSmartInsertDeleteType { get set }
    var keyboardType: UIKeyboardType { get set }
    var keyboardAppearance: UIKeyboardAppearance { get set }
    var returnKeyType: UIReturnKeyType { get set }
    var enablesReturnKeyAutomatically: Bool { get set }
    var isSecureTextEntry: Bool { get set }
    var textContentType: UITextContentType! { get set }
}

/// Every trait is optional in UIKit; a key input without one has the default.
extension UITextInputTraits {
    public var autocapitalizationType: UITextAutocapitalizationType { get { .sentences } set {} }
    public var autocorrectionType: UITextAutocorrectionType { get { .default } set {} }
    public var spellCheckingType: UITextSpellCheckingType { get { .default } set {} }
    public var smartQuotesType: UITextSmartQuotesType { get { .default } set {} }
    public var smartDashesType: UITextSmartDashesType { get { .default } set {} }
    public var smartInsertDeleteType: UITextSmartInsertDeleteType { get { .default } set {} }
    public var keyboardType: UIKeyboardType { get { .default } set {} }
    public var keyboardAppearance: UIKeyboardAppearance { get { .default } set {} }
    public var returnKeyType: UIReturnKeyType { get { .default } set {} }
    public var enablesReturnKeyAutomatically: Bool { get { false } set {} }
    public var isSecureTextEntry: Bool { get { false } set {} }
    public var textContentType: UITextContentType! { get { nil } set {} }
}

// MARK: Key input

/// A responder that takes typed text: the keyboard inserts text, and Backspace deletes.
@preconcurrency @MainActor
public protocol UIKeyInput: UITextInputTraits {
    var hasText: Bool { get }
    func insertText(_ text: String)
    func deleteBackward()
}

/// A responder that edits text with the input method: marked text while it composes, the
/// selection, and positions in the text.
// ponytail: what Iris asks of a text input; layout queries, writing directions and tokenizers
// are left out, and UITextField and UITextView have the ones apps call.
@preconcurrency @MainActor
public protocol UITextInput: UIKeyInput {
    func text(in range: UITextRange) -> String?
    func replace(_ range: UITextRange, withText text: String)
    var selectedTextRange: UITextRange? { get set }
    var markedTextRange: UITextRange? { get }
    var markedTextStyle: [NSAttributedString.Key: Any]? { get set }
    func setMarkedText(_ markedText: String?, selectedRange: NSRange)
    func unmarkText()
    var beginningOfDocument: UITextPosition { get }
    var endOfDocument: UITextPosition { get }
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange?
    func position(from position: UITextPosition, offset: Int) -> UITextPosition?
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int
}

/// A place in a text input's text.
open class UITextPosition: NSObject {}

/// A range of a text input's text.
open class UITextRange: NSObject {
    open var isEmpty: Bool {
        start.isEqual(end)
    }

    open var start: UITextPosition {
        UITextPosition()
    }

    open var end: UITextPosition {
        UITextPosition()
    }
}

/// A rectangle of selected text, from `selectionRects(for:)`.
open class UITextSelectionRect: NSObject {
    open var rect: CGRect {
        .zero
    }

    open var writingDirection: NSWritingDirection {
        .leftToRight
    }

    open var containsStart: Bool {
        false
    }

    open var containsEnd: Bool {
        false
    }

    open var isVertical: Bool {
        false
    }
}

/// Iris: a position in UITextField's and UITextView's text, in UTF-16 code units.
final class IrisTextPosition: UITextPosition {
    let offset: Int

    init(_ offset: Int) {
        self.offset = offset
    }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? IrisTextPosition)?.offset == offset
    }

    override var hash: Int {
        offset
    }
}

final class IrisTextRange: UITextRange {
    let range: Range<Int>

    init(_ range: Range<Int>) {
        self.range = range
    }

    override var start: UITextPosition {
        IrisTextPosition(range.lowerBound)
    }

    override var end: UITextPosition {
        IrisTextPosition(range.upperBound)
    }

    override var isEmpty: Bool {
        range.isEmpty
    }
}

final class IrisSelectionRect: UITextSelectionRect {
    private let frame: CGRect
    private let edges: (start: Bool, end: Bool)

    init(_ frame: CGRect, containsStart: Bool, containsEnd: Bool) {
        self.frame = frame
        edges = (containsStart, containsEnd)
    }

    override var rect: CGRect {
        frame
    }

    override var containsStart: Bool {
        edges.start
    }

    override var containsEnd: Bool {
        edges.end
    }
}

// MARK: Keyboard

extension UIResponder {
    public static let keyboardWillShowNotification = Notification.Name("UIKeyboardWillShowNotification")
    public static let keyboardDidShowNotification = Notification.Name("UIKeyboardDidShowNotification")
    public static let keyboardWillHideNotification = Notification.Name("UIKeyboardWillHideNotification")
    public static let keyboardDidHideNotification = Notification.Name("UIKeyboardDidHideNotification")
    public static let keyboardWillChangeFrameNotification = Notification.Name("UIKeyboardWillChangeFrameNotification")
    public static let keyboardDidChangeFrameNotification = Notification.Name("UIKeyboardDidChangeFrameNotification")

    public static let keyboardFrameBeginUserInfoKey = "UIKeyboardFrameBeginUserInfoKey"
    public static let keyboardFrameEndUserInfoKey = "UIKeyboardFrameEndUserInfoKey"
    public static let keyboardAnimationDurationUserInfoKey = "UIKeyboardAnimationDurationUserInfoKey"
    public static let keyboardAnimationCurveUserInfoKey = "UIKeyboardAnimationCurveUserInfoKey"
    public static let keyboardIsLocalUserInfoKey = "UIKeyboardIsLocalUserInfoKey"
}

/// On iOS, NSValue holds the keyboard's frames.
extension NSValue {
    public convenience init(cgRect rect: CGRect) {
        self.init(rect: rect)
    }

    public var cgRectValue: CGRect {
        rectValue
    }

    public convenience init(cgPoint point: CGPoint) {
        self.init(point: point)
    }

    public var cgPointValue: CGPoint {
        pointValue
    }

    public convenience init(cgSize size: CGSize) {
        self.init(size: size)
    }

    public var cgSizeValue: CGSize {
        sizeValue
    }
}

/// Iris: the keyboard, shown while the first responder takes key input. The Device UI types
/// with the computer's keyboard, as an iPhone with a hardware keyboard does, so the keyboard
/// takes no room: its frame is the bottom edge of the screen, zero points tall. The
/// notifications still come, in UIKit's order, for apps that move their content for it.
@MainActor
enum Keyboard {
    private(set) static var isShown = false
    private static var isUpdateScheduled = false

    /// Called when the first responder changes; the keyboard follows once the change is done.
    static func scheduleUpdate() {
        guard !isUpdateScheduled else { return }
        isUpdateScheduled = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated(update)
        }
    }

    /// Shows or hides the keyboard for the first responder, posting the notifications.
    static func update() {
        isUpdateScheduled = false
        let wantsKeyboard = UIResponder.first is UIKeyInput || UIResponder.first is any DeviceInputHandler
        guard wantsKeyboard != isShown else { return }
        isShown = wantsKeyboard
        let screen = UIScreen.main.bounds
        let frame = NSValue(cgRect: CGRect(x: 0, y: screen.maxY, width: screen.width, height: 0))
        let info: [AnyHashable: Any] = [
            UIResponder.keyboardFrameBeginUserInfoKey: frame,
            UIResponder.keyboardFrameEndUserInfoKey: frame,
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.25 as Double,
            UIResponder.keyboardAnimationCurveUserInfoKey: 7 as Int,
            UIResponder.keyboardIsLocalUserInfoKey: true,
        ]
        let center = NotificationCenter.default
        center.post(name: wantsKeyboard ? UIResponder.keyboardWillShowNotification : UIResponder.keyboardWillHideNotification, object: nil, userInfo: info)
        center.post(name: UIResponder.keyboardWillChangeFrameNotification, object: nil, userInfo: info)
        center.post(name: wantsKeyboard ? UIResponder.keyboardDidShowNotification : UIResponder.keyboardDidHideNotification, object: nil, userInfo: info)
        center.post(name: UIResponder.keyboardDidChangeFrameNotification, object: nil, userInfo: info)
    }
}

// MARK: Routing the host's input

/// Iris: UITextField and UITextView, which edit with IrisHost's editing state.
@MainActor
protocol IrisTextEditing: UIKeyInput {
    var editor: IrisTextEditor { get }
}

extension TouchInput {
    /// A first responder that takes the host's input as it comes, as a SwiftUI hosting view does
    /// for its focused text field, which edits on its own.
    private var handler: (any DeviceInputHandler)? {
        UIResponder.first as? any DeviceInputHandler
    }

    /// The input method commits text: UIKit inserts it, in place of the marked text.
    func commit(_ text: String) {
        if let handler {
            return handler.commit(text)
        }
        (UIResponder.first as? UIKeyInput)?.insertText(text)
    }

    /// The input method composes: marked text, for inputs that can show it; others get the
    /// text when it is committed.
    func compose(_ text: String) {
        if let handler {
            return handler.compose(text)
        }
        guard let input = UIResponder.first as? UITextInput else { return }
        input.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0))
        if text.isEmpty {
            input.unmarkText()
        }
    }

    /// A correction deletes around the marked text or the selection.
    func deleteSurrounding(before: Int, after: Int) {
        if let handler {
            handler.deleteSurrounding(before: before, after: after)
        } else if let input = UIResponder.first as? IrisTextEditing {
            input.editor.edit { $0.deleteSurrounding(before: before, after: after) }
        } else if let input = UIResponder.first as? UIKeyInput {
            // ponytail: other inputs lose characters before the caret only.
            for _ in 0 ..< before {
                input.deleteBackward()
            }
        }
    }

    /// Backspace and Return go through UIKeyInput, as UIKit's keyboard sends them, so that
    /// subclasses that override `deleteBackward()` or `insertText(_:)` see them; the other
    /// editing keys move in the text of UIKit's own text views.
    func press(_ code: String, command: Bool) {
        if let handler {
            return handler.press(code, command: command)
        }
        guard let input = UIResponder.first as? UIKeyInput else { return }
        switch code {
        case "Backspace" where !command:
            input.deleteBackward()
        case "Enter", "NumpadEnter":
            input.insertText("\n")
        default:
            (input as? IrisTextEditing)?.editor.press(code, command: command)
        }
    }
}
