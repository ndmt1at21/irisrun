import Foundation
import IrisHost
@testable import OpenUIKit
import Testing

// Auto Layout as UIKit does it: constraints, priorities, intrinsic sizes and the guides UIKit
// keeps, solved by the render core's Cassowary solver.

/// A view placed by constraints in `superview`.
@MainActor
private func make<View: UIView>(_ view: View, in superview: UIView) -> View {
    view.translatesAutoresizingMaskIntoConstraints = false
    superview.addSubview(view)
    return view
}

@MainActor
private func make(in superview: UIView) -> UIView {
    make(UIView(), in: superview)
}

@MainActor
private func label(_ text: String, in superview: UIView) -> UILabel {
    let label = make(UILabel(), in: superview)
    label.text = text
    return label
}

@MainActor
private func screen() -> UIView {
    UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
}

@MainActor @Test func constraintsPinCenterAndChainViews() {
    let root = screen()
    let header = make(in: root), left = make(in: root), right = make(in: root), badge = make(in: root)
    let inner = make(in: header)
    NSLayoutConstraint.activate([
        header.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
        header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 15),
        header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -15),
        header.heightAnchor.constraint(equalToConstant: 100),
        // Two equal widths in a chain, 10 points apart, 5 wide for every 2 high.
        left.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
        left.leadingAnchor.constraint(equalTo: header.leadingAnchor),
        right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 10),
        right.trailingAnchor.constraint(equalTo: header.trailingAnchor),
        right.widthAnchor.constraint(equalTo: left.widthAnchor),
        right.topAnchor.constraint(equalTo: left.topAnchor),
        left.heightAnchor.constraint(equalTo: left.widthAnchor, multiplier: 0.4),
        right.heightAnchor.constraint(equalTo: left.heightAnchor, multiplier: 1, constant: 20),
        // Centered, with the item and attribute API.
        NSLayoutConstraint(item: badge, attribute: .centerX, relatedBy: .equal, toItem: header, attribute: .centerX, multiplier: 1, constant: 0),
        NSLayoutConstraint(item: badge, attribute: .centerY, relatedBy: .equal, toItem: header, attribute: .centerY, multiplier: 1, constant: 0),
        NSLayoutConstraint(item: badge, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 40),
        badge.heightAnchor.constraint(equalTo: badge.widthAnchor),
        // In the header, lined up with a view outside it: in the header's coordinates.
        inner.leadingAnchor.constraint(equalTo: right.leadingAnchor),
        inner.topAnchor.constraint(equalTo: header.topAnchor, constant: 5),
        inner.widthAnchor.constraint(equalToConstant: 30),
        inner.heightAnchor.constraint(equalToConstant: 30),
    ])
    root.layoutIfNeeded()
    #expect(header.frame == CGRect(x: 15, y: 20, width: 360, height: 100))
    #expect(left.frame == CGRect(x: 15, y: 130, width: 175, height: 70))
    #expect(right.frame == CGRect(x: 200, y: 130, width: 175, height: 90))
    #expect(badge.frame == CGRect(x: 175, y: 50, width: 40, height: 40))
    #expect(inner.frame == CGRect(x: 185, y: 5, width: 30, height: 30))
    // The closest view both items are in holds a constraint; constraints of one item, the item.
    #expect(root.constraints.count == 13)
    #expect(header.constraints.count == 2 && left.constraints.count == 1 && inner.constraints.count == 2)
    #expect(header.constraints.contains { $0.firstItem === inner && $0.firstAttribute == .top })
}

@MainActor @Test func constantsAndPrioritiesChangeIncrementally() {
    let root = screen()
    let box = make(in: root)
    let height = box.heightAnchor.constraint(equalToConstant: 50)
    let wish = box.widthAnchor.constraint(equalToConstant: 100)
    wish.priority = .defaultHigh
    let wider = box.widthAnchor.constraint(equalToConstant: 200)
    wider.priority = UILayoutPriority(500)
    NSLayoutConstraint.activate([
        box.topAnchor.constraint(equalTo: root.topAnchor), box.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        height, wish, wider, box.widthAnchor.constraint(lessThanOrEqualToConstant: 150),
    ])
    root.layoutIfNeeded()
    // The higher priority wins; the required bound holds.
    #expect(box.frame.size == CGSize(width: 100, height: 50))
    wider.priority = UILayoutPriority(800)
    height.constant = 80
    root.layoutIfNeeded()
    #expect(box.frame.size == CGSize(width: 150, height: 80))
    // An inactive constraint counts no more, and again once active.
    height.isActive = false
    #expect(!height.isActive && height.firstItem === box)
    root.layoutIfNeeded()
    #expect(box.frame.height == 0)
    height.isActive = true
    root.layoutIfNeeded()
    #expect(box.frame.height == 80)
}

