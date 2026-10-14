// Plain Objective-C on libobjc2: classes, properties, categories, protocols,
// blocks, ARC + weak, @autoreleasepool, exceptions, runtime tricks, GCD.
#import "MiniFoundation.h"
#include <dispatch/dispatch.h>
#include <stdio.h>
#include <string.h>

static int failures, deallocs;
#define CHECK(c) do { if (!(c)) { failures++; printf("FAIL line %d: %s\n", __LINE__, #c); } } while (0)

@protocol Greeter
- (const char *)greet;
@optional
- (void)wave;
@end

@interface Person : NSObject <Greeter>
@property (nonatomic, copy) NSString *name;
@property (nonatomic, weak) Person *friend;
@property (nonatomic, copy) void (^onGreet)(const char *);
+ (instancetype)personNamed:(NSString *)name;
@end

@implementation Person
+ (instancetype)personNamed:(NSString *)name
{
  Person *p = [self new];
  p.name = name;
  return p;
}
- (const char *)greet
{
  if (self.onGreet) self.onGreet([self.name UTF8String]);
  return [self.name UTF8String];
}
- (void)dealloc { deallocs++; }
@end

@interface Person (Shouting)
- (int)shoutLength;
@end

@implementation Person (Shouting)
- (int)shoutLength { return (int)[self.name length] + 1; }
@end

@interface DemoError : NSObject
@property (nonatomic) int code;
@end
@implementation DemoError
@end

// UIKit-style target/action, the pattern #selector exists for.
@interface Button : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
- (void)tap;
@end
@implementation Button
- (void)tap { ((void (*)(id, SEL, id))objc_msgSend)(self.target, self.action, self); }
@end

@interface Controller : NSObject
@property (nonatomic) int taps;
@end
@implementation Controller
- (void)buttonTapped:(Button *)sender { self.taps++; }
@end

// Dynamic method resolution, as used by @dynamic and many pods.
static int answer(id self, SEL _cmd) { return 42; }
@interface Dynamic : NSObject
@end
@interface Dynamic (Resolved)
- (int)answer;
@end
@implementation Dynamic
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
  if (sel == @selector(answer))
    return class_addMethod(self, sel, (IMP)answer, "i@:");
  return NO;
}
@end

static int thrower(int code)
{
  DemoError *e = [DemoError new];
  e.code = code;
  @throw e;
}

static const char *original(id self, SEL _cmd) { return "swizzled"; }

int main(void)
{
  @autoreleasepool {
    // Literals: short ones are tagged pointers, longer ones NSConstantString.
    CHECK(strcmp([@"Ada" UTF8String], "Ada") == 0);
    CHECK(strcmp([@"Grace Hopper" UTF8String], "Grace Hopper") == 0);

    // Classes, properties, categories, protocols.
    Person *ada = [Person personNamed:@"Ada"];
    CHECK(strcmp([ada greet], "Ada") == 0);
    CHECK([ada shoutLength] == 4);
    CHECK([ada conformsToProtocol:@protocol(Greeter)]);
    CHECK(![ada respondsToSelector:@selector(wave)]);
    CHECK([ada isKindOfClass:[NSObject class]]);

    // Blocks: capture, __block, heap copy stored in a property.
    __block int greeted = 0;
    int bonus = 10;
    ada.onGreet = ^(const char *n) { greeted += bonus + (int)strlen(n); };
    [ada greet];
    CHECK(greeted == 13);

    // ARC: weak references zero out, dealloc runs when the last strong ref goes.
    int before = deallocs;
    @autoreleasepool {
      Person *grace = [Person personNamed:@"Grace Hopper"];
      ada.friend = grace;
      CHECK(ada.friend == grace);
    }
    CHECK(ada.friend == nil);
    CHECK(deallocs == before + 1);

    // @autoreleasepool drains autoreleased objects.
    before = deallocs;
    @autoreleasepool {
      __autoreleasing Person *tmp = [Person new];
      CHECK(deallocs == before);
      CHECK(tmp != nil); // a use after the check, or ARC may release it early
    }
    CHECK(deallocs == before + 1);

    // Exceptions: typed catch, @finally, rethrow.
    int caught = 0, finals = 0;
    @try {
      @try { thrower(7); }
      @finally { finals++; }
    }
    @catch (DemoError *e) { caught = e.code; }
    CHECK(caught == 7 && finals == 1);
    @try {
      @try { thrower(8); }
      @catch (id e) { @throw; }
    }
    @catch (DemoError *e) { caught = e.code; }
    CHECK(caught == 8);

    // Selectors and target/action.
    Controller *c = [Controller new];
    Button *b = [Button new];
    b.target = c;
    b.action = @selector(buttonTapped:);
    [b tap];
    [b tap];
    CHECK(c.taps == 2);

    // Runtime: dynamic resolution, associated objects, swizzling.
    CHECK([[Dynamic new] answer] == 42);
    static char key;
    objc_setAssociatedObject(ada, &key, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CHECK(objc_getAssociatedObject(ada, &key) == c);
    Method m = class_getInstanceMethod([Person class], @selector(greet));
    IMP old = method_setImplementation(m, (IMP)original);
    CHECK(strcmp([ada greet], "swizzled") == 0);
    method_setImplementation(m, old);

    // GCD from Objective-C, with ObjC objects captured in blocks.
    dispatch_group_t g = dispatch_group_create();
    __block int sum = 0;
    for (int i = 1; i <= 10; i++)
      dispatch_group_async(g, dispatch_get_global_queue(0, 0), ^{
        __sync_fetch_and_add(&sum, i + [ada shoutLength] - 4);
      });
    dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
    dispatch_release(g); // GCD objects are not ObjC objects on Linux
    CHECK(sum == 55);
  }
  printf(failures ? "%d check(s) failed\n" : "all checks passed\n", failures);
  return failures != 0;
}
