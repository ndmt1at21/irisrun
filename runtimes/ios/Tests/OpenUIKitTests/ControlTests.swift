import Foundation
import IrisHost
import IrisRender
@testable import OpenUIKit
import Testing

// Buttons, switches, sliders, segmented controls, progress views and image views, driven by
// touches through `TouchInput` as on a phone.

/// The events a control sent, by name.
@MainActor
private func record(_ control: UIControl, _ events: UIControl.Event...) -> () -> [String] {
    var sent: [String] = []
    let names: [(UIControl.Event, String)] = [(.touchUpInside, "up"), (.primaryActionTriggered, "primary"), (.valueChanged, "changed")]
    for (event, name) in names where events.contains(event) {
        control.addAction(UIAction { _ in sent.append(name) }, for: event)
    }
    return { sent }
}

@MainActor @Test func buttonsLayOutTitleAndImageWithInsets() throws {
    makeScene()
    let button = UIButton(type: .system)
    let image = UIImage(systemName: "plus.circle")!
    button.setTitle("Add", for: .normal)
    button.setImage(image, for: .normal)
    let title = try #require(button.titleLabel).intrinsicContentSize
    // Side by side, with 6 points above and below the title when there are no insets.
    #expect(button.intrinsicContentSize == CGSize(width: ceil(22 + title.width), height: ceil(max(22, title.height + 12))))
    button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    #expect(button.intrinsicContentSize == CGSize(width: ceil(22 + title.width + 20), height: ceil(max(22, title.height) + 8)))

    // Centered as a pair; edge insets move each by half their difference.
    let content = CGRect(x: 0, y: 0, width: 200, height: 44)
    let imageRect = button.imageRect(forContentRect: content)
    let titleRect = button.titleRect(forContentRect: content)
    #expect(abs(imageRect.minX - (100 - (22 + title.width) / 2)) < 0.01 && titleRect.minX == imageRect.maxX)
    #expect(abs(imageRect.midY - 22) < 0.01 && abs(titleRect.midY - 22) < 0.01)
    button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
    button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
    #expect(button.imageRect(forContentRect: content).minX == imageRect.minX - 4)
    #expect(button.titleRect(forContentRect: content).minX == titleRect.minX + 4)
    button.contentHorizontalAlignment = .left
    #expect(button.imageRect(forContentRect: content).minX == -4)

    // Titles per state fall back to the normal one; system titles are in the tint.
    button.setTitle("Selected", for: .selected)
    button.isSelected = true
    #expect(button.currentTitle == "Selected" && button.titleLabel?.text == "Selected")
    button.isSelected = false
    #expect(button.currentTitle == "Add" && button.currentTitleColor == button.tintColor)
    button.isEnabled = false
    #expect(button.currentTitleColor == .tertiaryLabel)
    #expect(UIButton().currentTitleColor == .white, "custom buttons have white titles")
    #expect(UIButton(type: .close).frame.size == CGSize(width: 30, height: 30) && UIButton(type: .contactAdd).frame.size == CGSize(width: 22, height: 22))
}

@MainActor @Test func buttonsSendTheirPrimaryActionAndFadeWhileTouched() throws {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let button = UIButton(type: .system, primaryAction: UIAction(title: "Go") { _ in })
    button.frame = CGRect(x: 100, y: 100, width: 100, height: 44)
    screen.root.addSubview(button)
    #expect(button.currentTitle == "Go")
    let sent = record(button, .touchUpInside, .primaryActionTriggered)
    screen.touch(.began, 150, 120)
    #expect(button.isHighlighted && abs((button.titleLabel?.alpha ?? 1) - 0.2) < 0.001)
    screen.touch(.ended, 150, 120)
    #expect(sent() == ["up", "primary"] && button.titleLabel?.alpha == 1)

    button.changesSelectionAsPrimaryAction = true
    screen.tap(150, 120)
    #expect(button.isSelected)
    screen.tap(150, 120)
    #expect(!button.isSelected)
}

