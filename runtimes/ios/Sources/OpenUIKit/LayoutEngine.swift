import Foundation
import IrisHost
import IrisRender

/// Iris: Auto Layout for a view hierarchy, kept by its topmost view (the window, for views on
/// screen) as UIKit keeps an engine in the window. The active constraints of the hierarchy and
/// the ones UIKit makes for its views (autoresizing masks they translate, intrinsic content
/// sizes, the frames of the layout guides it keeps) become linear constraints of the render
/// core's Cassowary solver, which re-solves incrementally as they change. Views that no
/// constraint mentions stay out, laid out by frames. Each view in the engine gets its solved
/// frame from its superview's `layoutSubviews`.
///
/// Positions are relative, as in UIKit: a view's x and y are its frame's origin in its
/// superview (a guide's in its owning view), so a constraint between two items adds the
/// positions of the views between them and the closest view they are both in.
@MainActor
final class LayoutEngine {
    /// A view or layout guide in the engine.
    final class Item {
        weak var object: AnyObject?
        let x, y, width, height: UInt32
        /// Constraints the engine makes for it: autoresizing, or the host's size; its intrinsic
        /// content size; a guide's frame in its view.
        var resizing: [NSLayoutConstraint] = []
        var content: [NSLayoutConstraint] = []
        var guide: [NSLayoutConstraint] = []
        /// A view's frame as last solved, in its superview.
        var frame: CGRect?
        /// The width the content size was measured at, for a label that wraps at its width.
        var contentWidth: CGFloat?
        /// A guide's insets when its constraints were made.
        var insets: UIEdgeInsets?

        init(_ object: AnyObject, _ solver: LayoutSolver) {
            self.object = object
            (x, y, width, height) = (solver.makeVariable(), solver.makeVariable(), solver.makeVariable(), solver.makeVariable())
        }
    }

    unowned let host: UIView
    /// For `systemLayoutSizeFitting`: the size the host should be, and how much that counts.
    private let fitting: (size: CGSize, horizontal: UILayoutPriority, vertical: UILayoutPriority)?
    private let solver = LayoutSolver()
    private var variableCount: UInt32 = 0
    private var items: [ObjectIdentifier: Item] = [:]
    /// Every constraint in the solver, with its id there; nil for a required one that is broken
    /// because it contradicts the others.
    private var installed: [ObjectIdentifier: (constraint: NSLayoutConstraint, id: UInt64?)] = [:]
    /// The app's constraints among them.
    private var userConstraints = Set<ObjectIdentifier>()
    /// The app's constraints on baselines, which move when the text does.
    private var baselineConstraints: [NSLayoutConstraint] = []
    private var needsSync = true
    private var changedConstraints: [NSLayoutConstraint] = []
    private var changedContent = Set<ObjectIdentifier>()
    private var solverChanged = false
    private var reportedOutside = Set<ObjectIdentifier>()
    /// Pixels per point, which frames are rounded to.
    private let scale = Double(UIScreen.main.scale)

    init(host: UIView, fitting: (size: CGSize, horizontal: UILayoutPriority, vertical: UILayoutPriority)? = nil) {
        self.host = host
        self.fitting = fitting
    }

    /// The hierarchy's views, constraints or guides changed.
    func setNeedsSync() {
        needsSync = true
        LayerCommit.schedule()
    }

    func constraintDidChange(_ constraint: NSLayoutConstraint) {
        changedConstraints.append(constraint)
        LayerCommit.schedule()
    }

    /// A view's intrinsic content size or content priorities changed.
    func contentDidChange(_ view: UIView) {
        guard items[ObjectIdentifier(view)] != nil else { return }
        changedContent.insert(ObjectIdentifier(view))
        LayerCommit.schedule()
    }

    // MARK: Solving

