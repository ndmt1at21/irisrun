import Foundation

/// A control that sends its primary action when tapped. A button shows either the content of
/// its `configuration` (iOS 15), or a title, image and background image per control state laid
/// out side by side with edge insets, as buttons did before. System buttons draw in the tint
/// and fade while touched.
// ponytail: no menus, pointer styles or symbol configurations; custom buttons don't darken
// their images while highlighted.
@preconcurrency @MainActor
open class UIButton: UIControl {
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public convenience init(type buttonType: UIButton.ButtonType) {
        self.init(frame: .zero)
        self.buttonType = buttonType
        switch buttonType {
        case .detailDisclosure, .infoLight, .infoDark: setImage(UIImage(systemName: "info.circle"), for: .normal)
        case .contactAdd: setImage(UIImage(systemName: "plus.circle"), for: .normal)
        case .close:
            setImage(UIImage(systemName: "xmark"), for: .normal)
            imageView?.tintColor = .secondaryLabel
            imageView?.backgroundColor = .tertiarySystemFill
        default: contentDidChange()
        }
        if currentImage != nil {
            frame.size = intrinsicContentSize
        }
    }

    /// Takes its title and image from the action, which it sends as its primary action.
    public convenience init(type buttonType: UIButton.ButtonType = .system, primaryAction: UIAction?) {
        self.init(type: buttonType)
        if let primaryAction {
            setTitle(primaryAction.title, for: .normal)
            setImage(primaryAction.image, for: .normal)
            addAction(primaryAction, for: .primaryActionTriggered)
        }
    }

    public convenience init(configuration: UIButton.Configuration, primaryAction: UIAction? = nil) {
        self.init(type: .system)
        // An initializer doesn't run the property's observer.
        self.configuration = configuration
        applyConfiguration()
        if let primaryAction {
            addAction(primaryAction, for: .primaryActionTriggered)
        }
    }

    open private(set) var buttonType = ButtonType.custom

    open var role = Role.normal {
        didSet { contentDidChange() }
    }

    // MARK: State

    override open var isHighlighted: Bool {
        didSet { contentDidChange() }
    }

    override open var isSelected: Bool {
        didSet { contentDidChange() }
    }

    override open var isEnabled: Bool {
        didSet { contentDidChange() }
    }

    open override func tintColorDidChange() {
        contentDidChange()
    }

    /// A tap toggles `isSelected` before the actions go out.
    open var changesSelectionAsPrimaryAction = false

    override func touchUpInsideEvents() -> Event {
        if changesSelectionAsPrimaryAction {
            isSelected.toggle()
        }
        return [.touchUpInside, .primaryActionTriggered]
    }

    private func contentDidChange() {
        if configuration != nil {
            setNeedsUpdateConfiguration()
        } else {
            updateContent()
        }
    }

    // MARK: Content per state

    private struct Content {
        var title: String?
        var attributedTitle: NSAttributedString?
        var titleColor: UIColor?
        var titleShadowColor: UIColor?
        var image: UIImage?
        var backgroundImage: UIImage?
    }

    private var contents: [UIControl.State: Content] = [:]

    /// What is set for a state, or else for the normal state, as UIKit falls back.
    private func content<Value>(_ part: KeyPath<Content, Value?>, for state: UIControl.State) -> Value? {
        contents[state]?[keyPath: part] ?? contents[.normal]?[keyPath: part]
    }

    private func set<Value>(_ part: WritableKeyPath<Content, Value?>, _ value: Value?, for state: UIControl.State) {
        contents[state, default: Content()][keyPath: part] = value
        contentDidChange()
        invalidateIntrinsicContentSize()
    }

    /// With a configuration, the normal title is the configuration's.
    open func setTitle(_ title: String?, for state: UIControl.State) {
        if state == .normal, configuration != nil {
            configuration?.title = title
        }
        set(\.title, title, for: state)
    }

    open func setAttributedTitle(_ title: NSAttributedString?, for state: UIControl.State) {
        set(\.attributedTitle, title, for: state)
    }

