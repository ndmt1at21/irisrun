import Foundation
import IrisHost

/// A container that shows one of its view controllers at a time, picked with the tab bar at the
/// bottom: the selected one's view fills the container's view, its safe area clear of the bar,
/// and a tap on its tab again pops a navigation controller to its root. Every view controller is
/// a child; switching tabs gives them UIKit's appearance callbacks, without an animation.
// ponytail: the More tab: past five view controllers the bar shows the first five; no
// customizing, and no animated switches.
@preconcurrency @MainActor
open class UITabBarController: UIViewController, UITabBarDelegate {
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private let bar = UITabBar()
    private var controllers: [UIViewController] = []
    private var selected = NSNotFound

    open weak var delegate: (any UITabBarControllerDelegate)?

    open var tabBar: UITabBar {
        bar
    }

    open var viewControllers: [UIViewController]? {
        get { controllers.isEmpty ? nil : controllers }
        set { setViewControllers(newValue, animated: false) }
    }

    /// Takes new view controllers, reselecting the one selected if it is still there, else the
    /// one at the same index, else the first, as UIKit does.
    open func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        let new = viewControllers ?? []
        let old = controllers
        let removed = old.filter { controller in !new.contains { $0 === controller } }
        let added = new.filter { controller in !old.contains { $0 === controller } }
        for controller in removed {
            controller.willMove(toParent: nil)
        }
        for controller in added {
            addChild(controller)
        }
        let previous = selectedViewController
        controllers = new
        irisItemsDidChange()
        let index = previous.flatMap { previous in new.firstIndex { $0 === previous } } ?? (new.indices.contains(selected) ? selected : new.isEmpty ? NSNotFound : 0)
        select(index, from: previous)
        for controller in removed {
            controller.removeFromParent()
        }
        for controller in added {
            controller.didMove(toParent: self)
        }
    }

    open var selectedIndex: Int {
        get { selected }
        set { select(newValue, from: selectedViewController) }
    }

    open var selectedViewController: UIViewController? {
        get { controllers.indices.contains(selected) ? controllers[selected] : nil }
        set {
            if let index = newValue.flatMap({ controller in controllers.firstIndex { $0 === controller } }) {
                select(index, from: selectedViewController)
            }
        }
    }

    // MARK: The view

    open override func loadView() {
        let container = UILayoutContainerView(frame: UIScreen.main.bounds)
        container.layOut = { [unowned self] in layOut() }
        bar.delegate = self
        bar.irisTabBarController = self
        container.addSubview(bar)
        view = container
        if let shown = selectedViewController {
            container.insertSubview(shown.view, belowSubview: bar)
            bar.isHidden = (shown as? UINavigationController)?.irisHidesBottomBar == true
        }
    }

    /// The bar at the bottom, 49 points above the bottom of the safe area (the home indicator)
    /// and reaching down under it; the selected view fills the view, each view controller's safe
    /// area clear of the bar unless its stack hides it.
    private func layOut() {
        let bounds = view.bounds, bottom = view.safeAreaInsets.bottom
        bar.frame = CGRect(x: 0, y: bounds.height - 49 - bottom, width: bounds.width, height: 49 + bottom)
        for child in controllers {
            if child.viewIfLoaded?.superview === view {
                child.view.frame = bounds
            }
            let hidesBar = (child as? UINavigationController)?.irisHidesBottomBar == true
            child.irisBarInsets = UIEdgeInsets(top: 0, left: 0, bottom: hidesBar ? 0 : 49, right: 0)
        }
    }

    /// Iris: a view controller's tab bar item changed or was replaced.
    func irisItemsDidChange() {
        bar.setItems(controllers.map(\.tabBarItem), animated: false)
        bar.selectedItem = selectedViewController?.tabBarItem
    }

    // MARK: Selecting

    /// Shows the view controller at `index` in place of `old`, the one selected, with UIKit's
    /// appearance callbacks and no animation.
    private func select(_ index: Int, from old: UIViewController?) {
        selected = controllers.indices.contains(index) ? index : controllers.isEmpty ? NSNotFound : selected
        let new = selectedViewController
        bar.selectedItem = new?.tabBarItem
        guard new !== old, isViewLoaded else { return }
        let onScreen = irisAppearance == .appeared || irisAppearance == .appearing
        UIViewController.irisTransition(
            from: onScreen ? old.map { [$0] } ?? [] : [], to: onScreen ? new.map { [$0] } ?? [] : [], animated: false,
            prepare: { [self] in
                if let new {
                    new.view.frame = view.bounds
                    view.insertSubview(new.view, belowSubview: bar)
                }
                bar.isHidden = (new as? UINavigationController)?.irisHidesBottomBar == true
                view.setNeedsLayout()
            },
            finish: { [self] in
                if let oldView = old?.viewIfLoaded, old !== selectedViewController, oldView.superview === view {
                    oldView.removeFromSuperview()
                }
            }
        )
    }

    /// The tab bar's item was tapped: unless the delegate says no, its view controller shows, or
    /// pops to its root if it is a navigation controller already showing; the delegate hears after.
    open func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let index = controllers.firstIndex(where: { $0.tabBarItem === item }) else { return }
        let controller = controllers[index]
        guard delegate?.tabBarController(self, shouldSelect: controller) ?? true else {
            bar.selectedItem = selectedViewController?.tabBarItem
            return
        }
        if index == selected {
            (controller as? UINavigationController)?.popToRootViewController(animated: true)
        } else {
            select(index, from: selectedViewController)
        }
        delegate?.tabBarController(self, didSelect: controller)
    }
}

