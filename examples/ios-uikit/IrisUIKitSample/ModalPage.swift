import SwiftUI
import UIKit

/// The appearance callbacks the Modal page's view controllers heard since its last button, in
/// order, with what UIKit said about them, shown on the page and on what it presents so that a
/// run can check them.
@MainActor
enum ModalLog {
    private(set) static var text = ""
    private static var labels: [WeakLabel] = []

    private struct WeakLabel {
        weak var label: UILabel?
    }

    static func record(_ entry: String) {
        text = text.isEmpty ? entry : text + " → " + entry
        refresh()
    }

    /// A callback of `controller`, by its title: being presented or dismissed, or moving to or
    /// from its parent.
    static func record(_ controller: UIViewController, _ callback: String) {
        var entry = "\(controller.title ?? "?") \(callback)"
        if controller.isBeingPresented { entry += " presented" }
        if controller.isBeingDismissed { entry += " dismissed" }
        if controller.isMovingToParent || controller.isMovingFromParent { entry += " moving" }
        record(entry)
    }

    static func reset() {
        text = ""
        refresh()
    }

    static func show(in label: UILabel) {
        labels.append(WeakLabel(label: label))
        label.text = text
    }

    private static func refresh() {
        labels.removeAll { $0.label == nil }
        for weak in labels {
            weak.label?.text = text
        }
    }
}

