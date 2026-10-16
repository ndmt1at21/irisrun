import Foundation
import IrisHost
@testable import OpenUIKit
import Testing

// Text fields and text views with the host's input method, the keyboard, scroll views and alerts.

/// The first view in a tree whose label or value reads `text`.
@MainActor
func view(_ text: String, in root: UIView) -> UIView? {
    if !root.isHidden, root.accessibilityLabel == text || root.accessibilityValue == text { return root }
    return root.subviews.lazy.compactMap { view(text, in: $0) }.first
}

@MainActor
private final class FieldDelegate: NSObject, UITextFieldDelegate {
    var log: [String] = []
    var maximumLength = Int.max

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        log.append("shouldBegin")
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        log.append("didBegin")
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        log.append("change \(range.location),\(range.length) \(string)")
        return (textField.text ?? "").utf16.count - range.length + string.utf16.count <= maximumLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        log.append("return")
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        log.append("didEnd")
    }
}

@MainActor @Test func textFieldsTakeComposedTextThroughTheirDelegate() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let field = UITextField(frame: CGRect(x: 20, y: 100, width: 300, height: 34))
    field.borderStyle = .roundedRect
    field.placeholder = "Tên"
    let delegate = FieldDelegate()
    field.delegate = delegate
    var events: [String] = []
    field.addAction(UIAction { _ in events.append("began") }, for: .editingDidBegin)
    field.addAction(UIAction { _ in events.append(field.text ?? "") }, for: .editingChanged)
    field.addAction(UIAction { _ in events.append("ended") }, for: .editingDidEnd)
    screen.root.addSubview(field)

    screen.tap(170, 117)
    #expect(field.isFirstResponder && field.isEditing && delegate.log == ["shouldBegin", "didBegin"])
    // Telex: the input method composes, then commits; the marked text is in the text meanwhile.
    screen.input.compose("Vi")
    screen.input.compose("Việ")
    #expect(field.text == "Việ" && field.markedTextRange.map { field.offset(from: $0.start, to: $0.end) } == 3)
    screen.input.commit("Việt")
    #expect(field.text == "Việt" && field.markedTextRange == nil)
    #expect(delegate.log.suffix(3) == ["change 0,0 Vi", "change 0,2 Việ", "change 0,3 Việt"])
    // Ranges count UTF-16 code units and keep characters whole.
    screen.input.commit(" 👋")
    #expect(delegate.log.last == "change 4,0  👋")
    screen.input.press("Backspace", command: false)
    #expect(field.text == "Việt " && delegate.log.last == "change 5,2 ")
    // The delegate refuses what would be too long.
    delegate.maximumLength = 6
    screen.input.commit("Nam")
    #expect(field.text == "Việt ")
    #expect(events == ["began", "Vi", "Việ", "Việt", "Việt 👋", "Việt "])
    // The caret follows the text and a tap moves it.
    field.layoutIfNeeded()
    let end = field.caretRect(for: field.endOfDocument)
    #expect(end.minX > 40 && end.maxX < 300 && end.height > 18)
    screen.tap(30, 117)
    #expect(field.selectedTextRange.map { field.offset(from: field.beginningOfDocument, to: $0.start) } == 0)
    #expect(view("Tên", in: field) == nil, "the placeholder hides while there is text")

    // Return asks the delegate, and ends editing only for an editingDidEndOnExit target.
    screen.input.press("Enter", command: false)
    #expect(delegate.log.last == "return" && field.isFirstResponder && field.text == "Việt ")
    field.addAction(UIAction { _ in events.append("exit") }, for: .editingDidEndOnExit)
    screen.input.press("Enter", command: false)
    #expect(!field.isFirstResponder && delegate.log.suffix(2) == ["return", "didEnd"] && events.suffix(2) == ["exit", "ended"])
}

@MainActor @Test func secureFieldsShowBulletsAndStartOverWhenEditedAgain() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    let field = UITextField(frame: CGRect(x: 20, y: 100, width: 300, height: 34))
    field.isSecureTextEntry = true
    let delegate = FieldDelegate()
    field.delegate = delegate
    screen.root.addSubview(field)
    field.becomeFirstResponder()
    screen.input.commit("mật")
    #expect(field.text == "mật" && field.accessibilityValue == "•••")
    field.resignFirstResponder()
    field.becomeFirstResponder()
    screen.input.commit("k")
    #expect(field.text == "k" && delegate.log.last == "change 0,3 k", "typing again replaces all of it")
    screen.input.commit("hẩu")
    #expect(field.text == "khẩu", "only the first edit starts over")
}

