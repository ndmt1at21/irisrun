import Foundation
import IrisHost
import IrisRender

/// What a layer's delegate (a view, for a view's layer) is asked. Every method is optional.
public protocol CALayerDelegate: NSObjectProtocol {
    func display(_ layer: CALayer)
    func layoutSublayers(of layer: CALayer)
}

extension CALayerDelegate {
    public func display(_ layer: CALayer) {}
    public func layoutSublayers(of layer: CALayer) {}
}

/// The Core Animation layer model UIKit draws with. Changes are drawn by Iris's render core at
/// the end of the main run loop's turn (`LayerCommit`), as Core Animation commits its implicit
/// transaction, and only what changed is sent.
// ponytail: an affine transform, no CATransform3D, zPosition, mask layers or public animations
// yet; UIKit's own controls animate through the render core (`irisAnimations`), apps with đợt 4.
open class CALayer: NSObject {
    public override init() {
        super.init()
    }

    /// A copy of the model values of `layer`, as Core Animation makes presentation layers.
    public init(layer: Any) {
        super.init()
        guard let layer = layer as? CALayer else { return }
        (bounds, position, anchorPoint, affine) = (layer.bounds, layer.position, layer.anchorPoint, layer.affine)
        (isHidden, masksToBounds, opacity, name) = (layer.isHidden, layer.masksToBounds, layer.opacity, layer.name)
        (backgroundColor, cornerRadius, borderWidth, borderColor) = (layer.backgroundColor, layer.cornerRadius, layer.borderWidth, layer.borderColor)
        (shadowColor, shadowOpacity, shadowOffset, shadowRadius) = (layer.shadowColor, layer.shadowOpacity, layer.shadowOffset, layer.shadowRadius)
        (contents, contentsGravity, contentsScale) = (layer.contents, layer.contentsGravity, layer.contentsScale)
    }

    open weak var delegate: (any CALayerDelegate)?
    open var name: String?

    // MARK: Geometry

    /// The layer's own coordinates; a nonzero origin moves what is inside, as scrolling does.
    open var bounds = CGRect.zero {
        didSet {
            changed(.geometry)
            if bounds.origin != oldValue.origin {
                // Sublayers sit relative to the origin, and so does the drawing.
                for sublayer in sublayers ?? [] {
                    sublayer.changed(.geometry)
                }
                if irisDrawing != nil {
                    changed(.contents)
                }
            }
            if bounds.size != oldValue.size {
                setNeedsLayout()
            }
        }
    }

    /// Where `anchorPoint` is, in the superlayer's coordinates.
    open var position = CGPoint.zero {
        didSet { changed(.geometry) }
    }