@MainActor @Test func labelsHugAndResistCompressionByPriority() {
    let root = screen()
    let name = label("Name", in: root), value = label("Value", in: root)
    value.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
    NSLayoutConstraint.activate([
        name.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
        value.leadingAnchor.constraint(equalTo: name.trailingAnchor, constant: 8),
        value.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
        name.topAnchor.constraint(equalTo: root.topAnchor), value.topAnchor.constraint(equalTo: root.topAnchor),
    ])
    root.layoutIfNeeded()
    // The label that hugs harder keeps its size; the other one takes the room left.
    let valueWidth = value.intrinsicContentSize.width
    #expect(value.frame.size == value.intrinsicContentSize)
    #expect(name.frame.width == 390 - 32 - 8 - valueWidth)
    #expect(name.frame.height == name.intrinsicContentSize.height)
    // Text that doesn't fit: the label that resists less gives way.
    name.text = String(repeating: "Long name ", count: 6)
    value.text = String(repeating: "Long value ", count: 3)
    name.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
    root.layoutIfNeeded()
    #expect(value.frame.width == value.intrinsicContentSize.width)
    #expect(name.frame.width == 390 - 32 - 8 - value.frame.width)
    // A changed intrinsic size lays out again.
    value.text = "OK"
    root.layoutIfNeeded()
    #expect(value.frame.width == value.intrinsicContentSize.width)
    #expect(value.frame.maxX == 374)
}

@MainActor @Test func autoresizingMasksBecomeConstraints() {
    let root = screen()
    // Placed by its frame and mask; constraints place the views inside it and below it.
    let panel = UIView(frame: CGRect(x: 20, y: 100, width: 350, height: 200))
    panel.autoresizingMask = [.flexibleWidth]
    root.addSubview(panel)
    let content = make(in: panel), below = make(in: root), marked = make(in: panel)
    NSLayoutConstraint.activate([
        // In the panel's coordinates, wherever the panel is.
        marked.topAnchor.constraint(equalTo: panel.layoutMarginsGuide.topAnchor),
        marked.trailingAnchor.constraint(equalTo: panel.layoutMarginsGuide.trailingAnchor),
        marked.widthAnchor.constraint(equalToConstant: 4), marked.heightAnchor.constraint(equalToConstant: 4),
        content.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
        content.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10),
        content.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
        content.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
        below.topAnchor.constraint(equalTo: panel.bottomAnchor, constant: 8),
        below.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
        below.widthAnchor.constraint(equalTo: panel.widthAnchor, multiplier: 0.5),
        below.heightAnchor.constraint(equalToConstant: 10),
    ])
    root.layoutIfNeeded()
    #expect(panel.frame == CGRect(x: 20, y: 100, width: 350, height: 200))
    #expect(content.frame == CGRect(x: 10, y: 10, width: 330, height: 180))
    #expect(below.frame == CGRect(x: 20, y: 308, width: 175, height: 10))
    #expect(marked.frame == CGRect(x: 338, y: 8, width: 4, height: 4))
    // The superview grows: the panel autoresizes, and what is constrained to it follows.
    root.frame.size.width = 430
    root.layoutIfNeeded()
    #expect(panel.frame == CGRect(x: 20, y: 100, width: 390, height: 200))
    #expect(content.frame == CGRect(x: 10, y: 10, width: 370, height: 180))
    #expect(below.frame.width == 195)
    // The panel moved by hand.
    panel.frame.origin.y = 50
    root.layoutIfNeeded()
    #expect(below.frame.minY == 258)
}

