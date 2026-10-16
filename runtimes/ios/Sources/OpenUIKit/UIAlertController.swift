import Foundation

/// An alert, or an action sheet, as iOS 17 draws them over a dimmed screen: an alert is a card
/// in the middle, with its buttons side by side when there are two; an action sheet rises from
/// the bottom, its cancel button apart. An action dismisses it, then runs its handler.
// ponytail: no blur behind the card (a solid color stands in), images, attributed titles or
// keyboard shortcuts; many actions don't scroll.
@preconcurrency @MainActor
open class UIAlertController: UIViewController {
    public convenience init(title: String?, message: String?, preferredStyle: UIAlertController.Style) {
        self.init(nibName: nil, bundle: nil)
        self.title = title
        self.message = message
        style = preferredStyle
        modalPresentationStyle = .overFullScreen
    }

    private var style = Style.alert

    open var preferredStyle: Style {
        style
    }

    open var message: String?
    open private(set) var actions: [UIAlertAction] = []
    /// Shows in bold, in place of the cancel action.
    open var preferredAction: UIAlertAction?
    open private(set) var textFields: [UITextField]?

    /// On an iPad an action sheet is a popover; on an iPhone there is none.
    open var popoverPresentationController: UIPopoverPresentationController? {
        nil
    }

    open func addAction(_ action: UIAlertAction) {
        actions.append(action)
    }

    /// A text field under the message; alerts only.
    open func addTextField(configurationHandler: ((UITextField) -> Void)? = nil) {
        guard style == .alert else {
            fatalError("Text fields can only be added to an alert controller of style UIAlertControllerStyleAlert")
        }
        let field = UITextField()
        field.font = .preferredFont(forTextStyle: .footnote)
        field.borderStyle = .roundedRect
        textFields = (textFields ?? []) + [field]
        configurationHandler?(field)
    }

    override open func loadView() {
        view = AlertView(controller: self)
    }

    override func irisDidPresent() {
        view.layoutIfNeeded()
        if let field = textFields?.first {
            field.becomeFirstResponder()
        } else {
            super.irisDidPresent()
        }
    }

    /// An action's button was tapped: the alert goes, then the handler runs, as in UIKit.
    fileprivate func run(_ action: UIAlertAction) {
        guard action.isEnabled else { return }
        dismiss(animated: true) {
            action.handler?(action)
        }
    }
}

extension UIAlertController {
    public enum Style: Int, Sendable {
        case actionSheet = 0, alert
    }
}

@preconcurrency @MainActor
open class UIAlertAction: NSObject {
    public convenience init(title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)? = nil) {
        self.init()
        self.title = title
        self.style = style
        self.handler = handler
    }

    open private(set) var title: String?
    open private(set) var style = Style.default
    /// A disabled action's button is gray and does nothing.
    open var isEnabled = true {
        didSet { onChange?() }
    }

    fileprivate var handler: ((UIAlertAction) -> Void)?
    fileprivate var onChange: (() -> Void)?
}

extension UIAlertAction {
    public enum Style: Int, Sendable {
        case `default` = 0, cancel, destructive
    }
}

/// Where a popover points, on an iPad.
@preconcurrency @MainActor
open class UIPopoverPresentationController: NSObject {
    open var sourceView: UIView?
    open var sourceRect = CGRect.zero
    open var permittedArrowDirections = UIPopoverArrowDirection.any
}

public struct UIPopoverArrowDirection: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let up = UIPopoverArrowDirection(rawValue: 1 << 0)
    public static let down = UIPopoverArrowDirection(rawValue: 1 << 1)
    public static let left = UIPopoverArrowDirection(rawValue: 1 << 2)
    public static let right = UIPopoverArrowDirection(rawValue: 1 << 3)
    public static let any = UIPopoverArrowDirection(rawValue: 0xF)
    public static let unknown = UIPopoverArrowDirection(rawValue: .max)
}

// MARK: Drawing

/// Iris: the dimmed screen with the alert's card, or the action sheet's two cards, laid out
/// with iOS 17's sizes (as OpenSwiftUI's alerts, patch 0025).
@MainActor
private final class AlertView: UIView {
    private unowned let controller: UIAlertController
    private var isSheet: Bool {
        controller.preferredStyle == .actionSheet
    }

    private let card = UIView()
    private let cancelCard = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private var buttons: [(action: UIAlertAction, button: AlertButton)] = []
    private var separators: [UIView] = []

    /// The material behind the cards, in place of the blur.
    static let material = UIColor(red: 242 / 255, green: 242 / 255, blue: 242 / 255, alpha: 1)

