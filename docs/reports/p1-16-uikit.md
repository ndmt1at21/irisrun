# P1-16 · UIKit cơ bản (OpenUIKit)

15/10/2026 · Máy dev WSL2 Ubuntu 20.04, dùng chung với các session khác. Swift 6.4.1 chạy trong container `irisrun-swift-dev:6.4.1`. Mọi số đo là của bản debug. Kế hoạch: [plans/p1-16-uikit.md](../plans/p1-16-uikit.md). Báo cáo này viết dần theo đợt; hiện có đợt 1 (1a nền, 1b chạm), đợt 2 (2a hiển thị và control, 2b nhập chữ, cuộn, alert; tổng kết đợt 2 sau 2b) và đợt 7a (một host, một cảnh, `UIHostingController`; ở cuối báo cáo).

## Kết luận (đợt 1)

- **Đợt 1 đạt tiêu chí của plan:** app tạo view bằng code (frame) hiện đúng, chạm đổi màu được, và chạy trong Device UI. Trong `/#/live`, chạm nút ở đáy app mẫu đổi màu xanh dương → xanh lá → cam, kéo vòng tròn tím thì nó đi theo ngón tay. `check-sample.sh examples/ios-uikit` đạt 26 điểm ở cả chế độ stdout lẫn frame.
- **App UIKit viết như cho Xcode build và chạy không sửa dòng nào** (1a). App mẫu `examples/ios-uikit` có `@main class AppDelegate: UIResponder, UIApplicationDelegate`, `SceneDelegate` lấy từ scene manifest trong Info.plist, `ViewController` dựng màn hình bằng frame. Ở 1b app mẫu có thêm: một `UIControl` con với `addAction(UIAction { … }, for: .touchUpInside)` và `.touchUpOutside`, một view override `touchesBegan`/`touchesEnded`, một view kéo được bằng `touchesMoved`, và ảnh `Logo` từ `Assets.xcassets` của app qua `layer.contents = UIImage(named: "Logo")?.cgImage`. Tất cả là code iOS 17 hợp lệ, không dùng API riêng của Iris.
- **Chạm đi đúng đường của UIKit:** `TouchInput` (input của thiết bị và lệnh kịch bản) tạo `UITouch` và một `UIEvent` dùng lại, `UIApplication.sendEvent` → `UIWindow.sendEvent`. Hit-test lúc chạm xuống, chạm ở lại view đó; gesture recognizer thấy chạm trước view; `touchesBegan…` mặc định chuyển lên `next`; có `isMultipleTouchEnabled`, `isExclusiveTouch`, `isUserInteractionEnabled`, `tapCount`.
- **Target/action chạy được mà không cần runtime Objective-C:** module mới `IrisObjC` có `Selector` (một tên), bảng method theo class tra theo lớp cha, `responds(to:)`/`perform`, lỗi "unrecognized selector" như iOS, và API Foundation nhận selector (`Timer`, `NotificationCenter`, `perform(_:with:afterDelay:)`). Mọi file của app thấy module này mà không cần import. Phần P1-35 phải sinh (selector theo tên, bảng method mỗi file, móc đăng ký mỗi module) đã viết thành hợp đồng trong plan, và đã chạy thử trên một app ngoài repo đăng ký đúng như vậy.
- **`UIControl` và tap/pan/long press recognizer có hành vi của UIKit** đến mức app quan sát được: thứ tự sự kiện, vùng đệm 70 điểm quanh control, phân xử giữa recognizer (yêu cầu thất bại, delegate, ngăn nhau, giữ chạm của view), control giữ tap của nó trước recognizer của view cha. Long press dùng timer của RunLoop, chạy được trong `hold` của kịch bản.
- **`UIImage` đọc asset catalog bằng cùng một bộ đọc với `Image` của SwiftUI** (đã chuyển sang `IrisHost` bằng patch `0030`); `UIFont` có metric thật của render core. App SwiftUI mẫu vẫn đạt 54 điểm ở cả hai chế độ, 81 frame PNG giống từng pixel với trước.

## Đã làm

### 1a: nền

| Phần | Ở đâu |
| --- | --- |
| Host dùng chung: `irisScene`, `irisSceneVersion`, `Scene.window` nạp font; `HostOptions` (IRISRUN_DEVICE, IRISRUN_SCALE, IRISRUN_FRAMES, chiếm stdout); `DeviceHost` (envelope có độ dài, DeviceInfo, AppStatus, tối đa 60 frame/giây, JPEG ở luồng khác, bỏ frame cũ); `DeviceInputHandler` + `DeviceTouch`; `runScriptCommand` (`tap`, `hold`, `swipe`, `drag`, `fling`, `type`, `compose`, `delete`, `key`); `writeFrame` ghi PNG | `runtimes/ios/Sources/IrisHost` |
| OpenSwiftUI dùng host chung: `DeviceInput` nhận `DeviceTouch`, `IrisDevice.swift` chỉ còn phần nối view graph với `DeviceHost`, `StdoutApp` lấy `HostOptions`, lệnh kịch bản và `writeFrame` của IrisHost | patch `openswiftui/0029` |
| `CALayer` (bounds, position, anchorPoint, frame, transform affine, sublayer, màu nền, bo góc, viền, bóng, opacity, hidden, masksToBounds, layout, `convert`), đồng bộ sang layer của render core | `Sources/OpenUIKit/CALayer.swift` |
| `UIView`, `UIWindow`, `UIViewController`, `UIResponder` (`next`), `UIScreen`, `UIColor`, `CGColor` | `Sources/OpenUIKit` |
| Vòng đời: `UIApplicationMain`, `UIApplicationDelegate.main()`, scene manifest hoặc `application(_:configurationForConnecting:options:)`, kiểu cũ không có scene (`window` của app delegate), notification của `UIApplication` | `UIApplication.swift`, `UIScene.swift` |
| Hai chế độ chạy: thiết bị qua `DeviceHost`, hoặc kịch bản stdin in cây view sau mỗi lệnh (thêm PNG khi có IRISRUN_FRAMES) | `Sources/OpenUIKit/Host.swift` |
| `import QuartzCore` (module `IrisQuartzCore` re-export OpenUIKit) và `import CoreGraphics` (alias sang OpenCoreGraphics) | `Sources/IrisQuartzCore`, `PackageWriter` |
| Pipeline: alias UIKit, CoreGraphics, QuartzCore; product OpenUIKit; ghi Info.plist cạnh file chạy; đổi `@UIApplicationMain` thành `@main`; sinh factory cho class mà UIKit tạo theo tên | `Sources/IrisBuild` (`PackageWriter`, `AppTarget`, `UIKitSources.swift`), `compile-app.sh` (`--runtime`) |
| `check-sample.sh [<thư mục ví dụ>]`, mặc định `examples/ios-swiftui` | `runtimes/ios/Scripts/check-sample.sh` |
| App mẫu UIKit (cũng là app mẫu của P1-33): project Xcode viết tay, Info.plist có scene manifest | `examples/ios-uikit` |
| CI: `swift test` của `runtimes/ios` (gồm OpenUIKit) và `check-sample.sh examples/ios-uikit` | `.github/workflows/ios-sample.yml` |

### 1b: chạm

| Phần | Ở đâu |
| --- | --- |
| `UITouch` (phase, `location(in:)`, `previousLocation(in:)`, `view`, `window`, `tapCount`, `timestamp`, `gestureRecognizers`, `type`), `UIEvent` (`allTouches`, `touches(for:)` theo window, view, recognizer, `type`, `timestamp`) | `Sources/OpenUIKit/UITouch.swift` |
| `TouchInput` biến input thành `UITouch`: ngón không đổi có phase `.stationary`, `tapCount` tăng khi chạm lại gần chỗ cũ trong 0,35 s | `Host.swift` |
| `UIApplication.sendEvent`, `UIWindow.sendEvent`, `UIApplication.sendAction(_:to:from:for:)` (target nil đi theo chuỗi responder) | `UIApplication.swift`, `UIWindow.swift` |
| `UIResponder`: `touchesBegan/Moved/Ended/Cancelled` chuyển lên `next`, first responder (`becomeFirstResponder`, `resignFirstResponder`, `isFirstResponder`), `target(forAction:withSender:)`, `canPerformAction(_:withSender:)` | `UIResponder.swift` |
| `UIControl`: `isEnabled`/`isSelected`/`isHighlighted`/`state`, mọi `UIControl.Event`, `begin/continue/end/cancelTracking`, vùng đệm 70 điểm, `addTarget`, `removeTarget`, `allTargets`, `allControlEvents`, `actions(forTarget:forControlEvent:)`, `addAction`, `removeAction`, `sendActions(for:)`, `sendAction(_:to:for:)`, `sendAction(_:)`, `init(frame:primaryAction:)`; `UIAction`, `UIMenuElement` | `UIControl.swift`, `UIAction.swift` |
| `UIGestureRecognizer` (máy trạng thái, target/action, `isEnabled`, `view`, `location(in:)`, `location(ofTouch:in:)`, `numberOfTouches`, `cancelsTouchesInView`, `delaysTouchesBegan`/`Ended`, `require(toFail:)`, API cho lớp con), `UIGestureRecognizerDelegate` (shouldBegin, shouldReceive touch/event, simultaneous, requireFailureOf, requiredToFailBy); `GestureEnvironment` giao chạm cho recognizer rồi view; `addGestureRecognizer`, `removeGestureRecognizer`, `gestureRecognizers`, `gestureRecognizerShouldBegin` của `UIView` | `UIGestureRecognizer.swift`, `UIView.swift` |
| `UITapGestureRecognizer` (số lần chạm, số ngón, giới hạn di chuyển), `UIPanGestureRecognizer` (`translation`, `setTranslation`, `velocity`, số ngón min/max, ngưỡng 10 điểm), `UILongPressGestureRecognizer` (0,5 s, 10 điểm, số lần chạm trước) | `GestureRecognizers.swift` |
| `Selector`, `NSStringFromSelector`, `NSSelectorFromString`, bảng method `_IrisMethods`, `responds(to:)`, `perform(_:)`/`(_:with:)`/`(_:with:with:)`; `Timer` và `NotificationCenter` theo selector, `perform(_:with:afterDelay:)`, `cancelPreviousPerformRequests`, `performSelector(onMainThread:…)` | `Sources/IrisObjC` (target mới) |
| Pipeline: mọi file của app import ngầm `IrisObjC` (`-Xfrontend -import-module`); `import UIKit.UIGestureRecognizerSubclass` thành `import UIKit` | `PackageWriter.swift`, `UIKitSources.swift` |
| `UIImage` (`named:`, `named:in:compatibleWith:`, `contentsOfFile:`, `data:`, `data:scale:`, `systemName:`, `cgImage:`, `size`, `scale`, `renderingMode`, `withRenderingMode`), `UITraitCollection` rỗng; `CALayer.contents`, `contentsGravity`, `contentsScale` vẽ qua render core | `UIImage.swift`, `CALayer.swift` |
| Bộ đọc asset catalog chuyển từ OpenSwiftUICore sang IrisHost, dùng chung cho hai framework | `Sources/IrisHost/AssetCatalog.swift`, patch `openswiftui/0030` |
| `CGImage` là `open` và có `init()`, để `UIImage.cgImage` mang ảnh (`IrisCGImage`) | patch `opencoregraphics/0001` |
| `UIFont` (`systemFont`, `boldSystemFont`, `italicSystemFont`, `monospacedDigitSystemFont`, `monospacedSystemFont`, `preferredFont(forTextStyle:)` theo cỡ Dynamic Type mặc định, `init?(name:size:)`, `withSize`, `pointSize`, `lineHeight`, `ascender`, `descender`, `capHeight`, `xHeight`, `leading`, `fontName`, `familyName`), `UIFont.Weight`, `UIFont.TextStyle`, `UIFontDescriptor` cơ bản | `UIFont.swift` |
| App mẫu: nút đổi màu, touch pad, vòng tròn kéo được, logo từ asset catalog; khối `#if canImport(ObjectiveC)` chờ P1-35 (chạm hai lần xoá đếm); `session.txt` 26 điểm | `examples/ios-uikit` |
| Test: 17 test mới cho chạm, responder, control, selector, recognizer, ảnh, font | `Tests/OpenUIKitTests/EventTests.swift`, `ImageAndFontTests.swift` |

## Quyết định

### 1a

- **OpenUIKit phụ thuộc OpenCoreGraphics, lấy từ checkout của `fetch-openswiftui.sh`.** Nếu tự định nghĩa `CGAffineTransform`, file nào import cả SwiftUI và UIKit cũng lỗi "ambiguous" (43/50 app SwiftUI trong corpus dùng UIKit). Vì vậy các target OpenKit trong `runtimes/ios/Package.swift` (IrisHost, IrisObjC, OpenUIKit, IrisQuartzCore, test) chỉ có trên Linux và khi có checkout `$IRISRUN_IOS_WORK/checkouts/OpenCoreGraphics`. `swift test` ở job `swift` của `ci.yml` (Linux không có checkout, và macOS) chạy như cũ; test của OpenUIKit chạy trong `ios-sample.yml`, cần `-Xlinker -L<repo>/target/release`.
- **OpenUIKit tự có `CALayer` và `CGColor`.** OpenCoreGraphics không có `CGColor`. `CALayer` của nó (OpenQuartzCore) là stub rỗng mà OpenSwiftUI không re-export, nên OpenUIKit không re-export OpenQuartzCore để khỏi trùng tên.
- **`import QuartzCore` đi qua một module riêng.** Compiler không cho hai alias cùng trỏ vào một module (`the name "OpenUIKit" is already used for a module alias`), nên `QuartzCore=IrisQuartzCore`, và module này chỉ re-export OpenUIKit. `CoreGraphics=OpenCoreGraphics`.
- **`@UIApplicationMain` làm swift-frontend 6.4.1 crash trên Linux** (signal 11 trong `emitArtificialTopLevel`). Pipeline đổi nó thành `@main` ngay trên dòng đó; `UIApplicationDelegate` có `static func main()` như UIKit.
- **Tạo class theo tên cần factory sinh lúc build.** `NSClassFromString("Module.Class")` chạy được trên Linux, nhưng Swift chỉ gọi được `init()` của một metatype khi init đó là `required`. Vì vậy `irisrun-ios-build` thêm vào cuối file (dòng của app giữ nguyên) `extension X: UIKit._IrisInstantiable { static func _irisMake() -> AnyObject { X() } }` cho class ở mức đầu file adopt `UIApplicationDelegate`, `UISceneDelegate`, `UIWindowSceneDelegate`, hoặc kế thừa `UIApplication`.
- **Info.plist do pipeline ghi** vào `Resources/Info.plist`, rồi tới thư mục chạy, cạnh file thực thi, nơi `Bundle.main` đọc.
- **Layer của UIKit đồng bộ sang render core như CATransaction commit:** mỗi thay đổi hẹn một commit ở cuối vòng RunLoop, commit layout các cửa sổ đang hiện rồi chỉ đẩy phần đã đổi; `irisSceneVersion` chỉ tăng khi có gì được gửi. Transform quanh anchor point được đổi sang quanh tâm như render core cần.
- **Màn hình UIKit nền đen** ở chỗ không cửa sổ nào vẽ, như iPhone; scene của SwiftUI giữ nền trắng.
- **Chế độ kịch bản in cây view:** lớp, frame, nền, bo góc, viền, bóng, alpha, transform, `clips`, `key`, ảnh (`image:WxH`, từ 1b) và nhãn accessibility trong ngoặc kép, để `# expect` và `tap <text>` dùng được (UIKit chưa có chữ trước `UILabel` ở đợt 2).
- **IrisHost, IrisObjC và OpenUIKit dịch ở Swift 6 language mode**, kiểu public có `@MainActor` như SDK iOS 18 (`UIResponder` và các lớp con, `UITouch`, `UIEvent`, `UIGestureRecognizer`, `UIMenuElement`/`UIAction`, delegate protocol); `CALayer`, `UIColor`, `CGColor`, `UIImage`, `UIFont` không gắn actor.

### 1b

