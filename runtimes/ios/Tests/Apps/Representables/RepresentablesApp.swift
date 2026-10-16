import SwiftUI
import UIKit

// What SwiftUI does with UIKit views and view controllers it embeds, shown as text for
// session.txt to check: when it makes, updates and dismantles them, how it sizes them, which
// side a touch goes to, and the view controller's parent. A folder without an Xcode project,
// so it also runs by the Info.plist irisrun-ios-build makes for such apps.

@main
struct RepresentablesApp: App {
    var body: some Scene {
        WindowGroup {
            Checks()
        }
    }
}

/// What the representables report, outside SwiftUI's state so that writing to it while SwiftUI
/// updates them changes nothing on screen until asked.
final class Journal {
    static let shared = Journal()
    var entries: [String] = []
}

struct Checks: View {
    @State private var value = 0
    @State private var other = 0
    @State private var shows = true
    @State private var journal = ""
    @State private var sizes: [String: CGSize] = [:]
    @State private var swiftUITaps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Tăng") { value += 1 }
                Button("Khác") { other += 1 }
                Button(shows ? "Ẩn" : "Hiện") { shows.toggle() }
                Button("Nhật ký") { journal = Journal.shared.entries.joined(separator: " ") }
            }
            // Sizes SwiftUI gives UIKit views by their intrinsic size, priorities and
            // sizeThatFits.
            Fixed(width: 51, height: 31)
                .fixedSize()
                .reportSize("cố định", into: $sizes)
            Fixed(width: 51, height: 31, hugs: true)
                .reportSize("ôm", into: $sizes)
                .frame(width: 300, height: 60)
            Fixed(width: 51, height: 31)
                .reportSize("giãn", into: $sizes)
                .frame(width: 300, height: 60)
            Fixed(width: 200, height: 20, hugs: true)
                .reportSize("không nén", into: $sizes)
                .frame(width: 100)
            Fixed(width: 200, height: 20, hugs: true, resists: false)
                .reportSize("nén", into: $sizes)
                .frame(width: 100)
            Fitting()
                .reportSize("sizeThatFits", into: $sizes)
            Growing()
                .fixedSize()
                .reportSize("lớn dần", into: $sizes)
            Text(sizes.keys.sorted().map { "\($0) \(Int(sizes[$0]!.width))x\(Int(sizes[$0]!.height))" }.joined(separator: ", "))
            // A UIKit button under SwiftUI content: the touch goes to what is in front, and
            // through what does not take touches.
            ZStack(alignment: .leading) {
                TapCounter()
                Color.blue.opacity(0.3)
                    .frame(width: 100)
                    .onTapGesture { swiftUITaps += 1 }
                Color.green.opacity(0.3)
                    .frame(width: 100)
                    .offset(x: 250)
                    .allowsHitTesting(false)
            }
            .frame(height: 44)
            Text("SwiftUI chạm: \(swiftUITaps)")
            // Made, updated as its input changes, and dismantled once it goes.
            if shows {
                Probe(value: value)
                    .fixedSize()
                Parented()
                    .frame(width: 10, height: 10)
            }
            Text("Khác: \(other)")
            Text("Nhật ký: \(journal)")
            // Laid out by constraints inside.
            Pinned()
                .fixedSize()
                .reportSize("ràng buộc", into: $sizes)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension View {
    func reportSize(_ name: String, into sizes: Binding<[String: CGSize]>) -> some View {
        onGeometryChange(for: CGSize.self) { $0.size } action: { sizes.wrappedValue[name] = $0 }
    }
}

/// Logs its lifecycle.
struct Probe: UIViewRepresentable {
    var value: Int

    final class Coordinator {
        init() {
            Journal.shared.entries.append("coordinator")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UILabel {
        Journal.shared.entries.append("make")
        return UILabel()
    }

    func updateUIView(_ label: UILabel, context: Context) {
        Journal.shared.entries.append("update\(value)")
        label.text = "Probe \(value)"
    }

    static func dismantleUIView(_ label: UILabel, coordinator: Coordinator) {
        Journal.shared.entries.append("dismantle")
    }
}

/// Logs the parent UIKit gives its view controller.
struct Parented: UIViewControllerRepresentable {
    final class Controller: UIViewController {
        override func willMove(toParent parent: UIViewController?) {
            Journal.shared.entries.append("will:" + name(parent))
        }

        override func didMove(toParent parent: UIViewController?) {
            Journal.shared.entries.append("did:" + name(parent))
        }

        private func name(_ parent: UIViewController?) -> String {
            parent.map { String(String(describing: type(of: $0)).prefix { $0 != "<" }) } ?? "nil"
        }
    }

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {}

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        Journal.shared.entries.append("dismantleVC")
    }
}

/// A view of a fixed intrinsic size, hugging or resisting compression as asked.
struct Fixed: UIViewRepresentable {
    var width: CGFloat
    var height: CGFloat
    var hugs = false
    var resists = true

    final class Box: UIView {
        var size = CGSize.zero
        override var intrinsicContentSize: CGSize { size }
    }

    func makeUIView(context: Context) -> Box {
        let view = Box()
        view.size = CGSize(width: width, height: height)
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            view.setContentHuggingPriority(hugs ? .required : .defaultLow, for: axis)
            view.setContentCompressionResistancePriority(resists ? .defaultHigh : .defaultLow, for: axis)
        }
        return view
    }

    func updateUIView(_ view: Box, context: Context) {}
}

/// Sized by sizeThatFits(_:uiView:context:), whatever its intrinsic size.
struct Fitting: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ view: UIView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        CGSize(width: 120, height: 40)
    }
}

/// A UIKit button that makes itself wider: SwiftUI lays it out again.
struct Growing: UIViewRepresentable {
    final class GrowButton: UIButton {
        @objc func grow() {
            setTitle((title(for: .normal) ?? "") + " rộng", for: .normal)
        }
    }

    func makeUIView(context: Context) -> GrowButton {
        let button = GrowButton(type: .system)
        button.setTitle("Rộng", for: .normal)
        button.addTarget(button, action: #selector(GrowButton.grow), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: GrowButton, context: Context) {}
}

/// A UIKit view laid out by constraints inside: SwiftUI sizes it as they make it, and again as
/// what is inside grows.
struct Pinned: UIViewRepresentable {
    final class Card: UIView {
        let button = UIButton(type: .system)

        override init(frame: CGRect) {
            super.init(frame: frame)
            button.setTitle("Ghim", for: .normal)
            button.addTarget(self, action: #selector(grow), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            addSubview(button)
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
                button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func grow() {
            button.setTitle((button.title(for: .normal) ?? "") + " chặt", for: .normal)
        }
    }

    func makeUIView(context: Context) -> Card {
        Card()
    }

    func updateUIView(_ view: Card, context: Context) {}
}

/// A UIKit button that counts its taps.
struct TapCounter: UIViewRepresentable {
    final class CountButton: UIButton {
        var taps = 0

        @objc func tapped() {
            taps += 1
            setTitle("UIKit chạm: \(taps)", for: .normal)
        }
    }

    func makeUIView(context: Context) -> CountButton {
        let button = CountButton(type: .system)
        button.setTitle("UIKit chạm: 0", for: .normal)
        button.addTarget(button, action: #selector(CountButton.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: CountButton, context: Context) {}
}
