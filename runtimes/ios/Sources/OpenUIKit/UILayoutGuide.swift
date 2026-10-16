import Foundation

/// A rectangle in a view that constraints place, without a view of its own: the space between
/// two views, or the safe area and margins UIKit keeps in every view.
@preconcurrency @MainActor
open class UILayoutGuide: NSObject, @preconcurrency NSCoding {
    public override init() {
        kind = .placed
        super.init()
    }

    public required init?(coder: NSCoder) {
        kind = .placed
        super.init()
    }

    open func encode(with coder: NSCoder) {}

    /// Iris: a guide UIKit keeps in `view`, its frame following the view's geometry.
    init(_ kind: Kind, of view: UIView, identifier: String) {
        self.kind = kind
        owningView = view
        self.identifier = identifier
        super.init()
    }

    /// The view whose coordinates the guide is in; `addLayoutGuide(_:)` sets it.
    open weak var owningView: UIView?

    open var identifier = ""

    /// Where the guide is in its owning view, as Auto Layout last placed it.
    open var layoutFrame: CGRect {
        if let frame = owningView?.irisRootView.layoutEngine?.frame(of: self) {
            return frame
        }
        guard kind != .placed, let view = owningView else { return .zero }
        // A guide UIKit keeps is where the view's geometry puts it, constrained or not.
        let insets = insets(in: view)
        let height = insets.height.map { CGRect(x: 0, y: view.bounds.height - $0, width: view.bounds.width, height: $0) }
        return height ?? CGRect(origin: .zero, size: view.bounds.size).inset(by: insets.edges)
    }

    // MARK: Anchors

    open var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .leading) }
    open var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .trailing) }
    open var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .left) }
    open var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .right) }
    open var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .top) }
    open var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .bottom) }
    open var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .width) }
    open var heightAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .height) }
    open var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .centerX) }
    open var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .centerY) }

    // MARK: Iris: the guides UIKit keeps

    enum Kind {
        /// Placed by the app's constraints only.
        case placed
        case safeArea, margins, readableContent, keyboard
    }

    let kind: Kind

    /// The width readable text takes at the default text size, which the readable content guide
    /// keeps to on wide screens.
    static let readableWidth: CGFloat = 672

    /// How far inside the view's bounds the guide is: by `edges`, or along the bottom
    /// `height` high, for the keyboard guide.
    // ponytail: the readable content guide is the margins guide on screens narrower than the
    // readable width, as an iPhone in portrait; the engine centers and narrows it on others.
    func insets(in view: UIView) -> (edges: UIEdgeInsets, height: CGFloat?) {
        switch kind {
        case .placed: return (.zero, nil)
        case .safeArea: return (view.safeAreaInsets, nil)
        case .margins, .readableContent: return (view.layoutMargins, nil)
        case .keyboard: return (.zero, (self as? UIKeyboardLayoutGuide)?.height(in: view) ?? 0)
        }
    }
}

/// A layout guide that follows something on screen as it moves.
@preconcurrency @MainActor
open class UITrackingLayoutGuide: UILayoutGuide {}

/// The keyboard's frame in a view, as `keyboardLayoutGuide`: its top edge is the keyboard's top.
/// Iris's keyboard is 0 points high at the bottom of the screen (typing comes from the computer's
/// keyboard), so the guide is the bottom safe area.
@preconcurrency @MainActor
open class UIKeyboardLayoutGuide: UITrackingLayoutGuide {
    open var followsUndockedKeyboard = false

    /// While the keyboard is down, the guide's top is the bottom of the safe area; false puts it
    /// at the bottom of the view.
    open var usesBottomSafeArea = true {
        didSet { owningView?.irisRootView.layoutEngine?.setNeedsSync() }
    }

    func height(in view: UIView) -> CGFloat {
        guard let window = view.window else { return 0 }
        let keyboardTop = window.screen.bounds.maxY
        let overlap = max(0, view.convert(view.bounds, to: window).maxY - keyboardTop)
        return usesBottomSafeArea ? max(overlap, view.safeAreaInsets.bottom) : overlap
    }
}
