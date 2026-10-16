import Foundation
import IrisHost

/// Manages a presentation: the views it puts in the window around the presented view
/// controller's view, where they go, and how they come and go. UIKit makes one for the style the
/// presented view controller has on an iPhone; a page sheet's is a `UISheetPresentationController`.
/// The presented view comes up from the bottom (`coverVertical`) or fades in (the other
/// transition styles).
// ponytail: no subclasses or custom presentations (`.custom` and a transitioning delegate), and
// the delegate is not asked to adapt; flips and curls fade, as the render core has no 3D.
@preconcurrency @MainActor
open class UIPresentationController: NSObject {
    public init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        presented = presentedViewController
        presenting = presentingViewController
        style = presentedViewController.modalPresentationStyle.onPhone
        super.init()
    }

    /// The presented view controller, which keeps its presentation controller.
    open var presentedViewController: UIViewController {
        presented!
    }

    private weak var presented: UIViewController?

    /// The view controller that presents, once the presentation begins.
    open var presentingViewController: UIViewController! {
        presenting
    }

    weak var presenting: UIViewController?

    /// Hears about a drag that dismisses a page sheet, or that may not.
    open weak var delegate: (any UIAdaptivePresentationControllerDelegate)?

    let style: UIModalPresentationStyle

    open var presentationStyle: UIModalPresentationStyle {
        style
    }

    /// The view the presentation puts in the window, where the presented view goes.
    open private(set) var containerView: UIView?

    /// The view that comes and goes with the transition.
    open var presentedView: UIView? {
        presentedViewController.viewIfLoaded
    }

    /// Where the presented view goes in the container: all of it.
    open var frameOfPresentedViewInContainerView: CGRect {
        containerView?.bounds ?? .zero
    }

    /// Whether the view under the presented one leaves the window once covered, as for the full
    /// screen and current context styles.
    open var shouldRemovePresentersView: Bool {
        style == .fullScreen || style == .currentContext
    }

    // MARK: Iris: the views and the transitions

    /// The presenting view, while the presentation keeps it out of the window, and where it was.
    private var removedPresentersView: (view: UIView, superview: UIView, index: Int)?

    private var fades: Bool {
        presentedViewController.modalTransitionStyle != .coverVertical
    }

    /// Seconds a transition takes.
    // ponytail: estimates (UIKit's modal transitions spring); measure on iOS to match.
    func duration(presenting: Bool) -> TimeInterval {
        fades ? 0.25 : presenting ? 0.4 : 0.3
    }

    /// Puts the container in the window, over all of it or over the view controller that defines
    /// the presentation context, with the presented view in it.
    func irisAddViews(in window: UIWindow) {
        let container = UITransitionView()
        container.controller = self
        if style.isOverContext, let context = presenting?.viewIfLoaded {
            container.frame = context.convert(context.bounds, to: window)
        } else {
            container.frame = window.bounds
            container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
        containerView = container
        addPresentedView(to: container)
        window.addSubview(container)
        layOut(container)
    }

    /// The presented view fills the container.
    func addPresentedView(to container: UIView) {
        let view: UIView = presentedViewController.view
        view.frame = container.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)
    }

    func layOut(_ container: UIView) {}

    /// The view that slides in and out, and how far.
    var slide: (view: UIView, distance: CGFloat)? {
        containerView.map { ($0, $0.bounds.height) }
    }

    /// In the transition's animation block: the presented view comes up from below the container,
    /// or the container fades in. Its views are new to the render core, so the animations are
    /// given to the layers outright.
    func irisAnimateIn() {
        guard let timing = IrisAnimationTiming.current, let container = containerView else { return }
        if fades {
            container.layer.irisAnimations.append(timing.animation(from: .opacity(0), to: .opacity(1)))
        } else if let (view, distance) = slide {
            view.layer.irisAnimations.append(timing.animation(from: .transform([1, 0, 0, 1, 0, Float(distance)]), to: .transform([1, 0, 0, 1, 0, 0])))
        }
    }

    /// In the dismissal's animation block: the presented view goes down out of the container, or
    /// the container fades out. Drawn only, so nothing lays out anew on the way.
    func irisAnimateOut() {
        if fades {
            containerView?.alpha = 0
        } else if let (view, distance) = slide {
            view.layer.irisPresentationTransform = CGAffineTransform(translationX: 0, y: distance)
        }
    }

    /// Once the presented view covers the presenting one, that leaves the window, if the style says.
    func irisRemovePresentersView() {
        guard shouldRemovePresentersView, presentedViewController.presentingViewController === presenting,
              let view = presenting?.irisTopView, let superview = view.superview,
              let index = superview.subviews.firstIndex(where: { $0 === view }) else { return }
        removedPresentersView = (view, superview, index)
        view.removeFromSuperview()
    }

    /// Before the dismissal, the presenting view comes back where it was.
    func irisRestorePresentersView() {
        guard let (view, superview, index) = removedPresentersView else { return }
        removedPresentersView = nil
        superview.insertSubview(view, at: min(index, superview.subviews.count))
    }

    /// In the dismissal's animation block: what the presentation did to the presenting view goes.
    func irisRestorePresenter() {}

    /// After the dismissal.
    func irisClearPresenter() {}

    func irisRemoveViews() {
        containerView?.removeFromSuperview()
        containerView = nil
    }
}

