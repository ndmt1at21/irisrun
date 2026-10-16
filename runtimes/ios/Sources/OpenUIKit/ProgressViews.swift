import Foundation
import IrisRender

/// A spinner for work of unknown length: eight bars around a circle, fading in turn, 20 points
/// across in the medium style and 37 in the large one. It is hidden while stopped, by default.
@preconcurrency @MainActor
open class UIActivityIndicatorView: UIView {
    private var bars: [CALayer] = []

    public init(style: UIActivityIndicatorView.Style) {
        self.style = style
        super.init(frame: CGRect(origin: .zero, size: style.size))
        setUp()
    }

    public override init(frame: CGRect) {
        style = .medium
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        style = .medium
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        isUserInteractionEnabled = false
        for index in 0 ..< 8 {
            let bar = CALayer()
            // The bars behind the brightest one, going round clockwise, are dimmer: the moment
            // of the animation in which the top bar lights.
            bar.opacity = index == 0 ? 1 : 0.25 + 0.75 * Float(index) / 8
            layer.addSublayer(bar)
            bars.append(bar)
        }
        isHidden = hidesWhenStopped
        updateBars()
    }

    open var style: UIActivityIndicatorView.Style {
        didSet { updateBars() }
    }

    private var ownColor: UIColor?

    /// Gray, or white in the old white styles.
    open var color: UIColor! {
        get { ownColor ?? style.defaultColor }
        set {
            ownColor = newValue
            updateBars()
        }
    }

    open var hidesWhenStopped = true {
        didSet { isHidden = hidesWhenStopped && !isAnimating }
    }

    open private(set) var isAnimating = false

    /// Each bar fades from full to a quarter over a second, an eighth of a second after the
    /// one before it, on the render core's clock.
    open func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        isHidden = false
        for (index, bar) in bars.enumerated() {
            bar.irisAnimations = [Animation(
                from: .opacity(1), to: .opacity(0.25), duration: 1, delay: Double(index) / 8,
                timing: .linear, repeatCount: .infinity
            )]
        }
    }

    open func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        for bar in bars {
            bar.irisStopsAnimations = true
        }
        if hidesWhenStopped {
            isHidden = true
        }
    }

    open override var intrinsicContentSize: CGSize {
        style.size
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        style.size
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        updateBars()
    }

    /// Bars as SwiftUI's spinner in patch 0019 draws them, 3 × 6 points 6 out from the center
    /// at the medium size.
    private func updateBars() {
        let scale = style.size.width / 20
        let barColor = color.cgColor
        for (index, bar) in bars.enumerated() {
            let angle = CGFloat(index) * .pi / 4
            bar.bounds = CGRect(x: 0, y: 0, width: 3 * scale, height: 6 * scale)
            bar.cornerRadius = 1.5 * scale
            bar.position = CGPoint(x: bounds.midX + sin(angle) * 6 * scale, y: bounds.midY - cos(angle) * 6 * scale)
            bar.setAffineTransform(CGAffineTransform(rotationAngle: angle))
            bar.backgroundColor = barColor
        }
    }
}

extension UIActivityIndicatorView {
    public enum Style: Int, Sendable {
        case whiteLarge = 0, white = 1, gray = 2
        case medium = 100, large = 101

        var size: CGSize {
            self == .large || self == .whiteLarge ? CGSize(width: 37, height: 37) : CGSize(width: 20, height: 20)
        }

        var defaultColor: UIColor {
            self == .white || self == .whiteLarge ? .white : .systemGray
        }
    }
}

/// A bar that fills with progress from 0 to 1, in the tint over a gray track: 4 points high
/// with round ends, or 2.5 and square in the bar style.
// ponytail: no progress or track images, and observedProgress isn't watched.
@preconcurrency @MainActor
open class UIProgressView: UIView {
    private let track = CALayer()
    private let fill = CALayer()

    public init(progressViewStyle style: UIProgressView.Style) {
        progressViewStyle = style
        super.init(frame: .zero)
        setUp()
    }

    public override init(frame: CGRect) {
        progressViewStyle = .default
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        progressViewStyle = .default
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        layer.addSublayer(track)
        track.addSublayer(fill)
        track.masksToBounds = true
        update(animated: false)
    }

    open var progressViewStyle: UIProgressView.Style {
        didSet { update(animated: false) }
    }

    private var storedProgress: Float = 0

    /// From 0 to 1.
    open var progress: Float {
        get { storedProgress }
        set { setProgress(newValue, animated: false) }
    }

    open func setProgress(_ progress: Float, animated: Bool) {
        let oldValue = storedProgress
        storedProgress = min(max(progress, 0), 1)
        _irisDidChangeValue(self, \UIProgressView.progress, from: oldValue)
        update(animated: animated)
    }

    open var progressTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var trackTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var progressImage: UIImage?
    open var trackImage: UIImage?

    private var barHeight: CGFloat {
        progressViewStyle == .bar ? 2.5 : 4
    }

    open override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: barHeight)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: barHeight)
    }

    open override func tintColorDidChange() {
        update(animated: false)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        update(animated: false)
    }

    private func update(animated: Bool) {
        track.frame = CGRect(x: 0, y: bounds.midY - barHeight / 2, width: bounds.width, height: barHeight)
        track.cornerRadius = progressViewStyle == .bar ? 0 : barHeight / 2
        track.backgroundColor = (trackTintColor ?? .systemFill).cgColor
        if animated {
            fill.irisAnimation = IrisAnimationTiming(duration: 0.25)
        }
        fill.frame = CGRect(x: 0, y: 0, width: bounds.width * CGFloat(progress), height: barHeight)
        fill.cornerRadius = track.cornerRadius
        fill.backgroundColor = (progressTintColor ?? tintColor).cgColor
    }
}

extension UIProgressView {
    public enum Style: Int, Sendable {
        case `default` = 0, bar
    }
}