    /// Runs the update-constraints pass, then brings the solver up to date with the hierarchy
    /// and marks the superviews of views whose frames changed as needing layout. True if the
    /// solver changed.
    @discardableResult
    func update() -> Bool {
        if needsSync {
            host.updateConstraintsIfNeeded()
        }
        solverChanged = false
        if needsSync {
            needsSync = false
            sync()
        } else {
            for (id, item) in items {
                guard let object = item.object else { continue }
                if let view = object as? UIView {
                    refreshResizing(item, of: view)
                    if changedContent.contains(id) {
                        refreshContent(item, of: view, width: item.contentWidth)
                    }
                } else if let guide = object as? UILayoutGuide, guide.kind != .placed {
                    refreshGuide(item, of: guide)
                }
            }
        }
        changedContent.removeAll()
        let changed = changedConstraints
        changedConstraints.removeAll()
        for constraint in changed where installed[ObjectIdentifier(constraint)] != nil {
            uninstall(constraint)
            install(constraint)
        }
        // Labels that wrap at their width measure their height at the width they got, so a
        // second solve gives them the height of their lines, as UIKit's two passes do.
        for _ in 0 ..< 3 where solverChanged {
            var rewrapped = false
            for item in items.values {
                guard let view = item.object as? UIView, view.irisWrapsAtLayoutWidth, !view.translatesAutoresizingMaskIntoConstraints || view === host else { continue }
                let width = solver.value(of: item.width)
                if abs(width - (item.contentWidth ?? -1)) > 0.25 {
                    refreshContent(item, of: view, width: width)
                    rewrapped = true
                }
            }
            if !rewrapped { break }
        }
        if solverChanged {
            readFrames()
        }
        return solverChanged
    }

    /// Where Auto Layout puts a view in its superview, or a guide in its view.
    func frame(of object: AnyObject) -> CGRect? {
        guard let item = items[ObjectIdentifier(object)], item.object === object else { return nil }
        if object is UIView {
            return item.frame
        }
        update()
        return rounded(item)
    }

    /// The host's size as solved: what `systemLayoutSizeFitting` returns.
    var hostSize: CGSize {
        let item = items[ObjectIdentifier(host)]!
        return rounded(item).size
    }

    /// The solved rectangle on the screen's pixels, as UIKit rounds frames.
    private func rounded(_ item: Item) -> CGRect {
        let scale = scale
        let round = { (value: Double) in CGFloat((value * scale).rounded() / scale) }
        let (x, y) = (solver.value(of: item.x), solver.value(of: item.y))
        let (width, height) = (max(0, solver.value(of: item.width)), max(0, solver.value(of: item.height)))
        let minX = round(x), minY = round(y)
        return CGRect(x: minX, y: minY, width: round(x + width) - minX, height: round(y + height) - minY)
    }

    /// Views that translate their autoresizing mask keep the frames they have, which their
    /// constraints only repeat.
    private func readFrames() {
        for item in items.values {
            guard let view = item.object as? UIView, view !== host, !view.translatesAutoresizingMaskIntoConstraints else { continue }
            let frame = rounded(item)
            if frame != item.frame {
                item.frame = frame
                view.superview?.setNeedsLayout()
            }
        }
    }

    // MARK: The hierarchy

    /// Takes in the hierarchy's constraints, and the views and guides they place with the views
    /// they are in, up to the host.
    private func sync() {
        var constraints: [NSLayoutConstraint] = []
        host.forEachInTree { constraints += $0.constraints }
        var needed: [ObjectIdentifier: AnyObject] = [:]
        var order: [AnyObject] = []
        func need(_ object: AnyObject) -> Bool {
            if needed[ObjectIdentifier(object)] != nil { return true }
            if object !== host {
                guard let container = container(of: object), need(container) else { return false }
            }
            needed[ObjectIdentifier(object)] = object
            order.append(object)
            if let guide = object as? UILayoutGuide, guide.kind == .readableContent, let view = guide.owningView {
                _ = need(view.layoutMarginsGuide)
            }
            return true
        }
        _ = need(host)
        var accepted: [NSLayoutConstraint] = []
        for constraint in constraints {
            guard let first = constraint.firstItem, need(first), constraint.secondItem.map(need) ?? true else {
                // UIKit raises an exception here; Iris leaves the constraint out.
                if reportedOutside.insert(ObjectIdentifier(constraint)).inserted, fitting == nil {
                    printError("The view hierarchy is not prepared for the constraint: \(constraint)")
                }
                continue
            }
            // Margin attributes are the margins guide's.
            for (item, attribute) in [(first, constraint.firstAttribute), (constraint.secondItem, constraint.secondAttribute)] {
                if attribute.withoutMargin != nil, let view = item as? UIView {
                    _ = need(view.layoutMarginsGuide)
                }
            }
            accepted.append(constraint)
        }
        for (id, item) in items where needed[id] == nil || item.object !== needed[id] {
            for constraint in item.resizing + item.content + item.guide {
                uninstall(constraint)
            }
            items[id] = nil
        }
        for object in order {
            let id = ObjectIdentifier(object)
            let item = items[id] ?? {
                let item = Item(object, solver)
                variableCount += 4
                items[id] = item
                return item
            }()
            if let view = object as? UIView {
                refreshResizing(item, of: view)
                refreshContent(item, of: view, width: item.contentWidth)
            } else if let guide = object as? UILayoutGuide {
                refreshGuide(item, of: guide)
            }
        }
        let current = Set(accepted.map(ObjectIdentifier.init))
        for id in userConstraints.subtracting(current) {
            if let constraint = installed[id]?.constraint {
                uninstall(constraint)
            }
        }
        userConstraints = current
        baselineConstraints = accepted.filter { $0.firstAttribute.isBaseline || $0.secondAttribute.isBaseline }
        for constraint in accepted {
            switch installed[ObjectIdentifier(constraint)] {
            case nil:
                install(constraint)
            case let (_, id)? where id == nil:
                // Broken before: the constraints it contradicted may be gone.
                uninstall(constraint)
                install(constraint, reportsConflict: false)
            default:
                break
            }
        }
    }

