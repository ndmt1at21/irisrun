import Foundation
import IrisHost
@testable import OpenUIKit
import Testing

// Navigation and tab bar controllers: the stack, the bars and the safe area under them, and the
// appearance callbacks of pushes, pops, swipes back and tab switches in UIKit's order. As in
// AppearanceTests, transitions end at once and viewDid… come on the main queue's next turn.

/// What a navigation or tab bar controller's delegate hears, written to a journal.
@MainActor
private final class Delegates: NSObject, UINavigationControllerDelegate, UITabBarControllerDelegate {
    let journal: Journal
    var allowsSelection = true

    init(_ journal: Journal) {
        self.journal = journal
    }

    private func name(_ controller: UIViewController) -> String {
        (controller as? Logged)?.name ?? controller.tabBarItem.title ?? "?"
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        journal.entries.append("will show \(name(viewController))")
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        journal.entries.append("did show \(name(viewController))")
    }

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        journal.entries.append("should select \(name(viewController))")
        return allowsSelection
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        journal.entries.append("did select \(name(viewController))")
    }
}

/// The first view showing `label` in `view` and the views inside it, as `tap <text>` finds it.
@MainActor
private func find(_ label: String, in view: UIView) -> UIView? {
    guard !view.isHidden else { return nil }
    if view.accessibilityLabel == label { return view }
    return view.subviews.lazy.compactMap { find(label, in: $0) }.first
}

extension OnScreen {
    @Test func pushesAndPopsCallBackInUIKitsOrder() async throws {
        let journal = Journal()
        let delegates = Delegates(journal)
        let root = Logged("A", journal)
        root.title = "Danh sách"
        let navigation = UINavigationController(rootViewController: root)
        navigation.delegate = delegates
        #expect(root.parent === navigation && root.navigationController === navigation && !root.isMovingToParent)
        let window = try await show(navigation)
        defer { window.isHidden = true }
        #expect(journal.entries == ["A load", "will show A", "A willAppear", "A didAppear", "did show A"])
        navigation.view.layoutIfNeeded()
        #expect(navigation.navigationBar.frame == CGRect(x: 0, y: 47, width: 390, height: 44))
        #expect(root.view.frame == window.bounds && root.view.safeAreaInsets == UIEdgeInsets(top: 91, left: 0, bottom: 34, right: 0))

        // A push: the stack changes at once; the new view controller moves to its parent until
        // its transition is over.
        journal.entries = []
        let detail = Logged("B", journal)
        detail.title = "Mục 1"
        navigation.pushViewController(detail, animated: true)
        #expect(navigation.viewControllers == [root, detail] && navigation.topViewController === detail && navigation.visibleViewController === detail)
        #expect(journal.entries == ["B load", "will show B", "A willDisappear animated", "B willAppear animated moving"])
        try await nextTurn()
        #expect(journal.entries.suffix(3) == ["A didDisappear animated", "B didAppear animated moving", "did show B"])
        #expect(!detail.isMovingToParent && root.viewIfLoaded?.window == nil && detail.view.window === window)
        navigation.view.layoutIfNeeded()
        #expect(detail.view.safeAreaInsets.top == 91)
        let back = try #require(find("Danh sách", in: navigation.navigationBar))
        #expect(back.frame.minX == 0 && find("Mục 1", in: navigation.navigationBar) != nil)

        // The back button pops, moving the top one from its parent until it is gone.
        journal.entries = []
        (back as? UIControl)?.sendActions(for: .touchUpInside)
        #expect(navigation.viewControllers == [root])
        #expect(journal.entries == ["will show A", "B willDisappear animated moving", "A willAppear animated"])
        try await nextTurn()
        #expect(journal.entries.suffix(3) == ["B didDisappear animated moving", "A didAppear animated", "did show A"])
        #expect(detail.parent == nil && !detail.isMovingFromParent && detail.viewIfLoaded?.window == nil)

        // Deeper, then back to the root at once: the ones between go without callbacks.
        let deeper = Logged("C", journal)
        navigation.pushViewController(detail, animated: false)
        navigation.pushViewController(deeper, animated: false)
        try await nextTurn()
        journal.entries = []
        let popped = navigation.popToRootViewController(animated: true)
        #expect(popped == [detail, deeper] && navigation.popToRootViewController(animated: true) == nil)
        try await nextTurn()
        #expect(journal.entries == ["will show A", "C willDisappear animated moving", "A willAppear animated", "C didDisappear animated moving", "A didAppear animated", "did show A"])
        #expect(detail.parent == nil && deeper.parent == nil)

        // A new stack shows its top as pushed; one that drops the top shows the new top as popped.
        journal.entries = []
        navigation.setViewControllers([root, detail], animated: false)
        try await nextTurn()
        #expect(journal.entries == ["will show B", "A willDisappear", "B willAppear moving", "A didDisappear", "B didAppear moving", "did show B"])
        journal.entries = []
        navigation.setViewControllers([deeper], animated: false)
        try await nextTurn()
        #expect(journal.entries == ["will show C", "B willDisappear moving", "C willAppear moving", "B didDisappear moving", "C didAppear moving", "did show C"])
        #expect(root.parent == nil && detail.parent == nil && deeper.parent === navigation)
    }

