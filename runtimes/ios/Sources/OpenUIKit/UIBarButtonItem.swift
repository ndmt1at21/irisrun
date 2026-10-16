import Foundation

/// What a bar shows an item with: its title, image and whether it is enabled. Bars make views of
/// their own for their items, and show changes to them.
@preconcurrency @MainActor
open class UIBarItem: NSObject {
    public override init() {
        super.init()
    }

    open var isEnabled = true {
        didSet { irisChanged() }
    }

    open var title: String? {
        didSet { irisChanged() }
    }

    open var image: UIImage? {
        didSet { irisChanged() }
    }

    open var landscapeImagePhone: UIImage?
    open var largeContentSizeImage: UIImage?
    open var imageInsets = UIEdgeInsets.zero
    open var tag = 0

    open var accessibilityLabel: String? {
        didSet { irisChanged() }
    }

    private var titleAttributes: [UIControl.State: [NSAttributedString.Key: Any]] = [:]

    /// The font and color of the title, by state.
    open func setTitleTextAttributes(_ attributes: [NSAttributedString.Key: Any]?, for state: UIControl.State) {
        titleAttributes[state] = attributes
        irisChanged()
    }

    open func titleTextAttributes(for state: UIControl.State) -> [NSAttributedString.Key: Any]? {
        titleAttributes[state]
    }

    /// Iris: the bar that shows the item.
    weak var irisBar: (any IrisItemBar)?

    func irisChanged() {
        irisBar?.irisItemsDidChange()
    }
}

/// Iris: a bar that shows items, told when one changes.
@MainActor
protocol IrisItemBar: AnyObject {
    func irisItemsDidChange()
}

/// A button in a navigation bar: a title, an image, a system item or a view of the app's. A tap
/// runs its primary action, or sends its action to its target, or up the responder chain from the
/// first responder without one, with the item as the sender.
// ponytail: no menus (`menu`, `UIMenu`) and no toolbars; spaces only space items out.
@preconcurrency @MainActor
open class UIBarButtonItem: UIBarItem {
    public override init() {
        super.init()
    }

    public convenience init(title: String?, style: UIBarButtonItem.Style, target: Any?, action: Selector?) {
        self.init()
        self.title = title
        self.style = style
        self.target = target as AnyObject?
        self.action = action
    }

    public convenience init(image: UIImage?, style: UIBarButtonItem.Style, target: Any?, action: Selector?) {
        self.init()
        self.image = image
        self.style = style
        self.target = target as AnyObject?
        self.action = action
    }

    public convenience init(image: UIImage?, landscapeImagePhone: UIImage?, style: UIBarButtonItem.Style, target: Any?, action: Selector?) {
        self.init(image: image, style: style, target: target, action: action)
        self.landscapeImagePhone = landscapeImagePhone
    }

    /// A system item: its title or symbol, in UIKit's English.
    public convenience init(barButtonSystemItem systemItem: UIBarButtonItem.SystemItem, target: Any?, action: Selector?) {
        self.init()
        self.systemItem = systemItem
        let (title, symbol, label) = systemItem.content
        self.title = title
        image = symbol.flatMap { UIImage(systemName: $0) }
        accessibilityLabel = label
        style = systemItem == .done || systemItem == .save ? .done : .plain
        self.target = target as AnyObject?
        self.action = action
    }

    public convenience init(systemItem: UIBarButtonItem.SystemItem, primaryAction: UIAction? = nil) {
        self.init(barButtonSystemItem: systemItem, target: nil, action: nil)
        self.primaryAction = primaryAction
    }

    public convenience init(customView: UIView) {
        self.init()
        self.customView = customView
    }

    /// Shows the action's title and image, and runs it.
    public convenience init(title: String? = nil, image: UIImage? = nil, primaryAction: UIAction? = nil) {
        self.init()
        self.title = title ?? primaryAction?.title
        self.image = image ?? primaryAction?.image
        self.primaryAction = primaryAction
    }

    public convenience init(primaryAction: UIAction?) {
        self.init(title: nil, image: nil, primaryAction: primaryAction)
    }

    public class func fixedSpace(_ width: CGFloat) -> UIBarButtonItem {
        let item = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        item.width = width
        return item
    }

    public class func flexibleSpace() -> UIBarButtonItem {
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }

    /// Done items show their title in semibold.
    open var style = Style.plain {
        didSet { irisChanged() }
    }

    open weak var target: AnyObject?
    open var action: Selector?

