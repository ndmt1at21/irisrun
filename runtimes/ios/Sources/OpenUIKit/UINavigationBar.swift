import Foundation
import IrisRender

/// What a navigation bar shows while a view controller is on top: its title or title view, its
/// buttons, and how the back button reads for the next one.
// ponytail: no prompt, search controller or navigation item styles (iOS 16).
@preconcurrency @MainActor
open class UINavigationItem: NSObject {
    public override init() {
        super.init()
    }

    public convenience init(title: String) {
        self.init()
        self.title = title
    }

    open var title: String? {
        didSet { changed() }
    }

    /// Shown in place of the title, as big as its frame, or its intrinsic size if it has one.
    open var titleView: UIView? {
        didSet { changed() }
    }

    open var prompt: String?

    /// The back button the next item shows: only its title counts, as in UIKit.
    open var backBarButtonItem: UIBarButtonItem? {
        didSet { changed() }
    }

    /// What the next item's back button reads in place of this item's title.
    open var backButtonTitle: String? {
        didSet { changed() }
    }

    open var backButtonDisplayMode = BackButtonDisplayMode.default {
        didSet { changed() }
    }

    open var hidesBackButton = false {
        didSet { changed() }
    }

    open func setHidesBackButton(_ hidesBackButton: Bool, animated: Bool) {
        self.hidesBackButton = hidesBackButton
    }

    /// From the leading edge in; in place of the back button, unless they supplement it.
    open var leftBarButtonItems: [UIBarButtonItem]? {
        didSet { changed() }
    }

    /// From the trailing edge in.
    open var rightBarButtonItems: [UIBarButtonItem]? {
        didSet { changed() }
    }

    open var leftBarButtonItem: UIBarButtonItem? {
        get { leftBarButtonItems?.first }
        set { leftBarButtonItems = newValue.map { [$0] } }
    }

    open var rightBarButtonItem: UIBarButtonItem? {
        get { rightBarButtonItems?.first }
        set { rightBarButtonItems = newValue.map { [$0] } }
    }

    open func setLeftBarButtonItems(_ items: [UIBarButtonItem]?, animated: Bool) {
        leftBarButtonItems = items
    }

    open func setRightBarButtonItems(_ items: [UIBarButtonItem]?, animated: Bool) {
        rightBarButtonItems = items
    }

    open func setLeftBarButton(_ item: UIBarButtonItem?, animated: Bool) {
        leftBarButtonItem = item
    }

    open func setRightBarButton(_ item: UIBarButtonItem?, animated: Bool) {
        rightBarButtonItem = item
    }

    open var leftItemsSupplementBackButton = false {
        didSet { changed() }
    }

    /// Whether the bar shows the title large, if it prefers large titles: automatic follows the
    /// item before, and is large for the first.
    open var largeTitleDisplayMode = LargeTitleDisplayMode.automatic {
        didSet { changed() }
    }

    /// The bar's look while this item is on top, in place of the bar's own.
    open var standardAppearance: UINavigationBarAppearance? {
        didSet { changed() }
    }

    open var compactAppearance: UINavigationBarAppearance?

    open var scrollEdgeAppearance: UINavigationBarAppearance? {
        didSet { changed() }
    }

    open var compactScrollEdgeAppearance: UINavigationBarAppearance?

    /// Iris: the bar that shows the item, as the top item or one under it.
    weak var irisBar: UINavigationBar?

    private func changed() {
        irisBar?.irisItemsDidChange()
    }

    public enum LargeTitleDisplayMode: Int, Sendable {
        case automatic = 0, always, never, inline
    }

    public enum BackButtonDisplayMode: Int, Sendable {
        /// The previous item's title, or "Back" if it doesn't fit.
        case `default` = 0
        /// "Back".
        case generic
        /// The chevron alone.
        case minimal
    }
}

// MARK: - Appearance

