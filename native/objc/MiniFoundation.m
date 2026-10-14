// Compiled without -fobjc-arc: it implements reference counting itself.
#import "MiniFoundation.h"
#import <objc/objc-arc.h>
#import <objc/hooks.h>
#include <stdio.h>
#include <stdlib.h>

// Exported by libobjc2 but not declared in its headers.
BOOL objc_create_block_classes_as_subclasses_of(Class super);

// libobjc2 leaves +resolveInstanceMethod: and unknown selectors to the
// Foundation; without this hook an unknown message silently returns nil.
static IMP forward(id receiver, SEL sel)
{
  Class cls = object_getClass(receiver);
  BOOL meta = class_isMetaClass(cls);
  id target = meta ? receiver : (id)cls;
  SEL resolve = meta ? @selector(resolveClassMethod:) : @selector(resolveInstanceMethod:);
  // Message sends carry typed selectors, @selector() literals untyped ones;
  // pass the untyped one so Apple-style `sel == @selector(x)` checks work.
  SEL untyped = sel_registerName(sel_getName(sel));
  if (((BOOL (*)(id, SEL, SEL))objc_msgSend)(target, resolve, untyped))
  {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) return method_getImplementation(m);
  }
  fprintf(stderr, "unrecognized selector %c[%s %s]\n", meta ? '+' : '-',
          class_getName(meta ? (Class)receiver : cls), sel_getName(sel));
  abort();
}

@implementation NSObject
+ (void)load
{
  // Makes blocks real objects (so -copy, ARC and properties work on them).
  objc_create_block_classes_as_subclasses_of(self);
  __objc_msg_forward2 = forward;
}
+ (BOOL)resolveInstanceMethod:(SEL)sel { return NO; }
+ (BOOL)resolveClassMethod:(SEL)sel { return NO; }
+ (instancetype)alloc { return class_createInstance(self, 0); }
+ (instancetype)new { return [[self alloc] init]; }
+ (Class)class { return self; }
- (instancetype)init { return self; }
- (Class)class { return object_getClass(self); }
- (id)copy { return [self retain]; }
- (id)retain { return objc_retain(self); }
- (void)release { objc_release(self); }
- (id)autorelease { return objc_autorelease(self); }
- (void)dealloc { object_dispose(self); }
// Tells libobjc2 that retain/release are the stock ones, enabling its ARC fast paths.
- (void)_ARCCompliantRetainRelease {}
- (BOOL)isKindOfClass:(Class)cls
{
  for (Class c = object_getClass(self); c; c = class_getSuperclass(c))
    if (c == cls) return YES;
  return NO;
}
- (BOOL)respondsToSelector:(SEL)sel
{
  return class_respondsToSelector(object_getClass(self), sel);
}
- (BOOL)conformsToProtocol:(Protocol *)protocol
{
  for (Class c = object_getClass(self); c; c = class_getSuperclass(c))
    if (class_conformsToProtocol(c, protocol)) return YES;
  return NO;
}
@end

@implementation NSString
- (const char *)UTF8String { return 0; }
- (unsigned)length { return 0; }
- (id)retain { return self; }
- (void)release {}
- (id)autorelease { return self; }
@end

@implementation NSConstantString
- (const char *)UTF8String { return str; }
- (unsigned)length { return length; }
@end

// On 64-bit, clang encodes ASCII literals shorter than 9 chars in the pointer
// itself: 7 bits per char from bit 57 down, length in bits 3-6, tag 4.
@interface NSTinyString : NSString
@end

@implementation NSTinyString
+ (void)load { objc_registerSmallObjectClass_np(self, 4); }
- (unsigned)length { return ((uintptr_t)self >> 3) & 0xf; }
- (const char *)UTF8String
{
  // ponytail: one buffer per thread, overwritten by the next call; fine for a demo.
  static __thread char buf[9];
  uintptr_t v = (uintptr_t)self;
  unsigned n = [self length];
  for (unsigned i = 0; i < n; i++)
    buf[i] = (v >> (57 - i * 7)) & 0x7f;
  buf[n] = 0;
  return buf;
}
@end
