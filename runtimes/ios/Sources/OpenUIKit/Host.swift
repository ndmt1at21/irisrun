import Foundation
import IrisHost

/// Iris: makes instances of an app class that UIKit knows only by name or by class, as UIKit
/// does with `alloc` and `init`. Swift can't call the `init()` of a class known only at run
/// time unless it is `required`, so irisrun-ios-build makes the app's delegate and application
/// classes conform to this.
@preconcurrency @MainActor
public protocol _IrisInstantiable: AnyObject {
    static func _irisMake() -> AnyObject
}

/// A new instance of `type`, or nil after saying why there is none.
@MainActor
func instantiate(_ type: AnyClass) -> AnyObject? {
    if let instantiable = type as? any _IrisInstantiable.Type {
        return instantiable._irisMake()
    }
    if type == UIApplication.self {
        return UIApplication()
    }
    if type == CALayer.self {
        return CALayer()
    }
    printError("irisrun: cannot make a \(type); irisrun-ios-build makes the classes that adopt a UIKit delegate protocol or subclass UIApplication")
    return nil
}

/// Iris: a view that draws more than its subviews, as a SwiftUI hosting view draws its SwiftUI
/// content: what the screen description shows inside it, and where its text is for `tap <text>`.
@preconcurrency @MainActor
public protocol _IrisScreenContent: UIView {
    /// What the view draws, a line each, in its coordinates; text in quotes.
    var _irisScreenLines: [String] { get }
    /// The first text that reads `text`, in the view's coordinates.
    func _irisFrame(ofText text: String) -> CGRect?
}

/// Iris: shows the app's windows as a Device Protocol device, or plays a script against them
/// and prints what the screen shows after each command.
@MainActor
final class UIKitHost {
    private let options: HostOptions

    private init(options: HostOptions) {
        self.options = options
    }

    /// Reads how irisrun runs the app, before anything prints, and makes the window's scene.
    static func start() -> UIKitHost {
        let options = HostOptions.fromEnvironment()
        irisScene = .window(size: UIScreen.main.bounds.size, scale: options.scale)
        // Where no window draws the screen is black, as on a phone.
        irisScene.root.backgroundColor = 0xFF00_0000
        return UIKitHost(options: options)
    }

    func run() -> Never {
        let input = TouchInput()
        if let output = options.deviceOutput {
            irisAnimates = true
            let device = DeviceHost(size: UIScreen.main.bounds.size, scale: options.scale, output: output, input: input) {
                LayerCommit.commit()
            }
            device.screenDidChange = { old in MainActor.assumeIsolated { UIWindow.screenDidChange(from: old) } }
            // Changes made outside input, such as by timers, show as soon as they are drawn.
            LayerCommit.didDraw = { device.scheduleUpdate(after: 0) }
            device.run()
        }
        play(input)
    }

    /// Takes one command per line on stdin, as OpenSwiftUI's stdout app does, and prints the
    /// screen after each; with IRISRUN_FRAMES it also writes each screen as a PNG.
    private func play(_ input: TouchInput) -> Never {
        var number = 0
        func show(updatedIn update: Duration) {
            LayerCommit.commit()
            print(screenDescription())
            if let frames = options.frames {
                writeFrame(number: number, to: frames, updatedIn: update)
                number += 1
            }
            fflush(nil)
        }
        show(updatedIn: .zero)
        while let line = readLine() {
            let command = line.drop { $0 == " " }
            guard !command.isEmpty, !command.hasPrefix("#") else { continue }
            print("> \(command)")
            let start = ContinuousClock.now
            _ = runScriptCommand(
                command, input: input, screenWidth: UIScreen.main.bounds.width,
                frameOfText: frame(ofText:),
                hold: {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: $0))
                    irisScriptTime += $0
                }
            )
            // What the command queued on the main queue runs before the screen is taken.
            RunLoop.main.run(until: Date())
            show(updatedIn: .now - start)
        }
        exit(0)
    }

    // MARK: The screen as text

    /// The windows on screen as a tree of views: class, frame in the superview, what draws,
    /// and text in quotes (accessibility labels and values, such as a text field's text), so
    /// `# expect <text>` lines of a session can find it, and which view is editing. Hidden
    /// views show without what is inside them.
    func screenDescription() -> String {
        var lines = [
            "OpenUIKit backend: stdout",
            "surface: \(format(UIScreen.main.bounds.width))x\(format(UIScreen.main.bounds.height))",
            "rendered:",
        ]
        for window in UIWindow.visible {
            describe(window, depth: 1, into: &lines)
        }
        return lines.joined(separator: "\n")
    }

    private func describe(_ view: UIView, depth: Int, into lines: inout [String]) {
        let frame = view.frame
        let layer = view.layer
        // Generic views, such as a hosting view of some SwiftUI content, by the class's name.
        let name = String(describing: type(of: view)).prefix { $0 != "<" }
        var line = String(repeating: "  ", count: depth) + "- \(name)"
            + " x:\(format(frame.minX)) y:\(format(frame.minY)) w:\(format(frame.width)) h:\(format(frame.height))"
        if let color = layer.backgroundColor {
            line += " background:\(hex(color))"
        }
        if layer.cornerRadius > 0 {
            line += " corner:\(format(layer.cornerRadius))"
        }
        if layer.borderWidth > 0, let color = layer.borderColor {
            line += " border:\(format(layer.borderWidth)) \(hex(color))"
        }
        if layer.shadowOpacity > 0, let color = layer.shadowColor {
            line += " shadow:\(hex(color)) opacity:\(format(CGFloat(layer.shadowOpacity))) offset:\(format(layer.shadowOffset.width)),\(format(layer.shadowOffset.height)) radius:\(format(layer.shadowRadius))"
        }
        if layer.opacity < 1 {
            line += " alpha:\(format(CGFloat(layer.opacity)))"
        }
        let transform = layer.affineTransform()
        if !transform.isIdentity {
            line += " transform:[\([transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map { format(CGFloat($0)) }.joined(separator: " "))]"
        }
        if let image = layer.contents as? IrisCGImage {
            line += " image:\(Int(image.image.pixelSize.width))x\(Int(image.image.pixelSize.height))"
        }
        if layer.masksToBounds {
            line += " clips"
        }
        if (view as? UIWindow)?.isKeyWindow == true {
            line += " key"
        }
        if view.isHidden {
            lines.append(line + " hidden")
            return
        }
        if let label = view.accessibilityLabel {
            line += " " + String(reflecting: label)
        }
        if let value = view.accessibilityValue, !value.isEmpty {
            line += " value:" + String(reflecting: value)
        }
        if view.isFirstResponder {
            line += " editing"
        }
        lines.append(line)
        for content in (view as? any _IrisScreenContent)?._irisScreenLines ?? [] {
            lines.append(String(repeating: "  ", count: depth + 1) + "- " + content)
        }
        for subview in view.subviews {
            describe(subview, depth: depth + 1, into: &lines)
        }
    }

    /// Where on screen the first visible view labelled `text`, or text drawn by a view's own
    /// content, is, front-most window first.
    private func frame(ofText text: String) -> CGRect? {
        func find(in view: UIView) -> CGRect? {
            guard !view.isHidden else { return nil }
            if view.accessibilityLabel == text || view.accessibilityValue == text {
                return view.layer.convert(view.bounds, to: nil)
            }
            if let frame = (view as? any _IrisScreenContent)?._irisFrame(ofText: text) {
                return view.layer.convert(frame, to: nil)
            }
            return view.subviews.lazy.compactMap(find).first
        }
        return UIWindow.visible.reversed().lazy.compactMap(find).first
    }
}