/// How a bar's background looks: by default a translucent material with a hairline under it,
/// opaque, or transparent.
// ponytail: no background effects (UIBlurEffect), images or shadow images; the material is a
// translucent near-white, as the render core has no blur.
@preconcurrency @MainActor
open class UIBarAppearance: NSObject, @preconcurrency NSCopying {
    public override init() {
        super.init()
        configureWithDefaultBackground()
    }

    public required init(barAppearance: UIBarAppearance) {
        super.init()
        (backgroundColor, shadowColor, irisMaterial) = (barAppearance.backgroundColor, barAppearance.shadowColor, barAppearance.irisMaterial)
    }

    open func copy(with zone: NSZone? = nil) -> Any {
        Self.init(barAppearance: self)
    }

    /// Drawn over the material, if any.
    open var backgroundColor: UIColor?

    /// The hairline under the bar; none if nil or clear.
    open var shadowColor: UIColor?

    /// Iris: the system's translucent material, under the background color.
    var irisMaterial = false

    open func configureWithDefaultBackground() {
        (irisMaterial, backgroundColor, shadowColor) = (true, nil, UIColor(white: 0, alpha: 0.3))
    }

    open func configureWithOpaqueBackground() {
        (irisMaterial, backgroundColor, shadowColor) = (false, .systemBackground, UIColor(white: 0, alpha: 0.3))
    }

    open func configureWithTransparentBackground() {
        (irisMaterial, backgroundColor, shadowColor) = (false, nil, nil)
    }

    /// Iris: what the bar's background shows.
    var irisBackground: UIColor? {
        backgroundColor ?? (irisMaterial ? UIColor(red: 249 / 255, green: 249 / 255, blue: 249 / 255, alpha: 0.94) : nil)
    }
}

/// A navigation bar's look: its background, and the font and color of its titles.
@preconcurrency @MainActor
open class UINavigationBarAppearance: UIBarAppearance {
    public required init(barAppearance: UIBarAppearance) {
        super.init(barAppearance: barAppearance)
        if let navigation = barAppearance as? UINavigationBarAppearance {
            (titleTextAttributes, largeTitleTextAttributes) = (navigation.titleTextAttributes, navigation.largeTitleTextAttributes)
        }
    }

    public override init() {
        super.init()
    }

    open var titleTextAttributes: [NSAttributedString.Key: Any] = [:]
    open var largeTitleTextAttributes: [NSAttributedString.Key: Any] = [:]
}

// MARK: - The bar

