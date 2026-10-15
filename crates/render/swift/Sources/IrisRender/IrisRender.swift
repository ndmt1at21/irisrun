import CIrisRender

/// The layers of one window, drawn into frames by the render core.
public final class Scene {
    let raw: OpaquePointer
    /// Fills the scene. It lives as long as the scene.
    public private(set) var root: Layer!
    /// Every live layer by id, for hit-testing.
    fileprivate var layers: [IrisLayer: Weak] = [:]

    public init(width: Float, height: Float, scale: Float) {
        raw = iris_scene_new(width, height, scale)
        root = Layer(root: self)
    }

    deinit {
        // Frees every layer; Layer objects still around become inert.
        iris_scene_free(raw)
    }

    public func resize(width: Float, height: Float, scale: Float) {
        iris_scene_resize(raw, width, height, scale)
    }

    /// Adds a TrueType or OpenType font; false if the data is not a font.
    /// Fonts added first are tried first for each character.
    @discardableResult
    public func addFont(_ data: [UInt8]) -> Bool {
        data.withUnsafeBufferPointer { iris_scene_add_font(raw, $0.baseAddress, $0.count) }
    }

    /// Adds a font file, mapped rather than read: a large CJK font then takes
    /// memory only for the glyphs drawn.
    @discardableResult
    public func addFont(path: String) -> Bool {
        iris_scene_add_font_file(raw, path)
    }

    /// The metrics of the first font added.
    public func fontMetrics(size: Float, weight: UInt16 = 400) -> FontMetrics? {
        var metrics = IrisFontMetrics()
        guard iris_scene_font_metrics(raw, size, weight, &metrics) else { return nil }
        return FontMetrics(
            ascender: metrics.ascender, descender: metrics.descender, leading: metrics.leading,
            capHeight: metrics.cap_height, xHeight: metrics.x_height
        )
    }

    /// How text in one style lays out in lines up to `maxWidth` wide.
    public func measure(_ text: String, style: TextStyle, maxWidth: Float = .infinity) -> TextMetrics {
        measure(text, runs: [style.run(for: text)], paragraph: style.paragraph, maxWidth: maxWidth)
    }

    /// How text in runs of styles lays out in lines up to `maxWidth` wide.
    public func measure(_ text: String, runs: [TextRun], paragraph: ParagraphStyle = ParagraphStyle(), maxWidth: Float = .infinity) -> TextMetrics {
        var metrics = IrisTextMetrics()
        var paragraph = paragraph.raw
        let runs = runs.map(\.raw)
        iris_scene_measure_text(raw, text, runs, runs.count, &paragraph, maxWidth, &metrics)
        return TextMetrics(
            width: metrics.width, height: metrics.height,
            firstBaseline: metrics.first_baseline, lastBaseline: metrics.last_baseline,
            lineCount: Int(metrics.line_count), isTruncated: metrics.truncated
        )
    }

    /// The clock animations run on, in seconds. Move it with real time, or
    /// with a virtual clock in tests.
    public var time: Double = 0 {
        didSet { iris_scene_set_time(raw, time) }
    }

    /// Whether an animation is still to run, so frames still change.
    public var isAnimating: Bool { iris_scene_is_animating(raw) }

    /// The front-most layer at a point, as `CALayer.hitTest` finds it.
    public func hitTest(_ point: Point) -> Layer? {
        layers[iris_scene_hit_test(raw, point.x, point.y)]?.layer
    }

    /// Draws the layers into a frame, which any thread may encode.
    public func render() -> Frame {
        Frame(iris_scene_render(raw))
    }

    /// Draws the layers and encodes the frame.
    public func encode(_ format: ImageFormat, quality: UInt8 = 90) -> [UInt8]? {
        bytes(iris_scene_encode(raw, format.raw, quality))
    }
}

/// A frame drawn by a scene. Immutable, so any thread may encode it.
public final class Frame: @unchecked Sendable {
    private let raw: OpaquePointer

