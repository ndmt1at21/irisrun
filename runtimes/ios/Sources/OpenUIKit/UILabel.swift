import Foundation
import IrisRender

/// A view that shows text: plain, in the label's font and color, or attributed. It measures and
/// draws through the render core, so its sizes fit what shows, and draws the text centered
/// vertically in its bounds, as UIKit does.
// ponytail: head and middle truncation, clipping and wrapping modes cut the last line with "…"
// as tail truncation does; the render core truncates at the tail only.
@preconcurrency @MainActor
open class UILabel: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    // MARK: Text

    /// The text as set: plain, or with attributes of its own when `isAttributed`.
    private var content: NSAttributedString?
    private var isAttributed = false

    open var text: String? {
        get { content?.string }
        set {
            content = newValue.map { NSAttributedString(string: $0) }
            isAttributed = false
            textDidChange()
        }
    }

    /// The text with all its attributes: its own, and the label's where it has none.
    open var attributedText: NSAttributedString? {
        get {
            guard let content else { return nil }
            let style = NSMutableParagraphStyle()
            style.alignment = textAlignment
            style.lineBreakMode = lineBreakMode
            let text = NSMutableAttributedString(string: content.string, attributes: [.font: font!, .foregroundColor: textColor!, .paragraphStyle: style])
            content.enumerateAttributes(in: NSRange(location: 0, length: content.length), options: []) { attributes, range, _ in
                text._irisAddAttributes(attributes, range: range)
            }
            return text
        }
        set {
            content = newValue.map { NSAttributedString(attributedString: $0) }
            isAttributed = newValue != nil
            textDidChange()
        }
    }

    open var font: UIFont! = .systemFont(ofSize: 17) {
        didSet {
            font = font ?? .systemFont(ofSize: 17)
            applyToAttributedText(.font, font!)
        }
    }

    open var textColor: UIColor! = .label {
        didSet {
            textColor = textColor ?? .label
            applyToAttributedText(.foregroundColor, textColor!)
        }
    }

    /// Applies to all of an attributed text, overriding its paragraphs' alignment.
    open var textAlignment = NSTextAlignment.natural {
        didSet {
            if isAttributed, let content {
                let text = NSMutableAttributedString(attributedString: content)
                var styles: [(NSRange, NSParagraphStyle)] = []
                text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length), options: []) { value, range, _ in
                    let style = (value as? NSParagraphStyle ?? .default).mutableCopy() as! NSMutableParagraphStyle
                    style.alignment = textAlignment
                    styles.append((range, style))
                }
                for (range, style) in styles {
                    text._irisAddAttribute(.paragraphStyle, value: style, range: range)
                }
                self.content = text
            }
            textDidChange()
        }
    }

    /// As UIKit does, a font or color set on a label with attributed text applies to all of it.
    private func applyToAttributedText(_ key: NSAttributedString.Key, _ value: Any) {
        if isAttributed, let content {
            let text = NSMutableAttributedString(attributedString: content)
            text._irisAddAttribute(key, value: value, range: NSRange(location: 0, length: text.length))
            self.content = text
        }
        textDidChange()
    }

    private func textDidChange() {
        invalidateIntrinsicContentSize()
        setNeedsDisplay()
    }

    open var lineBreakMode = NSLineBreakMode.byTruncatingTail {
        didSet { textDidChange() }
    }

    /// At most this many lines show, the last one truncated; 0 for as many as fit.
    open var numberOfLines = 1 {
        didSet { textDidChange() }
    }

    open var shadowColor: UIColor? {
        didSet { setNeedsDisplay() }
    }

    open var shadowOffset = CGSize(width: 0, height: -1) {
        didSet { setNeedsDisplay() }
    }

    open var highlightedTextColor: UIColor? {
        didSet { setNeedsDisplay() }
    }

    open var isHighlighted = false {
        didSet { setNeedsDisplay() }
    }

    /// A disabled label draws its text grayed out.
    open var isEnabled = true {
        didSet { setNeedsDisplay() }
    }

    /// Shrinks single and multiple lines that don't fit, down to `minimumScaleFactor` of the
    /// size; 0 there keeps the size.
    open var adjustsFontSizeToFitWidth = false {
        didSet { setNeedsDisplay() }
    }

    open var minimumScaleFactor: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    // ponytail: shrunk text keeps its baseline centered whatever the adjustment.
    open var baselineAdjustment = UIBaselineAdjustment.alignBaselines

    open var allowsDefaultTighteningForTruncation = false

    // ponytail: text has the default Dynamic Type size, so there is nothing to adjust yet.
    open var adjustsFontForContentSizeCategory = false

    /// The width lines wrap at for `intrinsicContentSize`; 0 for none.
    open var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// The text with the label's attributes where it has none, as the render core takes it.
    private var styledText: IrisText? {
        guard let content, content.length > 0 else { return nil }
        return IrisText(content, font: font, color: textColor, alignment: textAlignment)
    }

    // MARK: Size

    /// The text's size in `bounds`, at its origin: `numberOfLines` lines wrapped to the width
    /// (0 for any number), or one line as wide as it is.
    open func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        guard let text = styledText else { return CGRect(origin: bounds.origin, size: .zero) }
        let metrics = text.measure(maxWidth: numberOfLines == 1 ? .infinity : bounds.width, maxLines: numberOfLines)
        return CGRect(
            x: bounds.minX, y: bounds.minY,
            width: min(CGFloat(metrics.width), bounds.width), height: min(CGFloat(metrics.height), bounds.height)
        )
    }

    /// The text's size, wrapped at `preferredMaxLayoutWidth` if set.
    open override var intrinsicContentSize: CGSize {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : .greatestFiniteMagnitude
        return textSize(width: width)
    }

    /// The text's size, wrapped at the width when it may take more than one line.
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        textSize(width: numberOfLines != 1 && size.width > 0 ? size.width : .greatestFiniteMagnitude)
    }

    /// Without a preferred width, a label of more than one line wraps at the width Auto
    /// Layout gives it, as UIKit's labels do.
    override var irisWrapsAtLayoutWidth: Bool {
        numberOfLines != 1 && preferredMaxLayoutWidth == 0
    }

    override func irisContentSize(wrappingAt width: CGFloat?) -> CGSize {
        guard let width, width > 0, irisWrapsAtLayoutWidth else { return intrinsicContentSize }
        return textSize(width: width)
    }

    /// The text is centered vertically, as `drawText(in:)` draws it.
    override var irisBaselineOffsets: (first: CGFloat, last: CGFloat)? {
        guard let text = styledText else { return (font.irisCenteredBaseline, font.irisCenteredBaseline) }
        let metrics = text.measure(maxWidth: numberOfLines == 1 || bounds.width == 0 ? .infinity : bounds.width, maxLines: numberOfLines)
        let middle = CGFloat(metrics.height) / 2
        return (CGFloat(metrics.firstBaseline) - middle, CGFloat(metrics.lastBaseline) - middle)
    }

    private func textSize(width: CGFloat) -> CGSize {
        let size = textRect(forBounds: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude), limitedToNumberOfLines: numberOfLines).size
        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }

    // MARK: Drawing

    open override func draw(_ rect: CGRect) {
        drawText(in: rect)
    }

    /// Draws the text centered vertically in `rect`, as many lines as fit. Subclasses inset
    /// the text by drawing it in a smaller rectangle.
    open func drawText(in rect: CGRect) {
        guard let (text, metrics) = fittedText(in: rect.size) else {
            layer.irisDrawing = nil
            return
        }
        let height = CGFloat(metrics.height)
        layer.irisDrawing = IrisDrawing(
            content: .text(text),
            frame: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height),
            shadow: shadowColor.map { ($0.cgColor, shadowOffset) }
        )
    }

    /// The text as it shows in `size`: in the color of the label's state, in the lines that
    /// fit, shrunk if it may be.
    func fittedText(in size: CGSize) -> (IrisText, TextMetrics)? {
        guard var text = styledText else { return nil }
        // ponytail: disabled text is system gray, not checked against UIKit's dimming.
        if !isEnabled {
            text = text.colored(.systemGray)
        } else if isHighlighted, let highlightedTextColor {
            text = text.colored(highlightedTextColor)
        }
        var lines = numberOfLines
        var metrics = text.measure(maxWidth: size.width, maxLines: lines)
        if metrics.lineCount > 1, CGFloat(metrics.height) > size.height + 0.5 {
            // Only whole lines that fit in the height show.
            lines = max(1, Int(size.height / (CGFloat(metrics.height) / CGFloat(metrics.lineCount))))
            metrics = text.measure(maxWidth: size.width, maxLines: lines)
        }
        if adjustsFontSizeToFitWidth, minimumScaleFactor > 0, minimumScaleFactor < 1, metrics.isTruncated {
            // The largest scale that fits, by bisection.
            var (fits, fails) = (minimumScaleFactor, CGFloat(1))
            for _ in 0 ..< 8 {
                let scale = (fits + fails) / 2
                if text.scaled(by: scale).measure(maxWidth: size.width, maxLines: lines).isTruncated {
                    fails = scale
                } else {
                    fits = scale
                }
            }
            text = text.scaled(by: fits)
            metrics = text.measure(maxWidth: size.width, maxLines: lines)
        }
        text.paragraph.maxLines = UInt32(lines)
        return (text, metrics)
    }

    /// The text, as VoiceOver reads a label.
    open override var accessibilityLabel: String? {
        get { super.accessibilityLabel ?? text }
        set { super.accessibilityLabel = newValue }
    }
}

public enum UIBaselineAdjustment: Int, Sendable {
    case alignBaselines = 0, alignCenters, none
}