/// A bar at the top of a navigation controller's view that shows the top item: its title in the
/// middle, 44 points high, or large below that in another 52 when the bar prefers large titles;
/// its buttons at the sides; and a back button with a chevron and the item before's title. Its
/// background reaches up under the status bar: the standard appearance, or the scroll edge one
/// (transparent unless set) while the content's scroll view is at its top, or if there is none, as
/// in iOS 15 and later.
// ponytail: large titles don't shrink as the content scrolls, and the bar's content changes at
// once on a push or pop instead of sliding; no delegate, prompts or background images.
@preconcurrency @MainActor
open class UINavigationBar: UIView, IrisItemBar {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        background.isUserInteractionEnabled = false
        background.addSubview(shadow)
        titleLabel.textAlignment = .center
        largeTitleView.addSubview(largeTitleLabel)
        back.addAction(UIAction { [weak self] _ in self?.backTapped() }, for: .touchUpInside)
        for view in [titleLabel, back] as [UIView] {
            content.addSubview(view)
        }
        for view in [background, content, largeTitleView] as [UIView] {
            addSubview(view)
        }
    }

    // MARK: Items

    open private(set) var items: [UINavigationItem]?

    open var topItem: UINavigationItem? {
        items?.last
    }

    open var backItem: UINavigationItem? {
        guard let items, items.count > 1 else { return nil }
        return items[items.count - 2]
    }

    open func setItems(_ items: [UINavigationItem]?, animated: Bool) {
        self.items = items
        for item in items ?? [] {
            item.irisBar = self
        }
        irisItemsDidChange()
    }

    open func pushItem(_ item: UINavigationItem, animated: Bool) {
        setItems((items ?? []) + [item], animated: animated)
    }

    @discardableResult
    open func popItem(animated: Bool) -> UINavigationItem? {
        guard let item = items?.last else { return nil }
        setItems(items.map { Array($0.dropLast()) }, animated: animated)
        return item
    }

    /// Iris: the navigation controller whose bar this is.
    weak var irisNavigationController: UINavigationController?

    open var prefersLargeTitles = false {
        didSet { irisItemsDidChange() }
    }

    // MARK: Appearance

    open var standardAppearance = UINavigationBarAppearance() {
        didSet { irisItemsDidChange() }
    }

    open var compactAppearance: UINavigationBarAppearance?

    /// Used while the content is scrolled to its top; nil for the standard appearance with a
    /// transparent background.
    open var scrollEdgeAppearance: UINavigationBarAppearance? {
        didSet { irisItemsDidChange() }
    }

    open var compactScrollEdgeAppearance: UINavigationBarAppearance?

    /// Older ways of setting the standard appearance, which UIKit carries over to it.
    open var barTintColor: UIColor? {
        get { standardAppearance.backgroundColor }
        set {
            standardAppearance.backgroundColor = newValue
            irisItemsDidChange()
        }
    }

    open var isTranslucent = true {
        didSet {
            if isTranslucent { standardAppearance.configureWithDefaultBackground() } else { standardAppearance.configureWithOpaqueBackground() }
            irisItemsDidChange()
        }
    }

    open var titleTextAttributes: [NSAttributedString.Key: Any]? {
        get { standardAppearance.titleTextAttributes }
        set {
            standardAppearance.titleTextAttributes = newValue ?? [:]
            irisItemsDidChange()
        }
    }

    open var largeTitleTextAttributes: [NSAttributedString.Key: Any]? {
        get { standardAppearance.largeTitleTextAttributes }
        set {
            standardAppearance.largeTitleTextAttributes = newValue ?? [:]
            irisItemsDidChange()
        }
    }

    /// The appearance that shows: the top item's or the bar's, at the scroll edge or not.
    private var appearance: UINavigationBarAppearance {
        let standard = topItem?.standardAppearance ?? standardAppearance
        guard isAtScrollEdge else { return standard }
        if let edge = topItem?.scrollEdgeAppearance ?? scrollEdgeAppearance { return edge }
        let transparent = UINavigationBarAppearance(barAppearance: standard)
        transparent.configureWithTransparentBackground()
        return transparent
    }

    /// The top view controller's content scroll view, if any, is scrolled to its top.
    private var isAtScrollEdge: Bool {
        guard let scrollView = irisNavigationController?.topViewController?.contentScrollView(for: .top) else { return true }
        return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
    }

    // MARK: Iris: views

    private let background = _UIBarBackground()
    private let shadow = _UIBarBackgroundShadowView()
    private let content = _UINavigationBarContentView()
    private let titleLabel = UILabel()
    private let back = _UIButtonBarButton()
    private let largeTitleView = _UINavigationBarLargeTitleView()
    private let largeTitleLabel = UILabel()
    private var leftViews: [UIView] = []
    private var rightViews: [UIView] = []
    private var shownTitleView: UIView?
    private var needsRebuild = true
    /// Whether the scroll edge appearance showed when the titles were last styled.
    private var styledAtScrollEdge: Bool?

    /// The items changed: the bar shows them anew, and the navigation controller lays out again,
    /// as the bar's height may have changed.
    func irisItemsDidChange() {
        needsRebuild = true
        setNeedsLayout()
        superview?.setNeedsLayout()
    }

    /// The height the bar has with `item` on top: 44 points, and 52 more for a large title.
    func irisHeight(for item: UINavigationItem?) -> CGFloat {
        item.map(showsLargeTitle) == true ? 96 : 44
    }

    private func showsLargeTitle(_ item: UINavigationItem) -> Bool {
        guard prefersLargeTitles, let items, let index = items.firstIndex(where: { $0 === item }) else { return false }
        for current in items[...index].reversed() {
            switch current.largeTitleDisplayMode {
            case .always: return true
            case .never, .inline: return false
            case .automatic: continue
            }
        }
        return true
    }

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: irisHeight(for: topItem))
    }

    /// The back button comes, unless the top item hides it or has left items in its place.
    private var showsBack: Bool {
        guard let top = topItem, backItem != nil, !top.hidesBackButton else { return false }
        return top.leftBarButtonItems?.isEmpty ?? true || top.leftItemsSupplementBackButton
    }

    /// Makes the views for the top item's buttons and title view.
    private func rebuild() {
        needsRebuild = false
        for view in leftViews + rightViews + [shownTitleView].compactMap({ $0 }) {
            view.removeFromSuperview()
        }
        let top = topItem
        let views = { (items: [UIBarButtonItem]?) -> [UIView] in
            (items ?? []).filter { $0.systemItem != .flexibleSpace }.map { item in
                item.irisBar = self
                let view = item.irisMakeView()
                self.content.addSubview(view)
                return view
            }
        }
        leftViews = showsBack && top?.leftItemsSupplementBackButton != true ? [] : views(top?.leftBarButtonItems)
        rightViews = views(top?.rightBarButtonItems)
        shownTitleView = top?.titleView
        if let shownTitleView {
            content.addSubview(shownTitleView)
        }
        titleLabel.text = top?.title
        largeTitleLabel.text = top?.title
        back.isHidden = !showsBack
        styledAtScrollEdge = nil
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        if needsRebuild {
            rebuild()
        }
        let appearance = appearance
        if styledAtScrollEdge != isAtScrollEdge {
            styledAtScrollEdge = isAtScrollEdge
            style(titleLabel, appearance.titleTextAttributes, font: .systemFont(ofSize: 17, weight: .semibold))
            style(largeTitleLabel, appearance.largeTitleTextAttributes, font: .systemFont(ofSize: 34, weight: .bold))
        }
        background.frame = CGRect(x: 0, y: -frame.minY, width: bounds.width, height: bounds.height + frame.minY)
        background.backgroundColor = appearance.irisBackground
        shadow.frame = CGRect(x: 0, y: background.bounds.height, width: bounds.width, height: 1 / UIScreen.main.scale)
        shadow.backgroundColor = appearance.shadowColor
        shadow.isHidden = appearance.shadowColor.map { $0.cgColor.alpha == 0 } ?? true
        let large = topItem.map(showsLargeTitle) == true
        titleLabel.isHidden = large
        largeTitleView.isHidden = !large
        content.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
        largeTitleView.frame = CGRect(x: 0, y: 44, width: bounds.width, height: 52)
        largeTitleLabel.frame = CGRect(x: 16, y: 0, width: max(bounds.width - 32, 0), height: 52)
        layOutRow()
    }

    private func style(_ label: UILabel, _ attributes: [NSAttributedString.Key: Any], font: UIFont) {
        label.font = attributes[.font] as? UIFont ?? font
        label.textColor = attributes[.foregroundColor] as? UIColor ?? .label
    }

    /// The 44-point row: buttons from each side in, 16 points from the edges and 8 apart, the
    /// back button's chevron 8 points from the leading edge; the title in the middle of the bar
    /// if it fits there, else in the middle of the room left.
    private func layOutRow() {
        let width = bounds.width, height: CGFloat = 44
        func size(of view: UIView) -> CGSize {
            let intrinsic = view.intrinsicContentSize
            return CGSize(
                width: intrinsic.width >= 0 ? intrinsic.width : view.bounds.width,
                height: min(intrinsic.height >= 0 ? intrinsic.height : view.bounds.height, height)
            )
        }
        var trailing = width - 16
        for view in rightViews {
            let size = size(of: view)
            trailing -= size.width
            view.frame = CGRect(x: trailing, y: (height - size.height) / 2, width: size.width, height: size.height)
            trailing -= 8
        }
        let titleSize = shownTitleView.map(size(of:)) ?? CGSize(width: titleLabel.intrinsicContentSize.width, height: height)
        // The back button reads the item before's title, or "Back" if that would reach the
        // title, or nothing.
        var leading: CGFloat = 16
        if showsBack, let item = backItem {
            let centered = (width - titleSize.width) / 2
            var choices = [item.backButtonTitle ?? item.backBarButtonItem?.title ?? item.title, "Back", nil]
            switch topItem?.backButtonDisplayMode ?? .default {
            case .default: break
            case .generic: choices.removeFirst()
            case .minimal: choices = [nil]
            }
            for choice in choices {
                back.title = choice
                if choice == nil || back.intrinsicContentSize.width + 8 <= centered || (topItem?.title ?? "").isEmpty && shownTitleView == nil {
                    break
                }
            }
            back.frame = CGRect(x: 0, y: 0, width: back.intrinsicContentSize.width, height: height)
            leading = back.frame.maxX + 8
        }
        for view in leftViews {
            let size = size(of: view)
            view.frame = CGRect(x: leading, y: (height - size.height) / 2, width: size.width, height: size.height)
            leading += size.width + 8
        }
        let room = max(trailing - leading, 0)
        let titleWidth = min(titleSize.width, room)
        let x = min(max((width - titleWidth) / 2, leading), leading + room - titleWidth)
        let titleFrame = CGRect(x: x, y: (height - titleSize.height) / 2, width: titleWidth, height: titleSize.height)
        if let shownTitleView {
            shownTitleView.frame = titleFrame
        } else {
            titleLabel.frame = titleFrame
        }
    }

    private func backTapped() {
        if let irisNavigationController {
            irisNavigationController.popViewController(animated: true)
        } else {
            popItem(animated: true)
        }
    }
}

