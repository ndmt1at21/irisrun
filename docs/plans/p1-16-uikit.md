# Kế hoạch P1-16 · UIKit cơ bản (đã duyệt 15/10/2026)

15/10/2026. Task XL: "UIView, UIViewController, UINavigationController, UILabel, UIButton, UIImageView, UIStackView, UIScrollView, UITableView, Auto Layout (Cassowary), UIViewRepresentable, nạp storyboard/XIB". Tiêu chí: app UIKit mẫu chạy được. Plan tổng ([plan-and-stack.md](../plan-and-stack.md), lớp 3) đã chốt: UIKit tự viết, Auto Layout theo thuật toán Cassowary. Tài liệu này chi tiết hoá cách làm và chia đợt.

## Bối cảnh

- **Trên Linux không có UIKit, cũng không có ObjC interop** ([P0-07](../reports/p0-07-objc-linux.md)): `@objc`, `#selector`, `@IBOutlet`, `@IBAction`, KVO đều là lỗi compile. Trong corpus, 44/65 app dùng `#selector`, 42 dùng `@objc`, 15 dùng `@IBOutlet`. UIKit mà không có target/action thì gần như không app nào chạy, nên P1-16 phải đi cùng bước viết lại source mà P0-07 đề xuất (6–10 pw), hiện chưa có task riêng.
- **Mức dùng trong corpus** ([P0-08](../reports/p0-08-ios-corpus.md)): `UIView` 39 app, `UIViewController` 38, `UIViewRepresentable` 31, `UIViewControllerRepresentable` 31, `UIHostingController` 28. Phần lớn app SwiftUI dùng UIKit qua representable và các kiểu không phải view (`UIColor`, `UIFont`, `UIImage`, `UIApplication`, `UIScreen`), nên phần "kiểu không phải view" và interop với SwiftUI có giá trị sớm hơn app UIKit thuần.
- **Đã có để dùng lại:** render core (layer, chữ SkParagraph, ảnh, clip, bóng, transform), host IrisProtocol và input (`IrisDevice`, `DeviceInput`, IME), asset catalog (`IrisAssetCatalog`), pipeline build (`irisrun-ios-build`, `-module-alias`), runner `check-sample.sh` + `session.txt`.

## Kiến trúc đề xuất

1. **OpenUIKit** là một target Swift mới trong `runtimes/ios`, app `import UIKit` thì `-module-alias UIKit=OpenUIKit` như SwiftUI. Không phụ thuộc OpenSwiftUI; OpenSwiftUI phụ thuộc nó để có `UIViewRepresentable` và `UIHostingController`.
2. **Cây view thật, vẽ bằng render core:** `UIView` giữ một `CALayer` (tự viết, chỉ phần UIKit cần: frame/bounds/position/anchorPoint, transform affine, backgroundColor, cornerRadius, masksToBounds, border, shadow, opacity, sublayers, contents là ảnh). Mỗi frame, cây `CALayer` được đẩy sang layer tree của render core (cùng API mà `DisplayListLayerRenderer` của OpenSwiftUI đang dùng), chỉ phần đổi.
3. **Một host chung:** `UIApplicationMain`/`@main` + `UIApplicationDelegate` + `UISceneDelegate` chạy trên RunLoop, dùng lại `IrisDevice` (frame, DeviceInfo, AppStatus) và `DeviceInput` (chạm, IME, phím). Chạm đi qua `UIWindow.hitTest` → `UIResponder.touchesBegan…` → `UIGestureRecognizer`; chữ đi vào `UITextInput` của `UITextField`/`UITextView` (dùng lại logic `TextEditingState` của P1-15).
4. **Layout:** frame + `autoresizingMask` + `layoutSubviews`, và Auto Layout trên một solver Cassowary (port Swift có sẵn, xem Stack). `intrinsicContentSize`, hugging/compression, priority, `safeAreaLayoutGuide`, `layoutMargins`, `UIStackView` dựng bằng constraint như UIKit.
5. **Chữ:** `UILabel`/`UITextField`/`UITextView` đo và vẽ bằng paragraph của render core như Text của OpenSwiftUI; `NSAttributedString` với các key của UIKit.
6. **Target/action không cần ObjC:** `Selector` là giá trị mang tên và một closure gọi method; bước viết lại SwiftSyntax trong `irisrun-ios-build` đổi `#selector(T.m(_:))`, bỏ `@objc`/`@objcMembers`, sinh bảng outlet và action cho mỗi class có `@IBOutlet`/`@IBAction`, bảng property cho KVC/KVO.
7. **Storyboard và XIB:** đọc XML bằng IBDecodable, dựng view controller và view theo `customClass` (tìm kiểu Swift theo tên qua bảng sinh lúc build), gán thuộc tính, constraint, nối outlet/action/segue qua bảng ở mục 6.
8. **Interop SwiftUI:** `UIViewRepresentable`/`UIViewControllerRepresentable` thành một item platform view trong display list của OpenSwiftUI, renderer gắn layer của `UIView` vào đúng chỗ; `UIHostingController.view` là một `UIView` chứa layer gốc của OpenSwiftUI. Chạm được chia theo hit-test của bên chứa.

