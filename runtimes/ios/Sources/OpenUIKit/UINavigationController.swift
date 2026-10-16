import Foundation
import IrisHost
import IrisRender

/// A container that shows a stack of view controllers: the top one's view fills the container's
/// view under a navigation bar, and the safe area keeps clear of the bar. A push slides the new
/// view in from the trailing edge over the old one, which moves back by 30% under a dimming; a
/// pop slides the top view out; a swipe from the leading edge pops interactively. Appearance
/// callbacks come in UIKit's order, with `isMovingToParent` and `isMovingFromParent`; the stack
/// changes at once, and the view controllers join or leave as children once the transition ends.
// ponytail: no toolbar (`toolbarItems`, `setToolbarHidden`), custom transitions (animation
// controllers of the delegate), `hidesBarsOnSwipe` and the like, or bar and toolbar classes;
// pushing during a transition doesn't wait for it.
@preconcurrency @MainActor
open class UINavigationController: UIViewController {
    public init(rootViewController: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        setViewControllers([rootViewController], animated: false)
    }

    /// ponytail: the bar and toolbar classes are not used.
    public init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(nibName: nil, bundle: nil)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private let bar = UINavigationBar()
    private let edgePan = InteractivePopGestureRecognizer()
    private var stack: [UIViewController] = []
    private var barHidden = false
    /// An animated transition is on its way.
    private var isTransitioning = false
    /// The navigation controller has shown its first view controller, which the delegate heard of.
    private var hasShown = false

    open weak var delegate: (any UINavigationControllerDelegate)?

    open var navigationBar: UINavigationBar {
        bar
    }

    /// The swipe from the leading edge that pops; disable it, or give it a delegate, to change
    /// when it may begin.
    open var interactivePopGestureRecognizer: UIGestureRecognizer? {
        edgePan
    }

    open var viewControllers: [UIViewController] {
        get { stack }
        set { setViewControllers(newValue, animated: false) }
    }

    open var topViewController: UIViewController? {
        stack.last
    }

    /// The top view controller, or one presented over the navigation controller.
    open var visibleViewController: UIViewController? {
        presentedViewController ?? topViewController
    }

    /// Seconds the bar takes to slide in or out.
    public static let hideShowBarDuration: CGFloat = 0.2

    /// The root's tab, unless the navigation controller has one of its own, as in UIKit.
    open override var tabBarItem: UITabBarItem! {
        get { ownTabBarItem ?? stack.first?.tabBarItem ?? super.tabBarItem }
        set { super.tabBarItem = newValue }
    }

    // MARK: The view

    open override func loadView() {
        let container = UILayoutContainerView(frame: UIScreen.main.bounds)
        container.layOut = { [unowned self] in layOut() }
        bar.irisNavigationController = self
        bar.setItems(stack.map(\.navigationItem), animated: false)
        bar.isHidden = barHidden
        container.addSubview(bar)
        edgePan.navigationController = self
        container.addGestureRecognizer(edgePan)
        view = container
        if let top = stack.last {
            container.insertSubview(top.view, belowSubview: bar)
        }
    }

    /// The bar below the top of the safe area (the status bar), as high as the top item needs, or
    /// above it while hidden; the views of the view controllers fill the view, each one's safe
    /// area clear of the bar as high as it is for that view controller.
    private func layOut() {
        let bounds = view.bounds, top = view.safeAreaInsets.top
        let height = bar.irisHeight(for: bar.topItem)
        bar.frame = CGRect(x: 0, y: barHidden ? top - height : top, width: bounds.width, height: height)
        for child in stack {
            if child.viewIfLoaded?.superview === view {
                child.view.frame = bounds
            }
            child.irisBarInsets = UIEdgeInsets(top: barHidden ? 0 : bar.irisHeight(for: child.navigationItem), left: 0, bottom: 0, right: 0)
        }
    }

    // MARK: Pushing and popping