    /// The point of the bounds, from (0, 0) to (1, 1), that sits at `position` and that the
    /// transform turns about.
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5) {
        didSet { changed(.geometry) }
    }

    private var affine = CGAffineTransform.identity {
        didSet { changed(.geometry) }
    }

    open func affineTransform() -> CGAffineTransform {
        affine
    }

    open func setAffineTransform(_ m: CGAffineTransform) {
        affine = m
    }

    /// The bounds as they show in the superlayer: transformed, the box around them.
    open var frame: CGRect {
        get {
            let anchor = CGPoint(x: bounds.minX + anchorPoint.x * bounds.width, y: bounds.minY + anchorPoint.y * bounds.height)
            return bounds.applying(toSuperlayer(from: anchor))
        }
        set {
            position = CGPoint(x: newValue.minX + anchorPoint.x * newValue.width, y: newValue.minY + anchorPoint.y * newValue.height)
            bounds.size = newValue.size
        }
    }

    /// Maps the layer's coordinates to its superlayer's, with `anchor` the anchor point in the
    /// layer's coordinates.
    private func toSuperlayer(from anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -anchor.x, y: -anchor.y)
            .concatenating(affine)
            .concatenating(CGAffineTransform(translationX: position.x, y: position.y))
    }

    private var toSuperlayer: CGAffineTransform {
        toSuperlayer(from: CGPoint(x: bounds.minX + anchorPoint.x * bounds.width, y: bounds.minY + anchorPoint.y * bounds.height))
    }

    /// The layers from the root down to this one.
    private var ancestry: [CALayer] {
        var layers = [self]
        while let superlayer = layers[0].superlayer {
            layers.insert(superlayer, at: 0)
        }
        return layers
    }

    /// From this layer's coordinates to the root's superlayer, which for a window is the screen.
    private var toScreen: CGAffineTransform {
        ancestry.reversed().reduce(.identity) { $0.concatenating($1.toSuperlayer) }
    }

    /// `nil` stands for the screen.
    open func convert(_ p: CGPoint, from l: CALayer?) -> CGPoint {
        p.applying((l?.toScreen ?? .identity).concatenating(toScreen.inverted()))
    }

    open func convert(_ p: CGPoint, to l: CALayer?) -> CGPoint {
        p.applying(toScreen.concatenating(l?.toScreen.inverted() ?? .identity))
    }

    open func convert(_ r: CGRect, from l: CALayer?) -> CGRect {
        r.applying((l?.toScreen ?? .identity).concatenating(toScreen.inverted()))
    }

    open func convert(_ r: CGRect, to l: CALayer?) -> CGRect {
        r.applying(toScreen.concatenating(l?.toScreen.inverted() ?? .identity))
    }

    open func contains(_ p: CGPoint) -> Bool {
        bounds.contains(p)
    }

    // MARK: Hierarchy

    open private(set) weak var superlayer: CALayer?

    private var children: [CALayer] = [] {
        didSet { changed(.sublayers) }
    }

    open var sublayers: [CALayer]? {
        get { children.isEmpty ? nil : children }
        set {
            for layer in children { layer.superlayer = nil }
            children = []
            for layer in newValue ?? [] { addSublayer(layer) }
        }
    }

    open func addSublayer(_ layer: CALayer) {
        insertSublayer(layer, at: UInt32(children.count - (layer.superlayer === self ? 1 : 0)))
    }

    open func insertSublayer(_ layer: CALayer, at idx: UInt32) {
        layer.removeFromSuperlayer()
        children.insert(layer, at: min(Int(idx), children.count))
        layer.superlayer = self
        layer.changed(.geometry)
    }

    open func insertSublayer(_ layer: CALayer, below sibling: CALayer?) {
        layer.removeFromSuperlayer()
        insertSublayer(layer, at: UInt32(sibling.flatMap { s in children.firstIndex { $0 === s } } ?? 0))
    }

    open func insertSublayer(_ layer: CALayer, above sibling: CALayer?) {
        layer.removeFromSuperlayer()
        insertSublayer(layer, at: UInt32(sibling.flatMap { s in children.firstIndex { $0 === s }.map { $0 + 1 } } ?? children.count))
    }

    open func replaceSublayer(_ oldLayer: CALayer, with newLayer: CALayer) {
        guard let index = children.firstIndex(where: { $0 === oldLayer }) else { return }
        oldLayer.removeFromSuperlayer()
        insertSublayer(newLayer, at: UInt32(index))
    }

    open func removeFromSuperlayer() {
        guard let superlayer else { return }
        superlayer.children.removeAll { $0 === self }
        self.superlayer = nil
    }

    // MARK: Appearance

    open var isHidden = false {
        didSet { changed(.style) }
    }

    /// Clips sublayers, and the contents, to the rounded bounds.
    open var masksToBounds = false {
        didSet { changed(.style) }
    }

    open var opacity: Float = 1 {
        didSet { changed(.style) }
    }

    open var isOpaque = false

    open var backgroundColor: CGColor? {
        didSet { changed(.style) }
    }

    open var cornerRadius: CGFloat = 0 {
        didSet { changed(.style) }
    }

    open var borderWidth: CGFloat = 0 {
        didSet { changed(.style) }
    }

    open var borderColor: CGColor? = .black {
        didSet { changed(.style) }
    }

    open var shadowColor: CGColor? = .black {
        didSet { changed(.style) }
    }

    /// No shadow until this is above 0.
    open var shadowOpacity: Float = 0 {
        didSet { changed(.style) }
    }

    /// Points; positive heights go down. By default the shadow is cast 3 points up.
    open var shadowOffset = CGSize(width: 0, height: -3) {
        didSet { changed(.style) }
    }

    /// The blur, in points.
    open var shadowRadius: CGFloat = 3 {
        didSet { changed(.style) }
    }

    // MARK: Contents

    /// What the layer shows in its bounds, under its sublayers: an image (`UIImage.cgImage`).
    open var contents: Any? {
        didSet { changed(.contents) }
    }

    /// Where the contents go in the bounds; by default they fill them.
    open var contentsGravity = CALayerContentsGravity.resize {
        didSet { changed(.contents) }
    }

    /// Pixels of the contents per point, for gravities that don't scale them.
    open var contentsScale: CGFloat = 1 {
        didSet { changed(.contents) }
    }

    /// Iris: paints the contents' opaque parts in one color, as UIKit draws template images.
    var irisContentsTint: CGColor? {
        didSet { changed(.contents) }
    }

    /// Iris: text or a shape that a UIKit view draws in its layer, in place of drawing with
    /// `draw(_:)`: above the contents and below the sublayers.
    var irisDrawing: IrisDrawing? {
        didSet { changed(.contents) }
    }

    /// Iris: a render core layer that another framework draws into and owns, such as the
    /// SwiftUI content of a hosting view: above the drawing and below the sublayers, placed by
    /// its owner in this layer's coordinates. The layer only attaches it, so that what it
    /// shows stays when the window is drawn again.
    public var _irisContentLayer: IrisRender.Layer? {
        didSet { changed(.sublayers) }
    }

    /// Iris: a render core layer of another framework that this layer's render layer goes in,
    /// in place of the superlayer's, as SwiftUI shows a UIViewRepresentable's view at its place
    /// among SwiftUI's content: the superlayer leaves this layer out, and the owner layer's
    /// coordinates must be the superlayer's, as the layer's frame stays in them.
    public var _irisOwnerLayer: IrisRender.Layer? {
        didSet {
            guard _irisOwnerLayer !== oldValue else { return }
            renderLayer?.removeFromSuperlayer()
            changed(.sublayers)
            superlayer?.changed(.sublayers)
        }
    }

    // MARK: Display

    private var displayPending = false

    /// Has `display()` run before the layer is next drawn.
    open func setNeedsDisplay() {
        displayPending = true
        changed(.contents)
    }

    open func needsDisplay() -> Bool {
        displayPending
    }

    open func displayIfNeeded() {
        guard displayPending else { return }
        displayPending = false
        display()
    }

    /// Updates the contents: a view draws itself with `draw(_:)`; other delegates are asked.
    open func display() {
        if let view = delegate as? UIView {
            MainActor.assumeIsolated { view.irisDisplay() }
        } else {
            delegate?.display(self)
        }
    }

    // MARK: Animations

    /// Iris: render core animations that start when the layer is next drawn, if the host shows
    /// animations (`irisAnimates`). UIKit's controls use them until CAAnimation comes.
    var irisAnimations: [IrisRender.Animation] = [] {
        didSet { changed(.style) }
    }

    /// Iris: stops the layer's animations when it is next drawn.
    var irisStopsAnimations = false {
        didSet { changed(.style) }
    }

    /// Iris: animates the next change of the frame and background color over these seconds, as
    /// the implicit animation of a control's `setOn(_:animated:)` does.
    var irisAnimationDuration: Double?

    // MARK: Layout

    private var layoutPending = false

    open func setNeedsLayout() {
        layoutPending = true
        LayerCommit.schedule()
    }

    open func needsLayout() -> Bool {
        layoutPending
    }

    /// Lays out this layer and the layers below it that need it, from the highest superlayer
    /// that needs layout down.
    open func layoutIfNeeded() {
        var top = self
        while let superlayer = top.superlayer, superlayer.layoutPending {
            top = superlayer
        }
        top.layoutTree()
    }

    private func layoutTree() {
        if layoutPending {
            layoutPending = false
            layoutSublayers()
        }
        for sublayer in children {
            sublayer.layoutTree()
        }
    }

    open func layoutSublayers() {
        delegate?.layoutSublayers(of: self)
    }

    // MARK: Iris: drawing with the render core

    struct Changes: OptionSet {
        let rawValue: UInt8
        static let geometry = Changes(rawValue: 1)
        static let style = Changes(rawValue: 2)
        static let sublayers = Changes(rawValue: 4)
        static let contents = Changes(rawValue: 8)
        static let all: Changes = [.geometry, .style, .sublayers, .contents]
    }

    /// What changed since the layer was last drawn.
    private(set) var changes = Changes.all
    /// The render core's copy of this layer, made the first time it is drawn.
    private(set) var renderLayer: IrisRender.Layer?
    /// Draws `irisDrawing`, below the sublayers' render layers.
    private var drawingLayer: IrisRender.Layer?

    private func changed(_ change: Changes) {
        changes.formUnion(change)
        LayerCommit.schedule()
    }

    /// Makes or updates the render core layers of this tree, sending only what changed. True
    /// if anything was sent.
    func draw(in scene: IrisRender.Scene) -> Bool {
        let layer: IrisRender.Layer
        if let renderLayer {
            layer = renderLayer
        } else {
            layer = IrisRender.Layer(in: scene)
            renderLayer = layer
            changes = .all
        }
        displayIfNeeded()
        var drew = !changes.isEmpty
        let animation = irisAnimates && changes != .all ? irisAnimationDuration : nil
        irisAnimationDuration = nil
        if changes.contains(.geometry) {
            let oldFrame = layer.frame
            // The render core places a layer by its untransformed frame inside the
            // superlayer's bounds, and turns it about its center.
            let origin = superlayer?.bounds.origin ?? .zero
            let size = bounds.size
            layer.frame = Rect(
                x: Float(position.x - anchorPoint.x * size.width - origin.x),
                y: Float(position.y - anchorPoint.y * size.height - origin.y),
                width: Float(size.width), height: Float(size.height)
            )
            // About the anchor point is about the center, moved by L·d − d for d from the
            // anchor point to the center.
            let d = CGPoint(x: (0.5 - anchorPoint.x) * size.width, y: (0.5 - anchorPoint.y) * size.height)
            let t = affine
            layer.transform = [
                Float(t.a), Float(t.b), Float(t.c), Float(t.d),
                Float(t.tx + t.a * d.x + t.c * d.y - d.x), Float(t.ty + t.b * d.x + t.d * d.y - d.y),
            ]
            if let animation, layer.frame != oldFrame {
                layer.add(Animation(from: .frame(oldFrame), to: .frame(layer.frame), duration: animation, timing: .easeInEaseOut))
            }
        }
        if changes.contains(.style) {
            let oldColor = layer.backgroundColor
            if irisStopsAnimations {
                layer.removeAllAnimations()
                irisStopsAnimations = false
            }
            if irisAnimates {
                for animation in irisAnimations {
                    layer.add(animation)
                }
            }
            irisAnimations = []
            layer.isHidden = isHidden
            layer.opacity = opacity
            layer.masksToBounds = masksToBounds
            layer.backgroundColor = backgroundColor?.argb ?? 0
            layer.cornerRadius = Float(cornerRadius)
            layer.setBorder(width: Float(borderWidth), color: borderColor?.argb ?? 0)
            let shadow = shadowOpacity > 0 ? shadowColor?.copy(alpha: (shadowColor?.alpha ?? 0) * CGFloat(shadowOpacity)) : nil
            layer.shadowColor = shadow?.argb ?? 0
            layer.shadowOffset = Point(x: Float(shadowOffset.width), y: Float(shadowOffset.height))
            layer.shadowRadius = Float(shadowRadius)
            if let animation, layer.backgroundColor != oldColor {
                layer.add(Animation(from: .backgroundColor(oldColor), to: .backgroundColor(layer.backgroundColor), duration: animation, timing: .easeInEaseOut))
            }
        }
        if changes.contains(.contents) {
            if let image = contents as? IrisCGImage {
                layer.contentMode = contentsGravity.contentMode
                layer.contentTint = irisContentsTint?.argb ?? 0
                layer.setImage(image.image.bytes.bytes, scale: Float(contentsScale))
            } else {
                // ponytail: images only; other contents draw nothing.
                layer.clearContent()
            }
            if drawingLayer == nil, irisDrawing != nil {
                drawingLayer = IrisRender.Layer(in: scene)
                changes.insert(.sublayers)
            } else if drawingLayer != nil, irisDrawing == nil {
                drawingLayer = nil
                changes.insert(.sublayers)
            }
            if let drawing = irisDrawing, let drawingLayer {
                drawing.draw(into: drawingLayer, origin: bounds.origin)
            }
        }
        for sublayer in children {
            drew = sublayer.draw(in: scene) || drew
        }
        if changes.contains(.sublayers) {
            for sublayer in layer.sublayers {
                sublayer.removeFromSuperlayer()
            }
            if let drawingLayer {
                layer.addSublayer(drawingLayer)
            }
            if let _irisContentLayer {
                layer.addSublayer(_irisContentLayer)
            }
            for sublayer in children where sublayer._irisOwnerLayer == nil {
                layer.addSublayer(sublayer.renderLayer!)
            }
            _irisOwnerLayer?.addSublayer(layer)
        }
        changes = []
        return drew
    }
}