    @Test func aSwipeFromTheLeadingEdgePopsOrIsCalledOff() async throws {
        makeScene()
        let screen = Screen()
        defer { screen.close() }
        let journal = Journal()
        let delegates = Delegates(journal)
        let root = Logged("A", journal)
        let detail = Logged("B", journal)
        let navigation = UINavigationController(rootViewController: root)
        navigation.pushViewController(detail, animated: false)
        navigation.delegate = delegates
        screen.window.rootViewController = navigation
        try await nextTurn()
        #expect(navigation.interactivePopGestureRecognizer is UIScreenEdgePanGestureRecognizer)

        // Let go early and slowly: the top view comes back, as do its callbacks; it stays a child.
        journal.entries = []
        screen.touch(.began, 5, 400, after: 1)
        screen.touch(.moved, 30, 400)
        #expect(navigation.viewControllers == [root], "the pop begins")
        #expect(journal.entries == ["A load", "will show A", "B willDisappear animated moving", "A willAppear animated"])
        #expect(abs(detail.view.layer.irisPresentationTransform.tx - 25) < 0.01 && root.view.window != nil)
        screen.touch(.moved, 80, 400)
        screen.touch(.ended, 80, 400, after: 0.5)
        #expect(navigation.viewControllers == [root, detail])
        try await nextTurn()
        #expect(journal.entries.suffix(5) == ["A willDisappear animated", "B willAppear animated moving", "A didDisappear animated", "B didAppear animated moving", "did show B"])
        #expect(detail.parent === navigation && !detail.isMovingFromParent && root.viewIfLoaded?.window == nil)
        #expect(detail.view.layer.irisPresentationTransform == .identity)

        // Past the middle, it pops.
        journal.entries = []
        screen.drag(from: CGPoint(x: 5, y: 400), to: CGPoint(x: 300, y: 400))
        try await nextTurn()
        #expect(journal.entries == ["will show A", "B willDisappear animated moving", "A willAppear animated", "B didDisappear animated moving", "A didAppear animated", "did show A"])
        #expect(navigation.viewControllers == [root] && detail.parent == nil && detail.viewIfLoaded?.window == nil)

        // Not from the edge, or at the root, nothing pops.
        navigation.pushViewController(detail, animated: false)
        try await nextTurn()
        screen.drag(from: CGPoint(x: 60, y: 400), to: CGPoint(x: 360, y: 400))
        #expect(navigation.viewControllers == [root, detail])
        navigation.popViewController(animated: false)
        try await nextTurn()
        journal.entries = []
        screen.drag(from: CGPoint(x: 5, y: 400), to: CGPoint(x: 300, y: 400))
        #expect(journal.entries.isEmpty)
    }

