import Foundation

/// A finger on the screen, as the Device Protocol sends it.
public struct DeviceTouch: Sendable {
    public enum Phase: Sendable {
        case began, moved, stationary, ended, cancelled
    }

    /// The same for one finger from when it touches to when it lifts.
    public var id: UInt32
    public var phase: Phase
    /// In points from the top-left corner of the screen.
    public var location: CGPoint

    public init(id: UInt32, phase: Phase, location: CGPoint) {
        self.id = id
        self.phase = phase
        self.location = location
    }
}

/// Delivers a phone's input to the app, as each UI framework does it. Used on the main thread.
public protocol DeviceInputHandler: AnyObject {
    /// Every touch on the screen after a change, at a time on the `systemUptime` clock.
    func touch(_ touches: [DeviceTouch], at time: TimeInterval)
    /// Text from the input method: inserted at the caret in place of the marked text.
    func commit(_ text: String)
    /// The text the input method is composing, shown at the caret until it commits.
    func compose(_ text: String)
    /// Deletes UTF-16 code units around the caret, as an input method's correction does.
    func deleteSurrounding(before: Int, after: Int)
    /// A key pressed on a hardware keyboard, by W3C `KeyboardEvent.code`; `command` is the
    /// Command key of a Mac keyboard on iPad.
    func press(_ code: String, command: Bool)
}

/// Runs one command of a script, as a phone's input. Points are in points from the top-left
/// corner of the screen.
///
///     tap <text>                  touches the middle of the first text that reads <text>
///     tap <x> <y>                 touches a point
///     hold <text> | <x> <y>       touches and holds for 0.6 s, as a long press
///     swipe <text>                drags the row of a text 200 points to the left
///     drag <x1> <y1> <x2> <y2>    moves a finger between two points and holds it before lifting
///     fling <x1> <y1> <x2> <y2>   the same, lifting while moving, so scrolling keeps going
///     type <text>                 commits text from the input method at the caret
///     compose [<text>]            sets the input method's marked text; no text clears it
///     delete <before> <after>     deletes UTF-16 code units around the caret
///     key <code>                  presses a key by KeyboardEvent.code: Backspace, Enter, ArrowLeft…
///
/// `frameOfText` finds text on screen; `hold` lets the app's clock run on for some seconds while
/// a finger stays down. Returns false, after printing why, for a command that did nothing.
public func runScriptCommand(
    _ command: Substring,
    input: any DeviceInputHandler,
    screenWidth: CGFloat,
    frameOfText: (String) -> CGRect?,
    hold: (Double) -> Void
) -> Bool {
    let parts = command.split(separator: " ", maxSplits: 1)
    let name = parts[0]
    let argument = parts.count > 1 ? String(parts[1]) : ""
    let numbers = argument.split(separator: " ").compactMap { Double($0) }
    switch name {
    case "tap", "hold":
        let point: CGPoint
        if numbers.count == 2 {
            point = CGPoint(x: numbers[0], y: numbers[1])
        } else if let frame = frameOfText(argument) {
            point = CGPoint(x: frame.midX, y: frame.midY)
        } else {
            print("no text \"\(argument)\" on screen")
            return false
        }
        input.touch([DeviceTouch(id: 0, phase: .began, location: point)], at: ProcessInfo.processInfo.systemUptime)
        if name == "hold" {
            // The app's clock moves on while the finger stays down.
            hold(0.6)
        }
        input.touch([DeviceTouch(id: 0, phase: .ended, location: point)], at: ProcessInfo.processInfo.systemUptime)
    case "drag", "fling", "swipe":
        let from: CGPoint
        let to: CGPoint
        if name == "swipe" {
            guard let frame = frameOfText(argument) else {
                print("no text \"\(argument)\" on screen")
                return false
            }
            from = CGPoint(x: min(frame.maxX + 120, screenWidth - 20), y: frame.midY)
            to = CGPoint(x: from.x - 200, y: frame.midY)
        } else {
            guard numbers.count == 4 else {
                print("usage: \(name) <x1> <y1> <x2> <y2>")
                return false
            }
            from = CGPoint(x: numbers[0], y: numbers[1])
            to = CGPoint(x: numbers[2], y: numbers[3])
        }
        // Ten moves a frame apart, on a clock of its own so that velocities do not depend on
        // how fast this machine runs.
        var time = ProcessInfo.processInfo.systemUptime
        input.touch([DeviceTouch(id: 0, phase: .began, location: from)], at: time)
        for step in 1 ... 10 {
            time += 1.0 / 60
            let progress = Double(step) / 10
            let point = CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
            input.touch([DeviceTouch(id: 0, phase: .moved, location: point)], at: time)
        }
        if name != "fling" {
            time += 0.25
            input.touch([DeviceTouch(id: 0, phase: .stationary, location: to)], at: time)
        }
        time += 1.0 / 60
        input.touch([DeviceTouch(id: 0, phase: .ended, location: to)], at: time)
    case "type":
        input.commit(argument)
    case "compose":
        input.compose(argument)
    case "delete" where numbers.count == 2:
        input.deleteSurrounding(before: Int(numbers[0]), after: Int(numbers[1]))
    case "key" where !argument.isEmpty:
        input.press(argument, command: false)
    default:
        print("unknown command: \(command)")
        return false
    }
    return true
}