/// Where a layer's contents go in its bounds.
public struct CALayerContentsGravity: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let center = CALayerContentsGravity(rawValue: "center")
    public static let top = CALayerContentsGravity(rawValue: "top")
    public static let bottom = CALayerContentsGravity(rawValue: "bottom")
    public static let left = CALayerContentsGravity(rawValue: "left")
    public static let right = CALayerContentsGravity(rawValue: "right")
    public static let topLeft = CALayerContentsGravity(rawValue: "topLeft")
    public static let topRight = CALayerContentsGravity(rawValue: "topRight")
    public static let bottomLeft = CALayerContentsGravity(rawValue: "bottomLeft")
    public static let bottomRight = CALayerContentsGravity(rawValue: "bottomRight")
    public static let resize = CALayerContentsGravity(rawValue: "resize")
    public static let resizeAspect = CALayerContentsGravity(rawValue: "resizeAspect")
    public static let resizeAspectFill = CALayerContentsGravity(rawValue: "resizeAspectFill")

    /// The render core's placement, which takes `UIView.ContentMode`'s. Gravities name edges as
    /// Core Animation's y axis goes, up, so on iOS `top` shows the contents at the bottom of the
    /// screen; UIKit maps `UIView.ContentMode.top` to `bottom` for that.
    var contentMode: IrisRender.ContentMode {
        switch self {
        case .resizeAspect: .scaleAspectFit
        case .resizeAspectFill: .scaleAspectFill
        case .center: .center
        case .top: .bottom
        case .bottom: .top
        case .left: .left
        case .right: .right
        case .topLeft: .bottomLeft
        case .topRight: .bottomRight
        case .bottomLeft: .topLeft
        case .bottomRight: .topRight
        default: .scaleToFill
        }
    }
}