    @Test func tabsSwitchAndAskTheirDelegateAndBarsKeepTheSafeArea() async throws {
        makeScene()
        let screen = Screen()
        defer { screen.close() }
        let journal = Journal()
        let delegates = Delegates(journal)
        let first = Logged("A", journal)
        first.tabBarItem = UITabBarItem(title: "Một", image: UIImage(systemName: "star"), tag: 1)
        let second = Logged("B", journal)
        second.title = "Hai"
        let navigation = UINavigationController(rootViewController: second)
        let tabs = UITabBarController()
        tabs.viewControllers = [first, navigation]
        tabs.delegate = delegates
        #expect(tabs.selectedIndex == 0 && first.parent === tabs && navigation.parent === tabs && second.tabBarController === tabs)
        #expect(navigation.tabBarItem === second.tabBarItem && navigation.tabBarItem.title == "Hai", "the root's tab")
        screen.window.rootViewController = tabs
        try await nextTurn()
        #expect(journal.entries == ["A load", "A willAppear", "A didAppear"])
        tabs.view.layoutIfNeeded()
        #expect(tabs.tabBar.frame == CGRect(x: 0, y: 761, width: 390, height: 83))
        #expect(first.view.safeAreaInsets == UIEdgeInsets(top: 47, left: 0, bottom: 83, right: 0))

        // A tap on the second tab: the delegate is asked, the views switch without an animation,
        // and the delegate hears.
        journal.entries = []
        screen.tap(292, 790)
        #expect(tabs.selectedViewController === navigation && tabs.tabBar.selectedItem === second.tabBarItem)
        try await nextTurn()
        #expect(journal.entries == ["should select Hai", "B load", "A willDisappear", "B willAppear", "did select Hai", "A didDisappear", "B didAppear"])
        tabs.view.layoutIfNeeded()
        #expect(second.view.safeAreaInsets == UIEdgeInsets(top: 91, left: 0, bottom: 83, right: 0))

        // Pushed with hidesBottomBarWhenPushed, the tab bar goes and the safe area reaches the home
        // indicator; back at the root, the bar comes back.
        let hiding = Logged("C", journal)
        hiding.hidesBottomBarWhenPushed = true
        navigation.pushViewController(hiding, animated: true)
        try await nextTurn()
        tabs.view.layoutIfNeeded()
        #expect(tabs.tabBar.isHidden && hiding.view.safeAreaInsets == UIEdgeInsets(top: 91, left: 0, bottom: 34, right: 0))
        navigation.popViewController(animated: true)
        try await nextTurn()
        tabs.view.layoutIfNeeded()
        #expect(!tabs.tabBar.isHidden && second.view.safeAreaInsets.bottom == 83)

        // The selected tab tapped again pops its navigation controller to the root.
        navigation.pushViewController(Logged("D", journal), animated: false)
        try await nextTurn()
        journal.entries = []
        screen.tap(292, 790)
        try await nextTurn()
        #expect(navigation.viewControllers == [second] && journal.entries.first == "should select Hai" && journal.entries.contains("did select Hai"))

        // The delegate may keep a tab from being selected.
        delegates.allowsSelection = false
        journal.entries = []
        screen.tap(97, 790)
        #expect(tabs.selectedIndex == 1 && tabs.tabBar.selectedItem === second.tabBarItem && journal.entries == ["should select A"])
        // Programmatic selection asks no one.
        tabs.selectedIndex = 0
        try await nextTurn()
        #expect(tabs.selectedViewController === first && journal.entries.suffix(4) == ["B willDisappear", "A willAppear", "B didDisappear", "A didAppear"])
    }
}

