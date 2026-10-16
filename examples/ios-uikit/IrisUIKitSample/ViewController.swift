import UIKit

/// A screen built from frames, as an iPhone SE nib would have it: laid out for 320 × 568 points,
/// and stretched to the real screen by autoresizing. A segmented control in the header switches
/// between pages: touches, controls, a form, a SwiftUI card in the UIKit screen, and a page laid
/// out by constraints.
class ViewController: UIViewController {
    /// Lamps that light up when a notification and a timer reach their selectors.
    private let notificationLamp = Lamp(frame: CGRect(x: 256, y: 68, width: 20, height: 20), name: "Notification")
    private let timerLamp = Lamp(frame: CGRect(x: 284, y: 68, width: 20, height: 20), name: "Timer")
    private let footer = UIView(frame: CGRect(x: 0, y: 342, width: 320, height: 80))
    private var pages: [UIView] = []
    private var presses = (down: 0, up: 0)
    private var logoMoved = CGPoint.zero

    override func loadView() {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Shapes"
        view.backgroundColor = .systemGroupedBackground

        // A header that spans the screen, whatever its width.
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 146))
        header.backgroundColor = .systemIndigo
        header.autoresizingMask = [.flexibleWidth]
        header.accessibilityLabel = "Header"
        view.addSubview(header)

        // Which lifecycle callbacks ran, in order, and the lamps.
        let status = UIView(frame: CGRect(x: 16, y: 62, width: 232, height: 32))
        status.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        status.layer.cornerRadius = 8
        status.autoresizingMask = [.flexibleWidth]
        Lifecycle.onChange = { status.accessibilityLabel = $0 }
        header.addSubview(status)
        for lamp in [notificationLamp, timerLamp] {
            lamp.autoresizingMask = [.flexibleLeftMargin]
            header.addSubview(lamp)
        }
        // The pages under the header, and the control that picks one.
        let picker = UISegmentedControl(items: ["Touch", "Controls", "Form", "SwiftUI", "Layout"])
        picker.frame = CGRect(x: 16, y: 104, width: 288, height: 32)
        picker.autoresizingMask = [.flexibleWidth]
        picker.selectedSegmentIndex = 0
        picker.addTarget(self, action: #selector(pageChanged(_:)), for: .valueChanged)
        header.addSubview(picker)
        let touchPage = UIView(frame: CGRect(x: 0, y: 146, width: 320, height: 422))
        let formPage = FormPage(frame: touchPage.frame)
        formPage.accessibilityLabel = "Form page"
        // Logging in greets the person by name, in an alert this controller presents.
        formPage.onLogIn = { [weak self, weak formPage] name in
            let alert = UIAlertController(title: "Xin chào, \(name)!", message: "Bạn đã đăng nhập vào Iris.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Vào ứng dụng", style: .default) { _ in
                formPage?.showStatus("Đã đăng nhập: \(name)")
            })
            self?.present(alert, animated: true)
        }
        let swiftUIPage = SwiftUIPage(frame: touchPage.frame)
        swiftUIPage.accessibilityLabel = "SwiftUI page"
        let autoLayoutPage = AutoLayoutPage(frame: touchPage.frame)
        autoLayoutPage.accessibilityLabel = "Auto Layout page"
        pages = [touchPage, ControlsPage(frame: touchPage.frame), formPage, swiftUIPage, autoLayoutPage]
        for (index, page) in pages.enumerated() {
            page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            page.isHidden = index != picker.selectedSegmentIndex
            view.addSubview(page)
        }
        // The SwiftUI card's hosting controller joins this one as a child, and its view the page.
        addChild(swiftUIPage.card)
        swiftUIPage.addSubview(swiftUIPage.card.view)
        swiftUIPage.card.didMove(toParent: self)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerFired(_:)), userInfo: "tick", repeats: false)

        // A card with a shadow, holding four swatches with white borders.
        let card = UIView(frame: CGRect(x: 16, y: 12, width: 288, height: 96))
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.2
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.layer.shadowRadius = 10
        card.autoresizingMask = [.flexibleWidth]
        card.accessibilityLabel = "Card"
        card.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(cardHeld(_:))))
        touchPage.addSubview(card)
        let swatches: [(UIColor, String)] = [(.systemRed, "Red"), (.systemOrange, "Orange"), (.systemGreen, "Green"), (.systemBlue, "Blue")]
        for (index, (color, name)) in swatches.enumerated() {
            let swatch = UIView(frame: CGRect(x: 16 + CGFloat(index) * 68, y: 18, width: 60, height: 60))
            swatch.backgroundColor = color
            swatch.layer.cornerRadius = 30
            swatch.layer.borderWidth = 4
            swatch.layer.borderColor = UIColor.systemGray5.cgColor
            swatch.accessibilityLabel = name
            card.addSubview(swatch)
        }

        // The same square sticks out of two rounded boxes; only the first clips it.
        for (index, clips) in [true, false].enumerated() {
            let box = UIView(frame: CGRect(x: 16 + CGFloat(index) * 152, y: 120, width: 136, height: 110))
            box.backgroundColor = clips ? .systemTeal : .systemPink
            box.layer.cornerRadius = 20
            box.clipsToBounds = clips
            box.accessibilityLabel = clips ? "Clipped box" : "Box"
            box.autoresizingMask = index == 0 ? [.flexibleRightMargin] : [.flexibleLeftMargin]
            touchPage.addSubview(box)
            let square = UIView(frame: CGRect(x: 76, y: 56, width: 80, height: 80))
            square.backgroundColor = .systemYellow
            square.layer.borderWidth = 2
            square.layer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor
            square.accessibilityLabel = clips ? "Clipped square" : "Square"
            box.addSubview(square)
        }

        // Turned a sixteenth of a turn, half transparent, and one not shown at all.
        let rotated = UIView(frame: CGRect(x: 40, y: 268, width: 90, height: 90))
        rotated.backgroundColor = .systemPurple
        rotated.layer.cornerRadius = 12
        rotated.transform = CGAffineTransform(rotationAngle: .pi / 8)
        rotated.accessibilityLabel = "Rotated"
        touchPage.addSubview(rotated)
        let faded = UIView(frame: CGRect(x: 168, y: 268, width: 136, height: 90))
        faded.backgroundColor = .systemGreen
        faded.alpha = 0.5
        faded.layer.cornerRadius = 12
        faded.autoresizingMask = [.flexibleLeftMargin]
        faded.accessibilityLabel = "Half transparent"
        touchPage.addSubview(faded)
        let hidden = UIView(frame: CGRect(x: 168, y: 268, width: 136, height: 90))
        hidden.backgroundColor = .systemRed
        hidden.isHidden = true
        hidden.accessibilityLabel = "Hidden"
        touchPage.addSubview(hidden)

        // Three things to touch, kept above the footer: on the 568-point layout they would sit
        // over the shapes, and taller screens have room for them.
        let pad = TouchPad(frame: CGRect(x: 16, y: 98, width: 136, height: 110))
        pad.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin]
        touchPage.addSubview(pad)
        let logo = UIView(frame: CGRect(x: 168, y: 98, width: 136, height: 110))
        logo.backgroundColor = .secondarySystemGroupedBackground
        logo.layer.cornerRadius = 16
        logo.layer.contents = UIImage(named: "Logo")?.cgImage
        logo.layer.contentsGravity = .resizeAspect
        logo.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
        logo.accessibilityLabel = "Logo"
        logo.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(logoPanned(_:))))
        touchPage.addSubview(logo)
        let handle = DragHandle(frame: CGRect(x: 16, y: 228, width: 64, height: 64))
        handle.autoresizingMask = [.flexibleTopMargin]
        touchPage.addSubview(handle)
        // A double tap sends the handle back where it started.
        let doubleTap = UITapGestureRecognizer(target: handle, action: #selector(DragHandle.returnHome(_:)))
        doubleTap.numberOfTapsRequired = 2
        handle.addGestureRecognizer(doubleTap)

        // A bar kept at the bottom of the screen, with a button that changes color.
        footer.backgroundColor = .secondarySystemGroupedBackground
        footer.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        footer.accessibilityLabel = "Footer"
        touchPage.addSubview(footer)
        let button = ColorButton(frame: CGRect(x: 16, y: 12, width: 288, height: 44))
        button.autoresizingMask = [.flexibleWidth]
        footer.addSubview(button)
        let colors: [(UIColor, String)] = [(.systemGreen, "green"), (.systemOrange, "orange"), (.systemBlue, "blue")]
        var next = 0
        button.addAction(UIAction { action in
            guard let button = action.sender as? UIControl else { return }
            button.backgroundColor = colors[next].0
            button.accessibilityLabel = "Color: \(colors[next].1)"
            next = (next + 1) % colors.count
        }, for: .touchUpInside)
        // UIKit counts a touch as inside up to about 70 points out; further, the tap is off.
        button.addAction(UIAction { action in
            (action.sender as? UIControl)?.accessibilityLabel = "Released outside"
        }, for: .touchUpOutside)
        // Target and action, as a storyboard would connect the button to buttonUp(_:).
        button.addTarget(self, action: #selector(buttonDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonUp(_:)), for: .touchUpInside)
    }

    @objc private func pageChanged(_ picker: UISegmentedControl) {
        for (index, page) in pages.enumerated() {
            page.isHidden = index != picker.selectedSegmentIndex
        }
    }

    @objc private func buttonDown(_ sender: UIControl) {
        presses.down += 1
        footer.accessibilityLabel = "Button down \(presses.down), up \(presses.up)"
    }

    @IBAction func buttonUp(_ sender: Any) {
        presses.up += 1
        footer.accessibilityLabel = "Button down \(presses.down), up \(presses.up)"
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        notificationLamp.light("active")
    }

    @objc private func timerFired(_ timer: Timer) {
        timerLamp.light("fired (\(timer.userInfo as? String ?? ""))")
    }

    @objc private func cardHeld(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            recognizer.view?.backgroundColor = .systemYellow
            recognizer.view?.accessibilityLabel = "Card held"
        }
    }

    @objc private func logoPanned(_ pan: UIPanGestureRecognizer) {
        guard let logo = pan.view else { return }
        let translation = pan.translation(in: view)
        logo.center = CGPoint(x: logo.center.x + translation.x, y: logo.center.y + translation.y)
        logoMoved = CGPoint(x: logoMoved.x + translation.x, y: logoMoved.y + translation.y)
        pan.setTranslation(.zero, in: view)
        if pan.state == .ended {
            logo.accessibilityLabel = "Logo moved by \(Int(logoMoved.x)), \(Int(logoMoved.y))"
        }
    }
}

