import UIKit

// An app's Objective-C on iOS, which ObjCRewriterTests rewrite into Tests/ObjCRewriteTests and
// those tests then build and run. It must stay valid iOS code.

/// What reached the app, in order.
var events: [String] = []

class Counter: NSObject {
     dynamic var count = 0 { didSet { _irisDidChangeValue(self, \Counter.count, from: oldValue) } }
     var title: String?
     var cornerRadius: CGFloat = 0
     var enabled = true

     func increment() {
        count += 1
    }

     private func reset(_ sender: Any?) {
        count = 0
    }

     func add(_ amount: Int, times: Int) {
        count += amount * times
    }

     func move(to point: CGPoint) {
        events.append("moved to \(point.x)")
    }

    func selectors() -> [Selector] {
        [
            _irisSelector("increment"),
            _irisSelector("reset:"),
            _irisSelector("addAmount:times:"),
            _irisSelector("moveTo:"),
            _irisSelector("title"),
            _irisSelector("setIsEnabled:"),
            _irisSelector("resignFirstResponder")

,
            _irisSelector("increment"),
            _irisSelector("reset:"),
        ]
    }
}

class Greeter: NSObject {
     func greet() -> String {
        "hello"
    }
}

class LoudGreeter: Greeter {
    override func greet() -> String {
        "HELLO"
    }

     func shout(sender: Any) {
        events.append("shout")
    }
}

 class Settings: NSObject {
    dynamic var volume = 5 {
        didSet { _irisDidChangeValue(self, \Settings.volume, from: oldValue); events.append("volume \(volume)") }
    }
    var name = "Iris"

    func mute() {
        volume = 0
    }
}

private class Secret: NSObject {
     private func reveal() {
        events.append("revealed")
    }

    static func revealOne() {
        Secret().perform(_irisSelector("reveal"))
    }
}

func revealSecret() {
    Secret.revealOne()
}

enum Outer {
    class Inner: NSObject {
         func ping() {
            events.append("ping")
        }
    }
}

class Box<Value>: NSObject {
     func open() {}
}

 protocol ColorPickerDelegate: AnyObject {
      func picker(_ picker: ColorPicker, didPick color: UIColor)
      func preferredSize(for picker: ColorPicker) -> CGFloat
    func pickerDidClose(_ picker: ColorPicker)
}

class ColorPicker: UIViewController {
     weak var swatch: UIView!
     var swatches: [UIView]!
    weak var delegate: ColorPickerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: _irisSelector("themeChanged:"), name: .themeChanged, object: nil)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: _irisSelector("dismissKeyboard")))
    }

     func colorTapped(_ sender: UIControl) {
        _irisOptional(delegate, _irisSelector("picker:didPick:"))?.picker(self, didPick: .systemRed)
        events.append("size \(_irisOptional(delegate, _irisSelector("preferredSizeFor:"))?.preferredSize(for: self) ?? 44)")
        delegate?.pickerDidClose(self)
    }

     func themeChanged(_ notification: Notification) {
        events.append("theme changed")
    }

    func stopObserving() {
        NotificationCenter.default._irisRemoveObserver(self, name: .themeChanged, object: nil)
    }

    deinit {
        NotificationCenter.default._irisRemoveObserver(self)
    }

    #if os(macOS)
     func macOnly() {}
    #endif
}