@MainActor @Test func theKeyboardFollowsTheFirstResponder() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    UIResponder.first = nil
    Keyboard.update()
    final class Heard: @unchecked Sendable {
        var names: [String] = []
        var frames: [CGRect] = []
    }
    let heard = Heard()
    let names: [Notification.Name] = [UIResponder.keyboardWillShowNotification, UIResponder.keyboardDidShowNotification, UIResponder.keyboardWillHideNotification, UIResponder.keyboardDidHideNotification]
    let observers = names.map { name in
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
            heard.names.append(notification.name.rawValue.replacingOccurrences(of: "UIKeyboard", with: "").replacingOccurrences(of: "Notification", with: ""))
            heard.frames.append((notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .null)
        }
    }
    defer { observers.forEach(NotificationCenter.default.removeObserver) }
    let first = UITextField(frame: CGRect(x: 20, y: 100, width: 300, height: 34))
    let second = UITextField(frame: CGRect(x: 20, y: 150, width: 300, height: 34))
    screen.root.addSubview(first)
    screen.root.addSubview(second)
    first.becomeFirstResponder()
    Keyboard.update()
    // Moving to the next field keeps the keyboard up.
    second.becomeFirstResponder()
    Keyboard.update()
    #expect(heard.names == ["WillShow", "DidShow"] && heard.frames.allSatisfy { $0 == CGRect(x: 0, y: 844, width: 390, height: 0) })
    // endEditing(true) ends editing even when the delegate would refuse; leaving the window too.
    final class Stubborn: NSObject, UITextFieldDelegate {
        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool { false }
    }
    let stubborn = Stubborn()
    second.delegate = stubborn
    #expect(!screen.root.endEditing(false) && second.isFirstResponder)
    screen.root.endEditing(true)
    Keyboard.update()
    #expect(!second.isFirstResponder && heard.names.suffix(2) == ["WillHide", "DidHide"])
    first.becomeFirstResponder()
    first.removeFromSuperview()
    #expect(!first.isFirstResponder && UIResponder.first == nil)
}

@MainActor @Test func textViewsEditLinesAndScrollToTheCaret() {
    makeScene()
    let screen = Screen()
    defer { screen.close() }
    final class Delegate: NSObject, UITextViewDelegate {
        var changes = 0
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // No blank lines.
            !(text == "\n" && textView.text.hasSuffix("\n"))
        }

        func textViewDidChange(_ textView: UITextView) {
            changes += 1
        }
    }
    let delegate = Delegate()
    let textView = UITextView(frame: CGRect(x: 20, y: 100, width: 200, height: 70))
    textView.font = .systemFont(ofSize: 17)
    textView.delegate = delegate
    screen.root.addSubview(textView)
    screen.tap(100, 130)
    #expect(textView.isFirstResponder)
    for line in ["một", "hai", "ba", "bốn"] {
        screen.input.commit(line)
        screen.input.press("Enter", command: false)
        screen.input.press("Enter", command: false)
    }
    #expect(textView.text == "một\nhai\nba\nbốn\n" && delegate.changes == 8)
    screen.input.press("ArrowUp", command: false)
    screen.input.press("End", command: false)
    #expect(textView.selectedRange == NSRange(location: 14, length: 0))
    textView.layoutIfNeeded()
    // Five lines of 17-point text and the insets don't fit in 70 points: the caret's line shows.
    #expect(textView.contentSize.height > 100 && textView.contentOffset.y > 0)
    let caret = textView.caretRect(for: textView.selectedTextRange!.end)
    #expect(caret.minY >= textView.contentOffset.y && caret.maxY <= textView.contentOffset.y + 70)
}

