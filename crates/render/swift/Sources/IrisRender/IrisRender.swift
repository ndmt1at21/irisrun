import CIrisRender

/// The layers of one window, drawn into frames by the render core.
public final class Scene {
    let raw: OpaquePointer
    /// Fills the scene. It lives as long as the scene.
    public private(set) var root: Layer!

    public init(width: Float, height: Float, scale: Float) {
        raw = iris_scene_new(width, height, scale)
        root = Layer(root: self)
    }

    deinit {
        // Frees every layer; Layer objects still around become inert.
        iris_scene_free(raw)
    }

    /// Adds a TrueType or OpenType font; false if the data is not a font.
    /// Fonts added first are tried first for each character.
    @discardableResult
    public func addFont(_ data: [UInt8]) -> Bool {
        data.withUnsafeBufferPointer { iris_scene_add_font(raw, $0.baseAddress, $0.count) }
    }

    /// The size text takes when its lines may be up to `maxWidth` wide.
    public func measure(_ text: String, style: TextStyle, maxWidth: Float = .infinity) -> Size {
        var size = Size(width: 0, height: 0)
        var style = style.raw
        iris_scene_measure_text(raw, text, &style, maxWidth, &size.width, &size.height)
        return size
    }

    /// Draws the layers and encodes the frame.
    public func encode(_ format: ImageFormat, quality: UInt8 = 90) -> [UInt8]? {
        let bytes = iris_scene_encode(raw, format.raw, quality)
        defer { iris_bytes_free(bytes) }
        guard let data = bytes.data else { return nil }
        return Array(UnsafeBufferPointer(start: data, count: bytes.len))
    }
}

public enum ImageFormat: Sendable {
    case png, jpeg

    var raw: IrisImageFormat { self == .png ? IRIS_IMAGE_FORMAT_PNG : IRIS_IMAGE_FORMAT_JPEG }
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

public struct TextStyle: Sendable {
    public enum Alignment: Sendable { case leading, center, trailing }

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

    var raw: IrisTextStyle {
        let align = switch alignment {
        case .leading: IRIS_TEXT_ALIGN_LEADING
        case .center: IRIS_TEXT_ALIGN_CENTER
        case .trailing: IRIS_TEXT_ALIGN_TRAILING
        }
        return IrisTextStyle(size: size, weight: weight, color: color, align: align, max_lines: maxLines)
    }
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
    }

    fileprivate init(root scene: Scene) {
        self.scene = scene
        id = iris_scene_root(scene.raw)
    }

    deinit {
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

    public func setBorder(width: Float, color: UInt32) {
        iris_layer_set_border(raw, id, width, color)
    }

    public func setText(_ text: String, style: TextStyle) {
        var style = style.raw
        iris_layer_set_text(raw, id, text, &style)
    }

    /// PNG, JPEG, WebP, GIF or BMP; false if it cannot be decoded.
    @discardableResult
    public func setImage(_ data: [UInt8]) -> Bool {
        data.withUnsafeBufferPointer { iris_layer_set_image(raw, id, $0.baseAddress, $0.count) }
    }
}