    /// The view an item's frame is in: a view's superview, a guide's owning view.
    private func container(of object: AnyObject) -> UIView? {
        (object as? UIView)?.superview ?? (object as? UILayoutGuide)?.owningView
    }

    // MARK: Constraints UIKit makes

    /// The host keeps its size, or in `systemLayoutSizeFitting` is asked for one; other views
    /// that translate their autoresizing mask keep their frame, and their margins and size
    /// follow the superview's size as the mask says.
    private func refreshResizing(_ item: Item, of view: UIView) {
        var constraints: [NSLayoutConstraint] = []
        if view === host {
            constraints = [NSLayoutConstraint(view, .left, constant: 0), NSLayoutConstraint(view, .top, constant: 0)]
            if let fitting {
                constraints += [
                    NSLayoutConstraint(view, .width, constant: fitting.size.width, priority: fitting.horizontal, kind: "NSLayoutConstraint"),
                    NSLayoutConstraint(view, .height, constant: fitting.size.height, priority: fitting.vertical, kind: "NSLayoutConstraint"),
                ]
            } else {
                constraints += [NSLayoutConstraint(view, .width, constant: view.bounds.width), NSLayoutConstraint(view, .height, constant: view.bounds.height)]
            }
        } else if view.translatesAutoresizingMaskIntoConstraints, let superview = view.superview {
            // The frame without the transform, as Auto Layout places views, and how its parts
            // change per point of the superview's size: autoresizing is linear in it.
            let bounds = view.bounds, center = view.center, anchor = view.layer.anchorPoint
            let frame = CGRect(x: center.x - bounds.width * anchor.x, y: center.y - bounds.height * anchor.y, width: bounds.width, height: bounds.height)
            let size = superview.bounds.size
            let grown = view.autoresizingMask.resizing(frame, from: size, to: CGSize(width: size.width + 1, height: size.height + 1))
            let parts: [(NSLayoutConstraint.Attribute, CGFloat, CGFloat, NSLayoutConstraint.Attribute)] = [
                (.left, frame.minX, grown.minX - frame.minX, .width), (.width, frame.width, grown.width - frame.width, .width),
                (.top, frame.minY, grown.minY - frame.minY, .height), (.height, frame.height, grown.height - frame.height, .height),
            ]
            constraints = parts.map { attribute, value, perPoint, axis in
                perPoint == 0
                    ? NSLayoutConstraint(view, attribute, constant: value, kind: "NSAutoresizingMaskLayoutConstraint")
                    : NSLayoutConstraint(view, attribute, .equal, superview, axis, multiplier: perPoint, constant: value - perPoint * (axis == .width ? size.width : size.height), kind: "NSAutoresizingMaskLayoutConstraint")
            }
        }
        replace(&item.resizing, with: constraints)
    }

    /// A view that doesn't translate its autoresizing mask is as big as its intrinsic content
    /// size along each axis that has one, as far as its hugging and compression resistance
    /// priorities say.
    private func refreshContent(_ item: Item, of view: UIView, width: CGFloat? = nil) {
        var constraints: [NSLayoutConstraint] = []
        if !view.translatesAutoresizingMaskIntoConstraints || view === host && fitting != nil {
            let size = view.irisContentSize(wrappingAt: view.irisWrapsAtLayoutWidth ? width : nil)
            item.contentWidth = width
            for (attribute, value, axis) in [(NSLayoutConstraint.Attribute.width, size.width, NSLayoutConstraint.Axis.horizontal), (.height, size.height, .vertical)] where value >= 0 {
                constraints += [
                    NSLayoutConstraint(view, attribute, .greaterThanOrEqual, constant: value, priority: view.contentCompressionResistancePriority(for: axis), kind: "NSContentSizeLayoutConstraint"),
                    NSLayoutConstraint(view, attribute, .lessThanOrEqual, constant: value, priority: view.contentHuggingPriority(for: axis), kind: "NSContentSizeLayoutConstraint"),
                ]
            }
        }
        replace(&item.content, with: constraints)
        // Baselines move with the text.
        for constraint in baselineConstraints where constraint.firstItem === view || constraint.secondItem === view {
            constraintDidChange(constraint)
        }
    }

