import Foundation
import IrisProtocol
import IrisRender

/// Runs the app as a device of the Device Protocol on stdio, as `irisrun start` runs it:
/// size-delimited HostMessage envelopes come in on stdin and DeviceMessage envelopes go out on
/// the stdout that `HostOptions` kept. Input is handled on the main run loop; a frame is drawn
/// by the render core whenever `irisSceneVersion` moved, and encoded as JPEG on another thread.
public final class DeviceHost: @unchecked Sendable {
    private let size: CGSize
    private let scale: Float
    private let output: FileHandle
    private let input: any DeviceInputHandler
    private let update: () -> Void
    /// Encodes and writes, in order, everything sent to the host.
    private let writer = DispatchQueue(label: "dev.irisrun.device.writer")
    private let lock = NSLock()
    private var newestFrame: UInt64 = 0
    private var sequence: UInt64 = 0
    private var shownVersion = -1
    private var nextRender: DispatchTime?

    /// `size` is the screen in points. `update` brings `irisScene` up to date, as the UI
    /// framework renders a frame; it and `input` run on the main thread.
    public init(size: CGSize, scale: Float, output: FileHandle, input: any DeviceInputHandler, update: @escaping () -> Void) {
        self.size = size
        self.scale = scale
        self.output = output
        self.input = input
        self.update = update
    }

    public func run() -> Never {
        send(.with {
            $0.deviceInfo = .with {
                $0.platform = .ios
                $0.kind = .localRuntime
                $0.model = "iPhone 14"
                $0.osVersion = "18.0"
                $0.display = .with {
                    $0.widthPx = UInt32((Float(size.width) * scale).rounded())
                    $0.heightPx = UInt32((Float(size.height) * scale).rounded())
                    $0.scale = scale
                }
            }
        })
        send(status(.launching))
        render()
        send(status(.foreground))
        Thread.detachNewThread { [self] in
            readHostMessages()
        }
        // A timer keeps the run loop running while nothing else is scheduled.
        RunLoop.main.add(Timer(timeInterval: 3600, repeats: true) { _ in }, forMode: .default)
        while true {
            _ = RunLoop.main.run(mode: .default, before: .distantFuture)
        }
    }

    /// Updates and sends a frame on the main run loop after `delay` seconds, at most 60 times a
    /// second. Call it on the main thread when the app has something new to show.
    public func scheduleUpdate(after delay: Double) {
        let time = DispatchTime.now() + max(delay, 1.0 / 60)
        if let nextRender, nextRender <= time {
            return
        }
        nextRender = time
        DispatchQueue.main.asyncAfter(deadline: time) { [self] in
            guard let nextRender, nextRender <= .now() else { return }
            render()
        }
    }

    // MARK: Host messages

    private func readHostMessages() {
        while let envelope = Self.readEnvelope() {
            guard let message = try? IrisHostMessage(serializedBytes: envelope) else {
                printError("irisrun: dropped an envelope that is not a HostMessage")
                continue
            }
            DispatchQueue.main.async { [self] in
                handle(message)
            }
        }
        // The host closed stdin: it has gone, and so does the app.
        exit(0)
    }

    private func handle(_ message: IrisHostMessage) {
        guard case let .input(event)? = message.payload else {
            // ponytail: display configuration and adapters come with P1-28 and P1-17.
            return
        }
        // Bring the app up to now first: gestures time touches with the app's clock, and a
        // clock left at the last frame, then moved on by a frame in the middle of a tap, makes
        // the tap seem held too long.
        render()
        switch event.event {
        case let .touch(touch)?:
            input.touch(touch.touches.map { point in
                DeviceTouch(
                    id: point.id,
                    phase: Self.phase(point.phase),
                    location: CGPoint(x: CGFloat(point.x / scale), y: CGFloat(point.y / scale))
                )
            }, at: ProcessInfo.processInfo.systemUptime)
        case let .text(edit)?:
            switch edit.edit {
            case let .commitText(text)?:
                input.commit(text)
            case let .setComposingText(text)?:
                input.compose(text)
            case let .deleteSurroundingText(range)?:
                input.deleteSurrounding(before: Int(range.beforeLength), after: Int(range.afterLength))
            case nil:
                break
            }
        case let .key(key)? where key.action == .down:
            input.press(key.code, command: key.meta)
        default:
            return
        }
        // Answer input at once rather than at the next requested update.
        render()
    }

    private static func phase(_ phase: IrisTouchPhase) -> DeviceTouch.Phase {
        switch phase {
        case .began: .began
        case .moved: .moved
        case .ended: .ended
        case .cancelled: .cancelled
        default: .stationary
        }
    }

    // MARK: Frames

    private func render() {
        nextRender = nil
        update()
        guard irisSceneVersion != shownVersion else { return }
        shownVersion = irisSceneVersion
        sequence += 1
        let sequence = sequence
        let frame = irisScene.render()
        lock.withLock { newestFrame = sequence }
        writer.async { [self] in
            // Frames the encoder fell behind on are skipped: the newest shows everything.
            guard lock.withLock({ newestFrame == sequence }), let jpeg = frame.encode(.jpeg, quality: 85) else {
                return
            }
            write(.with {
                $0.frame = .with {
                    $0.sequence = sequence
                    $0.format = .jpeg
                    $0.data = Data(jpeg)
                }
            })
        }
    }

    // MARK: Envelopes

    private func status(_ state: IrisAppState) -> IrisDeviceMessage {
        .with {
            $0.appStatus = .with {
                $0.state = state
                $0.appID = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
            }
        }
    }

    private func send(_ message: IrisDeviceMessage) {
        writer.async { [self] in
            write(message)
        }
    }

    /// On the writer queue.
    private func write(_ message: IrisDeviceMessage) {
        guard let payload: [UInt8] = try? message.serializedBytes() else { return }
        var envelope: [UInt8] = []
        var length = UInt64(payload.count)
        repeat {
            envelope.append(UInt8(length & 0x7F) | (length > 0x7F ? 0x80 : 0))
            length >>= 7
        } while length > 0
        envelope += payload
        output.write(Data(envelope))
    }

    /// The next size-delimited envelope on stdin, or nil once it ends.
    private static func readEnvelope() -> [UInt8]? {
        var length: UInt64 = 0
        for shift in stride(from: 0, to: 64, by: 7) {
            guard let byte = readExactly(1)?.first else { return nil }
            length |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return readExactly(Int(length))
            }
        }
        return nil
    }

    private static func readExactly(_ count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        var done = 0
        while done < count {
            let read = bytes.withUnsafeMutableBytes { buffer in
                Glibc.read(STDIN_FILENO, buffer.baseAddress! + done, count - done)
            }
            guard read > 0 else { return nil }
            done += read
        }
        return bytes
    }
}
