# P1-12 · Pipeline build iOS

15/10/2026 · Máy dev WSL2 Ubuntu 20.04, Swift 6.4.1 trong container `irisrun-swift-dev:6.4.1`. Thử trên app mẫu và 65 app mã nguồn mở của corpus P0-08 (`~/.cache/irisrun/ios-corpus/apps`).

## Kết luận

- **Đọc được project Xcode thật.** Công cụ `irisrun-ios-build` đọc `project.pbxproj`, chọn target app iOS, rồi gom file Swift, resource, gói SPM và build setting cần cho compile. Nó sinh một package SwiftPM build với OpenKit: bỏ `#Preview` và `PreviewProvider`, alias `SwiftUI` sang OpenSwiftUI và `Observation` sang OpenObservation, đổi `.xcstrings` sang `.lproj/*.strings`. Cả 65 app của corpus đều được đọc và chọn đúng target iOS, kể cả 26 project dùng thư mục đồng bộ của Xcode 16; không app nào lỗi.
- **App mẫu SwiftUI build qua `.xcodeproj` của chính nó, không sửa code:** `check-sample.sh` vẫn đạt 14 điểm. App mẫu có thêm `IrisSample.xcodeproj` và `Assets.xcassets`, như một project Xcode 16 mới tạo. File project viết tay theo template của Xcode 16, chưa mở thử bằng Xcode vì máy dev không có Mac.
- **Chưa đạt nửa UIKit của tiêu chí nghiệm thu** ("app mẫu SwiftUI và UIKit build được"): chưa có app mẫu UIKit (P1-33) và OpenKit chưa có UIKit (P1-16). Pipeline đã nhận ra điểm vào `@UIApplicationMain` của app UIKit.
- **Chưa app nào của corpus compile được:** app nào cũng import thêm UIKit, Combine, framework khác hoặc gói bên thứ ba, đúng như P0-08 dự báo. Việc đó chờ P1-16, P1-17 và stub của P1-18. Lệnh `ios-corpus compile` giờ đi qua pipeline này, nên tỉ lệ compile sẽ đo đúng từng target.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Parser plist kiểu OpenStep (định dạng `project.pbxproj`): dictionary, array, chuỗi có hoặc không có ngoặc kép, escape `\U`, comment | `runtimes/ios/Sources/IrisBuild/Plist.swift` |
| Mô hình project: target, đường dẫn file theo cây group (`<group>`, `SOURCE_ROOT`, tuyệt đối), file của từng build phase, `PBXVariantGroup` (file bản địa hoá), thư mục đồng bộ của Xcode 16 cùng exception set, build setting theo configuration với `$(inherited)` và tham chiếu `$(NAME)`, gói SPM (remote với 6 kiểu requirement, local) | `XcodeProject.swift` |
| Chọn target: app (không extension, test, framework), build cho iOS (`SDKROOT`, `SUPPORTED_PLATFORMS`), ưu tiên target trùng tên project; chọn tên khác bằng `--target`. Không có `.xcodeproj` thì lấy mọi file Swift trừ test | `AppTarget.swift` |
| Tên module theo `PRODUCT_MODULE_NAME`, rồi `PRODUCT_NAME` (ví dụ "AC Helper" → `AC_Helper`); `SWIFT_ACTIVE_COMPILATION_CONDITIONS` thành `.define`; `INFOPLIST_KEY_*` | `AppTarget.swift` |
| Tìm file không phân biệt hoa thường khi đường dẫn đúng không có, như macOS | `existingFile` |
| Bỏ `#Preview` và kiểu conform `PreviewProvider`, kèm attribute ngay trên chúng (thay `strip-previews.py`) | `Previews.swift` |
| Sinh `Package.swift`, chép source đã bỏ preview, resource vào `Resources/`; `.xcstrings` → `<ngôn ngữ>.lproj/<bảng>.strings` | `PackageWriter.swift` |
| Lệnh `irisrun-ios-build <app> --out … --openswiftui … --render-lib …`, in JSON những gì tìm thấy | `Sources/irisrun-ios-build/main.swift` |
| `compile-app.sh` gọi công cụ này thay cho `find` + Python; `check-sample.sh` build app mẫu từ thư mục chứa `.xcodeproj` | `runtimes/ios/Scripts/` |
| Project Xcode và asset catalog cho app mẫu | `examples/ios-swiftui/IrisSample.xcodeproj`, `IrisSample/Assets.xcassets` |
| 7 test (swift-testing), trong đó một project giả có app iOS, app watchOS, gói SPM và thư mục đồng bộ | `runtimes/ios/Tests/IrisBuildTests` |

## Quyết định