    fileprivate init(_ raw: OpaquePointer) {
        self.raw = raw
    }

    deinit {
        iris_frame_free(raw)
    }

    public func encode(_ format: ImageFormat, quality: UInt8 = 90) -> [UInt8]? {
        bytes(iris_frame_encode(raw, format.raw, quality))
    }
}

private func bytes(_ bytes: IrisBytes) -> [UInt8]? {
    defer { iris_bytes_free(bytes) }
    guard let data = bytes.data else { return nil }
    return Array(UnsafeBufferPointer(start: data, count: bytes.len))
}

fileprivate struct Weak {
    weak var layer: Layer?
}

public enum ImageFormat: Sendable {
    case png, jpeg

    var raw: IrisImageFormat { self == .png ? IRIS_IMAGE_FORMAT_PNG : IRIS_IMAGE_FORMAT_JPEG }
}

public struct Point: Equatable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct Size: Equatable, Sendable {
    public var width: Float
    public var height: Float

    public init(width: Float, height: Float) {
        self.width = width
        self.height = height
    }
}

public struct Rect: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var width: Float
    public var height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
}

// MARK: - Text

public enum TextAlignment: Sendable {
    case leading, center, trailing

    var raw: IrisTextAlign {
        switch self {
        case .leading: IRIS_TEXT_ALIGN_LEADING
        case .center: IRIS_TEXT_ALIGN_CENTER
        case .trailing: IRIS_TEXT_ALIGN_TRAILING
        }
    }
}

/// One style for a whole text.
public struct TextStyle: Sendable {
    public typealias Alignment = TextAlignment

    public var size: Float
    public var weight: UInt16
    /// 0xAARRGGBB.
    public var color: UInt32
    public var alignment: Alignment
    /// 0 means no limit.
    public var maxLines: UInt32

    public init(size: Float = 17, weight: UInt16 = 400, color: UInt32 = 0xFF00_0000, alignment: Alignment = .leading, maxLines: UInt32 = 0) {
        self.size = size
        self.weight = weight
        self.color = color
        self.alignment = alignment
        self.maxLines = maxLines
    }

    func run(for text: String) -> TextRun {
        TextRun(0 ..< text.utf8.count, size: size, weight: weight, color: color)
    }

    var paragraph: ParagraphStyle { ParagraphStyle(alignment: alignment, maxLines: maxLines) }
}

/// How a range of UTF-8 bytes of a text looks. Bytes no run covers are
/// 17-point black regular text.
public struct TextRun: Sendable {
    public var range: Range<Int>
    public var size: Float
    public var weight: UInt16
    /// 0xAARRGGBB, also of underlines and strikethroughs.
    public var color: UInt32
    public var isItalic: Bool
    public var isUnderlined: Bool
    public var isStruckThrough: Bool
    /// Points added after each character.
    public var letterSpacing: Float
    /// Points the run is raised by.
    public var baselineOffset: Float

    public init(_ range: Range<Int>, size: Float = 17, weight: UInt16 = 400, color: UInt32 = 0xFF00_0000, isItalic: Bool = false, isUnderlined: Bool = false, isStruckThrough: Bool = false, letterSpacing: Float = 0, baselineOffset: Float = 0) {
        self.range = range
        self.size = size
        self.weight = weight
        self.color = color
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.isStruckThrough = isStruckThrough
        self.letterSpacing = letterSpacing
        self.baselineOffset = baselineOffset
    }

    var raw: IrisTextRun {
        var traits: UInt32 = 0
        if isItalic { traits |= IRIS_TEXT_ITALIC.rawValue }
        if isUnderlined { traits |= IRIS_TEXT_UNDERLINE.rawValue }
        if isStruckThrough { traits |= IRIS_TEXT_STRIKETHROUGH.rawValue }
        return IrisTextRun(
            start: max(range.lowerBound, 0), end: max(range.upperBound, 0), size: size, weight: weight,
            color: color, traits: traits, letter_spacing: letterSpacing, baseline_offset: baselineOffset
        )
    }
}

