# P0-07 · Objective-C trên Linux

15/10/2026 · Máy dev WSL2 Ubuntu 20.04, x86_64, 12 nhân dùng chung với các build khác. Swift 6.4.1 không chạy trên 20.04, nên mọi lệnh Swift, clang và CMake chạy trong container `swift:6.4.1-noble` (Ubuntu 24.04, thêm CMake 3.28 và Ninja).

## Kết luận

- **Go cho Objective-C bằng clang + libobjc2.** clang 21 có sẵn trong toolchain Swift 6.4.1 build được [libobjc2](https://github.com/gnustep/libobjc2) 2.3 (MIT). Bộ test của chính libobjc2 qua 190/190. Demo qua cả 26 kiểm tra: class, property, category, protocol, block, ARC và weak, `@autoreleasepool`, exception, target/action, `+resolveInstanceMethod:`, associated object, swizzling, cơ chế của KVO (isa swizzling), GCD và `@synchronized`.
- **Rẻ và nhỏ.** Build sạch mất 22–46 s, phần lớn là tải khoảng 4 MB. `libobjc.so` nặng 238 KB (195 KB sau khi strip). Không cần gói hệ thống nào ngoài toolchain Swift, CMake, Ninja hoặc Make, và git.
- **Swift gọi ObjC được ngay với toolchain gốc, qua C API của libobjc2.** Trong cùng process, code Swift gửi message tới class ObjC, cài closure thành method ObjC để target/action phía ObjC gọi vào, và truyền closure làm block. Đây là nền cho một bridge sinh tự động mà không cần toolchain riêng.
- **No-go cho "toolchain Swift bật ObjC interop" trong Phase 1–2.** Toolchain Linux chính thức không làm được: bật `-enable-objc-interop` thì ngay cả một class Swift không dính gì tới ObjC cũng không link được. Compiler sinh metadata theo ABI objc4 của Apple, khác layout class của libobjc2; runtime, stdlib và Foundation bản Linux đều build không có interop. Muốn có phải fork compiler, runtime và libobjc2: 38–63 người-tuần, cộng 6–12 người-tuần mỗi năm để theo kịp Swift. Upstream mới có đề xuất trên Swift Forums (3–6/2026), chưa có prototype.
- **`@objc`, `#selector`, KVO trong app Swift không chờ E2-03 được.** Trên 65 app của corpus P0-08, 44 app dùng `#selector` (29 trên 50 app SwiftUI), 42 app dùng `@objc`, 16 app dùng KVO, 15 app dùng `@IBOutlet`. Toolchain Linux báo lỗi với tất cả. Đề xuất đưa việc viết lại source (selector thành closure, KVO và KVC qua bảng sinh tự động) vào P1: 6–10 người-tuần, không cần ObjC runtime.
- **Code ObjC thật thì ít hơn:** 10/65 app (15%) có file `.m` trong app hoặc dùng pod ObjC (SDWebImage, MJRefresh, Firebase…). Chạy được chúng cần thêm Foundation và UIKit phía ObjC nối vào OpenKit: 21–32 người-tuần cho bản đầu. Đây là phần việc của E2-03.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Tải libobjc2 v2.3 (pin commit) và `Block_private.h` của libdispatch; build libobjc2 bằng clang của toolchain, link với `libBlocksRuntime` của toolchain; build và chạy demo | `native/objc/build.sh` |
| "Foundation" nhỏ nhất mà ObjC cần trên libobjc2: `NSObject` gốc, class cho literal `@"..."`, block thành object, hook forwarding gọi `+resolveInstanceMethod:` | `native/objc/MiniFoundation.h`, `native/objc/MiniFoundation.m` |
| 22 kiểm tra ObjC, rồi gọi phần Swift | `native/objc/demo.m` |
| 4 kiểm tra Swift↔ObjC qua C API của libobjc2 | `native/objc/Interop.swift` |
| Module map để Swift `import ObjCRuntime` (header của libobjc2) | `native/objc/module.modulemap` |

Cách làm và những chỗ phải biết:

1. **Một runtime block cho cả process.** libobjc2 build với `-DEMBEDDED_BLOCKS_RUNTIME=OFF` và link `libBlocksRuntime.so` của toolchain, thứ mà libdispatch và Swift cũng dùng. libobjc2 ghi `struct objc_class` vào các mảng `_NSConcrete*Block` (32 con trỏ) của runtime đó và đăng ký `_Block_use_RR2`. Nhờ vậy block thành object ObjC: có `-copy`, dùng được với ARC và property `copy`.
2. Toolchain không ship `Block_private.h`, header khai báo `_Block_use_RR2`. Script lấy file này từ libdispatch đúng tag `swift-6.4.1-RELEASE`, chỉ dùng lúc build.
3. **libobjc2 chỉ là runtime, không có class nào.** `MiniFoundation.m` (103 dòng) tự làm root class `NSObject`, refcount qua `objc_retain`/`objc_release`, và class cho chuỗi literal. Chuỗi ASCII dưới 9 ký tự là tagged pointer (tag 4); các chuỗi còn lại là `NSConstantString` theo layout của ABI gnustep-2.0. File này cũng cài hook `__objc_msg_forward2`: libobjc2 không tự gọi `+resolveInstanceMethod:`, nên thiếu hook thì message tới method không tồn tại trả về nil mà không báo lỗi.
4. **Selector có kiểu.** libobjc2 đăng ký selector có type encoding (từ message send) tách khỏi selector không kiểu (từ `@selector()`). Code viết cho Apple hay so sánh `sel == @selector(x)`, và phép so sánh này có thể sai. Hook chuyển sang selector không kiểu trước khi gọi `+resolveInstanceMethod:`.
5. **Swift không bật interop.** `Interop.swift` import header của libobjc2 như một module C. Swift gửi message bằng `objc_msg_lookup` rồi gọi IMP qua kiểu `@convention(c)`, và biến closure thành method bằng `imp_implementationWithBlock`. Swift coi `id` là con trỏ thường, nên phải tự gọi `objc_release`, và phải giữ closure sống bằng `withExtendedLifetime` cho tới khi ObjC copy block. Bridge sinh tự động sẽ phải làm đúng những việc này.
6. `swiftc` link cả object ObjC lẫn Swift; `main` trong `demo.m` gọi hàm Swift `swift_interop` (khai báo bằng `@_cdecl`).

Đã thử làm sai cố ý (đổi giá trị mong đợi ở cả phần ObjC lẫn Swift): demo báo đúng 3 chỗ sai và trả mã 1.

## Số đo

Máy dùng chung với các build Swift khác, nên thời gian dao động mạnh.

| Đo | Kết quả |
| --- | --- |
| Build sạch: clone libobjc2, header libdispatch, robin-map; configure; build; chạy demo | 22 s và 46 s ở hai lần chạy (lần đầu chưa có phần Swift); tải khoảng 4 MB |
| Chạy lại script khi đã có cache | 7–9 s |
| Build lại libobjc2 từ đầu (`--clean-first`, `-j 6`, 32 file object) | 1,2–5,8 s |
| clang compile `demo.m`; `swiftc` compile `Interop.swift` và link | 0,4–4,6 s; 1,5–8,4 s |
| Chạy demo (khởi động process, nạp runtime Swift, libobjc2, libdispatch) | 24–46 ms |
| Bộ test của libobjc2 (`ctest -j 6`) | 190/190 qua, 3–6 s |
| `libobjc.so.4.6` | 238 KB (195 KB sau khi strip) |
| Header cài đặt | 144 KB |
| Thư mục build | 7,2 MB: source 3,8 MB, build CMake 3 MB, bản cài 0,4 MB |
| File demo | 71 KB |

## Swift với ObjC interop

Thử trên toolchain Swift 6.4.1 chính thức cho Linux. Các file thử nằm ngoài repo; lệnh ở mục Chạy lại.

| Thử | Kết quả |
| --- | --- |
| `swiftc -enable-objc-interop` | `unknown argument`: đây là cờ của frontend, phải truyền qua `-Xfrontend` |
| `-Xfrontend -enable-objc-interop` với một class Swift bình thường, không dính gì tới ObjC | Compile được. Link lỗi vì thiếu `OBJC_CLASS_$__TtCs12_SwiftObject`, `OBJC_METACLASS_$__TtCs12_SwiftObject`, `_objc_empty_cache`, `objc_opt_self`; link thêm libobjc2 vẫn thiếu cả 4 symbol |
| `import` một module ObjC (header có `@interface`), không bật interop | Lỗi parse: ClangImporter đọc header như C |
| Như trên, có bật interop | Import được; subclass `NSObject` của header đó typecheck được |
| `@objc`, không bật interop | `Objective-C interoperability is disabled` |
| `@objc`, có bật interop | Đòi `import Foundation`; bỏ qua được bằng `-Xfrontend -disable-objc-attr-requires-foundation-module` |
| `#selector`, có bật interop | `import the 'ObjectiveC' module to use '#selector'`: Linux không có module Swift `ObjectiveC` |
| Subclass `NSObject` của header ObjC, có `@objc func`, bật interop | IR gọi `objc_msgSendSuper2`, `objc_opt_self`, `objc_allocWithZone`, tham chiếu `OBJC_CLASS_$_NSObject`, để selector trong section `objc_selrefs`. Link lỗi: libobjc2 không có `objc_msgSendSuper2`, `objc_opt_self`, `_objc_empty_cache`; còn clang (ABI gnustep-2.0) đặt tên class là `._OBJC_CLASS_NSObject` chứ không phải `OBJC_CLASS_$_NSObject` |
| Subclass `NSObject` của Foundation Linux, bật interop | Link lỗi: Foundation build không có interop nên không có metaclass `$s10Foundation8NSObjectCMm` |
| Không bật interop, bỏ `@objc`, subclass `NSObject` của Foundation Linux | Chạy được: `NSObject` của Foundation Linux là class Swift thuần |
| C API của libobjc2 từ Swift, không bật interop | Chạy được: `id` thành `UnsafeMutablePointer<objc_object>`; `SEL`, `Class`, `IMP` thành `OpaquePointer`; `@convention(block)` hoạt động. `Interop.swift` dùng cách này |

Vì sao không vá nhỏ được:

1. **Layout class khác nhau.** Khi bật interop, compiler đặt một class ObjC kiểu objc4 ở đầu metadata của mỗi class Swift: `isa, superclass, cache, vtable, data` (trong IR là `%objc_class = type { ptr, ptr, ptr, ptr, i64 }`), với `data` trỏ tới `class_ro_t` của Apple. `struct objc_class` của libobjc2 là `isa, super_class, name, version, info, instance_size, ivars, methods, dtable, …`. Ở offset 16 libobjc2 đọc `name`, còn Swift ghi `_objc_empty_cache`; ở offset 32 libobjc2 đọc cờ `info`, còn Swift ghi con trỏ tới `class_ro_t`. Object Swift không thể là object libobjc2 nếu một trong hai bên không đổi ABI. Issue [libobjc2#306](https://github.com/gnustep/libobjc2/issues/306) (mở từ 11/2024, chưa có quyết định) đi tới cùng chỗ đó. Tác giả nghiêng về một ABI libobjc2 mới, phải sửa cả clang lẫn IRGen của Swift; port objc4 sang ELF thì bị đánh giá là không đáng.
2. **Cách nạp metadata khác nhau.** Swift ghi class vào section `objc_classlist` và selector vào `objc_selrefs`, để dyld và objc4 xử lý lúc nạp. Trên ELF không có ai đọc các section này. libobjc2 cần các section `__objc_classes`, `__objc_selectors`… do clang sinh, và hàm `__objc_load` để đăng ký chúng.
3. **Runtime và stdlib.** Bản Linux build với `SWIFT_STDLIB_ENABLE_OBJC_INTEROP=FALSE`; CMake của Swift chỉ bật mặc định cho Darwin. `libswiftCore.so` không có `SwiftObject`, `swift_unknownObjectRetain`, `swift_getObjCClassMetadata`, `swift_dynamicCastObjCClass`… Đếm trong source Swift 6.4.1, phần phải port gồm: 6 file ObjC++ (3.676 dòng: `SwiftObject.mm`, `SwiftValue.mm`, `ErrorObject.mm`…) viết trên objc4; 223 chỗ `SWIFT_OBJC_INTEROP` trong 27 file runtime; 188 nhánh `_runtime(_ObjC)` trong 47 file stdlib (bridging `String`, `Array`, `Dictionary` với `NS*`). Các file này include `objc/NSObject.h`, `objc/objc-internal.h` (header riêng của objc4) và `Foundation/Foundation.h`; libobjc2 không có các header đó. Runtime nhắc tới 34 tên `objc_*` (hàm, biến và kiểu). libobjc2 có 12 hàm trong số đó (retain/release, weak, `objc_msgSend`, tìm class) và thiếu 14 hàm hoặc biến riêng của objc4, như `_objc_realizeClassFromSwift`, `objc_readClassPair`, `objc_setHook_getClass`, `objc_addLoadImageFunc`, `_objc_setClassCopyFixupHandler`.
4. **Compiler.** Code ObjC của IRGen nằm rải rác: 20 trên 170 file `.cpp`/`.h`, 66 chỗ kiểm `ObjCInterop`; riêng `GenObjC.cpp` có 1.776 dòng.
5. **Foundation.** Khi có interop, `NSString`, `NSArray`… phải là class ObjC thật để bridging với `String`, `Array`. Foundation trên Linux (swift-corelibs-foundation, swift-foundation) là Swift thuần. Phải chọn: dùng GNUstep Base (LGPL) kèm overlay bridging tự viết, hoặc bỏ bridging.

**Upstream.** Hendrik Hübner (có commit trong libobjc2) mở [thảo luận về tính khả thi](https://forums.swift.org/t/cross-platform-objective-c-interop-with-gnustep-feasibility-discussion/85306) (3/2026) và [đề xuất](https://forums.swift.org/t/cross-platform-swift-objective-c-interop-proposal/86668) (5/2026): một chế độ build riêng với ABI riêng, runtime phụ thuộc libobjc2 và GNUstep Base. Chưa có prototype hay PR. John McCall không ủng hộ bật interop kiểu Darwin cho mọi nền tảng; chế độ build riêng thì còn để ngỏ. Kyle-Ye, tác giả OpenSwiftUI và OpenAttributeGraph, ủng hộ đề xuất.

## App thật cần gì (corpus P0-08)

Quét source của 65 app trong corpus P0-08 (50 SwiftUI, 15 UIKit), bỏ qua `Pods/`, `Carthage/`, `.build/`. Bảng đếm số app dùng mỗi thứ ít nhất một lần. Đếm bằng regex nên chỉ là số thô; KVC đếm dư vì gồm cả `NSDictionary.value(forKey:)`, hàm có sẵn trên Linux.

| Dùng | Số app | Số dòng | Toolchain Linux |
| --- | --- | --- | --- |
| `#selector` | 44 (29 SwiftUI, 15 UIKit) | 1.419 | lỗi |
| `@objc` | 42 | 3.010 | lỗi |
| KVO: `@objc dynamic`, `observe(\.x)`, `forKeyPath:` | 16 (gộp; lần lượt 4, 8, 9) | 132 | lỗi, hoặc thiếu API |
| `@IBOutlet` / `@IBAction` | 15 / 10; storyboard hoặc XIB có ở 36 app | 1.561 / 451 | `@IBOutlet` lỗi khi kiểu là class Swift, tức mọi view của OpenKit; `@IBAction` qua |
| `@objcMembers` | 9 | 28 | lỗi |
| `@objc protocol`, requirement `optional` | 6, 5 | 32, 22 | lỗi |
| KVC: `value(forKey:)`, `setValue(_:forKey:)` | 29 | 228 | thiếu API, trừ ở `NSDictionary` |
| `NSSelectorFromString` | 8 | 28 | thiếu API (`NSClassFromString`, `NSStringFromClass` thì có sẵn) |
| Swizzling bằng runtime | 2 | 4 | không có runtime |
| Subclass `NSObject` | 56 | 478 | qua, nếu bỏ `@objc` |
| File `.m` trong app | 6: wikipedia (165 file), netnewswire (10), zlgithubclient (9), pass và yattee (helper bắt `NSException`), racerunner (1) | | cần clang + libobjc2 |
| Pod viết bằng ObjC | thêm 4: swifthub, jotify, say-their-names, bark | | cần clang + libobjc2 |

46/65 app (71%) dùng ít nhất một trong `#selector`, `@objc`, KVO, `@IBOutlet`, hoặc có file `.m`; tính cả KVC thì 53/65. Số app cần code ObjC (10) là cận dưới, vì chưa đọc các gói SPM có target ObjC.

`#selector` theo API: `NotificationCenter.addObserver` 336 dòng, `addTarget` 326, gesture recognizer 104, `UIBarButtonItem` 81, `sendAction` 20, `responds(to:)` 13, `CADisplayLink` 10, `Timer` 9, menu và phím tắt 7, `perform` 2. Thêm 185 dòng là đối số `selector:` hoặc `action:` của một lời gọi viết trên nhiều dòng. Như vậy ít nhất 77% số dòng đi qua API của UIKit và Foundation mà OpenKit tự viết (target/action, notification, timer, `responds(to:)`). OpenKit có thể nhận một `Selector` mang closure ở các API này, không cần ObjC runtime.

## Ước lượng công

Đơn vị là người-tuần (pw), tính cho người đã quen mảng đó. Khoảng rộng vì chưa ai làm, và vì chi tiết còn phụ thuộc OpenKit (P1-13, P1-16).

**A. App Swift dùng `@objc`, `#selector`, KVO, KVC, IB, không cần ObjC runtime. Đề xuất làm ở P1, cạnh P1-12: 6–10 pw.**

| Việc | pw |
| --- | --- |
| Bước viết lại bằng SwiftSyntax trong pipeline build: bỏ `@objc`, `@objcMembers`; `#selector(T.m(_:))` thành giá trị `Selector` mang tên và tham chiếu `T.m(_:)`, để compiler tự suy kiểu; `@objc dynamic var` thành property báo thay đổi; `@IBOutlet` thành property có trong bảng outlet; `@objc protocol` có `optional` thành protocol thường kèm cài đặt mặc định | 2–3 |
| OpenKit: kiểu `Selector`; target/action cho `UIControl`, gesture recognizer, `UIBarButtonItem`; `NotificationCenter`, `Timer`, `CADisplayLink`, `perform(_:with:afterDelay:)`, `responds(to:)` | 1–2 |
| KVO (`observe(\.x)`, `addObserver(_:forKeyPath:)`) và KVC (`value(forKey:)`, `setValue(_:forKey:)`) dựa trên bảng property sinh bằng macro hoặc bước viết lại | 2–3 |
| Nối bảng outlet và action vào bộ nạp storyboard và XIB của OpenKit; bản thân bộ nạp tính ở track UIKit | 1–2 |

Cách này không xử lý được: swizzling, selector dựng từ chuỗi lúc chạy mà không có trong bảng, và code ObjC gọi vào Swift. Các trường hợp đó cần hướng B.

**B. Code ObjC: file `.m`, pod ObjC, app UIKit viết bằng ObjC, app trộn Swift với ObjC (E2-03): 21–32 pw cho bản đầu.**

| Việc | pw |
| --- | --- |
| B1. Pipeline compile `.m`/`.mm` bằng clang (`-fobjc-runtime=gnustep-2.0 -fobjc-arc -fblocks`); ship libobjc2 bản build sẵn trong bộ tải toolchain (P1-02); module map | 1–2 |
| B2. Foundation phía ObjC trên libobjc2, nối sang swift-foundation: `NSObject`, `NSString`, `NSArray`, `NSDictionary`, `NSNumber`, `NSData`, `NSDate`, `NSError`, `NSException`, `NSNotificationCenter`, `NSUserDefaults`, `NSURL`, `NSTimer` và run loop. Forwarding đầy đủ (`NSInvocation`) cần libffi. Phương án khác là GNUstep Base (LGPL-2.1+, kéo theo libffi, ICU, libxml2…): 2–3 pw để tích hợp, nhưng hành vi khác Apple, và process có hai Foundation | 8–12 |
| B3. UIKit phía ObjC: sinh class ObjC bọc từng class Swift của OpenKit; ghép cặp object Swift với object ObjC; cho subclass ObjC override method (`viewDidLoad`…); delegate và data source có method optional; block; chuyển `NSString`↔`String` | 8–12, cộng phần đuôi dài theo bảng xếp hạng API |
| B4. App trộn: sinh wrapper Swift cho các class ObjC trong bridging header, gọi qua C API như `Interop.swift`. Helper nhỏ như hàm bắt `NSException` (pass, yattee) cũng cần bước này, vì Swift gọi nó qua bridging header | 4–6 |

**C. Toolchain Swift tự build, bật ObjC interop trên libobjc2. Không đề xuất lúc này: 38–63 pw, cộng 6–12 pw mỗi năm.**

| Việc | pw |
| --- | --- |
| libobjc2: ABI mới khớp layout class của Swift (issue #306); refcount và weak reference dùng chung với Swift; 14 hàm objc4 còn thiếu; sửa phần sinh code ObjC cho GNUstep trong clang (`CGObjCGNU`) theo ABI mới | 8–12 |
| IRGen của Swift: sinh metadata ObjC theo ABI mới (class, metaclass, method, ivar, protocol, category, selector, section ELF, `__objc_load`); bỏ các nhánh chỉ có ở objc4 (`objc_msgSendSuper2`, `objc_opt_*`, isa mask, tagged pointer) | 10–16 |
| Runtime và stdlib: port 6 file `.mm` (3.676 dòng), 223 chỗ `SWIFT_OBJC_INTEROP`, 188 nhánh `_runtime(_ObjC)`; cast và bridging | 10–16 |
| Module `ObjectiveC` (`Selector`, `ObjCBool`, `NSObject`, `autoreleasepool`) và Foundation có bridging (overlay cho GNUstep Base, hoặc tự viết) | 7–14 |
| Build toolchain từ source, đóng gói, chạy bộ test ObjC interop của Swift trên Linux | 3–5 |
| Theo kịp mỗi bản Swift (khoảng 2 bản mỗi năm) | 3–6 mỗi bản |

C thay được A, B3 và B4, nhưng vẫn cần B1. So sánh: A + B mất 27–42 pw và chỉ dùng toolchain gốc. C + B1 mất 39–65 pw, cộng chi phí theo Swift hằng năm, và rủi ro cao hơn nhiều vì là thay đổi ở mức ABI mà upstream chưa nhận.

Đề xuất cho cổng 0:

1. Làm A ở P1 (một người khoảng 2 tháng), vì 71% app trong corpus vướng ít nhất một thứ trong nhóm này.
2. Đổi E2-03 thành hướng B, làm theo nhu cầu: B1 và một phần B2 trước, sau đó B3/B4 theo danh sách pod và app hay gặp nhất.
3. Không làm C. Theo dõi đề xuất GNUstep interop trên Swift Forums và issue libobjc2#306; xem lại ở cổng 1 hoặc cổng 2 nếu upstream có prototype.

## Rủi ro

1. **Selector có kiểu** (mục Đã làm, ý 4): code ObjC so sánh SEL bằng `==` có thể chạy sai ở những chỗ hook chưa che.
2. **Code dựa vào nội bộ của objc4 hoặc Mach-O** sẽ không chạy, vì ABI của libobjc2 khác: không có non-pointer isa, tagged pointer theo kiểu khác. Có thể gặp ở thư viện hook Mach-O như fishhook, và ở công cụ debug chạy trong app như FLEX, LookinServer (có trong corpus); cần thử từng cái.
3. **libobjc2 sửa runtime block chung của cả process:** ghi class vào mảng `_NSConcrete*Block` và đăng ký `_Block_use_RR2`. Cách này phụ thuộc layout `libBlocksRuntime` của toolchain Swift, và `Block_private.h` phải lấy đúng tag. Cần kiểm lại mỗi lần lên bản Swift.
4. **Hai thế giới object.** Không có toll-free bridging giữa object ObjC và `String`/`Array` của Swift, nên mỗi lần qua ranh giới phải chuyển đổi. Qua C API thì không có ARC giữa hai bên: code sinh tự động phải tự retain và release đúng, sai là crash hoặc leak.
5. **Exception:** `NSException` đi xuyên qua frame Swift là hành vi không xác định (trên Apple cũng vậy). App tự viết helper bắt exception bằng ObjC (pass, yattee), nên các helper đó cần hướng B.
6. **Build cần mạng:** libobjc2, header của libdispatch, và robin-map (CMake của libobjc2 tự tải). P1-02 nên ship sẵn `libobjc.so` và header (khoảng 340 KB).
7. **libobjc2 v2.3 ra từ 16/09/2025.** Nhánh chính còn sửa lỗi sau đó, ví dụ leak khi block giữ block khác (06/10/2026). Nên pin commit mới hơn khi ship. Dự án ít người nhưng còn hoạt động (commit gần nhất 13/10/2026).
8. **Mới thử trên Linux x86_64** (Ubuntu 24.04 trong container). libobjc2 có `objc_msgSend` cho aarch64 nhưng chưa thử. Trên host macOS, Swift có sẵn ObjC interop của Apple: nên chạy cùng bước viết lại của hướng A ở mọi host, để app chạy giống nhau.
9. **Số liệu corpus là regex trên source**, chưa tính gói SPM có target ObjC. Nên chạy lại khi P0-08 có bảng xếp hạng API.
10. **Nếu sau này chọn C:** fork lệch ABI so với upstream, tốn công rebase mỗi bản Swift, và core team chưa cam kết nhận.

## License

| Thành phần | License | Dùng thế nào |
| --- | --- | --- |
| libobjc2 v2.3 | MIT | Build từ source, link động, sẽ ship cho dev |
| tsl::robin_map v1.4.0 (CMake của libobjc2 tự tải) | MIT | Header-only, compile vào `libobjc.so` |
| `Block_private.h` của swift-corelibs-libdispatch (`swift-6.4.1-RELEASE`) | Apache 2.0 kèm Runtime Library Exception | Chỉ dùng lúc build, không ship |
| clang, `libBlocksRuntime`, libdispatch, runtime Swift (toolchain swift.org) | Apache 2.0 (kèm LLVM Exception hoặc Runtime Library Exception) | Đã dùng sẵn cho iOS |

Không dùng file nào của Apple SDK, cũng không dùng objc4 (APSL 2.0). `MiniFoundation` tự viết, chỉ dùng tên API công khai (`NSObject`, `NSString`). Nếu chọn GNUstep Base (LGPL-2.1+) cho B2 thì cần tư vấn pháp lý trước.

## Chạy lại

Mọi lệnh chạy trong môi trường có Swift 6.4.1 (Ubuntu 22.04 hoặc 24.04; trên máy dev là container `swift:6.4.1-noble` có thêm CMake và Ninja).

```sh
JOBS=6 native/objc/build.sh     # build ở ~/.cache/irisrun/objc, in "all checks passed" và trả mã 0
```

Bộ test của libobjc2 (dùng source và header mà script vừa tải; `/usr` là chỗ cài toolchain trong container):

```sh
cd ~/.cache/irisrun/objc
inc=-I$PWD/libdispatch/src/BlocksRuntime
cmake -S libobjc2 -B build-tests -G Ninja -DTESTS=ON -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DEMBEDDED_BLOCKS_RUNTIME=OFF \
  -DCMAKE_LIBRARY_PATH=/usr/lib/swift/linux -DCMAKE_REQUIRED_INCLUDES=$PWD/libdispatch/src/BlocksRuntime \
  -DCMAKE_C_FLAGS=$inc -DCMAKE_CXX_FLAGS=$inc -DCMAKE_OBJC_FLAGS=$inc -DCMAKE_OBJCXX_FLAGS=$inc
cmake --build build-tests -j 6 && (cd build-tests && ctest -j 6)
```

Thử ObjC interop của Swift:

```sh
printf 'final class Box { var n = 1 }\nprint(Box().n)\n' > box.swift
swiftc -Xfrontend -enable-objc-interop box.swift                # link lỗi: SwiftObject, _objc_empty_cache, objc_opt_self
swiftc -Xfrontend -enable-objc-interop -emit-ir box.swift -o - | grep -E 'objc_class =|objc_classlist|SwiftObject'
printf 'class C {\n  @objc func f() {}\n}\n' > attr.swift
swiftc -typecheck attr.swift                                    # Objective-C interoperability is disabled
swiftc -typecheck -Xfrontend -enable-objc-interop attr.swift    # đòi import Foundation
```

Đếm trong corpus (bash, GNU grep; app do P0-08 clone):

```sh
cd ~/.cache/irisrun/ios-corpus/apps
apps() { grep -rlE --include='*.swift' --exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=.build \
  --exclude-dir=.git "$1" . | cut -d/ -f2 | sort -u | wc -l; }
apps '#selector\s*\('    # 44
apps '@objc\b'           # 42
apps '@IBOutlet'         # 15
apps '@objc\s+dynamic|\.observe\(\s*\\\.|forKeyPath:'    # 16
```

Đếm trong source Swift (clone thưa, chỉ lấy runtime, stdlib và IRGen):

```sh
git clone --depth 1 --filter=blob:none --sparse -b swift-6.4.1-RELEASE https://github.com/swiftlang/swift.git
cd swift && git sparse-checkout set stdlib/public/runtime stdlib/public/core lib/IRGen
cat stdlib/public/runtime/*.mm | wc -l                                       # 3676
grep -o SWIFT_OBJC_INTEROP stdlib/public/runtime/* | wc -l                  # 223
grep -oF '_runtime(_ObjC)' stdlib/public/core/*.swift | wc -l                # 188
```
