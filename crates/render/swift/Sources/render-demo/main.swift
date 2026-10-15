// Draws the screens of examples/ios-swiftui (IrisSample) through the render
// core's C API and measures how fast frames come out.
//
// The layout is done by hand here, with iOS 18 metrics for an iPhone 16
// (393 × 852 points at 3x). In P1-13 OpenSwiftUI's display list drives the
// layers instead.
//
// usage: render-demo [output-directory]
// Fonts come from ${IRISRUN_HOME:-~/.irisrun}/fonts; see crates/render/fetch-fonts.sh.

import Foundation
import IrisRender

/// iOS system colors in light mode.
enum SystemColor {
    static let background: UInt32 = 0xFFFF_FFFF
    static let groupedBackground: UInt32 = 0xFFF2_F2F7
    static let label: UInt32 = 0xFF00_0000
    static let secondaryLabel: UInt32 = 0x993C_3C43
    static let separator: UInt32 = 0x4A3C_3C43
    static let chevron: UInt32 = 0xFFC4_C4C6
    static let blue: UInt32 = 0xFF00_7AFF
}

let screenWidth: Float = 393
let screenHeight: Float = 852
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
let environment = ProcessInfo.processInfo.environment
let home = environment["IRISRUN_HOME"] ?? (environment["HOME"] ?? NSHomeDirectory()) + "/.irisrun"

let scene = Scene(width: screenWidth, height: screenHeight, scale: 3)
for font in ["Inter.ttf", "InterItalic.ttf", "NotoSansSC.ttf"] {
    let path = home + "/fonts/" + font
    guard scene.addFont(path: path) else {
        fatalError("cannot load \(path); run crates/render/fetch-fonts.sh")
    }
}

/// A layer that fills a rectangle with a color.
@MainActor
func box(_ frame: Rect, color: UInt32, radius: Float = 0, in parent: Layer) -> Layer {
    let layer = Layer(in: scene)
    layer.frame = frame
    layer.backgroundColor = color
    layer.cornerRadius = radius
    parent.addSublayer(layer)
    return layer
}

/// A text layer sized to its text. `x` is the left edge, or the right edge
/// for trailing text.
@discardableResult
@MainActor
func text(_ string: String, _ style: TextStyle, x: Float, centerY: Float, width: Float? = nil, in parent: Layer) -> Layer {
    let layer = Layer(in: scene)
    let size = scene.measure(string, style: style, maxWidth: width ?? .infinity)
    let width = width ?? size.width
    let left = style.alignment == .trailing ? x - width : x
    layer.frame = Rect(x: left, y: centerY - size.height / 2, width: width, height: size.height)
    layer.setText(string, style: style)
    parent.addSublayer(layer)
    return layer
}

/// The status bar and home indicator, drawn above every screen.
@MainActor
func addSystemChrome(to root: Layer) {
    text("9:41", TextStyle(size: 17, weight: 600), x: 51, centerY: 31, in: root)
    let battery = box(Rect(x: 336, y: 25, width: 25, height: 12), color: 0, radius: 3.5, in: root)
    battery.setBorder(width: 1, color: 0x59000000)
    _ = box(Rect(x: 2, y: 2, width: 21, height: 8), color: SystemColor.label, radius: 2, in: battery)
    _ = box(Rect(x: (screenWidth - 134) / 2, y: screenHeight - 13, width: 134, height: 5), color: SystemColor.label, radius: 2.5, in: root)
}

/// ContentView: a navigation stack with an inset grouped list.
@MainActor
final class LibraryScreen {
    let view = Layer(in: scene)
    private let count: Layer
    private let countStyle = TextStyle(size: 17)