public struct ParagraphStyle: Sendable {
    public var alignment: TextAlignment
    /// 0 means no limit; otherwise the last line ends with "…".
    public var maxLines: UInt32
    /// Points added between lines.
    public var lineSpacing: Float

    public init(alignment: TextAlignment = .leading, maxLines: UInt32 = 0, lineSpacing: Float = 0) {
        self.alignment = alignment
        self.maxLines = maxLines
        self.lineSpacing = lineSpacing
    }

    var raw: IrisParagraphStyle {
        IrisParagraphStyle(align: alignment.raw, max_lines: maxLines, line_spacing: lineSpacing)
    }
}

/// Where laid-out text sits; distances in points from its top.
public struct TextMetrics: Equatable, Sendable {
    public var width: Float
    public var height: Float
    public var firstBaseline: Float
    public var lastBaseline: Float
    public var lineCount: Int
    /// `maxLines` cut lines off.
    public var isTruncated: Bool
}

/// In points; the ascender is positive and the descender negative, as in `UIFont`.
public struct FontMetrics: Equatable, Sendable {
    public var ascender: Float
    public var descender: Float
    public var leading: Float
    public var capHeight: Float
    public var xHeight: Float
}

// MARK: - Shapes and gradients

/// A path in a layer's coordinates.
public struct Path: Sendable {
    public enum Element: Sendable {
        case move(to: Point)
        case line(to: Point)
        case quadCurve(to: Point, control: Point)
        case curve(to: Point, control1: Point, control2: Point)
        case closeSubpath
    }

    public var elements: [Element] = []

    public init() {}

    public mutating func move(to point: Point) { elements.append(.move(to: point)) }
    public mutating func addLine(to point: Point) { elements.append(.line(to: point)) }
    public mutating func addQuadCurve(to point: Point, control: Point) { elements.append(.quadCurve(to: point, control: control)) }
    public mutating func addCurve(to point: Point, control1: Point, control2: Point) { elements.append(.curve(to: point, control1: control1, control2: control2)) }
    public mutating func closeSubpath() { elements.append(.closeSubpath) }

    var raw: [IrisPathElement] {
        elements.map { element in
            switch element {
            case let .move(p): IrisPathElement(verb: IRIS_PATH_MOVE, points: (p.x, p.y, 0, 0, 0, 0))
            case let .line(p): IrisPathElement(verb: IRIS_PATH_LINE, points: (p.x, p.y, 0, 0, 0, 0))
            case let .quadCurve(p, c): IrisPathElement(verb: IRIS_PATH_QUAD, points: (c.x, c.y, p.x, p.y, 0, 0))
            case let .curve(p, c1, c2): IrisPathElement(verb: IRIS_PATH_CUBIC, points: (c1.x, c1.y, c2.x, c2.y, p.x, p.y))
            case .closeSubpath: IrisPathElement(verb: IRIS_PATH_CLOSE, points: (0, 0, 0, 0, 0, 0))
            }
        }
    }
}

/// How a shape layer fills and strokes its path, as `CAShapeLayer`.
public struct ShapeStyle: Sendable {
    public enum LineCap: UInt32, Sendable { case butt, round, square }
    public enum LineJoin: UInt32, Sendable { case miter, round, bevel }

    /// 0xAARRGGBB; 0 for none.
    public var fill: UInt32
    public var stroke: UInt32
    public var lineWidth: Float
    public var lineCap: LineCap
    public var lineJoin: LineJoin
    public var miterLimit: Float
    /// The fill rule; false is nonzero winding.
    public var isEvenOdd: Bool
    /// Lengths of dashes and gaps in turn; empty for a solid line.
    public var dashes: [Float]
    public var dashPhase: Float

    public init(fill: UInt32 = 0xFF00_0000, stroke: UInt32 = 0, lineWidth: Float = 1, lineCap: LineCap = .butt, lineJoin: LineJoin = .miter, miterLimit: Float = 10, isEvenOdd: Bool = false, dashes: [Float] = [], dashPhase: Float = 0) {
        self.fill = fill
        self.stroke = stroke
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.isEvenOdd = isEvenOdd
        self.dashes = dashes
        self.dashPhase = dashPhase
    }
}

