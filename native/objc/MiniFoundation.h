// The smallest "Foundation" plain Objective-C needs on libobjc2: a root class
// and the string classes clang emits for @"..." literals. Not GNUstep Base.
#import <objc/runtime.h>
#import <objc/message.h>

__attribute__((objc_root_class))
@interface NSObject
{
  Class isa;
}
+ (instancetype)alloc;
+ (instancetype)new;
+ (Class)class;
+ (BOOL)resolveInstanceMethod:(SEL)sel;
+ (BOOL)resolveClassMethod:(SEL)sel;
- (instancetype)init;
- (Class)class;
- (id)copy;
- (BOOL)isKindOfClass:(Class)cls;
- (BOOL)respondsToSelector:(SEL)sel;
- (BOOL)conformsToProtocol:(Protocol *)protocol;
#if !__has_feature(objc_arc)
- (id)retain;
- (void)release;
- (id)autorelease;
- (void)dealloc;
#endif
@end

// clang types every @"..." literal as NSString *.
@interface NSString : NSObject
- (const char *)UTF8String;
- (unsigned)length;
@end

// Layout fixed by clang's gnustep-2.0 ABI (literals of 9+ chars or non-ASCII).
@interface NSConstantString : NSString
{
  uint32_t flags;
  uint32_t length;
  uint32_t size;
  uint32_t hash;
  const char *str;
}
@end
