import Foundation
import IrisHost
import IrisRender

/// Manages a view: makes it when it is first asked for, with `loadView`, then calls
/// `viewDidLoad`. It hears its view appear and disappear, contains child view controllers, and
/// presents other view controllers over its window.
// ponytail: nibs come with step 6; transitioning delegates and custom presentation controllers
// are not used.
@preconcurrency @MainActor
open class UIViewController: UIResponder, @preconcurrency NSCoding {
    public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        nibName = nibNameOrNil
        nibBundle = nibBundleOrNil
        super.init()
    }

    /// View controllers come from code only until storyboards are read (P1-16, step 6).
    public required init?(coder: NSCoder) {
        super.init()
    }

    public override convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    open func encode(with coder: NSCoder) {}

    open private(set) var nibName: String?
    open private(set) var nibBundle: Bundle?

    /// What bars show for the view controller: setting it sets its navigation item's and tab bar
    /// item's titles, once they are made, as in UIKit.
    open var title: String? {
        didSet {
            ownNavigationItem?.title = title
            ownTabBarItem?.title = title
        }
    }

    private var loadedView: UIView?

    /// Loads the view the first time it is asked for.
    open var view: UIView! {
        get {
            loadViewIfNeeded()
            return loadedView
        }
        set {
            loadedView?.viewController = nil
            loadedView = newValue
            newValue?.viewController = self
        }
    }

    open var viewIfLoaded: UIView? {
        loadedView
    }

    open var isViewLoaded: Bool {
        loadedView != nil
    }

    /// Makes a plain view the size of the screen; override it to make the view yourself.
    open func loadView() {
        view = UIView(frame: UIScreen.main.bounds)
    }

    open func loadViewIfNeeded() {
        guard loadedView == nil else { return }
        loadView()
        if loadedView == nil {
            view = UIView(frame: UIScreen.main.bounds)
        }
        viewDidLoad()
    }

    open func viewDidLoad() {}

    /// Called before and after the view lays out its subviews.
    open func viewWillLayoutSubviews() {}

    open func viewDidLayoutSubviews() {}

    // MARK: Auto Layout

    /// The update-constraints pass calls it for the view; overrides call super last.
    open func updateViewConstraints() {
        viewIfLoaded?.updateConstraints()
    }

    /// The view's margins are at least the system minimum unless this is false.
    open var viewRespectsSystemMinimumLayoutMargins = true {
        didSet { LayerCommit.schedule() }
    }

    /// An iPhone's in portrait: no margins at the top and bottom, 16 points at the sides.
    open var systemMinimumLayoutMargins: NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
    }

    open func viewLayoutMarginsDidChange() {}

    open func viewSafeAreaInsetsDidChange() {}

    /// Insets the view's safe area further than the bars and the screen around it do, as for a
    /// bar of the app's own.
    open var additionalSafeAreaInsets = UIEdgeInsets.zero {
        didSet { irisSafeAreaDidChange() }
    }

    /// Iris: what a container's bars cover of the view, as a navigation bar its top: added to
    /// the safe area as `additionalSafeAreaInsets` is.
    var irisBarInsets = UIEdgeInsets.zero {
        didSet {
            if irisBarInsets != oldValue { irisSafeAreaDidChange() }
        }
    }

    var irisAddedSafeArea: UIEdgeInsets {
        let (app, bars) = (additionalSafeAreaInsets, irisBarInsets)
        return UIEdgeInsets(top: app.top + bars.top, left: app.left + bars.left, bottom: app.bottom + bars.bottom, right: app.right + bars.right)
    }

    /// The views inside lay out anew, as views whose layout reads their safe area do.
    private func irisSafeAreaDidChange() {
        viewIfLoaded?.forEachInTree { $0.setNeedsLayout() }
    }

    /// The view controller that presented this one, else the view's superview.
    override open var next: UIResponder? {
        presenter ?? loadedView?.superview
    }

    /// The size the view controller's content wants, for a container that sizes it.
    // ponytail: containers aren't told when it changes (preferredContentSizeDidChange) yet.
    open var preferredContentSize = CGSize.zero

    // MARK: Appearance

    /// Called before the view goes on screen, and after; `animated` says whether it comes in an
    /// animated transition. Overrides call super, as in UIKit.
    open func viewWillAppear(_ animated: Bool) {}

    open func viewDidAppear(_ animated: Bool) {}

    /// Called before the view goes off screen, and after.
    open func viewWillDisappear(_ animated: Bool) {}

    open func viewDidDisappear(_ animated: Bool) {}

    /// Whether the view controller passes its appearance callbacks on to the children whose
    /// views are in its view, as UIKit does unless a container does it itself.
    open var shouldAutomaticallyForwardAppearanceMethods: Bool {
        true
    }

    /// Iris: how far the view is on its way on screen or off it, as UIKit keeps track.
    enum Appearance {
        case disappeared, appearing, appeared, disappearing
    }

    private(set) var irisAppearance = Appearance.disappeared
    private(set) var appearanceAnimated = false
    /// The appearance transition began as the view went into a window or out of one.
    private var appearsWithWindow = false

    /// Starts the view's appearing or disappearing, as a container does for a child: viewWillAppear
    /// or viewWillDisappear, then the same for the children whose views are in the view. A call
    /// that changes nothing does nothing, as UIKit only logs unbalanced ones.
    open func beginAppearanceTransition(_ isAppearing: Bool, animated: Bool) {
        switch (irisAppearance, isAppearing) {
        case (.disappeared, true), (.disappearing, true): irisAppearance = .appearing
        case (.appeared, false), (.appearing, false): irisAppearance = .disappearing
        default: return
        }
        appearanceAnimated = animated
        if isAppearing {
            viewWillAppear(animated)
        } else {
            viewWillDisappear(animated)
        }
        for child in forwardedChildren {
            child.beginAppearanceTransition(isAppearing, animated: animated)
        }
    }

    /// Ends it: viewDidAppear or viewDidDisappear, then the children's.
    open func endAppearanceTransition() {
        switch irisAppearance {
        case .appearing:
            irisAppearance = .appeared
            viewDidAppear(appearanceAnimated)
        case .disappearing:
            irisAppearance = .disappeared
            viewDidDisappear(appearanceAnimated)
        default:
            return
        }
        for child in forwardedChildren {
            child.endAppearanceTransition()
        }
    }

    private var forwardedChildren: [UIViewController] {
        guard shouldAutomaticallyForwardAppearanceMethods, let view = viewIfLoaded else { return [] }
        return children.filter { $0.viewIfLoaded?.isDescendant(of: view) == true }
    }

    /// Iris: the view goes into a window or out of one. Outside a transition, as when a container
    /// on screen adds a child's view or takes it away, the child appears or disappears with it,
    /// unless its parent forwards nothing, as in UIKit; in the parent's own transition, the child
    /// ends appearing with the parent.
    func irisViewWillMove(toWindow window: UIWindow?) {
        guard let parent, parent.shouldAutomaticallyForwardAppearanceMethods else { return }
        if window != nil, irisAppearance == .disappeared, parent.irisAppearance == .appearing || parent.irisAppearance == .appeared {
            appearsWithWindow = parent.irisAppearance == .appeared
            beginAppearanceTransition(true, animated: appearsWithWindow ? false : parent.appearanceAnimated)
        } else if window == nil, irisAppearance == .appeared, parent.irisAppearance == .appeared {
            appearsWithWindow = true
            beginAppearanceTransition(false, animated: false)
        }
    }

    func irisViewDidMoveToWindow() {
        guard appearsWithWindow else { return }
        appearsWithWindow = false
        endAppearanceTransition()
    }

    /// Iris: one appearance transition, the place that presenting, dismissing and changing a
    /// window's root view controller go through, and that pushing, popping and switching tabs
    /// can: `disappearing` then `appearing` hear viewWill…, their views loaded first; `prepare`
    /// makes the view changes that come before the animation, such as putting the new view in,
    /// and `animations` run in an animation of `duration`. Once it is over, `finish` makes the last
    /// changes, such as taking the old view out, the view controllers hear viewDid… —
    /// `disappearing` first, or `appearing` first with `appearingEndsFirst` as UIKit's modal
    /// presentations have it — and `completion` runs. Without an animation, as also in a script,
    /// which shows where animations end, everything up to `finish` happens at once, and the rest
    /// on the main queue's next turn, as UIKit runs it once the transaction is committed.
    static func irisTransition(
        from disappearing: [UIViewController], to appearing: [UIViewController], animated: Bool,
        duration: TimeInterval = 0, options: UIView.AnimationOptions = [], appearingEndsFirst: Bool = false,
        prepare: () -> Void = {}, animations: @escaping () -> Void = {}, finish: @escaping () -> Void = {},
        completion: @escaping () -> Void = {}
    ) {
        for controller in appearing {
            controller.loadViewIfNeeded()
        }
        for controller in disappearing {
            controller.beginAppearanceTransition(false, animated: animated)
        }
        for controller in appearing {
            controller.beginAppearanceTransition(true, animated: animated)
        }
        prepare()
        let animates = animated && irisAnimates && duration > 0
        UIView.animate(withDuration: animates ? duration : 0, delay: 0, options: options, animations: animations) { _ in
            if animates {
                finish()
            }
            for controller in appearingEndsFirst ? appearing + disappearing : disappearing + appearing {
                controller.endAppearanceTransition()
            }
            completion()
        }
        if !animates {
            finish()
        }
    }

    // MARK: Containment

    open private(set) var children: [UIViewController] = []

    open private(set) weak var parent: UIViewController?

    /// True from `addChild(_:)` until `didMove(toParent:)`, as while a container adds the view
    /// controller and shows its view.
    open private(set) var isMovingToParent = false

    /// True from `willMove(toParent: nil)` until `removeFromParent()`.
    open private(set) var isMovingFromParent = false

    /// Makes `childController` a child, telling it first; the container then adds its view
    /// and calls `didMove(toParent:)`, as in UIKit.
    open func addChild(_ childController: UIViewController) {
        guard childController.parent !== self else { return }
        childController.removeFromParent()
        childController.isMovingToParent = true
        childController.willMove(toParent: self)
        children.append(childController)
        childController.parent = self
    }

    /// Takes this view controller from its parent, telling it after; the container calls
    /// `willMove(toParent: nil)` and removes the view before.
    open func removeFromParent() {
        guard let parent else { return }
        parent.children.removeAll { $0 === self }
        self.parent = nil
        isMovingFromParent = false
        didMove(toParent: nil)
    }

    /// Overrides call super, as in UIKit, which keeps `isMovingFromParent` here.
    open func willMove(toParent parent: UIViewController?) {
        if parent == nil, self.parent != nil {
            isMovingFromParent = true
        }
    }

    /// Overrides call super, as in UIKit, which keeps `isMovingToParent` here; a move from the
    /// parent that was called off, as a swipe back that let go too soon, ends here too.
    open func didMove(toParent parent: UIViewController?) {
        if parent != nil {
            isMovingToParent = false
            isMovingFromParent = false
        }
    }

    // MARK: Navigation and tabs

    private var ownNavigationItem: UINavigationItem?
    /// The tab bar item, once made or set.
    var ownTabBarItem: UITabBarItem?

    /// What a navigation bar shows while this view controller is on top: its title, its buttons
    /// and how the next one's back button reads. Made with the view controller's title.
    open var navigationItem: UINavigationItem {
        if let ownNavigationItem { return ownNavigationItem }
        let item = UINavigationItem(title: title ?? "")
        item.title = title
        ownNavigationItem = item
        return item
    }

    /// The view controller's tab in a tab bar controller: by default its title, without an image.
    open var tabBarItem: UITabBarItem! {
        get {
            if let ownTabBarItem { return ownTabBarItem }
            let item = UITabBarItem(title: title, image: nil, tag: 0)
            ownTabBarItem = item
            return item
        }
        set {
            ownTabBarItem = newValue
            tabBarController?.irisItemsDidChange()
        }
    }

    /// The closest ancestor that is a navigation controller.
    open var navigationController: UINavigationController? {
        sequence(first: self) { $0.parent }.dropFirst().lazy.compactMap { $0 as? UINavigationController }.first
    }

    /// The closest ancestor that is a tab bar controller.
    open var tabBarController: UITabBarController? {
        sequence(first: self) { $0.parent }.dropFirst().lazy.compactMap { $0 as? UITabBarController }.first
    }

    /// Hides the tab bar while this view controller, or one pushed after it, is on top of a
    /// navigation controller's stack.
    open var hidesBottomBarWhenPushed = false

    /// Shows a view controller as the container this one is in does: a navigation controller
    /// pushes it; without one it is presented.
    open func show(_ vc: UIViewController, sender: Any?) {
        if let navigationController {
            navigationController.show(vc, sender: sender)
        } else {
            present(vc, animated: true)
        }
    }

    /// Presents it, as on an iPhone outside a split view controller.
    open func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        present(vc, animated: true)
    }

    private weak var contentScrollView: UIScrollView?

    /// The scroll view whose content runs under the bars at an edge of the view, as their
    /// background follows it: the one set, else the view, or its first subview, if a scroll view.
    open func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
        contentScrollView ?? viewIfLoaded.flatMap { $0 as? UIScrollView ?? $0.subviews.first as? UIScrollView }
    }

    open func setContentScrollView(_ scrollView: UIScrollView?, for edge: NSDirectionalRectEdge = .all) {
        contentScrollView = scrollView
    }

    // MARK: Editing

    private var editing = false
    private var ownEditButtonItem: UIBarButtonItem?

    /// Whether the view controller lets the person edit its content, as a table view's rows.
    open var isEditing: Bool {
        get { editing }
        set { setEditing(newValue, animated: false) }
    }

    /// Overrides call super, which updates `editButtonItem`.
    open func setEditing(_ editing: Bool, animated: Bool) {
        self.editing = editing
        if let ownEditButtonItem {
            ownEditButtonItem.title = editing ? "Done" : "Edit"
            ownEditButtonItem.style = editing ? .done : .plain
        }
    }

    /// An Edit button that turns editing on and off, reading Done while it is on.
    open var editButtonItem: UIBarButtonItem {
        if let ownEditButtonItem { return ownEditButtonItem }
        let item = UIBarButtonItem(title: editing ? "Done" : "Edit", style: editing ? .done : .plain, target: nil, action: nil)
        item.irisAction = { [weak self] in
            guard let self else { return }
            setEditing(!isEditing, animated: true)
        }
        ownEditButtonItem = item
        return item
    }

    // MARK: Presentation

    /// The view controller this one presented, or that one of its ancestors presented.
    open var presentedViewController: UIViewController? {
        presented ?? parent?.presentedViewController
    }

    /// The view controller that presented this one, or one of its ancestors.
    open var presentingViewController: UIViewController? {
        presenter ?? parent?.presentingViewController
    }

    /// Iris: what this view controller presents itself, and who presented it.
    private var presented: UIViewController?
    private weak var presenter: UIViewController?

    open var modalPresentationStyle = UIModalPresentationStyle.automatic
    open var modalTransitionStyle = UIModalTransitionStyle.coverVertical
    /// True keeps a drag from dismissing the presented view controller, as for unsaved changes;
    /// the presentation controller's delegate hears of the attempt.
    open var isModalInPresentation = false
    open var definesPresentationContext = false
    open private(set) var isBeingPresented = false
    open private(set) var isBeingDismissed = false
    /// Iris: the transition's views are still on their way, until it is over or at once without
    /// an animation; meanwhile the view controller is not dismissed, as in UIKit.
    private var irisTransitioning = false

    private var ownPresentationController: UIPresentationController?

    /// The presentation controller that presents this view controller, or one of its ancestors,
    /// or will present it: made for its style when first asked for, as in UIKit, so that a
    /// delegate can be set before presenting.
    open var presentationController: UIPresentationController? {
        if let ownPresentationController { return ownPresentationController }
        if let parent { return parent.presentationController }
        return irisPresentationController()
    }

    /// The page sheet's presentation controller, if the view controller is presented as one.
    open var sheetPresentationController: UISheetPresentationController? {
        presentationController as? UISheetPresentationController
    }

    /// Iris: the presentation controller for the style the view controller will be presented
    /// with, made anew if the style changed since one was made, keeping its delegate.
    private func irisPresentationController() -> UIPresentationController {
        let style = modalPresentationStyle.onPhone
        if let ownPresentationController, ownPresentationController.style == style {
            return ownPresentationController
        }
        let controller = style == .pageSheet
            ? UISheetPresentationController(presentedViewController: self, presenting: nil)
            : UIPresentationController(presentedViewController: self, presenting: nil)
        controller.delegate = ownPresentationController?.delegate
        ownPresentationController = controller
        return controller
    }

    /// Iris: the presentation that presents this view controller, while one does.
    var irisPresentation: UIPresentationController? {
        presenter != nil ? ownPresentationController : nil
    }

    /// Iris: the view that shows the view controller in its window: its presentation's container
    /// if it is presented, else its view.
    var irisTopView: UIView? {
        irisPresentation?.containerView ?? viewIfLoaded
    }

    /// Presents a view controller over this one, as its style says on an iPhone (a page sheet
    /// unless set otherwise; full screen; over full screen; over the current context), with its
    /// transition style, and runs `completion` once it shows. The top of this view controller's
    /// hierarchy presents, or for a style over the current context the nearest that defines
    /// one, as in UIKit. A view controller that is already presenting presents nothing, as UIKit
    /// only warns then.
    open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        let presented = viewControllerToPresent
        let controller = presented.irisPresentationController()
        var presenter = self
        while let parent = presenter.parent, !(controller.style.isOverContext && presenter.definesPresentationContext) {
            presenter = parent
        }
        guard presenter.presented == nil, presented.presenter == nil, presented.parent == nil, let window = presenter.viewIfLoaded?.window else {
            let reason = presenter.presented.map { "which is already presenting \($0)" }
                ?? (presented.presenter != nil || presented.parent != nil ? "while it is presented or a child" : "whose view is not in the window hierarchy")
            printError("Attempt to present \(presented) on \(presenter) \(reason).")
            return
        }
        presenter.presented = presented
        presented.presenter = presenter
        presented.isBeingPresented = true
        presented.irisTransitioning = true
        controller.presenting = presenter
        UIViewController.irisTransition(
            from: controller.shouldRemovePresentersView ? [presenter] : [], to: [presented], animated: flag,
            duration: controller.duration(presenting: true), options: .curveEaseOut, appearingEndsFirst: true,
            prepare: { controller.irisAddViews(in: window) },
            animations: { controller.irisAnimateIn() },
            finish: {
                controller.irisRemovePresentersView()
                presented.irisTransitioning = false
            }
        ) {
            presented.isBeingPresented = false
            completion?()
        }
        presented.irisDidPresent()
    }

    /// Dismisses what this view controller, or an ancestor, presented, with whatever that one
    /// presented in turn; if they presented nothing, the view controller that presented this one,
    /// or an ancestor. Only the top one leaves with its transition; those under it go at once, as
    /// in UIKit. Once their views are gone they are presented no more, before they hear
    /// viewDidDisappear, and `completion` runs after.
    open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        var holder: UIViewController? = self
        while let current = holder, current.presented == nil {
            holder = current.parent
        }
        guard let holder = holder ?? presentingViewController, let first = holder.presented,
              let firstController = first.ownPresentationController else {
            completion?()
            return
        }
        var chain = [first]
        while let next = chain.last?.presented {
            chain.append(next)
        }
        guard !chain.contains(where: \.irisTransitioning), let top = chain.last, let topController = top.ownPresentationController else {
            printError("Attempt to dismiss from \(self) while a presentation or dismiss is in progress.")
            return
        }
        for controller in chain {
            controller.isBeingDismissed = true
            controller.irisTransitioning = true
        }
        UIViewController.irisTransition(
            from: chain.reversed(), to: firstController.shouldRemovePresentersView ? [holder] : [], animated: flag,
            duration: topController.duration(presenting: false), options: .curveEaseInOut,
            prepare: {
                for between in chain.dropLast() {
                    between.ownPresentationController?.irisRemoveViews()
                }
                firstController.irisRestorePresentersView()
            },
            animations: {
                topController.irisAnimateOut()
                firstController.irisRestorePresenter()
            },
            finish: {
                topController.irisRemoveViews()
                firstController.irisClearPresenter()
                for controller in chain {
                    controller.presenter?.presented = nil
                    controller.presenter = nil
                    controller.irisTransitioning = false
                }
            }
        ) {
            for controller in chain {
                controller.isBeingDismissed = false
            }
            completion?()
        }
    }

    /// Iris: the view controller now shows; an alert takes the keyboard for its first text field.
    func irisDidPresent() {
        UIResponder.forceResign()
    }
}

public enum UIModalPresentationStyle: Int, Sendable {
    case fullScreen = 0, pageSheet, formSheet, currentContext, custom, overFullScreen, overCurrentContext, popover
    case none = -1
    case automatic = -2

    /// Iris: the style UIKit gives a presentation on an iPhone: the automatic style, form sheets and
    /// popovers adapt to page sheets.
    var onPhone: UIModalPresentationStyle {
        switch self {
        case .automatic, .pageSheet, .formSheet, .popover: .pageSheet
        case .none: .fullScreen
        // ponytail: no custom presentation controllers; over full screen, as most draw.
        case .custom: .overFullScreen
        case .fullScreen, .currentContext, .overFullScreen, .overCurrentContext: self
        }
    }

    /// Iris: presented in the frame of the view controller that defines the presentation context.
    var isOverContext: Bool {
        self == .currentContext || self == .overCurrentContext
    }
}

public enum UIModalTransitionStyle: Int, Sendable {
    case coverVertical = 0, flipHorizontal, crossDissolve, partialCurl
}