/// Iris: a bar's background, with UIKit's class name; a navigation bar's reaches up under the
/// status bar.
@MainActor
final class _UIBarBackground: UIView {}

/// Iris: the hairline along a bar.
@MainActor
final class _UIBarBackgroundShadowView: UIView {}

@MainActor
private final class _UINavigationBarContentView: UIView {}

@MainActor
private final class _UINavigationBarLargeTitleView: UIView {}

/// Iris: a navigation bar's back button: the chevron 8 points from the leading edge, then the
/// title 6 points after it, in the tint; it fades while touched, as system buttons do.
@MainActor
private final class _UIButtonBarButton: UIControl {
    private let chevron = UIView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        chevron.isUserInteractionEnabled = false
        label.font = .systemFont(ofSize: 17)
        addSubview(chevron)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var title: String? {
        get { label.text }
        set {
            label.text = newValue
            label.isHidden = newValue == nil
            accessibilityLabel = newValue ?? "Back"
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 8 + 12 + (title.map { _ in 6 + label.intrinsicContentSize.width } ?? 0), height: 44)
    }

    override var isHighlighted: Bool {
        didSet { tintColorDidChange() }
    }

    override func tintColorDidChange() {
        label.textColor = tintColor
        label.alpha = isHighlighted ? 0.2 : 1
        chevron.alpha = label.alpha
        setNeedsLayout()
    }

    /// SF Symbols' chevron.backward at 17 points, semibold, as round-ended strokes.
    override func layoutSubviews() {
        super.layoutSubviews()
        chevron.frame = CGRect(x: 8, y: (bounds.height - 20) / 2, width: 12, height: 20)
        label.frame = CGRect(x: 26, y: 0, width: max(bounds.width - 26, 0), height: bounds.height)
        var path = IrisRender.Path()
        path.move(to: Point(x: 10.75, y: 1.25))
        path.addLine(to: Point(x: 1.25, y: 10))
        path.addLine(to: Point(x: 10.75, y: 18.75))
        chevron.layer.irisDrawing = IrisDrawing(
            content: .shape(path, ShapeStyle(fill: 0, stroke: tintColor.cgColor.argb, lineWidth: 2.5, lineCap: .round, lineJoin: .round)),
            frame: chevron.bounds
        )
    }
}