    /// A guide UIKit keeps is inset in its view's bounds, as its kind says.
    private func refreshGuide(_ item: Item, of guide: UILayoutGuide) {
        guard let view = guide.owningView else { return }
        let (insets, height) = guide.insets(in: view)
        typealias Part = (NSLayoutConstraint.Attribute, NSLayoutConstraint.Relation, AnyObject?, NSLayoutConstraint.Attribute, CGFloat, UILayoutPriority)
        var parts: [Part] = []
        if let height {
            parts = [(.left, .equal, nil, .notAnAttribute, 0, .required), (.width, .equal, view, .width, 0, .required),
                     (.height, .equal, nil, .notAnAttribute, height, .required), (.bottom, .equal, view, .bottom, 0, .required)]
        } else if guide.kind == .readableContent {
            let margins = view.layoutMarginsGuide
            parts = [(.top, .equal, margins, .top, 0, .required), (.bottom, .equal, margins, .bottom, 0, .required),
                     (.centerX, .equal, margins, .centerX, 0, .required), (.width, .lessThanOrEqual, margins, .width, 0, .required),
                     (.width, .lessThanOrEqual, nil, .notAnAttribute, UILayoutGuide.readableWidth, .required),
                     (.width, .equal, margins, .width, 0, UILayoutPriority(999))]
        } else if guide.kind != .placed {
            parts = [(.left, .equal, nil, .notAnAttribute, insets.left, .required), (.top, .equal, nil, .notAnAttribute, insets.top, .required),
                     (.width, .equal, view, .width, -insets.left - insets.right, .required),
                     (.height, .equal, view, .height, -insets.top - insets.bottom, .required)]
        }
        let constraints = parts.map { attribute, relation, other, otherAttribute, constant, priority in
            let constraint = NSLayoutConstraint(guide, attribute, relation, other, otherAttribute, constant: constant, priority: priority)
            constraint.identifier = "\(guide.identifier)-\(attribute.name)"
            return constraint
        }
        replace(&item.guide, with: constraints)
        // Views hear when their safe area and margins move, as in UIKit.
        if let old = item.insets, old != insets, fitting == nil {
            switch guide.kind {
            case .safeArea:
                view.safeAreaInsetsDidChange()
                view.viewController?.viewSafeAreaInsetsDidChange()
            case .margins:
                view.layoutMarginsDidChange()
                view.viewController?.viewLayoutMarginsDidChange()
            default: break
            }
        }
        item.insets = insets
    }

    /// Puts `constraints` in place of `old` unless they are the same.
    private func replace(_ old: inout [NSLayoutConstraint], with constraints: [NSLayoutConstraint]) {
        guard old.count != constraints.count || zip(old, constraints).contains(where: { !$0.irisSame(as: $1) }) else { return }
        for constraint in old {
            uninstall(constraint)
        }
        old = constraints
        for constraint in constraints {
            install(constraint)
        }
    }

    // MARK: The solver

    private func install(_ constraint: NSLayoutConstraint, reportsConflict: Bool = true) {
        if fitting == nil {
            constraint.irisEngine = self
        }
        solverChanged = true
        guard let (terms, constant) = linear(constraint) else {
            installed[ObjectIdentifier(constraint)] = (constraint, nil)
            return
        }
        let id = solver.add(terms, constant: constant, relation: relation(constraint), strength: strength(constraint.priority))
        installed[ObjectIdentifier(constraint)] = (constraint, id)
        if id == nil, reportsConflict, fitting == nil {
            reportConflict(breaking: constraint)
        }
    }

    private func uninstall(_ constraint: NSLayoutConstraint) {
        guard let entry = installed.removeValue(forKey: ObjectIdentifier(constraint)) else { return }
        if let id = entry.id {
            solver.remove(id)
        }
        if constraint.irisEngine === self {
            constraint.irisEngine = nil
        }
        solverChanged = true
    }

