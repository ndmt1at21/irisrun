# P1-35 · Viết lại `@objc`, `#selector`, IB và KVO bằng SwiftSyntax

16/10/2026 · Máy dev WSL2 Ubuntu 20.04, Swift 6.4.1 trong container `irisrun-swift-dev:6.4.1`. Kế hoạch và hợp đồng với runtime: mục "Hợp đồng cho P1-35" của [plans/p1-16-uikit.md](../plans/p1-16-uikit.md). Bối cảnh: [P0-07](p0-07-objc-linux.md) mục A, [P1-16](p1-16-uikit.md) phần 1b.

## Kết luận

- **Đạt tiêu chí của task.** App UIKit mẫu `examples/ios-uikit` giờ dùng `#selector` với `UITapGestureRecognizer` (chạm hai lần), `UIPanGestureRecognizer`, `UILongPressGestureRecognizer`, `addTarget(_:action:for:)` với method `@objc` và `@IBAction`, observer `NotificationCenter` và `Timer` theo selector. Đó là code iOS 17 hợp lệ, không có `#if` hay API riêng của Iris, và build không sửa dòng nào: `check-sample.sh examples/ios-uikit` đạt 34 điểm (26 cũ, 8 mới) ở cả chế độ stdout lẫn frame. Trong Device UI chạm hai lần, kéo và giữ đều có hiệu lực.
- **Trong corpus không app nào còn vướng `@objc`/`#selector`.** Typecheck module của từng app với OpenKit trước bước viết lại: 34 app có lỗi do tính năng Objective-C, 3.601 lỗi, trong đó `Objective-C interoperability is disabled` 1.534 lỗi ở 30 app và `#selector` 1.825 lỗi ở 32 app. Sau bước viết lại: không còn lỗi nào do `@objc`, `#selector`, `@IBOutlet`, `#keyPath` hay `optional`, và code bước viết lại sinh ra không gây lỗi nào ngoài lỗi kéo theo khi kiểu nó nhắc tới chưa có (`@IBOutlet var label: UILabel!` trước khi OpenUIKit có `UILabel`). Phần chưa làm được có số ở mục Corpus: KVO kiểu cũ (4 app), `@NSManaged` (4 app), method của class generic (3 app), một chỗ dùng runtime Objective-C thật (swiftfin).
- **Mọi dòng của app giữ nguyên số dòng:** `irisrun-ios-build` sửa tại chỗ (bỏ attribute, đổi biểu thức), dấu xuống dòng của đoạn bị thay đi theo sau phần thay, và code sinh thêm nằm sau dòng cuối của file. Lỗi compile và stack trace vẫn chỉ đúng dòng của dev.
- **Bảng outlet và action là bảng method sẵn có, đọc qua KVC như UIKit.** Outlet là setter `setLabel:`, đặt bằng `setValue(_:forKey:)`; action là method `@IBAction` theo đúng tên selector Xcode ghi trong storyboard. Bộ nạp storyboard/XIB của đợt 6 không cần API mới.
- **P1-35 tìm ra một lỗi của Foundation trên Linux** làm mọi gesture recognizer có hẹn giờ hỏng khi RunLoop chạy: `Timer(timeInterval:repeats:block:)` chạy ngay chứ không chờ. Chạm hai lần không bao giờ nhận ra, long press nhận ra ngay sau khi chạm xuống thay vì sau 0,5 s, `Timer` theo selector và `perform(_:with:afterDelay:)` chạy ngay. Đã sửa trong OpenUIKit và IrisObjC (tạo timer với ngày chạy).

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Bước viết lại bằng SwiftSyntax (604, cho phép 603 trong đồ thị của app): đọc mọi file của target, giải `#selector` theo khai báo, sửa tại chỗ, sinh bảng ở cuối file và file đăng ký của module | `runtimes/ios/Sources/IrisBuild/ObjCSources.swift` (mới), `PackageWriter.swift` |
| Summary JSON của `irisrun-ios-build` có thêm `objc`: số cấu trúc tìm thấy, viết lại và còn lại theo loại | `Sources/irisrun-ios-build/main.swift` |
| Factory `_IrisInstantiable` gọi `_ = _irisMethodsRegistered`, để app UIKit có bảng ngay lúc khởi động | `UIKitSources.swift` |
| `Method.init` 3 tham số, `_irisRegister`, `_irisOptional`, `Timer(fireAt:interval:target:selector:userInfo:repeats:)` | `Sources/IrisObjC/Selector.swift`, `TargetSelector.swift` |
| KVC (`value(forKey:)`, `setValue(_:forKey:)`, theo key path, `UserDefaults`) và KVO (`observe(_:options:changeHandler:)`, `NSKeyValueObservation`, `NSKeyValueObservingOptions`, `NSKeyValueObservedChange`, `_irisDidChangeValue`) trên bảng method | `Sources/IrisObjC/KeyValueCoding.swift` (mới) |
| Timer có ngày chạy thật: timer theo selector, `perform(_:with:afterDelay:)`, timer của gesture recognizer | `TargetSelector.swift`, `Sources/OpenUIKit/GestureRecognizers.swift` |
| App fixture có mọi dạng ObjC (code iOS hợp lệ), bản viết lại của nó được so từng ký tự và kiểm số dòng | `Tests/IrisBuildTests/Fixtures/ObjCApp.swift`, `ObjCRewriterTests.swift` |
| Bản viết lại đó build như app (Swift 5, alias `UIKit`, `-import-module IrisObjC`) và chạy: selector tới method private, override, class lồng nhau, KVC, outlet, KVO, protocol optional, notification | target mới `Tests/ObjCRewriteTests` |
| App mẫu dùng selector, recognizer, `@IBAction`, notification, timer; `session.txt` 34 điểm | `examples/ios-uikit` |
| Công cụ đo corpus: chạy bước viết lại trên 65 app, typecheck trước và sau với OpenKit (module thiếu thành module rỗng), tóm tắt lỗi | `~/.cache/irisrun/devtools/objc-corpus-rewrite.sh`, `objc-corpus-typecheck.py`, `objc-corpus-typecheck-all.sh`, `objc-corpus-summary.py` |

