import Foundation
import IrisRender

/// The bytes of an image file, kept once however many views show it; the render core decodes
/// them when it draws.
public final class IrisEncodedImage: Equatable, @unchecked Sendable {
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public static func == (lhs: IrisEncodedImage, rhs: IrisEncodedImage) -> Bool {
        lhs === rhs || lhs.bytes == rhs.bytes
    }
}

/// Image sets of the asset catalogs (`.xcassets`) in a bundle's resources, read as Xcode
/// writes them, since there is no CoreUI to compile them, for both UI frameworks. irisrun puts
/// an app's resources next to its executable, where `Bundle.main` finds them. Loose files
/// (`name.png`, `name@2x.png`) count too.
// ponytail: PNG, JPEG, WebP, GIF and BMP images; vector images (PDF, SVG) and appearances
// (dark mode) come later.
public enum IrisAssetCatalog {
    public struct Image: Sendable {
        public var bytes: IrisEncodedImage
        /// Pixels per point.
        public var scale: CGFloat
        public var pixelSize: CGSize
        /// The image set's "Render As": true for a template, false for the original image,
        /// nil when it doesn't say.
        public var isTemplate: Bool?

        /// Nil if the render core can't read the image's size from its header.
        public init?(bytes: [UInt8], scale: CGFloat, isTemplate: Bool? = nil) {
            guard let size = IrisRender.Layer.imageSize(bytes) else { return nil }
            self.bytes = IrisEncodedImage(bytes: bytes)
            self.scale = scale
            pixelSize = CGSize(width: size.width, height: size.height)
            self.isTemplate = isTemplate
        }

        /// An image file, at the scale its name gives: 2 for `name@2x.png`.
        public init?(contentsOfFile path: String) {
            guard let data = FileManager.default.contents(atPath: path) else { return nil }
            let name = (path as NSString).deletingPathExtension
            let scale = ["@3x": 3, "@2x": 2].first { name.hasSuffix($0.key) }?.value ?? 1
            self.init(bytes: [UInt8](data), scale: CGFloat(scale))
        }
    }

    /// The image named `name` in `bundle`, in the variant closest to `scale`.
    public static func image(named name: String, in bundle: Bundle, scale: CGFloat) -> Image? {
        let key = Key(bundle: bundle.bundleURL, name: name, scale: scale)
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] {
            return cached
        }
        let image = load(named: name, in: bundle, scale: scale)
        cache[key] = image
        return image
    }

    private struct Key: Hashable {
        var bundle: URL
        var name: String
        var scale: CGFloat
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: Image?] = [:]
    nonisolated(unsafe) private static var imageSets: [URL: [String: URL]] = [:]

    private static func load(named name: String, in bundle: Bundle, scale: CGFloat) -> Image? {
        guard let resources = bundle.resourceURL ?? Optional(URL(fileURLWithPath: bundle.bundlePath)) else {
            return nil
        }
        if let set = sets(in: resources)[name], let image = image(inSet: set, scale: scale) {
            return image
        }
        // Loose files, the best scale first.
        let scales = [Int(scale.rounded()), 3, 2, 1].filter { $0 > 0 }
        for candidate in scales {
            let suffix = candidate == 1 ? "" : "@\(candidate)x"
            for ext in ["png", "jpg", "jpeg"] {
                let url = resources.appendingPathComponent("\(name)\(suffix).\(ext)")
                if let image = decode(url, scale: CGFloat(candidate), isTemplate: nil) {
                    return image
                }
            }
        }
        return nil
    }

    /// Every image set under the resources, by the name Xcode gives it: folders that provide
    /// a namespace prefix it, `Folder/name`.
    private static func sets(in resources: URL) -> [String: URL] {
        if let sets = imageSets[resources] {
            return sets
        }
        var sets: [String: URL] = [:]
        let manager = FileManager.default
        let catalogs = (try? manager.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)) ?? []
        for catalog in catalogs where catalog.pathExtension == "xcassets" {
            func walk(_ directory: URL, prefix: String) {
                let entries = (try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
                for entry in entries {
                    switch entry.pathExtension {
                    case "imageset":
                        let name = prefix + entry.deletingPathExtension().lastPathComponent
                        // The first catalog wins, as Xcode reports a clash.
                        if sets[name] == nil {
                            sets[name] = entry
                        }
                    case "":
                        var isDirectory: ObjCBool = false
                        guard manager.fileExists(atPath: entry.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                            continue
                        }
                        let contents = json(entry.appendingPathComponent("Contents.json"))
                        let properties = contents?["properties"] as? [String: Any]
                        let namespaced = properties?["provides-namespace"] as? Bool ?? false
                        walk(entry, prefix: namespaced ? prefix + entry.lastPathComponent + "/" : prefix)
                    default:
                        continue
                    }
                }
            }
            walk(catalog, prefix: "")
        }
        imageSets[resources] = sets
        return sets
    }

    private static func image(inSet set: URL, scale: CGFloat) -> Image? {
        guard let contents = json(set.appendingPathComponent("Contents.json")),
              let entries = contents["images"] as? [[String: Any]]
        else { return nil }
        let properties = contents["properties"] as? [String: Any]
        let isTemplate: Bool? = switch properties?["template-rendering-intent"] as? String {
        case "template": true
        case "original": false
        default: nil
        }
        // Entries with a file, for the phone or for every device, best scale first: the
        // smallest at or above the screen's, then the largest below it.
        let candidates = entries.compactMap { entry -> (file: String, scale: CGFloat)? in
            guard let file = entry["filename"] as? String,
                  ["universal", "iphone", nil].contains(entry["idiom"] as? String)
            else { return nil }
            let scale = (entry["scale"] as? String).flatMap { Double($0.dropLast()) } ?? 1
            return (file, CGFloat(scale))
        }
        let ordered = candidates.sorted { a, b in
            switch (a.scale >= scale, b.scale >= scale) {
            case (true, false): true
            case (false, true): false
            case (true, true): a.scale < b.scale
            case (false, false): a.scale > b.scale
            }
        }
        for candidate in ordered {
            if let image = decode(set.appendingPathComponent(candidate.file), scale: candidate.scale, isTemplate: isTemplate) {
                return image
            }
        }
        return nil
    }

    private static func decode(_ url: URL, scale: CGFloat, isTemplate: Bool?) -> Image? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return Image(bytes: [UInt8](data), scale: scale, isTemplate: isTemplate)
    }

    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