- **Selector là một tên; method nằm trong bảng theo class, đăng ký lúc chạy.** Linux không có `+load`, và protocol conformance kiểu factory của 1a không dùng được cho bảng method: lớp con không khai lại được conformance mà lớp cha đã có (`redundant conformance`, đã thử), và static member trong extension không override được. Vì vậy P1-35 sinh mỗi file một hàm đăng ký (với tới cả class `private`, cả method thêm vào class của module khác bằng extension, như `extension UIViewController { @objc func dismissKeyboard() }` rất phổ biến), mỗi module một biến `let` lười gọi các hàm đó, và mọi selector của module đi qua `_irisSelector(_:)` chạm vào biến ấy trước. Factory của 1a cũng chạm vào nó, cho action đọc từ storyboard. Tất cả là code mà bước viết lại chỉ nhìn cú pháp sinh được; chi tiết ở mục "Hợp đồng cho P1-35" của plan.
- **`Method` nhận tham chiếu method chưa áp dụng**, `.init(ViewController.tapped(_:))`: kiểu suy ra từ khai báo, nên P1-35 không cần biết kiểu tham số. Đã thử: dịch được ở cả Swift 5 lẫn Swift 6 mode, kể cả với method `@MainActor` và class `private`. Closure không gắn actor, nên selector chạy trên luồng gọi, như Objective-C.
- **`IrisObjC` là module riêng, chỉ dùng Foundation, OpenUIKit re-export, và pipeline import ngầm nó vào mọi file** (`-Xfrontend -import-module -Xfrontend IrisObjC`, đã thử với SwiftPM): file chỉ import Foundation cũng thấy `Selector` và API Foundation nhận selector, như trên Darwin. Foundation trên Linux không có kiểu `Selector` nào để trùng (đã thử).
- **API Foundation theo selector làm luôn ở 1b vì rẻ:** `Timer` (một lớp con giữ `userInfo`, vì `userInfo` của Foundation trên Linux luôn nil), `perform(_:with:afterDelay:)` và `cancelPreviousPerformRequests`, `performSelector(onMainThread:…)`, `NotificationCenter.addObserver(_:selector:name:object:)`. Extension không thay được `removeObserver(_:)` của Foundation (gọi sẽ "ambiguous", đã thử), nên có `_irisRemoveObserver` để P1-35 đổi lời gọi sang.
- **Kết quả object của `perform` được giữ tới hết vòng RunLoop chính.** Trả `Unmanaged` không giữ thì object chết ngay (test đã crash vì vậy); Darwin giữ nó trong autorelease pool.
- **Gesture recognizer theo thứ tự của UIKit:** mỗi event, recognizer nhận chạm trước; rồi trạng thái được phân xử (chờ recognizer phải thất bại trước, ngăn nhau khi chung chạm trừ khi delegate cho phép cùng lúc, `gestureRecognizerShouldBegin` của delegate và của các view từ view bị chạm lên view của recognizer) và action được gửi; rồi view nhận phase chưa bị giữ (`delaysTouchesBegan`/`Ended`); recognizer nhận ra với `cancelsTouchesInView` thì view nhận `touchesCancelled`. Đổi trạng thái ngoài lúc giao chạm (timer) được phân xử ở lượt kế của main queue. Recognizer xong thì `reset()` và bỏ các chạm còn lại.
- **Control giữ tap của nó:** `UIControl.gestureRecognizerShouldBegin` từ chối recognizer tap một ngón một lần của view khác khi control đang bật và có action cho touchDown, touchUpInside hay primaryActionTriggered (luật của iOS 6+).
- **Hằng số riêng của UIKit lấy theo hành vi quan sát được:** vùng đệm control 70 điểm, tap lệch tối đa 45 điểm và cách nhau tối đa 0,35 s (dùng cả cho `tapCount`), ngưỡng bắt đầu pan 10 điểm, vận tốc pan tính trên 0,1 s cuối, bằng 0 khi ngón đứng yên lâu hơn.
- **`UIApplication.sendAction` với target nil đi từ first responder, hoặc từ sender khi chưa có first responder**, để nút có action target nil tới được view controller của nó.
- **`UIImage.cgImage` cần sửa OpenCoreGraphics:** `CGImage` của nó không có init public và không cho kế thừa. Patch nhỏ `opencoregraphics/0001` (`open`, `init()`) dùng cơ chế patch sẵn có của `fetch-openswiftui.sh`; `IrisCGImage` mang byte ảnh, `CALayer.contents` nhận nó và gọi `setImage` của render core.
- **Bộ đọc asset catalog chuyển sang IrisHost bằng patch `0030`** (+9 −180 dòng trong OpenSwiftUI), cùng lớp `IrisEncodedImage`; OpenSwiftUI chỉ còn đổi "Render As" của image set sang rendering mode của nó.
- **`UIFont` đo bằng metric của render core** (`irisScene.fontMetrics`, Inter), `lineHeight = ascender − descender + leading`; cỡ của text style theo Dynamic Type mặc định của iOS (body 17, headline 17 semibold, largeTitle 34…). Tên font hệ thống như iOS (`.SFUI-Semibold`, họ `.AppleSystemUIFont`). `UIFont(name:size:)` không trả nil: app hay force-unwrap font của mình, nên Iris trả font hệ thống với độ đậm và kiểu nghiêng đọc từ tên.
- **`UIImage(systemName:)` là ô trống 20 điểm:** SF Symbols cần font của Apple; `Image(systemName:)` của OpenSwiftUI hiện ra ảnh rỗng kích thước 0.
- **App mẫu không dùng gesture recognizer**, vì chúng cần `#selector`, chỉ dịch được sau P1-35. Recognizer được kiểm bằng unit test đăng ký method đúng như P1-35 sẽ sinh, bằng app thử `~/.cache/irisrun/p1-16/gesture-app` (long press bằng timer thật trong `hold`, pan, `Timer` và `NotificationCenter` theo selector từ file chỉ import Foundation, 4 điểm), và bằng khối `#if canImport(ObjectiveC)` chờ sẵn trong app mẫu.

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| swift-frontend crash khi dịch `@UIApplicationMain` | Compiler sinh entry point bằng các hàm Objective-C mà Linux không có | Pipeline đổi thành `@main`, giữ dòng |
| Hai `-module-alias` cho cùng OpenUIKit bị từ chối | Compiler chỉ cho một alias trỏ vào một module | Module `IrisQuartzCore` re-export OpenUIKit |
| `stdout`/`stderr` của C lỗi "not concurrency-safe" ở Swift 6 | Biến toàn cục C | `printError` (FileHandle) và `fflush(nil)` |
| Script `check-sample.sh` hỏng giữa chừng | Sửa `compile-app.sh` trong lúc bash đang chạy nó | Chạy lại; đừng sửa script khi đang chạy |
| `git -C <checkout> format-patch -o Patches/openswiftui` ghi patch vào checkout | `-o` tương đối tính theo thư mục của `-C` | Dùng đường dẫn tuyệt đối cho `-o` |
| `perform(_:with:)` truyền `Optional<Any>` cho tham số `Any` | Ép một optional sang `Any` thì optional nằm nguyên bên trong | Mở optional trước khi ép |
| Test crash khi đọc kết quả của `perform` | `Unmanaged.passUnretained` của object không ai giữ | Giữ kết quả tới hết vòng RunLoop chính |
| Ngón đã chạm xuống được giao `began` lần nữa ở event sau | Input của kịch bản chỉ gửi ngón đổi; ngón còn lại giữ phase cũ | Mỗi event đặt ngón không đổi về `.stationary` |
| Kéo trong Device UI không trúng view | `drag` của driver CDP đổi toạ độ dọc bằng tỉ lệ ngang, mà Device UI kéo dãn khung hình theo chiều dọc | Sửa driver (`~/.cache/irisrun/devtools/cdp/ui.mjs`) dùng tỉ lệ riêng mỗi trục như `tap` |

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `check-sample.sh examples/ios-uikit` | 26 điểm; 41 s ở stdout, 42 s ở chế độ frame | Build đã có |
| Một bước kịch bản UIKit | Update 0,3–1,2 ms (`hold` 600 ms vì chờ 0,6 s); vẽ và PNG ở 3x 75–100 ms | 21 view (cả cửa sổ), một ảnh |
| `check-sample.sh` (SwiftUI) sau patch 0030 | 54 điểm ở chế độ stdout và frame; 81 PNG ở 3x giống từng pixel với trước | Lần đầu gồm build lại OpenSwiftUI (IrisHost và OpenCoreGraphics đổi): khoảng 5 phút; chế độ frame 52 s |
| App thử gesture (`gesture-app`) | 4 điểm | Long press, `Timer`/`NotificationCenter` theo selector, pan |
| `irisrun start examples/ios-uikit` | Build 58 s, frame đầu 0,9 s sau khi chạy | Chạm và kéo trong `/#/live` có hiệu lực ngay ở frame sau |
| Test | 35: OpenUIKit 25 (8 của 1a, 17 mới), IrisBuild 9, IrisProtocol 1 | `swift test` của `runtimes/ios` |
| Code | OpenUIKit 3812 dòng (1a: 1831), IrisObjC 336, IrisHost 618 (thêm `AssetCatalog.swift` 180), test OpenUIKit 810; patch `0030` +9 −180, `opencoregraphics/0001` +5 −1 | |

## Giới hạn và việc tiếp

- **Đợt 2 (control và chữ):** chưa có `UILabel`, `UIButton`, `UIImageView`, `UITextField`, `UITextView` và các control khác; chưa vẽ chữ trong UIKit (`tap <text>` tìm theo nhãn accessibility). Các lệnh chữ và phím của `TouchInput` còn bỏ trống. `UIKeyboardType`, `UITextContentType` vẫn nằm trong OpenSwiftUI (P1-15): khi OpenUIKit có chúng, phải chuyển hẳn sang OpenUIKit, không thì file import cả hai sẽ trùng tên. Chi tiết trong [bàn giao cho đợt 2](../plans/p1-16-handoff.md).
- **P1-35 (viết lại `@objc`/`#selector`):** phải sinh selector theo tên, bảng method mỗi file và móc đăng ký mỗi module theo hợp đồng trong plan; đổi `NotificationCenter.removeObserver` sang `_irisRemoveObserver`. Method delegate chỉ có ở lớp con của class adopt protocol thì chưa được gọi (protocol Swift lấy hiện thực mặc định trong extension). Còn thiếu `Timer(fireAt:…target:selector:…)`, `performSelector(inBackground:with:)`, `Thread(target:selector:object:)`.
- **Chạm:** first responder là một cho cả app (UIKit: một cho mỗi cửa sổ); không có lực chạm, bán kính, chạm dự đoán, `UIPress`, `motionBegan…` và `UIEvent.subtype`. Pan dời gốc khi có ngón mới trước khi bắt đầu; sau khi bắt đầu thì translation nhảy. Disabled control chuyển chạm lên chuỗi responder.
- **Ảnh:** chưa có ảnh vector, dark mode, ảnh resizable, ảnh động, tô màu ảnh template, `UIImage.SymbolConfiguration`; `contentsGravity` các cạnh chưa đối chiếu với iOS; `UIView.contentMode` chưa đổi `contentsGravity` (cần cho `UIImageView`). `UITraitCollection` là lớp rỗng.
- **Font:** chỉ Inter (và Noto Sans SC); font monospace và font riêng của app (UIAppFonts) chưa nạp; `UIFontDescriptor` chỉ có cỡ, tên và trait.
- **CALayer:** chưa có `CATransform3D`, `zPosition`, mask layer, `maskedCorners`, `draw(_:)`, animation, `CATransaction` public. Lớp layer riêng của app (`layerClass`) tạm nhận `CALayer` thường.
- **Cửa sổ đang hiện được giữ lại** dù app không giữ nó; trên iOS cửa sổ như vậy biến mất.
- **Factory sinh bằng cách quét dòng:** chỉ class khai báo ở mức đầu file, không generic, hoặc conformance khai báo trong `extension`; lớp con của một lớp đã có factory sẽ lỗi "redundant conformance" nếu cũng adopt delegate protocol. Bước SwiftSyntax của P1-35 sẽ thay.
- **SwiftUI trên iOS re-export UIKit** (dùng `UIColor` chỉ với `import SwiftUI`); OpenSwiftUI chưa làm vậy, việc này để cho đợt 7, cùng việc chia gốc của scene giữa hai framework.
- Device UI kéo dãn khung hình theo chiều dọc (ảnh 780×1688 hiện trong ô 324×756), nên hình tròn hơi thành ellipse. Lỗi này thuộc `apps/web`, có ở cả app SwiftUI.

## Chạy lại

```sh
crates/render/fetch-fonts.sh
cargo build -p irisrun-render --release
runtimes/ios/Scripts/fetch-openswiftui.sh
(cd runtimes/ios && swift test -Xlinker -L$PWD/../../target/release)  # 35 test; cần checkout của fetch-openswiftui
runtimes/ios/Scripts/check-sample.sh examples/ios-uikit               # 26 điểm; IRISRUN_FRAMES=<dir> để có PNG
runtimes/ios/Scripts/check-sample.sh                                  # app SwiftUI, 54 điểm

cargo build -p irisrun
IRISRUN_SWIFT_RUNNER=swiftenv target/debug/irisrun start examples/ios-uikit
# mở http://127.0.0.1:7777/#/live
```

Ở máy dev, đặt `swiftenv` trước mỗi lệnh Swift (xem `docs/progress.md`), ví dụ `swiftenv env IRISRUN_FRAMES=<dir> runtimes/ios/Scripts/check-sample.sh examples/ios-uikit`; `irisrun start` cần `~/.cache/irisrun/devtools/bin` trong `PATH` để tìm `swiftenv`. Checkout đã có từ trước thì sau khi kéo về patch mới phải xoá `~/.cache/irisrun/p0-05/checkouts/OpenSwiftUI` và `OpenCoreGraphics` rồi chạy lại `fetch-openswiftui.sh` (script cảnh báo khi stamp khác).

## Đợt 2a: hiển thị và control (16/10)

### Kết luận