## Quy tắc viết lại

| Trong app | Thành | Ghi chú |
| --- | --- | --- |
| `#selector(m)`, `#selector(m(_:))`, `#selector(T.m(a:b:))`, `#selector(self.m)`, `#selector(super.m)`, `#selector(getter: T.p)`, `#selector(setter: T.p)`, `#selector((m))`, `#selector(m as …)` | `_irisSelector("tênObjC")` | Tên theo quy tắc của compiler: `tapped(_:)` → `tapped:`, `tapped(sender:)` → `tappedWithSender:`, `do(with:and:)` → `doWith:and:`, `move(to:)` → `moveTo:` (không thêm "With" khi nhãn đầu hay tên method là giới từ), `init(name:)` → `initWithName:`; `@objc(tên:)` thắng; setter `setP:`. Không ghi nhãn thì giải theo khai báo; không thấy khai báo (method của UIKit) thì theo cú pháp. Selector viết trên nhiều dòng: dấu xuống dòng đi sau lời gọi |
| `Selector("x")`, `NSSelectorFromString(x)` | `_irisSelector("x")`, `_irisSelector(x)` | Để mọi selector đi qua điểm móc đăng ký |
| `#keyPath(UIView.layer.cornerRadius)` | `"layer.cornerRadius"` | Bỏ các thành phần đầu viết hoa |
| `@objc`, `@objc(tên)`, `@objcMembers`, `@nonobjc`, `@IBAction`, `@IBOutlet`, `@IBInspectable`, `@IBDesignable`, `@IBSegueAction`, `@GKInspectable` | (bỏ, giữ dòng) | `dynamic` ở lại: Linux nhận nó ở mọi chỗ đã thử (property, method, `let`, extension, struct, class generic) |
| `@objc protocol P` | `protocol P: AnyObject` | `optional` bị bỏ; requirement optional có hiện thực trong `extension P` gửi selector qua bảng |
| `x?.m?(a)`, `x.m!(a)` với `m` là requirement optional của protocol `@objc` trong module | `_irisOptional(x, _irisSelector("m:"))?.m(a)`, `x.m(a)` | Khớp theo tên và nhãn đối số; closure optional của app (`onSelect?(x)`) không bị đụng |
| Property lưu trữ `dynamic` của class `@objc` | thêm `didSet { _irisDidChangeValue(self, \T.p, from: oldValue) }` cùng dòng | Hoặc chèn lời gọi vào đầu `didSet` sẵn có |
| `X.removeObserver(o)`, `X.removeObserver(o, name:, object:)` khi `X` chứa "center" | `X._irisRemoveObserver(…)` | KVO `removeObserver(_:forKeyPath:)` và hàm `removeObserver` của app giữ nguyên |
| (cuối mỗi file) | extension đăng ký method của từng class, hàm `_irisRegisterMethods_<file>()`, hiện thực requirement optional | Trong cùng `#if` với khai báo |
| (mỗi module) | `Sources/<module>/_IrisMethodTables.swift`: `_irisMethodsRegistered`, `_irisSelector(_:)` | |