    init(books: [String]) {
        view.frame = Rect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        view.backgroundColor = SystemColor.groupedBackground
        text("Library", TextStyle(size: 34, weight: 700), x: 20, centerY: 122, in: view)

        let rowHeight: Float = 44
        let rows = books.count + 2
        let section = box(Rect(x: 20, y: 162, width: screenWidth - 40, height: Float(rows) * rowHeight), color: SystemColor.background, radius: 10, in: view)
        section.masksToBounds = true
        let right = section.frame.width - 20
        func row(_ index: Int) -> Float { Float(index) * rowHeight + rowHeight / 2 }

        count = text("Count: 0", countStyle, x: 20, centerY: row(0), in: section)
        text("Increment", TextStyle(size: 17, color: SystemColor.blue, alignment: .trailing), x: right, centerY: row(0), in: section)
        for (index, title) in books.enumerated() {
            text(title, TextStyle(size: 17), x: 20, centerY: row(index + 1), in: section)
            text("›", TextStyle(size: 22, weight: 500, color: SystemColor.chevron, alignment: .trailing), x: right, centerY: row(index + 1) - 1, in: section)
        }
        text("Add book", TextStyle(size: 17, color: SystemColor.blue), x: 20, centerY: row(rows - 1), in: section)
        for index in 1..<rows {
            _ = box(Rect(x: 20, y: Float(index) * rowHeight - 0.33, width: section.frame.width - 20, height: 0.33), color: SystemColor.separator, in: section)
        }
    }

    func setCount(_ value: Int) {
        count.setText("Count: \(value)", style: countStyle)
        count.frame.width = scene.measure("Count: \(value)", style: countStyle).width
    }
}

/// BookDetailView: a centered stack under an inline navigation bar.
@MainActor
final class DetailScreen {
    let view = Layer(in: scene)

    init(title: String) {
        view.frame = Rect(x: 0, y: 0, width: screenWidth, height: screenHeight)
        view.backgroundColor = SystemColor.background
        let barCenter: Float = 59 + 22
        text("‹", TextStyle(size: 30, weight: 500, color: SystemColor.blue), x: 10, centerY: barCenter - 2, in: view)
        text("Library", TextStyle(size: 17, color: SystemColor.blue), x: 28, centerY: barCenter, in: view)
        text(title, TextStyle(size: 17, weight: 600, alignment: .center), x: 100, centerY: barCenter, width: screenWidth - 200, in: view)

        // VStack(spacing: 16), centered between the bar and the home indicator.
        let lines: [(String, TextStyle)] = [
            (title, TextStyle(size: 28)),
            ("Not a favorite", TextStyle(size: 17, color: SystemColor.secondaryLabel)),
            ("Add to favorites", TextStyle(size: 17, color: SystemColor.blue)),
        ]
        let heights = lines.map { scene.measure($0.0, style: $0.1).height }
        var y = (103 + (screenHeight - 34) - heights.reduce(0, +) - 32) / 2
        for ((string, style), height) in zip(lines, heights) {
            let width = scene.measure(string, style: style).width
            text(string, style, x: (screenWidth - width) / 2, centerY: y + height / 2, in: view)
            y += height + 16
        }
    }
}