/// A page that presents view controllers in UIKit's styles and logs the appearance callbacks
/// they hear: a page sheet, which leaves the screen under it and which a drag down dismisses
/// unless it may not go; a full-screen cover, which the screen under it disappears for, and a sheet
/// over it that one dismiss takes away with it; an overlay that fades in; and a child view
/// controller that comes and goes. The SwiftUI card on it is in a hosting controller that is not
/// the window's root: its sheet, alert, dialog and cover come over the whole window, through UIKit.
class ModalPage: UIView {
    private(set) lazy var card = UIHostingController(rootView: PresentingCard())
    private let log = UILabel(frame: CGRect(x: 16, y: 12, width: 288, height: 66))
    private let child = ChildCard()
    private let childButton = UIButton(configuration: .gray())

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        log.font = .preferredFont(forTextStyle: .footnote)
        log.numberOfLines = 0
        log.autoresizingMask = [.flexibleWidth]
        ModalLog.show(in: log)
        addSubview(log)
        let buttons: [(String, Selector)] = [
            ("Thẻ", #selector(presentSheet)), ("Toàn màn hình", #selector(presentCover)),
            ("Phủ mờ dần", #selector(presentOverlay)), ("Thêm con", #selector(toggleChild)),
        ]
        for (index, (title, action)) in buttons.enumerated() {
            let button = index == 3 ? childButton : UIButton(configuration: .gray())
            button.configuration?.title = title
            button.frame = CGRect(x: index % 2 == 0 ? 16 : 164, y: 86 + CGFloat(index / 2) * 44, width: 140, height: 36)
            button.autoresizingMask = index % 2 == 0 ? [.flexibleWidth, .flexibleRightMargin] : [.flexibleWidth, .flexibleLeftMargin]
            button.addTarget(self, action: action, for: .touchUpInside)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The view controller whose view the page is in, which presents.
    private var controller: UIViewController? {
        sequence(first: self as UIResponder) { $0.next }.first { $0 is UIViewController } as? UIViewController
    }

    /// The SwiftUI card under the buttons, as tall as SwiftUI says it needs at the page's width.
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width - 32
        card.view.frame = CGRect(x: 16, y: 182, width: width, height: card.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        child.viewIfLoaded?.frame = CGRect(x: 16, y: card.view.frame.maxY + 12, width: width, height: 36)
    }

    private func present(_ screen: ModalScreen) {
        ModalLog.reset()
        controller?.present(screen, animated: true) {
            ModalLog.record("presented")
        }
    }

    @objc private func presentSheet() {
        present(ModalScreen(title: "Sheet", style: .automatic))
    }

    @objc private func presentCover() {
        present(ModalScreen(title: "Cover", style: .fullScreen))
    }

    @objc private func presentOverlay() {
        present(ModalScreen(title: "Overlay", style: .overFullScreen, transition: .crossDissolve))
    }

    /// A child view controller joins the screen's, its view the page, and leaves again.
    @objc private func toggleChild() {
        guard let controller else { return }
        ModalLog.reset()
        if child.parent == nil {
            controller.addChild(child)
            addSubview(child.view)
            setNeedsLayout()
            child.didMove(toParent: controller)
        } else {
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }
        childButton.configuration?.title = child.parent == nil ? "Thêm con" : "Bỏ con"
    }
}

/// A presented view controller: its title, the log, its safe area, and buttons to dismiss it,
/// to keep a drag from dismissing it, to present a sheet over it, or to dismiss everything from
/// the screen under them all. It logs its appearance callbacks, and what its presentation
/// controller tells its delegate.
class ModalScreen: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let panel = UIView()
    private let name = UILabel()
    private let log = UILabel()
    private let safeArea = UILabel()
    private var buttons: [UIButton] = []

    init(title: String, style: UIModalPresentationStyle, transition: UIModalTransitionStyle = .coverVertical) {
        super.init(nibName: nil, bundle: nil)
        self.title = title
        modalPresentationStyle = style
        modalTransitionStyle = transition
        presentationController?.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // The overlay lets the screen under it show through, around a panel.
        if modalPresentationStyle == .overFullScreen {
            view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            panel.backgroundColor = .systemBackground
            panel.layer.cornerRadius = 14
            view.addSubview(panel)
        } else {
            view.backgroundColor = .systemBackground
        }
        view.accessibilityLabel = title
        name.text = title
        name.font = .boldSystemFont(ofSize: 22)
        log.font = .preferredFont(forTextStyle: .footnote)
        log.numberOfLines = 0
        ModalLog.show(in: log)
        safeArea.font = .preferredFont(forTextStyle: .footnote)
        safeArea.textColor = .secondaryLabel
        for label in [name, log, safeArea] {
            view.addSubview(label)
        }
        var actions: [(String, Selector)] = [("Đóng", #selector(close))]
        switch title {
        case "Sheet": actions.append(("Chặn kéo: tắt", #selector(toggleModal(_:))))
        case "Cover": actions.append(("Thẻ lồng", #selector(presentNested)))
        case "Nested": actions.append(("Đóng tất cả", #selector(closeAll)))
        default: break
        }
        for (title, action) in actions {
            let button = UIButton(configuration: .filled())
            button.configuration?.title = title
            button.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(button)
            buttons.append(button)
        }
    }

    /// From the top of the safe area down: the title, the log, the safe area, the buttons.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let insets = view.safeAreaInsets
        let width = view.bounds.width - 32
        safeArea.text = "Safe area: \(Int(insets.top)), \(Int(insets.bottom))"
        let frames = [(name, 28.0), (log, 66.0), (safeArea, 20.0)]
        var y = insets.top + 20
        for (label, height) in frames {
            label.frame = CGRect(x: 16, y: y, width: width, height: height)
            y += height + 8
        }
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(x: 16 + CGFloat(index) * (width + 12) / 2, y: y, width: (width - 12) / 2, height: 36)
        }
        panel.frame = CGRect(x: 8, y: insets.top + 8, width: view.bounds.width - 16, height: y + 48 - insets.top - 8)
    }

    @objc private func close() {
        ModalLog.reset()
        dismiss(animated: true) {
            ModalLog.record("dismissed")
        }
    }

    @objc private func toggleModal(_ sender: UIButton) {
        isModalInPresentation.toggle()
        sender.configuration?.title = isModalInPresentation ? "Chặn kéo: bật" : "Chặn kéo: tắt"
    }

    @objc private func presentNested() {
        ModalLog.reset()
        present(ModalScreen(title: "Nested", style: .pageSheet), animated: true) {
            ModalLog.record("presented")
        }
    }

    /// The screen under them all dismisses what it presented, and what that presented.
    @objc private func closeAll() {
        ModalLog.reset()
        view.window?.rootViewController?.dismiss(animated: true) {
            ModalLog.record("dismissed")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ModalLog.record(self, "willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ModalLog.record(self, "didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ModalLog.record(self, "willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ModalLog.record(self, "didDisappear")
    }

    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        ModalLog.record("will dismiss")
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        ModalLog.record("did dismiss")
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        ModalLog.record("attempt")
    }
}

/// A child view controller: a bar on the page that logs its appearance callbacks.
class ChildCard: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Child"
        view.backgroundColor = .systemMint
        view.layer.cornerRadius = 8
        view.accessibilityLabel = "Child card"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ModalLog.record(self, "willAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ModalLog.record(self, "didAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ModalLog.record(self, "willDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ModalLog.record(self, "didDisappear")
    }
}

/// SwiftUI's part: a sheet, an alert, a confirmation dialog and a full-screen cover, which cover
/// the whole window as on iOS, though the card is only part of the page; it says what happened.
struct PresentingCard: View {
    @State private var showsSheet = false
    @State private var showsAlert = false
    @State private var showsDialog = false
    @State private var showsCover = false
    @State private var status = "SwiftUI: chưa trình bày gì"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(status)
                .font(.footnote)
            HStack {
                Button("Sheet SwiftUI") { showsSheet = true }
                Button("Alert SwiftUI") { showsAlert = true }
            }
            HStack {
                Button("Hộp thoại SwiftUI") { showsDialog = true }
                Button("Phủ SwiftUI") { showsCover = true }
            }
        }
        .buttonStyle(.bordered)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showsSheet, onDismiss: { status = "SwiftUI: sheet đã đóng" }) {
            VStack(spacing: 12) {
                Text("Sheet từ SwiftUI")
                    .font(.headline)
                Button("Đóng sheet") { showsSheet = false }
            }
        }
        .alert("Cảnh báo từ SwiftUI", isPresented: $showsAlert) {
            Button("OK") { status = "SwiftUI: alert OK" }
        }
        .confirmationDialog("Xoá ghi chú?", isPresented: $showsDialog, titleVisibility: .visible) {
            Button("Xoá", role: .destructive) { status = "SwiftUI: đã xoá" }
        }
        .fullScreenCover(isPresented: $showsCover, onDismiss: { status = "SwiftUI: phủ đã đóng" }) {
            VStack(spacing: 12) {
                Text("Phủ từ SwiftUI")
                    .font(.headline)
                Button("Đóng phủ") { showsCover = false }
            }
        }
    }
}
