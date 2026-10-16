import Foundation
import IrisHost
import IrisRender

/// An image from the app's asset catalogs, a file or data, which the render core decodes when
/// it draws. Asset catalogs are read as Xcode writes them (`IrisAssetCatalog`), shared with
/// SwiftUI's `Image`.
// ponytail: no resizable or animated images, symbol configurations or drawing into images yet.
open class UIImage: NSObject, @unchecked Sendable {
    /// Nil for a symbol: SF Symbols need Apple's font.
    let encoded: IrisAssetCatalog.Image?
    open private(set) var size: CGSize
    open private(set) var scale: CGFloat
    open private(set) var renderingMode: UIImage.RenderingMode
    open private(set) var isSymbolImage: Bool
    /// The outline of a symbol that UIKit's own controls show.
    let symbol: IrisSymbol?

    init(_ encoded: IrisAssetCatalog.Image?, size: CGSize? = nil, renderingMode: RenderingMode? = nil, isSymbolImage: Bool = false, symbol: IrisSymbol? = nil) {
        self.encoded = encoded
        self.symbol = symbol
        scale = encoded?.scale ?? 1
        self.size = size ?? encoded.map { CGSize(width: $0.pixelSize.width / $0.scale, height: $0.pixelSize.height / $0.scale) } ?? .zero
        self.renderingMode = renderingMode ?? encoded?.isTemplate.map { $0 ? .alwaysTemplate : .alwaysOriginal } ?? .automatic
        self.isSymbolImage = isSymbolImage
        cgImage = encoded.map(IrisCGImage.init)
        super.init()
    }

    /// The image set of this name in the app's asset catalogs, or a loose file of the app.
    public convenience init?(named name: String) {
        self.init(named: name, in: nil, compatibleWith: nil)
    }

    public convenience init?(named name: String, in bundle: Bundle?, compatibleWith traitCollection: UITraitCollection?) {
        guard let image = IrisAssetCatalog.image(named: name, in: bundle ?? .main, scale: CGFloat(HostOptions.scale)) else {
            return nil
        }
        self.init(image)
    }

    /// The file's scale comes from its name: 2 for `name@2x.png`.
    public convenience init?(contentsOfFile path: String) {
        guard let image = IrisAssetCatalog.Image(contentsOfFile: path) else { return nil }
        self.init(image)
    }

    public convenience init?(data: Data) {
        self.init(data: data, scale: 1)
    }

    public convenience init?(data: Data, scale: CGFloat) {
        guard let image = IrisAssetCatalog.Image(bytes: [UInt8](data), scale: scale) else { return nil }
        self.init(image)
    }

    /// A blank the size of a symbol at the body text size, since SF Symbols need Apple's font;
    /// the few symbols UIKit's own buttons show are drawn (`IrisSymbol`).
    // ponytail: every other symbol is a blank 20-point square; real ones vary in width.
    public convenience init?(systemName name: String) {
        let symbol = IrisSymbol(rawValue: name)
        self.init(nil, size: CGSize(width: symbol == nil ? 20 : 22, height: symbol == nil ? 20 : 22), isSymbolImage: true, symbol: symbol)
    }

    public convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// ponytail: the orientation is taken as `.up`.
    public convenience init(cgImage: CGImage, scale: CGFloat, orientation: UIImage.Orientation) {
        var image = (cgImage as? IrisCGImage)?.image
        image?.scale = scale
        self.init(image)
    }

    /// The image for `CALayer.contents`; nil for symbols.
    open private(set) var cgImage: CGImage?

    open var imageOrientation: UIImage.Orientation {
        .up
    }

    open func withRenderingMode(_ renderingMode: UIImage.RenderingMode) -> UIImage {
        UIImage(encoded, size: size, renderingMode: renderingMode, isSymbolImage: isSymbolImage, symbol: symbol)
    }

    /// Iris: whether the image shows in the tint color: template images, and symbols unless
    /// they are always original.
    var irisIsTemplate: Bool {
        renderingMode == .alwaysTemplate || (renderingMode == .automatic && isSymbolImage)
    }
}

extension UIImage {
    public enum RenderingMode: Int, Sendable {
        case automatic = 0, alwaysOriginal, alwaysTemplate
    }

    public enum Orientation: Int, Sendable {
        case up = 0, down, left, right, upMirrored, downMirrored, leftMirrored, rightMirrored
    }
}

