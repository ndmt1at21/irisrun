// Swift half of the demo, called from demo.m. The stock Linux toolchain has ObjC
// interop off, so Swift cannot see ObjC classes or use @objc and #selector; it
// goes through libobjc2's C API instead, as a generated bridge would.
import ObjCRuntime

/// Looks up `name` on `receiver`, as every libobjc2 message send does, and
/// returns the IMP typed as the C function F, with its selector.
private func lookup<F>(_ receiver: id?, _ name: String, as _: F.Type) -> (F, SEL?) {
  let sel = sel_registerName(name)
  return (unsafeBitCast(objc_msg_lookup(receiver, sel), to: F.self), sel)
}

// One wrapper per method signature, the part a bridge generator would emit.
private func send(_ receiver: id?, _ name: String) {
  let (imp, sel) = lookup(receiver, name, as: (@convention(c) (id?, SEL?) -> Void).self)
  imp(receiver, sel)
}

private func send(_ receiver: id?, _ name: String, _ arg: id?) {
  let (imp, sel) = lookup(receiver, name, as: (@convention(c) (id?, SEL?, id?) -> Void).self)
  imp(receiver, sel, arg)
}

private func send(_ receiver: id?, _ name: String, _ arg: SEL?) {
  let (imp, sel) = lookup(receiver, name, as: (@convention(c) (id?, SEL?, SEL?) -> Void).self)
  imp(receiver, sel, arg)
}

private func sendInt32(_ receiver: id?, _ name: String) -> Int32 {
  let (imp, sel) = lookup(receiver, name, as: (@convention(c) (id?, SEL?) -> Int32).self)
  return imp(receiver, sel)
}

private func new(_ className: String) -> id? {
  let cls = objc_getClass(className)
  let (imp, sel) = lookup(cls, "new", as: (@convention(c) (id?, SEL?) -> id?).self)
  return imp(cls, sel)
}

/// Hands a Swift closure to ObjC as a block. Swift sees the `id` as a plain
/// pointer, so the closure must outlive the call; the callee copies the block.
private func withBlock<T, R>(_ closure: T, _ body: (id) -> R) -> R {
  withExtendedLifetime(closure) { body(unsafeBitCast(closure, to: id.self)) }
}

@_cdecl("swift_interop")
func swiftInterop() -> Int32 {
  var failures: Int32 = 0
  func check(_ ok: Bool, _ what: String) {
    if !ok { failures += 1; print("FAIL Swift: \(what)") }
  }

  // Swift calls ObjC: button.target = controller; button.action = @selector(buttonTapped:).
  let controller = new("Controller"), button = new("Button")
  defer { objc_release(button); objc_release(controller) }
  send(button, "setTarget:", controller)
  send(button, "setAction:", sel_registerName("buttonTapped:"))
  send(button, "tap")
  check(sendInt32(controller, "taps") == 1, "-[Button tap] reached -[Controller buttonTapped:]")

  // ObjC calls Swift: a closure becomes -[Controller swiftTapped:], which the
  // ObjC button reaches through target/action, as UIKit would.
  var swiftTaps = 0
  let tapped: @convention(block) (id?, id?) -> Void = { this, sender in
    if this == controller && sender == button { swiftTaps += 1 }
  }
  let added = withBlock(tapped) {
    class_addMethod(OpaquePointer(objc_getClass("Controller")), sel_registerName("swiftTapped:"),
                    imp_implementationWithBlock($0), "v@:@")
  }
  check(added != 0, "class_addMethod")
  send(button, "setAction:", sel_registerName("swiftTapped:"))
  send(button, "tap")
  send(button, "tap")
  check(swiftTaps == 2, "ObjC target/action called the Swift closure")

  // A Swift closure stored in an ObjC block property and called by -[Person greet].
  let person = new("Person")
  defer { objc_release(person) }
  var greeted = false
  let onGreet: @convention(block) (UnsafePointer<CChar>?) -> Void = { _ in greeted = true }
  withBlock(onGreet) { send(person, "setOnGreet:", $0) }
  send(person, "greet")
  check(greeted, "ObjC called a Swift closure passed as a block")
  return failures
}