@MainActor @Test func theBarShowsTitlesButtonsAndTheBackButtonAsIOSDoes() {
    makeScene()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let root = UIViewController()
    root.title = "Danh sách"
    let navigation = UINavigationController(rootViewController: root)
    navigation.navigationBar.prefersLargeTitles = true
    window.rootViewController = navigation
    window.isHidden = false
    defer { window.isHidden = true }
    let bar = navigation.navigationBar
    navigation.view.layoutIfNeeded()
    // A large title: the bar is 96 points high and the title 34 points, at the margin.
    #expect(bar.frame == CGRect(x: 0, y: 47, width: 390, height: 96) && root.view.safeAreaInsets.top == 143)
    let large = try! #require(find("Danh sách", in: bar))
    #expect(large.convert(large.bounds, to: bar) == CGRect(x: 16, y: 44, width: 358, height: 52))

    // A view controller that shows a small title, with buttons at the sides.
    let detail = UIViewController()
    detail.title = "Mục 1"
    detail.navigationItem.largeTitleDisplayMode = .never
    let done = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
    let add = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
    detail.navigationItem.rightBarButtonItems = [done, add]
    navigation.pushViewController(detail, animated: false)
    navigation.view.layoutIfNeeded()
    #expect(bar.frame.height == 44 && detail.view.safeAreaInsets.top == 91 && root.irisBarInsets.top == 96, "each keeps its own")
    let doneButton = try! #require(find("Done", in: bar) as? UIButton)
    let addButton = try! #require(find("Add", in: bar))
    #expect(doneButton.frame.maxX == 374 && addButton.frame.maxX == doneButton.frame.minX - 8)
    #expect(doneButton.titleLabel?.font.pointSize == 17)
    let title = try! #require(find("Mục 1", in: bar))
    #expect(abs(title.frame.midX - 195) < 0.5, "in the middle of the bar")
    let back = try! #require(find("Danh sách", in: bar))
    #expect(back.frame.minX == 0 && back.frame.maxX < title.frame.minX)

    // A title too long for the item before's: "Back"; changes to the item show at once.
    root.title = "Một tiêu đề rất dài cho màn trước"
    navigation.view.layoutIfNeeded()
    #expect(find("Back", in: bar) != nil)
    detail.navigationItem.title = "Chi tiết"
    detail.navigationItem.hidesBackButton = true
    navigation.view.layoutIfNeeded()
    #expect(find("Chi tiết", in: bar) != nil && find("Back", in: bar) == nil)

    // A hidden bar takes the safe area with it.
    navigation.setNavigationBarHidden(true, animated: false)
    navigation.view.layoutIfNeeded()
    #expect(bar.isHidden && detail.view.safeAreaInsets.top == 47)
    navigation.isNavigationBarHidden = false
    navigation.view.layoutIfNeeded()
    #expect(!bar.isHidden && detail.view.safeAreaInsets.top == 91)

    // Its background: transparent while there is no scroll view, as in iOS 15 and later; the
    // standard appearance, or the app's, while content is scrolled under it.
    let background = try! #require(bar.subviews.first)
    #expect(background.backgroundColor == nil && background.frame.minY == -47)
    let scrollView = UIScrollView(frame: detail.view.bounds)
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    detail.view.addSubview(scrollView)
    navigation.view.layoutIfNeeded()
    #expect(scrollView.contentOffset.y == -91 && scrollView.adjustedContentInset.top == 91, "the content starts under the bar")
    scrollView.contentOffset.y = 100
    navigation.view.layoutIfNeeded()
    #expect(background.backgroundColor != nil)
    let appearance = UINavigationBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = .systemIndigo
    appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
    bar.standardAppearance = appearance
    navigation.view.layoutIfNeeded()
    #expect(background.backgroundColor == .systemIndigo && (find("Chi tiết", in: bar) as? UILabel)?.textColor == .white)
}

@MainActor @Test func showingPushesInANavigationControllerAndBarButtonsSendTheirActions() async throws {
    makeScene()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let root = UIViewController()
    let navigation = UINavigationController(rootViewController: root)
    window.rootViewController = navigation
    window.isHidden = false
    defer { window.isHidden = true }
    let shown = UIViewController()
    root.show(shown, sender: nil)
    #expect(navigation.topViewController === shown && shown.presentingViewController == nil)
    // Outside one, showing presents.
    let lone = UIViewController()
    let other = UIWindow(frame: window.frame)
    other.rootViewController = lone
    other.isHidden = false
    defer { other.isHidden = true }
    let presented = UIViewController()
    lone.show(presented, sender: nil)
    #expect(lone.presentedViewController === presented)
    lone.dismiss(animated: false)

    // A primary action runs; editButtonItem turns editing on and reads Done.
    var ran = 0
    let item = UIBarButtonItem(title: "Chạy", primaryAction: UIAction { _ in ran += 1 })
    shown.navigationItem.rightBarButtonItems = [item, shown.editButtonItem]
    navigation.view.layoutIfNeeded()
    (find("Chạy", in: navigation.navigationBar) as? UIControl)?.sendActions(for: .primaryActionTriggered)
    #expect(ran == 1)
    (find("Edit", in: navigation.navigationBar) as? UIControl)?.sendActions(for: .primaryActionTriggered)
    navigation.view.layoutIfNeeded()
    #expect(shown.isEditing && shown.editButtonItem.title == "Done" && find("Done", in: navigation.navigationBar) != nil)
    try await nextTurn()
}