    private func relation(_ constraint: NSLayoutConstraint) -> LayoutSolver.Relation {
        switch constraint.relation {
        case .lessThanOrEqual: .lessThanOrEqual
        case .equal: .equal
        case .greaterThanOrEqual: .greaterThanOrEqual
        }
    }

    /// Priorities weigh exponentially, 10 times more every 167: a wish beats any few wishes of
    /// much lower priority, as UIKit meets higher priorities first.
    // ponytail: UIKit's engine is lexicographic, so a priority beats any number of lower ones;
    // here 1,000 wishes at 250 outweigh one at 750. A solver with a level per priority if apps
    // run into it.
    private func strength(_ priority: UILayoutPriority) -> Double {
        priority >= .required ? LayoutSolver.required : pow(10, 6 * Double(max(priority.rawValue, 1)) / 1000)
    }

    /// The constraint as `terms + constant <relation> 0`: first − multiplier × second − constant.
    private func linear(_ constraint: NSLayoutConstraint) -> ([(variable: UInt32, coefficient: Double)], Double)? {
        guard let first = constraint.firstItem else { return nil }
        let second = constraint.secondItem
        var space: UIView?
        if let second, constraint.firstAttribute.kind != .dimension || constraint.secondAttribute.kind != .dimension {
            guard let common = commonView(first, second) else { return nil }
            space = common
        }
        var terms: [(variable: UInt32, coefficient: Double)] = []
        var constant = -Double(constraint.constant)
        guard add(first, constraint.firstAttribute, 1, in: space, &terms, &constant) else { return nil }
        if let second {
            guard add(second, constraint.secondAttribute, -Double(constraint.multiplier), in: space, &terms, &constant) else { return nil }
        }
        return (terms, constant)
    }

    /// Adds `coefficient` × the attribute of `object` in the coordinates of `space` (the
    /// object's container for nil): its position plus those of the views between, or 0 for a
    /// view in its own coordinates.
    private func add(
        _ object: AnyObject, _ attribute: NSLayoutConstraint.Attribute, _ coefficient: Double, in space: UIView?,
        _ terms: inout [(variable: UInt32, coefficient: Double)], _ constant: inout Double
    ) -> Bool {
        if let plain = attribute.withoutMargin, let view = object as? UIView {
            return add(view.layoutMarginsGuide, plain, coefficient, in: space, &terms, &constant)
        }
        guard let item = items[ObjectIdentifier(object)], item.object === object else { return false }
        let horizontal = attribute.kind == .horizontal
        // How far along the size the attribute is, plus a constant: a baseline's offset.
        let (fraction, offset): (Double, Double)
        switch attribute {
        case .width, .height:
            terms.append((attribute == .width ? item.width : item.height, coefficient))
            return true
        case .left, .leading, .top: (fraction, offset) = (0, 0)
        case .right, .trailing, .bottom: (fraction, offset) = (1, 0)
        case .firstBaseline, .lastBaseline:
            let baselines = (object as? UIView)?.irisBaselineOffsets
            (fraction, offset) = baselines.map { (0.5, Double(attribute == .firstBaseline ? $0.first : $0.last)) } ?? (1, 0)
        default: (fraction, offset) = (0.5, 0)
        }
        // The solver adds up the coefficients of a variable that comes twice.
        terms.append((horizontal ? item.width : item.height, coefficient * fraction))
        constant += coefficient * offset
        guard object !== space else { return true }
        terms.append((horizontal ? item.x : item.y, coefficient))
        guard let space else { return true }
        var view = container(of: object)
        while let current = view, current !== space {
            guard let ancestor = items[ObjectIdentifier(current)] else { return false }
            terms.append((horizontal ? ancestor.x : ancestor.y, coefficient))
            view = current.superview
        }
        return view != nil
    }

    // MARK: Conflicts