- **App UIKit hiện chữ và control như iOS 17:** `UILabel` (chữ thường và attributed, cắt dòng, co chữ, căn giữa theo chiều dọc), `UIImageView` (mọi content mode, ảnh template tô theo tint), `UIButton` (5 kiểu, nội dung theo state với edge insets, và `UIButton.Configuration` của iOS 15), `UISwitch`, `UISlider`, `UISegmentedControl`, `UIActivityIndicatorView`, `UIProgressView`. Chữ đo và vẽ cùng một đường qua render core, nên kích thước khớp với cái vẽ ra.
- **App mẫu chia trang bằng `UISegmentedControl` ở header:** "Touch" (nội dung cũ, giữ đủ 34 điểm), "Controls" (2a), "Form" (trống, cho 2b). Trang Controls dùng target/action với `#selector` và `UIAction` như app thật; `session.txt` có thêm 28 điểm (62 tất cả) cho từng tương tác: bấm từng loại nút, gạt switch bằng chạm và kéo, kéo slider (cả progress view theo), chọn segment, bật tắt spinner.
- **App Swift 5 gọi API main actor của UIKit từ chỗ không cô lập được như trên iOS:** mọi kiểu public có `@MainActor` giờ là `@preconcurrency @MainActor`, nên `deinit { button.removeFromSuperview() }` (zlgithubclient) dịch không lỗi, không cảnh báo; test target mới `Swift5AppTests` dịch đúng đoạn đó ở Swift 5.
- **Tìm ra một lỗi của Foundation trên Linux:** `NSMutableAttributedString.addAttribute(_:value:range:)` và `addAttributes(_:range:)` làm app dừng (`__HALT` trong `CFAttributedStringSetAttribute`) khi giá trị là object (font, màu), kể cả trên chuỗi chưa có thuộc tính nào; `setAttributes` và `init(string:attributes:)` không sao. 15 app trong corpus dùng `addAttribute`, 8 dùng `addAttributes`. `irisrun-ios-build` giờ đổi hai lời gọi đó thành `_irisAddAttribute(s)` của IrisObjC (gộp rồi `setAttributes` từng đoạn), như P1-35 làm với `removeObserver`.

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| Render core: màu nền cho từng run chữ (`.backgroundColor`), tô màu ảnh (`contentTint`, cho ảnh template); 2 test Rust mới | `crates/render/src`, `include/irisrun_render.h`, `swift/Sources/IrisRender` |
| `CALayer`: `setNeedsDisplay`/`display()` (view vẽ bằng `draw(_:)` trước khi layer được vẽ), một chỗ vẽ chữ hay hình của view UIKit (`irisDrawing`, layer render riêng dưới sublayer), tô màu contents, animation của render core (`irisAnimations`, animation ngầm cho `setOn(_:animated:)`), đồng hồ animation theo uptime; `contentsGravity` đổi trên/dưới như Core Animation | `CALayer.swift` |
| `UIView`: `contentMode` → `contentsGravity`, `tintColor` thừa kế, `tintAdjustmentMode` (mờ thành xám), `tintColorDidChange`, `intrinsicContentSize`, `noIntrinsicMetric`, `setNeedsDisplay`, `draw(_:)`, `endEditing(_:)`; tự đăng ký `endEditing:`, `removeFromSuperview`, `setNeedsLayout`, `layoutIfNeeded` cho selector | `UIView.swift` |
| `NSAttributedString.Key` của UIKit, `NSParagraphStyle`/`NSMutableParagraphStyle`, `NSTextAlignment`, `NSLineBreakMode`, `NSUnderlineStyle`, `NSWritingDirection`, `NSStringDrawingOptions`/`Context`; `size(withAttributes:)` và `boundingRect(with:options:attributes:context:)` của `NSString` và `String`, `size()`/`boundingRect` của `NSAttributedString`; `IrisText` (attributed → run UTF-8 của render core); `AttributeScopes.UIKitAttributes` cho `AttributedString` (`container.font = UIFont…`), `AttributeContainer([NSAttributedString.Key: Any])` | `NSAttributedString.swift` |
| `UILabel` (text, attributedText, font, textColor, alignment, numberOfLines, lineBreakMode, co chữ, highlighted, disabled, shadow, `textRect`, `drawText(in:)`, `intrinsicContentSize`, `sizeThatFits`, `preferredMaxLayoutWidth`) | `UILabel.swift` |
| `UIImageView` (image, highlightedImage, content mode, tint), `UIImage` vẽ được 3 symbol của nút hệ thống (`info.circle`, `plus.circle`, `xmark`) | `UIImageView.swift`, `UIImage.swift` |
| `UIButton` (kiểu, role, nội dung theo state, edge insets, `titleRect`/`imageRect`/`contentRect`, mờ khi chạm, `primaryActionTriggered`, `changesSelectionAsPrimaryAction`), `UIButton.Configuration` (8 style, title/subtitle/attributed, image, `imagePlacement`, padding, insets, `cornerStyle`, `buttonSize`, `showsActivityIndicator`, transformer), `configurationUpdateHandler`, `UIBackgroundConfiguration`, `UIConfigurationColorTransformer`, `UIConfigurationTextAttributesTransformer` | `UIButton.swift`, `UIButtonConfiguration.swift` |
| `UISwitch`, `UISlider`, `UISegmentedControl` (cả `init(frame:actions:)`, momentary, thuộc tính chữ theo state), `UIActivityIndicatorView`, `UIProgressView`; `UIControl.contentHorizontalAlignment`/`contentVerticalAlignment` | `UISwitch.swift`, `UISlider.swift`, `UISegmentedControl.swift`, `ProgressViews.swift`, `UIControl.swift` |
| `UIEdgeInsets`, `NSDirectionalEdgeInsets`, `NSDirectionalRectEdge`, `CGRect.inset(by:)` | `UIGeometry.swift` |
| `_irisAddAttribute(s)` và luật đổi tên trong bước viết lại | `Sources/IrisObjC/AttributedStrings.swift`, `Sources/IrisBuild/ObjCSources.swift` |
| Test: 12 test OpenUIKit mới (`TextTests.swift`, `ControlTests.swift`), 1 test IrisBuild, target `Swift5AppTests` | `runtimes/ios/Tests` |
| App mẫu: header có `UISegmentedControl`, 3 trang, trang Controls; `session.txt` 62 điểm | `examples/ios-uikit` |

### Quyết định

- **Chữ của view vẽ vào một layer render riêng của layer view** (`irisDrawing`), không phải `CALayer` con: app không thấy sublayer lạ, còn chữ vẫn có khung riêng (căn giữa theo chiều dọc, inset của `drawText(in:)`). `UILabel` vẽ trong `draw(_:)` → `drawText(in: bounds)` như UIKit, nên lớp con override `drawText(in:)` để thêm lề chạy được; `contentMode` mặc định `.redraw` vẽ lại khi đổi cỡ.
- **`contentsGravity` theo Core Animation:** trục y của layer đi lên, nên gravity `top` hiện ở đáy màn hình, và `UIView.contentMode.top` đặt gravity `bottom` (UIKit làm vậy). 1b đặt theo tên; đã sửa ở cả hai chiều.
- **Phần của control là `CALayer` (knob, track, thumb, plate, vạch chia, nan spinner), còn chữ và ảnh của chúng là `UILabel`/`UIImageView`** (để `tap <chữ>` và mô tả màn hình thấy chúng, như UIKit có subview riêng).
- **Animation của control chạy trên render core, chỉ ở chế độ thiết bị:** `LayerCommit` đặt đồng hồ của scene theo uptime và vẽ frame mới khi còn animation; chế độ kịch bản không animation nên PNG và cây view là trạng thái cuối. Spinner: mỗi nan một animation opacity lặp mãi, lệch 1/8 s; giá trị model là khoảnh khắc nan trên cùng sáng nhất, nên PNG tĩnh vẫn giống spinner.
- **Kích thước và màu theo iOS 17, lấy số của OpenSwiftUI (patch 0019, 0024) khi có:** switch 51 × 31, knob 27 (34 khi giữ); slider thumb 28, track 4; progress 4 (bar 2,5); segmented cao 32, bo 9, plate trắng bo 7; nút hệ thống chữ 15 điểm, 6 điểm trên dưới khi không có inset, mờ 0,2 khi chạm; configuration medium chữ 17 với inset 7/12 (cao 35 điểm với Inter; iOS 34,33), small 15, mini 12, large 17 với 14/20.
- **Màu theo state của configuration được tính lúc hiện** (disabled: chữ `tertiaryLabel`, nền `tertiarySystemFill`; highlighted: mờ 0,75, plain 0,5), nên `updated(for:)` trả lại chính nó.
- **`@preconcurrency @MainActor` cho mọi kiểu public có actor** thay vì bỏ actor: OpenUIKit vẫn kiểm tra ở Swift 6, app Swift 5 chỉ nhận như SDK iOS (đã thử: không còn lỗi, không cảnh báo).
- **`addAttribute(s)` đổi tên lúc build** vì extension không che được method của Foundation ("ambiguous", đã thử như P1-35), và đây là lỗi của Foundation trên Linux chứ không phải của OpenUIKit. OpenUIKit tự dùng `_irisAddAttribute(s)`.

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Test dừng ở `CFAttributedStringSetAttribute` (`__HALT`) | `addAttribute(s)` của Foundation trên Linux với giá trị là object | `_irisAddAttribute(s)` (gộp, rồi `setAttributes` từng đoạn) và luật đổi tên của `irisrun-ios-build` |
| `UIButton(configuration:)` không hiện title | Gán property trong initializer (cả convenience) không gọi `didSet` | Gọi `applyConfiguration()` trong init |
| `CGSize(width:height: .greatestFiniteMagnitude)` "ambiguous" trong test | Kiểu của literal không rõ khi import cả IrisRender | Ghi `CGFloat.greatestFiniteMagnitude` |

### Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `check-sample.sh examples/ios-uikit` | 62 điểm (34 cũ, 28 mới) ở chế độ stdout và frame | Trong PNG, trang Controls như iOS 17: chữ attributed và cắt "…", nút các kiểu, switch, slider, segmented, spinner tĩnh |
| `check-sample.sh` (SwiftUI) | 54 điểm | OpenSwiftUI build lại vì IrisRender đổi |
| Một bước kịch bản trên trang Controls | Update 1–1,4 ms; vẽ và PNG ở 3x 99–110 ms | 74 view |
| `irisrun start examples/ios-uikit` | Build 41 s, frame đầu 0,7 s | Trong `/#/live`: chọn trang, gạt switch, kéo slider, chọn segment, bấm nút, spinner quay (frame liên tục, khoảng 12 frame/giây ở máy dev) |
| Test | 58: OpenUIKit 37 (12 mới), IrisBuild 13 (1 mới), ObjCRewriteTests 6, Swift5AppTests 1 (mới), IrisProtocol 1; render core Rust 18 (2 mới) | |
| Code | OpenUIKit 6747 dòng (+2547 ở 10 file mới), test mới 374 dòng; render core +74 dòng | |

### Giới hạn và việc tiếp

- **Chữ:** cắt đầu, cắt giữa, `byClipping` và `byWordWrapping` có giới hạn dòng đều cắt cuối bằng "…" (render core chỉ cắt cuối); một paragraph style cho cả đoạn; `paragraphSpacing`, indent, `justified`, stroke, shadow của chữ attributed, attachment chưa hiện; chiều cao dòng (`lineHeightMultiple`, min/max) thành khoảng cách giữa các dòng. Chữ disabled là `systemGray` (chưa đối chiếu cách UIKit làm mờ).
- **Control:** chưa có menu, pointer, kéo plate của segmented control, highlight segment khi giữ, ảnh track của slider, `observedProgress`; ảnh của nút custom không tối đi khi chạm; selected của configuration trông như filled.
- **Symbol:** chỉ 3 symbol của nút hệ thống được vẽ; `UIImage(systemName:)` khác vẫn là ô trống 20 điểm.
- **Animation:** chỉ animation nội bộ của control (`irisAnimations`); `UIView.animate`, `CAAnimation` là đợt 4.
- **Tint:** `tintColorDidChange` được gọi khi view vào cây mới, không chỉ khi tint thật sự đổi.

## Đợt 2b: nhập chữ, cuộn, alert (16/10)

### Kết luận

- **App UIKit nhận chữ từ bộ gõ của host như UIKit:** chữ đang soạn (marked text) nằm trong `text` của ô, có gạch chân, `markedTextRange` khác nil và target của `editingChanged` thấy nó; commit thay chữ đang soạn; mọi khoảng tính theo UTF-16 và không cắt giữa ký tự. Input của host đi tới first responder qua đúng API của UIKit: commit → `insertText(_:)`, soạn → `setMarkedText(_:selectedRange:)`, Backspace → `deleteBackward()`, Return → `insertText("\n")`, nên lớp con override `deleteBackward()` (ô OTP) vẫn chạy.
- **`UITextField`, `UITextView`, `UIScrollView`, `UIAlertController` có hành vi và hình dạng của iOS 17** mà app quan sát được: thứ tự delegate, control event và notification; delegate từ chối được từng sửa đổi; ô mật khẩu hiện chấm và gõ lại thì thay hết; chữ dài cuộn ngang theo caret, không sửa thì cắt "…"; caret nhấp nháy trên thiết bị; text view xuống dòng và cuộn theo caret; scroll view có đà, nảy, paging, chỉ báo cuộn, giữ chạm cho nội dung 0,15 s; alert và action sheet như iOS 17, handler chạy sau khi đóng.
- **Sửa chữ dùng chung với SwiftUI:** trạng thái sửa chữ của P1-15 chuyển sang `IrisHost` (`TextEditingState`, patch `0031`), thêm vùng chọn và Command-A; `TextField` của SwiftUI và hai view chữ của UIKit sửa chữ cùng một cách. App mẫu SwiftUI vẫn đạt 54 điểm, 81 PNG giống từng pixel với trước.
- **OpenSwiftUI phụ thuộc và re-export OpenUIKit** (patch `0032`), như SwiftUI trên iOS re-export UIKit: `import SwiftUI` thấy `UIColor`, `UIApplication`; `UIKeyboardType`, `UITextContentType` chỉ còn ở OpenUIKit; file import cả SwiftUI lẫn UIKit dịch được (`LoginView.swift` của app mẫu SwiftUI giờ import cả hai).
- **Trang Form của app mẫu UIKit là form đăng nhập gõ tiếng Việt được** ở chế độ kịch bản (20 điểm mới, 82 tất cả, cả hai chế độ) và trong Device UI (mục tổng kết bên dưới).

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| `TextEditingState` dùng chung: chữ có marked text bên trong, vùng chọn, `committedText`, commit/compose (cả `selectedRange`)/unmark/deleteSurrounding, `replace`, Backspace/Delete, mũi tên, Home/End, Command với chúng, Command-A, Return khi nhiều dòng; 3 test | `Sources/IrisHost/TextEditing.swift`, `Tests/OpenUIKitTests/TextEditingTests.swift` |
| `TextField`/`SecureField`/`TextEditor` của SwiftUI dùng nó: binding nhận chữ không có marked text, chạm hay Return giữ chữ đang soạn | patch `openswiftui/0031` (+40 −166) |
| OpenSwiftUI phụ thuộc OpenUIKit và re-export nó; bỏ hai kiểu UIKit của P1-15; ghi rõ `CALayer`, `NSUnderlineStyle` của shim | patch `openswiftui/0032` (+16 −52) |
| Trait bàn phím (`UIKeyboardType`, `UIReturnKeyType`, `UITextContentType`, autocapitalization, autocorrection, spell checking, smart quotes/dashes/insert, appearance), `UITextInputTraits`, `UIKeyInput`, `UITextInput` (tập con), `UITextPosition`, `UITextRange`, `UITextSelectionRect`, `NSValue(cgRect:)` | `Sources/OpenUIKit/UITextInput.swift` |
| Notification bàn phím (`keyboardWill/DidShow`, `Will/DidHide`, `Will/DidChangeFrame`, khung, thời gian, curve) theo first responder; input của host tới first responder | `UITextInput.swift` (`Keyboard`, `TouchInput`) |
| First responder: view rời cửa sổ thì resign, `endEditing(true)` không hỏi delegate, `inputView`, `inputAccessoryView`, `reloadInputViews` | `UIResponder.swift`, `UIView.swift` |
| `IrisTextEditor` (sửa chữ, hỏi delegate với khoảng UTF-16, gõ lại ô mật khẩu, từ ở chỗ chạm hai lần) và `TextCanvasView` (chữ, caret nhấp nháy, vùng chọn, gạch chân) | `IrisTextEditor.swift` |
| `UITextField`: text/attributedText, placeholder (cả attributed), font, màu, căn lề, 4 `borderStyle`, `background`/`disabledBackground`, nút xoá, left/right view, `isSecureTextEntry`, trait, caret, chạm đặt caret, chạm hai lần chọn từ, cuộn ngang, `adjustsFontSizeToFitWidth`, `clearsOnBeginEditing`, `clearsOnInsertion`, mọi rect có thể override, delegate, `editingDidBegin/Changed/End/EndOnExit`, 3 notification, `UITextInput` | `UITextField.swift` |
| `UITextView` (lớp con của `UIScrollView`): chữ nhiều dòng, attributed, `textContainerInset`, `NSTextContainer` (`lineFragmentPadding`, số dòng), `isEditable`/`isSelectable`, `selectedRange`, `scrollRangeToVisible`, cuộn theo caret, tự cao theo chữ khi không cuộn, delegate, notification | `UITextView.swift` |
| `UIScrollView`: `contentSize`, `contentOffset` (KVO), `setContentOffset(_:animated:)`, `contentInset`, `adjustedContentInset` theo `contentInsetAdjustmentBehavior` và safe area, chỉ báo cuộn và inset của chúng, bounce, đà theo `decelerationRate`, paging, `panGestureRecognizer`, `isTracking/isDragging/isDecelerating`, `scrollRectToVisible`, `delaysContentTouches`/`canCancelContentTouches`/`touchesShouldCancel(in:)`, `keyboardDismissMode`, delegate; `ScrollMotion` (rubber band, quãng đà, trang, lò xo) | `UIScrollView.swift` |
| `UIView.safeAreaInsets` (cửa sổ 47/34 như iPhone 14), `accessibilityValue`; `CALayer` vẽ lại `irisDrawing` khi gốc bounds dời | `UIView.swift`, `UIWindow.swift`, `CALayer.swift` |
| `UIAlertController` (`.alert`, `.actionSheet`, `UIAlertAction` 3 style, `isEnabled`, `preferredAction`, `addTextField`, `popoverPresentationController` nil như trên iPhone), `UIViewController.present/dismiss`, `presentedViewController`, `presentingViewController`, `modalPresentationStyle`, `modalTransitionStyle` | `UIAlertController.swift`, `UIViewController.swift` |
| Mô tả màn hình in `value:"…"` (chữ của ô) và `editing`; `tap <chữ>` tìm cả value | `Host.swift` |
| Test: 8 test mới (gõ có marked text và khoảng UTF-16, delegate từ chối, Return, ô mật khẩu, bàn phím và first responder, text view, vật lý cuộn, kéo/đà/nảy/KVO, paging, alert và action sheet) | `Tests/OpenUIKitTests/TextInputTests.swift` |
| App mẫu: `FormPage` (form đăng nhập trong `UIScrollView`, ghi chú `UITextView`, alert chào), `session.txt` 20 điểm mới | `examples/ios-uikit` |
| App mẫu SwiftUI: `LoginView.swift` import cả UIKit | `examples/ios-swiftui` |

