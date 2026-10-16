import SwiftUI
import UIKit

/// UIKit inside SwiftUI: UIKit views and a view controller on a SwiftUI screen, with state
/// going both ways.
struct UIKitView: View {
    @State private var name = ""
    @State private var note = ""
    @State private var isLoading = false
    @State private var reloads = 0
    @State private var isOn = false
    @State private var count = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // A UIKit text field bound to SwiftUI state through its coordinator, next to a
            // SwiftUI one: the keyboard goes to whichever was tapped.
            NameField(text: $name, placeholder: "Tên (UIKit)")
            Text(name.isEmpty ? "SwiftUI thấy: chưa có tên" : "SwiftUI thấy: \(name)")
            TextField("Ghi chú (SwiftUI)", text: $note)
                .textFieldStyle(.roundedBorder)
            // SwiftUI state drives a UIKit view; a SwiftUI button drawn over it keeps its taps.
            Toggle("Tải dữ liệu", isOn: $isLoading)
            LoadingView(isLoading: isLoading)
                .overlay(alignment: .trailing) {
                    Button("Tải lại") {
                        reloads += 1
                    }
                    .padding(.trailing, 12)
                }
            Text("Tải lại: \(reloads) lần")
            // A UIKit switch sends its value back through its coordinator.
            HStack {
                Text("Công tắc UIKit")
                Spacer()
                SwitchView(isOn: $isOn)
                    .fixedSize()
            }
            Text(isOn ? "SwiftUI: bật" : "SwiftUI: tắt")
            // A UIKit view controller with its own label and button.
            CounterView(count: $count)
                .frame(height: 96)
            HStack {
                Text("SwiftUI đếm: \(count)")
                Spacer()
                Button("Đặt lại") {
                    count = 0
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("UIKit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A UITextField whose text is a SwiftUI binding.
struct NameField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.autocorrectionType = .no
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        // As tall as its text, as wide as SwiftUI offers.
        field.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.text = $text
        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
        }
    }
}

/// A UIKit view of the app's: a spinner and a status line.
final class LoadingStatusView: UIView {
    let spinner = UIActivityIndicatorView(style: .medium)
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        spinner.hidesWhenStopped = false
        addSubview(spinner)
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        spinner.frame = CGRect(x: 12, y: (bounds.height - 20) / 2, width: 20, height: 20)
        label.frame = CGRect(x: 44, y: 0, width: bounds.width - 56, height: bounds.height)
    }
}

/// Shows SwiftUI's loading state in the UIKit view.
struct LoadingView: UIViewRepresentable {
    var isLoading: Bool

    func makeUIView(context: Context) -> LoadingStatusView {
        LoadingStatusView()
    }

    func updateUIView(_ view: LoadingStatusView, context: Context) {
        if isLoading {
            view.spinner.startAnimating()
        } else {
            view.spinner.stopAnimating()
        }
        view.label.text = isLoading ? "UIKit: đang tải" : "UIKit: chờ"
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LoadingStatusView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: 48)
    }
}

/// A UISwitch whose value is a SwiftUI binding.
struct SwitchView: UIViewRepresentable {
    @Binding var isOn: Bool

    func makeUIView(context: Context) -> UISwitch {
        let control = UISwitch()
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISwitch, context: Context) {
        context.coordinator.isOn = $isOn
        control.setOn(isOn, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    final class Coordinator: NSObject {
        var isOn: Binding<Bool>

        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }

        @objc func valueChanged(_ control: UISwitch) {
            isOn.wrappedValue = control.isOn
        }
    }
}

/// A UIKit view controller that counts taps on its button and says so.
final class CounterViewController: UIViewController {
    var count = 0 {
        didSet { label.text = "UIKit đếm: \(count)" }
    }
    var onCount: ((Int) -> Void)?
    private let label = UILabel()
    private let button = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 10
        label.text = "UIKit đếm: \(count)"
        button.setTitle("Đếm", for: .normal)
        button.addTarget(self, action: #selector(countTapped), for: .touchUpInside)
        view.addSubview(label)
        view.addSubview(button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        label.frame = CGRect(x: 16, y: 12, width: view.bounds.width - 32, height: 24)
        button.frame = CGRect(x: 16, y: 48, width: 80, height: 36)
    }

    @objc private func countTapped() {
        count += 1
        onCount?(count)
    }
}

/// The counter in SwiftUI: its count is a SwiftUI binding.
struct CounterView: UIViewControllerRepresentable {
    @Binding var count: Int

    func makeUIViewController(context: Context) -> CounterViewController {
        CounterViewController()
    }

    func updateUIViewController(_ controller: CounterViewController, context: Context) {
        controller.onCount = { count = $0 }
        if controller.count != count {
            controller.count = count
        }
    }
}