/// What a tab bar controller's delegate hears as the person picks tabs. Every method is optional.
@preconcurrency @MainActor
public protocol UITabBarControllerDelegate: NSObjectProtocol {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
}

extension UITabBarControllerDelegate {
    public func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        true
    }

    public func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {}
}

/// What a tab bar's delegate hears when the person taps an item.
@preconcurrency @MainActor
public protocol UITabBarDelegate: NSObjectProtocol {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem)
}

extension UITabBarDelegate {
    public func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {}
}

// MARK: - Items

/// A tab: its title and image, the image shown while selected, and a badge.
@preconcurrency @MainActor
open class UITabBarItem: UIBarItem {
    public override init() {
        super.init()
    }

    public convenience init(title: String?, image: UIImage?, tag: Int) {
        self.init()
        self.title = title
        self.image = image
        self.tag = tag
    }

    public convenience init(title: String?, image: UIImage?, selectedImage: UIImage?) {
        self.init(title: title, image: image, tag: 0)
        self.selectedImage = selectedImage
    }

    /// A system tab, with its title in UIKit's English and its symbol.
    public convenience init(tabBarSystemItem systemItem: UITabBarItem.SystemItem, tag: Int) {
        let (title, symbol) = systemItem.content
        self.init(title: title, image: UIImage(systemName: symbol), tag: tag)
    }

    open var selectedImage: UIImage? {
        didSet { irisChanged() }
    }

    /// Text in a red oval at the top right of the image; empty for a dot.
    open var badgeValue: String? {
        didSet { irisChanged() }
    }

    open var badgeColor: UIColor? {
        didSet { irisChanged() }
    }

    public enum SystemItem: Int, Sendable {
        case more = 0, favorites, featured, topRated, recents, contacts, history, bookmarks, search, downloads, mostRecent, mostViewed

        var content: (title: String, symbol: String) {
            switch self {
            case .more: ("More", "ellipsis")
            case .favorites: ("Favorites", "star")
            case .featured: ("Featured", "star")
            case .topRated: ("Top Rated", "star")
            case .recents: ("Recents", "clock.fill")
            case .contacts: ("Contacts", "person.crop.circle.fill")
            case .history: ("History", "clock.fill")
            case .bookmarks: ("Bookmarks", "book.fill")
            case .search: ("Search", "magnifyingglass")
            case .downloads: ("Downloads", "arrow.down.circle.fill")
            case .mostRecent: ("Most Recent", "clock.fill")
            case .mostViewed: ("Most Viewed", "list.number")
            }
        }
    }
}

/// A tab bar's look; its background as a bar appearance's.
// ponytail: no item appearances (stackedLayoutAppearance and the like).
@preconcurrency @MainActor
open class UITabBarAppearance: UIBarAppearance {
    public required init(barAppearance: UIBarAppearance) {
        super.init(barAppearance: barAppearance)
    }

    public override init() {
        super.init()
    }
}

// MARK: - The bar