/// Iris: draws the layers of the windows on screen into `irisScene` once per turn of the main
/// run loop, after laying them out, as Core Animation commits its implicit transaction.
enum LayerCommit {
    /// The layers of the windows on screen, back to front.
    nonisolated(unsafe) static var roots: [CALayer] = [] {
        didSet { rootsChanged = true; schedule() }
    }

    /// Called after a commit that changed `irisScene`, for the device host to send a frame.
    nonisolated(unsafe) static var didDraw: (() -> Void)?
    nonisolated(unsafe) private static var isScheduled = false
    nonisolated(unsafe) private static var rootsChanged = true
    /// The render layers of `roots` in the scene's root, which is UIKit's: OpenSwiftUI draws
    /// into hosting views' layers (`CALayer._irisContentLayer`).
    nonisolated(unsafe) private static var attached: [IrisRender.Layer] = []

    static func schedule() {
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async {
            commit()
        }
    }

    /// Lays out and draws what changed now. False if nothing did.
    @discardableResult
    static func commit() -> Bool {
        isScheduled = false
        guard let scene = irisScene else { return false }
        // Animations run on the render core's clock, which follows the uptime clock.
        scene.time = ProcessInfo.processInfo.systemUptime
        // What SwiftUI draws while its hosting views lay out counts too.
        let version = irisSceneVersion
        for root in roots {
            if let window = root.delegate as? UIView {
                MainActor.assumeIsolated { window.irisLayout { window.layer.layoutIfNeeded() } }
            } else {
                root.layoutIfNeeded()
            }
        }
        var drew = irisSceneVersion != version
        for root in roots {
            drew = root.draw(in: scene) || drew
        }
        if rootsChanged {
            rootsChanged = false
            drew = true
            for layer in attached {
                layer.removeFromSuperlayer()
            }
            attached = roots.map { $0.renderLayer! }
            for layer in attached {
                scene.root.addSublayer(layer)
            }
        }
        // While something animates, every frame is new.
        guard drew || scene.isAnimating else { return false }
        irisSceneVersion += 1
        didDraw?()
        return true
    }
}

/// Iris: what a UIKit view draws in its layer through the render core, at `frame` in the
/// layer's coordinates.
struct IrisDrawing {
    enum Content {
        case text(IrisText)
        /// A path in the drawing's own coordinates.
        case shape(IrisRender.Path, ShapeStyle)
    }

    var content: Content
    var frame: CGRect
    /// A sharp shadow, as `UILabel.shadowColor` casts.
    var shadow: (color: CGColor, offset: CGSize)?

    fileprivate func draw(into layer: IrisRender.Layer, origin: CGPoint) {
        layer.frame = Rect(
            x: Float(frame.minX - origin.x), y: Float(frame.minY - origin.y),
            width: Float(frame.width), height: Float(frame.height)
        )
        switch content {
        case let .text(text): layer.setText(text.string, runs: text.runs, paragraph: text.paragraph)
        case let .shape(path, style): layer.setShape(path, style: style)
        }
        layer.shadowColor = shadow?.color.argb ?? 0
        layer.shadowOffset = Point(x: Float(shadow?.offset.width ?? 0), y: Float(shadow?.offset.height ?? 0))
    }
}