/// A dot that turns green when what it waits for happens.
class Lamp: UIView {
    private let name: String

    init(frame: CGRect, name: String) {
        self.name = name
        super.init(frame: frame)
        backgroundColor = .systemGray3
        layer.cornerRadius = frame.height / 2
        accessibilityLabel = "\(name): waiting"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func light(_ state: String) {
        backgroundColor = .systemGreen
        accessibilityLabel = "\(name): \(state)"
    }
}

/// A control that dims while a finger is on it, as buttons do.
class ColorButton: UIControl {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBlue
        layer.cornerRadius = 22
        accessibilityLabel = "Tap to change color"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1 }
    }
}

/// Lights up while touched and counts the touches that lift on it.
class TouchPad: UIView {
    private(set) var taps = 0 {
        didSet { accessibilityLabel = "Touch pad: \(taps) \(taps == 1 ? "tap" : "taps")" }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemTeal
        layer.cornerRadius = 16
        accessibilityLabel = "Touch pad"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = .systemOrange
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = .systemTeal
        if let touch = touches.first, bounds.contains(touch.location(in: self)) {
            taps += 1
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = .systemTeal
    }

}

/// A square that follows the finger dragging it.
class DragHandle: UIView {
    private var dragged = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemPurple
        layer.cornerRadius = 32
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.cgColor
        accessibilityLabel = "Drag me"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        superview?.bringSubviewToFront(self)
        transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let superview else { return }
        let location = touch.location(in: superview)
        let previous = touch.previousLocation(in: superview)
        center = CGPoint(x: center.x + location.x - previous.x, y: center.y + location.y - previous.y)
        dragged = CGPoint(x: dragged.x + location.x - previous.x, y: dragged.y + location.y - previous.y)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        transform = .identity
        accessibilityLabel = "Dragged by \(Int(dragged.x.rounded())), \(Int(dragged.y.rounded()))"
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        transform = .identity
    }