    /// Pushes a view controller on top, and shows it.
    open func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard !stack.contains(where: { $0 === viewController }) else {
            printError("Pushing the same view controller instance (\(viewController)) more than once is not supported.")
            return
        }
        let old = stack.last
        addChild(viewController)
        stack.append(viewController)
        transition(to: viewController, from: old, animated: animated, pushing: true) {
            viewController.didMove(toParent: self)
        }
    }

    /// Pushes it, as showing a view controller in a navigation controller does.
    open override func show(_ vc: UIViewController, sender: Any?) {
        pushViewController(vc, animated: true)
    }

    /// Pops the top view controller and returns it; nil at the root.
    @discardableResult
    open func popViewController(animated: Bool) -> UIViewController? {
        guard stack.count > 1 else { return nil }
        return popToViewController(stack[stack.count - 2], animated: animated)?.last
    }

    @discardableResult
    open func popToRootViewController(animated: Bool) -> [UIViewController]? {
        stack.first.flatMap { popToViewController($0, animated: animated) }
    }

    /// Pops the view controllers above `viewController`, bottom first; nil if there are none, or
    /// if it is not in the stack (UIKit raises an exception).
    @discardableResult
    open func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        guard let index = stack.firstIndex(where: { $0 === viewController }) else {
            printError("Tried to pop to a view controller that doesn't exist.")
            return nil
        }
        let popped = Array(stack[(index + 1)...])
        guard let old = popped.last else { return nil }
        for controller in popped {
            controller.willMove(toParent: nil)
        }
        stack.removeSubrange((index + 1)...)
        transition(to: viewController, from: old, animated: animated, pushing: false) {
            for controller in popped {
                controller.removeFromParent()
            }
        }
        return popped
    }

    /// Takes a new stack: its top shows as if pushed, if it is new, or as if popped to.
    open func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        let old = stack
        let removed = old.filter { controller in !viewControllers.contains { $0 === controller } }
        let added = viewControllers.filter { controller in !old.contains { $0 === controller } }
        for controller in removed {
            controller.willMove(toParent: nil)
        }
        for controller in added {
            addChild(controller)
        }
        stack = viewControllers
        let finish = {
            for controller in removed {
                controller.removeFromParent()
            }
            for controller in added {
                controller.didMove(toParent: self)
            }
        }
        if viewControllers.last === old.last {
            if isViewLoaded {
                bar.setItems(stack.map(\.navigationItem), animated: animated)
            }
            finish()
        } else {
            let top = viewControllers.last
            transition(to: top, from: old.last, animated: animated, pushing: top.map { top in !old.contains { $0 === top } } ?? false, completion: finish)
        }
    }

    // MARK: The bar

    open var isNavigationBarHidden: Bool {
        get { barHidden }
        set { setNavigationBarHidden(newValue, animated: false) }
    }

    /// Slides the bar out above the top of the safe area, or back in; the view controllers' safe
    /// area changes with it.
    open func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        guard hidden != barHidden else { return }
        barHidden = hidden
        guard isViewLoaded else { return }
        bar.isHidden = false
        view.setNeedsLayout()
        UIView.animate(withDuration: animated ? Self.hideShowBarDuration : 0) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.bar.isHidden = self.barHidden
        }
        if !animated {
            bar.isHidden = hidden
        }
    }

    // MARK: Iris: transitions

    /// Iris: whether the tab bar hides for the stack: a view controller pushed above the root hides
    /// it.
    var irisHidesBottomBar: Bool {
        stack.dropFirst().contains(where: \.hidesBottomBarWhenPushed)
    }

    /// The tab bar controller whose selected tab this is, which shows or hides its bar with the stack.
    private var tabs: UITabBarController? {
        tabBarController.flatMap { $0.selectedViewController === self ? $0 : nil }
    }

    /// Shows `new` in place of `old`, sliding in over it on a push or uncovered on a pop, through
    /// UIKit's appearance transition: the delegate hears first, then the appearance callbacks;
    /// `completion` runs after the did… callbacks, before the delegate hears again. Off screen, the
    /// views change at once.
    private func transition(to new: UIViewController?, from old: UIViewController?, animated: Bool, pushing: Bool, completion: @escaping () -> Void) {
        guard isViewLoaded else { return completion() }
        bar.setItems(stack.map(\.navigationItem), animated: animated)
        let onScreen = irisAppearance == .appeared || irisAppearance == .appearing
        let animates = onScreen && animated && irisAnimates
        let width = view.bounds.width
        let oldView = old?.viewIfLoaded
        let newView = new?.view
        let dimming = UIView(frame: view.bounds)
        dimming.backgroundColor = .black
        dimming.isUserInteractionEnabled = false
        // The tab bar goes with the view it belongs to.
        let tabBar = tabs?.tabBar
        let hidesTabBar = irisHidesBottomBar
        let movesTabBar = tabBar.map { $0.isHidden != hidesTabBar } ?? false
        let prepare = { [self] in
            if let newView {
                newView.frame = view.bounds
                if pushing || oldView?.superview !== view {
                    view.insertSubview(newView, belowSubview: bar)
                } else if let oldView {
                    view.insertSubview(newView, belowSubview: oldView)
                }
            }
            if animates, let below = pushing ? newView : oldView {
                view.insertSubview(dimming, belowSubview: below)
            }
            if movesTabBar, !hidesTabBar {
                tabBar?.isHidden = false
            }
            tabs?.view.setNeedsLayout()
            view.setNeedsLayout()
            isTransitioning = animates
        }
        let animations = { [self] in
            view.layoutIfNeeded()
            guard let timing = IrisAnimationTiming.current else { return }
            let slide = { (x: CGFloat) in Animation.Value.transform([1, 0, 0, 1, Float(x), 0]) }
            if pushing {
                newView?.layer.irisAnimations.append(timing.animation(from: slide(width), to: slide(0)))
                oldView?.layer.irisPresentationTransform = CGAffineTransform(translationX: -0.3 * width, y: 0)
                dimming.alpha = 0.1
                dimming.layer.irisAnimations.append(timing.animation(from: .opacity(0), to: .opacity(0.1)))
            } else {
                oldView?.layer.irisPresentationTransform = CGAffineTransform(translationX: width, y: 0)
                newView?.layer.irisAnimations.append(timing.animation(from: slide(-0.3 * width), to: slide(0)))
                dimming.alpha = 0
                dimming.layer.irisAnimations.append(timing.animation(from: .opacity(0.1), to: .opacity(0)))
            }
            if movesTabBar, let tabBar {
                if hidesTabBar {
                    tabBar.layer.irisPresentationTransform = CGAffineTransform(translationX: -0.3 * width, y: 0)
                } else {
                    tabBar.layer.irisAnimations.append(timing.animation(from: slide(-0.3 * width), to: slide(0)))
                }
            }
        }
        let finish = { [self] in
            // Unless another transition brought it back on top meanwhile.
            if let oldView, old !== stack.last, oldView.superview === view {
                oldView.removeFromSuperview()
            }
            oldView?.layer.irisPresentationTransform = .identity
            dimming.removeFromSuperview()
            if movesTabBar, hidesTabBar, let tabBar {
                tabBar.isHidden = true
                tabBar.layer.irisPresentationTransform = .identity
            }
            isTransitioning = false
        }
        guard onScreen else {
            prepare()
            finish()
            return completion()
        }
        if let new {
            delegate?.navigationController(self, willShow: new, animated: animated)
        }
        UIViewController.irisTransition(
            from: old.map { [$0] } ?? [], to: new.map { [$0] } ?? [], animated: animated, duration: 0.35, options: .curveEaseInOut,
            prepare: prepare, animations: animations, finish: finish
        ) { [self] in
            completion()
            if let new {
                delegate?.navigationController(self, didShow: new, animated: animated)
            }
        }
    }

    /// The delegate hears of the first view controller as the navigation controller first shows.
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !hasShown, let top = stack.last {
            delegate?.navigationController(self, willShow: top, animated: animated)
        }
    }

    /// And again once the first view controller has appeared.
    open override func endAppearanceTransition() {
        super.endAppearanceTransition()
        if !hasShown, irisAppearance == .appeared, let top = stack.last {
            hasShown = true
            delegate?.navigationController(self, didShow: top, animated: appearanceAnimated)
        }
    }

    // MARK: Iris: the swipe back

    /// The pop the swipe began: the top view controller, the one under it, and the dimming.
    private var swipe: (top: UIViewController, under: UIViewController, dimming: UIView, movesTabBar: Bool)?

    /// Whether the swipe may begin: something to pop, and no transition on its way.
    fileprivate var canSwipeBack: Bool {
        stack.count > 1 && !isTransitioning && swipe == nil
    }

    /// The swipe back: it begins the pop, the top view follows the finger and the one under it
    /// comes from the left; let go past the middle, or quickly enough, the pop ends, else it is
    /// called off and the top view comes back, as in UIKit.
    fileprivate func swipeBack(_ pan: UIPanGestureRecognizer) {
        let width = max(view.bounds.width, 1)
        let progress = min(max(pan.translation(in: view).x / width, 0), 1)
        switch pan.state {
        case .began:
            guard stack.count > 1, let top = stack.last else { return }
            let under = stack[stack.count - 2]
            top.willMove(toParent: nil)
            stack.removeLast()
            under.loadViewIfNeeded()
            delegate?.navigationController(self, willShow: under, animated: true)
            top.beginAppearanceTransition(false, animated: true)
            under.beginAppearanceTransition(true, animated: true)
            under.view.frame = view.bounds
            view.insertSubview(under.view, belowSubview: top.view)
            let dimming = UIView(frame: view.bounds)
            dimming.backgroundColor = .black
            dimming.isUserInteractionEnabled = false
            view.insertSubview(dimming, belowSubview: top.view)
            let movesTabBar = tabs?.tabBar.isHidden == true && !irisHidesBottomBar
            if movesTabBar {
                tabs?.tabBar.isHidden = false
                tabs?.view.setNeedsLayout()
            }
            swipe = (top, under, dimming, movesTabBar)
            follow(progress)
        case .changed:
            follow(progress)
        case .ended, .cancelled:
            guard let (top, under, dimming, movesTabBar) = swipe else { return }
            swipe = nil
            let velocity = pan.state == .ended ? pan.velocity(in: view).x : 0
            let pops = pan.state == .ended && (velocity > 300 || progress > 0.5 && velocity > -300)
            if !pops {
                stack.append(top)
            }
            let tabBar = movesTabBar ? tabs?.tabBar : nil
            let ends = {
                top.view.layer.irisPresentationTransform = pops ? CGAffineTransform(translationX: width, y: 0) : .identity
                under.view.layer.irisPresentationTransform = pops ? .identity : CGAffineTransform(translationX: -0.3 * width, y: 0)
                tabBar?.layer.irisPresentationTransform = under.view.layer.irisPresentationTransform
                dimming.alpha = pops ? 0 : 0.1
            }
            isTransitioning = true
            UIViewController.irisTransition(
                from: pops ? [top] : [under], to: pops ? [under] : [top], animated: true,
                duration: 0.35 * (pops ? 1 - progress : progress), options: .curveEaseOut, animations: ends,
                finish: { [self] in
                    (pops ? top : under).view.removeFromSuperview()
                    for view in [top.view, under.view, tabBar] {
                        view?.layer.irisPresentationTransform = .identity
                    }
                    dimming.removeFromSuperview()
                    if !pops, movesTabBar {
                        tabBar?.isHidden = true
                    }
                    if pops {
                        bar.setItems(stack.map(\.navigationItem), animated: true)
                    }
                    isTransitioning = false
                }
            ) { [self] in
                if pops {
                    top.removeFromParent()
                } else {
                    top.didMove(toParent: self)
                }
                delegate?.navigationController(self, didShow: pops ? under : top, animated: true)
            }
        default:
            break
        }
    }

    /// Where the swipe has the views: the top one moved with the finger, the one under it 30% of
    /// the way back in, the dimming over it fading.
    private func follow(_ progress: CGFloat) {
        guard let (top, under, dimming, movesTabBar) = swipe else { return }
        let width = view.bounds.width
        top.view.layer.irisPresentationTransform = CGAffineTransform(translationX: progress * width, y: 0)
        under.view.layer.irisPresentationTransform = CGAffineTransform(translationX: -0.3 * width * (1 - progress), y: 0)
        dimming.alpha = 0.1 * (1 - progress)
        if movesTabBar {
            tabs?.tabBar.layer.irisPresentationTransform = under.view.layer.irisPresentationTransform
        }
    }
}