### Quyết định

- **Marked text nằm trong chữ, như `UITextInput`:** `textField.text` có chữ đang soạn, `editingChanged` báo cả khi soạn và khi commit (kể cả commit đúng chữ đang soạn, vì app hay giới hạn độ dài trong `editingChanged` khi `markedTextRange == nil`). SwiftUI vẫn chỉ đưa chữ đã commit vào binding như P1-15. Trạng thái chung giữ marked text trong chữ để hai framework là hai cách nhìn của một trạng thái.
- **Delegate được hỏi với khoảng UTF-16 tính từ hai trạng thái** (đầu chung, cuối chung, không bắt đầu sau chỗ đang sửa, làm tròn ra ranh giới ký tự) thay vì mỗi thao tác tự báo khoảng: một chỗ cho mọi đường sửa (commit, soạn, xoá quanh caret, phím, `replace`). Delegate từ chối thì không đổi gì.
- **Bàn phím cao 0 điểm ở đáy màn hình:** Device UI gõ bằng bàn phím của máy tính, như iPhone có bàn phím rời, nên bàn phím không chiếm chỗ. Notification vẫn gửi đủ, theo thứ tự của UIKit, sau `textFieldDidBeginEditing`; app đẩy nội dung lên theo chiều cao bàn phím thì không đẩy gì, thay vì để một khoảng trống mà không có bàn phím nào vẽ ở đó.
- **Ô mật khẩu như iOS:** chấm "•" cho mỗi ký tự; nhận lại bàn phím rồi sửa thì sửa đầu tiên thay toàn bộ chữ (delegate thấy khoảng là cả chữ). Chưa hiện ký tự vừa gõ trong chốc lát (iOS chỉ làm với bàn phím ảo).
- **Return của ô một dòng:** `textFieldShouldReturn`, rồi `editingDidEndOnExit`, và ô chỉ bỏ bàn phím khi có target cho event đó, như UIKit; ô không bao giờ nhận "\n".
- **Caret nhấp nháy bằng timer 0,5 s** (bật/tắt), không bằng animation của render core: host vẽ liên tục 60 frame/giây khi còn animation, còn timer chỉ cần 2 frame/giây. Caret đứng yên sau mỗi lần sửa.
- **Cuộn theo số của UIKit và của `ScrollView` OpenSwiftUI (patch 0011):** rubber band hệ số 0,55, đà giảm theo `decelerationRate` mỗi ms (0,998 / 0,99) tới đích tính trước (delegate đổi được đích qua `targetContentOffset`), trở về mép và paging bằng lò xo tắt dần tới hạn 0,4 s, paging tối đa một trang mỗi lần kéo. Chế độ kịch bản nhảy tới cuối và gọi delegate ngay; thiết bị chạy timer 60 Hz cập nhật `contentOffset` (nên `scrollViewDidScroll` chạy từng frame như UIKit). Vận tốc cho delegate tính theo điểm mỗi ms như UIKit.
- **Chạm trong nội dung như UIKit:** một recognizer giữ `touchesBegan` của nội dung 0,15 s (`delaysContentTouches`), rồi thất bại; pan của scroll view bắt đầu trước đó thì lấy chạm, nội dung không thấy gì; nội dung đã nhận chạm thì pan chỉ bắt đầu nếu `touchesShouldCancel(in:)` cho phép (control giữ chạm). Kéo theo trục không cuộn được thì để cho scroll view bên ngoài. Chạm vào nội dung đang trôi thì dừng nó và không tới nội dung.
- **Alert: handler chạy sau khi alert đóng,** như UIKit (handler present tiếp được). Hai nút: cancel bên trái; nhiều nút: cancel cuối; action sheet: cancel tách riêng, chạm ra ngoài là cancel. Màu nền đặc #F2F2F2 thay cho blur. Alert có ô chữ thì ô đầu nhận bàn phím; không có thì first responder bỏ bàn phím.
- **`present` tối thiểu:** view của view controller được present phủ cả cửa sổ, nằm trên cùng, responder tiếp theo là view controller đã present nó; sheet, chuyển cảnh và callback xuất hiện để cho đợt 4.
- **Re-export OpenUIKit từ OpenSwiftUI bằng `@_exported public import`:** tên của OpenUIKit hiện ra trong mọi file của OpenSwiftUI, nên hai tên trùng với shim (`CALayer` của OpenQuartzCore, `NSUnderlineStyle` của UIFoundation_Private) được ghi kèm module trong hai file dùng chúng. App chỉ thấy bản của OpenUIKit, như trên iOS.
- **First responder vẫn là một cho cả app** (UIKit: một cho mỗi cửa sổ): Iris có một cửa sổ nhận bàn phím mỗi lúc.

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Link lỗi "undefined reference" tới `UIScrollView.run(_:completion:)` từ vtable của `UITextView` | Swift 6.4.1 mangle method `private` có closure `@MainActor @Sendable` của class `@preconcurrency @MainActor` khác nhau ở class và ở lớp con | `private final func` |
| Object không build lại sau khi sửa | Build trong Docker đôi khi giữ object cũ | `touch` file nguồn |
| Gõ "Nguyễn" khi đang soạn "Nguyễn" không báo `editingChanged`, nhãn trạng thái của app mẫu vẫn "Đang soạn" | Chữ không đổi nên `edit` coi là đổi vùng chọn | Marked text đổi cũng là chữ đổi |
| `'CALayer' is ambiguous`, `'NSUnderlineStyle' is ambiguous` khi build OpenSwiftUI | `@_exported import OpenUIKit` đưa tên của OpenUIKit vào mọi file của OpenSwiftUI | Ghi kèm module của shim (patch 0032) |
| `#expect(state.press(…))` không dịch | Macro bọc biểu thức trong closure, không gọi được method `mutating` | Gọi trước, kiểm kết quả |

### Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `check-sample.sh examples/ios-uikit` | 82 điểm (62 cũ, 20 mới) ở chế độ stdout và frame | Build lại sau khi đổi OpenUIKit: khoảng 1 phút |
| Một bước kịch bản trên trang Form | Update 1,1 ms trung bình (tối đa 2,4); vẽ và PNG ở 3x 76 ms | 27 bước, khoảng 90 view |
| `check-sample.sh` (SwiftUI) | 54 điểm ở cả hai chế độ; 81 PNG giống từng pixel với lần chạy của 1b | Build lại OpenSwiftUI sau patch 0031/0032: 1 phút 49 giây đến 2 phút 16 giây |
| `irisrun start examples/ios-uikit` | Build 45 s, frame đầu 0,8 s | Device UI: caret nhấp nháy 2 frame/giây, cuộn và nảy tới khoảng 29 frame/giây ở máy dev |
| Test | 69: OpenUIKit 48 (11 mới), IrisBuild 13, ObjCRewriteTests 6, Swift5AppTests 1, IrisProtocol 1 | |
| Code | OpenUIKit 9651 dòng (+2904; 6 file mới 2770), IrisHost `TextEditing.swift` 234, test mới 439; patch 0031 +40 −166, 0032 +16 −52 | |

### Giới hạn và việc tiếp

- **Nhập chữ:** chưa có copy, cut, paste và menu sửa, tay nắm vùng chọn, kính lúp, Shift với mũi tên, undo, tự sửa lỗi; `UITextInput` thiếu tokenizer, hướng viết và vài truy vấn bố cục; `UITextView` chưa có TextKit (`layoutManager`, `textStorage`), link và data detector; `inputView`/`inputAccessoryView` chỉ được giữ; `touchesShouldBegin(_:with:in:)` không được hỏi; text view chỉ chọn được thì không chọn được chữ.
- **Cuộn:** chưa có zoom (pinch, `zoomScale`, `viewForZooming`), refresh control, khoá hướng, chạm thanh trạng thái để lên đầu; đà dừng ở mép thay vì vượt rồi nảy; `contentOffset` không tự dời khi safe area đổi.
- **Alert và trình bày:** chưa có blur, ảnh, nhiều nút thì không cuộn; `present` luôn phủ cửa sổ, chưa có sheet, chuyển cảnh, `viewWillAppear`… (đợt 4).
- **Đợt 7** dựa trên OpenSwiftUI re-export OpenUIKit: xem [bàn giao](../plans/p1-16-handoff.md).

## Đợt 2: tổng kết

- **Đạt tiêu chí "Form đăng nhập UIKit gõ tiếng Việt được".** Bằng chứng: (1) `session.txt` của `examples/ios-uikit` gõ Telex qua `compose`/`type`/`delete`/`key` vào form (chữ đang soạn "Nguyê" hiện trong ô và trong nhãn "Đang soạn: Nguyê", "Nguyễn Thị Ánh" sau Backspace và sửa của bộ gõ, Return sang ô mật khẩu, mật khẩu "•••••••", nút bật khi đủ hai ô, ghi chú hai dòng, cuộn 96 điểm, alert "Xin chào, Nguyễn Thị Ánh!" rồi "Đã đăng nhập: Nguyễn Thị Ánh"), 82 điểm đạt ở chế độ stdout và frame, PNG như iOS 17; (2) trong Device UI (Chromium headless, sự kiện IME thật `Input.imeSetComposition`/`Input.insertText`), cùng các bước bằng chuột và bộ gõ: chữ đang soạn có gạch chân, commit, Return, mật khẩu chấm, ghi chú, kéo cuộn có nảy, alert và đóng alert đều đúng; (3) form đăng nhập SwiftUI vẫn gõ được tiếng Việt trong Device UI sau khi đổi sang trạng thái sửa chữ chung.
- **Đợt 2 làm được:** chữ (`NSAttributedString` với key của UIKit, đo và vẽ qua render core), `UILabel`, `UIButton` + `Configuration`, `UIImageView`, `UISwitch`, `UISlider`, `UISegmentedControl`, `UIActivityIndicatorView`, `UIProgressView` (2a); nhập chữ với bộ gõ (`UITextField`, `UITextView`, first responder, bàn phím), `UIScrollView`, `UIAlertController` và `present` tối thiểu, sửa chữ chung với SwiftUI, OpenSwiftUI re-export OpenUIKit (2b). 69 test, app mẫu UIKit 82 điểm, app mẫu SwiftUI 54 điểm.
- **Còn lại sau đợt 2** (theo plan): interop SwiftUI (đợt 7, kế tiếp), Auto Layout (đợt 3), view controller và điều hướng (đợt 4), bảng (đợt 5), storyboard (đợt 6); các giới hạn ở mục "Giới hạn và việc tiếp" của 2a và 2b.

## Đợt 7a: một host, một cảnh, `UIHostingController` (16/10)

Đợt 7 (interop SwiftUI) chia hai phần: 7a là phần này, 7b là `UIViewRepresentable`/`UIViewControllerRepresentable` ([bàn giao](../plans/p1-16-handoff.md)).

### Kết luận

- **Mọi app chạy trong một host:** app SwiftUI giờ chạy như trên iOS. `App.main()` trên Linux gọi `UIApplicationMain` của OpenUIKit với app delegate của SwiftUI (`IrisAppDelegate`); scene delegate của nó (`IrisSceneDelegate`) đặt view của scene đầu tiên vào một `UIWindow` có gốc là `UIHostingController`. Host stdout/thiết bị riêng của SwiftUI (`StdoutApp` + `IrisDevice`) không còn được dùng: app SwiftUI và app UIKit chung một host Device Protocol, một ngôn ngữ lệnh kịch bản và một mô tả màn hình (cây view của UIKit, nội dung SwiftUI liệt kê bên trong hosting view, chữ trong ngoặc kép như trước).
- **Một chủ của cảnh:** UIKit giữ `irisScene.root` và chỉ gỡ layer cửa sổ nó đã gắn. SwiftUI vẽ display list vào một layer render của hosting view (`CALayer._irisContentLayer`, trên phần vẽ, dưới sublayer), không xoá root nữa. Chi phí mỗi frame giữ như cũ: OpenSwiftUI vẫn dựng lại layer theo mỗi display list, nhưng chỉ trong cây con của mình.
- **`UIHostingController` dùng được làm gốc cửa sổ và làm view controller con trong màn UIKit:** `init(rootView:)`, `init?(coder:rootView:)`, `rootView` đổi được (state của SwiftUI giữ nguyên), `view`, `sizeThatFits(in:)`, `sizingOptions` (`preferredContentSize`, `intrinsicContentSize`), `safeAreaRegions`. Nội dung layout theo bounds và safe area của view UIKit, nhận trait của UIKit (display scale, size class compact/regular, light), sheet và alert của SwiftUI hiện trong nó.
- **Chạm và bàn phím chia đúng bên:** UIKit hit-test như mọi view; chạm trúng hosting view đi tiếp vào hệ sự kiện của SwiftUI (gesture, nút, cuộn), chạm chỗ khác ở lại UIKit. Khi một ô chữ SwiftUI được focus, hosting view thành first responder của UIKit nên bàn phím tới SwiftUI; ô UIKit nhận bàn phím thì SwiftUI bỏ focus, và ngược lại.
- **App mẫu SwiftUI không đổi dòng nào, vẫn đạt 54 điểm ở cả hai chế độ; 81 PNG giống từng pixel với lần chạy trước khi đổi** (chạy hai lần, cả hai giống). Display list của mọi bước giống hệt; chỉ phần đầu mô tả màn hình đổi (xem Quyết định).
- **App mẫu UIKit có trang "SwiftUI"** (16 điểm mới, 98 tất cả, cả hai chế độ): thẻ SwiftUI trong `UIHostingController` là view controller con, cao theo `sizeThatFits(in:)`; chạm nút SwiftUI đổi state và báo UIKit qua closure; gõ Telex vào ô SwiftUI; ô UIKit lấy bàn phím rồi trả lại; nút UIKit thay `rootView`. Trong Device UI cả hai app chạy như trên (ảnh ở mục Số đo).

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| `UIHostingController<Content>` cho Linux; `UIHostingControllerSizingOptions` của upstream mở cho Linux | patch `openswiftui/0033`, `Integration/Hosting/UIKit/Controller/IrisHostingController.swift` |
| `_UIHostingView<Content>`: `ViewRendererHost` của một `UIView` (bounds, safe area theo `safeAreaRegions`, trait, môi trường kế thừa của scene), render khi layout, settle trong kịch bản, sizing, chạm → `DeviceInput`, focus ↔ first responder, `DeviceInputHandler` cho bàn phím, `_IrisScreenContent` cho mô tả màn hình | `Integration/Hosting/UIKit/View/IrisHostingView.swift` (patch 0033) |
| `runApp` trên Linux → `runIrisApp`: `AppGraph`, `IrisAppDelegate` (chuyển callback vòng đời cho delegate của app), `IrisSceneDelegate` (cửa sổ, `scenePhase` theo vòng đời scene) | `App/App/Stdout/IrisApp.swift`, `App.swift` (patch 0033) |
| `UIApplicationDelegateAdaptor` trên Linux: delegate của app tạo qua factory `_IrisInstantiable` mà `irisrun-ios-build` đã sinh | `App/App/UIKit/UIApplicationDelegateAdaptor.swift` (patch 0033) |
| Display list vẽ vào layer của host (`IrisLayerHost`, `Scene.show(_:in:)`), `DisplayList.stdoutLines` cho mô tả màn hình | `DisplayListLayerRenderer.swift`, `DisplayListStdoutRenderer.swift` (patch 0033, +674 −12 tất cả) |
| `CALayer._irisContentLayer`; `LayerCommit` chỉ gỡ layer cửa sổ nó gắn, tính cả thay đổi của SwiftUI khi báo frame mới | `Sources/OpenUIKit/CALayer.swift` |
| `irisAnimates` (thay `LayerCommit.animates`) và `irisScriptTime` (thời gian giữ ngón tay trong kịch bản) trong host chung | `Sources/IrisHost/Window.swift`, `Host.swift` |
| Mô tả màn hình: `_IrisScreenContent` (nội dung SwiftUI trong hosting view, `tap <chữ>` tìm cả chữ SwiftUI), tên class generic bỏ phần `<…>` | `Sources/OpenUIKit/Host.swift` |
| Input chữ tới first responder là `DeviceInputHandler` (hosting view); bàn phím hiện cho nó | `UITextInput.swift` |
| `UIViewController`: `addChild`, `removeFromParent`, `children`, `parent`, `willMove/didMove(toParent:)`, `preferredContentSize` | `UIViewController.swift` |
| `irisrun-ios-build` ghi `UIApplicationSceneManifest` khi project có `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`, như Xcode | `Sources/IrisBuild/AppTarget.swift` |
| Test: 4 test mới (layer của chủ khác ở yên khi vẽ lại và khi đổi cửa sổ; input chữ tới bên có bàn phím và chuyển qua lại; view controller con), 1 kiểm tra manifest | `Tests/OpenUIKitTests/InteropTests.swift`, `Tests/IrisBuildTests/IrisBuildTests.swift` |
| App mẫu UIKit: segment "SwiftUI", `SwiftUIPage` + `GreetingCard` (iOS 17, dịch được trong Xcode), 16 điểm mới | `examples/ios-uikit` |