@Test func scrollViewsMoveByUIKitsNumbers() {
    #expect(abs(ScrollMotion.rubberBand(100, dimension: 400) - 48.35) < 0.01)
    #expect(abs(ScrollMotion.distance(velocity: CGPoint(x: 0, y: 1000), rate: 0.998).y - 499) < 0.01)
    #expect(ScrollMotion.page(from: 0, at: 150, velocity: 0, size: 390) == 0)
    #expect(ScrollMotion.page(from: 0, at: 150, velocity: 500, size: 390) == 390)
    #expect(ScrollMotion.page(from: 390, at: 1000, velocity: 2000, size: 390) == 780, "one page at a time")
    // A fling slows to its target; a spring settles.
    let fling = ScrollMotion(from: .zero, to: CGPoint(x: 0, y: 499), velocity: CGPoint(x: 0, y: 1000), kind: .decelerate(rate: 0.998))
    #expect(abs(fling.offset(at: 0.001).0.y - 1) < 0.01, "a thousand points a second at first")
    #expect(fling.offset(at: 4).1)
    let spring = ScrollMotion(from: CGPoint(x: 0, y: -80), to: .zero, kind: .spring)
    #expect(spring.offset(at: 0.2).0.y > -80 && spring.offset(at: 0.2).0.y < 0 && spring.offset(at: 1).1)
}

@MainActor
private final class ScrollLog: NSObject, UIScrollViewDelegate {
    var log: [String] = []
    var scrolls = 0

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrolls += 1
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        log.append("willBeginDragging")
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        log.append("willEndDragging \(Int(velocity.y.rounded())) \(Int(targetContentOffset.pointee.y))")
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        log.append("didEndDragging \(decelerate)")
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        log.append("willBeginDecelerating")
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        log.append("didEndDecelerating \(Int(scrollView.contentOffset.y))")
    }
}

@MainActor @Test func scrollViewsDragFlingAndBounce() {
    let screen = Screen()
    defer { screen.close() }
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 100, width: 390, height: 600))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    let log = ScrollLog()
    scrollView.delegate = log
    // Apps observe the offset with KVO.
    final class Offsets: @unchecked Sendable {
        var values: [CGFloat] = []
    }
    let offsets = Offsets()
    let observation = scrollView.observe(\.contentOffset, options: [.new]) { _, change in
        offsets.values.append(change.newValue?.y ?? -1)
    }
    defer { observation.invalidate() }
    var taps = 0
    let button = UIControl(frame: CGRect(x: 20, y: 20, width: 100, height: 44))
    button.addAction(UIAction { _ in taps += 1 }, for: .touchUpInside)
    scrollView.addSubview(button)
    screen.root.addSubview(scrollView)
    #expect(scrollView.adjustedContentInset == .zero, "clear of the safe area")

    // A tap on a control inside still reaches it, once the scroll view lets the touch go.
    screen.tap(70, 142)
    #expect(taps == 1 && scrollView.contentOffset == .zero)
    // A drag that rests before lifting moves the content as far as the finger, and stops.
    func drag(_ from: CGFloat, _ to: CGFloat, rest: Bool) {
        screen.touch(.began, 200, from, after: 1)
        for step in 1 ... 10 {
            screen.touch(.moved, 200, from + (to - from) * CGFloat(step) / 10)
        }
        if rest {
            screen.touch(.stationary, 200, to, after: 0.25)
        }
        screen.touch(.ended, 200, to)
    }
    drag(500, 300, rest: true)
    #expect(scrollView.contentOffset.y == 200 && !scrollView.isDragging && !scrollView.isDecelerating)
    #expect(offsets.values.last == 200 && log.scrolls == offsets.values.count)
    #expect(log.log == ["willBeginDragging", "willEndDragging 0 200", "didEndDragging false"])
    // A fling goes on, slowing, up to the end of the content; a script shows where it ends.
    log.log = []
    drag(600, 100, rest: false)
    #expect(log.log == ["willBeginDragging", "willEndDragging 3 1400", "didEndDragging true", "willBeginDecelerating", "didEndDecelerating 1400"])
    #expect(scrollView.contentOffset.y == 1400 && taps == 1)
    // Past the start, the content stretches, then springs back.
    scrollView.setContentOffset(.zero, animated: false)
    screen.touch(.began, 200, 300, after: 1)
    for step in 1 ... 10 {
        screen.touch(.moved, 200, 300 + 30 * CGFloat(step))
    }
    #expect(scrollView.contentOffset.y < 0 && scrollView.contentOffset.y > -300, "stretched")
    screen.touch(.stationary, 200, 600, after: 0.25)
    screen.touch(.ended, 200, 600)
    #expect(scrollView.contentOffset.y == 0)
    // A drag along an axis the content can't scroll leaves the content alone.
    screen.touch(.began, 300, 400, after: 1)
    screen.touch(.moved, 100, 402)
    screen.touch(.ended, 100, 402)
    #expect(scrollView.contentOffset == .zero)
}

