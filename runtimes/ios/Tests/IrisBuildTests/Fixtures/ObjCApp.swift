import UIKit

// An app's Objective-C on iOS, which ObjCRewriterTests rewrite into Tests/ObjCRewriteTests and
// those tests then build and run. It must stay valid iOS code.

/// What reached the app, in order.
var events: [String] = []

class Counter: NSObject {
    @objc dynamic var count = 0
    @objc var title: String?
    @IBInspectable var cornerRadius: CGFloat = 0
    @objc(isEnabled) var enabled = true

    @objc func increment() {
        count += 1
    }

    @objc private func reset(_ sender: Any?) {
        count = 0
    }

    @objc(addAmount:times:) func add(_ amount: Int, times: Int) {
        count += amount * times
    }

    @objc func move(to point: CGPoint) {
        events.append("moved to \(point.x)")
    }

    func selectors() -> [Selector] {
        [
            #selector(increment),
            #selector(reset(_:)),
            #selector(Counter.add(_:times:)),
            #selector(self.move(to:)),
            #selector(getter: Counter.title),
            #selector(setter: Counter.enabled),
            #selector(
                UIResponder.resignFirstResponder
            ),
            Selector("increment"),
            NSSelectorFromString("reset:"),
        ]
    }
}

class Greeter: NSObject {
    @objc func greet() -> String {
        "hello"
    }
}

class LoudGreeter: Greeter {
    override func greet() -> String {
        "HELLO"
    }

    @objc func shout(sender: Any) {
        events.append("shout")
    }
}

@objcMembers class Settings: NSObject {
    dynamic var volume = 5 {
        didSet { events.append("volume \(volume)") }
    }
    var name = "Iris"

    func mute() {
        volume = 0
    }
}

private class Secret: NSObject {
    @objc private func reveal() {
        events.append("revealed")
    }

    static func revealOne() {
        Secret().perform(#selector(Secret.reveal))
    }
}

func revealSecret() {
    Secret.revealOne()
}

enum Outer {
    class Inner: NSObject {
        @objc func ping() {
            events.append("ping")
        }
    }
}

class Box<Value>: NSObject {
    @objc func open() {}
}

@objc protocol ColorPickerDelegate {
    @objc optional func picker(_ picker: ColorPicker, didPick color: UIColor)
    @objc optional func preferredSize(for picker: ColorPicker) -> CGFloat
    func pickerDidClose(_ picker: ColorPicker)
}

class ColorPicker: UIViewController {
    @IBOutlet weak var swatch: UIView!
    @IBOutlet var swatches: [UIView]!
    weak var delegate: ColorPickerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged(_:)), name: .themeChanged, object: nil)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
    }

    @IBAction func colorTapped(_ sender: UIControl) {
        delegate?.picker?(self, didPick: .systemRed)
        events.append("size \(delegate?.preferredSize?(for: self) ?? 44)")
        delegate?.pickerDidClose(self)
    }

    @objc func themeChanged(_ notification: Notification) {
        events.append("theme changed")
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self, name: .themeChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    #if os(macOS)
    @objc func macOnly() {}
    #endif
}

extension UIViewController {
    @objc func dismissKeyboard() {
        events.append("dismissed keyboard")
    }
}

class PickerHost: NSObject, ColorPickerDelegate {
    func picker(_ picker: ColorPicker, didPick color: UIColor) {
        events.append("picked")
    }

    func pickerDidClose(_ picker: ColorPicker) {
        events.append("closed")
    }
}

class SizedPickerHost: PickerHost {
    @objc func preferredSize(for picker: ColorPicker) -> CGFloat {
        60
    }
}

extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}

/// An app's own removeObserver(_:), which stays.
final class Store {
    func removeObserver(_ observer: AnyObject) {}
}

func forget(_ observer: AnyObject, in store: Store) {
    store.removeObserver(observer)
}

let titleKey = #keyPath(Counter.title)
