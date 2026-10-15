# Kế hoạch P1-16 · UIKit cơ bản (đề xuất, chờ duyệt)

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
| Cassowary | [CassowarySwift](https://swiftpackageregistry.com/tribalworldwidelondon/CassowarySwift) (BSD-3, có test trên Linux, ngừng cập nhật từ 2019) hoặc [compnerd/cassowary](https://swiftpackageregistry.com/compnerd/cassowary) (Swift, theo Kiwi) | BSD-3 / cần kiểm | Thử cả hai trong đợt 3, chọn cái build sạch với Swift 6.4.1 và nhanh hơn; fork vào checkout như OpenSwiftUI |
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

## Cần anh/chị quyết

1. Đồng ý kiến trúc trên (OpenUIKit tự viết trên render core, không phụ thuộc OpenSwiftUI) và thứ tự đợt 1 → 2 → 7 → 3 → 4 → 5 → 6?
2. Tách bước viết lại `@objc`/`#selector`/IB thành task mới P1-35 (làm song song), hay giữ trong P1-16 (đợt 6)?
