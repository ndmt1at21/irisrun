import Foundation

/// Something a menu shows: an action, or a submenu.
// ponytail: menus (UIMenu, context menus) come with the controls that show them.
@preconcurrency @MainActor
open class UIMenuElement: NSObject {
    init(title: String, subtitle: String?, image: UIImage?) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        super.init()
    }

    open internal(set) var title: String
    open internal(set) var subtitle: String?
    open internal(set) var image: UIImage?
}

extension UIMenuElement {
    public struct Attributes: OptionSet, Hashable, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        public static let disabled = Attributes(rawValue: 1 << 0)
        public static let destructive = Attributes(rawValue: 1 << 1)
        public static let hidden = Attributes(rawValue: 1 << 2)
        public static let keepsMenuPresented = Attributes(rawValue: 1 << 3)
    }

    public enum State: Int, Sendable {
        case off = 0, on, mixed
    }
}

public typealias UIActionHandler = @MainActor (UIAction) -> Void

/// A closure to run, with a title and image for menus. Controls run it for the events it was
/// added for; `sender` is the control while it runs.
@preconcurrency @MainActor
open class UIAction: UIMenuElement {
    public init(
        title: String = "",
        subtitle: String? = nil,
        image: UIImage? = nil,
        selectedImage: UIImage? = nil,
        identifier: UIAction.Identifier? = nil,
        discoverabilityTitle: String? = nil,
        attributes: UIMenuElement.Attributes = [],
        state: UIMenuElement.State = .off,
        handler: @escaping UIActionHandler
    ) {
        self.selectedImage = selectedImage
        self.identifier = identifier ?? UIAction.Identifier(UUID().uuidString)
        self.discoverabilityTitle = discoverabilityTitle
        self.attributes = attributes
        self.state = state
        self.handler = handler
        super.init(title: title, subtitle: subtitle, image: image)
    }

    override open var title: String {
        get { super.title }
        set { super.title = newValue }
    }

    override open var subtitle: String? {
        get { super.subtitle }
        set { super.subtitle = newValue }
    }

    override open var image: UIImage? {
        get { super.image }
        set { super.image = newValue }
    }

    open var selectedImage: UIImage?
    open private(set) var identifier: UIAction.Identifier
    open var discoverabilityTitle: String?
    open var attributes: UIMenuElement.Attributes
    open var state: UIMenuElement.State
    /// What runs the action, such as a control, while it runs.
    open internal(set) var sender: Any?

    let handler: UIActionHandler
}

extension UIAction {
    public struct Identifier: RawRepresentable, Hashable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}
