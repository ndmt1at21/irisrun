import Foundation
@testable import OpenUIKit
import Testing

// UIStackView as UIKit lays it out: the frames below are the ones UIKit gives the same
// arrangement, worked out from its documented rules and the constraints it makes.

/// A view with an intrinsic content size, as an image view has.
@MainActor
private final class Sized: UIView {
    var size: CGSize {
        didSet { invalidateIntrinsicContentSize() }
    }

    init(_ width: CGFloat, _ height: CGFloat) {
        size = CGSize(width: width, height: height)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        size
    }
}

/// A stack view of `views` in a screen-sized root, its top left corner at `origin`, and as wide
/// as `width` if given.
@MainActor
private func makeStack(_ views: [UIView], at origin: CGPoint = .zero, width: CGFloat? = nil) -> (root: UIView, stack: UIStackView) {
    let root = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let stack = UIStackView(arrangedSubviews: views)
    stack.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: origin.x),
        stack.topAnchor.constraint(equalTo: root.topAnchor, constant: origin.y),
    ])
    if let width {
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
    }
    return (root, stack)
}

@MainActor @Test func stackViewsFillTheirLengthAndCloseUpOverHiddenViews() {
    let views = [Sized(30, 30), Sized(40, 40), Sized(50, 50)]
    let (root, stack) = makeStack(views, at: CGPoint(x: 20, y: 100), width: 350)
    stack.distribution = .fillEqually
    stack.spacing = 10
    root.layoutIfNeeded()
    // As high as the highest view wishes: compression resistance beats hugging.
    #expect(stack.frame == CGRect(x: 20, y: 100, width: 350, height: 50))
    #expect(views.map(\.frame) == [
        CGRect(x: 0, y: 0, width: 110, height: 50), CGRect(x: 120, y: 0, width: 110, height: 50), CGRect(x: 240, y: 0, width: 110, height: 50),
    ])
    #expect(views.allSatisfy { !$0.translatesAutoresizingMaskIntoConstraints && $0.superview === stack })
    // A hidden view takes no room and no spacing.
    views[1].isHidden = true
    root.layoutIfNeeded()
    #expect(views[0].frame == CGRect(x: 0, y: 0, width: 170, height: 50))
    #expect(views[2].frame == CGRect(x: 180, y: 0, width: 170, height: 50))
    #expect(views[1].frame.width == 0)
    #expect(Set(stack.constraints.compactMap(\.identifier)) == ["UISV-canvas-connection", "UISV-spacing", "UISV-fill-equally", "UISV-hiding", "UISV-alignment"])
    views[1].isHidden = false
    root.layoutIfNeeded()
    #expect(views[1].frame == CGRect(x: 120, y: 0, width: 110, height: 50))
    // Filling, the view that hugs its content least stretches; the others keep their size.
    stack.distribution = .fill
    views[0].setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
    views[2].setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
    root.layoutIfNeeded()
    #expect(views.map(\.frame.minX) == [0, 40, 300] && views.map(\.frame.width) == [30, 250, 50])
    // A stack view placed by its frame keeps it.
    let framed = UIStackView(frame: CGRect(x: 10, y: 600, width: 300, height: 40))
    root.addSubview(framed)
    let left = Sized(10, 10), right = Sized(10, 10)
    framed.addArrangedSubview(left)
    framed.addArrangedSubview(right)
    framed.distribution = .fillEqually
    root.layoutIfNeeded()
    #expect(framed.frame == CGRect(x: 10, y: 600, width: 300, height: 40))
    #expect(left.frame == CGRect(x: 0, y: 0, width: 150, height: 40) && right.frame == CGRect(x: 150, y: 0, width: 150, height: 40))
    // On its own, as SwiftUI measures the view of a representable: its views and the spacing.
    let alone = UIStackView(arrangedSubviews: [Sized(30, 20), Sized(40, 25)])
    alone.spacing = 10
    #expect(!alone.constraints.isEmpty)
    #expect(alone.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize) == CGSize(width: 80, height: 25))
}

@MainActor @Test func stackViewsLineUpTheirViewsAcrossTheAxis() {
    let wide = Sized(100, 20), narrow = Sized(60, 30)
    let (root, stack) = makeStack([wide, narrow], at: CGPoint(x: 10, y: 50))
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 8
    root.layoutIfNeeded()
    // As small as its views let it: as wide as the widest, as high as all with the spacing.
    #expect(stack.frame == CGRect(x: 10, y: 50, width: 100, height: 58))
    #expect(wide.frame == CGRect(x: 0, y: 0, width: 100, height: 20))
    #expect(narrow.frame == CGRect(x: 20, y: 28, width: 60, height: 30))
    #expect(stack.layoutGuides.map(\.identifier) == ["UISV-alignment-spanner"])
    stack.alignment = .trailing
    root.layoutIfNeeded()
    #expect(narrow.frame.minX == 40)
    stack.alignment = .leading
    root.layoutIfNeeded()
    #expect(narrow.frame.minX == 0 && stack.frame.width == 100)
    // Wider than its views, by a constraint of the app's.
    stack.widthAnchor.constraint(equalToConstant: 200).isActive = true
    stack.alignment = .center
    root.layoutIfNeeded()
    #expect(wide.frame.minX == 50 && narrow.frame.minX == 70)
    stack.alignment = .fill
    root.layoutIfNeeded()
    #expect(wide.frame.width == 200 && narrow.frame.width == 200 && stack.layoutGuides.isEmpty)
    // Spacing of its own after one view; the system's standard spacing.
    stack.setCustomSpacing(20, after: wide)
    root.layoutIfNeeded()
    #expect(narrow.frame.minY == 40 && stack.customSpacing(after: wide) == 20)
    #expect(stack.customSpacing(after: narrow) == UIStackView.spacingUseDefault)
    stack.setCustomSpacing(UIStackView.spacingUseDefault, after: wide)
    stack.spacing = UIStackView.spacingUseSystem
    root.layoutIfNeeded()
    #expect(narrow.frame.minY == 28)
}