/// What the render core draws beyond the sample: scripts, weights, wrapping,
/// images, clipping, transforms and group opacity.
@MainActor
func typographyScreen(thumbnail: [UInt8]) -> Layer {
    let view = Layer(in: scene)
    view.frame = Rect(x: 0, y: 0, width: screenWidth, height: screenHeight)
    view.backgroundColor = SystemColor.background
    var y: Float = 90
    for (string, style) in [
        ("Tiếng Việt: ắ ằ ẳ ẵ ặ ơ ư đ Đ", TextStyle(size: 22, weight: 600)),
        ("中文 · 日本語のひらがな · カタカナ", TextStyle(size: 22)),
        ("Iris 100 · 400 · 700 · 900", TextStyle(size: 17, weight: 300)),
    ] {
        text(string, style, x: 20, centerY: y, in: view)
        y += 40
    }
    for (index, weight) in [100, 400, 700, 900].enumerated() {
        text("Aa", TextStyle(size: 28, weight: UInt16(weight)), x: 20 + Float(index) * 60, centerY: y, in: view)
    }
    y += 50

    let card = box(Rect(x: 20, y: y, width: screenWidth - 40, height: 120), color: 0xFFEE_F4FF, radius: 14, in: view)
    card.setBorder(width: 1, color: SystemColor.blue)
    let wrapped = "Xin chào! Đoạn văn này dài hơn ba dòng nên phải xuống dòng. Từ dòng thứ ba trở đi, phần còn lại bị cắt và thay bằng dấu ba chấm, giống lineLimit(3) của SwiftUI."
    text(wrapped, TextStyle(size: 15, maxLines: 3), x: 14, centerY: 60, width: card.frame.width - 28, in: card)
    y += 140

    let image = box(Rect(x: 20, y: y, width: 120, height: 260), color: 0, radius: 16, in: view)
    image.masksToBounds = true
    image.setBorder(width: 2, color: SystemColor.label)
    guard image.setImage(thumbnail) else { fatalError("the thumbnail does not decode") }

    let rotated = box(Rect(x: 190, y: y + 30, width: 150, height: 80), color: 0xFFFF_9500, radius: 12, in: view)
    let angle = Float.pi / 12
    rotated.transform = [cos(angle), sin(angle), -sin(angle), cos(angle), 0, 0]
    text("rotationEffect", TextStyle(size: 15, weight: 600, color: 0xFFFF_FFFF), x: 14, centerY: 40, in: rotated)

    let group = box(Rect(x: 190, y: y + 150, width: 150, height: 80), color: 0xFF34_C759, radius: 12, in: view)
    group.opacity = 0.5
    _ = box(Rect(x: 40, y: 20, width: 70, height: 40), color: 0xFF00_0000, radius: 8, in: group)
    return view
}