Được đăng ký: member có attribute ObjC hay IB, member của extension `@objc`, mọi member của class `@objcMembers` và lớp con của nó, member mà một `#selector` gọi tên (kể cả override của method UIKit như `layoutSubviews`), và member hiện thực requirement của protocol `@objc` trong module, kể cả khi chỉ lớp cha adopt protocol. Method có tham số được đăng ký bằng tham chiếu chưa áp dụng (`.init(T.m(_:))`), method không tham số và property bằng closure.

## Quyết định

- **swift-syntax `"603.0.0" ..< "605.0.0"`, resolve ra 604.0.0** (bản cho Swift 6.4, như `tools/ios-corpus`). Package của app phụ thuộc `runtimes/ios` cạnh OpenSwiftUI, mà OpenObservation chỉ nhận swift-syntax 603: ghi `from: "604.0.0"` thì SwiftPM không resolve được đồ thị của app (đã thử). App không build IrisBuild, nên trong đồ thị đó 603 chỉ để resolve.
- **Bảng đăng ký từ bên trong extension của từng class.** `@objc private func tapped()` rất phổ biến; hàm ở mức file không với tới member `private`, extension trong cùng file thì được. Hàm static trong extension của class UIKit gắn main actor, và ở Swift 5 mode gọi nó từ hàm không cô lập là lỗi; đánh `nonisolated` thì closure bên trong lỗi, key path tới property cô lập thành cảnh báo, `@Sendable` cũng cảnh báo (đã thử cả bốn cách). Cách sạch: hàm của file gọi `_irisRegister { T._irisMethods_…() }`; closure nhận isolation main actor từ tham số, và `_irisRegister` gọi nó ở luồng hiện tại (`unsafeBitCast` bỏ isolation: hàm chỉ điền bảng). Kết quả: bản viết lại của fixture build ở Swift 5 không một cảnh báo.
- **Method không tham số đăng ký bằng closure `{ (o: T) in { o.m() } }`**, vì `T.m` mơ hồ khi class có overload cùng tên, như `dismiss()` của app cạnh `dismiss(animated:completion:)` của UIKit. Method có tham số dùng tham chiếu có nhãn như hợp đồng của 1b.
- **Không có bảng outlet và action riêng.** iOS nối outlet bằng KVC (`setValue:forKey:`) và action bằng selector; Iris làm y như vậy trên bảng method: outlet và `@IBInspectable` có getter và setter trong bảng, `@IBAction` có tên selector đúng như Xcode ghi. API nhỏ nhất là KVC, thứ app cũng dùng trực tiếp.
- **Requirement optional của protocol `@objc`:** Swift không có requirement optional ngoài ObjC, nên requirement thành bắt buộc, hiện thực mặc định trong extension gửi selector qua bảng, còn lời gọi `?.m?(…)` hỏi `responds(to:)` trước (`_irisOptional`). Hành vi khớp iOS: object không có method thì không gọi và biểu thức là nil (`delegate?.preferredSize?(for: self) ?? 44` cho 44); lớp con có method mà lớp cha adopt protocol thì vẫn được gọi, giới hạn mà hợp đồng 1b ghi đã hết với protocol của app. Trong corpus có 23 protocol `@objc` (4 app), 10 requirement optional và 9 lời gọi.
- **KVO bằng `didSet` sinh lúc build và danh sách observation.** Chỉ property lưu trữ `dynamic` của class `@objc` báo thay đổi, như ObjC chỉ bảo đảm KVO cho `@objc dynamic`. Observation khớp theo key path (`\Counter.count`), nên key path phải bắt đầu từ class khai báo property. Trong corpus, `observe(\.x)` lên object của chính app chỉ có ở wikipedia; phần lớn là `WKWebView`, `AVPlayer`, `UIScrollView`, `Progress`, việc của framework (P1-17, P1-18, đợt 2): OpenUIKit gọi cùng `_irisDidChangeValue` là đủ.
- **`removeObserver` nhận theo receiver.** Đổi mọi `removeObserver(_:)` sẽ làm hỏng hàm cùng tên của app (`store.removeObserver(x)` ở pilgrim và hai app khác); receiver chứa "center" khớp mọi lời gọi tới NotificationCenter trong corpus (114 dòng, gồm 10 dòng `NSWorkspace.shared.notificationCenter` của macOS) và không khớp hàm nào của app.
- **Kiểm bằng fixture vàng.** `IrisBuildTests` so bản viết lại của `Fixtures/ObjCApp.swift` với `Tests/ObjCRewriteTests/ObjCApp.swift` từng ký tự (chạy cả trên macOS), còn target `ObjCRewriteTests` build chính file đó như build app và chạy. Đổi bước viết lại thì sinh lại hai file bằng `irisrun-ios-build Tests/IrisBuildTests/Fixtures` (lệnh ở chú thích của test).
- **Chạm hai lần trong app mẫu đặt trên tay nắm kéo, không trên touch pad như 1b định.** Kịch bản chạm touch pad rồi giữ ngay; với recognizer chạm hai lần trên pad, cặp đó trên iOS cũng là chạm hai lần, và điểm "Touch pad: 2 taps" sẽ sai. Chạm hai lần đưa tay nắm về chỗ cũ (`# expect Drag me`).

