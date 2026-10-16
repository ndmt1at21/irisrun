import SwiftUI
import UIKit

/// A page with a SwiftUI card inside, as apps bring SwiftUI into a UIKit screen: the card's
/// UIHostingController is a child of the screen's view controller, which puts the card's view
/// on this page (`ViewController.viewDidLoad`). The card keeps its own state, takes taps and
/// typing, and tells UIKit through a closure; the UIKit label, field and button around it go
/// on working, and the button gives the card a new root view.
class SwiftUIPage: UIView {
    private(set) lazy var card = UIHostingController(rootView: makeCard(title: "Thẻ SwiftUI"))
    private let heard = UILabel(frame: CGRect(x: 16, y: 12, width: 288, height: 20))
    private let size = UILabel()
    private let field = UITextField()
    private let rename = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        heard.text = "UIKit nghe được: chưa có gì"
        heard.autoresizingMask = [.flexibleWidth]
        addSubview(heard)
        size.font = .preferredFont(forTextStyle: .footnote)
        size.textColor = .secondaryLabel
        field.placeholder = "Ô của UIKit"
        field.borderStyle = .roundedRect
        rename.setTitle("Đổi tiêu đề", for: .normal)
        rename.addTarget(self, action: #selector(renameCard), for: .touchUpInside)
        for view in [size, field, rename] {
            view.autoresizingMask = [.flexibleWidth]
            addSubview(view)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeCard(title: String) -> GreetingCard {
        GreetingCard(title: title) { [weak self] taps in
            self?.heard.text = "UIKit nghe được: \(taps) lần chạm"
        }
    }

    /// The card is as tall as SwiftUI says it needs at the page's width; the UIKit views follow.
    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width - 32
        let fitting = card.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        card.view.frame = CGRect(x: 16, y: 40, width: width, height: fitting.height)
        size.text = "Cỡ thẻ: \(Int(fitting.width)) × \(Int(fitting.height))"
        size.frame = CGRect(x: 16, y: card.view.frame.maxY + 8, width: width, height: 18)
        field.frame = CGRect(x: 16, y: size.frame.maxY + 12, width: width, height: 34)
        rename.frame = CGRect(x: 16, y: field.frame.maxY + 12, width: width, height: 34)
    }

    @objc private func renameCard() {
        card.rootView = makeCard(title: "Tiêu đề từ UIKit")
    }
}

/// SwiftUI's part: a counter, a button, and a text field that greets by name.
struct GreetingCard: View {
    var title: String
    var onTap: (Int) -> Void

    @State private var taps = 0
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            HStack {
                Text("Đã chạm \(taps) lần")
                Spacer()
                Button("Chạm vào SwiftUI") {
                    taps += 1
                    onTap(taps)
                }
                .buttonStyle(.borderedProminent)
            }
            TextField("Tên trong SwiftUI", text: $name)
                .textFieldStyle(.roundedBorder)
            Text(name.isEmpty ? "Chưa có tên" : "Xin chào, \(name)!")
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
