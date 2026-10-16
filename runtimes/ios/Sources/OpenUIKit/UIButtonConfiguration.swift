import Foundation

extension UIButton {
    /// What a button shows (iOS 15): a style of colors and background, a title and subtitle,
    /// an image or activity indicator, and how they are laid out. Sizes and colors follow
    /// iOS 17's defaults; the button resolves them for its state as it shows them.
    // ponytail: no indicators (pop-up and pull-down), Mac styles or symbol configurations.
    public struct Configuration {
        enum Style {
            case plain, tinted, gray, filled, borderless, bordered, borderedTinted, borderedProminent
        }

        let style: Style

        init(style: Style) {
            self.style = style
            background = .clear()
        }

        public static func plain() -> Configuration { Configuration(style: .plain) }
        public static func tinted() -> Configuration { Configuration(style: .tinted) }
        public static func gray() -> Configuration { Configuration(style: .gray) }
        public static func filled() -> Configuration { Configuration(style: .filled) }
        public static func borderless() -> Configuration { Configuration(style: .borderless) }
        public static func bordered() -> Configuration { Configuration(style: .bordered) }
        public static func borderedTinted() -> Configuration { Configuration(style: .borderedTinted) }
        public static func borderedProminent() -> Configuration { Configuration(style: .borderedProminent) }

        /// The button resolves state-dependent colors as it draws, so this is the same.
        public func updated(for button: UIButton) -> Configuration {
            self
        }

        public var background: UIBackgroundConfiguration
        public var cornerStyle = CornerStyle.dynamic
        public var buttonSize = Size.medium
        public var baseForegroundColor: UIColor?
        public var baseBackgroundColor: UIColor?
        public var image: UIImage?
        public var imageColorTransformer: UIConfigurationColorTransformer?
        public var showsActivityIndicator = false
        public var activityIndicatorColorTransformer: UIConfigurationColorTransformer?
        public var title: String?
        public var attributedTitle: AttributedString?
        public var titleTextAttributesTransformer: UIConfigurationTextAttributesTransformer?
        public var titleLineBreakMode = NSLineBreakMode.byWordWrapping
        public var subtitle: String?
        public var attributedSubtitle: AttributedString?
        public var subtitleTextAttributesTransformer: UIConfigurationTextAttributesTransformer?
        public var subtitleLineBreakMode = NSLineBreakMode.byWordWrapping
        public var imagePlacement = NSDirectionalRectEdge.leading
        public var imagePadding: CGFloat = 0
        public var titlePadding: CGFloat = 0
        public var titleAlignment = TitleAlignment.automatic
        public var automaticallyUpdateForSelection = true

        private var ownContentInsets: NSDirectionalEdgeInsets?

        /// By default the button size's insets.
        public var contentInsets: NSDirectionalEdgeInsets {
            get { ownContentInsets ?? buttonSize.contentInsets }
            set { ownContentInsets = newValue }
        }

        public mutating func setDefaultContentInsets() {
            ownContentInsets = nil
        }

        public enum CornerStyle: Int, Sendable {
            case fixed = -1, dynamic, small, medium, large, capsule
        }

        public enum Size: Int, Sendable {
            case mini, small, medium, large

            /// As SwiftUI's bordered buttons of the control size, in patch 0024.
            var contentInsets: NSDirectionalEdgeInsets {
                let (vertical, horizontal): (CGFloat, CGFloat) = switch self {
                case .mini: (3, 8)
                case .small: (4, 10)
                case .medium: (7, 12)
                case .large: (14, 20)
                }
                return NSDirectionalEdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
            }

            /// Of the title and the subtitle: body text for medium and large buttons.
            var fonts: (UIFont, UIFont) {
                switch self {
                case .mini: (.systemFont(ofSize: 12), .systemFont(ofSize: 11))
                case .small: (.systemFont(ofSize: 15), .systemFont(ofSize: 13))
                case .medium, .large: (.systemFont(ofSize: 17), .systemFont(ofSize: 15))
                }
            }
        }

        public enum TitleAlignment: Int, Sendable {
            case automatic, leading, center, trailing
        }