/// What a presentation controller's delegate hears about a drag that dismisses a page sheet.
/// Every method is optional.
@preconcurrency @MainActor
public protocol UIAdaptivePresentationControllerDelegate: NSObjectProtocol {
    /// Asked as a drag starts to dismiss; false keeps the sheet, as `isModalInPresentation` does.
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController)
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController)
    /// A drag tried to dismiss a sheet that may not go.
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController)
}

extension UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        true
    }

    public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {}
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {}
    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {}
}

// MARK: - Page sheets

/// A page sheet on an iPhone, as iOS 13 and later draw it: a card rounded at the top, 10 points
/// below the top of the safe area at the large detent and half as high at the medium one, over a
/// dimmed backdrop, the presenting view receded and rounded behind it. A drag down dismisses it,
/// unless `isModalInPresentation` or the delegate says no, or rests it at a detent.
// ponytail: the receded view's scale (16 points in from each side) and the dimming (black, 20%,
// as Iris's SwiftUI sheets) are estimates; no undimmed detents, custom detents or scrolling that
// expands the sheet.
@preconcurrency @MainActor
open class UISheetPresentationController: UIPresentationController {
    /// The heights the sheet rests at.
    open var detents: [Detent] = [.large()] {
        didSet { containerView?.setNeedsLayout() }
    }

    /// The detent the sheet is at; nil is the smallest, as in UIKit.
    open var selectedDetentIdentifier: Detent.Identifier? {
        didSet { containerView?.setNeedsLayout() }
    }

    open var largestUndimmedDetentIdentifier: Detent.Identifier?
    open var prefersGrabberVisible = false {
        didSet { containerView?.setNeedsLayout() }
    }

    /// The card's corner radius; nil for the system's, 10 points.
    open var preferredCornerRadius: CGFloat? {
        didSet { containerView?.setNeedsLayout() }
    }

    open var prefersScrollingExpandsWhenScrolledToEdge = true
    open var prefersEdgeAttachedInCompactHeight = false
    open var widthFollowsPreferredContentSizeWhenEdgeAttached = false

    /// Animates changes to the detents or the selected one.
    open func animateChanges(_ changes: () -> Void) {
        changes()
        guard let containerView else { return }
        UIView.animate(withDuration: 0.3) {
            containerView.layoutIfNeeded()
        }
    }

    // MARK: Iris: the card

    private let card = UIDropShadowView()
    private let dimming = UIDimmingView()
    private let grabber = UIView()
    /// The view under the sheet, receded while the sheet shows.
    private weak var backdrop: UIView?

    override open var presentedView: UIView? {
        card
    }

    private var radius: CGFloat {
        preferredCornerRadius ?? 10
    }

    /// The height of the card's content above the home indicator at the large detent.
    private var fullHeight: CGFloat {
        guard let containerView else { return 0 }
        let safe = containerView.safeAreaInsets
        return max(containerView.bounds.height - safe.top - 10 - safe.bottom, 0)
    }