/// Iris: an SF Symbol of UIKit's own buttons and bar items, drawn as round-ended strokes.
enum IrisSymbol: String, Sendable {
    case infoCircle = "info.circle"
    case plusCircle = "plus.circle"
    case xmark
    case plus
    case listBullet = "list.bullet"
    case squareGrid = "square.grid.2x2"
    case star

    /// The strokes in a square of side `side` at the origin, and their width.
    func path(side s: CGFloat) -> (IrisRender.Path, lineWidth: CGFloat) {
        var path = IrisRender.Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> Point {
            Point(x: Float(x * s), y: Float(y * s))
        }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
            path.move(to: point(x1, y1))
            path.addLine(to: point(x2, y2))
        }
        func circle() {
            // Four quarter arcs, as cubic Béziers.
            let (r, k) = (0.45, 0.45 * 0.5523)
            path.move(to: point(0.5, 0.5 - r))
            path.addCurve(to: point(0.5 + r, 0.5), control1: point(0.5 + k, 0.5 - r), control2: point(0.5 + r, 0.5 - k))
            path.addCurve(to: point(0.5, 0.5 + r), control1: point(0.5 + r, 0.5 + k), control2: point(0.5 + k, 0.5 + r))
            path.addCurve(to: point(0.5 - r, 0.5), control1: point(0.5 - k, 0.5 + r), control2: point(0.5 - r, 0.5 + k))
            path.addCurve(to: point(0.5, 0.5 - r), control1: point(0.5 - r, 0.5 - k), control2: point(0.5 - k, 0.5 - r))
            path.closeSubpath()
        }
        switch self {
        case .infoCircle:
            circle()
            line(0.5, 0.45, 0.5, 0.71)
            // The dot: a stroke too short to see but for its round ends.
            line(0.5, 0.3, 0.5, 0.301)
            return (path, 0.075 * s)
        case .plusCircle:
            circle()
            line(0.5, 0.29, 0.5, 0.71)
            line(0.29, 0.5, 0.71, 0.5)
            return (path, 0.075 * s)
        case .xmark:
            line(0.3, 0.3, 0.7, 0.7)
            line(0.7, 0.3, 0.3, 0.7)
            return (path, 0.1 * s)
        case .plus:
            line(0.5, 0.18, 0.5, 0.82)
            line(0.18, 0.5, 0.82, 0.5)
            return (path, 0.09 * s)
        case .listBullet:
            for y in [0.27, 0.5, 0.73] {
                line(0.15, y, 0.15, y + 0.001)
                line(0.36, y, 0.88, y)
            }
            return (path, 0.08 * s)
        case .squareGrid:
            for (x, y) in [(0.12, 0.12), (0.56, 0.12), (0.12, 0.56), (0.56, 0.56)] {
                path.move(to: point(x, y))
                for (dx, dy) in [(0.32, 0.0), (0.32, 0.32), (0.0, 0.32)] {
                    path.addLine(to: point(x + dx, y + dy))
                }
                path.closeSubpath()
            }
            return (path, 0.07 * s)
        case .star:
            // Five points out, five in, from the top.
            for index in 0 ..< 10 {
                let angle = Double(index) * .pi / 5 - .pi / 2
                let radius = index % 2 == 0 ? 0.44 : 0.18
                let corner = point(0.5 + radius * cos(angle), 0.54 + radius * sin(angle))
                if index == 0 {
                    path.move(to: corner)
                } else {
                    path.addLine(to: corner)
                }
            }
            path.closeSubpath()
            return (path, 0.07 * s)
        }
    }

    /// The symbol stroked in `color`, in the middle of `rect`.
    func drawing(in rect: CGRect, color: UIColor) -> IrisDrawing {
        let side = min(rect.width, rect.height)
        let (path, lineWidth) = path(side: side)
        return IrisDrawing(
            content: .shape(path, ShapeStyle(fill: 0, stroke: color.cgColor.argb, lineWidth: Float(lineWidth), lineCap: .round, lineJoin: .round)),
            frame: CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        )
    }
}

/// Iris: a CGImage of an encoded image, which `CALayer.contents` draws.
final class IrisCGImage: CGImage, @unchecked Sendable {
    let image: IrisAssetCatalog.Image

    init(_ image: IrisAssetCatalog.Image) {
        self.image = image
        super.init()
    }
}

/// The traits of the interface, such as its size class and appearance.
// ponytail: no traits yet; they come with dark mode and Dynamic Type.
open class UITraitCollection: NSObject, @unchecked Sendable {
    public override init() {
        super.init()
    }
}
