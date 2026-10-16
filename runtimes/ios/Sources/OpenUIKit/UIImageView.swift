import Foundation

/// A view that shows an image, placed by its content mode, in the tint color if the image is
/// a template.
// ponytail: no animated images (animationImages) or symbol configurations yet.
@preconcurrency @MainActor
open class UIImageView: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
    }

    /// As large as the image.
    public init(image: UIImage?) {
        super.init(frame: CGRect(origin: .zero, size: image?.size ?? .zero))
        isUserInteractionEnabled = false
        self.image = image
        imageDidChange()
    }

    public convenience init(image: UIImage?, highlightedImage: UIImage?) {
        self.init(image: image)
        self.highlightedImage = highlightedImage
    }

    open var image: UIImage? {
        didSet { imageDidChange() }
    }

    open var highlightedImage: UIImage? {
        didSet { imageDidChange() }
    }

    open var isHighlighted = false {
        didSet { imageDidChange() }
    }

    open override var intrinsicContentSize: CGSize {
        image?.size ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        image?.size ?? .zero
    }

    open override func tintColorDidChange() {
        imageDidChange()
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        drawSymbol()
    }

    private var shownImage: UIImage? {
        isHighlighted ? highlightedImage ?? image : image
    }

    private func imageDidChange() {
        let image = shownImage
        layer.contents = image?.cgImage
        layer.contentsScale = image?.scale ?? 1
        layer.irisContentsTint = image?.irisIsTemplate == true ? tintColor.cgColor : nil
        invalidateIntrinsicContentSize()
        drawSymbol()
    }

    /// Symbols have no bitmap: the view draws their strokes, placed by the content mode.
    private func drawSymbol() {
        guard let image = shownImage, let symbol = image.symbol else {
            layer.irisDrawing = nil
            return
        }
        let rect = contentMode.rect(for: image.size, in: bounds)
        layer.irisDrawing = symbol.drawing(in: rect, color: image.irisIsTemplate ? tintColor : .label)
    }
}