/// The render core's second round: text in runs, shadows, gradients, shapes,
/// masks, image placement and animations.
@MainActor
func effectsScreen() -> (view: Layer, card: Layer, badge: Layer) {
    let view = Layer(in: scene)
    view.frame = Rect(x: 0, y: 0, width: screenWidth, height: screenHeight)
    view.backgroundColor = SystemColor.groupedBackground

    let rich = "Đậm, nghiêng, gạch chân, gạch ngang và chữ nâng lên."
    func range(_ word: String) -> Range<Int> {
        let start = rich.utf8.distance(from: rich.startIndex, to: rich.range(of: word)!.lowerBound)
        return start ..< start + word.utf8.count
    }
    let line = Layer(in: scene)
    let runs = [
        TextRun(range("Đậm"), weight: 700),
        TextRun(range("nghiêng"), isItalic: true),
        TextRun(range("gạch chân"), color: SystemColor.blue, isUnderlined: true),
        TextRun(range("gạch ngang"), isStruckThrough: true),
        TextRun(range("nâng lên"), size: 12, baselineOffset: 6),
    ]
    let paragraph = ParagraphStyle(lineSpacing: 6)
    let metrics = scene.measure(rich, runs: runs, paragraph: paragraph, maxWidth: screenWidth - 40)
    line.frame = Rect(x: 20, y: 70, width: screenWidth - 40, height: metrics.height)
    line.setText(rich, runs: runs, paragraph: paragraph)
    view.addSublayer(line)

    let card = box(Rect(x: 20, y: 150, width: 160, height: 110), color: SystemColor.background, radius: 16, in: view)
    card.shadowColor = 0x4000_0000
    card.shadowOffset = Point(x: 0, y: 6)
    card.shadowRadius = 16
    text("Bóng đổ", TextStyle(size: 17, weight: 600), x: 16, centerY: 30, in: card)

    let gradient = box(Rect(x: 200, y: 150, width: 173, height: 110), color: 0, radius: 16, in: view)
    gradient.setGradient(Gradient(.linear(start: Point(x: 0, y: 0), end: Point(x: 173, y: 110)), colors: [0xFF00_7AFF, 0xFFAF_52DE]))
    text("Gradient", TextStyle(size: 17, weight: 600, color: 0xFFFF_FFFF), x: 16, centerY: 30, in: gradient)

    let radial = box(Rect(x: 20, y: 290, width: 110, height: 110), color: 0, in: view)
    radial.setGradient(Gradient(.radial(center: Point(x: 55, y: 55), startRadius: 0, endRadius: 55), colors: [0xFFFF_CC00, 0xFFFF_3B30, 0x00FF_3B30], locations: [0, 0.7, 1]))
    let conic = box(Rect(x: 142, y: 290, width: 110, height: 110), color: 0, radius: 55, in: view)
    conic.setGradient(Gradient(.conic(center: Point(x: 55, y: 55), startAngle: 0, endAngle: 2 * .pi), colors: [0xFFFF_3B30, 0xFFFF_CC00, 0xFF34_C759, 0xFF00_7AFF, 0xFFAF_52DE, 0xFFFF_3B30]))

    var star = Path()
    for index in 0 ..< 10 {
        let radius: Float = index % 2 == 0 ? 52 : 22
        let angle = Float(index) * .pi / 5 - .pi / 2
        let point = Point(x: 55 + radius * cos(angle), y: 55 + radius * sin(angle))
        if index == 0 { star.move(to: point) } else { star.addLine(to: point) }
    }
    star.closeSubpath()
    let shape = box(Rect(x: 264, y: 290, width: 110, height: 110), color: 0, in: view)
    shape.setShape(star, style: ShapeStyle(fill: 0xFFFF_CC00, stroke: 0xFF1C_1C1E, lineWidth: 3, lineJoin: .round, dashes: [8, 4]))

    // A 90 × 60 picture, red to blue across and darker down, in a circle
    // mask, then fit and fill.
    var pixels: [UInt8] = []
    for y in 0 ..< 60 {
        for x in 0 ..< 90 {
            pixels += [UInt8(x * 255 / 89), UInt8(150 - y * 2), UInt8(255 - x * 255 / 89), 255]
        }
    }
    var circle = Path()
    let k: Float = 0.5523 * 50 // cubic Bézier circle
    circle.move(to: Point(x: 100, y: 50))
    circle.addCurve(to: Point(x: 50, y: 100), control1: Point(x: 100, y: 50 + k), control2: Point(x: 50 + k, y: 100))
    circle.addCurve(to: Point(x: 0, y: 50), control1: Point(x: 50 - k, y: 100), control2: Point(x: 0, y: 50 + k))
    circle.addCurve(to: Point(x: 50, y: 0), control1: Point(x: 0, y: 50 - k), control2: Point(x: 50 - k, y: 0))
    circle.addCurve(to: Point(x: 100, y: 50), control1: Point(x: 50 + k, y: 0), control2: Point(x: 100, y: 50 - k))
    circle.closeSubpath()
    for (index, mode) in [ContentMode.scaleAspectFill, .scaleAspectFit, .scaleAspectFill].enumerated() {
        let image = box(Rect(x: 20 + Float(index) * 122, y: 430, width: 100, height: 100), color: 0xFFFF_FFFF, radius: 12, in: view)
        image.contentMode = mode
        image.setImage(rgba: pixels, width: 90, height: 60, rowBytes: 90 * 4, premultiplied: false)
        if index == 0 { image.mask = circle } else { image.masksToBounds = index == 2 }
    }

    let badge = box(Rect(x: 20, y: 560, width: 120, height: 44), color: 0xFF34_C759, radius: 22, in: view)
    text("Animation", TextStyle(size: 15, weight: 600, color: 0xFFFF_FFFF), x: 18, centerY: 22, in: badge)
    return (view, card, badge)
}

@MainActor
func save(_ name: String, _ format: ImageFormat) -> [UInt8] {
    guard let data = scene.encode(format) else { fatalError("cannot encode \(name)") }
    _ = FileManager.default.createFile(atPath: output.appendingPathComponent(name).path, contents: Data(data))
    return data
}

