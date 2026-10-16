import Foundation
import IrisHost

/// The phone's screen, `IrisScreen.current` (an iPhone 14, 390 × 844 points, unless
/// IRISRUN_SCREEN or the host picks another), at the scale frames are drawn at.
@preconcurrency @MainActor
open class UIScreen: NSObject {
    private static let shared = UIScreen()

    open class var main: UIScreen {
        shared
    }

    open class var screens: [UIScreen] {
        [shared]
    }

    open var bounds: CGRect {
        CGRect(origin: .zero, size: IrisScreen.current.size)
    }

    /// Pixels per point of the frames: IRISRUN_SCALE, or 2 on a device and the phone's own in
    /// scripts.
    open var scale: CGFloat {
        CGFloat(HostOptions.scale)
    }

    open var nativeScale: CGFloat {
        scale
    }

    open var nativeBounds: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width * scale, height: bounds.height * scale)
    }
}
