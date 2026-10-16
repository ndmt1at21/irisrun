import Foundation
import IrisHost
import IrisRender

/// Manages a view: makes it when it is first asked for, with `loadView`, then calls
/// `viewDidLoad`. It presents other view controllers over its window.
// ponytail: appearance callbacks, sheets, transitions and nibs come with step 4 and 6;
// presented view controllers cover the window.
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

    open var title: String?

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

    override open var next: UIResponder? {
        presentingViewController ?? loadedView?.superview
    }

    /// The size the view controller's content wants, for a container that sizes it.
    // ponytail: containers aren't told when it changes (preferredContentSizeDidChange) yet.
    open var preferredContentSize = CGSize.zero

    // MARK: Containment

    open private(set) var children: [UIViewController] = []

    open private(set) weak var parent: UIViewController?

    /// Makes `childController` a child, telling it first; the container then adds its view
    /// and calls `didMove(toParent:)`, as in UIKit.
    open func addChild(_ childController: UIViewController) {
        guard childController.parent !== self else { return }
        childController.removeFromParent()
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
        didMove(toParent: nil)
    }

    open func willMove(toParent parent: UIViewController?) {}

    open func didMove(toParent parent: UIViewController?) {}

    // MARK: Presentation

    open private(set) var presentedViewController: UIViewController?
    open private(set) weak var presentingViewController: UIViewController?
    open var modalPresentationStyle = UIModalPresentationStyle.automatic
    open var modalTransitionStyle = UIModalTransitionStyle.coverVertical
    open var isModalInPresentation = false
    open var definesPresentationContext = false

    /// Shows a view controller over this one's window, its view filling the window, and runs
    /// `completion` once it shows. One that is already presenting presents nothing, as UIKit
    /// only warns then.
    open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        guard presentedViewController == nil, let window = viewIfLoaded?.window else {
            let reason = presentedViewController != nil ? "which is already presenting \(presentedViewController!)" : "whose view is not in the window hierarchy"
            printError("Attempt to present \(viewControllerToPresent) on \(self) \(reason).")
            return
        }
        presentedViewController = viewControllerToPresent
        viewControllerToPresent.presentingViewController = self
        let view: UIView = viewControllerToPresent.view
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        if flag {
            view.layer.irisAnimations = [IrisRender.Animation(from: .opacity(0), to: .opacity(1), duration: 0.25)]
        }
        viewControllerToPresent.irisDidPresent()
        completion?()
    }

    /// Dismisses what this view controller presented, or, if it presented nothing, itself.
    open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let presenter = presentedViewController == nil ? presentingViewController : self,
              let presented = presenter.presentedViewController else {
            completion?()
            return
        }
        presented.viewIfLoaded?.removeFromSuperview()
        presenter.presentedViewController = nil
        presented.presentingViewController = nil
        completion?()
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
}

public enum UIModalTransitionStyle: Int, Sendable {
    case coverVertical = 0, flipHorizontal, crossDissolve, partialCurl
}