@MainActor @Test func configurationsLayOutTheirPartsAndColors() throws {
    makeScene()
    var configuration = UIButton.Configuration.filled()
    configuration.title = "Filled"
    configuration.image = UIImage(systemName: "plus.circle")
    configuration.imagePadding = 8
    let button = UIButton(configuration: configuration)
    let title = try #require(button.titleLabel).intrinsicContentSize
    // Medium buttons: 17-point titles, 12 points left and right and 7 above and below.
    #expect(button.titleLabel?.font.pointSize == 17)
    #expect(button.intrinsicContentSize == CGSize(width: ceil(12 + 22 + 8 + title.width + 12), height: ceil(7 + max(22, title.height) + 7)))
    button.frame = CGRect(origin: .zero, size: button.intrinsicContentSize)
    button.layoutIfNeeded()
    #expect(abs(button.imageView!.frame.minX - 12) < 0.5 && abs(button.titleLabel!.frame.minX - 42) < 0.5)

    // Images on top stack above the title; a subtitle goes under the title.
    button.configuration?.imagePlacement = .top
    button.configuration?.subtitle = "Subtitle"
    button.configuration?.titlePadding = 4
    button.layoutIfNeeded()
    let subtitle = try #require(button.subtitleLabel)
    #expect(button.imageView!.frame.maxY + 8 == button.titleLabel!.frame.minY)
    #expect(button.titleLabel!.frame.maxY + 4 == subtitle.frame.minY && subtitle.font.pointSize == 15)

    // Filled is white on the tint, faded while highlighted, gray when disabled.
    let tint = button.tintColor!
    #expect(configuration.colors(tint: tint, state: .normal) == (.white, tint))
    let pressed = configuration.colors(tint: tint, state: .highlighted)
    #expect(pressed.background?.cgColor.alpha == 0.75)
    #expect(configuration.colors(tint: tint, state: .disabled) == (.tertiaryLabel, .tertiarySystemFill))
    #expect(UIButton.Configuration.plain().colors(tint: tint, state: .normal) == (tint, nil))

    // The update handler runs when the state changes, before the button is laid out.
    var states: [UIControl.State] = []
    button.configurationUpdateHandler = { button in
        states.append(button.state)
        button.configuration?.title = button.isHighlighted ? "Pressed" : "Filled"
    }
    button.layoutIfNeeded()
    button.isHighlighted = true
    button.layoutIfNeeded()
    #expect(states == [.normal, .highlighted] && button.titleLabel?.text == "Pressed")
}

@MainActor @Test func switchesFlipByTapAndDrag() {
    let screen = Screen()
    defer { screen.close() }
    let toggle = UISwitch(frame: CGRect(x: 100, y: 100, width: 200, height: 100))
    #expect(toggle.frame.size == CGSize(width: 51, height: 31))
    screen.root.addSubview(toggle)
    let sent = record(toggle, .valueChanged, .primaryActionTriggered)
    screen.tap(110, 115)
    #expect(toggle.isOn && sent() == ["primary", "changed"])
    // Dragging the knob to the other half leaves the switch there.
    screen.drag(from: CGPoint(x: 140, y: 115), to: CGPoint(x: 105, y: 115))
    #expect(!toggle.isOn && sent().count == 4)
    screen.drag(from: CGPoint(x: 105, y: 115), to: CGPoint(x: 112, y: 115))
    #expect(!toggle.isOn && sent().count == 4, "still on the off half")
    toggle.setOn(true, animated: true)
    #expect(toggle.isOn && sent().count == 4, "only the user's changes are sent")
}

@MainActor @Test func slidersFollowTheThumb() {
    let screen = Screen()
    defer { screen.close() }
    let slider = UISlider(frame: CGRect(x: 0, y: 100, width: 228, height: 31))
    slider.maximumValue = 100
    slider.value = 150
    #expect(slider.value == 100, "kept in the range")
    slider.value = 0
    screen.root.addSubview(slider)
    let sent = record(slider, .valueChanged)
    // The thumb has 200 points to travel: 50 points is a quarter of the range.
    screen.drag(from: CGPoint(x: 14, y: 115), to: CGPoint(x: 64, y: 115))
    #expect(abs(slider.value - 25) < 0.01 && sent().count == 10)
    // Touching the track away from the thumb does nothing.
    screen.drag(from: CGPoint(x: 200, y: 115), to: CGPoint(x: 220, y: 115))
    #expect(abs(slider.value - 25) < 0.01)
    slider.isContinuous = false
    screen.drag(from: CGPoint(x: 64, y: 115), to: CGPoint(x: 264, y: 115))
    #expect(slider.value == 100 && sent().count == 11, "one event when the drag ends")
}