/// The bar at the bottom of a tab bar controller's view: its items side by side, each an image
/// over its title (10 points, medium), in the tint while selected and gray otherwise, with a
/// badge. The background is the standard appearance's, or the scroll edge one (transparent unless
/// set) while the content's scroll view is at its bottom, or if there is none, as in iOS 15 and
/// later.
@preconcurrency @MainActor
open class UITabBar: UIView, IrisItemBar {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        background.isUserInteractionEnabled = false
        addSubview(background)
        addSubview(shadow)
    }

    open weak var delegate: (any UITabBarDelegate)?

    open private(set) var items: [UITabBarItem]?

    open func setItems(_ items: [UITabBarItem]?, animated: Bool) {
        self.items = items
        for item in items ?? [] {
            item.irisBar = self
        }
        irisItemsDidChange()
    }

    open var selectedItem: UITabBarItem? {
        didSet { setNeedsLayout() }
    }

    /// The color of the items that are not selected; gray unless set.
    open var unselectedItemTintColor: UIColor? {
        didSet { setNeedsLayout() }
    }

    open var standardAppearance = UITabBarAppearance() {
        didSet { setNeedsLayout() }
    }

    /// Used while the content is scrolled to its bottom; nil for the standard appearance with a
    /// transparent background.
    open var scrollEdgeAppearance: UITabBarAppearance? {
        didSet { setNeedsLayout() }
    }

    open var barTintColor: UIColor? {
        get { standardAppearance.backgroundColor }
        set {
            standardAppearance.backgroundColor = newValue
            setNeedsLayout()
        }
    }

    open var isTranslucent = true {
        didSet {
            if isTranslucent { standardAppearance.configureWithDefaultBackground() } else { standardAppearance.configureWithOpaqueBackground() }
            setNeedsLayout()
        }
    }

    /// Iris: the tab bar controller whose bar this is.
    weak var irisTabBarController: UITabBarController?

    /// The content's scroll view, if any, is scrolled to its bottom.
    private var isAtScrollEdge: Bool {
        var controller = irisTabBarController?.selectedViewController
        if let navigationController = controller as? UINavigationController {
            controller = navigationController.topViewController
        }
        guard let scrollView = controller?.contentScrollView(for: .bottom) else { return true }
        return scrollView.contentOffset.y >= scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height - 0.5
    }

    // MARK: Iris: views

    private let background = _UIBarBackground()
    private let shadow = _UIBarBackgroundShadowView()
    private var buttons: [UITabBarButton] = []
    private var needsRebuild = true

    func irisItemsDidChange() {
        needsRebuild = true
        setNeedsLayout()
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: 49 + safeAreaInsets.bottom)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        if needsRebuild {
            needsRebuild = false
            for button in buttons {
                button.removeFromSuperview()
            }
            // ponytail: past five items the More tab would come; the first five show.
            buttons = (items ?? []).prefix(5).map { item in
                let button = UITabBarButton(item: item)
                button.addAction(UIAction { [weak self] _ in self?.tapped(item) }, for: .touchUpInside)
                addSubview(button)
                return button
            }
        }
        let standard = standardAppearance
        let appearance = isAtScrollEdge ? scrollEdgeAppearance ?? {
            let transparent = UITabBarAppearance(barAppearance: standard)
            transparent.configureWithTransparentBackground()
            return transparent
        }() : standard
        background.frame = bounds
        background.backgroundColor = appearance.irisBackground
        shadow.frame = CGRect(x: 0, y: -1 / UIScreen.main.scale, width: bounds.width, height: 1 / UIScreen.main.scale)
        shadow.backgroundColor = appearance.shadowColor
        shadow.isHidden = appearance.shadowColor.map { $0.cgColor.alpha == 0 } ?? true
        let width = bounds.width / CGFloat(max(buttons.count, 1))
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: 49)
            button.show(selected: button.item === selectedItem, color: button.item === selectedItem ? tintColor : unselectedItemTintColor ?? .systemGray)
        }
    }

    private func tapped(_ item: UITabBarItem) {
        selectedItem = item
        delegate?.tabBar(self, didSelect: item)
    }
}

/// Iris: a tab of a tab bar, with UIKit's class name: the image centered over the title, 2
/// points apart, the pair in the middle of the 49-point bar; the badge at the image's top right.
@MainActor
private final class UITabBarButton: UIControl {
    let item: UITabBarItem
    private let image = UITabBarSwappableImageView()
    private let label = UITabBarButtonLabel()
    private let badge = _UIBadgeView()

    init(item: UITabBarItem) {
        self.item = item
        super.init(frame: .zero)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textAlignment = .center
        label.text = item.title
        badge.isHidden = item.badgeValue == nil
        badge.text = item.badgeValue
        badge.backgroundColor = item.badgeColor ?? .systemRed
        for view in [image, label, badge] as [UIView] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        accessibilityLabel = item.accessibilityLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Images show as templates in the color, unless always original.
    func show(selected: Bool, color: UIColor) {
        let shown = selected ? item.selectedImage ?? item.image : item.image
        image.image = shown.map { $0.renderingMode == .alwaysOriginal ? $0 : $0.withRenderingMode(.alwaysTemplate) }
        image.tintColor = color
        label.textColor = color
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let imageSize = image.image?.size ?? .zero
        let titleHeight = item.title == nil ? 0 : ceil(label.intrinsicContentSize.height)
        let gap: CGFloat = imageSize.height > 0 && titleHeight > 0 ? 2 : 0
        let top = (bounds.height - imageSize.height - gap - titleHeight) / 2
        image.frame = CGRect(x: (bounds.width - imageSize.width) / 2, y: top, width: imageSize.width, height: imageSize.height)
        label.frame = CGRect(x: 0, y: top + imageSize.height + gap, width: bounds.width, height: titleHeight)
        let badgeWidth = max(18, (badge.text ?? "").isEmpty ? 10 : badge.textWidth + 10)
        let badgeHeight: CGFloat = (badge.text ?? "").isEmpty ? 10 : 18
        badge.frame = CGRect(x: image.frame.midX + 4, y: max(image.frame.minY - 3, 0), width: (badge.text ?? "").isEmpty ? 10 : badgeWidth, height: badgeHeight)
        badge.layer.cornerRadius = badgeHeight / 2
    }
}

@MainActor
private final class UITabBarSwappableImageView: UIImageView {}

@MainActor
private final class UITabBarButtonLabel: UILabel {}

/// Iris: a tab's badge: white text, 13 points, on its color.
@MainActor
private final class _UIBadgeView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    var textWidth: CGFloat {
        ceil(label.intrinsicContentSize.width)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
    }
}
