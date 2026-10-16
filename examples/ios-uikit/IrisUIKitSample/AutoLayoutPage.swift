import UIKit

/// A page laid out only by constraints, as most UIKit screens are: anchors and the
/// item/attribute API, a layout guide between two buttons, the layout margins and the safe area,
/// priorities, content hugging and compression resistance between two labels, a label that
/// wraps its lines at the width Auto Layout gives it, and stack views. "Phóng to" changes one
/// constant, and Auto Layout moves everything that depends on it, in an animation; a tapped tag
/// hides, and the tags left share its room.
class AutoLayoutPage: UIView {
    private let avatar = UIView()
    private let enlarge = UIButton(configuration: .filled())
    private var avatarWidth: NSLayoutConstraint!
    private let tags = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        // Inside the safe area: the page reaches down to the home indicator.
        directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        let margins = layoutMarginsGuide

        let title = UILabel()
        title.text = "Auto Layout"
        title.font = .boldSystemFont(ofSize: 22)

        avatar.backgroundColor = .systemIndigo
        avatar.layer.cornerRadius = 12
        avatar.accessibilityLabel = "Avatar"
        avatarWidth = avatar.widthAnchor.constraint(equalToConstant: 56)

        // Too long for the row: the name gives way, as it resists compression less than the
        // badge, which also hugs its text.
        let name = UILabel()
        name.text = "Nguyễn Thị Ánh Dương, kỹ sư phần mềm"
        name.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
        let badge = UILabel()
        badge.text = "PRO"
        badge.font = .boldSystemFont(ofSize: 13)
        badge.textColor = .white
        badge.backgroundColor = .systemOrange
        badge.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let body = UILabel()
        body.text = "Màn này dựng hoàn toàn bằng constraint: anchor, NSLayoutConstraint, một layout guide, safe area và margin. Nhãn nhiều dòng xuống dòng theo bề rộng mà Auto Layout cho nó."
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .subheadline)
        body.textColor = .secondaryLabel

        // Two buttons as wide as each other, a layout guide of 12 points between them.
        enlarge.configuration?.title = "Phóng to"
        enlarge.addTarget(self, action: #selector(toggleAvatar), for: .touchUpInside)
        let reset = UIButton(configuration: .gray())
        reset.configuration?.title = "Đặt lại"
        reset.addTarget(self, action: #selector(resetAvatar), for: .touchUpInside)
        let gap = UILayoutGuide()
        addLayoutGuide(gap)

        // Tags in a stack view, as wide as each other, 8 points apart.
        for name in ["Swift", "UIKit", "Iris"] {
            let tag = UIButton(configuration: .tinted())
            tag.configuration?.title = name
            tag.addTarget(self, action: #selector(hideTag(_:)), for: .touchUpInside)
            tags.addArrangedSubview(tag)
        }
        tags.distribution = .fillEqually
        tags.spacing = 8
        tags.accessibilityLabel = "Tags"

        // As tall as it wishes only if there is room: it gives way to the footer. Its text is
        // a column of two labels, centered.
        let box = UIView()
        box.backgroundColor = .systemTeal
        box.layer.cornerRadius = 16
        box.accessibilityLabel = "Priority box"
        let boxLabel = UILabel()
        boxLabel.text = "Cao 400 @250"
        boxLabel.textColor = .white
        let boxNote = UILabel()
        boxNote.text = "co lại cho vừa"
        boxNote.font = .preferredFont(forTextStyle: .footnote)
        boxNote.textColor = .white
        let boxText = UIStackView(arrangedSubviews: [boxLabel, boxNote])
        boxText.axis = .vertical
        boxText.alignment = .center
        boxText.spacing = 4
        let boxHeight = box.heightAnchor.constraint(equalToConstant: 400)
        boxHeight.priority = .defaultLow

        let footer = UILabel()
        footer.text = "Ghim trên vạch Home"
        footer.font = .preferredFont(forTextStyle: .footnote)
        footer.textAlignment = .center
        footer.textColor = .secondaryLabel

        for view in [title, avatar, name, badge, body, enlarge, reset, tags, box, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        boxText.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(boxText)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: margins.topAnchor),
            title.leadingAnchor.constraint(equalTo: margins.leadingAnchor),

            avatar.topAnchor.constraint(equalToSystemSpacingBelow: title.bottomAnchor, multiplier: 1.5),
            avatar.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            avatarWidth,
            avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor),

            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            name.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            badge.leadingAnchor.constraint(greaterThanOrEqualTo: name.trailingAnchor, constant: 8),
            badge.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            badge.firstBaselineAnchor.constraint(equalTo: name.firstBaselineAnchor),

            body.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 16),
            body.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: margins.trailingAnchor),

            enlarge.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 16),
            enlarge.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            gap.leadingAnchor.constraint(equalTo: enlarge.trailingAnchor),
            gap.widthAnchor.constraint(equalToConstant: 12),
            reset.leadingAnchor.constraint(equalTo: gap.trailingAnchor),
            reset.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            NSLayoutConstraint(item: reset, attribute: .width, relatedBy: .equal, toItem: enlarge, attribute: .width, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: reset, attribute: .top, relatedBy: .equal, toItem: enlarge, attribute: .top, multiplier: 1, constant: 0),

            tags.topAnchor.constraint(equalTo: enlarge.bottomAnchor, constant: 16),
            tags.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            tags.trailingAnchor.constraint(equalTo: margins.trailingAnchor),

            box.topAnchor.constraint(equalTo: tags.bottomAnchor, constant: 16),
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            NSLayoutConstraint(item: box, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 0.5, constant: 0),
            boxHeight,
            box.bottomAnchor.constraint(lessThanOrEqualTo: footer.topAnchor, constant: -16),
            boxText.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            boxText.centerYAnchor.constraint(equalTo: box.centerYAnchor),

            footer.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func toggleAvatar() {
        avatarWidth.constant = avatarWidth.constant == 56 ? 80 : 56
        enlarge.configuration?.title = avatarWidth.constant == 56 ? "Phóng to" : "Thu nhỏ"
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
        }
    }

    @objc private func resetAvatar() {
        avatarWidth.constant = 56
        enlarge.configuration?.title = "Phóng to"
        UIView.animate(withDuration: 0.3) {
            for tag in self.tags.arrangedSubviews {
                tag.isHidden = false
            }
            self.layoutIfNeeded()
        }
    }

    @objc private func hideTag(_ tag: UIButton) {
        UIView.animate(withDuration: 0.3) {
            tag.isHidden = true
            self.tags.layoutIfNeeded()
        }
    }
}