- **Viết bằng Swift, chỉ dùng Foundation,** trong package `runtimes/ios` có sẵn. Máy nào build app iOS cũng đã có Swift, nên không thêm phụ thuộc mới; bỏ được Python khỏi đường build. Corpus (P1-20) dùng chung công cụ này qua `compile-app.sh`.
- **Không dùng SwiftSyntax cho việc bỏ preview.** Quét dòng và đếm ngoặc là đủ cho preview như Xcode viết, nhanh và không phải build swift-syntax. Khi làm việc viết lại `@objc`/`#selector` mà P0-08 đề xuất thì chuyển sang SwiftSyntax.
- **Asset catalog chép nguyên, không biên dịch.** `Contents.json` của mỗi imageset, colorset đã là manifest JSON, nên OpenKit đọc thẳng lúc chạy (P1-13, P1-16). `actool` chỉ có trên máy Apple.
- **String catalog đổi sang `.strings`,** vì Foundation trên Linux đọc `.lproj/*.strings` qua `Bundle`, không đọc `.xcstrings`.
- **Thư mục đồng bộ theo đúng ngữ nghĩa của Xcode 16:** target có liệt kê thư mục thì nhận mọi file trong đó trừ các file trong exception set của nó; target không liệt kê thì chỉ nhận các file mà exception set của nó nêu tên. Các thư mục `.xcassets`, `.lproj`, `.bundle`, `.icon` được tính là một file.

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| 10/65 app không nhận ra là executable | App UIKit cũ đánh dấu điểm vào bằng `@UIApplicationMain` trên AppDelegate, không phải `@main` | Nhận cả `@UIApplicationMain`; còn 1 app có điểm vào trong `main.m` |
| 6 app báo thiếu file Swift | Ba app ghi đường dẫn khác hoa thường so với đĩa (ví dụ `View/` với `view/`); macOS không phân biệt nên Xcode vẫn chạy | Tìm từng phần đường dẫn không phân biệt hoa thường khi đường dẫn đúng không có. Ba app còn lại thiếu file thật: `R.generated.swift` sinh lúc build, `Secrets.swift` bị gitignore, một tham chiếu cũ |
| Thư mục `AppIcon.icon` (icon kiểu mới) bị duyệt như thư mục thường | Danh sách bundle chưa có `.icon` | Thêm `.icon` |

## Số đo trên corpus

| Mục | Số |
| --- | --- |
| Project đọc được, có target iOS | 65/65 (26 dùng thư mục đồng bộ của Xcode 16) |
| Có điểm vào (`@main`, `@UIApplicationMain`, `main.swift`) | 64/65 |
| File Swift của target được chọn | 8005, trung vị 68 mỗi app |
| App dùng gói SPM | 38, tổng 155 gói |
| Cảnh báo | 13 app có storyboard hoặc XIB (trừ launch screen) cần Interface Builder; 6 có bridging header Objective-C; 6 có file C hoặc Objective-C bị bỏ qua; 3 thiếu file trên đĩa |
| Resource hay gặp | `.lproj` 154, ảnh `.png` 127, `.xcassets` 106, `.json` 106, `.xib` 104, `.strings` 79, `.storyboard` 61, `.xcstrings` 32 |
| Thời gian | 65 app dưới 1 phút, phần lớn là chép file |

## Giới hạn và việc tiếp

- **Resource mới được chép vào `Resources/` của package;** chưa có bước đặt chúng cạnh executable để `Bundle.main` tìm thấy. Host thật của P1-13 hoặc CLI làm bước này khi chạy app.
- **Plural của `.xcstrings` lấy dạng `other`;** nên sinh `.stringsdict` khi có app cần.
- **Storyboard và XIB chỉ được chép và cảnh báo:** 13/65 app cần Interface Builder ở runtime, việc của nhánh UIKit.
- **C, Objective-C, bridging header:** bỏ qua và cảnh báo; clang + libobjc2 của P0-07 là hướng làm.
- **Chưa đọc `.xcworkspace`,** XcodeGen hay Tuist (corpus không có app nào cần), và chưa đọc `.xcconfig` mà build setting tham chiếu tới.
- **Gói SPM bên thứ ba được khai báo đúng,** nhưng nhiều gói import UIKit nên chưa build được trên Linux (E2-04).

## Chạy lại

```sh
cd runtimes/ios
swift test                                   # 7 test của IrisBuild, 1 của IrisProtocol
swift run irisrun-ios-build <thư mục app> --out /tmp/pkg \
  --openswiftui ~/.cache/irisrun/p0-05/checkouts/OpenSwiftUI --render-lib ../../target/release
Scripts/check-sample.sh                      # app mẫu qua IrisSample.xcodeproj, 14 điểm
```

Ở máy dev, đặt `swiftenv` trước mỗi lệnh Swift (xem `docs/progress.md`).