extension UIViewController {
     func dismissKeyboard() {
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
     func preferredSize(for picker: ColorPicker) -> CGFloat {
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

let titleKey = "title"
extension ColorPicker { static func _irisMethods_ObjCApp_swift_0() { _IrisMethods.register(ColorPicker.self, [
    "swatch": .init { (o: ColorPicker) in { o.swatch } },
    "setSwatch:": .init { (o: ColorPicker) in { o.swatch = $0 } },
    "swatches": .init { (o: ColorPicker) in { o.swatches } },
    "setSwatches:": .init { (o: ColorPicker) in { o.swatches = $0 } },
    "colorTapped:": .init(ColorPicker.colorTapped(_:)),
    "themeChanged:": .init(ColorPicker.themeChanged(_:)),
]) } }
#if os(macOS)
extension ColorPicker { static func _irisMethods_ObjCApp_swift_1() { _IrisMethods.register(ColorPicker.self, [
    "macOnly": .init { (o: ColorPicker) in { o.macOnly() } },
]) } }
#endif
extension ColorPickerDelegate { func picker(_ a0: ColorPicker, didPick a1: UIColor) { _IrisMethods.send(_irisSelector("picker:didPick:"), to: self, with: [a0, a1]) } }
extension ColorPickerDelegate { func preferredSize(for a0: ColorPicker) -> CGFloat { _IrisMethods.send(_irisSelector("preferredSizeFor:"), to: self, with: [a0]) as! CGFloat } }
extension Counter { static func _irisMethods_ObjCApp_swift_2() { _IrisMethods.register(Counter.self, [
    "count": .init { (o: Counter) in { o.count } },
    "setCount:": .init { (o: Counter) in { o.count = $0 } },
    "title": .init { (o: Counter) in { o.title } },
    "setTitle:": .init { (o: Counter) in { o.title = $0 } },
    "cornerRadius": .init { (o: Counter) in { o.cornerRadius } },
    "setCornerRadius:": .init { (o: Counter) in { o.cornerRadius = $0 } },
    "isEnabled": .init { (o: Counter) in { o.enabled } },
    "setIsEnabled:": .init { (o: Counter) in { o.enabled = $0 } },
    "increment": .init { (o: Counter) in { o.increment() } },
    "reset:": .init(Counter.reset(_:)),
    "addAmount:times:": .init(Counter.add(_:times:)),
    "moveTo:": .init(Counter.move(to:)),
]) } }
extension Greeter { static func _irisMethods_ObjCApp_swift_3() { _IrisMethods.register(Greeter.self, [
    "greet": .init { (o: Greeter) in { o.greet() } },
]) } }
extension LoudGreeter { static func _irisMethods_ObjCApp_swift_4() { _IrisMethods.register(LoudGreeter.self, [
    "shoutWithSender:": .init(LoudGreeter.shout(sender:)),
]) } }
extension Outer.Inner { static func _irisMethods_ObjCApp_swift_5() { _IrisMethods.register(Outer.Inner.self, [
    "ping": .init { (o: Outer.Inner) in { o.ping() } },
]) } }
extension PickerHost { static func _irisMethods_ObjCApp_swift_6() { _IrisMethods.register(PickerHost.self, [
    "picker:didPick:": .init(PickerHost.picker(_:didPick:)),
    "pickerDidClose:": .init(PickerHost.pickerDidClose(_:)),
]) } }
extension Secret { static func _irisMethods_ObjCApp_swift_7() { _IrisMethods.register(Secret.self, [
    "reveal": .init { (o: Secret) in { o.reveal() } },
]) } }
extension Settings { static func _irisMethods_ObjCApp_swift_8() { _IrisMethods.register(Settings.self, [
    "volume": .init { (o: Settings) in { o.volume } },
    "setVolume:": .init { (o: Settings) in { o.volume = $0 } },
    "name": .init { (o: Settings) in { o.name } },
    "setName:": .init { (o: Settings) in { o.name = $0 } },
    "mute": .init { (o: Settings) in { o.mute() } },
]) } }
extension SizedPickerHost { static func _irisMethods_ObjCApp_swift_9() { _IrisMethods.register(SizedPickerHost.self, [
    "preferredSizeFor:": .init(SizedPickerHost.preferredSize(for:)),
]) } }
extension UIViewController { static func _irisMethods_ObjCApp_swift_10() { _IrisMethods.register(UIViewController.self, [
    "dismissKeyboard": .init { (o: UIViewController) in { o.dismissKeyboard() } },
]) } }
func _irisRegisterMethods_ObjCApp_swift() {
    _irisRegister { ColorPicker._irisMethods_ObjCApp_swift_0() }
#if os(macOS)
    _irisRegister { ColorPicker._irisMethods_ObjCApp_swift_1() }
#endif
    _irisRegister { Counter._irisMethods_ObjCApp_swift_2() }
    _irisRegister { Greeter._irisMethods_ObjCApp_swift_3() }
    _irisRegister { LoudGreeter._irisMethods_ObjCApp_swift_4() }
    _irisRegister { Outer.Inner._irisMethods_ObjCApp_swift_5() }
    _irisRegister { PickerHost._irisMethods_ObjCApp_swift_6() }
    _irisRegister { Secret._irisMethods_ObjCApp_swift_7() }
    _irisRegister { Settings._irisMethods_ObjCApp_swift_8() }
    _irisRegister { SizedPickerHost._irisMethods_ObjCApp_swift_9() }
    _irisRegister { UIViewController._irisMethods_ObjCApp_swift_10() }
}
