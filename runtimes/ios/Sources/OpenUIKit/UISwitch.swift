import Foundation

/// A control that turns an option on and off: 51 × 31 points, flipped by a tap or by dragging
/// its knob across, and sending `valueChanged` when the user changes it.
// ponytail: no styles (checkbox), on and off images, or Mac titles.
@preconcurrency @MainActor
open class UISwitch: UIControl {
    static let size = CGSize(width: 51, height: 31)
    private let knob = CALayer()

    /// The frame keeps the switch's own size.
    public override init(frame: CGRect) {
        super.init(frame: CGRect(origin: frame.origin, size: UISwitch.size))
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        layer.cornerRadius = UISwitch.size.height / 2
        knob.backgroundColor = UIColor.white.cgColor
        knob.cornerRadius = 13.5
        knob.shadowOpacity = 0.2
        knob.shadowOffset = CGSize(width: 0, height: 2)
        knob.shadowRadius = 3
        layer.addSublayer(knob)
        update(animated: false)
    }

    open override var frame: CGRect {
        get { super.frame }
        set { super.frame = CGRect(origin: newValue.origin, size: UISwitch.size) }
    }

    open override var intrinsicContentSize: CGSize {
        UISwitch.size
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        UISwitch.size
    }

    // MARK: Value

    open var isOn = false {
        didSet {
            _irisDidChangeValue(self, \UISwitch.isOn, from: oldValue)
            update(animated: false)
        }
    }

    open func setOn(_ on: Bool, animated: Bool) {
        isOn = on
        update(animated: animated)
    }

    /// The track when on; by default system green.
    open var onTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var thumbTintColor: UIColor? {
        didSet { update(animated: false) }
    }

    open var onImage: UIImage?
    open var offImage: UIImage?

    // MARK: Tracking

    private var startedOn = false
    private var startX: CGFloat = 0
    private var isPressed = false
    /// Where a drag has put the knob, until the finger lifts.
    private var draggedOn: Bool?

    open override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        startedOn = isOn
        startX = touch.location(in: self).x
        isPressed = true
        update(animated: true)
        return true
    }

    /// Past a few points, the knob follows the finger to the half of the track it is over.
    open override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let x = touch.location(in: self).x
        guard draggedOn != nil || abs(x - startX) > 4 else { return true }
        let on = x > bounds.midX
        if on != draggedOn {
            draggedOn = on
            update(animated: true)
        }
        return true
    }

    /// A tap flips the switch; a drag leaves it where the knob is.
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let on = draggedOn ?? (isTouchInside ? !startedOn : startedOn)
        isPressed = false
        draggedOn = nil
        if on != isOn {
            setOn(on, animated: true)
            sendActions(for: [.valueChanged, .primaryActionTriggered])
        } else {
            update(animated: true)
        }
    }

    open override func cancelTracking(with event: UIEvent?) {
        isPressed = false
        draggedOn = nil
        update(animated: true)
    }

    /// The track's color and the knob's place; a pressed knob stretches toward the middle.
    private func update(animated: Bool) {
        let on = draggedOn ?? isOn
        if animated {
            layer.irisAnimationDuration = 0.25
            knob.irisAnimationDuration = 0.25
        }
        layer.backgroundColor = (on ? onTintColor ?? .systemGreen : .secondarySystemFill).cgColor
        knob.backgroundColor = (thumbTintColor ?? .white).cgColor
        let width: CGFloat = isPressed ? 34 : 27
        knob.frame = CGRect(x: on ? UISwitch.size.width - 2 - width : 2, y: 2, width: width, height: 27)
    }
}