/// Calls `frame` for each frame, encoding each as JPEG, and prints the rate.
@MainActor
func measure(_ name: String, frames: Int, _ frame: (Int) -> Void) {
    let clock = ContinuousClock()
    var bytes = 0
    let elapsed = clock.measure {
        for index in 0..<frames {
            frame(index)
            bytes += scene.encode(.jpeg)?.count ?? 0
        }
    }
    let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    let perFrame = seconds * 1000 / Double(frames)
    print(String(format: "%@: %d frames, %.1f ms/frame, %.0f fps, %d KB/frame", name, frames, perFrame, 1000 / perFrame, bytes / frames / 1024))
}

// Screens below, the status bar and home indicator above.
let screens = box(Rect(x: 0, y: 0, width: screenWidth, height: screenHeight), color: 0, in: scene.root)
let chrome = box(Rect(x: 0, y: 0, width: screenWidth, height: screenHeight), color: 0, in: scene.root)
addSystemChrome(to: chrome)

let books = ["Dế Mèn phiêu lưu ký", "Truyện Kiều"]
let library = LibraryScreen(books: books)
screens.addSublayer(library.view)
let thumbnail = save("library.png", .png)

measure("same frame", frames: 30) { _ in }
measure("counter", frames: 60) { library.setCount($0 + 1) }
_ = save("library-counter.jpg", .jpeg)

// NavigationLink push: the detail slides in from the right while the list
// moves a third of the way out, over 0.35 s at 60 fps.
let detail = DetailScreen(title: books[0])
detail.view.frame.x = screenWidth
screens.addSublayer(detail.view)
measure("push transition", frames: 21) { index in
    let t = Float(index + 1) / 21
    let eased = 1 - (1 - t) * (1 - t) * (1 - t)
    detail.view.frame.x = screenWidth * (1 - eased)
    library.view.frame.x = -screenWidth / 3 * eased
    if index == 10 { _ = save("push-midway.jpg", .jpeg) }
}
_ = save("detail.png", .png)

detail.view.removeFromSuperlayer()
library.view.removeFromSuperlayer()
let typography = typographyScreen(thumbnail: thumbnail)
screens.addSublayer(typography)
_ = save("typography.png", .png)

typography.removeFromSuperlayer()
let effects = effectsScreen()
screens.addSublayer(effects.view)
// The chrome layer covers the screen, and hit-testing finds plain layers too.
chrome.isHidden = true
precondition(scene.hitTest(Point(x: 100, y: 200)) === effects.card, "the card is front-most there")
chrome.isHidden = false
_ = save("effects.png", .png)

// The badge slides right and fades out and back in, over 0.6 s of the
// scene's clock at 60 fps; the layer keeps its own values meanwhile.
let start = effects.badge.frame
effects.badge.add(Animation(from: .frame(start), to: .frame(Rect(x: 253, y: start.y, width: start.width, height: start.height)), duration: 0.6, timing: .easeInEaseOut))
effects.badge.add(Animation(from: .opacity(1), to: .opacity(0.2), duration: 0.3, timing: .linear, autoreverses: true))
var animationFrames = 0
measure("animation", frames: 37) { index in
    scene.time = Double(index) / 60
    animationFrames += scene.isAnimating ? 1 : 0
    if index == 18 { _ = save("animation-midway.jpg", .jpeg) }
}
precondition(animationFrames == 36 && !scene.isAnimating, "the animations end after 0.6 s")

// Frames encoded on other threads while the next one renders.
let clock = ContinuousClock()
let group = DispatchGroup()
let encodedFrames = 30
let pipelined = clock.measure {
    for index in 0 ..< encodedFrames {
        effects.card.frame.y = 150 + Float(index)
        let frame = scene.render()
        DispatchQueue.global().async(group: group) { _ = frame.encode(.jpeg) }
    }
    group.wait()
}
let milliseconds = Double(pipelined.components.attoseconds) / 1e15 + Double(pipelined.components.seconds) * 1000
print(String(format: "encoded on other threads: %d frames, %.1f ms/frame, %.0f fps", encodedFrames, milliseconds / Double(encodedFrames), Double(encodedFrames) * 1000 / milliseconds))
print("frames written to \(output.path)")