@MainActor @Test func segmentedControlsSelectByTap() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let control = UISegmentedControl(items: ["One", "Two", "Three"])
    #expect(control.numberOfSegments == 3 && control.selectedSegmentIndex == UISegmentedControl.noSegment)
    #expect(control.frame.height == 32 && control.frame.width > 0)
    control.frame = CGRect(x: 0, y: 100, width: 300, height: 32)
    screen.root.addSubview(control)
    let sent = record(control, .valueChanged)
    screen.tap(150, 116)
    #expect(control.selectedSegmentIndex == 1 && sent() == ["changed"])
    screen.tap(150, 116)
    #expect(sent().count == 1, "the selected segment again changes nothing")
    control.insertSegment(withTitle: "Zero", at: 0, animated: false)
    #expect(control.selectedSegmentIndex == 2 && control.titleForSegment(at: 2) == "Two")
    control.removeSegment(at: 2, animated: false)
    #expect(control.selectedSegmentIndex == UISegmentedControl.noSegment)

    var picked: [String] = []
    let actions = UISegmentedControl(frame: CGRect(x: 0, y: 200, width: 200, height: 32), actions: [
        UIAction(title: "Left") { _ in picked.append("left") }, UIAction(title: "Right") { _ in picked.append("right") },
    ])
    screen.root.addSubview(actions)
    screen.tap(150, 216)
    #expect(picked == ["right"] && actions.selectedSegmentIndex == 1)
    actions.isMomentary = true
    screen.tap(150, 216)
    #expect(picked == ["right", "right"], "momentary segments act every time")
}

@MainActor @Test func progressAndActivityViewsShowTheirState() {
    let progress = UIProgressView(progressViewStyle: .default)
    progress.frame = CGRect(x: 0, y: 0, width: 200, height: 4)
    progress.setProgress(1.5, animated: false)
    #expect(progress.progress == 1 && progress.intrinsicContentSize.height == 4)
    progress.progress = 0.25
    progress.layoutIfNeeded()
    #expect(progress.layer.sublayers?.first?.sublayers?.first?.frame.width == 50)

    let spinner = UIActivityIndicatorView(style: .large)
    #expect(spinner.frame.size == CGSize(width: 37, height: 37) && spinner.isHidden && !spinner.isAnimating)
    spinner.startAnimating()
    #expect(!spinner.isHidden && spinner.isAnimating && spinner.layer.sublayers?.allSatisfy { !$0.irisAnimations.isEmpty } == true)
    spinner.stopAnimating()
    #expect(spinner.isHidden && spinner.layer.sublayers?.allSatisfy(\.irisStopsAnimations) == true)
}

@MainActor @Test func imageViewsPlaceAndTintImages() throws {
    // Content modes become gravities with top and bottom swapped, as in Core Animation.
    let view = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    view.contentMode = .top
    #expect(view.layer.contentsGravity == .bottom && CALayerContentsGravity.bottom.contentMode == .top)
    view.contentMode = .bottomLeft
    #expect(view.layer.contentsGravity == .topLeft && CALayerContentsGravity.topLeft.contentMode == .bottomLeft)
    let size = CGSize(width: 20, height: 10)
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
    #expect(UIView.ContentMode.scaleAspectFit.rect(for: size, in: bounds) == CGRect(x: 0, y: 0, width: 100, height: 50))
    #expect(UIView.ContentMode.scaleAspectFill.rect(for: CGSize(width: 10, height: 10), in: bounds) == CGRect(x: 0, y: -25, width: 100, height: 100))
    #expect(UIView.ContentMode.bottomRight.rect(for: size, in: bounds) == CGRect(x: 80, y: 40, width: 20, height: 10))

    // Template images take the tint, which comes down from the superview, dimmed if asked.
    final class TintWatcher: UIView {
        var changes = 0
        override func tintColorDidChange() { changes += 1 }
    }
    let parent = UIView()
    let watcher = TintWatcher()
    parent.addSubview(watcher)
    watcher.addSubview(view)
    #expect(view.tintColor == .systemBlue)
    let image = try #require(UIImage(systemName: "info.circle"))
    view.image = image.withRenderingMode(.alwaysOriginal)
    #expect(view.layer.irisContentsTint == nil && view.intrinsicContentSize == CGSize(width: 22, height: 22))
    view.image = image
    view.layoutIfNeeded()
    let changes = watcher.changes
    parent.tintColor = .systemPink
    #expect(watcher.changes == changes + 1 && view.tintColor == .systemPink)
    if case let .shape(_, style)? = view.layer.irisDrawing?.content {
        #expect(style.stroke == UIColor.systemPink.cgColor.argb, "symbols draw in the tint")
    } else {
        Issue.record("a symbol draws its strokes")
    }
    parent.tintAdjustmentMode = .dimmed
    #expect(view.tintColor.cgColor.numberOfComponents == 2, "a dimmed tint is gray")
}