## Corpus

Bước viết lại chạy trên target app iOS mà `irisrun-ios-build` chọn của cả 65 app (`objc-corpus-rewrite.sh`, 11 phút với bản debug của tool). Không file nào lỗi cú pháp với parser của swift-syntax 604.

| Cấu trúc | Số lần | Số app |
| --- | --- | --- |
| `@objc` (bỏ) | 1.623 | 34 |
| `@IBOutlet` / `@IBAction` (bỏ) | 902 / 299 | 13 / 9 |
| `@objcMembers` / `@IBInspectable` / `@IBDesignable` / `@nonobjc` | 17 / 14 / 3 / 5 | 2 / 1 / 1 / 2 |
| `#selector`, giải theo khai báo / theo cú pháp | 1.025 / 34 | 31 / 16 |
| `Selector("…")`, `NSSelectorFromString` | 6 | 4 |
| `#keyPath` | 125 | 5 |
| Protocol `@objc` / requirement optional / lời gọi requirement optional | 23 / 10 / 9 | 4 / 3 / 3 |
| `removeObserver` của NotificationCenter | 76 | 13 |
| Property báo thay đổi cho KVO | 11 | 2 |
| Đăng ký: method / property (getter, setter) | 1.616 / 1.129 | 32 / 13 |
| Còn lại: method của class generic, class cục bộ, class private lồng nhau | 13 | 3 (authenticator 6, wikipedia 5, oscar-weather 2) |
| Còn lại: method `async`, `throws` hay hơn 3 tham số | 20 | 2 (wikipedia 19) |
| Còn lại: KVO kiểu cũ, `addObserver(_:forKeyPath:…)` / `observeValue(forKeyPath:…)` | 8 / 5 | 4 / 4 |
| Còn lại: `@NSManaged` (Core Data) | 76 | 4 |

38/65 app có `@objc` hay `#selector` trong target được build (P0-07 đếm 44 và 42 app trên mọi file của repo, cả target macOS, widget và package).

### Typecheck trước và sau

`objc-corpus-typecheck.py` typecheck module của từng app hai lần, với đúng các cờ mà SwiftPM dùng để build app mẫu với OpenKit (lấy từ `swift build -v`): "trước" là file của target như dev viết (chỉ đổi `@UIApplicationMain` thành `@main` để compiler khỏi crash, và thêm factory của 1a như pipeline), "sau" là package `irisrun-ios-build` viết ra. Module mà OpenKit chưa có (Combine, framework Apple khác, gói bên thứ ba) được thay bằng module rỗng để typecheck đi qua `import`; driver chạy với `-continue-building-after-errors`, không thì nó dừng ở batch lỗi đầu tiên và bỏ sót phần lớn lỗi. 62/65 app xong cả hai lần trong 30 phút mỗi lần. dime và yattee quá giờ ở cả hai lần. oscar-weather quá giờ ở lần sau: chạy lại với giới hạn 2 giờ, lần trước xong sau 20 phút, lần sau 20 phút chưa xong thì dừng; bước viết lại của app này chỉ đổi 8 `@objc`, 9 `#selector` và 5 `removeObserver`.