## Stack

| Phần | Chọn | License | Ghi chú |
| --- | --- | --- | --- |
| UIKit | Tự viết (OpenUIKit) | — | Theo plan tổng. [UIKit-cross-platform](https://github.com/flowkey/UIKit-cross-platform) (MIT, của flowkey, vẽ bằng SDL_gpu, chạy Android và macOS, không có Linux) dùng làm tham khảo cho vật lý cuộn và gesture recognizer, không lấy làm nền vì vẽ, input, chữ và vòng đời đều phải đi qua render core và IrisProtocol |
| Cassowary | [kasuari](https://crates.io/crates/kasuari) 0.4 (crate Rust, fork của `cassowary-rs` do nhóm ratatui giữ) trong render core, qua C ABI `iris_layout_*` | MIT OR Apache-2.0 | Chọn ở đợt 3a bằng đo màn 300 view, 1.500 ràng buộc: giải cả màn 21–23 ms, đổi một constant 84 µs. `cassowary` 0.3 (Rust) chậm gấp đôi; CassowarySwift và compnerd/cassowary (Swift, BSD-3-Clause) chậm 9–25 lần. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 3a" |
| Storyboard/XIB | [IBDecodable](https://swiftpackageregistry.com/IBDecodable/IBDecodable) 0.6.1 + SWXMLHash | MIT | Chỉ dùng lúc chạy để đọc XML; có thể chuyển sang lúc build nếu chậm |
| Viết lại source | swift-syntax | Apache-2.0 | Trong `irisrun-ios-build` (P1-12), theo bảng việc mục A của P0-07 |

## Chia đợt

Mỗi đợt có patch/commit riêng, thêm vào app mẫu UIKit mới `examples/ios-uikit` (P1-33) và `session.txt` của nó, chạy bằng `check-sample.sh` và trong CI.

| Đợt | Nội dung | Xong khi |
| --- | --- | --- |
| 1. Lõi | Target OpenUIKit, module alias, `UIApplication`/delegate/scene, `UIWindow`, `UIView`, `CALayer`, `UIColor`, `UIFont`, `UIImage` (asset catalog), `UIScreen`, vẽ qua render core, host IrisProtocol, chạm → responder, `UIControl` target/action (closure), `UITapGestureRecognizer`, `UIPanGestureRecognizer`, `UILongPressGestureRecognizer` | App tạo view bằng code (frame) hiện đúng, chạm đổi màu được, chạy trong Device UI |
| 2. Control và chữ | `UILabel`, `UIButton` (+ `Configuration`), `UIImageView`, `UITextField`, `UITextView` (IME như P1-15), `UISwitch`, `UISlider`, `UISegmentedControl`, `UIActivityIndicatorView`, `UIProgressView`, `UIScrollView` (cuộn, đà, nảy), `UIAlertController` | Form đăng nhập UIKit gõ tiếng Việt được |
| 3. Auto Layout | `NSLayoutConstraint`, anchor, priority, `intrinsicContentSize`, hugging/compression, `safeAreaLayoutGuide`, `layoutMargins`, `UIStackView`, `translatesAutoresizingMaskIntoConstraints`, `layoutIfNeeded` trong animation | Màn dựng toàn bằng constraint hiện như iOS ở 2 cỡ màn hình |
| 4. View controller | Vòng đời (`viewDidLoad`…`viewDidAppear`), `UINavigationController` (thanh, push/pop, back), `UITabBarController`, `present`/`dismiss` (sheet, full screen), child view controller, `UIView.animate` | App nhiều màn điều hướng được |
| 5. Bảng | `UITableView` (data source/delegate, tái dùng cell, style mặc định của cell, section, swipe xoá, `reloadData`), `UICollectionView` với flow layout cơ bản | Danh sách 1000 dòng cuộn mượt |
| 6. Viết lại source và IB | Bước SwiftSyntax (selector, `@objc`, outlet/action, KVC/KVO), bộ nạp storyboard/XIB, `Main.storyboard` trong Info.plist, segue | App mẫu dựng bằng storyboard chạy không sửa code |
| 7. Interop SwiftUI | `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController`, chia chạm giữa hai bên | Màn SwiftUI nhúng `UIView` và ngược lại |

Đề xuất làm đợt 1 → 2 → 7 → 3 → 4 → 5 → 6: đợt 7 sớm vì 31 app SwiftUI dùng representable; đợt 6 cuối vì cần SwiftSyntax trong pipeline, có thể tách thành task riêng (đề xuất P1-35 "Viết lại `@objc`/`#selector`/KVO/IB bằng SwiftSyntax", 6–10 pw theo P0-07) và làm song song.

## Ngoài phạm vi P1-16

`UICollectionView` compositional layout và diffable data source, hệ thống chữ đầy đủ, các control còn lại (E2-01); `UIGraphicsImageRenderer`/`draw(_:)` bằng Core Graphics (cần CoreGraphics vẽ được, chưa có task); code ObjC thật (E2-03); dark mode và Dynamic Type.

## Rủi ro

- **Diện API rất rộng:** làm theo thứ tự mức dùng trong corpus, báo API thiếu qua P1-18.
- **Hai hệ vẽ chung một cảnh:** OpenSwiftUI và OpenUIKit cùng đẩy layer vào render core; cần một chủ sở hữu cây layer gốc và thứ tự cập nhật (đợt 7).
- **Cassowary bằng Swift có thể chậm** với màn nhiều constraint: đo ở đợt 3, nếu chậm thì chuyển solver sang Rust trong render core (crate `cassowary`, MIT/Apache-2.0) qua C ABI.
- **Bước viết lại source** đụng mọi file Swift của app: phải giữ vị trí dòng để lỗi compile và stack trace vẫn chỉ đúng code của dev.

## Quyết định

Ngày 15/10/2026 người dùng duyệt plan ("tiếp tục triển khai theo plan"):

1. Kiến trúc như trên, thứ tự đợt 1 → 2 → 7 → 3 → 4 → 5 → 6.
2. Bước viết lại `@objc`/`#selector`/IB tách thành task P1-35 (mặc định của đề xuất, người dùng chưa chọn khác). Đợt 6 của P1-16 còn bộ nạp storyboard/XIB, `Main.storyboard` và segue, dùng bảng outlet/action do P1-35 sinh.

## Tiến độ

Đợt 1 chia hai phần cho hai subagent nối nhau:

- **1a. Nền:** target OpenUIKit, host dùng chung với OpenSwiftUI, `UIApplication`/scene/`UIWindow`/`UIView`/`CALayer`/`UIColor`/`UIScreen`, `UIViewController` tối thiểu, vẽ qua render core, chế độ stdout và thiết bị, module alias trong pipeline, app mẫu `examples/ios-uikit`. **Xong (15/10):** app mẫu đạt 17 điểm, chạy trong Device UI; app SwiftUI vẫn đạt 54 điểm, PNG giống từng pixel. Xem [báo cáo](../reports/p1-16-uikit.md) và [bàn giao cho 1b](p1-16-handoff.md). Quyết định chính:
  - Host chung là target `IrisHost` (scene, Device Protocol, lệnh kịch bản, PNG); OpenSwiftUI dùng nó qua patch `0029`.
  - OpenUIKit lấy kiểu CoreGraphics từ checkout OpenCoreGraphics của OpenSwiftUI, để file import cả hai không trùng `CGAffineTransform`. Vì vậy các target OpenKit của `runtimes/ios` chỉ có trên Linux, khi có checkout. OpenUIKit tự có `CALayer` và `CGColor`.
  - Alias `UIKit=OpenUIKit`, `CoreGraphics=OpenCoreGraphics`, `QuartzCore=IrisQuartzCore` (module re-export OpenUIKit, vì compiler không cho hai alias trỏ vào một module).
  - `@UIApplicationMain` làm compiler crash trên Linux, nên pipeline đổi nó thành `@main` trên cùng dòng. Swift không gọi được `init()` không `required` của class biết theo tên, nên pipeline thêm factory `_IrisInstantiable` ở cuối file cho class adopt delegate của app hay scene. Pipeline cũng ghi Info.plist (đã thay `$(…)`) cạnh file chạy, nơi `Bundle.main` đọc.
- **1b. Chạm:** responder và `UITouch`/`UIEvent`, `UIControl` + `UIAction`, `Selector` theo tên với bảng method (P1-35 điền), tap/pan/long press recognizer, `UIImage` từ asset catalog, `UIFont`, CI, báo cáo đợt 1. **Xong (15/10), đợt 1 xong:** app mẫu đạt 26 điểm ở cả hai chế độ, trong Device UI chạm đổi màu và kéo di chuyển view; app SwiftUI vẫn đạt 54 điểm, 81 PNG giống từng pixel; 35 test. Xem [báo cáo](../reports/p1-16-uikit.md) và [bàn giao cho đợt 2](p1-16-handoff.md). Quyết định chính:
  - Module mới `IrisObjC` (chỉ Foundation) có `Selector`, bảng method `_IrisMethods`, `responds(to:)`/`perform` và API Foundation nhận selector; OpenUIKit re-export nó, pipeline import ngầm nó vào mọi file của app. Bảng method đăng ký lúc chạy, theo hợp đồng ở mục "Hợp đồng cho P1-35" bên dưới.
  - Gesture recognizer và chạm theo thứ tự của UIKit (recognizer trước view, phân xử, giữ và huỷ chạm của view); control giữ tap của nó trước recognizer của view cha.
  - Bộ đọc asset catalog chuyển sang IrisHost (patch `openswiftui/0030`); `CGImage` của OpenCoreGraphics thành `open` (patch `opencoregraphics/0001`) để `UIImage.cgImage` mang ảnh tới `CALayer.contents`.
  - App mẫu chỉ dùng API có thật trên iOS 17, nên chưa có gesture recognizer (cần `#selector`); recognizer được kiểm bằng unit test và app thử ngoài repo, móc sẵn trong app mẫu sau `#if canImport(ObjectiveC)`.

**Thứ tự sau đợt 1 (orchestrator, 15/10):** làm P1-35 trước đợt 2, rồi đợt 2 → 7 → 3 → 4 → 5 → 6. Chạy nối tiếp, không song song: P1-35 sửa `irisrun-ios-build`, mà mọi lần chạy `check-sample.sh` đều build lại tool này và dùng chung thư mục build trong `~/.cache/irisrun/p0-05`, nên hai agent chạy cùng lúc sẽ giẫm lên nhau. Làm P1-35 trước để app mẫu của các đợt sau viết được như app thật (`addTarget(_:action:for:)` với `#selector`, gesture recognizer, `@IBAction`).

**P1-35 (16/10):** xong, xem [báo cáo](../reports/p1-35-objc-rewrite.md). `irisrun-ios-build` viết lại `@objc`/`#selector`/IB/KVO bằng SwiftSyntax theo hợp đồng dưới đây (đã cập nhật); app mẫu dùng selector, gesture recognizer và `@IBAction`, `session.txt` 34 điểm. Timer của gesture recognizer trước đó chạy ngay khi RunLoop chạy (lỗi của Foundation trên Linux), đã sửa.

**Đợt 2 chia hai phần.** **2a. Hiển thị và control (16/10):** `UILabel`, `NSAttributedString` với key của UIKit và đo chữ, `UIImageView`, `UIButton` (+ `Configuration`), `UISwitch`, `UISlider`, `UISegmentedControl`, `UIActivityIndicatorView`, `UIProgressView`, tint thừa kế; app mẫu chia trang Touch/Controls/Form bằng `UISegmentedControl`. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 2a" và [bàn giao cho 2b](p1-16-handoff.md). Quyết định chính:
  - Chữ của view vẽ qua render core vào một layer render riêng của layer view (`CALayer.irisDrawing`), sau `display()` → `draw(_:)` như UIKit; đo và vẽ cùng `IrisText`.
  - Render core có thêm màu nền của run chữ và tô màu ảnh (ảnh template); control animation bằng animation của render core, chỉ ở chế độ thiết bị.
  - Kiểu public có actor là `@preconcurrency @MainActor`, để app Swift 5 gọi chúng từ `deinit` như trên iOS.
  - `addAttribute(s)` của Foundation trên Linux dừng app với giá trị là object; `irisrun-ios-build` đổi lời gọi sang `_irisAddAttribute(s)` của IrisObjC.
  - `contentsGravity` theo trục y đi lên của Core Animation (`top` hiện ở đáy), `UIView.contentMode` đổi trên/dưới khi đặt gravity, như UIKit.

**2b. Nhập chữ, cuộn, alert (16/10):** xong, **đợt 2 xong**: form đăng nhập UIKit gõ tiếng Việt được ở chế độ kịch bản và trong Device UI (sự kiện IME thật của Chromium). `UITextField`, `UITextView`, first responder và notification bàn phím, `UIScrollView`, `UIAlertController` với `present`/`dismiss` tối thiểu; app mẫu UIKit 82 điểm, app mẫu SwiftUI 54 điểm (81 PNG giống từng pixel), 69 test. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 2b" và "Đợt 2: tổng kết", và [bàn giao cho đợt 7](p1-16-handoff.md). Quyết định chính:
  - Trạng thái sửa chữ của P1-15 chuyển sang `IrisHost` (`TextEditingState`, patch `openswiftui/0031`), có thêm vùng chọn; marked text nằm trong chữ như `UITextInput`, binding của SwiftUI vẫn chỉ nhận chữ đã commit. Input của host tới first responder qua API của UIKit (`insertText`, `setMarkedText`, `deleteBackward`, Return là `insertText("\n")`).
  - OpenSwiftUI phụ thuộc và re-export OpenUIKit (patch `0032`), như SwiftUI re-export UIKit trên iOS; `UIKeyboardType`, `UITextContentType` chỉ còn ở OpenUIKit; tên của OpenUIKit hiện trong mọi file của OpenSwiftUI nên `CALayer`, `NSUnderlineStyle` của shim được ghi kèm module.
  - Bàn phím cao 0 điểm ở đáy màn hình (Device UI gõ bằng bàn phím của máy tính, như iPhone có bàn phím rời), notification vẫn gửi đủ theo thứ tự của UIKit.
  - Delegate được hỏi với khoảng UTF-16 tính từ trạng thái trước và sau; `editingChanged` báo cả khi commit đúng chữ đang soạn; ô mật khẩu sửa lại thì thay hết; handler của alert chạy sau khi alert đóng.
  - Cuộn theo số của UIKit (rubber band 0,55, đà theo `decelerationRate`, lò xo 0,4 s), giữ chạm cho nội dung 0,15 s; chế độ kịch bản nhảy tới cuối, thiết bị chạy timer 60 Hz. Zoom ngoài phạm vi.

**Đợt 7 chia hai phần.** **7a. Một host, một cảnh, `UIHostingController` (16/10):** xong. App SwiftUI chạy như trên iOS: `App.main()` qua `UIApplicationMain` của OpenUIKit, app delegate và scene delegate của SwiftUI, cửa sổ có gốc là `UIHostingController`; host stdout/thiết bị riêng của SwiftUI không còn dùng. UIKit giữ root của cảnh, SwiftUI vẽ vào layer của hosting view. `UIHostingController` làm gốc cửa sổ và làm view controller con; chạm và bàn phím chia theo hit-test và first responder của UIKit. App mẫu SwiftUI không sửa dòng nào, 54 điểm, 81 PNG giống từng pixel; app mẫu UIKit thêm trang SwiftUI, 98 điểm; 73 test. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 7a" và [bàn giao cho 7b](p1-16-handoff.md). Quyết định chính:
  - Một host theo hướng iOS (`IrisAppDelegate`, `IrisSceneDelegate`, patch `openswiftui/0033`); `runStdoutApp` chỉ còn cho app tự xin renderer stdout qua SPI.
  - `_UIHostingView` viết mới cho Linux theo `StdoutRendererHost`, render khi layout; display list vẽ vào `CALayer._irisContentLayer` của nó; `LayerCommit` chỉ gỡ layer cửa sổ nó gắn.
  - First responder của UIKit là nguồn sự thật cho focus: ô SwiftUI được focus thì hosting view thành first responder (`DeviceInputHandler` nhận chữ), bị resign thì SwiftUI bỏ focus.
  - Đồng hồ SwiftUI trong kịch bản: settle 60 Hz ảo như trước, cộng thời gian `hold` (`irisScriptTime`); trên thiết bị theo uptime.
  - Hosting view gốc của app SwiftUI bỏ safe area (`safeAreaRegions = []`) để giữ layout và PNG cũ; `irisrun-ios-build` ghi scene manifest như Xcode (`UIApplicationSceneManifest_Generation`); `@UIApplicationDelegateAdaptor` tạo delegate qua `_IrisInstantiable`.

**7b. UIKit trong SwiftUI (16/10):** xong, **đợt 7 xong** (màn SwiftUI nhúng `UIView` và ngược lại). `UIViewRepresentable`, `UIViewControllerRepresentable` với vòng đời, kích thước và chạm như iOS; app SwiftUI có safe area của iOS; app là thư mục có scene manifest. App mẫu SwiftUI có màn "UIKit", 68 điểm (14 mới); app kiểm tra `runtimes/ios/Tests/Apps/Representables` 11 điểm; app mẫu UIKit 98 điểm; 75 test. Patch `openswiftui/0034`–`0036`. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 7b" và "Đợt 7: tổng kết", và [bàn giao cho đợt 3](p1-16-handoff.md). Quyết định chính:
  - Mở code representable của upstream cho Linux (vòng đời trong `PlatformViewChild` chạy được trên Compute); chỉ `PlatformViewHost` và responder của nó viết mới.
  - View UIKit là subview của hosting view; renderer để một "layer chỗ" ở vị trí của item trong cây layer của display list, layer render của view gắn vào đó (`CALayer._irisOwnerLayer`), nên thứ tự vẽ, opacity, clip, transform, cuộn đều đúng.
  - Hit-test do responder của SwiftUI quyết (một `UIViewResponder` cho mỗi representable): nội dung SwiftUI ở trên giữ chạm, còn lại UIKit hit-test bên trong view.
  - Kích thước theo luật của upstream: `sizeThatFits(_:uiView:context:)`, rồi intrinsic size và hugging/compression (OpenUIKit có `UILayoutPriority`); `invalidateIntrinsicContentSize()` báo superview qua `_intrinsicContentSizeInvalidated(forChildView:)`, hook Auto Layout cũng sẽ dùng.
  - Safe area như iOS cho app SwiftUI; scroll view tràn dưới thanh theo trục cuộn, lớp trình bày phủ cả màn hình; `rotationEffect` được vẽ và ellipse bắt đầu như Core Graphics (lỗi lộ ra khi vẽ rotation).
  - Phần OpenSwiftUI kiểm bằng app thư mục chạy qua `check-sample.sh` (package `runtimes/ios` không phụ thuộc được OpenSwiftUI), cũng là phép thử cho manifest của app thư mục.

**Đợt 3 chia hai phần.** **3a. Engine Auto Layout (16/10):** xong. Solver Cassowary (crate Rust kasuari trong render core, qua C ABI), `NSLayoutConstraint` và anchor như UIKit, `UILayoutGuide`, safe area, margin, readable content và keyboard guide, intrinsic size với hugging/compression, autoresizing mask thành constraint, `updateConstraints`, `systemLayoutSizeFitting`, nhãn nhiều dòng hai lượt, baseline, log xung đột như UIKit; `PlatformViewHost` đo view UIKit dựng bằng constraint (patch `openswiftui/0037`). App mẫu UIKit có trang "Layout" dựng toàn bằng constraint, 114 điểm (16 mới, `# expect frame` kiểm frame); app kiểm tra representable 13 điểm; app SwiftUI 68 điểm, 97 PNG giống từng pixel; 89 test. Xem [báo cáo](../reports/p1-16-uikit.md) mục "Đợt 3a" và [bàn giao cho 3b](p1-16-handoff.md). Quyết định chính:
  - Solver chọn bằng đo: Rust nhanh gấp 9–25 lần port Swift ở màn lớn, không thêm dependency SwiftPM; kasuari thay `cassowary` 0.3 vì nhanh gấp đôi và còn được giữ.
  - Engine ở view trên cùng của cây (cửa sổ), vị trí tương đối như UIKit; giải trong commit trước layout và trong `layoutIfNeeded()`; `layoutSubviews()` gốc đặt frame cho view không dịch autoresizing mask, view dịch mask giữ frame (trang dựng bằng frame không đổi pixel nào).
  - Priority là trọng số mũ, không theo thứ tự từ điển như UIKit (`ponytail`); ràng buộc mâu thuẫn bị bỏ là cái thêm sau, log liệt kê tập mâu thuẫn nhỏ nhất.
  - `layoutMargins` trả margin đã cộng safe area; view gốc của view controller theo margin tối thiểu của hệ thống (0/16); bàn phím 0 điểm nên keyboard guide là dải safe area dưới cùng.
- **3b** (`UIStackView`, `UIView.animate` với `layoutIfNeeded`, cỡ màn hình thứ hai): chưa làm.

## Hợp đồng cho P1-35 (selector và bảng method)

Phần chạy của target/action có từ 1b. P1-35 (xong 16/10, [báo cáo](../reports/p1-35-objc-rewrite.md)) sinh code theo hợp đồng này bằng bước viết lại chỉ nhìn cú pháp (SwiftSyntax, `Sources/IrisBuild/ObjCSources.swift`), giữ nguyên số dòng của app: mỗi dòng của app sửa tại chỗ, code sinh thêm nằm sau dòng cuối. Mục này mô tả hợp đồng như đã làm.

**Iris có (module `IrisObjC` trong `runtimes/ios`, nằm trong product `OpenUIKit`):**

- `Selector`: một tên kiểu Objective-C (`"tapped:"`), tạo bằng `Selector("…")` hay string literal, `Hashable`, `description` là tên đó. `NSStringFromSelector`, `NSSelectorFromString`.
- `_IrisMethods.register(_ cls: AnyClass, _ methods: [Selector: _IrisMethods.Method])`: thêm method vào bảng của một class, method cùng tên thì thay (như category). `Method.init` nhận tham chiếu method chưa áp dụng có 0 tới 3 tham số, giá trị trả về tuỳ ý. Tra cứu đi lên lớp cha (`_getSuperclass`), nên lớp con thừa kế và override như Objective-C. Tham số thừa bị bỏ, thiếu thì là nil; tham số `Any` nhận nil như thunk `@objc` của Swift.
- `_irisRegister(_:)`: chạy hàm đăng ký của một class. Hàm đó nằm trong extension của class nên gắn main actor với class của UIKit, còn bảng được đăng ký trên luồng tạo selector đầu tiên; gọi được vì nó chỉ điền bảng.
- `NSObjectProtocol`: `responds(to:)`, `perform(_:)`, `perform(_:with:)`, `perform(_:with:with:)`. Kết quả là object thì được giữ tới hết vòng RunLoop chính, thay cho autorelease pool. Gửi selector không có trong bảng thì app dừng với thông báo như iOS: `-[Module.Class tapped:]: unrecognized selector sent to instance 0x…`. `_irisOptional(object, selector)` trả object nếu nó có method cho selector, không thì nil.
- KVC: `NSObject.value(forKey:)` (getter `key`, rồi `isKey`), `setValue(_:forKey:)` (setter `setKey:`), `value(forKeyPath:)`, `setValue(_:forKeyPath:)`; key không có accessor trong bảng thì app dừng như iOS (`…: this class is not key value coding-compliant for the key …`). `UserDefaults` đọc và ghi theo key như trên Darwin.
- KVO: `observe(_:options:changeHandler:)` của mọi `NSObject`, `NSKeyValueObservation` (hết khi `invalidate()` hay khi bị giải phóng), `NSKeyValueObservingOptions` (`.new`, `.old`, `.initial`; `.prior` chưa gửi), `NSKeyValueObservedChange`, và `_irisDidChangeValue(_:_:from:)` mà property báo thay đổi gọi. Key path phải bắt đầu ở class khai báo property (`\.count` trên một `Counter`).
- Foundation: `Timer(timeInterval:target:selector:userInfo:repeats:)`, `Timer.scheduledTimer(timeInterval:target:selector:userInfo:repeats:)` (giữ `userInfo`; bản init thì không giữ được vì Foundation trên Linux không cho đặt), `perform(_:with:afterDelay:)` (cả `inModes:`), `cancelPreviousPerformRequests(withTarget:)` (cả `selector:object:`), `performSelector(onMainThread:with:waitUntilDone:)`, `NotificationCenter.addObserver(_:selector:name:object:)` (không giữ observer, tự bỏ khi observer mất như iOS 9+) và `_irisRemoveObserver(_:)`, `_irisRemoveObserver(_:name:object:)`. Các timer này và timer của gesture recognizer được tạo với ngày chạy, vì `Timer(timeInterval:repeats:block:)` của Foundation trên Linux chạy ngay lập tức (P1-35 tìm ra và sửa).
- UIKit: target/action của `UIControl`, `UIGestureRecognizer`, `UIApplication.sendAction(_:to:from:for:)`. Target nil đi theo chuỗi responder từ first responder, hoặc từ sender khi chưa có first responder (`target(forAction:withSender:)`, `canPerformAction(_:withSender:)` mặc định là `responds(to:)`). `UIResponder` tự đăng ký `becomeFirstResponder`, `resignFirstResponder`.
- Mọi file của app thấy `IrisObjC` mà không cần import: `PackageWriter` thêm `-Xfrontend -import-module -Xfrontend IrisObjC`.

**P1-35 sinh ra:**

1. **Biểu thức selector:** `#selector(m)`, `#selector(m(_:))`, `#selector(X.m(a:b:))`, `#selector(self.m)`, `#selector(getter: X.p)`, `#selector(setter: X.p)`, cùng `Selector("…")` và `NSSelectorFromString(x)`, thành `_irisSelector("tênObjC")` (hay `_irisSelector(x)`). Tên theo quy tắc compiler Swift dùng cho `@objc`: `m()` → `m`, `m(_:)` → `m:`, `m(_:b:)` → `m:b:`, `m(a:)` → `mWithA:`, nhưng `m(with:)` → `mWith:` và `move(to:)` → `moveTo:` (không thêm "With" trước giới từ); `@objc(tên:)` thắng; getter là tên property, setter là `setP:`. `#selector` không ghi nhãn được giải theo khai báo: trong kiểu đứng trước tên, hay kiểu chứa biểu thức và lớp cha của nó trong module, rồi cả module; không thấy (method của UIKit) thì đặt tên theo cú pháp. `#keyPath(T.a.b)` thành `"a.b"`. Selector và bảng lấy tên từ cùng một hàm nên luôn khớp nhau; chỉ tên action trong storyboard/XIB đòi đúng tuyệt đối.
2. **Bảng method của mỗi file**, ở cuối file: mỗi class (cả class của module khác mà file mở rộng) có một extension với hàm static đăng ký method của class đó khai báo trong file. Hàm nằm trong extension để với tới member `private`; hàm của file gọi chúng qua `_irisRegister`:

   ```swift
   extension ViewController { static func _irisMethods_App_ViewController_swift_0() { _IrisMethods.register(ViewController.self, [
       "label": .init { (o: ViewController) in { o.label } },
       "setLabel:": .init { (o: ViewController) in { o.label = $0 } },
       "tapped:": .init(ViewController.tapped(_:)),
       "refresh": .init { (o: ViewController) in { o.refresh() } },
   ]) } }
   func _irisRegisterMethods_App_ViewController_swift() {
       _irisRegister { ViewController._irisMethods_App_ViewController_swift_0() }
   }
   ```

   Được đăng ký: member có `@objc`, `@IBAction`, `@IBOutlet`, `@IBInspectable`, `@IBSegueAction`, `@GKInspectable`, member của extension `@objc`, mọi member của class `@objcMembers` (và lớp con của nó trong module), member mà một `#selector` nào đó gọi tên, và member hiện thực requirement của protocol `@objc` trong module (cả khi lớp cha mới adopt protocol). Method có tham số dùng tham chiếu chưa áp dụng; method không tham số dùng closure, vì `T.m` có thể trỏ tới overload khác (`dismiss(animated:completion:)` của UIKit). Property có getter, và setter khi gán được. Khai báo nằm trong `#if` thì phần đăng ký nằm trong cùng `#if`. Không đăng ký (summary của `irisrun-ios-build` đếm ở `objc`): method static, method generic, `async`, `throws` hay có hơn 3 tham số, member của class generic, class cục bộ và class `private` lồng trong kiểu khác.
3. **Một file cho mỗi module**, `Sources/<module>/_IrisMethodTables.swift`, đăng ký cả module một lần, trước selector đầu tiên:

   ```swift
   let _irisMethodsRegistered: Void = {
       _irisRegisterMethods_App_ViewController_swift()
   }()

   func _irisSelector(_ name: String) -> Selector {
       _ = _irisMethodsRegistered
       return Selector(name)
   }
   ```

   Factory `_IrisInstantiable` (1a) gọi `_ = _irisMethodsRegistered` trước khi tạo object, nên app UIKit có bảng ngay lúc khởi động, trước khi storyboard (đợt 6) gửi action.
4. **Bỏ** `@objc`, `@objc(…)`, `@objcMembers`, `@nonobjc`, `@IBAction`, `@IBOutlet`, `@IBInspectable`, `@IBDesignable`, `@IBSegueAction`, `@GKInspectable`, và `optional` trong protocol `@objc` (giữ dòng). `dynamic` ở lại: Linux nhận nó ở mọi chỗ đã thử. `import UIKit.UIGestureRecognizerSubclass` thành `import UIKit` (1b, `UIKitSources.swift`).
5. **Protocol `@objc`** thành protocol cho class (`: AnyObject`, hay thêm `, AnyObject`), để `weak var delegate: P?` dịch được. Requirement optional có hiện thực trong `extension P` gửi selector (`_IrisMethods.send(_irisSelector("m:"), to: self, with: [a0])`). Lời gọi `x?.m?(a)` thành `_irisOptional(x, _irisSelector("m:"))?.m(a)`, `x.m!(a)` thành `x.m(a)`. Vì vậy method optional không có thì không được gọi và biểu thức là nil như iOS, còn method chỉ có ở lớp con của class adopt protocol vẫn được gọi qua bảng.
6. **KVO:** property lưu trữ `dynamic` của class `@objc` (`@objc dynamic`, hay `dynamic` trong class `@objcMembers`) có thêm `didSet { _irisDidChangeValue(self, \T.p, from: oldValue) }` trên cùng dòng, hoặc lời gọi đó ở đầu `didSet` sẵn có.
7. **`removeObserver`:** `X.removeObserver(o)` và `X.removeObserver(o, name:, object:)` có receiver chứa "center" (`NotificationCenter.default`, `notificationCenter`, `center`) thành `_irisRemoveObserver(…)`. `removeObserver(_:forKeyPath:)` của KVO và `removeObserver(_:)` của chính app (`store.removeObserver(x)`) giữ nguyên.

**Bộ nạp storyboard/XIB (đợt 6) dùng bảng như UIKit:**

- Outlet: `owner.setValue(destination, forKey: "label")` gọi setter `setLabel:` của bảng; outlet collection nhận một mảng. Thuộc tính `@IBInspectable` và "User Defined Runtime Attributes" cũng qua `setValue(_:forKey:)`. Giá trị được ép bằng `as?` sang kiểu property, nên bộ nạp phải đưa đúng kiểu (`CGFloat` cho property `CGFloat`, không phải `Double`).
- Action: `control.addTarget(target, action: Selector(tênTrongXIB), for: event)` hay `UIGestureRecognizer(target:action:)`. Method `@IBAction` được đăng ký đúng tên ObjC mà Xcode ghi: `tapped:`, `tapped:forEvent:`, `tapped` khi không có sender.
- Class từ `customClass`: `NSClassFromString("Module.Class")` chạy được, nhưng tạo view controller hay view bằng `init(coder:)` cần factory sinh lúc build như `_IrisInstantiable`: việc của đợt 6. P1-35 bỏ `@objc(Tên)` của class mà không giữ tên đó; storyboard dùng tên ObjC (không có `customModule`) cần thêm bảng tên.

**Giới hạn đã biết:** method chạy trên luồng gọi như Objective-C. Method optional của protocol UIKit (`UITableViewDelegate`…) là việc của OpenUIKit: protocol Swift có hiện thực mặc định, và OpenUIKit hỏi `responds(to:)` trước khi gọi như UIKit. Selector của method UIKit được đặt tên theo cú pháp (`#selector(UIViewController.dismiss(animated:completion:))` → `dismissWithAnimated:completion:`, không phải `dismissViewControllerAnimated:completion:`), nên OpenUIKit đăng ký method của mình bằng tên `objcSelector` của `IrisBuild` sinh ra. Chưa có `Timer(fireAt:…target:selector:…)`, `performSelector(inBackground:with:)`, `Thread(target:selector:object:)`, các kiểu UIKit nhận selector sẽ đến sau (`UIBarButtonItem`, `UIKeyCommand`, `CADisplayLink`), KVO kiểu cũ (`addObserver(_:forKeyPath:options:context:)`, `observeValue(forKeyPath:…)`), KVO của property tính toán và của object thuộc framework (`WKWebView`, `AVPlayer`…). Package local của app chưa được viết lại.

**App mẫu:** `examples/ios-uikit` dùng tất cả như app thật: chạm hai lần (`UITapGestureRecognizer`) đưa tay nắm kéo về chỗ cũ, kéo logo (`UIPanGestureRecognizer`), giữ thẻ (`UILongPressGestureRecognizer`), `addTarget(_:action:for:)` với method `@objc` và `@IBAction`, observer `NotificationCenter` và `Timer` theo selector; `session.txt` có 34 điểm. Chạm hai lần không đặt trên touch pad như 1b định: kịch bản chạm touch pad rồi giữ ngay, trên iOS cũng thành chạm hai lần.