### Quyết định

- **Một host, theo hướng của iOS** (đề xuất của plan, đã làm): upstream đã có app delegate và scene delegate cho UIKit thật (`App/App/UIKit/UIKitAppDelegate.swift`, 716 dòng, nhiều API riêng của UIKit), nên bản Linux viết mới gọn hơn (138 dòng) theo đúng đường đó: `UIApplicationMain` → app delegate của SwiftUI → scene delegate → `UIWindow` + `UIHostingController`. Không có lý do giữ hai host. `runStdoutApp` vẫn còn cho app tự xin renderer stdout qua SPI `rendererConfiguration` (không app iOS nào dùng); khi đó nó có cả root của cảnh.
- **`_UIHostingView` viết mới cho Linux** theo `StdoutRendererHost` (đã chạy trên Linux), không lấy `_UIHostingView` của upstream (2300 dòng gắn với UIKit thật: display link, `UIHostingViewBase`, trait collection riêng). Tên và API công khai theo SwiftUI; `_UIHostingView` để internal.
- **SwiftUI vẽ vào layer của hosting view, UIKit gắn layer đó:** `CALayer._irisContentLayer` (public có gạch dưới, vì OpenSwiftUI là module khác) được gắn trên phần vẽ, dưới sublayer; frame do chủ đặt. Như vậy cây layer của UIKit là chủ duy nhất của root, và `show(_:in:)` chỉ xoá con của layer được giao.
- **Hosting view render khi layout:** graph xin update thì hosting view gọi `setNeedsLayout()` (thiết bị: sau độ trễ, tối đa 60 lần mỗi giây), `LayerCommit` layout rồi vẽ. Đồng hồ của graph: trên thiết bị theo uptime (như host cũ); trong kịch bản chỉ chạy khi settle (60 Hz ảo, tối đa 2 s, như `settle` của app stdout) và khi ngón tay được giữ (`hold` của UIKit chờ 0,6 s thật rồi cộng vào `irisScriptTime`, SwiftUI cộng vào đồng hồ trước sự kiện kế tiếp). Nhờ vậy long press của SwiftUI và recognizer của UIKit đều chạy trong `hold`, và PNG không phụ thuộc tốc độ máy.
- **Focus một nơi:** first responder của UIKit là nguồn sự thật. SwiftUI focus một ô thì hosting view `becomeFirstResponder()` (không được thì SwiftUI bỏ focus); hosting view bị resign (ô UIKit nhận bàn phím, `endEditing`, rời cửa sổ) thì bỏ focus của SwiftUI nếu ô đó vẫn là của nó. Input của host tới first responder; hosting view là một `DeviceInputHandler` (giao thức của IrisHost) nên chữ, marked text, xoá quanh caret và phím tới thẳng ô SwiftUI như trước, không cần giả `UITextInput`.
- **Chạm qua responder của UIKit:** `touchesBegan/Moved/Ended/Cancelled` của hosting view chuyển thành sự kiện của SwiftUI, toạ độ trong hosting view. Recognizer của view cha (vd. pan của scroll view) thấy chạm trước và huỷ được, như iOS. Chạm `.stationary` không tới view (UIKit cũng vậy); vận tốc kéo của SwiftUI vẫn 0 khi ngón dừng trước khi nhấc, vì nó chỉ nhìn 0,1 s cuối.
- **Hosting view gốc của app SwiftUI bỏ safe area (`safeAreaRegions = []`):** app SwiftUI trên Iris trước giờ layout từ mép màn hình; giữ nguyên để `session.txt` (có toạ độ) và PNG không đổi. Hosting controller do app tạo thì theo safe area của UIKit như iOS. Có theo safe area của iOS ở gốc không (đổi toạ độ trong `session.txt` và PNG mẫu) là câu hỏi mở cho người dùng.
- **Mô tả màn hình chung:** phần đầu là của UIKit (`OpenUIKit backend: stdout`, không còn `display-list-version`), mỗi bước in một lần sau khi settle (chế độ stdout cũ của SwiftUI in mỗi display list mới, nhiều lần một bước). Dòng `fill …`/`text … "…"` của SwiftUI nằm dưới dòng `_UIHostingView`, toạ độ trong hosting view; `# expect` và `tap <chữ>` chạy như cũ, `session.txt` không phải sửa. Hosting view đang có bàn phím in `editing`.
- **Scene manifest như Xcode:** `irisrun-ios-build` trước bỏ các cờ `_Generation`; giờ ghi `UIApplicationSceneManifest` (`UIApplicationSupportsMultipleScenes = true`) cho cờ của manifest, để app SwiftUI vào vòng đời scene như trên iOS. OpenUIKit vẫn quyết định theo manifest như UIKit.
- **`@UIApplicationDelegateAdaptor`:** delegate được tạo khi `App` được tạo (iOS: khi SwiftUI cần), qua `_IrisInstantiable`. Delegate là `ObservableObject`/`Observable` dùng init chung, không vào environment (ponytail). App delegate của SwiftUI chuyển các callback vòng đời, không chuyển mọi method như `forwardingTarget` của iOS.

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Context menu (long press) của app mẫu SwiftUI không mở trong kịch bản | `hold` của host UIKit chờ thời gian thật, còn đồng hồ của graph SwiftUI trong kịch bản là ảo; `DurationGesture` đo bằng thời gian của view graph | `irisScriptTime`: host cộng thời gian giữ, hosting view đưa đồng hồ tới đó trước sự kiện kế tiếp (như `render(interval: 0.6)` của app stdout) |
| `cannot find type 'PlatformViewDefinition'` | Kiểu nằm sau SPI `DisplayList_ViewSystem` | `@_spi(DisplayList_ViewSystem) import OpenSwiftUICore` |
| Công cụ so PNG báo "giống" cả khi khác | `getbbox()` của ảnh RGBA chỉ nhìn kênh alpha | `getbbox(alpha_only=False)` (`~/.cache/irisrun/devtools/pngdiff.py`) |

### Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `check-sample.sh` (SwiftUI) | 54 điểm ở chế độ stdout và frame; 81/81 PNG giống từng pixel với baseline, hai lần chạy | Update mỗi bước trung bình 175 ms (trước 172), tối đa 2,1 s ở bước kéo có đà (trước 1,9 s); vẽ và PNG 102 ms (trước 112) |
| `check-sample.sh examples/ios-uikit` | 98 điểm (82 cũ, 16 mới) ở cả hai chế độ | 57 PNG cũ chỉ khác ở segmented control (4 segment) và một frame có đèn timer 0,3 s chạy theo thời gian thật (đã khác giữa các lần chạy trước đây); 11 frame mới. Bước của trang SwiftUI: update trung bình 19 ms, tối đa 73 ms |
| Device UI | App UIKit: trang SwiftUI chạm, soạn Telex ("Ánh" gạch chân rồi commit), ô UIKit lấy bàn phím, đổi tiêu đề; app SwiftUI: chi tiết sách, yêu thích, đăng nhập Telex, sheet mở và đóng | Frame đầu 0,8 s (UIKit), 1,5 s (SwiftUI); ảnh ở `~/.cache/irisrun/p1-16/7a/live/` |
| Test | 73: OpenUIKit 52 (4 mới), IrisBuild 13, ObjCRewriteTests 6, Swift5AppTests 1, IrisProtocol 1 | |
| Code | Patch 0033 +674 −12 (hosting view 400, app 138, controller 65); OpenUIKit và IrisHost khoảng +120 dòng; test mới 118 dòng; app mẫu `SwiftUIPage.swift` 90 dòng | |

### Giới hạn và việc tiếp

- **Chưa có platform view** (`UIViewRepresentable`, `UIViewControllerRepresentable`): đợt 7b, chỗ nối ở [bàn giao](../plans/p1-16-handoff.md).
- **Hosting view:** sheet/alert của SwiftUI hiện trong khung nội dung của hosting view (iOS trình bày trên cả cửa sổ qua view controller); chưa có `safeAreaRegions` cho bàn phím (bàn phím Iris cao 0), `UIHostingController` không đổi `preferredStatusBarStyle`, toolbar hay navigation item của UIKit; `intrinsicContentSize` chưa ai đọc cho tới Auto Layout (đợt 3); một scene, không theo dõi thay đổi danh sách scene của app, không `SceneStorage`, không chuyển scene delegate của app.
- **Hit-test:** hosting view nhận mọi chạm trong bounds, cả chỗ trong suốt (như iOS 17). Nhiều ngón trong một hosting view: mỗi lần chỉ gửi ngón đổi phase.
- **App SwiftUI vẫn bỏ safe area** ở gốc (xem Quyết định).
- **App không có project Xcode** (một thư mục file Swift) không có Info.plist nên không có scene manifest: app SwiftUI như vậy sẽ không có cửa sổ. Trên iOS cũng cần manifest; thêm manifest mặc định nếu corpus có app như vậy.

## Đợt 7b: UIKit trong SwiftUI (`UIViewRepresentable`, 16/10)

Phần thứ hai của đợt 7: màn SwiftUI nhúng view và view controller UIKit, cùng hai việc 7a để lại (safe area của app SwiftUI, scene manifest cho thư mục không có project Xcode).

### Kết luận