@MainActor @Test func pagingScrollViewsStopOnPages() {
    let screen = Screen()
    defer { screen.close() }
    let scrollView = UIScrollView(frame: CGRect(x: 0, y: 100, width: 390, height: 300))
    scrollView.contentSize = CGSize(width: 390 * 3, height: 300)
    scrollView.isPagingEnabled = true
    screen.root.addSubview(scrollView)
    // A short drag that rests goes back; a flick goes to the next page.
    screen.touch(.began, 300, 200, after: 1)
    for step in 1 ... 10 {
        screen.touch(.moved, 300 - 10 * CGFloat(step), 200)
    }
    screen.touch(.stationary, 200, 200, after: 0.25)
    screen.touch(.ended, 200, 200)
    #expect(scrollView.contentOffset.x == 0)
    screen.drag(from: CGPoint(x: 300, y: 200), to: CGPoint(x: 200, y: 200))
    #expect(scrollView.contentOffset.x == 390)
}

extension OnScreen {
    @Test func alertsShowTheirActionsAndRunTheHandlerOnceDismissed() async throws {
        makeScene()
        let screen = Screen()
        defer { screen.close() }
        let controller = UIViewController()
        screen.window.rootViewController = controller
        let alert = UIAlertController(title: "Xin chào, Việt!", message: "Bạn đã đăng nhập.", preferredStyle: .alert)
        var handled: [String] = []
        alert.addAction(UIAlertAction(title: "Đóng", style: .default) { _ in
            handled.append("close, presented: \(controller.presentedViewController != nil)")
        })
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel) { _ in handled.append("cancel") })
        alert.addTextField { $0.placeholder = "Ghi chú" }
        controller.present(alert, animated: true)
        #expect(controller.presentedViewController === alert && alert.presentingViewController === controller)
        #expect(alert.textFields?.first?.isFirstResponder == true, "the first field takes the keyboard")
        alert.view.layoutIfNeeded()
        // A 270-point card in the middle, cancel on the left of two buttons.
        let close = view("Đóng", in: alert.view)!.superview!
        let cancel = view("Huỷ", in: alert.view)!.superview!
        let card = close.superview!
        #expect(card.frame.width == 270 && abs(card.frame.midX - 195) < 0.5 && abs(card.frame.midY - 422) < 0.5)
        #expect(cancel.frame.minX == 0 && close.frame.minX == 135 && close.frame.height == 44)
        let center = close.convert(CGPoint(x: close.bounds.midX, y: close.bounds.midY), to: nil)
        screen.tap(center.x, center.y)
        // A script shows the alert gone at once; the handler runs once the dismissal is over.
        #expect(alert.viewIfLoaded?.window == nil && handled.isEmpty)
        try await Task.sleep(for: .milliseconds(10))
        #expect(handled == ["close, presented: false"] && controller.presentedViewController == nil)

        // An action sheet sits on the bottom of the safe area, its cancel button apart; a tap
        // outside cancels it.
        let sheet = UIAlertController(title: nil, message: "Xoá ghi chú?", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Huỷ bỏ", style: .cancel) { _ in handled.append("sheet cancel") })
        sheet.addAction(UIAlertAction(title: "Xoá", style: .destructive))
        controller.present(sheet, animated: false)
        sheet.view.layoutIfNeeded()
        let delete = view("Xoá", in: sheet.view)!
        let cancelSheet = view("Huỷ bỏ", in: sheet.view)!.superview!.superview!
        #expect((delete as? UILabel)?.textColor == .systemRed && delete.superview!.frame.height == 57)
        #expect(cancelSheet.frame == CGRect(x: 8, y: 844 - 34 - 57, width: 374, height: 57))
        screen.tap(195, 200)
        try await Task.sleep(for: .milliseconds(10))
        #expect(handled.last == "sheet cancel" && controller.presentedViewController == nil)
    }
}