    private var selectedDetent: Detent? {
        let full = fullHeight
        return detents.first { $0.identifier == selectedDetentIdentifier } ?? detents.min { $0.height(in: full) < $1.height(in: full) }
    }

    /// The card's frame at its detent: it reaches the bottom of the container.
    override open var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        let height = (selectedDetent?.height(in: fullHeight) ?? fullHeight) + containerView.safeAreaInsets.bottom
        return CGRect(x: 0, y: containerView.bounds.height - height, width: containerView.bounds.width, height: height)
    }

    /// The card, a little taller than its frame so its rounded bottom is off screen, holds the
    /// presented view and takes the drag; the dimming covers the container behind it.
    override func addPresentedView(to container: UIView) {
        dimming.backgroundColor = UIColor(white: 0, alpha: 0.2)
        dimming.alpha = 1
        container.addSubview(dimming)
        card.clipsToBounds = true
        card.layer.irisPresentationTransform = .identity
        container.addSubview(card)
        let view: UIView = presentedViewController.view
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(view)
        grabber.backgroundColor = UIColor(red: 60 / 255, green: 60 / 255, blue: 67 / 255, alpha: 0.3)
        grabber.layer.cornerRadius = 2.5
        grabber.isUserInteractionEnabled = false
        card.addSubview(grabber)
        if card.gestureRecognizers == nil {
            let pan = SheetPanGestureRecognizer()
            pan.sheet = self
            card.addGestureRecognizer(pan)
        }
        backdrop = presenting?.irisPresentation?.presentedView ?? presenting?.viewIfLoaded
    }

    override func layOut(_ container: UIView) {
        dimming.frame = container.bounds
        let frame = frameOfPresentedViewInContainerView
        card.layer.cornerRadius = radius
        card.frame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + radius)
        presentedViewController.viewIfLoaded?.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        grabber.isHidden = !prefersGrabberVisible
        grabber.frame = CGRect(x: (frame.width - 36) / 2, y: 5, width: 36, height: 5)
        card.bringSubviewToFront(grabber)
    }

    override var slide: (view: UIView, distance: CGFloat)? {
        containerView.map { (card, $0.bounds.height - card.frame.minY) }
    }

    /// The card comes up, the dimming fades in, and the view under the sheet recedes: smaller, its
    /// top at the safe area's, its corners rounded.
    override func irisAnimateIn() {
        super.irisAnimateIn()
        guard let window = containerView?.window, let backdrop else { return }
        if let timing = IrisAnimationTiming.current, presentedViewController.modalTransitionStyle == .coverVertical {
            dimming.layer.irisAnimations.append(timing.animation(from: .opacity(0), to: .opacity(1)))
        }
        let frame = backdrop.convert(backdrop.bounds, to: window)
        let scale = max(frame.width - 32, 0) / max(frame.width, 1)
        let top = window.safeAreaInsets.top - (frame.midY - frame.height * scale / 2)
        backdrop.layer.irisPresentationTransform = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: 0, y: top))
        backdrop.layer.irisPresentationCornerRadius = 10
    }

    override func irisAnimateOut() {
        super.irisAnimateOut()
        dimming.alpha = 0
    }

    override func irisRestorePresenter() {
        backdrop?.layer.irisPresentationTransform = .identity
        backdrop?.layer.irisPresentationCornerRadius = backdrop?.layer.cornerRadius
    }

    override func irisClearPresenter() {
        backdrop?.layer.irisPresentationCornerRadius = nil
    }

    // MARK: Iris: the drag

    /// The offset a drag gives the card: down with the finger, or rubber-banded, as up past the
    /// largest detent, or down when the sheet may not go.
    private var dragAllowed = true

    fileprivate func pan(_ pan: UIPanGestureRecognizer) {
        guard let containerView, !presentedViewController.isBeingDismissed else { return }
        let translation = pan.translation(in: containerView).y
        switch pan.state {
        case .began:
            dragAllowed = !presentedViewController.isModalInPresentation && delegate?.presentationControllerShouldDismiss(self) ?? true
            if !dragAllowed, translation > 0 {
                delegate?.presentationControllerDidAttemptToDismiss(self)
            }
            card.layer.irisPresentationTransform = offset(for: translation)
        case .changed:
            card.layer.irisPresentationTransform = offset(for: translation)
        case .ended:
            settle(at: translation + pan.velocity(in: containerView).y * 0.2)
        default:
            settle(at: 0)
        }
    }

    private func offset(for translation: CGFloat) -> CGAffineTransform {
        let rubberBand = { (distance: CGFloat) in distance * 0.55 / (1 + abs(distance) / 300) }
        let full = fullHeight
        let largest = detents.map { $0.height(in: full) }.max() ?? full
        let room = largest - (selectedDetent?.height(in: full) ?? full)
        let offset = translation > 0
            ? (dragAllowed || detents.count > 1 ? translation : rubberBand(translation))
            : (-translation <= room ? translation : -room + rubberBand(translation + room))
        return CGAffineTransform(translationX: 0, y: offset)
    }

    /// Where a drag would take the card: dismissed if that is well below the lowest detent, else
    /// at the detent closest to it.
    private func settle(at translation: CGFloat) {
        let full = fullHeight
        let height = (selectedDetent?.height(in: full) ?? full) - translation
        let lowest = detents.map { $0.height(in: full) }.min() ?? full
        if dragAllowed, height < lowest / 2 {
            delegate?.presentationControllerWillDismiss(self)
            presentedViewController.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                delegate?.presentationControllerDidDismiss(self)
            }
            return
        }
        let closest = detents.min { abs($0.height(in: full) - height) < abs($1.height(in: full) - height) }
        let moves = closest != nil && closest !== selectedDetent
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) { [self] in
            card.layer.irisPresentationTransform = .identity
            if moves, let closest {
                selectedDetentIdentifier = closest.identifier
                containerView?.layoutIfNeeded()
            }
        }
        if moves {
            (delegate as? any UISheetPresentationControllerDelegate)?.sheetPresentationControllerDidChangeSelectedDetentIdentifier(self)
        }
    }
}

