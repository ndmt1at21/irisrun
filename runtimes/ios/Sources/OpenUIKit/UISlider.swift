import Foundation

/// A control that picks a value in a range by dragging its thumb along a 4-point track, the
/// part before the thumb in the tint. It sends `valueChanged` while dragged, or when the drag
/// ends if it is not continuous.
// ponytail: no value images or track images; a thumb image replaces the round thumb.
@preconcurrency @MainActor
open class UISlider: UIControl {
    private let maximumTrack = CALayer()
    private let minimumTrack = CALayer()
    private let thumb = CALayer()
    static let thumbSize: CGFloat = 28

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        for track in [maximumTrack, minimumTrack] {
            track.cornerRadius = 2
            layer.addSublayer(track)
        }
        thumb.shadowOpacity = 0.2
        thumb.shadowOffset = CGSize(width: 0, height: 2)
        thumb.shadowRadius = 3
        layer.addSublayer(thumb)
        update(animated: false)
    }

    open override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 31)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: max(size.width, UISlider.thumbSize), height: 31)
    }

    // MARK: Value

    private var storedValue: Float = 0

    /// Kept between the minimum and maximum.
    open var value: Float {
        get { storedValue }
        set { setValue(newValue, animated: false) }
    }

    open func setValue(_ value: Float, animated: Bool) {
        let oldValue = storedValue
        storedValue = min(max(value, minimumValue), max(maximumValue, minimumValue))
        _irisDidChangeValue(self, \UISlider.value, from: oldValue)
        update(animated: animated)
    }

    open var minimumValue: Float = 0 {
        didSet { setValue(storedValue, animated: false) }
    }

    open var maximumValue: Float = 1 {
        didSet { setValue(storedValue, animated: false) }
    }

    open var isContinuous = true

    open var minimumTrackTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var maximumTrackTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var thumbTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var minimumValueImage: UIImage?
    open var maximumValueImage: UIImage?

    private var thumbImages: [UIControl.State: UIImage] = [:]

    open func setThumbImage(_ image: UIImage?, for state: UIControl.State) {
        thumbImages[state] = image
        update(animated: false)
    }

    open func thumbImage(for state: UIControl.State) -> UIImage? {
        thumbImages[state] ?? thumbImages[.normal]
    }

    open var currentThumbImage: UIImage? {
        thumbImage(for: state)
    }

    open override func tintColorDidChange() {
        update(animated: false)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        update(animated: false)
    }

    // MARK: Geometry

    /// The whole width, 4 points high in the middle.
    open func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX, y: bounds.midY - 2, width: bounds.width, height: 4)
    }

    /// The thumb sits inside the track's ends, at the value's fraction of the room between.
    open func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let size = currentThumbImage?.size ?? CGSize(width: UISlider.thumbSize, height: UISlider.thumbSize)
        let range = maximumValue - minimumValue
        let fraction = range > 0 ? CGFloat((value - minimumValue) / range) : 0
        return CGRect(x: rect.minX + (rect.width - size.width) * fraction, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func update(animated: Bool) {
        let track = trackRect(forBounds: bounds)
        let thumbFrame = thumbRect(forBounds: bounds, trackRect: track, value: value)
        if animated {
            minimumTrack.irisAnimation = IrisAnimationTiming(duration: 0.25)
            thumb.irisAnimation = IrisAnimationTiming(duration: 0.25)
        }
        maximumTrack.frame = track
        maximumTrack.backgroundColor = (maximumTrackTintColor ?? .systemFill).cgColor
        minimumTrack.frame = CGRect(x: track.minX, y: track.minY, width: thumbFrame.midX - track.minX, height: track.height)
        minimumTrack.backgroundColor = (minimumTrackTintColor ?? tintColor).cgColor
        thumb.frame = thumbFrame
        if let image = currentThumbImage {
            thumb.contents = image.cgImage
            thumb.contentsScale = image.scale
            thumb.backgroundColor = nil
            thumb.shadowOpacity = 0
        } else {
            thumb.contents = nil
            thumb.backgroundColor = (thumbTintColor ?? .white).cgColor
            thumb.cornerRadius = UISlider.thumbSize / 2
            thumb.shadowOpacity = 0.2
        }
    }

    // MARK: Tracking

    private var startValue: Float = 0
    private var startX: CGFloat = 0
    private var changedWhileTracking = false

    /// Only a touch on the thumb, give or take a few points, drags it.
    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let thumbFrame = thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
        let location = touch.location(in: self)
        guard thumbFrame.insetBy(dx: -10, dy: -10).contains(location) else { return false }
        startValue = value
        startX = location.x
        changedWhileTracking = false
        return true
    }

    /// The value moves as far as the finger, over the room the thumb has.
    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let track = trackRect(forBounds: bounds)
        let room = max(track.width - thumbRect(forBounds: bounds, trackRect: track, value: value).width, 1)
        let delta = Float((touch.location(in: self).x - startX) / room) * (maximumValue - minimumValue)
        let oldValue = value
        value = startValue + delta
        if value != oldValue {
            changedWhileTracking = true
            if isContinuous {
                sendActions(for: [.valueChanged, .primaryActionTriggered])
            }
        }
        return true
    }

    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if !isContinuous, changedWhileTracking {
            sendActions(for: [.valueChanged, .primaryActionTriggered])
        }
    }
}
