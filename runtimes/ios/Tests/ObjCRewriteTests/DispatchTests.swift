import Foundation
import Testing
import UIKit

// ObjCApp.swift and _IrisMethodTables.swift are IrisBuildTests' fixture app as irisrun-ios-build
// rewrites it. These tests check that what it registers reaches the app's methods, built in
// Swift 5 mode as apps are.

@MainActor
@Suite(.serialized) struct RewrittenAppTests {
    init() {
        events = []
    }

    @Test func selectorsHaveTheirObjectiveCNames() {
        #expect(Counter().selectors().map(NSStringFromSelector) == [
            "increment", "reset:", "addAmount:times:", "moveTo:", "title", "setIsEnabled:", "resignFirstResponder", "increment", "reset:",
        ])
        #expect(titleKey == "title")
    }

    @Test func selectorsReachPrivateOverriddenAndNestedMethods() {
        let counter = Counter()
        counter.perform(_irisSelector("increment"))
        counter.perform(_irisSelector("addAmount:times:"), with: 2, with: 3)
        #expect(counter.count == 7)
        counter.perform(_irisSelector("reset:"), with: nil)
        #expect(counter.count == 0, "a private method")
        #expect(_IrisMethods.send(_irisSelector("greet"), to: LoudGreeter(), with: []) as? String == "HELLO", "the subclass's override")
        #expect(_IrisMethods.send(_irisSelector("greet"), to: Greeter(), with: []) as? String == "hello")
        LoudGreeter().perform(_irisSelector("shoutWithSender:"), with: self)
        revealSecret()
        Outer.Inner().perform(_irisSelector("ping"))
        UIViewController().perform(_irisSelector("dismissKeyboard"))
        #expect(events == ["shout", "revealed", "ping", "dismissed keyboard"])
        #expect(Settings().responds(to: _irisSelector("mute")), "@objcMembers")
        #expect(!Box<Int>().responds(to: _irisSelector("open")), "generic classes have no table")
        #expect(!ColorPicker().responds(to: _irisSelector("macOnly")), "#if os(macOS)")
    }

    @Test func keyValueCodingGoesThroughAccessors() {
        let counter = Counter()
        counter.setValue(5, forKey: "count")
        counter.setValue("Taps", forKey: "title")
        #expect(counter.count == 5)
        #expect(counter.value(forKey: "title") as? String == "Taps")
        #expect(counter.value(forKey: "enabled") as? Bool == true, "the getter @objc(isEnabled) names")
        // How a storyboard connects outlets and sets inspectable values.
        let picker = ColorPicker()
        let swatch = UIView()
        picker.setValue(swatch, forKey: "swatch")
        picker.setValue([swatch, UIView()], forKey: "swatches")
        counter.setValue(CGFloat(12), forKey: "cornerRadius")
        #expect(picker.swatch === swatch)
        #expect(picker.swatches.count == 2)
        #expect(counter.cornerRadius == 12)
    }

    @Test func observersSeeDynamicPropertiesChange() {
        let counter = Counter()
        var changes: [String] = []
        let observation = counter.observe(\.count, options: [.old, .new, .initial]) { _, change in
            changes.append("\(change.oldValue.map(String.init) ?? "-") → \(change.newValue.map(String.init) ?? "-")")
        }
        counter.count = 3
        counter.increment()
        observation.invalidate()
        counter.count = 9
        #expect(changes == ["- → 0", "0 → 3", "3 → 4"])

        let settings = Settings()
        let volume = settings.observe(\.volume, options: .new) { settings, _ in changes.append("volume is \(settings.volume)") }
        settings.mute()
        #expect(changes.last == "volume is 0")
        #expect(events == ["volume 0"], "the property's own didSet runs too")
        _ = volume
    }

    @Test func actionsCallOptionalRequirementsOnlyWhereTheyExist() {
        let picker = ColorPicker()
        let control = UIControl()
        control.addTarget(picker, action: _irisSelector("colorTapped:"), for: .touchUpInside)
        control.sendActions(for: .touchUpInside)
        #expect(events == ["size 44.0"])

        let host = PickerHost()
        picker.delegate = host
        control.sendActions(for: .touchUpInside)
        // A subclass of the class that adopts the protocol has the size.
        let sized = SizedPickerHost()
        picker.delegate = sized
        control.sendActions(for: .touchUpInside)
        #expect(events == ["size 44.0", "picked", "size 44.0", "closed", "picked", "size 60.0", "closed"])
    }

    @Test func notificationsReachObserversUntilRemoved() {
        let picker = ColorPicker()
        picker.loadViewIfNeeded()
        NotificationCenter.default.post(name: .themeChanged, object: nil)
        picker.stopObserving()
        NotificationCenter.default.post(name: .themeChanged, object: nil)
        #expect(events == ["theme changed"])
        #expect(picker.view.gestureRecognizers?.first?.view === picker.view)
    }
}