extension UISheetPresentationController {
    /// A height a sheet rests at.
    @preconcurrency @MainActor
    public class Detent: NSObject {
        public let identifier: Identifier
        private let resolve: (CGFloat) -> CGFloat

        init(_ identifier: Identifier, resolve: @escaping (CGFloat) -> CGFloat) {
            self.identifier = identifier
            self.resolve = resolve
        }

        /// About half the screen.
        public class func medium() -> Detent {
            Detent(.medium) { $0 / 2 }
        }

        /// The full height of a sheet.
        public class func large() -> Detent {
            Detent(.large) { $0 }
        }

        /// The height of the content above the home indicator, out of `full` at the large detent.
        func height(in full: CGFloat) -> CGFloat {
            min(resolve(full), full)
        }

        public struct Identifier: RawRepresentable, Hashable, Sendable {
            public let rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(_ rawValue: String) {
                self.rawValue = rawValue
            }

            public static let medium = Identifier("com.apple.UIKit.medium")
            public static let large = Identifier("com.apple.UIKit.large")
        }
    }
}

/// What a sheet's delegate hears besides a presentation controller's.
@preconcurrency @MainActor
public protocol UISheetPresentationControllerDelegate: UIAdaptivePresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController)
}

extension UISheetPresentationControllerDelegate {
    public func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ sheetPresentationController: UISheetPresentationController) {}
}

// MARK: - The views

/// Iris: a presentation's container in the window, with UIKit's class name; it lays out what the
/// presentation put in it.
@MainActor
private final class UITransitionView: UIView {
    weak var controller: UIPresentationController?

    override func layoutSubviews() {
        super.layoutSubviews()
        controller?.layOut(self)
    }
}

/// Iris: the dimming behind a sheet.
@MainActor
private final class UIDimmingView: UIView {}

/// Iris: a sheet's card, which holds the presented view.
@MainActor
private final class UIDropShadowView: UIView {}

/// Iris: a sheet's drag, which moves the card before the app's targets hear of it.
@MainActor
private final class SheetPanGestureRecognizer: UIPanGestureRecognizer {
    weak var sheet: UISheetPresentationController?

    override func sendActions() {
        sheet?.pan(self)
        super.sendActions()
    }
}
