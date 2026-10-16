import Foundation

/// A row of segments, titles or images, one of them selected, in iOS 13's look: a gray track
/// with the selected segment on a white rounded plate. A tap on another segment selects it,
/// runs its action and sends `valueChanged`.
// ponytail: no sliding the selection along, highlight while pressed, or background and divider
// images.
@preconcurrency @MainActor
open class UISegmentedControl: UIControl {
    nonisolated public static let noSegment = -1

    private struct Segment {
        var title: String?
        var image: UIImage?
        var action: UIAction?
        var width: CGFloat = 0
        var contentOffset = CGSize.zero
        var isEnabled = true
        /// A label or image view that shows the segment.
        var view: UIView
    }

    private var segments: [Segment] = []
    private let plate = CALayer()
    private var dividers: [CALayer] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    /// Titles (strings) or images, sized to fit them.
    public init(items: [Any]?) {
        super.init(frame: .zero)
        setUp()
        for item in items ?? [] {
            if let image = item as? UIImage {
                insertSegment(with: image, at: numberOfSegments, animated: false)
            } else {
                insertSegment(withTitle: item as? String ?? "\(item)", at: numberOfSegments, animated: false)
            }
        }
        frame.size = intrinsicContentSize
    }

    /// A segment for each action, which runs when its segment is selected.
    public convenience init(frame: CGRect, actions: [UIAction]) {
        self.init(frame: frame)
        for action in actions {
            insertSegment(action: action, at: numberOfSegments, animated: false)
        }
    }

    private func setUp() {
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 9
        plate.cornerRadius = 7
        plate.shadowOpacity = 0.12
        plate.shadowOffset = CGSize(width: 0, height: 3)
        plate.shadowRadius = 4
        plate.borderWidth = 0.5
        plate.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor
        layer.insertSublayer(plate, at: 0)
    }

    // MARK: Segments

    open var numberOfSegments: Int {
        segments.count
    }

    open var isMomentary = false {
        didSet { setNeedsLayout() }
    }

    open var apportionsSegmentWidthsByContent = false {
        didSet { setNeedsLayout() }
    }

    open func insertSegment(withTitle title: String?, at segment: Int, animated: Bool) {
        insert(Segment(title: title, view: UILabel()), at: segment)
    }

    open func insertSegment(with image: UIImage?, at segment: Int, animated: Bool) {
        insert(Segment(image: image, view: UIImageView()), at: segment)
    }

    open func insertSegment(action: UIAction, at segment: Int, animated: Bool) {
        let view: UIView = action.title.isEmpty && action.image != nil ? UIImageView() : UILabel()
        insert(Segment(title: action.title, image: action.image, action: action, view: view), at: segment)
    }

    private func insert(_ segment: Segment, at index: Int) {
        let index = min(max(index, 0), segments.count)
        segments.insert(segment, at: index)
        addSubview(segment.view)
        if selectedSegmentIndex >= index {
            storedSelection += 1
        }
        segmentsDidChange()
    }

    open func removeSegment(at segment: Int, animated: Bool) {
        guard segments.indices.contains(segment) else { return }
        segments.remove(at: segment).view.removeFromSuperview()
        if selectedSegmentIndex == segment {
            storedSelection = UISegmentedControl.noSegment
        } else if selectedSegmentIndex > segment {
            storedSelection -= 1
        }
        segmentsDidChange()
    }

    open func removeAllSegments() {
        while !segments.isEmpty {
            removeSegment(at: segments.count - 1, animated: false)
        }
    }

    open func setTitle(_ title: String?, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        if !(segments[segment].view is UILabel) {
            segments[segment].view.removeFromSuperview()
            segments[segment].view = UILabel()
            addSubview(segments[segment].view)
        }
        segments[segment].title = title
        segmentsDidChange()
    }

    open func titleForSegment(at segment: Int) -> String? {
        segments.indices.contains(segment) ? segments[segment].title : nil
    }

    open func setImage(_ image: UIImage?, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        if !(segments[segment].view is UIImageView) {
            segments[segment].view.removeFromSuperview()
            segments[segment].view = UIImageView()
            addSubview(segments[segment].view)
        }
        segments[segment].image = image
        segmentsDidChange()
    }

    open func imageForSegment(at segment: Int) -> UIImage? {
        segments.indices.contains(segment) ? segments[segment].image : nil
    }

    open func setAction(_ action: UIAction, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        segments[segment].action = action
        setTitle(action.title, forSegmentAt: segment)
    }

    open func actionForSegment(at segment: Int) -> UIAction? {
        segments.indices.contains(segment) ? segments[segment].action : nil
    }

    open func segmentIndex(identifiedBy actionIdentifier: UIAction.Identifier) -> Int {
        segments.firstIndex { $0.action?.identifier == actionIdentifier } ?? UISegmentedControl.noSegment
    }

    /// 0 shares the room with the other segments.
    open func setWidth(_ width: CGFloat, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        segments[segment].width = width
        segmentsDidChange()
    }

    open func widthForSegment(at segment: Int) -> CGFloat {
        segments.indices.contains(segment) ? segments[segment].width : 0
    }

    open func setContentOffset(_ offset: CGSize, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        segments[segment].contentOffset = offset
        setNeedsLayout()
    }

    open func contentOffsetForSegment(at segment: Int) -> CGSize {
        segments.indices.contains(segment) ? segments[segment].contentOffset : .zero
    }

    open func setEnabled(_ enabled: Bool, forSegmentAt segment: Int) {
        guard segments.indices.contains(segment) else { return }
        segments[segment].isEnabled = enabled
        segmentsDidChange()
    }

    open func isEnabledForSegment(at segment: Int) -> Bool {
        segments.indices.contains(segment) ? segments[segment].isEnabled : false
    }