/// Colors blended across a layer's rounded bounds, as `CAGradientLayer`.
public struct Gradient: Sendable {
    public enum Kind: Sendable {
        case linear(start: Point, end: Point)
        case radial(center: Point, startRadius: Float, endRadius: Float)
        /// Angles in radians, clockwise from the positive x axis.
        case conic(center: Point, startAngle: Float, endAngle: Float)
    }

    public var kind: Kind
    /// 0xAARRGGBB, at least two.
    public var colors: [UInt32]
    /// From 0 to 1, one per color; nil spaces them evenly.
    public var locations: [Float]?

    public init(_ kind: Kind, colors: [UInt32], locations: [Float]? = nil) {
        self.kind = kind
        self.colors = colors
        self.locations = locations
    }
}

// MARK: - Animations

/// A change of one property over time, as `CABasicAnimation`. The layer's own
/// value shows before it begins and after it ends, so set the layer to the
/// final value when adding one.
public struct Animation: Sendable {
    public enum Value: Sendable {
        case opacity(Float)
        case frame(Rect)
        /// `[a, b, c, d, tx, ty]` about the layer's center.
        case transform([Float])
        /// 0xAARRGGBB.
        case backgroundColor(UInt32)
        case cornerRadius(Float)
    }

    /// A cubic Bézier from (0, 0) to (1, 1), as `CAMediaTimingFunction`.
    public struct Timing: Sendable {
        public var x1, y1, x2, y2: Float

        public init(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) {
            (self.x1, self.y1, self.x2, self.y2) = (x1, y1, x2, y2)
        }

        public static let linear = Timing(0, 0, 1, 1)
        public static let easeIn = Timing(0.42, 0, 1, 1)
        public static let easeOut = Timing(0, 0, 0.58, 1)
        public static let easeInEaseOut = Timing(0.42, 0, 0.58, 1)
        public static let `default` = Timing(0.25, 0.1, 0.25, 1)
    }

    public var from: Value
    /// The same property as `from`.
    public var to: Value
    /// Seconds.
    public var duration: Double
    /// Seconds from when it is added.
    public var delay: Double
    public var timing: Timing
    /// Up to 1 plays once; `.infinity` repeats forever.
    public var repeatCount: Float
    public var autoreverses: Bool

    public init(from: Value, to: Value, duration: Double, delay: Double = 0, timing: Timing = .default, repeatCount: Float = 1, autoreverses: Bool = false) {
        self.from = from
        self.to = to
        self.duration = duration
        self.delay = delay
        self.timing = timing
        self.repeatCount = repeatCount
        self.autoreverses = autoreverses
    }

    var raw: IrisAnimation? {
        var animation = IrisAnimation()
        func set(_ value: Value, _ numbers: inout (Float, Float, Float, Float, Float, Float), _ color: inout UInt32) -> IrisProperty {
            switch value {
            case let .opacity(v): numbers.0 = v; return IRIS_PROPERTY_OPACITY
            case let .cornerRadius(v): numbers.0 = v; return IRIS_PROPERTY_CORNER_RADIUS
            case let .frame(r): numbers = (r.x, r.y, r.width, r.height, 0, 0); return IRIS_PROPERTY_FRAME
            case let .backgroundColor(c): color = c; return IRIS_PROPERTY_BACKGROUND_COLOR
            case let .transform(t):
                precondition(t.count == 6, "an affine transform has 6 numbers")
                numbers = (t[0], t[1], t[2], t[3], t[4], t[5])
                return IRIS_PROPERTY_TRANSFORM
            }
        }
        let property = set(from, &animation.from, &animation.from_color)
        guard set(to, &animation.to, &animation.to_color) == property else { return nil }
        animation.property = property
        animation.duration = duration
        animation.delay = delay
        animation.timing = (timing.x1, timing.y1, timing.x2, timing.y2)
        animation.repeat_count = repeatCount
        animation.autoreverses = autoreverses
        return animation
    }
}