    open var customView: UIView? {
        didSet { irisChanged() }
    }

    /// The width of a fixed space, or of the item's view when not zero.
    open var width: CGFloat = 0 {
        didSet { irisChanged() }
    }

    open var primaryAction: UIAction?

    /// The tint of the item's title and image; the bar's unless set.
    open var tintColor: UIColor? {
        didSet { irisChanged() }
    }

    open var isSelected = false
    open var possibleTitles: Set<String>?

    /// Iris: the system item the item was made as.
    private(set) var systemItem: SystemItem?

    /// Iris: what UIKit's own items do when tapped, such as `editButtonItem`.
    var irisAction: (() -> Void)?

    /// Iris: a tap on the item's view, as UIKit's button for it sends it.
    func irisTrigger(from view: UIView?) {
        if let irisAction {
            irisAction()
        } else if let primaryAction {
            primaryAction.sender = self
            primaryAction.handler(primaryAction)
            primaryAction.sender = nil
        } else if let action {
            let receiver = target ?? (UIResponder.first ?? view)?.target(forAction: action, withSender: self) as AnyObject?
            UIApplication.shared.sendAction(action, to: receiver, from: self, for: nil)
        }
    }

    /// Iris: the view a bar shows the item with: the custom view, or a system button with the
    /// title (17 points, semibold for done items) or the image in the tint.
    func irisMakeView() -> UIView {
        if let customView { return customView }
        let button = systemItem == .close ? UIButton(type: .close) : UIButton(type: .system)
        if systemItem != .close {
            let attributes = titleTextAttributes(for: .normal)
            button.titleLabel?.font = attributes?[.font] as? UIFont ?? .systemFont(ofSize: 17, weight: style == .done ? .semibold : .regular)
            button.setTitleColor(attributes?[.foregroundColor] as? UIColor, for: .normal)
            button.setTitle(image == nil ? title : nil, for: .normal)
            button.setImage(image, for: .normal)
        }
        button.tintColor = tintColor
        button.isEnabled = isEnabled
        button.accessibilityLabel = accessibilityLabel ?? title
        button.addAction(UIAction { [weak self, weak button] _ in self?.irisTrigger(from: button) }, for: .primaryActionTriggered)
        return button
    }
}

extension UIBarButtonItem {
    public enum Style: Int, Sendable {
        case plain = 0
        @available(*, deprecated, message: "Use UIBarButtonItem.Style.plain when minimum deployment target is iOS 8.0 or later")
        case bordered = 1
        case done = 2
    }

    public enum SystemItem: Int, Sendable {
        case done = 0, cancel, edit, save, add, flexibleSpace, fixedSpace, compose, reply, action, organize, bookmarks
        case search, refresh, stop, camera, trash, play, pause, rewind, fastForward, undo, redo, pageCurl, close

        /// Iris: the title, or the SF Symbol, and what VoiceOver reads, as UIKit shows the item.
        // ponytail: in English, whatever the app's languages; the symbols Iris draws are few
        // (`IrisSymbol`), the others show blank.
        var content: (title: String?, symbol: String?, label: String?) {
            switch self {
            case .done: ("Done", nil, nil)
            case .cancel: ("Cancel", nil, nil)
            case .edit: ("Edit", nil, nil)
            case .save: ("Save", nil, nil)
            case .undo: ("Undo", nil, nil)
            case .redo: ("Redo", nil, nil)
            case .add: (nil, "plus", "Add")
            case .close: (nil, nil, "Close")
            case .compose: (nil, "square.and.pencil", "Compose")
            case .reply: (nil, "arrowshape.turn.up.left", "Reply")
            case .action: (nil, "square.and.arrow.up", "Share")
            case .organize: (nil, "folder", "Organize")
            case .bookmarks: (nil, "book", "Bookmarks")
            case .search: (nil, "magnifyingglass", "Search")
            case .refresh: (nil, "arrow.clockwise", "Refresh")
            case .stop: (nil, "xmark", "Stop")
            case .camera: (nil, "camera", "Camera")
            case .trash: (nil, "trash", "Delete")
            case .play: (nil, "play.fill", "Play")
            case .pause: (nil, "pause.fill", "Pause")
            case .rewind: (nil, "backward.fill", "Rewind")
            case .fastForward: (nil, "forward.fill", "Fast Forward")
            case .pageCurl: (nil, "doc", nil)
            case .flexibleSpace, .fixedSpace: (nil, nil, nil)
            }
        }
    }
}