@MainActor @Test func safeAreaMarginsAndKeyboardGuidesFollowTheScreen() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let controller = UIViewController()
    window.rootViewController = controller
    window.isHidden = false
    defer { window.isHidden = true }
    let view: UIView = controller.view
    let box = make(in: view), card = make(in: view), footer = make(in: view)
    let inner = make(in: card)
    NSLayoutConstraint.activate([
        box.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        box.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
        box.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        box.heightAnchor.constraint(equalToConstant: 20),
        // A view's own margins are 8 points, inside its safe area.
        card.topAnchor.constraint(equalTo: view.topAnchor),
        card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        card.heightAnchor.constraint(equalToConstant: 200),
        NSLayoutConstraint(item: inner, attribute: .top, relatedBy: .equal, toItem: card, attribute: .topMargin, multiplier: 1, constant: 0),
        NSLayoutConstraint(item: inner, attribute: .leading, relatedBy: .equal, toItem: card, attribute: .leadingMargin, multiplier: 1, constant: 0),
        inner.widthAnchor.constraint(equalToConstant: 10), inner.heightAnchor.constraint(equalToConstant: 10),
        // Above the keyboard, which is down: above the home indicator.
        footer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        footer.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
        footer.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
        footer.heightAnchor.constraint(equalToConstant: 44),
    ])
    window.layoutIfNeeded()
    #expect(view.safeAreaLayoutGuide.layoutFrame == CGRect(x: 0, y: 47, width: 390, height: 763))
    #expect(view.layoutMargins == UIEdgeInsets(top: 47, left: 16, bottom: 34, right: 16))
    #expect(view.layoutMarginsGuide.layoutFrame == CGRect(x: 16, y: 47, width: 358, height: 763))
    #expect(view.readableContentGuide.layoutFrame == view.layoutMarginsGuide.layoutFrame)
    #expect(view.keyboardLayoutGuide.layoutFrame == CGRect(x: 0, y: 810, width: 390, height: 34))
    #expect(box.frame == CGRect(x: 16, y: 47, width: 358, height: 20))
    #expect(inner.frame == CGRect(x: 8, y: 55, width: 10, height: 10))
    #expect(footer.frame == CGRect(x: 16, y: 766, width: 358, height: 44))
    // Margins the app sets; a view controller's view keeps the system minimum at the sides.
    view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 4, bottom: 0, trailing: 30)
    window.layoutIfNeeded()
    #expect(box.frame == CGRect(x: 16, y: 47, width: 344, height: 20))
    card.insetsLayoutMarginsFromSafeArea = false
    window.layoutIfNeeded()
    #expect(inner.frame.minY == 8)
}

@MainActor @Test func layoutGuidesAreSpacesBetweenViews() {
    let root = screen()
    let first = make(in: root), second = make(in: root)
    let gap = UILayoutGuide()
    root.addLayoutGuide(gap)
    NSLayoutConstraint.activate([
        first.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
        first.widthAnchor.constraint(equalToConstant: 100),
        gap.leadingAnchor.constraint(equalTo: first.trailingAnchor),
        gap.widthAnchor.constraint(equalToConstant: 50),
        second.leadingAnchor.constraint(equalTo: gap.trailingAnchor),
        second.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
        gap.topAnchor.constraint(equalTo: root.topAnchor, constant: 30), gap.heightAnchor.constraint(equalToConstant: 20),
        first.centerYAnchor.constraint(equalTo: gap.centerYAnchor), second.centerYAnchor.constraint(equalTo: gap.centerYAnchor),
        first.heightAnchor.constraint(equalToConstant: 10), second.heightAnchor.constraint(equalToConstant: 10),
    ])
    root.layoutIfNeeded()
    #expect(gap.owningView === root && root.layoutGuides.count == 1)
    #expect(gap.layoutFrame == CGRect(x: 110, y: 30, width: 50, height: 20))
    #expect(second.frame == CGRect(x: 160, y: 35, width: 220, height: 10))
    // Taking the guide out takes its constraints.
    root.removeLayoutGuide(gap)
    #expect(gap.owningView == nil && root.constraints.count == 2)
}

@MainActor @Test func labelsWrapAtTheWidthLayoutGivesThem() throws {
    makeScene()
    let root = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 600))
    let text = label("Auto Layout gives this label its width, and it wraps its lines to fit.", in: root)
    text.numberOfLines = 0
    let below = make(in: root)
    NSLayoutConstraint.activate([
        text.topAnchor.constraint(equalTo: root.topAnchor),
        text.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
        text.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
        below.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 4),
        below.leadingAnchor.constraint(equalTo: root.leadingAnchor), below.widthAnchor.constraint(equalToConstant: 10), below.heightAnchor.constraint(equalToConstant: 10),
    ])
    root.layoutIfNeeded()
    let wrapped = text.sizeThatFits(CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude))
    #expect(wrapped.height > text.font.lineHeight * 2)
    #expect(text.frame == CGRect(x: 10, y: 0, width: 180, height: wrapped.height))
    #expect(below.frame.minY == wrapped.height + 4)
}

