import Foundation

/// The name of a method as Objective-C names it: `tapped:` for `tapped(_:)`, `fooWithBar:` for
/// `foo(bar:)`. Linux has no Objective-C runtime, so a selector is only that name;
/// `_IrisMethods` has what it calls on each class. irisrun-ios-build (P1-35) turns
/// `#selector(...)` into these names.
public struct Selector: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let name: String

    public init(_ str: String) {
        name = str
    }

    public init(stringLiteral value: String) {
        name = value
    }

    public var description: String {
        name
    }
}

public func NSStringFromSelector(_ aSelector: Selector) -> String {
    aSelector.name
}

public func NSSelectorFromString(_ aSelectorName: String) -> Selector {
    Selector(aSelectorName)
}

/// Iris: the methods selectors call, per class, as the Objective-C runtime keeps each class's
/// method list. Code that irisrun-ios-build writes (P1-35) registers the `@objc` methods of
/// each class, and those that extensions add to other modules' classes, before the app makes a
/// selector; "Hợp đồng cho P1-35" in Iris's docs/plans/p1-16-uikit.md has the details. A
/// lookup walks up the superclasses, so subclasses inherit and override methods as in
/// Objective-C.
public enum _IrisMethods {
    /// How to call one method on an instance: `.init(ViewController.tapped(_:))`. Arguments
    /// past the ones the method takes are dropped, as Objective-C drops them.
    public struct Method {
        let call: (AnyObject, Selector, [Any?]) -> Any?

        public init<T: AnyObject, R>(_ method: @escaping (T) -> () -> R) {
            call = { target, _, _ in method(target as! T)() }
        }

        public init<T: AnyObject, A, R>(_ method: @escaping (T) -> (A) -> R) {
            call = { target, selector, arguments in
                method(target as! T)(argument(0, of: arguments, for: selector, on: target))
            }
        }

        public init<T: AnyObject, A, B, R>(_ method: @escaping (T) -> (A, B) -> R) {
            call = { target, selector, arguments in
                method(target as! T)(
                    argument(0, of: arguments, for: selector, on: target),
                    argument(1, of: arguments, for: selector, on: target)
                )
            }
        }

        /// Delegate methods take three arguments at most, such as
        /// `collectionView(_:layout:sizeForItemAt:)`.
        public init<T: AnyObject, A, B, C, R>(_ method: @escaping (T) -> (A, B, C) -> R) {
            call = { target, selector, arguments in
                method(target as! T)(
                    argument(0, of: arguments, for: selector, on: target),
                    argument(1, of: arguments, for: selector, on: target),
                    argument(2, of: arguments, for: selector, on: target)
                )
            }
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var tables: [ObjectIdentifier: [Selector: Method]] = [:]

    /// Adds methods to a class, replacing those with the same selectors, as a category does.
    public static func register(_ cls: AnyClass, _ methods: [Selector: Method]) {
        lock.withLock {
            tables[ObjectIdentifier(cls), default: [:]].merge(methods) { $1 }
        }
    }

    /// The method a selector names on instances of `cls`, its own or a superclass's.
    static func method(_ selector: Selector, in cls: AnyClass) -> Method? {
        lock.withLock {
            var current: AnyClass? = cls
            while let cls = current {
                if let method = tables[ObjectIdentifier(cls)]?[selector] {
                    return method
                }
                current = _getSuperclass(cls)
            }
            return nil
        }
    }

    static func responds(_ target: AnyObject, to selector: Selector) -> Bool {
        method(selector, in: type(of: target)) != nil
    }

    /// Calls the method `selector` names on `target`, or stops the app as iOS does when there
    /// is none.
    @discardableResult
    public static func send(_ selector: Selector, to target: AnyObject, with arguments: [Any?]) -> Any? {
        guard let method = method(selector, in: type(of: target)) else {
            fatalError("-[\(String(reflecting: type(of: target))) \(selector)]: unrecognized selector sent to instance \(Unmanaged.passUnretained(target).toOpaque())")
        }
        return method.call(target, selector, arguments)
    }

    /// Argument `index`, as the type the method takes. Objective-C passes nil for missing
    /// arguments, and an `Any` parameter takes nil as an empty optional, as Swift's `@objc`
    /// thunks pass it.
    private static func argument<A>(_ index: Int, of arguments: [Any?], for selector: Selector, on target: AnyObject) -> A {
        let value = index < arguments.count ? arguments[index] : nil
        // Unwrapped first: an optional cast to `Any` would stay an optional inside it.
        if let value, let argument = value as? A {
            return argument
        }
        if value == nil, let argument = (value as Any) as? A {
            return argument
        }
        fatalError("-[\(String(reflecting: type(of: target))) \(selector)]: argument \(index + 1) is \(value.map { "a \(type(of: $0))" } ?? "nil"), not a \(A.self)")
    }
}

/// Iris: runs a class's registration of its methods, which irisrun-ios-build writes in an
/// extension of the class, as `_irisRegister { ViewController._irisMethods_…() }`. It is
/// isolated to the main actor with UIKit's classes, while a module registers its methods on
/// the thread that makes its first selector; that is safe, as it only fills the tables.
public func _irisRegister(_ registration: @escaping @MainActor @Sendable () -> Void) {
    unsafeBitCast(registration, to: (@Sendable () -> Void).self)()
}

/// Iris: `object` if it has a method for `selector`, else nil. irisrun-ios-build (P1-35) turns a
/// call to an optional requirement of an `@objc` protocol, `delegate?.method?(x)`, into
/// `_irisOptional(delegate, …)?.method(x)`, so that it is skipped when the method is missing,
/// as in Objective-C.
public func _irisOptional<T>(_ object: T?, _ selector: Selector) -> T? {
    guard let object, _IrisMethods.responds(object as AnyObject, to: selector) else { return nil }
    return object
}

extension NSObjectProtocol {
    public func responds(to aSelector: Selector!) -> Bool {
        aSelector.map { _IrisMethods.responds(self, to: $0) } ?? false
    }

    @discardableResult
    public func perform(_ aSelector: Selector!) -> Unmanaged<AnyObject>! {
        unmanagedResult(_IrisMethods.send(aSelector, to: self, with: []))
    }

    @discardableResult
    public func perform(_ aSelector: Selector!, with object: Any!) -> Unmanaged<AnyObject>! {
        unmanagedResult(_IrisMethods.send(aSelector, to: self, with: [object]))
    }

    @discardableResult
    public func perform(_ aSelector: Selector!, with object1: Any!, with object2: Any!) -> Unmanaged<AnyObject>! {
        unmanagedResult(_IrisMethods.send(aSelector, to: self, with: [object1, object2]))
    }
}

/// What `perform` returns: the object a method returned, unretained, and kept until the main
/// run loop's turn ends, as Darwin's autorelease pool keeps it; nil for other values.
// ponytail: methods returning optional objects give nil too; unwrap when an app needs it.
private func unmanagedResult(_ value: Any?) -> Unmanaged<AnyObject>? {
    guard let value, type(of: value) is AnyObject.Type else { return nil }
    let object = value as AnyObject
    let isFirst = performResultsLock.withLock {
        performResults.append(object)
        return performResults.count == 1
    }
    if isFirst {
        DispatchQueue.main.async {
            performResultsLock.withLock { performResults.removeAll() }
        }
    }
    return .passUnretained(object)
}

nonisolated(unsafe) private var performResults: [AnyObject] = []
private let performResultsLock = NSLock()