- **`UIViewRepresentable` và `UIViewControllerRepresentable` chạy với vòng đời của SwiftUI:** code của upstream (`PlatformViewRepresentable`, `PlatformViewChild`, `ViewLeafView`, hai protocol public) mở cho Linux; chỉ `PlatformViewHost` (view chứa view UIKit) và responder của nó viết mới cho Linux. Coordinator tạo trước, `updateUIView` chạy ngay sau `makeUIView`, chạy lại khi input của view (hay môi trường nó đọc) đổi, không chạy khi state khác của cha đổi, và một lần nữa khi view bị gỡ (phase đổi, như code của SwiftUI), rồi `dismantleUIView` đúng một lần; hiện lại thì coordinator và view mới. View controller là con của hosting controller (`willMove`/`didMove(toParent:)`) khi view của nó ở trong cửa sổ.
- **Kích thước như iOS:** `sizeThatFits(_:uiView:context:)` nếu app có; không thì theo `intrinsicContentSize` và độ ưu tiên hugging/compression (≥ 750 thì cố định chiều đó, `noIntrinsicMetric` thì nhận mọi cỡ). `invalidateIntrinsicContentSize()` của view UIKit làm SwiftUI layout lại. OpenUIKit có thêm `UILayoutPriority`, `contentHuggingPriority`/`contentCompressionResistancePriority` (mặc định 250/750 như UIKit).
- **Vẽ đúng thứ tự:** view UIKit là subview của hosting view (trong `PlatformViewHost`, như iOS), còn layer render của nó nằm đúng chỗ của item trong cây layer của display list: nội dung SwiftUI vẽ trước nằm dưới, vẽ sau nằm trên; opacity, clip, transform (cả `rotationEffect`), cuộn của SwiftUI áp lên nó. Frame trong UIKit khớp chỗ vẽ, nên hit-test và `convert` của UIKit đúng.
- **Chạm chia theo SwiftUI:** view UIKit có responder trong cây responder của SwiftUI; hosting view hỏi hit-test của SwiftUI xem điểm chạm thuộc nội dung SwiftUI ở trên hay view UIKit; thuộc UIKit thì UIKit hit-test tiếp bên trong (control, recognizer, scroll view), không thì SwiftUI nhận. Nội dung `allowsHitTesting(false)` để chạm đi xuyên qua.
- **Bàn phím:** `UITextField` trong representable nhận bàn phím khi chạm, ô SwiftUI lấy lại khi chạm vào nó, qua lại nhiều lần; first responder của UIKit vẫn là nguồn sự thật (cơ chế của 7a, không phải sửa).
- **App SwiftUI có safe area của iOS** (47 trên, 34 dưới): nội dung nằm trong safe area, `ignoresSafeArea()` chạy, nền mở rộng như SwiftUI; scroll view và `List` tràn xuống dưới thanh home indicator theo trục cuộn, nội dung đầu và cuối tránh nó; sheet chạm đáy màn hình, lớp tối của sheet/alert/dialog/menu phủ cả màn hình.
- **Thư mục file Swift không có project Xcode** có Info.plist như Xcode sinh cho app mới (scene manifest), cộng `Info.plist` trong thư mục nếu có; app SwiftUI như vậy có cửa sổ.
- **Mẫu:** app SwiftUI có màn "UIKit" (68 điểm, 14 điểm mới); app kiểm tra `runtimes/ios/Tests/Apps/Representables` (11 điểm, vòng đời, kích thước, chạm); app UIKit vẫn 98 điểm. Trong Device UI: gõ "Việt" (IME thật của Chromium) vào ô UIKit trong màn SwiftUI và "Năm" vào ô SwiftUI, chạm hai bên đều đúng.

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIViewRepresentableContext` (`coordinator`, `transaction`, `environment`, `animate` chạy thay đổi ngay) của upstream mở cho Linux | patch `openswiftui/0036`, `Integration/Representable/UIKit/*.swift` |
| Vòng đời, kích thước, display list của upstream (`PlatformViewChild`, `ViewLeafView`, `PlatformViewDisplayList`, `InvalidatableLeafLayoutComputer`) mở cho Linux; responder của view thêm vào `ViewLeafView` | `Platform/PlatformViewRepresentable.swift` (0036) |
| `PlatformViewHost` cho Linux: chứa view UIKit, layout traits từ intrinsic size và priority, báo SwiftUI khi intrinsic size đổi (sau update đang chạy), containment cho view controller; `UIViewResponder` + `PlatformViewResponderFilter` | `Platform/IrisPlatformViewHost.swift` (0036, 230 dòng) |
| Renderer tìm `.platformView` trong display list, để một layer "chỗ" (toạ độ của hosting view) đúng vị trí trong cây layer; hosting view đặt subview, frame/transform UIKit và gắn layer | `DisplayListLayerRenderer.swift`, `IrisHostingView.swift` (`irisPlace`, `hitTest`) (0036) |
| Safe area cho app SwiftUI; scroll view tràn theo trục cuộn; sheet/alert/dialog/menu phủ cả màn hình | patch `0034` (`IrisApp.swift`, `ScrollView.swift`, `IrisPresentation.swift`, `IrisMenu.swift`) |
| Vẽ `rotationEffect` (display list có case `.rotation` riêng, trước bị bỏ qua); ellipse bắt đầu bên phải, theo chiều kim đồng hồ như Core Graphics | patch `0035` |
| `CALayer._irisOwnerLayer`: layer render của một layer gắn vào layer render của framework khác (chỗ trong display list), layer cha bỏ qua nó | `Sources/OpenUIKit/CALayer.swift` |
| `invalidateIntrinsicContentSize()` báo superview (`_intrinsicContentSizeInvalidated(forChildView:)`); `UILayoutPriority`, `NSLayoutConstraint.Axis`, hugging/compression; `viewWillLayoutSubviews`/`viewDidLayoutSubviews` | `UIView.swift`, `NSLayoutConstraint.swift` (mới), `UIViewController.swift` |
| Info.plist cho app là thư mục (scene manifest như Xcode, cộng `Info.plist` có sẵn) | `Sources/IrisBuild/AppTarget.swift` |
| Test: layer có chủ khác vẽ trong layer của chủ đó và quay lại khi bỏ; superview nghe intrinsic size đổi, priority mặc định; callback layout của view controller; Info.plist của app thư mục | `Tests/OpenUIKitTests/InteropTests.swift`, `Tests/IrisBuildTests/IrisBuildTests.swift` |
| App kiểm tra representable (thư mục không có project Xcode), chạy trong CI | `Tests/Apps/Representables`, `.github/workflows/ios-sample.yml` |
| App mẫu SwiftUI: màn "UIKit" (`UITextField` + coordinator, `LoadingStatusView` của app với spinner, `UISwitch` + coordinator, `UIViewController` đếm chạm), `session.txt` đổi toạ độ theo safe area và thêm 14 điểm | `examples/ios-swiftui/IrisSample/UIKitView.swift`, `ContentView.swift`, `session.txt` |

### Quyết định

- **Mở code upstream thay vì viết gọn:** `PlatformViewChild` của upstream là vòng đời của SwiftUI (so sánh input qua graph, environment theo tracker, `performExternalUpdate`, `ObservedAttribute.destroy` gọi dismantle); Compute gọi `destroy` khi subgraph bị gỡ, nên chạy được trên Linux không sửa dòng nào. Chỉ phần gắn với UIKit thật (`_UIConstraintBasedLayoutHostingView`, safe area helper, focus) viết lại cho Linux.
- **Thứ tự vẽ bằng "layer chỗ"** (cách (b) của bàn giao): renderer để một layer rỗng ở vị trí của item, transform của nó là nghịch đảo của transform từ cha tới hosting view, nên toạ độ bên trong là toạ độ của hosting view; layer render của `PlatformViewHost` gắn vào đó (`CALayer._irisOwnerLayer`) và UIKit vẫn đặt frame của nó như mọi view. Một chỗ cho mọi effect: opacity, clip, transform, cuộn đều đi qua cây layer.
- **Hit-test hỏi SwiftUI** như iOS hỏi responder: một `UIViewResponder` cho mỗi representable trong cây responder; hosting view chỉ hỏi khi UIKit hit-test trúng view trong một representable, nên app không có representable không đổi gì. Chạm mà view UIKit không xử lý (view thường) đi lên chuỗi responder tới hosting view, rồi tới gesture SwiftUI gắn trên representable, như iOS.
- **Kích thước theo luật của upstream** (iOS 17, không "unified layout"); không gọi `UIView.sizeThatFits(_:)` của view, như SwiftUI (app muốn thì tự gọi trong `sizeThatFits(_:uiView:context:)`).
- **`invalidateIntrinsicContentSize` báo superview** qua `_intrinsicContentSizeInvalidated(forChildView:)` (hook riêng của UIKit có tên đó); `PlatformViewHost` xếp việc invalidate layout của SwiftUI vào sau update đang chạy (`Update.enqueueAction`), vì `updateUIView` hay đổi chữ của label. Auto Layout (đợt 3) sẽ dùng cùng hook.
- **View controller rời hosting controller khi view rời cửa sổ** (`willMove(toParent: nil)`, `removeFromParent`); chưa có callback appearance vì UIKit của Iris chưa có (đợt 4).
- **Safe area như iOS cho app SwiftUI** (câu hỏi mở của 7a, task này quyết): bỏ `safeAreaRegions = []`. Kéo theo hai chỗ của Iris trước giờ giả định không có safe area: `ScrollView` (giờ `ignoresSafeArea` theo trục cuộn, đệm nội dung bằng inset) và lớp trình bày (lớp tối và `GeometryReader` của menu bỏ safe area, sheet chạm đáy).
- **`rotationEffect` vẽ được** vì representable xoay phải xoay; khi bật thì lộ lỗi ellipse bắt đầu ở đỉnh (vòng tiến độ của form đăng nhập trước "đúng" nhờ hai lỗi bù nhau), sửa luôn trong patch `0035`.
- **Manifest cho app thư mục theo mặc định của Xcode** (`UIApplicationSceneManifest_Generation = YES`): app SwiftUI chạy trong scene. ponytail: app UIKit thư mục tự tạo cửa sổ trong app delegate cần Info.plist không có manifest; chưa thấy app như vậy trong corpus.
- **App kiểm tra thay cho `swift test`** ở phần OpenSwiftUI: package `runtimes/ios` không phụ thuộc được OpenSwiftUI (OpenSwiftUI phụ thuộc nó), nên vòng đời, kích thước và hit-test của representable được kiểm bằng một app thư mục chạy qua `check-sample.sh` (build chung với OpenSwiftUI đã có, ~30 s). Phần OpenUIKit có test riêng.

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Lần "Thêm sách" thứ 12 không có tác dụng sau khi có safe area | Nút "Add book" bị đẩy xuống dưới đáy màn hình, chạm vào chữ của nó rơi ra ngoài | `session.txt` dùng nút "Thêm" trên thanh công cụ cho lần cuối |
| Long press "Book 4" không mở menu | Hàng đó cuộn vào dưới thanh điều hướng (bị cắt), như trên iOS không chạm được | Giữ "Book 7", mở "Book 8" (hàng nhìn thấy) |
| Menu ngữ cảnh lệch 47 điểm, lớp tối chừa thanh trạng thái và home indicator | Lớp trình bày nằm trong safe area, còn anchor của menu theo toạ độ màn hình | Patch `0034` |
| Representable xoay không xoay | Display list có `.transform(.rotation)` riêng, renderer chỉ vẽ `.affine` | Vẽ mọi transform có `affineTransform` (`0035`) |
| Vòng tiến độ của form đăng nhập lệch một phần tư vòng sau khi vẽ rotation | Ellipse dựng như hình chữ nhật bo góc, bắt đầu ở đỉnh | Ellipse bắt đầu bên phải, theo chiều kim đồng hồ (`0035`); PNG giống trước, chỉ khác khử răng cưa (370 pixel) |
| `cannot find type 'CGAffineTransform'` trong renderer | OpenSwiftUICore lấy kiểu CoreGraphics qua shim | `package import OpenCoreGraphicsShims` |

### Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `check-sample.sh` (SwiftUI) | 68 điểm (54 cũ, 14 mới) ở chế độ stdout và frame; 97 PNG | Mọi PNG cũ khác 7a vì safe area. Đã kiểm: dời 47 điểm thì giống 7a, trừ hàng "UIKit" mới, nội dung căn giữa theo chiều dọc dời 6,5 điểm ít hơn (căn trong 763 điểm thay vì 844), danh sách cuộn tới đáy màn hình (vị trí cuộn khác), lớp tối/sheet phủ cả màn hình, vòng tiến độ (khử răng cưa) và vài đường kẻ 1 pixel |
| `check-sample.sh examples/ios-uikit` | 98 điểm cả hai chế độ; 68/68 PNG giống 7a ở lần chạy cuối | Lần chạy trước frame 1 khác ở đèn timer 0,3 s chạy theo thời gian thật (đã biết từ 7a) |
| App kiểm tra representable | 11 điểm cả hai chế độ | Build app ~30 s khi OpenSwiftUI đã build |
| Device UI | Màn "UIKit": gõ Telex/IME "Việt" vào ô UIKit (SwiftUI thấy theo), "Năm" vào ô SwiftUI, công tắc UIKit, nút SwiftUI đè lên view UIKit, view controller đếm/đặt lại; sheet, đăng nhập "Nguyễn"; app UIKit: trang SwiftUI chạm được | Ảnh ở `~/.cache/irisrun/p1-16/7b/live/` |
| Test | 75: OpenUIKit 54 (2 mới, 1 mở rộng), IrisBuild 13 (1 mở rộng), ObjCRewriteTests 6, Swift5AppTests 1, IrisProtocol 1 | |
| Code | Patch `0034` +25 −9, `0035` +15 −2, `0036` +382 −28 (host 230); OpenUIKit khoảng +100 dòng; app kiểm tra 230 dòng; màn mẫu 228 dòng | |

### Giới hạn và việc tiếp

- **Hit-test bỏ qua clip:** phần view UIKit bị `.clipped()`/`clipShape` cắt đi vẫn nhận chạm (UIKit và responder của SwiftUI đều theo frame đầy đủ); iOS đặt view trong view chứa có `clipsToBounds`.
- **Môi trường SwiftUI chưa tới trait của UIKit** (`updateEnvironment` chỉ lưu): `colorScheme`, `tint`, `layoutDirection` không đổi view UIKit; chưa có baseline chữ (căn theo `firstTextBaseline` lấy đỉnh); safe area không truyền vào view UIKit (`propagatesSafeArea` là SPI); focus của SwiftUI (`@FocusState`) không biết ô UIKit.
- **Thứ tự subview trong UIKit không theo display list** (chỉ thứ tự vẽ và hit-test theo SwiftUI); view chồng nhau vẫn đúng vì hosting view hỏi SwiftUI.
- **Sheet, alert do SwiftUI trình bày từ hosting controller nhúng** hiện trong vùng của nó, không phủ cửa sổ; đợt 4 chuyển chúng qua `present` của UIKit khi tổng quát hoá việc trình bày.
- **View controller:** chưa có callback appearance (`viewWillAppear`…), chưa `preferredContentSizeDidChange` (SwiftUI lấy `preferredContentSize` lúc layout).
- **Lớp danh sách của Iris** vẫn đặt thanh điều hướng phía trên nội dung (không cuộn xuống dưới thanh như iOS); hàng cuộn khuất dưới thanh không chạm được.

## Đợt 7: tổng kết

Tiêu chí của plan: "Màn SwiftUI nhúng `UIView` và ngược lại". **Đạt.**

- **UIKit nhúng SwiftUI (7a):** trang "SwiftUI" của app mẫu UIKit đặt `UIHostingController` làm view controller con; chạm, gõ Telex, đổi `rootView`, kích thước theo `sizeThatFits(in:)` (16 điểm trong `examples/ios-uikit/session.txt`, Device UI).
- **SwiftUI nhúng UIKit (7b):** màn "UIKit" của app mẫu SwiftUI có `UITextField`, view UIKit của app, `UISwitch` qua `UIViewRepresentable` và một `UIViewController` qua `UIViewControllerRepresentable`; state đi hai chiều (`updateUIView`, coordinator → binding), chạm tới đúng bên kể cả khi nút SwiftUI vẽ đè lên view UIKit, gõ được ở cả hai ô (14 điểm trong `examples/ios-swiftui/session.txt`, Device UI với IME thật). App kiểm tra `Tests/Apps/Representables` khoá vòng đời, kích thước và hit-test (11 điểm).
- **Một host:** app SwiftUI và UIKit chạy chung host, chung cây layer của UIKit, chung chuỗi responder và first responder; app SwiftUI có safe area của iOS.
- Còn lại cho các đợt sau: Auto Layout (đợt 3) cho view UIKit dựng bằng constraint trong representable; trình bày qua UIKit (đợt 4); các giới hạn ở mục trên.

## Đợt 3a: Auto Layout, phần engine (16/10)

Phần đầu của đợt 3: solver, constraint, layout guide, margin, kích thước vừa. Phần 3b (`UIStackView`, `UIView.animate` với `layoutIfNeeded`, màn mẫu ở cỡ màn hình thứ hai) làm tiếp theo [bàn giao](../plans/p1-16-handoff.md).

### Kết luận

- **Solver chọn bằng đo: crate Rust [kasuari](https://crates.io/crates/kasuari) 0.4 (MIT OR Apache-2.0) trong render core, qua C ABI** (`iris_layout_*` trong `include/irisrun_render.h`, lớp `LayoutSolver` của gói Swift `IrisRender`). Không thêm dependency SwiftPM: render core đã link vào mọi app. kasuari là bản fork của `cassowary-rs` do nhóm ratatui giữ, nhanh gấp đôi bản gốc, nhanh gấp 9 lần port Swift tốt nhất ở màn lớn (bảng "Số đo").
- **API như UIKit:** `NSLayoutConstraint` (init item/attribute, `activate`/`deactivate`, `isActive`, `constant`, `multiplier`, `priority`, `identifier`, item, attribute, relation, `firstAnchor`/`secondAnchor`, `description` như UIKit), `Attribute` (cả margin, `centerXWithinMargins`, baseline), `Relation`; `NSLayoutAnchor`, `NSLayoutXAxisAnchor`, `NSLayoutYAxisAnchor`, `NSLayoutDimension` với mọi overload, cả system spacing; anchor của `UIView` và `UILayoutGuide`; `UIView.constraints`, `addConstraint(s)`/`removeConstraint(s)`, `translatesAutoresizingMaskIntoConstraints`, `updateConstraints`/`updateConstraintsIfNeeded`/`setNeedsUpdateConstraints`/`needsUpdateConstraints`/`requiresConstraintBasedLayout`, `systemLayoutSizeFitting` (hai dạng), `layoutFittingCompressedSize`/`ExpandedSize`, `hasAmbiguousLayout`, `exerciseAmbiguityInLayout`; `UILayoutGuide` (`addLayoutGuide`, `layoutFrame`, `owningView`, `identifier`), `safeAreaLayoutGuide`, `layoutMarginsGuide`, `readableContentGuide`, `keyboardLayoutGuide` (`UIKeyboardLayoutGuide`, `UITrackingLayoutGuide`), `layoutMargins`, `directionalLayoutMargins`, `preservesSuperviewLayoutMargins`, `insetsLayoutMarginsFromSafeArea`, `layoutMarginsDidChange`; ở `UIViewController`: `updateViewConstraints`, `systemMinimumLayoutMargins`, `viewRespectsSystemMinimumLayoutMargins`, `viewLayoutMarginsDidChange`, `viewSafeAreaInsetsDidChange`.
- **Engine như UIKit:** mỗi cây view có một engine ở view trên cùng (cửa sổ, với view trên màn hình). Constraint của app cùng constraint UIKit tự tạo (autoresizing mask của view dịch mask, intrinsic size với hugging/compression, khung của guide) thành ràng buộc tuyến tính; vị trí tương đối như UIKit (origin của view trong superview, của guide trong view chủ), constraint giữa hai item cộng vị trí các view ở giữa tới view chung gần nhất. Giải trong `LayerCommit.commit()` trước lượt layout (sau lượt update constraints, từ lá lên) và trong `layoutIfNeeded()`; `layoutSubviews()` gốc đặt frame đã giải cho subview, nên override gọi super trước như trên iOS. View không constraint nào nhắc tới vẫn layout bằng frame và autoresizing.
- **Đổi tăng dần:** đổi `constant`, `priority` (giữa hai mức không bắt buộc), intrinsic size (`invalidateIntrinsicContentSize`, priority của content), margin, frame của view dịch mask chỉ thay vài ràng buộc trong solver; đổi cấu trúc (activate, thêm/bớt view, guide) mới duyệt lại cây.
- **Nhãn nhiều dòng hai lượt như iOS:** nhãn `numberOfLines != 1` không có `preferredMaxLayoutWidth` đo lại chiều cao ở bề rộng solver vừa cho, trong cùng lượt giải; `systemLayoutSizeFitting` của ô kiểu table cell cũng vậy. Baseline tính từ metric chữ (nhãn) hoặc font (nút, ô chữ).
- **Xung đột như UIKit:** ràng buộc bắt buộc mâu thuẫn bị bỏ, log `[LayoutConstraints] Unable to simultaneously satisfy constraints.` với đúng tập ràng buộc mâu thuẫn nhỏ nhất (lọc từng cái trên solver tạm), "Will attempt to recover by breaking constraint …", lời nhắc NSAutoresizingMaskLayoutConstraint khi có; ràng buộc bị bỏ được thử lại khi cây đổi.
- **SwiftUI đo view UIKit dựng bằng constraint** (patch `openswiftui/0037`): `PlatformViewHost` lấy `systemLayoutSizeFitting(layoutFittingCompressedSize)` theo trục không có intrinsic size khi view giữ constraint; view giữ constraint báo intrinsic size của subview đổi lên superview, nên SwiftUI đo lại khi nội dung lớn lên.
- **Mẫu:** app UIKit có trang "Layout" (`AutoLayoutPage.swift`) dựng toàn bằng constraint: anchor và API item/attribute, layout guide giữa hai nút bằng nhau, margin và safe area, baseline, priority (hộp cao 400 @250 co lại cho vừa), hugging/compression giữa hai nhãn, nhãn nhiều dòng; nút "Phóng to" đổi một `constant`. `check-sample.sh` có thêm `# expect frame "<chữ>" x:… y:… w:… h:…` để kiểm frame trong dump; app mẫu UIKit 114 điểm (16 mới), app kiểm tra representable 13 (2 mới), app SwiftUI 68.

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| Solver: kasuari sau một lớp số hoá biến, thêm/bớt ràng buộc theo id, giải lại từ đầu khi một ràng buộc bắt buộc thêm hỏng (simplex của kasuari có thể để bảng dở dang) | `crates/render/src/layout.rs` (mới), C ABI và test ở `src/ffi.rs`, `include/irisrun_render.h`, `swift/Sources/IrisRender/IrisRender.swift` (`LayoutSolver`), `Cargo.toml` |
| `NSLayoutConstraint`, `Attribute`, `Relation`, anchor, kiểm cặp attribute như UIKit, `description` | `Sources/OpenUIKit/NSLayoutConstraint.swift` |
| `UILayoutGuide`, guide UIKit giữ (safe area, margin, readable, bàn phím), `UIKeyboardLayoutGuide` | `Sources/OpenUIKit/UILayoutGuide.swift` (mới) |
| Engine: đồng bộ cây, ràng buộc của UIKit, biểu thức theo toạ độ tương đối, frame làm tròn theo pixel, hai lượt cho nhãn, xung đột, mơ hồ | `Sources/OpenUIKit/LayoutEngine.swift` (mới) |
| API Auto Layout của `UIView` (constraint, update constraints, margin, guide, kích thước vừa, anchor), `layoutSubviews()` gốc đặt frame, engine theo view khi thêm/bỏ view (bỏ view thì bỏ constraint từ ngoài vào nó, như UIKit) | `Sources/OpenUIKit/UIView.swift` |
| Margin của view controller, `updateViewConstraints`; giải trước layout trong commit; nhãn xuống dòng theo bề rộng layout, baseline của nhãn, nút, ô chữ | `UIViewController.swift`, `CALayer.swift`, `UILabel.swift`, `UIButton.swift`, `UITextField.swift` |
| `PlatformViewHost` đo view dựng bằng constraint | patch `openswiftui/0037` |
| 14 test: pin, căn giữa, tỉ lệ, chuỗi, bằng nhau, priority, hugging/compression, intrinsic size đổi, autoresizing thành constraint, safe area/margin/readable/bàn phím, guide của app, nhãn xuống dòng, kích thước vừa, baseline, log xung đột, update constraints, bỏ view, mơ hồ, màn 300 view | `Tests/OpenUIKitTests/AutoLayoutTests.swift` (mới) |
| `# expect frame` | `Scripts/check-sample.sh` |
| Trang "Layout" của app mẫu UIKit (16 điểm); representable dựng bằng constraint lớn lên khi nút trong nó đổi chữ (2 điểm) | `examples/ios-uikit/IrisUIKitSample/AutoLayoutPage.swift`, `ViewController.swift`, `session.txt`; `Tests/Apps/Representables` |

### Quyết định

- **Rust thay vì Swift:** hai port Swift chạy được trên Swift 6.4.1 (chế độ Swift 5) nhưng chậm 9–25 lần ở màn 300 view; port của compnerd còn kéo theo swift-collections. Crate Rust nằm sẵn trong thư viện mọi app đã link, C ABI chỉ 6 hàm. Chọn kasuari thay `cassowary` 0.3 vì nhanh gấp đôi và còn được giữ (cassowary 0.3 từ 2017); kasuari kéo theo hashbrown, foldhash, allocator-api2, thiserror (đều MIT/Apache-2.0, hashbrown và thiserror đã có trong `Cargo.lock`).
- **Đổi constant bằng bỏ rồi thêm ràng buộc** (solver không đổi hằng số tại chỗ): 84 µs ở màn 1.500 ràng buộc, đủ cho 60 Hz.
- **Priority là trọng số mũ** 10^(6p/1000): 250 → 32, 750 → 31.623, 999 → 1.000.000 (dưới mức bắt buộc của Cassowary). Một mức cao thắng vài mức thấp hơn nhiều; UIKit theo thứ tự từ điển (mức cao luôn thắng mọi số mức thấp hơn). Ghi `ponytail` trong code, nâng lên solver nhiều mức nếu app gặp.
- **Ràng buộc bị bỏ khi xung đột là cái được thêm sau**, như solver gặp nó; log liệt kê tập mâu thuẫn nhỏ nhất. UIKit cũng chọn một trong số đó, không hẳn cùng cái.
- **Frame chỉ đặt cho view không dịch autoresizing mask;** view dịch mask (container, view gốc của view controller) giữ frame của nó, ràng buộc của nó chỉ chép lại frame và mask (tuyến tính theo cỡ superview), nên trang dựng bằng frame không đổi pixel nào. Frame làm tròn theo pixel của màn hình như UIKit (97,5 → 97,67 ở 3x).
- **Engine ở view trên cùng của cây, tạo khi có constraint đầu tiên** (hoặc view có `requiresConstraintBasedLayout`): app chỉ dùng frame không tốn gì. Thêm cây có engine vào cây khác thì engine nhập vào; bỏ view thì nó có engine riêng cho constraint bên trong.
- **Margin:** `layoutMargins` trả margin hiệu lực, đã cộng safe area khi `insetsLayoutMarginsFromSafeArea` (view gốc ở iPhone 14: 47/16/34/16); view thường 8 điểm, view gốc của view controller theo `systemMinimumLayoutMargins` (0 trên dưới, 16 hai bên ở iPhone dọc). `readableContentGuide` là margin guide, rộng tối đa 672 và căn giữa. `keyboardLayoutGuide` là dải safe area dưới cùng vì bàn phím của Iris cao 0 điểm (2b).
- **Hệ khoảng cách "system spacing" là 8 điểm** cho mọi anchor; iOS tính khoảng cách giữa baseline theo font.

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Trang "Layout" lệch lên 146 điểm | Ràng buộc chỉ một item (khung của guide, autoresizing) cộng cả vị trí các view phía trên | Vị trí của ràng buộc một item tính trong toạ độ của view chứa nó; test mới đặt guide trong view lệch khỏi gốc |
| Ràng buộc với attribute margin không có tác dụng | Margin guide không được đưa vào engine khi chỉ attribute nhắc tới nó | Đưa margin guide của view vào khi constraint dùng attribute margin |
| Màn 300 view: layout đầu 420 ms, đổi constant 17 ms (debug) | `UIScreen.main.scale` đọc cả môi trường mỗi lần gọi (`HostOptions.scale`), view chung gần nhất dựng `Set`, mỗi lượt layout đặt lại frame của mọi subview | Engine giữ scale, đi lên theo độ sâu, chỉ đặt frame đổi: 51 ms và 1,4 ms (debug), 43 ms và 0,8 ms (release) |
| `kasuari` có thể để bảng simplex dở dang sau `UnsatisfiableConstraint` | Đường thêm bằng biến nhân tạo xoay bảng rồi trả lỗi không tối ưu lại | `LayoutSolver` giải lại các ràng buộc cũ khi thêm hỏng (chỉ khi có xung đột) |

### Số đo

Solver, màn 300 view lưới 30 × 10, 5 ràng buộc mỗi view (1.500), bản release, trung vị (`~/.cache/irisrun/p1-16/3a/bench-*`):

| Solver | License | Giải cả màn | Đổi một constant (bỏ + thêm) | Đổi bề rộng màn (edit variable) |
| --- | --- | --- | --- | --- |
| **kasuari 0.4.13 (Rust)** | MIT OR Apache-2.0 | **21–23 ms** | **84 µs** | **28–41 µs** |
| cassowary 0.3.0 (Rust) | MIT / Apache-2.0 | 43–70 ms | 150–260 µs | 100–118 µs |
| compnerd/cassowary (Swift, cần swift-collections) | BSD-3-Clause | 190–206 ms | 1,0–1,1 ms | 250–276 µs |
| CassowarySwift (Swift, ngừng từ 2019) | BSD-3-Clause | 558–615 ms | 3,5–3,6 ms | 1,0–1,1 ms |

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| OpenUIKit cả đường (release), 300 view, 1.530 constraint | layout đầu 40–43 ms, đổi constant 0,8 ms, đổi bề rộng màn 2,8 ms (300 frame đổi) | `bench-uikit`; trong `swift test` (debug) 46–51 ms và 1,4–1,6 ms |
| Test | 89 (14 mới): OpenUIKit 68, IrisBuild 13, ObjCRewriteTests 6, Swift5AppTests 1, IrisProtocol 1 | Rust: 2 test mới của render core |
| `check-sample.sh` | UIKit 114, representable 13, SwiftUI 68, cả chế độ stdout và frame | |
| Code | render core: `layout.rs` 111 dòng, C ABI và test ~75, header 28, Swift 48; OpenUIKit: `LayoutEngine.swift` 590, `NSLayoutConstraint.swift` 464 (từ 44), `UILayoutGuide.swift` 108, `UIView.swift` +298; patch `0037` +13; test 447; trang mẫu 135 | |

### Giới hạn và việc tiếp

- **Priority không theo thứ tự từ điển** (xem "Quyết định").
- **Chưa có:** visual format language (`constraints(withVisualFormat:)`), `anchorWithOffset(to:)`, `constraintsAffectingLayout(for:)`, `alignmentRectInsets` (alignment rect là frame), `forFirstBaselineLayout`/`forLastBaselineLayout`, `additionalSafeAreaInsets`, layout guide nội dung/khung của `UIScrollView` (constraint tới scroll view theo khung của nó), `UIView.constraints` không liệt kê ràng buộc content size như iOS, anchor không so bằng nhau theo item và attribute, RTL (leading là trái).
- **`hasAmbiguousLayout` tối thiểu:** đẩy từng biến của view bằng một mong muốn yếu hơn mọi priority xem nó có chạy không; `exerciseAmbiguityInLayout` đặt view tới khung khác đó một lần.
- **Bàn phím cao 0 điểm** nên `keyboardLayoutGuide` không bao giờ lên; cỡ màn hình vẫn cố định 390 × 844 (3b làm cỡ thứ hai).
- **Phần 3b:** `UIStackView`, `UIView.animate` tối thiểu để `layoutIfNeeded()` trong block animate frame, cỡ màn hình thứ hai, trang "Layout" ở cả hai cỡ ([bàn giao](../plans/p1-16-handoff.md)).

## Đợt 3b: `UIStackView`, `UIView.animate`, cỡ màn hình thứ hai (16/10)

Phần cuối của đợt 3, theo [bàn giao](../plans/p1-16-handoff.md) của 3a: stack view, animate tối thiểu để `layoutIfNeeded()` trong block animate frame, một cỡ màn hình thứ hai, và trang "Layout" ở cả hai cỡ.

### Kết luận

- **`UIStackView` dựng bằng constraint như UIKit, cùng tên:** `UISV-canvas-connection` (view đầu, cuối với mép, hay với margin guide khi `isLayoutMarginsRelativeArrangement`), `UISV-spacing`, `UISV-fill-equally`, `UISV-fill-proportionally`, `UISV-distributing` và `UISV-distributing-edge` (guide giữa hai view khi chia đều khoảng trống), `UISV-alignment`, `UISV-alignment-spanner` với `UISV-spanning-boundary` và `UISV-spanning-fit` (guide bao các view khi không fill), `UISV-hiding`, `UISV-ambiguity-suppression`. Stack view giữ chúng trong `constraints` của nó, guide trong `layoutGuides`. Đủ 5 distribution, 6 alignment (`top`/`bottom` là tên khác của `leading`/`trailing`), `spacing`, `setCustomSpacing(_:after:)`/`customSpacing(after:)`, `spacingUseDefault`/`spacingUseSystem`, margins-relative, baseline-relative; view xếp vào thôi dịch autoresizing mask; `removeArrangedSubview` giữ subview, `removeFromSuperview` bỏ view khỏi arrangement.
- **View ẩn không chiếm chỗ, không có spacing:** `UIView.isHidden` báo stack view cha (hook mới, chỉ khi giá trị đổi). View ẩn dài 0 (`UISV-hiding`, bắt buộc như UIKit) và nằm ngoài chuỗi spacing, nên các view còn lại khít lại kể cả khi `UISV-hiding` mâu thuẫn với chiều cao bắt buộc app đặt cho view đó (UIKit cũng log xung đột này).
- **`fillProportionally` theo intrinsic size:** `view.width == m × canvas.width` @999, 998… với m = intrinsic / (tổng intrinsic + spacing), như UIKit; stack view override `_intrinsicContentSizeInvalidated(forChildView:)` (giữ chữ ký) để làm lại tỉ lệ khi intrinsic size đổi.
- **`UIView.animate` tối thiểu:** `animate(withDuration:animations:)`, `…completion:`, `…delay:options:animations:completion:`, lò xo `usingSpringWithDamping:initialSpringVelocity:`, `UIView.AnimationOptions` (đường cong, `repeat`, `autoreverse` có tác dụng; option khác nhận nhưng chưa làm gì), `performWithoutAnimation`. Frame, transform, alpha, màu nền đổi trong block, cả frame do `layoutIfNeeded()` trong block đặt, thành animation của render core từ giá trị đang hiện tới giá trị mới; view nhận giá trị mới ngay như UIKit. Trong lúc delay màn vẫn hiện giá trị cũ (render core có thêm `fills_backwards`, như fill mode backwards của Core Animation). Chế độ kịch bản nhảy tới cuối, `completion(true)` chạy ở lượt sau của main queue, trước khi màn hình in; trên thiết bị sau delay + duration. Animation ngầm của switch, slider, progress view đi cùng đường.
- **Cỡ màn hình thứ hai:** `IrisScreen` của IrisHost có iPhone 14 (390 × 844 điểm, safe area 47/34, 3x; mặc định, như trước) và iPhone SE (3rd generation) (375 × 667, 20/0, 2x, không có home indicator). `IRISRUN_SCREEN=iphone-se` chọn máy khi app khởi động (đọc môi trường một lần; `HostOptions.scale` giờ cũng đọc một lần); `irisrun start` chuyển biến này vào runtime. Qua Device Protocol: `DeviceConfig.display` có cỡ (điểm) của một máy đã biết thì runtime đổi màn như scene đổi cỡ (scene của render core đổi cỡ, cửa sổ đang phủ màn cũ phủ màn mới, mọi thứ layout lại), rồi gửi lại `DeviceInfo` với tên máy và display mới. `UIScreen`, `UIWindow.safeAreaInsets` và mọi chỗ dùng chúng (cả app SwiftUI, vì safe area của nó lấy từ UIKit) theo máy đang chạy; không còn 390 × 844 hay 47/34 viết cứng. Patch `0034` của OpenSwiftUI không có hằng số nào (7b đã bỏ), nên OpenSwiftUI không đổi: vẫn 37 patch, stamp `e126d17d1ceb1242`.
- **Mẫu:** trang "Layout" của app mẫu UIKit có thêm hàng thẻ (`UIStackView` fillEqually; chạm thẻ thì nó ẩn trong một animation, "Đặt lại" hiện lại), chữ trong hộp priority là stack dọc căn giữa, "Phóng to" chạy `layoutIfNeeded()` trong `UIView.animate`. Chạy đúng ở cả hai cỡ: 124 điểm ở iPhone 14 (10 mới), kịch bản riêng `session-iphone-se.txt` 27 điểm ở iPhone SE. `check-sample.sh` chọn kịch bản theo `IRISRUN_SCREEN`; CI chạy thêm cỡ SE.

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| `UIStackView`: arrangement, ràng buộc và guide `UISV-…`, view ẩn, custom spacing, tỉ lệ theo intrinsic size | `Sources/OpenUIKit/UIStackView.swift` (mới) |
| Hook của `isHidden`; `UIView.animate` (4 overload), `performWithoutAnimation`, `UIView.AnimationOptions` | `UIView.swift` |
| `CALayer.irisAnimation` thay `irisAnimationDuration`: layer đổi hình học hay style trong block được đánh dấu; khi vẽ thì thêm animation frame, transform, opacity, màu nền; `IrisAnimationTiming` (thời gian, delay, đường cong, lặp, đảo chiều) | `CALayer.swift`, `UISwitch.swift`, `UISlider.swift`, `ProgressViews.swift` |
| Render core: `fills_backwards` (giá trị `from` hiện trong lúc delay); test Rust mở rộng | `crates/render/src/animation.rs`, `ffi.rs`, `include/irisrun_render.h`, `swift/Sources/IrisRender` |
| `IrisScreen` (tên máy, cỡ, safe area dọc, scale), `IRISRUN_SCREEN`; `HostOptions.scale` đọc một lần, mặc định theo máy ở chế độ kịch bản | `Sources/IrisHost/Window.swift` |
| `DeviceHost`: `DeviceInfo.model` theo máy; `DeviceConfig.display` đổi máy, đổi cỡ scene, gửi lại `DeviceInfo`; `screenDidChange` cho framework | `Sources/IrisHost/DeviceHost.swift` |
| `UIScreen.bounds`, `UIWindow.safeAreaInsets` theo `IrisScreen.current`; `UIWindow.screenDidChange(from:)` cho cửa sổ phủ màn mới; host UIKit nối callback | `UIScreen.swift`, `UIWindow.swift`, `Host.swift` |
| `irisrun start` chuyển `IRISRUN_SCREEN` vào lệnh chạy runtime | `crates/engine/src/ios.rs` |
| `check-sample.sh` chơi `session-<máy>.txt` khi có `IRISRUN_SCREEN` và file đó | `Scripts/check-sample.sh` |
| 7 test mới. Stack view (5): fill equally, fill theo hugging, view ẩn và hiện lại, stack view đặt bằng frame, đo một mình bằng `systemLayoutSizeFitting`; căn giữa, đầu, cuối, fill trong cột tự co và cột rộng hơn; custom spacing, `spacingUseDefault`, `spacingUseSystem`; equal spacing, equal centering, tự co khi không có bề rộng; proportionally và đổi intrinsic size; margins-relative, xung đột `UISV-hiding` với chiều cao bắt buộc, bỏ và chèn view; baseline của hàng và baseline-relative của cột. Animate (1): giá trị mới ngay, animation trên render core, `performWithoutAnimation` lồng trong block, completion trên thiết bị và trong kịch bản. Màn hình (1): safe area của SE, đổi sang iPhone 14 lúc chạy | `Tests/OpenUIKitTests/StackViewTests.swift` (mới), `AutoLayoutTests.swift` |
| App mẫu: hàng thẻ, chữ của hộp là stack dọc, `UIView.animate` + `layoutIfNeeded()`; `session.txt` +10 điểm; `session-iphone-se.txt` (mới) 27 điểm | `examples/ios-uikit` |
| CI: app mẫu UIKit ở cỡ SE | `.github/workflows/ios-sample.yml` |

### Quyết định

- **Ràng buộc như của UIKit, giữ ở stack view, dựng lại ngay:** mỗi khi arrangement đổi (thêm, bỏ, chèn view, thuộc tính, custom spacing, view ẩn hay hiện, intrinsic size khi proportionally), stack view bỏ hết ràng buộc và guide cũ rồi dựng lại, không so khác biệt (O(n) ràng buộc mỗi lần đổi). Dựng ngay thay vì đợi lượt update constraints vì `PlatformViewHost` (patch `0037`) chỉ đo bằng `systemLayoutSizeFitting` những view đã có constraint: stack view trả về từ `makeUIView` phải có constraint ngay (thấy khi đọc lại patch, trước khi gặp lỗi). Ràng buộc một item (`UISV-hiding`) cũng nằm ở stack view, không ở view được xếp (dùng `addConstraints`, không dùng `activate`).
- **View ẩn ra khỏi chuỗi spacing:** chuỗi spacing chỉ nối các view hiện. View ẩn dài 0 và đặt ở giữa khoảng spacing nó sẽ có (sau view hiện cuối thì sát view đó, trước view hiện đầu thì ở mép), như TZStackView (bản viết lại UIStackView có test so khung với UIKit). Engine bỏ ràng buộc bắt buộc thêm sau khi mâu thuẫn, nên khi app đặt chiều cao bắt buộc cho view bị ẩn thì `UISV-hiding` bị bỏ (UIKit thường bỏ ràng buộc của app); vì view ẩn ở ngoài chuỗi, các view khác vẫn khít lại, chỉ khung của view ẩn (không nhìn thấy) khác.
- **Guide thay view phụ:** spanner và khoảng chia đều là `UILayoutGuide` của stack view, như UIKit từ iOS 9.
- **Căn theo baseline:** hàng căn theo `firstBaseline`/`lastBaseline` có spanner bao mọi view, view có chữ cao nhất chạm mép trên; cột căn theo baseline coi như fill (tài liệu Apple: chỉ hợp lệ cho hàng).
- **Priority của stack view theo các mức UIKit dùng** (999, 998… cho tỉ lệ, 150 cho equal centering, 51 cho spanning fit, 25 cho ambiguity suppression). Với trọng số mũ của 3a, các cấu hình trong test và trang mẫu cho cùng khung như thứ tự từ điển của UIKit.
- **Animate đi qua cùng đường với animation ngầm của control:** block đặt `IrisAnimationTiming.current`; `CALayer.changed(_:)` đánh dấu layer đổi hình học hay style trong lúc đó; lần vẽ sau thêm animation của render core từ giá trị render layer đang giữ (giá trị vừa vẽ) tới giá trị mới. Không cần lớp presentation riêng.
- **`fills_backwards` ở render core thay vì hoãn block tới hết delay:** hoãn block thì `layoutIfNeeded()` chạy sau delay, còn lượt layout của commit chạy trước, không animation (mẫu `constant = …; animate(…, delay:) { layoutIfNeeded() }` rất hay gặp); Core Animation của UIKit cũng dùng fill backwards cho animation có delay. Là cờ riêng vì spinner (2a) cần giá trị model trong lúc delay.
- **Lò xo là đường cong ease-out**, bỏ damping và vận tốc đầu (`ponytail`): render core chưa có timing lò xo.
- **Completion:** kịch bản dùng `DispatchQueue.main.async`, chạy trước khi màn hình in như mọi việc lệnh xếp vào main queue; thiết bị dùng `asyncAfter(delay + duration)`, gấp đôi duration khi autoreverse, không gọi khi repeat; `finished` luôn true. Duration 0 thì không animation.
- **Máy là bảng 2 dòng** trong `IrisScreen` (tên Apple, cỡ điểm, safe area dọc, scale). `IRISRUN_SCREEN` nhận `iphone-14`, `iphone-se` (không phân biệt hoa thường); tên lạ thì in lỗi và chạy iPhone 14. Scale mặc định của chế độ kịch bản theo máy (SE 2x như máy thật, PNG 750 × 1334); thiết bị vẫn 2.
- **`DeviceConfig.display` đổi màn lúc chạy như scene đổi cỡ (iPad, xoay), không khởi động lại app:** giữ state, không cần bridge của CLI hiểu `DeviceConfig` (bridge chỉ chuyển tiếp), và đúng câu "áp dụng khác biệt theo cách của nền tảng" trong proto. Chỉ đổi khi cỡ (điểm, tính theo scale của config) trùng một máy đã biết; scale của frame giữ nguyên; cỡ khác (kể cả màn ngang) thì log và giữ màn. App đặt frame theo `UIScreen.main.bounds` lúc đầu thì không tự theo, như trên iOS khi scene đổi cỡ.
- **CLI không thêm tuỳ chọn:** `irisrun start` chuyển `IRISRUN_SCREEN` của môi trường vào runtime qua `env` (wrapper như `docker run` không chuyển môi trường), như cách `IRISRUN_SWIFT_RUNNER` chọn cách chạy Swift.
- **Kịch bản theo máy:** `session-<máy>.txt` cạnh `session.txt`; `check-sample.sh` chọn theo `IRISRUN_SCREEN`, không có file thì chơi `session.txt`.

### Chỗ khác iOS

- View được xếp ẩn ngay khi đặt `isHidden` trong block animate; UIKit giữ nó hiện tới hết animation co lại. Các view còn lại vẫn animate tới chỗ mới.
- `finished` luôn true; chưa có `beginFromCurrentState` (animation bắt đầu từ giá trị vẽ lần cuối, không từ giá trị đang hiện giữa animation); view đang animate vẫn nhận chạm (UIKit tắt chạm của chúng trừ khi có `allowUserInteraction`).
- Lò xo không vượt quá đích; transform animate theo từng phần tử ma trận (xoay co lại giữa chừng, giới hạn của render core từ 2a).
- Chữ của nhãn và nút không co giãn theo khung đang animate: chữ đặt theo khung cuối ngay (UIKit vẽ lại chữ ở cỡ cuối rồi kéo giãn ảnh trong lúc animate).
- `isBaselineRelativeArrangement`: view đầu và cuối vẫn chạm mép bằng cạnh; UIKit đặt baseline của chúng cách mép. `spacingUseSystem` là 8 điểm cả giữa baseline (UIKit tính theo font).
- Không chắc UIKit cho ra gì, chọn theo cách hợp lý nhất: `fill` khi nhiều view cùng hugging thấp nhất (solver chọn view giãn; UIKit chọn theo thứ tự trong `arrangedSubviews`); custom spacing sau một view ẩn (không dùng, khoảng sau view hiện trước nó được dùng); vị trí của view ẩn (khung dài 0, không nhìn thấy); lúc UIKit dựng ràng buộc (ở đây ngay khi đổi); `fillProportionally` khi stack view rộng hơn cỡ tự nhiên mà spacing khác 0 (phần lệch dồn vào view sau cùng, theo công thức của TZStackView, chưa đối chiếu trên iOS 17/18).

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Test: `UISV-hiding` không có trong `constraints` của stack view | `NSLayoutConstraint.activate` đặt ràng buộc một item vào chính item đó | Stack view `addConstraints` lên chính nó |
| Cảnh báo "non-'@objc' class method declared in extension cannot be overridden" | `open class func` trong extension | `public class func` (không ai override method lớp này) |
| Stack view trong representable sẽ không được đo | Ràng buộc dựng trong lượt update constraints, còn patch `0037` chỉ đo view đã có constraint | Dựng lại ngay khi arrangement đổi |
| Trong Device UI, ảnh chụp 120 ms sau khi chạm "Phóng to" chưa thấy animation | Device UI hiện frame chậm (khoảng 20 frame/giây ở máy dev), không phải lỗi của animation | Ghi mọi frame thiết bị gửi bằng client WebSocket: 18 frame trong 300 ms, khung đổi dần |

### Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| `swift test` | 96 test (7 mới): OpenUIKit 75, IrisBuild 13, ObjCRewriteTests 6, Swift5AppTests 1, IrisProtocol 1 | Màn 300 view (debug): layout đầu 65 ms, đổi constant 1,9 ms, như 3a |
| `cargo test -p irisrun-render` | 20 test (1 test mở rộng cho fill backwards) | `cargo fmt --check`, `clippy -D warnings` sạch |
| `check-sample.sh examples/ios-uikit` | 124 điểm (10 mới) ở chế độ stdout và frame | 67/72 PNG giống 3a: frame 1 (đèn timer chạy theo thời gian thật, đã biết từ 7a), 68–70 (trang Layout đổi), 71 (bước mới) |
| … với `IRISRUN_SCREEN=iphone-se` | 27 điểm (mới) ở hai chế độ | 5 PNG 750 × 1334 |
| App kiểm tra representable | 13 điểm, 12/12 PNG giống 3a | |
| `check-sample.sh` (SwiftUI) | 68 điểm, 97/97 PNG giống 3a từng pixel | |
| Một bước trên trang Layout | update STEP_UPDATE ms, vẽ và PNG STEP_DRAW ms | 3x ở iPhone 14, 2x ở SE |
| Device UI (iPhone 14) | Animation "Phóng to", ẩn thẻ, "Đặt lại": thiết bị gửi 18 frame trong 300 ms (60 frame/giây); Device UI hiện khoảng 20 frame/giây | Ảnh và frame ở `~/.cache/irisrun/p1-16/3b/live/` |
| Device UI (`IRISRUN_SCREEN=iphone-se`) | Ghi "iPhone SE (3rd generation) · iOS 18.0"; chạm trang Layout, "Phóng to", ẩn thẻ đúng | Khung máy của Device UI vẫn dáng iPhone 14, ảnh 750 × 1334 bị kéo giãn vào đó (`apps/web`, P1-28) |
| `DeviceConfig.display` (client WebSocket) | 750 × 1334 @2 → `DeviceInfo` "iPhone SE (3rd generation)", frame 750 × 1334, trang layout lại; 1170 × 2532 @3 → iPhone 14, frame 780 × 1688; 2532 × 1170 (ngang) → log, giữ màn | |
| Code | `UIStackView.swift` 293 dòng; `UIView.swift` +91, `CALayer.swift` +43, IrisHost +73, `UIScreen`/`UIWindow`/`Host` +18; render core +28; CLI +7; test +288; trang mẫu +42, kịch bản SE 49 dòng | |

### Giới hạn và việc tiếp

- **Phần còn lại của `UIView.animate` (đợt 4):** `transition(with:…)`, `transition(from:to:…)`, keyframe, `UIViewPropertyAnimator`, `beginFromCurrentState` (cần đọc giá trị đang hiện từ render core), chạm trong lúc animate, view ẩn ở cuối animation, timing lò xo, `areAnimationsEnabled`, `CAAnimation`.
- **Đổi màn lúc chạy:** chưa xoay, chưa `viewWillTransition(to:with:)` và trait collection; Device UI chưa gửi `DeviceConfig` (P1-28); scale của frame không đổi theo config.
- **Stack view:** các mục "Chỗ khác iOS"; dựng lại toàn bộ mỗi lần đổi (stack rất lớn thì nên so khác biệt).

## Đợt 3: tổng kết

Tiêu chí của plan: "Màn dựng toàn bằng constraint hiện như iOS ở 2 cỡ màn hình". **Đạt.**

- **Engine (3a):** solver Cassowary kasuari trong render core; `NSLayoutConstraint`, anchor, `UILayoutGuide`, safe area, margin, readable content, keyboard guide; intrinsic size, hugging, compression; autoresizing mask thành constraint; `updateConstraints`, `systemLayoutSizeFitting`; nhãn nhiều dòng hai lượt; baseline; log xung đột như UIKit; SwiftUI đo view UIKit dựng bằng constraint.
- **Trên engine (3b):** `UIStackView` bằng ràng buộc `UISV-…`; `UIView.animate` với `layoutIfNeeded()` trong block; iPhone SE cạnh iPhone 14, chọn bằng `IRISRUN_SCREEN` hay `DeviceConfig.display`.
- **Bằng chứng:** trang "Layout" của app mẫu UIKit dựng toàn bằng constraint (anchor, API item/attribute, layout guide, margin, safe area, priority, hugging/compression, nhãn nhiều dòng, baseline, hai stack view) và không có số nào theo cỡ màn hình. `# expect frame` kiểm khung của nó ở iPhone 14 (`session.txt`) và iPhone SE (`session-iphone-se.txt`, 27 điểm): ở SE cùng cấu trúc với bề rộng 343 điểm, nút rộng 165,5, thẻ 109, hộp co lại vừa chỗ, chân trang cách đáy 12 điểm vì không có home indicator. PNG cả hai cỡ như iOS. Trong Device UI, cả hai cỡ chạm được, animation của `layoutIfNeeded()` và của stack view chạy 60 frame/giây ở thiết bị.
- 96 test, app mẫu UIKit 124 điểm (iPhone 14) và 27 điểm (SE), app kiểm tra representable 13, app mẫu SwiftUI 68 với PNG giống từng pixel.
- **Còn lại:** view controller (đợt 4, kế tiếp; xem [bàn giao](../plans/p1-16-handoff.md)), bảng (đợt 5), storyboard (đợt 6); priority theo thứ tự từ điển (chờ app cần); các giới hạn ở mục "Giới hạn và việc tiếp" của 3a và 3b.