@MainActor @Test func viewsTellTheSizeTheirConstraintsGiveThem() throws {
    makeScene()
    let card = UIView()
    let title = label("Title", in: card)
    let body = label("A body of text that is longer than the card is wide.", in: card)
    body.numberOfLines = 0
    NSLayoutConstraint.activate([
        title.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
        title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        title.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -16),
        body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
        body.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        body.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        body.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
    ])
    let titleHeight = title.intrinsicContentSize.height
    // As small as the constraints let it: one line of body text.
    let compressed = card.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    #expect(compressed == CGSize(width: body.intrinsicContentSize.width + 32, height: 28 + titleHeight + body.intrinsicContentSize.height))
    // A width it must have, as a table cell: the body wraps to it.
    let fitted = card.systemLayoutSizeFitting(CGSize(width: 200, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    let bodyHeight = body.sizeThatFits(CGSize(width: 168, height: CGFloat.greatestFiniteMagnitude)).height
    #expect(bodyHeight > body.intrinsicContentSize.height)
    #expect(fitted == CGSize(width: 200, height: 28 + titleHeight + bodyHeight))
    // A view without constraints inside is its intrinsic size.
    #expect(title.systemLayoutSizeFitting(.zero) == title.intrinsicContentSize)
    // Fitting changes nothing: the card was never laid out.
    #expect(card.frame == .zero && body.frame == .zero)
}

@MainActor @Test func baselinesLineUpTextOfDifferentSizes() throws {
    makeScene()
    let root = screen()
    let big = label("Big", in: root), small = label("small", in: root)
    big.font = .systemFont(ofSize: 34)
    NSLayoutConstraint.activate([
        big.topAnchor.constraint(equalTo: root.topAnchor, constant: 100), big.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        small.leadingAnchor.constraint(equalTo: big.trailingAnchor, constant: 8),
        small.firstBaselineAnchor.constraint(equalTo: big.firstBaselineAnchor),
    ])
    root.layoutIfNeeded()
    let (bigOffset, smallOffset) = (try #require(big.irisBaselineOffsets), try #require(small.irisBaselineOffsets))
    let bigBaseline = big.frame.midY + bigOffset.first
    let smallBaseline = small.frame.midY + smallOffset.first
    #expect(abs(bigBaseline - smallBaseline) < 0.5)
    #expect(small.frame.minY > big.frame.minY)
}

@MainActor @Test func conflictingConstraintsBreakOneAndLogWhichAsUIKitDoes() {
    var logged: [String] = []
    let log = LayoutEngine.log
    LayoutEngine.log = { logged.append($0) }
    defer { LayoutEngine.log = log }
    let root = screen()
    let box = make(in: root)
    let narrow = box.widthAnchor.constraint(equalToConstant: 100)
    let wide = box.widthAnchor.constraint(equalToConstant: 200)
    wide.identifier = "wide"
    NSLayoutConstraint.activate([box.leadingAnchor.constraint(equalTo: root.leadingAnchor), box.heightAnchor.constraint(equalToConstant: 10), narrow, wide])
    root.layoutIfNeeded()
    #expect(box.frame.width == 100)
    #expect(logged.count == 1)
    let message = logged.first ?? ""
    #expect(message.hasPrefix("[LayoutConstraints] Unable to simultaneously satisfy constraints."))
    // Only the constraints in the conflict are listed, then the one broken.
    #expect(message.contains("\"\(narrow)\"") && message.contains("\"\(wide)\""))
    #expect(!message.contains("height"))
    #expect(message.contains("Will attempt to recover by breaking constraint \n\(wide)"))
    #expect(wide.description.hasPrefix("<NSLayoutConstraint:0x") && wide.description.hasSuffix(" 'wide' UIView:\(address(of: box)).width == 200   (active)>"))
    // The conflict gone, the broken constraint holds.
    narrow.isActive = false
    root.layoutIfNeeded()
    #expect(box.frame.width == 200)
    #expect(logged.count == 1)
}

/// Adds its constraints in `updateConstraints`, as custom views do.
private final class SelfConstrainingView: UIView {
    var updates = 0
    var side: CGFloat = 30
    private var size: [NSLayoutConstraint] = []

    override class var requiresConstraintBasedLayout: Bool {
        true
    }

    override func updateConstraints() {
        updates += 1
        NSLayoutConstraint.deactivate(size)
        size = [widthAnchor.constraint(equalToConstant: side), heightAnchor.constraint(equalToConstant: side)]
        NSLayoutConstraint.activate(size)
        super.updateConstraints()
    }
}

@MainActor @Test func updateConstraintsRunsBeforeLayoutWhereNeeded() {
    let root = screen()
    let view = make(SelfConstrainingView(), in: root)
    NSLayoutConstraint.activate([view.topAnchor.constraint(equalTo: root.topAnchor), view.leadingAnchor.constraint(equalTo: root.leadingAnchor)])
    root.layoutIfNeeded()
    #expect(view.updates == 1 && view.frame.size == CGSize(width: 30, height: 30))
    #expect(!view.needsUpdateConstraints())
    root.layoutIfNeeded()
    #expect(view.updates == 1)
    view.side = 50
    view.setNeedsUpdateConstraints()
    #expect(view.needsUpdateConstraints())
    root.layoutIfNeeded()
    #expect(view.updates == 2 && view.frame.size == CGSize(width: 50, height: 50))
}

@MainActor @Test func removingAViewTakesTheConstraintsToItButNotThoseInside() throws {
    let root = screen()
    let panel = make(in: root), content = make(in: panel)
    NSLayoutConstraint.activate([
        panel.topAnchor.constraint(equalTo: root.topAnchor), panel.leadingAnchor.constraint(equalTo: root.leadingAnchor),
        panel.widthAnchor.constraint(equalToConstant: 100), panel.heightAnchor.constraint(equalToConstant: 80),
        content.topAnchor.constraint(equalTo: panel.topAnchor, constant: 5), content.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 5),
        content.widthAnchor.constraint(equalToConstant: 40), content.heightAnchor.constraint(equalToConstant: 30),
    ])
    root.layoutIfNeeded()
    #expect(panel.frame == CGRect(x: 0, y: 0, width: 100, height: 80))
    panel.removeFromSuperview()
    #expect(root.constraints.isEmpty)
    #expect(panel.constraints.count == 4 && content.constraints.count == 2)
    // Its own hierarchy lays it out by the constraints it kept.
    let top = try #require(panel.constraints.first { $0.firstItem === content && $0.firstAttribute == .top })
    top.constant = 15
    panel.layoutIfNeeded()
    #expect(content.frame == CGRect(x: 5, y: 15, width: 40, height: 30))
}

@MainActor @Test func ambiguousLayoutsAreFound() {
    let root = screen()
    let box = make(in: root), framed = UIView(frame: CGRect(x: 5, y: 5, width: 5, height: 5))
    root.addSubview(framed)
    NSLayoutConstraint.activate([box.widthAnchor.constraint(equalToConstant: 20), box.heightAnchor.constraint(equalToConstant: 20)])
    root.layoutIfNeeded()
    #expect(box.hasAmbiguousLayout)
    #expect(!framed.hasAmbiguousLayout)
    box.exerciseAmbiguityInLayout()
    #expect(box.frame.origin != .zero && box.frame.size == CGSize(width: 20, height: 20))
    NSLayoutConstraint.activate([box.topAnchor.constraint(equalTo: root.topAnchor), box.leadingAnchor.constraint(equalTo: root.leadingAnchor)])
    #expect(!box.hasAmbiguousLayout)
    // A view no constraint mentions keeps the frame it was given.
    root.layoutIfNeeded()
    #expect(framed.frame == CGRect(x: 5, y: 5, width: 5, height: 5))
}

/// 300 views in a 30 × 10 grid with 5 constraints each, as a big screen of Auto Layout: the
/// first layout and a change of one constant, timed.
@MainActor @Test func aBigScreenLaysOutQuickly() {
    let root = screen()
    var views: [UIView] = []
    var constraints: [NSLayoutConstraint] = []
    var spacing: NSLayoutConstraint?
    for row in 0 ..< 30 {
        for column in 0 ..< 10 {
            let view = make(in: root)
            let left = column == 0 ? view.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16) : view.leadingAnchor.constraint(equalTo: views.last!.trailingAnchor, constant: 8)
            if row == 15, column == 5 { spacing = left }
            let height = view.heightAnchor.constraint(equalToConstant: 44)
            height.priority = .defaultLow
            constraints += [
                left,
                row == 0 ? view.topAnchor.constraint(equalTo: root.topAnchor, constant: 16) : view.topAnchor.constraint(equalTo: views[views.count - 10].bottomAnchor, constant: 8),
                column == 0 ? view.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor) : view.widthAnchor.constraint(equalTo: views[row * 10].widthAnchor),
                height, view.heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
            ]
            views.append(view)
        }
        constraints.append(views.last!.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16))
    }
    NSLayoutConstraint.activate(constraints)
    var start = ProcessInfo.processInfo.systemUptime
    root.layoutIfNeeded()
    let first = ProcessInfo.processInfo.systemUptime - start
    #expect(abs(views[9].frame.maxX - 374) < 0.01 && abs(views[299].frame.maxY - (16 + 30 * 44 + 29 * 8)) < 0.01)
    start = ProcessInfo.processInfo.systemUptime
    spacing!.constant = 12
    root.layoutIfNeeded()
    let change = ProcessInfo.processInfo.systemUptime - start
    #expect(abs(views[155].frame.minX - (views[154].frame.maxX + 12)) < 0.01)
    print(String(format: "Auto Layout, 300 views and %d constraints: first layout %.1f ms, a constant change %.2f ms", constraints.count, first * 1000, change * 1000))
    #expect(first < 2 && change < 0.2)
}