| Lỗi | Trước | Sau |
| --- | --- | --- |
| `Objective-C interoperability is disabled` | 1.534 lỗi, 30 app | 0 |
| `'#selector' can only be used with the Objective-C runtime` | 1.825 lỗi, 32 app | 0 |
| `@IBOutlet` với kiểu là class Swift | 131 lỗi, 9 app | 0 |
| `#keyPath` | 21 lỗi, 4 app | 0 |
| `'optional' can only be applied to members of an @objc protocol` | 10 lỗi, 3 app | 0 |
| Mọi lỗi khớp mẫu Objective-C của `objc-corpus-summary.py` (cả API như `observe`, `setValue`, `perform`) | 3.601 lỗi, 34 app | 20 lỗi, 8 app, không lỗi nào do `@objc` hay `#selector` |
| Lỗi trong code bước viết lại sinh ra | | Chỉ lỗi kéo theo kiểu chưa có, ở 13 app (wikipedia 473, openfind 191, racerunner 136, netnewswire 106…): bảng của outlet `UILabel`, `UIButton`, `NSLayoutConstraint`, của file AppKit, của file không import Foundation |

20 lỗi còn khớp mẫu sau khi viết lại: KVO kiểu cũ (openfind gọi `removeObserver(_:forKeyPath:)` trên `UserDefaults`, nytimes gọi `super.observeValue(forKeyPath:…)`); runtime Objective-C thật (swiftfin, `NotchReader.swift`, 2 lỗi: `@convention(c) (AnyObject, Selector) -> CGRect` để gọi IMP của một method UIKit riêng); lỗi kéo theo kiểu hay import thiếu (wikipedia 6, vì nhiều file không import Foundation mà sống nhờ bridging header; swift-radio-pro, `UISlider.value`); lỗi có sẵn của app, giống hệt ở hai lần (off-day 5); tên trùng mẫu (ice-cubes `AppAccountsSelectorView`, swiftfin 2); một lỗi isolation (zlgithubclient, xem Giới hạn).

Tổng số lỗi giảm ít (bark 1.853 → 1.817, wikipedia 22.703 → 22.140) vì phần còn lại là API UIKit chưa có (đợt 2–5 của P1-16), framework thiếu (P1-17, P1-18) và gói bên thứ ba. Số "trước" còn tính cả preview, bước viết lại thì không.

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| SwiftPM không resolve được package của app | `runtimes/ios` đòi swift-syntax 604, OpenObservation đòi 603 | Khoảng `603.0.0 ..< 605.0.0` |
| `call to main actor-isolated static method … in a synchronous nonisolated context` | Hàm đăng ký nằm trong extension của lớp con `UIViewController` | `_irisRegister { … }` |
| `instance method 'value(forKey:)' is declared in extension of 'NSObject' and cannot be overridden` | Thêm bản riêng cho `UserDefaults` trong extension | Một hàm trên `NSObject`, xử lý `UserDefaults` bên trong |
| Chạm hai lần trên tay nắm không có hiệu lực trong app mẫu, dù unit test của 1b qua | `Timer(timeInterval:repeats:block:)` của Foundation trên Linux chạy ngay; unit test không chạy RunLoop nên không thấy | Timer tạo với `fire: Date(timeIntervalSinceNow:)` |
| Typecheck corpus dừng ở `@testable import` | Module rỗng thay module thiếu không bật testing | Module rỗng build với `-enable-testing` |

## Số đo

| Mục | Số đo |
| --- | --- |
| Test của `runtimes/ios` | 44: OpenUIKit 25, IrisBuild 12 (3 mới), ObjCRewriteTests 6 (mới), IrisProtocol 1 |
| `check-sample.sh examples/ios-uikit` | 34 điểm ở chế độ stdout và frame |
| `check-sample.sh` (SwiftUI) | 54 điểm |
| `irisrun start examples/ios-uikit` | Build 55 s, frame đầu 0,8 s sau khi chạy. Trong `/#/live` (driver CDP): hai đèn đã xanh, kéo tay nắm, chạm hai lần đưa nó về, giữ thẻ làm thẻ vàng, kéo logo lên 60 điểm |
| Viết lại 65 app bằng bản debug của tool | 11 phút, khoảng 10 s mỗi app (chủ yếu là parse bằng swift-syntax bản debug) |
| Code | `ObjCSources.swift` 806 dòng, `KeyValueCoding.swift` 149 dòng, `DispatchTests.swift` 105 dòng; fixture 176 dòng |