    // MARK: Selection

    private var storedSelection = UISegmentedControl.noSegment

    open var selectedSegmentIndex: Int {
        get { storedSelection }
        set {
            let oldValue = storedSelection
            storedSelection = segments.indices.contains(newValue) ? newValue : UISegmentedControl.noSegment
            _irisDidChangeValue(self, \UISegmentedControl.selectedSegmentIndex, from: oldValue)
            segmentsDidChange()
        }
    }

    /// The plate under the selected segment; by default white.
    open var selectedSegmentTintColor: UIColor? {
        didSet { segmentsDidChange() }
    }

    private var titleAttributes: [UInt: [NSAttributedString.Key: Any]] = [:]

    /// The font and color of titles in a state: normal, selected, highlighted or disabled.
    open func setTitleTextAttributes(_ attributes: [NSAttributedString.Key: Any]?, for state: UIControl.State) {
        titleAttributes[state.rawValue] = attributes
        segmentsDidChange()
    }

    open func titleTextAttributes(for state: UIControl.State) -> [NSAttributedString.Key: Any]? {
        titleAttributes[state.rawValue]
    }

    open override var isEnabled: Bool {
        didSet { segmentsDidChange() }
    }

    open override func tintColorDidChange() {
        segmentsDidChange()
    }

    /// Shows each segment in its state: 13-point titles, semibold when selected.
    private func segmentsDidChange() {
        for (index, segment) in segments.enumerated() {
            let selected = index == selectedSegmentIndex && !isMomentary
            let enabled = isEnabled && segment.isEnabled
            var attributes = titleAttributes[UIControl.State.normal.rawValue] ?? [:]
            if selected {
                attributes.merge(titleAttributes[UIControl.State.selected.rawValue] ?? [:]) { $1 }
            }
            if !enabled {
                attributes.merge(titleAttributes[UIControl.State.disabled.rawValue] ?? [:]) { $1 }
            }
            let color = enabled ? attributes[.foregroundColor] as? UIColor ?? .label : .tertiaryLabel
            if let label = segment.view as? UILabel {
                label.font = attributes[.font] as? UIFont ?? .systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
                label.textColor = color
                label.text = segment.title
            } else if let imageView = segment.view as? UIImageView {
                imageView.image = segment.image
                imageView.tintColor = color
            }
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Layout

    private static let padding: CGFloat = 12

    private func contentWidth(_ segment: Segment) -> CGFloat {
        segment.view.sizeThatFits(.zero).width + 2 * UISegmentedControl.padding
    }

    /// Fixed widths first; the rest of the width shared evenly, or by content.
    private func segmentWidths(in width: CGFloat) -> [CGFloat] {
        let fixed = segments.reduce(0) { $0 + $1.width }
        let shared = segments.filter { $0.width == 0 }
        let room = max(width - fixed, 0)
        let content = shared.reduce(0) { $0 + contentWidth($1) }
        return segments.map { segment in
            if segment.width > 0 { return segment.width }
            if apportionsSegmentWidthsByContent, content > 0 { return room * contentWidth(segment) / content }
            return room / CGFloat(shared.count)
        }
    }

    open override var intrinsicContentSize: CGSize {
        let widest = segments.filter { $0.width == 0 }.map(contentWidth).max() ?? 0
        let width = segments.reduce(0) { total, segment in
            total + (segment.width > 0 ? segment.width : apportionsSegmentWidthsByContent ? contentWidth(segment) : widest)
        }
        return CGSize(width: ceil(width), height: 32)
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    private func segmentFrames() -> [CGRect] {
        var x = bounds.minX
        return segmentWidths(in: bounds.width).map { width in
            defer { x += width }
            return CGRect(x: x, y: bounds.minY, width: width, height: bounds.height)
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        let frames = segmentFrames()
        for (segment, frame) in zip(segments, frames) {
            let size = segment.view.sizeThatFits(.zero)
            let fitted = CGSize(width: min(size.width, frame.width - 8), height: min(size.height, frame.height))
            segment.view.frame = CGRect(
                x: frame.midX - fitted.width / 2 + segment.contentOffset.width,
                y: frame.midY - fitted.height / 2 + segment.contentOffset.height,
                width: fitted.width, height: fitted.height
            )
        }
        let selected = frames.indices.contains(selectedSegmentIndex) && !isMomentary ? selectedSegmentIndex : nil
        plate.isHidden = selected == nil
        if let selected {
            plate.frame = frames[selected].insetBy(dx: 2, dy: 2)
            plate.backgroundColor = (selectedSegmentTintColor ?? .white).cgColor
        }
        // A divider between segments, but not beside the plate.
        while dividers.count < max(frames.count - 1, 0) {
            let divider = CALayer()
            divider.backgroundColor = UIColor.separator.cgColor
            layer.insertSublayer(divider, above: plate)
            dividers.append(divider)
        }
        for (index, divider) in dividers.enumerated() {
            let shown = index + 1 < frames.count && selected != index && selected != index + 1
            divider.isHidden = !shown
            if shown {
                divider.frame = CGRect(x: frames[index].maxX - 0.5, y: bounds.midY - 8, width: 1, height: 16)
            }
        }
    }

    // MARK: Tracking

    private func segment(at point: CGPoint) -> Int? {
        segmentFrames().firstIndex { $0.minX <= point.x && point.x < $0.maxX }
    }

    /// A touch that lifts on an enabled segment selects it.
    open override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard isTouchInside, let touch, let index = segment(at: touch.location(in: self)), segments[index].isEnabled,
              index != selectedSegmentIndex || isMomentary else { return }
        selectedSegmentIndex = index
        if let action = segments[index].action {
            sendAction(action)
        }
        sendActions(for: [.valueChanged, .primaryActionTriggered])
    }
}