/// Calls `completion` and remembers what it was told.
@MainActor
private final class Completion {
    var finished: Bool?
}

@MainActor @Test func layoutInAnAnimationBlockAnimatesTheFrames() async throws {
    makeScene()
    let screen = Screen()
    let box = make(in: screen.root)
    let width = box.widthAnchor.constraint(equalToConstant: 50)
    NSLayoutConstraint.activate([box.topAnchor.constraint(equalTo: screen.root.topAnchor), box.leadingAnchor.constraint(equalTo: screen.root.leadingAnchor), width, box.heightAnchor.constraint(equalToConstant: 50)])
    LayerCommit.commit()
    // As on a device: the views take the new values at once, and their layers animate to them
    // when drawn, from what showed; the frames a layoutIfNeeded() sets in the block too.
    irisAnimates = true
    let completion = Completion()
    width.constant = 100
    UIView.animate(withDuration: 0.3, delay: 0.1, options: [.curveEaseOut, .allowUserInteraction]) {
        screen.root.layoutIfNeeded()
        box.alpha = 0.5
    } completion: {
        completion.finished = $0
    }
    #expect(box.frame.width == 100 && box.alpha == 0.5)
    let timing = try #require(box.layer.irisAnimation)
    #expect(timing.duration == 0.3 && timing.delay == 0.1 && timing.curve.x2 == 0.58 && timing.repeatCount == 1)
    LayerCommit.commit()
    #expect(irisScene.isAnimating && box.layer.irisAnimation == nil)
    // Not inside performWithoutAnimation, even in an animation.
    UIView.animate(withDuration: 0.3) {
        UIView.performWithoutAnimation { box.backgroundColor = .systemRed }
    }
    #expect(box.layer.irisAnimation == nil)
    irisAnimates = false
    screen.close()
    // The completion runs once the animation is over.
    #expect(completion.finished == nil)
    try await Task.sleep(for: .milliseconds(600))
    #expect(completion.finished == true)
    // A script shows where animations end, and runs completions on the main queue's next turn.
    let scripted = Completion()
    UIView.animate(withDuration: 5, animations: { box.alpha = 1 }, completion: { scripted.finished = $0 })
    #expect(box.alpha == 1 && scripted.finished == nil)
    try await Task.sleep(for: .milliseconds(10))
    #expect(scripted.finished == true)
}

@MainActor @Test func otherPhonesHaveTheirOwnScreenAndSafeArea() {
    let phone = IrisScreen.current
    defer { IrisScreen.current = phone }
    IrisScreen.current = .iPhoneSE
    let window = UIWindow(frame: UIScreen.main.bounds)
    let controller = UIViewController()
    window.rootViewController = controller
    window.isHidden = false
    defer { window.isHidden = true }
    #expect(window.frame == CGRect(x: 0, y: 0, width: 375, height: 667))
    #expect(window.safeAreaInsets == UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0))
    #expect(controller.view.safeAreaLayoutGuide.layoutFrame == CGRect(x: 0, y: 20, width: 375, height: 647))
    // The host asks for an iPhone 14: the window fills its screen, what is in it lays out anew.
    IrisScreen.current = .iPhone14
    UIWindow.screenDidChange(from: .iPhoneSE)
    window.layoutIfNeeded()
    #expect(window.frame == CGRect(x: 0, y: 0, width: 390, height: 844))
    #expect(controller.view.frame == window.bounds)
    #expect(controller.view.safeAreaLayoutGuide.layoutFrame == CGRect(x: 0, y: 47, width: 390, height: 763))
}