// MARK: - Layers

/// Where an image goes in a layer; the raw values of `UIView.ContentMode`.
public enum ContentMode: UInt32, Sendable {
    case scaleToFill = 0, scaleAspectFit, scaleAspectFill, redraw
    case center, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
}

/// A layer in the style of `CALayer`: a superlayer keeps its sublayers
/// alive, and a layer nothing refers to is destroyed. A layer whose scene is
/// gone does nothing.
public final class Layer {
    private weak var scene: Scene?
    let id: IrisLayer
    public private(set) var sublayers: [Layer] = []
    public private(set) weak var superlayer: Layer?

    public init(in scene: Scene) {
        self.scene = scene
        id = iris_layer_new(scene.raw)
        scene.layers[id] = Weak(layer: self)
    }

    fileprivate init(root scene: Scene) {
        self.scene = scene
        id = iris_scene_root(scene.raw)
        scene.layers[id] = Weak(layer: self)
    }

    deinit {
        scene?.layers[id] = nil
        // Fails harmlessly for the root, which lives as long as the scene.
        iris_layer_destroy(raw, id)
    }

    /// Null once the scene is gone, which the render core ignores.
    private var raw: OpaquePointer? { scene?.raw }

    public func addSublayer(_ layer: Layer) {
        layer.removeFromSuperlayer()
        iris_layer_add_sublayer(raw, id, layer.id)
        sublayers.append(layer)
        layer.superlayer = self
    }

    public func removeFromSuperlayer() {
        guard let superlayer else { return }
        iris_layer_remove_from_parent(raw, id)
        superlayer.sublayers.removeAll { $0 === self }
        self.superlayer = nil
    }

    /// In the superlayer's coordinates, in points.
    public var frame = Rect.zero {
        didSet { iris_layer_set_frame(raw, id, frame.x, frame.y, frame.width, frame.height) }
    }

    /// 0xAARRGGBB.
    public var backgroundColor: UInt32 = 0 {
        didSet { iris_layer_set_background_color(raw, id, backgroundColor) }
    }

    public var cornerRadius: Float = 0 {
        didSet { iris_layer_set_corner_radius(raw, id, cornerRadius) }
    }

    public var opacity: Float = 1 {
        didSet { iris_layer_set_opacity(raw, id, opacity) }
    }

    public var isHidden = false {
        didSet { iris_layer_set_hidden(raw, id, isHidden) }
    }

    public var masksToBounds = false {
        didSet { iris_layer_set_masks_to_bounds(raw, id, masksToBounds) }
    }

    /// An affine transform about the layer's center, as `[a, b, c, d, tx, ty]`.
    public var transform: [Float] = [1, 0, 0, 1, 0, 0] {
        didSet {
            precondition(transform.count == 6, "an affine transform has 6 numbers")
            iris_layer_set_transform(raw, id, transform)
        }
    }

    /// Clips the layer and its sublayers, for drawing and hit-testing.
    public var mask: Path? {
        didSet {
            let path = mask?.raw ?? []
            iris_layer_set_mask(raw, id, path, path.count, false)
        }
    }

    /// 0xAARRGGBB of a shadow cast by all the layer draws; 0 for none.
    /// Masking to bounds clips it away, as in Core Animation.
    public var shadowColor: UInt32 = 0 {
        didSet { updateShadow() }
    }

    /// Points, positive y downwards.
    public var shadowOffset = Point(x: 0, y: 0) {
        didSet { updateShadow() }
    }

    /// The blur, in points.
    public var shadowRadius: Float = 0 {
        didSet { updateShadow() }
    }

    private func updateShadow() {
        iris_layer_set_shadow(raw, id, shadowColor, shadowOffset.x, shadowOffset.y, shadowRadius)
    }

    public var contentMode = ContentMode.scaleToFill {
        didSet { iris_layer_set_content_mode(raw, id, contentMode.rawValue) }
    }