/// What a navigation controller's delegate hears as view controllers come on top. Every method is
/// optional.
@preconcurrency @MainActor
public protocol UINavigationControllerDelegate: NSObjectProtocol {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool)
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool)
}

extension UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {}
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {}
}

/// Iris: the view of a navigation or tab bar controller, with UIKit's class name; its controller
/// lays out its bars and children.
@MainActor
final class UILayoutContainerView: UIView {
    var layOut: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        layOut?()
    }
}

/// A pan that begins at an edge of the screen and moves away from it, as a swipe back does.
@preconcurrency @MainActor
open class UIScreenEdgePanGestureRecognizer: UIPanGestureRecognizer {
    open var edges: UIRectEdge = []

    /// Points from the edge a touch may begin at; UIKit's is private, about this.
    static let edgeWidth: CGFloat = 20

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard state == .possible, self.touches.count == touches.count, let window = view?.window else { return }
        let point = location(in: nil), bounds = window.bounds, edge = Self.edgeWidth
        let near = edges.contains(.left) && point.x - bounds.minX <= edge || edges.contains(.right) && bounds.maxX - point.x <= edge
            || edges.contains(.top) && point.y - bounds.minY <= edge || edges.contains(.bottom) && bounds.maxY - point.y <= edge
        if !near {
            state = .failed
        }
    }

    /// Moving along the edge, or back towards it, is no swipe from it.
    override open func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let moved = translation(in: nil)
        if state == .possible, hypot(moved.x, moved.y) > UIPanGestureRecognizer.hysteresis {
            let away = edges.contains(.left) && moved.x > abs(moved.y) || edges.contains(.right) && -moved.x > abs(moved.y)
                || edges.contains(.top) && moved.y > abs(moved.x) || edges.contains(.bottom) && -moved.y > abs(moved.x)
            if !away {
                state = .failed
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    /// A pan inside the view, such as a scroll view's, waits for the swipe to fail.
    override open func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let view, let other = otherGestureRecognizer.view else { return false }
        return otherGestureRecognizer is UIPanGestureRecognizer && other !== view && other.isDescendant(of: view)
    }
}

/// Iris: a navigation controller's swipe back, which moves the views before targets hear of it.
@MainActor
private final class InteractivePopGestureRecognizer: UIScreenEdgePanGestureRecognizer {
    weak var navigationController: UINavigationController?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        edges = .left
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if state == .possible, navigationController?.canSwipeBack != true {
            state = .failed
        }
    }

    override func sendActions() {
        navigationController?.swipeBack(self)
        super.sendActions()
    }
}