        /// The foreground and background colors of the style in a state.
        func colors(tint: UIColor, state: UIControl.State) -> (foreground: UIColor, background: UIColor?) {
            let base = baseBackgroundColor ?? tint
            var (foreground, background): (UIColor, UIColor?) = switch style {
            case .plain, .borderless: (baseForegroundColor ?? tint, nil)
            case .tinted, .borderedTinted: (baseForegroundColor ?? tint, base.withAlphaComponent(0.15))
            case .gray, .bordered: (baseForegroundColor ?? tint, baseBackgroundColor ?? .secondarySystemFill)
            case .filled, .borderedProminent: (baseForegroundColor ?? .white, base)
            }
            if let color = self.background.backgroundColor {
                background = color
            }
            if state.contains(.disabled) {
                return (.tertiaryLabel, background == nil ? nil : .tertiarySystemFill)
            }
            if automaticallyUpdateForSelection, state.contains(.selected), style != .filled, style != .borderedProminent {
                // ponytail: a selected button looks filled, roughly as UIKit's toggles do.
                (foreground, background) = (.white, base)
            }
            if state.contains(.highlighted) {
                let fade: CGFloat = background == nil ? 0.5 : 0.75
                foreground = foreground.withAlphaComponent(foreground.cgColor.alpha * fade)
                background = background.map { $0.withAlphaComponent($0.cgColor.alpha * fade) }
            }
            return (foreground, background)
        }

        // ponytail: UIKit's radii by eye, the dynamic ones as SwiftUI's in patch 0024.
        func cornerRadius(height: CGFloat) -> CGFloat {
            switch cornerStyle {
            case .fixed: background.cornerRadius
            case .small: 4
            case .medium: 8
            case .large: 12
            case .capsule: height / 2
            case .dynamic:
                switch buttonSize {
                case .mini: 5
                case .small: 6
                case .medium: 7
                case .large: 12
                }
            }
        }

        /// A title or subtitle in the size's font and the foreground color, unless its own
        /// attributes say otherwise, then through the transformer.
        func text(_ plain: String?, _ attributed: AttributedString?, font: UIFont, color: UIColor, transformer: UIConfigurationTextAttributesTransformer?) -> NSAttributedString? {
            guard var text = attributed ?? plain.map({ AttributedString($0) }), !text.characters.isEmpty else { return nil }
            for run in text.runs {
                var attributes = AttributeContainer()
                attributes.uiKit.font = font
                attributes.uiKit.foregroundColor = color
                attributes.merge(run.attributes)
                text[run.range].setAttributes(transformer.map { $0(attributes) } ?? attributes)
            }
            return text.irisNSAttributedString
        }
    }
}

/// The background of a button or cell: a color, an image or a view, rounded and stroked.
// ponytail: buttons show the color, corner radius and stroke; no images, views or effects.
public struct UIBackgroundConfiguration {
    public static func clear() -> UIBackgroundConfiguration {
        UIBackgroundConfiguration()
    }

    public var customView: UIView?
    public var cornerRadius: CGFloat = 0
    public var backgroundInsets = NSDirectionalEdgeInsets.zero
    public var backgroundColor: UIColor?
    public var backgroundColorTransformer: UIConfigurationColorTransformer?
    public var image: UIImage?
    public var imageContentMode = UIView.ContentMode.scaleToFill
    public var strokeColor: UIColor?
    public var strokeColorTransformer: UIConfigurationColorTransformer?
    public var strokeWidth: CGFloat = 0
    public var strokeOutset: CGFloat = 0

    public func resolvedBackgroundColor(for tintColor: UIColor) -> UIColor {
        let color = backgroundColor ?? .clear
        return backgroundColorTransformer.map { $0(color) } ?? color
    }

    public func resolvedStrokeColor(for tintColor: UIColor) -> UIColor {
        let color = strokeColor ?? tintColor
        return strokeColorTransformer.map { $0(color) } ?? color
    }
}

public struct UIConfigurationColorTransformer {
    let transform: (UIColor) -> UIColor

    public init(_ transform: @escaping (UIColor) -> UIColor) {
        self.transform = transform
    }

    public func callAsFunction(_ input: UIColor) -> UIColor {
        transform(input)
    }

    public static var grayscale: UIConfigurationColorTransformer {
        UIConfigurationColorTransformer { $0.irisDimmed }
    }
}

public struct UIConfigurationTextAttributesTransformer {
    let transform: (AttributeContainer) -> AttributeContainer

    public init(_ transform: @escaping (AttributeContainer) -> AttributeContainer) {
        self.transform = transform
    }

    public func callAsFunction(_ input: AttributeContainer) -> AttributeContainer {
        transform(input)
    }
}