    init(controller: UIAlertController) {
        self.controller = controller
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = UIColor(white: 0, alpha: 0.2)
        for card in [card, cancelCard] {
            card.backgroundColor = Self.material
            card.layer.cornerRadius = 14
            card.clipsToBounds = true
            addSubview(card)
        }
        cancelCard.backgroundColor = .systemBackground
        for label in [titleLabel, messageLabel] {
            label.numberOfLines = 0
            label.textAlignment = .center
            card.addSubview(label)
        }
        titleLabel.font = .preferredFont(forTextStyle: isSheet ? .footnote : .headline)
        if isSheet {
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .secondaryLabel
            messageLabel.textColor = .secondaryLabel
        }
        messageLabel.font = .preferredFont(forTextStyle: .footnote)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The actions in the order iOS shows them: in an alert of two, the cancel one on the
    /// left; else the cancel one last.
    private var orderedActions: [UIAlertAction] {
        let others = controller.actions.filter { $0.style != .cancel }
        let cancel = controller.actions.filter { $0.style == .cancel }
        return !isSheet && controller.actions.count == 2 ? cancel + others : others + cancel
    }

    private func makeButtons() {
        guard buttons.map(\.action) != orderedActions else { return }
        for (_, button) in buttons {
            button.removeFromSuperview()
        }
        buttons = orderedActions.map { action in
            let button = AlertButton()
            button.addAction(UIAction { [unowned controller] _ in controller.run(action) }, for: .touchUpInside)
            action.onChange = { [unowned self] in setNeedsLayout() }
            (isSheet && action.style == .cancel ? cancelCard : card).addSubview(button)
            return (action, button)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        makeButtons()
        titleLabel.text = controller.title
        messageLabel.text = controller.message
        let preferred = controller.preferredAction ?? controller.actions.first { $0.style == .cancel }
        for (action, button) in buttons {
            let color: UIColor = !action.isEnabled ? .tertiaryLabel : action.style == .destructive ? .systemRed : tintColor
            let size: CGFloat = isSheet ? 20 : 17
            button.label.text = action.title
            button.label.font = .systemFont(ofSize: size, weight: action === preferred ? .semibold : .regular)
            button.label.textColor = color
            button.isEnabled = action.isEnabled
        }
        isSheet ? layOutSheet() : layOutAlert()
    }

    /// Hairlines, made again at each layout.
    private func separator(_ frame: CGRect, in view: UIView) {
        let line = UIView(frame: frame)
        line.backgroundColor = .separator
        line.isUserInteractionEnabled = false
        view.addSubview(line)
        separators.append(line)
    }

    /// The title and message, centered, and the text fields under them, from `top` in a card
    /// `width` wide; returns where they end.
    private func layOutText(width: CGFloat, top: CGFloat, spacing: CGFloat, bottom: CGFloat) -> CGFloat {
        var y = top
        for label in [titleLabel, messageLabel] {
            label.isHidden = label.text?.isEmpty ?? true
            guard !label.isHidden else { continue }
            if y > top {
                y += spacing
            }
            let height = label.sizeThatFits(CGSize(width: width - 32, height: .greatestFiniteMagnitude)).height
            label.frame = CGRect(x: 16, y: y, width: width - 32, height: height)
            y += height
        }
        for (index, field) in (controller.textFields ?? []).enumerated() {
            if field.superview !== card {
                card.addSubview(field)
            }
            y += index == 0 ? (y > top ? 16 : 0) : 6
            field.frame = CGRect(x: 16, y: y, width: width - 32, height: field.intrinsicContentSize.height)
            y = field.frame.maxY
        }
        return y + bottom
    }

    /// A 270-point card in the middle: the text, then 44-point buttons under a hairline,
    /// two side by side.
    private func layOutAlert() {
        separators.forEach { $0.removeFromSuperview() }
        separators = []
        cancelCard.isHidden = true
        let width: CGFloat = 270
        let hasText = !(titleLabel.text?.isEmpty ?? true) || !(messageLabel.text?.isEmpty ?? true)
        var y = hasText ? layOutText(width: width, top: 19, spacing: 4, bottom: 17) : 0
        if buttons.count == 2 {
            separator(CGRect(x: 0, y: y, width: width, height: 0.33), in: card)
            for (index, (_, button)) in buttons.enumerated() {
                button.frame = CGRect(x: CGFloat(index) * width / 2, y: y + 0.33, width: width / 2, height: 44)
            }
            separator(CGRect(x: width / 2, y: y + 0.33, width: 0.33, height: 44), in: card)
            y += 44.33
        } else {
            for (_, button) in buttons {
                separator(CGRect(x: 0, y: y, width: width, height: 0.33), in: card)
                button.frame = CGRect(x: 0, y: y + 0.33, width: width, height: 44)
                y += 44.33
            }
        }
        card.frame = CGRect(x: (bounds.width - width) / 2, y: (bounds.height - y) / 2, width: width, height: y)
    }

    /// Cards 8 points from the screen's sides, on the bottom of the safe area: the title and
    /// message in gray, 57-point buttons, and the cancel button apart.
    private func layOutSheet() {
        separators.forEach { $0.removeFromSuperview() }
        separators = []
        let width = bounds.width - 16
        let hasText = !(titleLabel.text?.isEmpty ?? true) || !(messageLabel.text?.isEmpty ?? true)
        var y = hasText ? layOutText(width: width, top: 14, spacing: 4, bottom: 14) : 0
        for (action, button) in buttons where action.style != .cancel {
            if y > 0 {
                separator(CGRect(x: 0, y: y, width: width, height: 0.33), in: card)
                y += 0.33
            }
            button.frame = CGRect(x: 0, y: y, width: width, height: 57)
            y += 57
        }
        let cancel = buttons.first { $0.action.style == .cancel }?.button
        cancelCard.isHidden = cancel == nil
        let bottom = bounds.height - max(window?.safeAreaInsets.bottom ?? 0, 8)
        var cardBottom = bottom
        if let cancel {
            cancel.frame = CGRect(x: 0, y: 0, width: width, height: 57)
            cancelCard.frame = CGRect(x: 8, y: bottom - 57, width: width, height: 57)
            cardBottom = cancelCard.frame.minY - 8
        }
        card.frame = CGRect(x: 8, y: cardBottom - y, width: width, height: y)
    }

    /// A tap on the dimmed screen around an action sheet cancels it.
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isSheet, let cancel = controller.actions.first(where: { $0.style == .cancel }) else { return }
        controller.run(cancel)
    }
}

/// Iris: an action's button: its title, and gray while pressed.
@MainActor
private final class AlertButton: UIControl {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(white: 0, alpha: 0.1) : nil }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 8, dy: 0)
    }
}