    public func setBorder(width: Float, color: UInt32) {
        iris_layer_set_border(raw, id, width, color)
    }

    public func setText(_ text: String, style: TextStyle) {
        setText(text, runs: [style.run(for: text)], paragraph: style.paragraph)
    }

    public func setText(_ text: String, runs: [TextRun], paragraph: ParagraphStyle = ParagraphStyle()) {
        var paragraph = paragraph.raw
        let runs = runs.map(\.raw)
        iris_layer_set_text(raw, id, text, runs, runs.count, &paragraph)
    }

    /// PNG, JPEG, WebP, GIF or BMP with `scale` pixels per point; false if it
    /// cannot be decoded.
    @discardableResult
    public func setImage(_ data: [UInt8], scale: Float = 1) -> Bool {
        data.withUnsafeBufferPointer { iris_layer_set_image(raw, id, $0.baseAddress, $0.count, scale) }
    }

    /// RGBA pixels, 8 bits a channel, rows `rowBytes` apart.
    @discardableResult
    public func setImage(rgba: [UInt8], width: Int, height: Int, rowBytes: Int, premultiplied: Bool, scale: Float = 1) -> Bool {
        rgba.withUnsafeBufferPointer {
            iris_layer_set_image_pixels(raw, id, Int32(width), Int32(height), $0.baseAddress, rowBytes, premultiplied, scale)
        }
    }

    public func setShape(_ path: Path, style: ShapeStyle) {
        let elements = path.raw
        style.dashes.withUnsafeBufferPointer { dashes in
            var raw = IrisShapeStyle(
                fill: style.fill, stroke: style.stroke, line_width: style.lineWidth,
                line_cap: IrisLineCap(style.lineCap.rawValue), line_join: IrisLineJoin(style.lineJoin.rawValue),
                miter_limit: style.miterLimit, even_odd: style.isEvenOdd,
                dashes: dashes.baseAddress, dash_count: dashes.count, dash_phase: style.dashPhase
            )
            iris_layer_set_shape(self.raw, id, elements, elements.count, &raw)
        }
    }

    /// False with fewer than two colors, or locations that don't match them.
    @discardableResult
    public func setGradient(_ gradient: Gradient) -> Bool {
        var raw = IrisGradient()
        switch gradient.kind {
        case let .linear(start, end):
            raw.kind = IRIS_GRADIENT_LINEAR
            (raw.start_x, raw.start_y, raw.end_x, raw.end_y) = (start.x, start.y, end.x, end.y)
        case let .radial(center, startRadius, endRadius):
            raw.kind = IRIS_GRADIENT_RADIAL
            (raw.center_x, raw.center_y, raw.start_radius, raw.end_radius) = (center.x, center.y, startRadius, endRadius)
        case let .conic(center, startAngle, endAngle):
            raw.kind = IRIS_GRADIENT_CONIC
            (raw.center_x, raw.center_y, raw.start_angle, raw.end_angle) = (center.x, center.y, startAngle, endAngle)
        }
        if let locations = gradient.locations, locations.count != gradient.colors.count {
            return false
        }
        raw.count = gradient.colors.count
        return gradient.colors.withUnsafeBufferPointer { colors in
            (gradient.locations ?? []).withUnsafeBufferPointer { locations in
                raw.colors = colors.baseAddress
                raw.locations = gradient.locations == nil ? nil : locations.baseAddress
                return iris_layer_set_gradient(self.raw, id, &raw)
            }
        }
    }

    public func clearContent() {
        iris_layer_clear_content(raw, id)
    }

    /// Starts an animation on the scene's clock, replacing one of the same
    /// property. False if `from` and `to` are different properties.
    @discardableResult
    public func add(_ animation: Animation) -> Bool {
        guard var animation = animation.raw else { return false }
        return iris_layer_add_animation(raw, id, &animation)
    }

    public func removeAllAnimations() {
        iris_layer_remove_animations(raw, id)
    }
}
