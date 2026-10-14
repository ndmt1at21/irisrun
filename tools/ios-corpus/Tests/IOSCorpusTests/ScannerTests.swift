import Testing

@testable import IOSCorpus

@Test func attributesSwiftUIAndUIKitUsage() {
    let swiftUI = scan(
        source: """
            import SwiftUI

            @main struct DemoApp: App {
                var body: some Scene { WindowGroup { ContentView() } }
            }

            struct ContentView: View {
                @State private var count = 0
                @Environment(\\.dismiss) private var dismiss
                var body: some View {
                    VStack {
                        Text("\\(count)").padding()
                        Image(systemName: "star.fill")
                    }
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .onTapGesture { withAnimation { count += 1 } }
                }
            }

            #Preview { ContentView() }
            """)
    let uiKit = scan(
        source: """
            import UIKit

            class BaseViewController: UIViewController {}

            final class ListViewController: BaseViewController {
                @IBOutlet weak var tableView: UITableView!
                override func viewDidLoad() {
                    super.viewDidLoad()
                    tableView.reloadData()
                    view.addSubview(UILabel())
                    setUp()
                    present(UIAlertController(), animated: true)
                    navigationItem.rightBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .add, target: self, action: #selector(add))
                }
                func setUp() {}
                @objc func add() {}
            }
            """)
    let usage = analyze(id: "demo", ui: "swiftui", files: [swiftUI, uiKit], inventory: Inventory()).usage

    #expect(usage["swiftui.view"]?["VStack"] == 1)
    #expect(usage["swiftui.view"]?["ContentView"] == nil)
    #expect(usage["swiftui.type"]?["WindowGroup"] == 1)
    #expect(usage["swiftui.modifier"]?.keys.sorted() == ["navigationBarTitleDisplayMode", "onTapGesture", "padding", "withAnimation"])
    #expect(usage["attribute"]?["State"] == 1)
    #expect(usage["swiftui.environment"]?["\\.dismiss"] == 1)
    #expect(usage["macro"]?["Preview"] == 1)
    #expect(usage["sfsymbol"]?["star.fill"] == 1)
    #expect(usage["entry"]?["SwiftUI App"] == 1)

    #expect(usage["uikit.type"]?["UITableView"] == 1)
    #expect(usage["uikit.member"]?["UIViewController.viewDidLoad"] == 2)
    #expect(usage["uikit.member"]?["UITableView.reloadData"] == 1)
    #expect(usage["uikit.member"]?["UIView.addSubview"] == 1)
    #expect(usage["uikit.member"]?["UIViewController.present"] == 1)
    #expect(usage["uikit.member"]?["UINavigationItem.rightBarButtonItem"] == 1)
    #expect(usage["uikit.member"]?["UIViewController.setUp"] == nil)
    #expect(usage["objc"] == ["#selector": 1, "@objc": 1, "@IBOutlet": 1])
}
