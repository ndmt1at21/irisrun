import Foundation

/// An object that takes part in handling events: views, view controllers, windows, scenes and
/// the application. What a responder does not handle goes up the chain of `next` responders:
/// touches by default, and actions sent to nil to the first one that can perform them.
@preconcurrency @MainActor
open class UIResponder: NSObject {
    public override init() {
        super.init()
        _ = UIResponder.ownMethods
    }

    /// The next object up the responder chain.
    open var next: UIResponder? {
        nil
    }

    // MARK: Touches

    open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesBegan(touches, with: event)
    }

    open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesMoved(touches, with: event)
    }

    open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesEnded(touches, with: event)
    }

    open func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        next?.touchesCancelled(touches, with: event)
    }

    open func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {}

    // MARK: First responder

    /// The responder that gets keyboard input, and actions sent to nil, first.
    // ponytail: one for the app, not one per window as in UIKit; Iris has one window that
    // takes keyboard input at a time.
    static weak var first: UIResponder?

    open var canBecomeFirstResponder: Bool {
        false
    }

    open var canResignFirstResponder: Bool {
        true
    }

    open var isFirstResponder: Bool {
        UIResponder.first === self
    }

    /// Views can only become first responder in a window. The keyboard shows once the change
    /// is done, if the new first responder takes key input.
    @discardableResult
    open func becomeFirstResponder() -> Bool {
        guard !isFirstResponder else { return true }
        guard canBecomeFirstResponder, (self as? UIView).map({ $0.window != nil }) ?? true else { return false }
        if let current = UIResponder.first, !current.resignFirstResponder() {
            return false
        }
        UIResponder.first = self
        Keyboard.scheduleUpdate()
        return true
    }

    @discardableResult
    open func resignFirstResponder() -> Bool {
        guard canResignFirstResponder || UIResponder.isForcingResign else { return false }
        if isFirstResponder {
            UIResponder.first = nil
            Keyboard.scheduleUpdate()
        }
        return true
    }

    /// Iris: set while `endEditing(true)` or a view leaving its window makes the first
    /// responder resign, which then may not refuse.
    static var isForcingResign = false

    /// Makes the first responder resign without asking whether it may.
    static func forceResign() {
        guard let first else { return }
        isForcingResign = true
        defer { isForcingResign = false }
        if !first.resignFirstResponder(), self.first === first {
            self.first = nil
            Keyboard.scheduleUpdate()
        }
    }

    // MARK: Input views

    /// A view to show in place of the keyboard; text inputs let apps set it.
    open var inputView: UIView? {
        nil
    }

    /// A bar above the keyboard.
    open var inputAccessoryView: UIView? {
        nil
    }

    // ponytail: the Device UI shows no keyboard, so there is nothing to reload.
    open func reloadInputViews() {}

    // MARK: Actions

    /// The responder that performs an action sent to nil: this one if it can, else the first
    /// one up the chain that can.
    open func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        canPerformAction(action, withSender: sender) ? self : next?.target(forAction: action, withSender: sender)
    }

    /// Whether the responder has a method for the action.
    open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        responds(to: action)
    }

    /// UIKit's own methods that apps name with selectors, such as
    /// `#selector(UIResponder.resignFirstResponder)` sent to nil to put the keyboard away.
    private static let ownMethods: Void = _IrisMethods.register(UIResponder.self, [
        "becomeFirstResponder": .init(UIResponder.becomeFirstResponder),
        "resignFirstResponder": .init(UIResponder.resignFirstResponder),
    ])
}