private func format(_ value: CGFloat) -> String {
    String(format: "%.1f", value == 0 ? 0 : Double(value))
}

/// #RRGGBBAA.
private func hex(_ color: CGColor) -> String {
    let argb = color.argb
    return String(format: "#%06X%02X", argb & 0xFF_FFFF, argb >> 24)
}

/// Iris: a phone's input, for UIKit. Each change of the fingers on the screen updates their
/// `UITouch`es, and `UIApplication.sendEvent(_:)` delivers them in one reused `UIEvent`, as
/// UIKit does.
@MainActor
final class TouchInput {
    /// The touches on the screen, by finger.
    private var touches: [UInt32: UITouch] = [:]
    private let event = UIEvent()
    /// Where and when the last tap lifted, on the screen, and its tap count.
    private var lastTap: (location: CGPoint, time: TimeInterval, count: Int)?

    /// The front-most view that takes touches at a point on the screen.
    func hitTest(_ point: CGPoint) -> UIView? {
        UIWindow.visible.reversed().lazy.compactMap { window in
            window.hitTest(window.layer.convert(point, from: nil), with: nil)
        }.first
    }
}

extension TouchInput: @preconcurrency DeviceInputHandler {
    func touch(_ deviceTouches: [DeviceTouch], at time: TimeInterval) {
        // Fingers this change leaves out stay where they were.
        for touch in touches.values {
            touch.phase = .stationary
            touch.previousLocation = touch.location
        }
        for deviceTouch in deviceTouches {
            let touch: UITouch
            if deviceTouch.phase == .began {
                touch = UITouch()
                touch.view = hitTest(deviceTouch.location)
                touch.window = touch.view as? UIWindow ?? touch.view?.window
                if let lastTap, time - lastTap.time <= TapLimits.interval,
                   hypot(deviceTouch.location.x - lastTap.location.x, deviceTouch.location.y - lastTap.location.y) <= TapLimits.movement {
                    touch.tapCount = lastTap.count + 1
                }
                touches[deviceTouch.id] = touch
            } else if let existing = touches[deviceTouch.id] {
                touch = existing
            } else {
                continue
            }
            let location = touch.window.map { $0.layer.convert(deviceTouch.location, from: nil) } ?? deviceTouch.location
            touch.previousLocation = deviceTouch.phase == .began ? location : touch.location
            touch.location = location
            touch.timestamp = time
            touch.phase = switch deviceTouch.phase {
            case .began: .began
            case .moved: .moved
            case .stationary: .stationary
            case .ended: .ended
            case .cancelled: .cancelled
            }
            if deviceTouch.phase == .ended {
                lastTap = (deviceTouch.location, time, touch.tapCount)
            }
        }
        event.timestamp = time
        event.touches = Set(touches.values)
        UIApplication.shared.sendEvent(event)
        touches = touches.filter { !$0.value.hasLifted }
    }

    // Text and keys go to the first responder (UITextInput.swift).
}