@MainActor @Test func stackViewsDistributeTheRoomLeft() {
    // Equal spacing: what is left of 320 points shared between neighbours.
    let spaced = [Sized(40, 20), Sized(80, 20), Sized(20, 20)]
    let (root, stack) = makeStack(spaced)
    let width = stack.widthAnchor.constraint(equalToConstant: 320)
    width.isActive = true
    stack.distribution = .equalSpacing
    stack.spacing = 10
    root.layoutIfNeeded()
    #expect(spaced.map(\.frame.minX) == [0, 130, 300] && spaced.map(\.frame.width) == [40, 80, 20])
    #expect(stack.layoutGuides.map(\.identifier) == ["UISV-distributing", "UISV-distributing"])
    // Equal centering: centers as far apart as each other.
    stack.distribution = .equalCentering
    root.layoutIfNeeded()
    #expect(spaced.map(\.frame.minX) == [0, 125, 300])
    // Without a width, as short as the spacing lets it.
    stack.distribution = .equalSpacing
    width.isActive = false
    root.layoutIfNeeded()
    #expect(stack.frame.width == 160 && spaced.map(\.frame.minX) == [0, 50, 140])
    // Proportionally: each its intrinsic width's share; it changes with the intrinsic width.
    let shared = [Sized(100, 20), Sized(50, 20)]
    let (proportionalRoot, proportional) = makeStack(shared, width: 300)
    proportional.distribution = .fillProportionally
    proportionalRoot.layoutIfNeeded()
    #expect(shared.map(\.frame.width) == [200, 100] && shared[1].frame.minX == 200)
    shared[1].size.width = 100
    proportionalRoot.layoutIfNeeded()
    #expect(shared.map(\.frame.width) == [150, 150])
    #expect(proportional.constraints.contains { $0.identifier == "UISV-fill-proportionally" && $0.multiplier == 0.5 })
}

@MainActor @Test func stackViewsArrangeInTheirMarginsAndKeepTheirSubviews() {
    var logged: [String] = []
    let log = LayoutEngine.log
    LayoutEngine.log = { logged.append($0) }
    defer { LayoutEngine.log = log }
    let top = Sized(10, 30), fixed = UIView(), bottom = Sized(10, 40)
    let (root, stack) = makeStack([top, fixed, bottom], width: 200)
    stack.axis = .vertical
    stack.spacing = 6
    stack.isLayoutMarginsRelativeArrangement = true
    stack.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 14, right: 16)
    fixed.heightAnchor.constraint(equalToConstant: 44).isActive = true
    root.layoutIfNeeded()
    #expect(top.frame == CGRect(x: 12, y: 10, width: 172, height: 30))
    #expect(fixed.frame == CGRect(x: 12, y: 46, width: 172, height: 44))
    #expect(bottom.frame == CGRect(x: 12, y: 96, width: 172, height: 40))
    #expect(stack.frame.height == 150 && logged.isEmpty)
    // Hiding a view that must be 44 high contradicts 'UISV-hiding', which UIKit logs too; the
    // views around close up all the same.
    fixed.isHidden = true
    root.layoutIfNeeded()
    #expect(bottom.frame.minY == 46 && stack.frame.height == 100)
    #expect(logged.count == 1 && logged.first?.contains("'UISV-hiding'") == true)
    // Out of the arrangement, a view stays a subview; out of the stack view, it leaves the
    // arrangement.
    stack.removeArrangedSubview(top)
    #expect(stack.arrangedSubviews == [fixed, bottom] && top.superview === stack)
    bottom.removeFromSuperview()
    #expect(stack.arrangedSubviews == [fixed])
    stack.insertArrangedSubview(bottom, at: 0)
    stack.insertArrangedSubview(fixed, at: 0)
    #expect(stack.arrangedSubviews == [fixed, bottom] && bottom.superview === stack)
}

@MainActor @Test func stackViewsLineUpBaselines() throws {
    makeScene()
    let small = UILabel(), big = UILabel()
    small.text = "small"
    big.text = "Big"
    big.font = .systemFont(ofSize: 34)
    let (root, row) = makeStack([small, big], at: CGPoint(x: 0, y: 100))
    row.alignment = .firstBaseline
    row.spacing = 8
    let first = UILabel(), second = UILabel()
    first.text = "First"
    second.text = "Second"
    let column = UIStackView(arrangedSubviews: [first, second])
    column.axis = .vertical
    column.isBaselineRelativeArrangement = true
    column.spacing = 30
    column.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(column)
    NSLayoutConstraint.activate([column.topAnchor.constraint(equalTo: root.topAnchor, constant: 300), column.leadingAnchor.constraint(equalTo: root.leadingAnchor)])
    root.layoutIfNeeded()
    let (smallOffset, bigOffset) = (try #require(small.irisBaselineOffsets), try #require(big.irisBaselineOffsets))
    let (firstOffset, secondOffset) = (try #require(first.irisBaselineOffsets), try #require(second.irisBaselineOffsets))
    // The row spans both; the bigger text sits at its top.
    #expect(abs(small.frame.midY + smallOffset.first - big.frame.midY - bigOffset.first) < 0.5)
    #expect(big.frame.minY == 0 && small.frame.minY > 0 && row.frame.height == big.frame.height)
    #expect(small.frame.minX == 0 && big.frame.minX == small.frame.width + 8)
    // The column's spacing goes from baseline to baseline.
    #expect(abs(second.frame.midY + secondOffset.first - first.frame.midY - firstOffset.last - 30) < 0.5)
}
