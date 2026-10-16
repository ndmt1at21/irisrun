import Foundation
import IrisRender

/// The render core scene of the app's one window, made when the app starts, before anything is
/// laid out. OpenSwiftUI and OpenUIKit draw into it, and measure text with its fonts so that
/// layout agrees with what is drawn. Main thread only.
public nonisolated(unsafe) var irisScene: IrisRender.Scene!

/// Counts the changes drawn into `irisScene`, so hosts know when a frame changed.
public nonisolated(unsafe) var irisSceneVersion = 0

/// Whether the host shows animations as they run, on the uptime clock, as a device does. A
/// script shows each step where its animations end, and SwiftUI's content runs on a clock of
/// its own that only moves while a step settles.
public nonisolated(unsafe) var irisAnimates = false

/// Seconds that a script has let pass with a finger held down (`hold`), the only time its steps
/// take besides settling: SwiftUI's clock moves on by them, as a device's would.
public nonisolated(unsafe) var irisScriptTime = 0.0

extension IrisRender.Scene {
    /// A white window with the fonts in `${IRISRUN_HOME:-~/.irisrun}/fonts`, which Iris's
    /// crates/render/fetch-fonts.sh downloads.
    public static func window(size: CGSize, scale: Float) -> IrisRender.Scene {
        let scene = IrisRender.Scene(width: Float(size.width), height: Float(size.height), scale: scale)
        scene.root.backgroundColor = 0xFFFF_FFFF
        let environment = ProcessInfo.processInfo.environment
        // In a container NSHomeDirectory() can differ from $HOME.
        let home = environment["IRISRUN_HOME"] ?? (environment["HOME"] ?? NSHomeDirectory()) + "/.irisrun"
        for name in ["Inter.ttf", "InterItalic.ttf", "NotoSansSC.ttf"] {
            let path = home + "/fonts/" + name
            // Mapped, not read: the CJK font takes memory only for the glyphs drawn.
            guard scene.addFont(path: path) else {
                fatalError("cannot load \(path); run Iris's crates/render/fetch-fonts.sh")
            }
        }
        return scene
    }
}

/// How irisrun asked the app to run, read from the environment when the app starts.
public struct HostOptions {
    /// With IRISRUN_DEVICE=stdio the app is a Device Protocol device (`DeviceHost`), and this is
    /// the stdout that envelopes go to.
    public var deviceOutput: FileHandle?
    /// Pixels per point of the frames, `HostOptions.scale`.
    public var scale: Float
    /// IRISRUN_FRAMES=<dir>: where a script run writes each step as a PNG.
    public var frames: URL?

    /// Reads the environment. For a device it also takes stdout for the protocol and sends what
    /// the app prints to stderr instead, where irisrun shows it as logs, so call it before
    /// anything prints.
    public static func fromEnvironment() -> HostOptions {
        let environment = ProcessInfo.processInfo.environment
        let deviceOutput = environment["IRISRUN_DEVICE"] == "stdio" ? takeStandardOutput() : nil
        let frames = environment["IRISRUN_FRAMES"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let frames {
            try? FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        }
        return HostOptions(deviceOutput: deviceOutput, scale: scale, frames: frames)
    }

    /// IRISRUN_SCALE pixels per point, read once: by default 2 for a device, which is enough for
    /// the Device UI, and otherwise the phone's own (3 on an iPhone 14, 2 on an iPhone SE).
    public static let scale: Float = {
        let environment = ProcessInfo.processInfo.environment
        return environment["IRISRUN_SCALE"].flatMap { Float($0) } ?? (environment["IRISRUN_DEVICE"] == "stdio" ? 2 : IrisScreen.launch.scale)
    }()
}

/// The phone whose screen the app runs on. IRISRUN_SCREEN picks it when the app starts:
/// `iphone-14` (the default) or `iphone-se`; a device host takes another when the host asks for
/// its display (`DeviceHost`).
public struct IrisScreen: Equatable, Sendable {
    /// As Apple names the model.
    public var model: String
    /// In points, in portrait.
    public var size: CGSize
    /// How far the safe area is inside the top and bottom edges in portrait: below the status
    /// bar or the Dynamic Island, above the home indicator.
    public var safeTop, safeBottom: CGFloat
    /// Pixels per point of the phone's display.
    public var scale: Float

    public static let iPhone14 = IrisScreen(model: "iPhone 14", size: CGSize(width: 390, height: 844), safeTop: 47, safeBottom: 34, scale: 3)
    public static let iPhoneSE = IrisScreen(model: "iPhone SE (3rd generation)", size: CGSize(width: 375, height: 667), safeTop: 20, safeBottom: 0, scale: 2)
    /// The phones IRISRUN_SCREEN names.
    public static let named = ["iphone-14": iPhone14, "iphone-se": iPhoneSE]

    /// The phone IRISRUN_SCREEN names, read once.
    public static let launch: IrisScreen = {
        guard let name = ProcessInfo.processInfo.environment["IRISRUN_SCREEN"], !name.isEmpty else { return .iPhone14 }
        guard let screen = named[name.lowercased()] else {
            printError("irisrun: IRISRUN_SCREEN=\(name) names no phone (\(named.keys.sorted().joined(separator: ", "))); running on an iPhone 14")
            return .iPhone14
        }
        return screen
    }()

    /// The phone the app runs on: the one it launched on, until a host asks for another. Main
    /// thread only.
    public nonisolated(unsafe) static var current = launch
}

private func takeStandardOutput() -> FileHandle {
    fflush(nil)
    let protocolOutput = dup(STDOUT_FILENO)
    dup2(STDERR_FILENO, STDOUT_FILENO)
    return FileHandle(fileDescriptor: protocolOutput, closeOnDealloc: true)
}

/// Draws `irisScene` and writes it to `directory` as `frame-<number>.png`, then prints where,
/// with how long the step's update took.
public func writeFrame(number: Int, to directory: URL, updatedIn update: Duration) {
    let clock = ContinuousClock()
    var png: [UInt8]?
    let encode = clock.measure { png = irisScene.encode(.png) }
    let url = directory.appendingPathComponent(String(format: "frame-%03d.png", number))
    guard let png, FileManager.default.createFile(atPath: url.path, contents: Data(png)) else {
        printError("cannot write \(url.path)")
        exit(1)
    }
    print("frame: \(url.path) (update \(milliseconds(update)) ms, draw and PNG \(milliseconds(encode)) ms)")
}

/// Prints a line to stderr, which irisrun shows as the app's log.
public func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

public func milliseconds(_ duration: Duration) -> String {
    String(format: "%.1f", duration / .milliseconds(1))
}