## Giới hạn và việc tiếp

- **Class generic:** method `@objc` của class generic không được đăng ký (đăng ký cần kiểu cụ thể); action gửi tới chúng làm app dừng với "unrecognized selector". Trong corpus: 13 method ở 3 app, như nút trong `ButtonHeaderView<Action>` của authenticator. Hướng nâng cấp: một protocol tra method theo instance, mà class generic adopt trong extension.
- **Method `async`/`throws`, hơn 3 tham số, static, init:** không đăng ký; selector vẫn có tên.
- **KVO kiểu cũ** (`addObserver(_:forKeyPath:options:context:)` cùng override `observeValue(forKeyPath:of:change:context:)`, 4 app) chưa có: `observeValue` phải override được, mà method thêm bằng extension của `NSObject` thì không. Cần một lớp gốc riêng hoặc viết lại override thành method thường. KVO của property tính toán (`keyPathsForValuesAffecting…`) và `.prior` cũng chưa.
- **Isolation của OpenUIKit chặt hơn SDK iOS:** OpenUIKit dịch ở Swift 6 mode, nên app Swift 5 gọi method main actor từ chỗ không cô lập (như `deinit`) bị lỗi, trong khi với UIKit thật (import kiểu `@preconcurrency`) chỉ là cảnh báo. Corpus gặp 1 lần (zlgithubclient); việc của P1-16.
- **Tên selector của method UIKit** theo cú pháp (`dismissWithAnimated:completion:` chứ không phải `dismissViewControllerAnimated:completion:`): OpenUIKit phải đăng ký method của nó bằng tên `objcSelector` sinh ra.
- **Chưa có:** `performSelector(inBackground:with:)`, `Thread(target:selector:object:)`, và kiểu UIKit nhận selector chưa làm (`UIBarButtonItem`, `UIKeyCommand`, `CADisplayLink`). Package local của app chưa được viết lại (pipeline tham chiếu chúng theo đường dẫn).
- **Cho P1-16 đợt 6 (storyboard/XIB):** outlet đặt bằng `setValue(_:forKey:)`, action nối bằng `addTarget(_:action:for:)` với tên selector trong XIB, `@IBInspectable` và runtime attribute qua KVC với đúng kiểu property. Cần thêm: factory tạo view controller và view theo `customClass` bằng `init(coder:)` (như `_IrisInstantiable`), bảng tên cho class có `@objc(Tên)` (P1-35 bỏ attribute mà không giữ tên), `Main.storyboard` trong Info.plist và segue.
- **Cho P1-16 đợt 2:** xem mục "Sau P1-35" của [bàn giao](../plans/p1-16-handoff.md): control mới nhận `Selector` và gửi qua `_IrisMethods.send`; delegate của UIKit có method optional thì hỏi `responds(to:)`; property KVO của UIKit gọi `_irisDidChangeValue`.

## Chạy lại

```sh
cd runtimes/ios
swift test -Xlinker -L$PWD/../../target/release                     # 44 test
swift run irisrun-ios-build <app> --out <dir> --openswiftui - --runtime - --render-lib -   # summary có "objc"
cd ../..
runtimes/ios/Scripts/check-sample.sh examples/ios-uikit             # 34 điểm; IRISRUN_FRAMES=<dir> để có PNG
runtimes/ios/Scripts/check-sample.sh                                # SwiftUI, 54 điểm

# Corpus (mọi lệnh trong container Swift; app ở ~/.cache/irisrun/ios-corpus/apps, xem tools/ios-corpus)
W=~/.cache/irisrun/p1-35/corpus
~/.cache/irisrun/devtools/objc-corpus-rewrite.sh <irisrun-ios-build> ~/.cache/irisrun/ios-corpus/apps $W/after
# driver-command.txt: lệnh swiftc mà `swift build -v` in cho module của một app mẫu
~/.cache/irisrun/devtools/objc-corpus-typecheck-all.sh $W/driver-command.txt ~/.cache/irisrun/ios-corpus/apps $W/after $W/typecheck
python3 ~/.cache/irisrun/devtools/objc-corpus-summary.py $W/typecheck
```

Ở máy dev, đặt `swiftenv` trước mỗi lệnh Swift (xem `docs/progress.md`).