    @objc func returnHome(_ recognizer: UITapGestureRecognizer) {
        center = CGPoint(x: center.x - dragged.x, y: center.y - dragged.y)
        dragged = .zero
        accessibilityLabel = "Drag me"
    }
}

/// UIKit's text and controls, each with a label that says what it did.
class ControlsPage: UIView {
    private let status = UILabel(frame: CGRect(x: 16, y: 560, width: 288, height: 20))
    private let wifi = UILabel(frame: CGRect(x: 80, y: 293, width: 224, height: 21))
    private let volume = UILabel(frame: CGRect(x: 16, y: 368, width: 288, height: 20))
    private let progress = UIProgressView(progressViewStyle: .default)
    private let size = UILabel(frame: CGRect(x: 16, y: 456, width: 288, height: 20))
    private let spinner = UIActivityIndicatorView(style: .large)
    private let spinnerButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        // Labels: attributed text, a line too long that truncates, and one that shrinks.
        let styled = NSMutableAttributedString(string: "Bold red, underlined, spaced")
        styled.addAttributes([.font: UIFont.boldSystemFont(ofSize: 17), .foregroundColor: UIColor.systemRed], range: NSRange(location: 0, length: 8))
        styled.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 10, length: 10))
        styled.addAttribute(.kern, value: 3, range: NSRange(location: 22, length: 6))
        let attributed = label(CGRect(x: 16, y: 12, width: 288, height: 24))
        attributed.attributedText = styled
        let truncated = label(CGRect(x: 16, y: 40, width: 288, height: 20))
        truncated.text = "This line is far too long to fit in its label, so it ends in an ellipsis"
        truncated.textColor = .secondaryLabel
        let shrunk = label(CGRect(x: 16, y: 64, width: 288, height: 24))
        shrunk.text = "This one shrinks to fit the width of its label"
        shrunk.adjustsFontSizeToFitWidth = true
        shrunk.minimumScaleFactor = 0.5

        // The logo as a template in the tint, and placed by content modes.
        for (index, mode) in [UIView.ContentMode.scaleAspectFit, .center, .topLeft].enumerated() {
            let image = UIImageView(frame: CGRect(x: 16 + CGFloat(index) * 72, y: 96, width: 64, height: 40))
            image.image = index == 0 ? UIImage(named: "Logo")?.withRenderingMode(.alwaysTemplate) : UIImage(named: "Logo")
            image.contentMode = mode
            image.clipsToBounds = true
            image.backgroundColor = .secondarySystemBackground
            image.layer.cornerRadius = 8
            image.tintColor = .systemPink
            image.accessibilityLabel = ["Tinted logo", "Centered logo", "Top-left logo"][index]
            addSubview(image)
        }

        // Buttons of each type, sending their actions by selector or as UIActions.
        let system = UIButton(type: .system)
        system.setTitle("System", for: .normal)
        system.frame = CGRect(x: 16, y: 148, width: 80, height: 30)
        system.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        addSubview(system)
        for (index, type) in [UIButton.ButtonType.detailDisclosure, .contactAdd, .close].enumerated() {
            let button = UIButton(type: type)
            button.frame.origin = CGPoint(x: 112 + CGFloat(index) * 40, y: type == .close ? 148 : 152)
            button.accessibilityLabel = ["Info", "Add", "Close"][index]
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(button)
        }
        let styles: [(String, UIButton.Configuration)] = [("Filled", .filled()), ("Tinted", .tinted()), ("Gray", .gray()), ("Plain", .plain())]
        var x: CGFloat = 16
        for (title, style) in styles {
            var configuration = style
            configuration.title = title
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
                self?.status.text = "Last tap: \(title)"
            })
            button.frame = CGRect(origin: CGPoint(x: x, y: 188), size: button.intrinsicContentSize)
            x += button.frame.width + 8
            addSubview(button)
        }
        // A toggle whose title follows its state, and one with an image and a subtitle.
        var favorite = UIButton.Configuration.bordered()
        favorite.image = UIImage(systemName: "plus.circle")
        favorite.imagePadding = 6
        let toggle = UIButton(configuration: favorite)
        toggle.changesSelectionAsPrimaryAction = true
        toggle.configurationUpdateHandler = { button in
            button.configuration?.title = button.isSelected ? "Favorited" : "Favorite"
        }
        toggle.frame = CGRect(x: 16, y: 232, width: 140, height: 44)
        addSubview(toggle)
        var subtitled = UIButton.Configuration.borderedProminent()
        subtitled.title = "Download"
        subtitled.subtitle = "12 MB"
        subtitled.cornerStyle = .capsule
        let download = UIButton(configuration: subtitled, primaryAction: UIAction { [weak self] _ in
            self?.status.text = "Last tap: Download"
        })
        download.frame = CGRect(x: 164, y: 232, width: 140, height: 52)
        addSubview(download)

        // A switch, a slider driving a progress view, and a segmented control.
        let toggleSwitch = UISwitch(frame: CGRect(x: 16, y: 288, width: 0, height: 0))
        toggleSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        addSubview(toggleSwitch)
        wifi.text = "Wi-Fi: off"
        addSubview(wifi)
        let slider = UISlider(frame: CGRect(x: 16, y: 332, width: 288, height: 31))
        slider.value = 0.5
        slider.autoresizingMask = [.flexibleWidth]
        slider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.showVolume(slider.value)
        }, for: .valueChanged)
        addSubview(slider)
        addSubview(volume)
        progress.frame = CGRect(x: 16, y: 396, width: 288, height: 4)
        progress.autoresizingMask = [.flexibleWidth]
        addSubview(progress)
        showVolume(slider.value)
        let sizes = UISegmentedControl(items: ["Small", "Medium", "Large"])
        sizes.frame = CGRect(x: 16, y: 416, width: 288, height: 32)
        sizes.autoresizingMask = [.flexibleWidth]
        sizes.selectedSegmentIndex = 1
        sizes.addTarget(self, action: #selector(sizeChanged(_:)), for: .valueChanged)
        addSubview(sizes)
        size.text = "Size: Medium"
        addSubview(size)

        // A spinner that a button starts and stops.
        spinner.frame.origin = CGPoint(x: 16, y: 488)
        addSubview(spinner)
        spinnerButton.setTitle("Start spinner", for: .normal)
        spinnerButton.frame = CGRect(x: 72, y: 492, width: 140, height: 30)
        spinnerButton.addTarget(self, action: #selector(toggleSpinner(_:)), for: .touchUpInside)
        addSubview(spinnerButton)

        status.text = "Last tap: none"
        addSubview(status)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func label(_ frame: CGRect) -> UILabel {
        let label = UILabel(frame: frame)
        label.autoresizingMask = [.flexibleWidth]
        addSubview(label)
        return label
    }

    private func showVolume(_ value: Float) {
        volume.text = "Volume: \(Int((value * 100).rounded()))"
        progress.setProgress(value, animated: true)
    }

    @objc private func tapped(_ sender: UIButton) {
        status.text = "Last tap: \(sender.currentTitle ?? sender.accessibilityLabel ?? "?")"
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        wifi.text = "Wi-Fi: \(sender.isOn ? "on" : "off")"
    }

    @objc private func sizeChanged(_ sender: UISegmentedControl) {
        size.text = "Size: \(sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "")"
    }

    @objc private func toggleSpinner(_ sender: UIButton) {
        if spinner.isAnimating {
            spinner.stopAnimating()
        } else {
            spinner.startAnimating()
        }
        sender.setTitle(spinner.isAnimating ? "Stop spinner" : "Start spinner", for: .normal)
        status.text = "Spinner: \(spinner.isAnimating ? "running" : "stopped")"
    }
}

/// A login form in a scroll view: the return key moves from the name to the password, the
/// button waits until both have text, and a note takes several lines.
class FormPage: UIView, UITextFieldDelegate, UITextViewDelegate {
    var onLogIn: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let username = UITextField(frame: CGRect(x: 16, y: 60, width: 288, height: 44))
    private let password = UITextField(frame: CGRect(x: 16, y: 112, width: 288, height: 44))
    private let status = UILabel(frame: CGRect(x: 16, y: 164, width: 288, height: 20))
    private let logInButton = UIButton(configuration: .filled())
    private let noteLabel = UILabel(frame: CGRect(x: 16, y: 262, width: 288, height: 20))
    private let note = UITextView(frame: CGRect(x: 16, y: 288, width: 288, height: 120))
    private let footer = UILabel(frame: CGRect(x: 16, y: 724, width: 288, height: 20))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        scrollView.delegate = self
        addSubview(scrollView)

        let title = UILabel(frame: CGRect(x: 16, y: 16, width: 288, height: 32))
        title.text = "Tài khoản Iris"
        title.font = .boldSystemFont(ofSize: 28)
        add(title)

        username.placeholder = "Tên đăng nhập"
        username.keyboardType = .emailAddress
        username.textContentType = .username
        username.autocapitalizationType = .none
        username.autocorrectionType = .no
        username.returnKeyType = .next
        username.clearButtonMode = .whileEditing
        password.placeholder = "Mật khẩu"
        password.isSecureTextEntry = true
        password.textContentType = .password
        password.returnKeyType = .go
        for field in [username, password] {
            field.borderStyle = .roundedRect
            field.delegate = self
            field.addTarget(self, action: #selector(fieldChanged(_:)), for: .editingChanged)
            add(field)
        }

        status.font = .preferredFont(forTextStyle: .footnote)
        status.textColor = .secondaryLabel
        add(status)
        logInButton.configuration?.title = "Đăng nhập"
        logInButton.frame = CGRect(x: 16, y: 196, width: 288, height: 50)
        logInButton.isEnabled = false
        logInButton.addTarget(self, action: #selector(logIn), for: .touchUpInside)
        add(logInButton)

        noteLabel.text = "Ghi chú"
        noteLabel.font = .preferredFont(forTextStyle: .subheadline)
        add(noteLabel)
        note.font = .preferredFont(forTextStyle: .body)
        note.layer.cornerRadius = 8
        note.layer.borderWidth = 1
        note.layer.borderColor = UIColor.systemGray4.cgColor
        note.delegate = self
        add(note)

        // Room below the note, so the form scrolls.
        footer.text = "Kéo để cuộn biểu mẫu"
        footer.textAlignment = .center
        footer.textColor = .tertiaryLabel
        add(footer)
        showStatus("Điền tên và mật khẩu")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func add(_ view: UIView) {
        view.autoresizingMask = [.flexibleWidth]
        scrollView.addSubview(view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: 760)
    }

    func showStatus(_ text: String) {
        status.text = text
    }

    /// The button waits for both fields; the status shows what the input method is composing.
    @objc private func fieldChanged(_ field: UITextField) {
        logInButton.isEnabled = !(username.text ?? "").isEmpty && !(password.text ?? "").isEmpty
        if let marked = field.markedTextRange, let composing = field.text(in: marked) {
            showStatus("Đang soạn: \(composing)")
        } else {
            showStatus(logInButton.isEnabled ? "Sẵn sàng đăng nhập" : "Điền tên và mật khẩu")
        }
    }

    /// Return goes from the name to the password, and from the password logs in.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === username {
            password.becomeFirstResponder()
        } else if logInButton.isEnabled {
            logIn()
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        noteLabel.text = "Ghi chú (\(textView.text.count) ký tự)"
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView else { return }
        footer.text = "Đã cuộn \(Int(scrollView.contentOffset.y.rounded())) điểm"
    }

    @objc private func logIn() {
        endEditing(true)
        onLogIn?(username.text ?? "")
    }
}