    /// Logs what UIKit logs for a required constraint that contradicts others, which it breaks:
    /// the smallest set of required constraints that contradict one another.
    private func reportConflict(breaking broken: NSLayoutConstraint) {
        let candidates = installed.values.filter { $0.id != nil && $0.constraint.priority == .required }.map(\.constraint)
            .sorted { $0.irisOrder < $1.irisOrder }
        // Adding constraints one by one to a fresh solver, the one that makes it fail is in the
        // conflict; start again with what was before it until the conflict alone fails.
        var conflict: [NSLayoutConstraint] = []
        var rest = candidates
        while true {
            let scratch = LayoutSolver()
            for _ in 0 ..< variableCount {
                _ = scratch.makeVariable()
            }
            let fits = { (constraint: NSLayoutConstraint) -> Bool in
                guard let (terms, constant) = self.linear(constraint) else { return true }
                return scratch.add(terms, constant: constant, relation: self.relation(constraint), strength: LayoutSolver.required) != nil
            }
            guard conflict.allSatisfy(fits), fits(broken), let index = rest.firstIndex(where: { !fits($0) }) else { break }
            conflict.append(rest[index])
            rest = Array(rest[..<index])
        }
        let listed = (conflict + [broken]).sorted { $0.irisOrder < $1.irisOrder }
        var message = """
            [LayoutConstraints] Unable to simultaneously satisfy constraints.
            \tProbably at least one of the constraints in the following list is one you don't want.
            \tTry this:
            \t\t(1) look at each constraint and try to figure out which you don't expect;
            \t\t(2) find the code that added the unwanted constraint or constraints and fix it.

            """
        if listed.contains(where: { $0.irisKind == "NSAutoresizingMaskLayoutConstraint" }) {
            message += "\t(Note: If you're seeing NSAutoresizingMaskLayoutConstraints that you don't understand, refer to the documentation for the UIView property translatesAutoresizingMaskIntoConstraints) \n"
        }
        message += "(\n" + listed.map { "    \"\($0)\"" }.joined(separator: ",\n") + "\n)\n\n"
        message += "Will attempt to recover by breaking constraint \n\(broken)\n\n"
        message += "Make a symbolic breakpoint at UIViewAlertForUnsatisfiableConstraints to catch this in the debugger.\n"
        message += "The methods in the UIConstraintBasedLayoutDebugging category on UIView listed in <UIKitCore/UIView.h> may also be helpful."
        LayoutEngine.log(message)
    }

    /// Where the engine reports what UIKit logs; tests listen here.
    static var log: (String) -> Void = { printError($0) }

    // MARK: Ambiguity

    /// Whether some other frame of the view meets its constraints as well: nudging one of its
    /// variables with a wish weaker than any priority moves it.
    func alternativeFrame(of view: UIView) -> CGRect? {
        update()
        guard let item = items[ObjectIdentifier(view)], item.object === view else { return nil }
        for variable in [item.x, item.y, item.width, item.height] {
            let value = solver.value(of: variable)
            for push in [100.0, -100.0] {
                guard let nudge = solver.add([(variable, 1)], constant: -(value + push), relation: .equal, strength: 1e-6) else { continue }
                let moved = solver.value(of: variable)
                let frame = rounded(item)
                solver.remove(nudge)
                if abs(moved - value) > 0.5 { return frame }
            }
        }
        return nil
    }
}

extension NSLayoutConstraint {
    /// Whether it says the same as `other`.
    func irisSame(as other: NSLayoutConstraint) -> Bool {
        firstItem === other.firstItem && firstAttribute == other.firstAttribute && relation == other.relation
            && secondItem === other.secondItem && secondAttribute == other.secondAttribute
            && multiplier == other.multiplier && constant == other.constant && priority == other.priority
    }
}

extension NSLayoutConstraint.Attribute {
    var isBaseline: Bool {
        self == .firstBaseline || self == .lastBaseline
    }
}

extension UIView.AutoresizingMask {
    /// How UIKit's descriptions of autoresizing constraints write the mask, per axis: the
    /// leading margin, the size and the trailing margin, `&` where flexible and `-` where fixed.
    var irisNotation: String {
        let flag = { (option: Self) in self.contains(option) ? "&" : "-" }
        return "h=\(flag(.flexibleLeftMargin))\(flag(.flexibleWidth))\(flag(.flexibleRightMargin)) v=\(flag(.flexibleTopMargin))\(flag(.flexibleHeight))\(flag(.flexibleBottomMargin))"
    }
}

extension UIView {
    /// Lays out with Auto Layout: the update-constraints pass and a solve of the hierarchy's
    /// engine, then `layout`; again while laying out moved what the engine depends on (a guide's
    /// insets, as its view moved), a few times at most, as UIKit repeats its passes.
    func irisLayout(_ layout: () -> Void) {
        guard let engine = irisRootView.layoutEngine else { return layout() }
        for _ in 0 ..< 4 {
            let changed = engine.update()
            layout()
            if !changed { return }
        }
    }
}

extension UIFont {
    /// Where a line's baseline is from the middle of the line, for text centered in a view.
    var irisCenteredBaseline: CGFloat {
        ascender - lineHeight / 2
    }
}
