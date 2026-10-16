import Foundation

// Key-value coding and observing, which Foundation on Linux leaves out (P1-35). A key is a
// property that the method tables have accessors for, `key` and `setKey:`: irisrun-ios-build
// registers them for `@objc`, `@IBOutlet` and `@IBInspectable` properties. Storyboards connect
// outlets and set inspectable values this way, as UIKit's do.

extension NSObject {
    /// The value of the property `key`, from its getter `key` or `isKey`; the app stops as on
    /// iOS when there is neither.
    public func value(forKey key: String) -> Any? {
        // Darwin's user defaults keep values by key, as `object(forKey:)` reads them.
        if let defaults = self as? UserDefaults { return defaults.object(forKey: key) }
        guard let getter = [key, "is" + capitalized(key)].map(Selector.init(_:)).first(where: { responds(to: $0) }) else {
            undefinedKey(key, of: self, in: "valueForUndefinedKey:")
        }
        return _IrisMethods.send(getter, to: self, with: [])
    }

    /// Sets the property `key` with its setter, `setKey:`.
    public func setValue(_ value: Any?, forKey key: String) {
        if let defaults = self as? UserDefaults { return defaults.set(value, forKey: key) }
        let setter = Selector("set\(capitalized(key)):")
        guard responds(to: setter) else { undefinedKey(key, of: self, in: "setValue:forUndefinedKey:") }
        _IrisMethods.send(setter, to: self, with: [value])
    }

    /// The value at a path of keys, such as `layer.cornerRadius`; nil past a nil value.
    public func value(forKeyPath keyPath: String) -> Any? {
        keyPath.split(separator: ".").reduce(self as Any?) { object, key in (object as? NSObject)?.value(forKey: String(key)) }
    }

    public func setValue(_ value: Any?, forKeyPath keyPath: String) {
        let keys = keyPath.split(separator: ".").map(String.init)
        let owner = keys.dropLast().reduce(self as Any?) { object, key in (object as? NSObject)?.value(forKey: key) }
        (owner as? NSObject)?.setValue(value, forKey: keys.last ?? "")
    }
}

private func capitalized(_ key: String) -> String {
    key.prefix(1).uppercased() + key.dropFirst()
}

private func undefinedKey(_ key: String, of object: NSObject, in method: String) -> Never {
    fatalError("[<\(String(reflecting: type(of: object))) \(Unmanaged.passUnretained(object).toOpaque())> \(method)]: this class is not key value coding-compliant for the key \(key).")
}

// MARK: Observing

public struct NSKeyValueObservingOptions: OptionSet, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let new = NSKeyValueObservingOptions(rawValue: 1)
    public static let old = NSKeyValueObservingOptions(rawValue: 2)
    public static let initial = NSKeyValueObservingOptions(rawValue: 4)
    /// Iris doesn't send notes before changes.
    public static let prior = NSKeyValueObservingOptions(rawValue: 8)
}

public enum NSKeyValueChange: UInt, Sendable {
    case setting = 1, insertion, removal, replacement
}

public struct NSKeyValueObservedChange<Value> {
    public let kind: NSKeyValueChange
    public let newValue: Value?
    public let oldValue: Value?
    public let indexes: IndexSet?
    public let isPrior: Bool
}

/// What `observe(_:options:changeHandler:)` returns: the observation lasts until it is
/// invalidated or released.
public final class NSKeyValueObservation: @unchecked Sendable {
    fileprivate weak var object: AnyObject?
    fileprivate let keyPath: AnyKeyPath
    /// Calls the handler for the object and the property's old value.
    fileprivate let changed: (AnyObject, Any?) -> Void

    fileprivate init(object: AnyObject, keyPath: AnyKeyPath, changed: @escaping (AnyObject, Any?) -> Void) {
        self.object = object
        self.keyPath = keyPath
        self.changed = changed
    }

    public func invalidate() {
        observationsLock.withLock { observations.removeAll { $0.observation == nil || $0.observation === self } }
    }

    deinit {
        invalidate()
    }
}

/// The observations, held weakly: one ends when the app releases it.
// ponytail: one list scanned on every change; index it by object if apps observe a lot.
nonisolated(unsafe) private var observations: [WeakObservation] = []
private let observationsLock = NSLock()

private struct WeakObservation {
    weak var observation: NSKeyValueObservation?
}

/// Iris: what has key-value observing, NSObject and its subclasses.
public protocol _IrisKeyValueObserving {}

extension NSObject: _IrisKeyValueObserving {}

extension _IrisKeyValueObserving {
    /// Calls `changeHandler` when the property at `keyPath` changes, which Iris knows for the
    /// `dynamic` properties of the app's `@objc` classes (irisrun-ios-build gives them a
    /// `didSet` that calls `_irisDidChangeValue`). The key path must start at the class that
    /// declares the property.
    public func observe<Value>(
        _ keyPath: KeyPath<Self, Value>,
        options: NSKeyValueObservingOptions = [],
        changeHandler: @escaping (Self, NSKeyValueObservedChange<Value>) -> Void
    ) -> NSKeyValueObservation {
        let observation = NSKeyValueObservation(object: self as AnyObject, keyPath: keyPath) { object, old in
            guard let object = object as? Self else { return }
            changeHandler(object, NSKeyValueObservedChange(
                kind: .setting,
                newValue: options.contains(.new) ? object[keyPath: keyPath] : nil,
                oldValue: options.contains(.old) ? old as? Value : nil,
                indexes: nil,
                isPrior: false
            ))
        }
        observationsLock.withLock { observations.append(WeakObservation(observation: observation)) }
        if options.contains(.initial) {
            observation.changed(self as AnyObject, nil)
        }
        return observation
    }
}

/// Iris: tells the observers of `object`'s property at `keyPath` that it changed from `oldValue`.
public func _irisDidChangeValue<Root: AnyObject, Value>(_ object: Root, _ keyPath: KeyPath<Root, Value>, from oldValue: Value) {
    let observing = observationsLock.withLock {
        observations.compactMap(\.observation).filter { $0.object === object && $0.keyPath == keyPath }
    }
    for observation in observing {
        observation.changed(object, oldValue)
    }
}