    open func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        set(\.titleColor, color, for: state)
    }

    open func setTitleShadowColor(_ color: UIColor?, for state: UIControl.State) {
        set(\.titleShadowColor, color, for: state)
    }

    open func setImage(_ image: UIImage?, for state: UIControl.State) {
        set(\.image, image, for: state)
    }

    open func setBackgroundImage(_ image: UIImage?, for state: UIControl.State) {
        set(\.backgroundImage, image, for: state)
    }

    open func title(for state: UIControl.State) -> String? {
        content(\.title, for: state)
    }

    open func attributedTitle(for state: UIControl.State) -> NSAttributedString? {
        content(\.attributedTitle, for: state)
    }

    open func titleColor(for state: UIControl.State) -> UIColor? {
        content(\.titleColor, for: state)
    }

    open func titleShadowColor(for state: UIControl.State) -> UIColor? {
        content(\.titleShadowColor, for: state)
    }

    open func image(for state: UIControl.State) -> UIImage? {
        content(\.image, for: state)
    }

    open func backgroundImage(for state: UIControl.State) -> UIImage? {
        content(\.backgroundImage, for: state)
    }

    open var currentTitle: String? {
        title(for: state) ?? attributedTitle(for: state)?.string
    }

    open var currentAttributedTitle: NSAttributedString? {
        attributedTitle(for: state)
    }

    /// The color set for the state, or the type's: the tint for system buttons, gray when
    /// disabled, and white for custom ones.
    open var currentTitleColor: UIColor {
        if let color = titleColor(for: state) { return color }
        guard buttonType != .custom else { return .white }
        return isEnabled ? (role == .destructive ? .systemRed : tintColor) : .tertiaryLabel
    }

    open var currentTitleShadowColor: UIColor? {
        titleShadowColor(for: state)
    }

    open var currentImage: UIImage? {
        image(for: state)
    }

    open var currentBackgroundImage: UIImage? {
        backgroundImage(for: state)
    }

    // MARK: Parts

    private var label: UILabel?
    private var image: UIImageView?
    private var backgroundImageView: UIImageView?

    /// Made when first asked for, in UIKit's style: 15 points, cut in the middle.
    open var titleLabel: UILabel? {
        if let label { return label }
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        label.lineBreakMode = .byTruncatingMiddle
        self.label = label
        addSubview(label)
        return label
    }

    open var imageView: UIImageView? {
        if let image { return image }
        let image = UIImageView()
        image.contentMode = .center
        self.image = image
        // Above the backgrounds.
        insertSubview(image, at: [backgroundImageView, background].compactMap { $0 }.count)
        return image
    }

    // MARK: Insets (deprecated in iOS 15, still common)

    open var contentEdgeInsets = UIEdgeInsets.zero {
        didSet { setNeedsLayout(); invalidateIntrinsicContentSize() }
    }

    /// Moves the title: by half the difference of left and right when centered.
    open var titleEdgeInsets = UIEdgeInsets.zero {
        didSet { setNeedsLayout() }
    }

    open var imageEdgeInsets = UIEdgeInsets.zero {
        didSet { setNeedsLayout() }
    }

    open var adjustsImageWhenHighlighted = true
    open var adjustsImageWhenDisabled = true
    open var showsTouchWhenHighlighted = false
    open var reversesTitleShadowWhenHighlighted = false

    /// Shows the state's title, image and background image in the type's colors.
    private func updateContent() {
        if let title = attributedTitle(for: state) {
            titleLabel?.attributedText = title
        } else if let title = title(for: state) {
            titleLabel?.text = title
        } else {
            label?.text = nil
        }
        label?.textColor = currentTitleColor
        label?.shadowColor = currentTitleShadowColor
        // System buttons draw images in the tint unless they are always original.
        let image = currentImage.map { buttonType != .custom && $0.renderingMode == .automatic ? $0.withRenderingMode(.alwaysTemplate) : $0 }
        if image != nil || self.image != nil {
            imageView?.image = image
            if buttonType != .close {
                self.image?.tintColor = currentTitleColor
            }
        }
        if let background = currentBackgroundImage, backgroundImageView == nil {
            let view = UIImageView()
            backgroundImageView = view
            insertSubview(view, at: 0)
            view.image = background
        } else {
            backgroundImageView?.image = currentBackgroundImage
        }
        // System buttons fade while touched.
        let alpha: CGFloat = buttonType != .custom && isHighlighted ? 0.2 : 1
        label?.alpha = alpha
        self.image?.alpha = alpha
        setNeedsLayout()
    }

    // MARK: Layout

    open func backgroundRect(forBounds bounds: CGRect) -> CGRect {
        bounds
    }

    open func contentRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: contentEdgeInsets)
    }

    open func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        legacyLayout(in: contentRect).title
    }

    open func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        legacyLayout(in: contentRect).image
    }

    private var hasTitle: Bool {
        !(currentTitle ?? "").isEmpty
    }

    /// The image then the title, side by side, placed as a pair by the content alignment, then
    /// each moved by its edge insets as UIKit moves them.
    private func legacyLayout(in content: CGRect) -> (image: CGRect, title: CGRect) {
        var imageSize = currentImage?.size ?? .zero
        imageSize = CGSize(width: min(imageSize.width, max(content.width, 0)), height: min(imageSize.height, max(content.height, 0)))
        var titleSize = hasTitle ? label?.intrinsicContentSize ?? .zero : .zero
        let room = content.width - imageSize.width - titleEdgeInsets.left - titleEdgeInsets.right
        titleSize = CGSize(width: max(min(titleSize.width, room), 0), height: titleSize.height)
        let width = imageSize.width + titleSize.width
        let horizontal = effectiveContentHorizontalAlignment
        let x: CGFloat = switch horizontal {
        case .left, .fill: content.minX
        case .right: content.maxX - width
        default: content.midX - width / 2
        }
        func y(_ height: CGFloat) -> CGFloat {
            switch contentVerticalAlignment {
            case .top, .fill: content.minY
            case .bottom: content.maxY - height
            case .center: content.midY - height / 2
            }
        }
        func shift(_ rect: CGRect, by insets: UIEdgeInsets) -> CGRect {
            let dx: CGFloat = switch horizontal {
            case .left: insets.left
            case .right: -insets.right
            default: (insets.left - insets.right) / 2
            }
            let dy: CGFloat = switch contentVerticalAlignment {
            case .top: insets.top
            case .bottom: -insets.bottom
            default: (insets.top - insets.bottom) / 2
            }
            return rect.offsetBy(dx: dx, dy: dy)
        }
        return (
            shift(CGRect(x: x, y: y(imageSize.height), width: imageSize.width, height: imageSize.height), by: imageEdgeInsets),
            shift(CGRect(x: x + imageSize.width, y: y(titleSize.height), width: titleSize.width, height: titleSize.height), by: titleEdgeInsets)
        )
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        if needsConfigurationUpdate {
            needsConfigurationUpdate = false
            updateConfiguration()
        }
        if let configuration {
            layoutConfiguration(configuration)
            return
        }
        backgroundImageView?.frame = backgroundRect(forBounds: bounds)
        let content = contentRect(forBounds: bounds)
        if buttonType == .close {
            // The mark in a gray circle.
            image?.frame = CGRect(x: content.midX - 15, y: content.midY - 15, width: 30, height: 30)
            image?.layer.cornerRadius = 15
        } else {
            image?.frame = imageRect(forContentRect: content)
        }
        label?.frame = titleRect(forContentRect: content)
    }

    /// The content and its insets; a title gets 6 points above and below without insets.
    /// The title's, centered vertically.
    override var irisBaselineOffsets: (first: CGFloat, last: CGFloat)? {
        guard let font = titleLabel?.font else { return nil }
        return (font.irisCenteredBaseline, font.irisCenteredBaseline)
    }

    open override var intrinsicContentSize: CGSize {
        if let configuration {
            return configurationLayout(configuration, in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).size
        }
        let image = buttonType == .close ? CGSize(width: 30, height: 30) : currentImage?.size ?? .zero
        let title = hasTitle ? titleLabel?.intrinsicContentSize ?? .zero : .zero
        var size = CGSize(width: image.width + title.width, height: max(image.height, title.height))
        if hasTitle, contentEdgeInsets == .zero {
            size.height = max(size.height, title.height + 12)
        }
        if let background = currentBackgroundImage?.size {
            size = CGSize(width: max(size.width, background.width), height: max(size.height, background.height))
        }
        return CGSize(
            width: ceil(size.width + contentEdgeInsets.left + contentEdgeInsets.right),
            height: ceil(size.height + contentEdgeInsets.top + contentEdgeInsets.bottom)
        )
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        intrinsicContentSize
    }

    /// The title, as VoiceOver reads a button.
    open override var accessibilityLabel: String? {
        get { super.accessibilityLabel ?? configuration?.title ?? currentTitle }
        set { super.accessibilityLabel = newValue }
    }

    // MARK: Configuration

    /// What the button shows, in place of the content per state; nil for that content.
    open var configuration: UIButton.Configuration? {
        didSet {
            applyConfiguration()
            invalidateIntrinsicContentSize()
        }
    }

    public typealias ConfigurationUpdateHandler = (UIButton) -> Void

    /// Called when the state changes, to update `configuration` for it.
    open var configurationUpdateHandler: UIButton.ConfigurationUpdateHandler? {
        didSet { setNeedsUpdateConfiguration() }
    }

    open var automaticallyUpdatesConfiguration = true

    private var needsConfigurationUpdate = false
    private var isUpdatingConfiguration = false

    /// Has `updateConfiguration()` run before the next layout.
    open func setNeedsUpdateConfiguration() {
        needsConfigurationUpdate = true
        setNeedsLayout()
    }

    /// Runs the update handler, or updates the configuration for the state.
    open func updateConfiguration() {
        guard !isUpdatingConfiguration else { return }
        isUpdatingConfiguration = true
        defer { isUpdatingConfiguration = false }
        if let configurationUpdateHandler {
            configurationUpdateHandler(self)
        } else if automaticallyUpdatesConfiguration, let configuration {
            self.configuration = configuration.updated(for: self)
        }
        applyConfiguration()
    }

    private var subtitle: UILabel?
    private var indicator: UIActivityIndicatorView?
    private var background: UIView?

    open var subtitleLabel: UILabel? {
        guard configuration != nil else { return nil }
        if let subtitle { return subtitle }
        let label = UILabel()
        subtitle = label
        addSubview(label)
        return label
    }

    /// Shows the configuration in the button's state.
    private func applyConfiguration() {
        guard let configuration else {
            background?.removeFromSuperview()
            background = nil
            updateContent()
            return
        }
        let (foreground, fill) = configuration.colors(tint: role == .destructive ? .systemRed : tintColor, state: state)
        if background == nil {
            let view = UIView()
            view.isUserInteractionEnabled = false
            background = view
            insertSubview(view, at: 0)
        }
        background?.backgroundColor = configuration.background.backgroundColorTransformer.map { $0(fill ?? .clear) } ?? fill
        background?.layer.borderWidth = configuration.background.strokeWidth
        background?.layer.borderColor = configuration.background.strokeColor?.cgColor

        // The fonts first: a font set after attributed text would apply to all of it.
        let (titleFont, subtitleFont) = configuration.buttonSize.fonts
        titleLabel?.font = titleFont
        titleLabel?.attributedText = configuration.text(configuration.title, configuration.attributedTitle, font: titleFont, color: foreground, transformer: configuration.titleTextAttributesTransformer)
        titleLabel?.numberOfLines = configuration.titleLineBreakMode == .byWordWrapping ? 0 : 1
        titleLabel?.alpha = 1
        let subtitleText = configuration.text(configuration.subtitle, configuration.attributedSubtitle, font: subtitleFont, color: foreground, transformer: configuration.subtitleTextAttributesTransformer)
        if subtitleText != nil || subtitle != nil {
            subtitleLabel?.font = subtitleFont
            subtitleLabel?.attributedText = subtitleText
            subtitleLabel?.numberOfLines = configuration.subtitleLineBreakMode == .byWordWrapping ? 0 : 1
        }
        if configuration.image != nil || image != nil {
            imageView?.image = configuration.image
            image?.tintColor = configuration.imageColorTransformer.map { $0(foreground) } ?? foreground
            image?.alpha = 1
            image?.isHidden = configuration.showsActivityIndicator
        }
        if configuration.showsActivityIndicator {
            if indicator == nil {
                let spinner = UIActivityIndicatorView(style: .medium)
                indicator = spinner
                addSubview(spinner)
            }
            indicator?.color = configuration.activityIndicatorColorTransformer.map { $0(foreground) } ?? foreground
            indicator?.startAnimating()
        } else {
            indicator?.removeFromSuperview()
            indicator = nil
        }
        setNeedsLayout()
    }

    private func layoutConfiguration(_ configuration: UIButton.Configuration) {
        let layout = configurationLayout(configuration, in: bounds.size)
        let outset = configuration.background.strokeOutset
        background?.frame = bounds.insetBy(dx: -outset, dy: -outset)
        background?.layer.cornerRadius = configuration.cornerRadius(height: bounds.height)
        image?.frame = layout.image
        indicator?.frame = layout.image
        label?.frame = layout.title
        subtitle?.frame = layout.subtitle
    }

    /// Where the image (or activity indicator), title and subtitle go in a button of `size`,
    /// and the size the button wants.
    func configurationLayout(_ configuration: UIButton.Configuration, in size: CGSize) -> (image: CGRect, title: CGRect, subtitle: CGRect, size: CGSize) {
        let insets = configuration.contentInsets.irisInsets
        let content = CGRect(origin: .zero, size: size).inset(by: insets)
        let imageSize = configuration.showsActivityIndicator ? CGSize(width: 20, height: 20) : configuration.image?.size ?? .zero
        let hasImage = imageSize != .zero
        let horizontal = !configuration.imagePlacement.isDisjoint(with: [.leading, .trailing]) || configuration.imagePlacement == .all
        let padding = hasImage ? configuration.imagePadding : 0
        let textWidth = horizontal ? content.width - imageSize.width - padding : content.width
        let titleSize = label?.text?.isEmpty == false ? label!.sizeThatFits(CGSize(width: max(textWidth, 1), height: .greatestFiniteMagnitude)) : .zero
        let subtitleSize = subtitle?.text?.isEmpty == false ? subtitle!.sizeThatFits(CGSize(width: max(textWidth, 1), height: .greatestFiniteMagnitude)) : .zero
        let titleWidth = min(titleSize.width, max(textWidth, 0))
        let subtitleWidth = min(subtitleSize.width, max(textWidth, 0))
        let between = titleSize.height > 0 && subtitleSize.height > 0 ? configuration.titlePadding : 0
        let text = CGSize(width: max(titleWidth, subtitleWidth), height: titleSize.height + between + subtitleSize.height)
        let hasText = text.height > 0
        let gap = hasImage && hasText ? padding : 0
        let group = horizontal
            ? CGSize(width: imageSize.width + gap + text.width, height: max(imageSize.height, text.height))
            : CGSize(width: max(imageSize.width, text.width), height: imageSize.height + gap + text.height)
        let origin = CGPoint(x: content.midX - group.width / 2, y: content.midY - group.height / 2)
        var imageRect = CGRect(origin: origin, size: imageSize)
        var textRect = CGRect(origin: origin, size: text)
        if horizontal {
            imageRect.origin.y += (group.height - imageSize.height) / 2
            textRect.origin.y += (group.height - text.height) / 2
            if configuration.imagePlacement.contains(.trailing) {
                imageRect.origin.x += text.width + gap
            } else {
                textRect.origin.x += imageSize.width + gap
            }
        } else {
            imageRect.origin.x += (group.width - imageSize.width) / 2
            textRect.origin.x += (group.width - text.width) / 2
            if configuration.imagePlacement.contains(.bottom) {
                imageRect.origin.y += text.height + gap
            } else {
                textRect.origin.y += imageSize.height + gap
            }
        }
        // Title and subtitle line up by the title alignment, centered unless beside an image.
        let alignment = configuration.titleAlignment == .automatic ? (horizontal && hasImage ? .leading : .center) : configuration.titleAlignment
        func aligned(_ width: CGFloat) -> CGFloat {
            switch alignment {
            case .leading: textRect.minX
            case .trailing: textRect.maxX - width
            default: textRect.midX - width / 2
            }
        }
        label?.textAlignment = alignment == .leading ? .left : alignment == .trailing ? .right : .center
        subtitle?.textAlignment = label?.textAlignment ?? .center
        let title = CGRect(x: aligned(titleWidth), y: textRect.minY, width: titleWidth, height: titleSize.height)
        let subtitleRect = CGRect(x: aligned(subtitleWidth), y: title.maxY + between, width: subtitleWidth, height: subtitleSize.height)
        let wanted = CGSize(width: ceil(group.width + insets.left + insets.right), height: ceil(group.height + insets.top + insets.bottom))
        return (imageRect, title, subtitleRect, wanted)
    }
}

extension UIButton {
    public enum ButtonType: Int, Sendable {
        case custom = 0, system, detailDisclosure, infoLight, infoDark, contactAdd
        case close = 7

        public static var roundedRect: ButtonType {
            .system
        }
    }

    public enum Role: Int, Sendable {
        case normal = 0, primary, cancel, destructive
    }
}
