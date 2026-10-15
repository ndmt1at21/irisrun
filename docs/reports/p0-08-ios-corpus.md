# P0-08 · Corpus iOS và bảng xếp hạng API

14–15/10/2026 · Chạy trên WSL2 Ubuntu 20.04, x86_64, 12 nhân, máy dùng chung với các build khác. Swift 6.4.1 không chạy trên Ubuntu 20.04, nên Swift và git 2.43 chạy trong container `swift:6.4.1-noble`. Corpus gồm 65 app, 12.262 file Swift, 1,5 triệu dòng.

## Kết luận

- **Corpus đã sẵn sàng.** 65 app mã nguồn mở (50 SwiftUI, 15 UIKit) lấy từ open-source-ios-apps. Mỗi app được pin vào một commit. Ngày 14/10/2026 cả 65 commit đều tải được. Tải sparse cả 65 app mất 4,5 phút (523 MB), phân tích mất 14 giây.
- **SwiftUI có lõi nhỏ và đuôi dài.** 53 API có mặt trong ít nhất 60% app, ví dụ `Text`, `VStack`, `HStack`, `Spacer`, `ForEach`, `Button`, `Color`, `Image`, `.padding`, `.font`, `.frame`, `.background`, `.sheet`, `@State`, `@Binding`, `@Environment`. Nhưng tính cả corpus thì có 78 view, 195 kiểu và 325 modifier khác nhau.
- **Phải hỗ trợ cả hai mô hình state.** 37 app dùng `ObservableObject` (`@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`). 23 app dùng `@Observable`. 9 app dùng cả hai.
- **App SwiftUI vẫn cần UIKit.** 43/50 app SwiftUI (86%) dùng view hoặc view controller UIKit. 37 app bọc view UIKit bằng `UIViewRepresentable` hoặc `UIViewControllerRepresentable`, 24 app dùng `UIHostingController`. Chỉ 1 app SwiftUI không dùng tên UIKit nào.
- **Objective-C chặn 72% app.** Đo bằng `swiftc` 6.4.1 trên Linux: `@objc`, `#selector`, `#keyPath`, `Selector`, `@IBOutlet` và KVO lỗi compile, `@NSManaged` lỗi link. 47 app (72%) có ít nhất một cấu trúc như vậy, kể cả 32/50 app SwiftUI. Viết lại bằng SwiftSyntax đủ cho 27 app. 20 app (31%) cần ObjC runtime hoặc Core Data.
- **Framework Apple trải rất rộng.** Corpus import 123 module Apple. 54/65 app import ít nhất một framework chưa có trong plan, hay gặp nhất là WidgetKit (28 app), AppIntents (16) và AuthenticationServices (12). Combine có trong 38 app (58%). Core Data hoặc SwiftData có trong 30 app (46%).
- **Trần tỉ lệ compile là 28%, lên 60% nếu viết lại ObjC. Số thật chưa có.** Khi P1-18 sinh stub cho mọi framework chưa làm, 18 app (28%) hết rào chắn tính theo import. Viết lại `@objc`/`#selector` bằng SwiftSyntax nâng con số lên 39 app (60%). Không có stub thì chỉ còn 7 app (11%), kể cả khi đã làm thật E2-05, E2-10 và Charts. Lệnh `compile` đã nối sẵn và đã chạy thử với một lệnh giả. Script compile của P0-05 vừa có, nhưng mới cung cấp SwiftUI và Observation, mà không app nào chỉ import những module đó. Vì vậy lần chạy đầu sẽ ra 0/65 và chỉ đo khoảng trống, chưa đo độ phủ.
- **Build:** cả 65 app đều có `.xcodeproj`, không app nào chỉ có `Package.swift`. 46 app (71%) dùng gói SPM bên thứ ba, 9 app dùng CocoaPods hoặc Carthage, 20 app có storyboard/XIB, 27 app có widget extension, 18 app có code macOS/watchOS trong cùng repo. 11 app đặt deployment target iOS 26, và 18 app đã dùng API iOS 26 như `.glassEffect`.

## Corpus

Danh sách nằm trong `tools/ios-corpus/corpus.json`, gồm tên, repo, commit, license, tag và lý do chọn từng app. Nguồn là file `contents.json` của open-source-ios-apps ở commit `6d68805`. Tiêu chí chọn:

- 50 app SwiftUI và 15 app UIKit, để đo được cả hai phía.
- Đủ cỡ: từ 569 dòng (FoundationChat) tới 188 nghìn dòng (Wikipedia). Trung vị là 10 nghìn dòng.
- Đủ thời kỳ: từ code thời SwiftUI 1.0 (MovieSwiftUI) tới app cho iOS 26 (FoundationChat, IcySky).
- Có app production lớn (Ice Cubes, Mlem, Thunderbird, Swiftfin, Wikipedia, NetNewsWire), sample của Apple (Backyard Birds, Food Truck), và app dùng TCA, RxSwift, Firebase, Realm.
- Còn được bảo trì: lúc kiểm tra, 64/65 app vẫn có HEAD đúng bằng commit đã pin. NetNewsWire đã có commit mới, còn commit pin vẫn tải được.

Code của các app chỉ được tải về máy để đo, không chép vào repo, nên license GPL và AGPL không ảnh hưởng tới Iris.

<!-- generated:summary -->
| Chỉ số | Giá trị |
| --- | --- |
| App | 65 (SwiftUI 50, UIKit 15) |
| File Swift (không tính test) | 12262 |
| Dòng Swift | 1501522 |
| Dòng Swift mỗi app: trung vị (nhỏ nhất–lớn nhất) | 9998 (569–187757) |
| License | mit 39, apache-2.0 8, other 8, gpl-3.0 6, mpl-2.0 2, agpl-3.0 1, cc0-1.0 1 |
| Điểm vào (`@main`) | SwiftUI App 46, WidgetKit 27, UIWindowSceneDelegate 22, UIApplicationDelegate 21, other 3, AppKit 1 |
<!-- /generated:summary -->

`@main` trên `WidgetBundle` hoặc `Widget` là widget extension. Ba điểm vào "other" là hai công cụ dòng lệnh và một plugin macro nằm trong repo.

## Bảng xếp hạng API

Mỗi bảng xếp theo số app dùng, rồi tới số lần dùng. Cột "% app" tính trên 65 app. Cách quy một tên về SwiftUI hay UIKit nằm ở mục Giới hạn và trong `tools/ios-corpus/README.md`.

### SwiftUI: view

<!-- generated:swiftui-views -->
| # | View | App | % app | Lần dùng |
| --- | --- | --- | --- | --- |
| 1 | `Text` | 55 | 85% | 11322 |
| 2 | `VStack` | 55 | 85% | 3779 |
| 3 | `HStack` | 55 | 85% | 3666 |
| 4 | `Spacer` | 55 | 85% | 2531 |
| 5 | `ForEach` | 54 | 83% | 2069 |
| 6 | `Button` | 52 | 80% | 4226 |
| 7 | `Color` | 51 | 78% | 6402 |
| 8 | `Image` | 49 | 75% | 3079 |
| 9 | `RoundedRectangle` | 46 | 71% | 1155 |
| 10 | `ZStack` | 46 | 71% | 962 |
| 11 | `ScrollView` | 46 | 71% | 503 |
| 12 | `List` | 45 | 69% | 372 |
| 13 | `TextField` | 42 | 65% | 357 |
| 14 | `Section` | 41 | 63% | 1109 |
| 15 | `Rectangle` | 41 | 63% | 805 |
| 16 | `Group` | 41 | 63% | 675 |
| 17 | `Divider` | 40 | 62% | 603 |
| 18 | `NavigationLink` | 39 | 60% | 509 |
| 19 | `Picker` | 37 | 57% | 441 |
| 20 | `EmptyView` | 37 | 57% | 370 |
| 21 | `Circle` | 36 | 55% | 621 |
| 22 | `ProgressView` | 35 | 54% | 541 |
| 23 | `GeometryReader` | 35 | 54% | 401 |
| 24 | `Toggle` | 34 | 52% | 619 |
| 25 | `NavigationStack` | 34 | 52% | 494 |
| 26 | `Form` | 33 | 51% | 248 |
| 27 | `Label` | 30 | 46% | 943 |
| 28 | `Menu` | 30 | 46% | 258 |
| 29 | `LinearGradient` | 28 | 43% | 254 |
| 30 | `LazyVGrid` | 28 | 43% | 92 |
| 31 | `Capsule` | 27 | 42% | 341 |
| 32 | `LazyVStack` | 25 | 38% | 113 |
| 33 | `TabView` | 24 | 37% | 42 |
| 34 | `NavigationView` | 23 | 35% | 177 |
| 35 | `Link` | 23 | 35% | 92 |
| 36 | `ScrollViewReader` | 21 | 32% | 53 |
| 37 | `Path` | 20 | 31% | 239 |
| 38 | `Slider` | 20 | 31% | 85 |
| 39 | `AnyView` | 16 | 25% | 158 |
| 40 | `DatePicker` | 16 | 25% | 51 |

Số API khác nhau: 78 view, 195 kiểu, 325 modifier. Hàm tự do: `withAnimation` 44 app, `withTransaction` 7 app.
<!-- /generated:swiftui-views -->

### SwiftUI: modifier và method

Gồm modifier của `View` và method của `Text`, `Image`, `Shape`, `Path`, `Font`, `Animation`, `AnyTransition`, gesture và `ScrollViewProxy`. Ví dụ `.weight` là `Font.weight(_:)`, `.combined` là `AnyTransition.combined(with:)`, `.onEnded` là của gesture.

<!-- generated:swiftui-modifiers -->
| # | Modifier hoặc method | App | % app | Lần dùng |
| --- | --- | --- | --- | --- |
| 1 | `.padding` | 55 | 85% | 6809 |
| 2 | `.font` | 55 | 85% | 6583 |
| 3 | `.frame` | 55 | 85% | 6161 |
| 4 | `.background` | 53 | 82% | 2138 |
| 5 | `.opacity` | 48 | 74% | 2983 |
| 6 | `.sheet` | 47 | 72% | 504 |
| 7 | `.resizable` | 46 | 71% | 724 |
| 8 | `.onAppear` | 45 | 69% | 808 |
| 9 | `.modifier` | 45 | 69% | 506 |
| 10 | `.foregroundColor` | 44 | 68% | 3693 |
| 11 | `.overlay` | 44 | 68% | 997 |
| 12 | `.animation` | 44 | 68% | 948 |
| 13 | `.disabled` | 44 | 68% | 833 |
| 14 | `.onChange` | 42 | 65% | 1220 |
| 15 | `.fill` | 42 | 65% | 1196 |
| 16 | `.lineLimit` | 42 | 65% | 924 |
| 17 | `.environment` | 42 | 65% | 758 |
| 18 | `.multilineTextAlignment` | 42 | 65% | 534 |
| 19 | `.onTapGesture` | 42 | 65% | 466 |
| 20 | `.fontWeight` | 41 | 63% | 854 |
| 21 | `.buttonStyle` | 40 | 62% | 1335 |
| 22 | `.clipShape` | 40 | 62% | 526 |
| 23 | `.toolbar` | 40 | 62% | 474 |
| 24 | `.navigationTitle` | 39 | 60% | 627 |
| 25 | `.tint` | 38 | 58% | 497 |
| 26 | `.cornerRadius` | 38 | 58% | 415 |
| 27 | `.shadow` | 38 | 58% | 326 |
| 28 | `.stroke` | 37 | 57% | 419 |
| 29 | `.id` | 37 | 57% | 257 |
| 30 | `.listStyle` | 37 | 57% | 197 |
| 31 | `.tag` | 36 | 55% | 683 |
| 32 | `.fixedSize` | 36 | 55% | 372 |
| 33 | `.foregroundStyle` | 35 | 54% | 3610 |
| 34 | `.contentShape` | 35 | 54% | 729 |
| 35 | `.transition` | 35 | 54% | 426 |
| 36 | `.aspectRatio` | 35 | 54% | 379 |
| 37 | `.ignoresSafeArea` | 34 | 52% | 351 |
| 38 | `.scaleEffect` | 34 | 52% | 316 |
| 39 | `.offset` | 31 | 48% | 465 |
| 40 | `.bold` | 31 | 48% | 349 |
| 41 | `.navigationBarTitleDisplayMode` | 31 | 48% | 336 |
| 42 | `.alert` | 31 | 48% | 212 |
| 43 | `.task` | 30 | 46% | 328 |
| 44 | `.pickerStyle` | 30 | 46% | 170 |
| 45 | `.weight` | 29 | 45% | 605 |
| 46 | `.scaledToFit` | 29 | 45% | 242 |
| 47 | `.onReceive` | 29 | 45% | 235 |
| 48 | `.contextMenu` | 29 | 45% | 179 |
| 49 | `.listRowBackground` | 28 | 43% | 421 |
| 50 | `.clipped` | 28 | 43% | 111 |
| 51 | `.environmentObject` | 26 | 40% | 419 |
| 52 | `.minimumScaleFactor` | 26 | 40% | 234 |
| 53 | `.focused` | 26 | 40% | 200 |
| 54 | `.combined` | 26 | 40% | 194 |
| 55 | `.presentationDetents` | 25 | 38% | 134 |
| 56 | `.onDisappear` | 25 | 38% | 133 |
| 57 | `.onEnded` | 25 | 38% | 111 |
| 58 | `.swipeActions` | 25 | 38% | 81 |
| 59 | `.allowsHitTesting` | 24 | 37% | 208 |
| 60 | `.move` | 24 | 37% | 189 |
<!-- /generated:swiftui-modifiers -->

### SwiftUI: kiểu khác

<!-- generated:swiftui-types -->
| # | Kiểu | App | % app | Lần dùng |
| --- | --- | --- | --- | --- |
| 1 | `View` | 51 | 78% | 12860 |
| 2 | `ViewModifier` | 46 | 71% | 390 |
| 3 | `WindowGroup` | 46 | 71% | 75 |
| 4 | `Binding` | 45 | 69% | 1146 |
| 5 | `Scene` | 45 | 69% | 82 |
| 6 | `App` | 45 | 69% | 68 |
| 7 | `ToolbarItem` | 38 | 58% | 622 |
| 8 | `Font` | 36 | 55% | 674 |
| 9 | `ObservableObject` | 34 | 52% | 340 |
| 10 | `PreviewProvider` | 33 | 51% | 435 |
| 11 | `UIViewRepresentable` | 31 | 48% | 95 |
| 12 | `UIViewControllerRepresentable` | 31 | 48% | 64 |
| 13 | `EnvironmentValues` | 28 | 43% | 252 |
| 14 | `UIHostingController` | 28 | 43% | 146 |
| 15 | `GridItem` | 27 | 42% | 138 |
| 16 | `EdgeInsets` | 26 | 40% | 337 |
| 17 | `DragGesture` | 25 | 38% | 112 |
| 18 | `StrokeStyle` | 23 | 35% | 93 |
| 19 | `Shape` | 23 | 35% | 90 |
| 20 | `ToolbarItemGroup` | 22 | 34% | 51 |
| 21 | `LocalizedStringKey` | 21 | 32% | 421 |
| 22 | `ButtonStyle` | 21 | 32% | 97 |
| 23 | `PreferenceKey` | 21 | 32% | 65 |
| 24 | `Angle` | 19 | 29% | 115 |
| 25 | `ColorScheme` | 19 | 29% | 78 |
| 26 | `Gradient` | 18 | 28% | 123 |
| 27 | `Animation` | 18 | 28% | 59 |
| 28 | `UnitPoint` | 16 | 25% | 66 |
| 29 | `GeometryProxy` | 15 | 23% | 73 |
| 30 | `AnyTransition` | 15 | 23% | 66 |
<!-- /generated:swiftui-types -->

### Property wrapper và macro

<!-- generated:swiftui-wrappers -->
| # | Thuộc tính / macro | Module | App | % app | Lần dùng |
| --- | --- | --- | --- | --- | --- |
| 1 | `@Environment` | SwiftUI | 53 | 82% | 2791 |
| 2 | `@State` | SwiftUI | 52 | 80% | 4927 |
| 3 | `@Binding` | SwiftUI | 50 | 77% | 903 |
| 4 | `@ViewBuilder` | SwiftUI | 43 | 66% | 2496 |
| 5 | `#Preview` | SwiftUI | 32 | 49% | 854 |
| 6 | `@Published` | Combine | 31 | 48% | 1443 |
| 7 | `@StateObject` | SwiftUI | 28 | 43% | 347 |
| 8 | `@FocusState` | SwiftUI | 27 | 42% | 148 |
| 9 | `@EnvironmentObject` | SwiftUI | 26 | 40% | 624 |
| 10 | `@ObservedObject` | SwiftUI | 24 | 37% | 684 |
| 11 | `@AppStorage` | SwiftUI | 24 | 37% | 535 |
| 12 | `@Observable` | Observation | 23 | 35% | 288 |
| 13 | `@Parameter` | AppIntents | 18 | 28% | 179 |
| 14 | `@UIApplicationDelegateAdaptor` | SwiftUI | 17 | 26% | 17 |
| 15 | `@Bindable` | SwiftUI | 16 | 25% | 247 |
| 16 | `@Model` | SwiftData | 15 | 23% | 73 |
| 17 | `@Namespace` | SwiftUI | 15 | 23% | 73 |
| 18 | `@ScaledMetric` | SwiftUI | 15 | 23% | 73 |
| 19 | `@ObservationIgnored` | Observation | 12 | 18% | 136 |
| 20 | `#Predicate` | Foundation | 12 | 18% | 117 |
| 21 | `@Query` | SwiftData | 11 | 17% | 118 |
| 22 | `@Entry` | SwiftUI | 11 | 17% | 77 |
| 23 | `@Previewable` | SwiftUI | 10 | 15% | 164 |
| 24 | `@Relationship` | SwiftData | 9 | 14% | 40 |
| 25 | `@GestureState` | SwiftUI | 9 | 14% | 21 |
| 26 | `@Attribute` | SwiftData | 8 | 12% | 26 |
| 27 | `@ToolbarContentBuilder` | SwiftUI | 7 | 11% | 31 |
| 28 | `@FetchRequest` | SwiftUI | 6 | 9% | 57 |
| 29 | `@NSApplicationDelegateAdaptor` | SwiftUI | 6 | 9% | 6 |
| 30 | `@WidgetBundleBuilder` | WidgetKit | 6 | 9% | 6 |
<!-- /generated:swiftui-wrappers -->

### Khoá `@Environment`

`(object)` là dạng `@Environment(Model.self)`, đi cùng `@Observable`.

<!-- generated:swiftui-environment -->
| # | Khoá `@Environment` | App | % app | Lần dùng |
| --- | --- | --- | --- | --- |
| 1 | `\.dismiss` | 31 | 48% | 306 |
| 2 | `\.colorScheme` | 28 | 43% | 167 |
| 3 | `\.scenePhase` | 25 | 38% | 54 |
| 4 | `\.widgetFamily` | 24 | 37% | 64 |
| 5 | `\.openURL` | 18 | 28% | 43 |
| 6 | `\.horizontalSizeClass` | 17 | 26% | 59 |
| 7 | `(object)` | 16 | 25% | 973 |
| 8 | `\.presentationMode` | 13 | 20% | 79 |
| 9 | `\.dynamicTypeSize` | 12 | 18% | 61 |
| 10 | `\.modelContext` | 10 | 15% | 104 |
| 11 | `\.accessibilityReduceMotion` | 9 | 14% | 68 |
| 12 | `\.isEnabled` | 9 | 14% | 29 |
| 13 | `\.managedObjectContext` | 6 | 9% | 49 |
| 14 | `\.openWindow` | 6 | 9% | 24 |
| 15 | `\.displayScale` | 6 | 9% | 10 |
<!-- /generated:swiftui-environment -->

### UIKit trong app SwiftUI

Một app được tính là dùng view UIKit khi có `UIViewRepresentable`, `UIViewControllerRepresentable`, `UIHostingController`, hoặc một kiểu UIKit có chữ `View` hay `Controller` trong tên.

<!-- generated:uikit-in-swiftui -->
| 50 app SwiftUI | App | % |
| --- | --- | --- |
| Không dùng tên UIKit nào | 1 | 2% |
| Chỉ dùng kiểu UIKit không phải view (vòng đời app, `UIDevice`, `UIPasteboard`…) | 6 | 12% |
| Dùng view hoặc view controller UIKit | 43 | 86% |
| Trong đó bọc view UIKit (`UIViewRepresentable`, `UIViewControllerRepresentable`) | 37 | 74% |
| Trong đó đặt SwiftUI vào UIKit (`UIHostingController`) | 24 | 48% |

App UIKit có import SwiftUI: 6/15.
<!-- /generated:uikit-in-swiftui -->

### UIKit: kiểu

Tính mọi tên `UI…` và vài kiểu `NS…` thuộc UIKit trên iOS (Auto Layout, TextKit, diffable data source, compositional layout).

<!-- generated:uikit -->
| # | API | App | % app | App SwiftUI (/50) | App UIKit (/15) | Lần dùng |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `UIApplication` | 56 | 86% | 41 | 15 | 977 |
| 2 | `UIColor` | 51 | 78% | 36 | 15 | 3716 |
| 3 | `UIImage` | 50 | 77% | 35 | 15 | 1723 |
| 4 | `UIView` | 39 | 60% | 24 | 15 | 1513 |
| 5 | `UIResponder` | 39 | 60% | 25 | 14 | 180 |
| 6 | `UIWindowScene` | 39 | 60% | 29 | 10 | 141 |
| 7 | `UIFont` | 38 | 58% | 25 | 13 | 1272 |
| 8 | `UIViewController` | 38 | 58% | 23 | 15 | 969 |
| 9 | `UIApplicationDelegate` | 38 | 58% | 24 | 14 | 56 |
| 10 | `UIDevice` | 36 | 55% | 23 | 13 | 441 |
| 11 | `UIWindow` | 34 | 52% | 19 | 15 | 153 |
| 12 | `UIScreen` | 30 | 46% | 19 | 11 | 289 |
| 13 | `UIPasteboard` | 28 | 43% | 18 | 10 | 116 |
| 14 | `UIActivityViewController` | 27 | 42% | 19 | 8 | 127 |
| 15 | `UINavigationController` | 25 | 38% | 12 | 13 | 223 |
| 16 | `UIScene` | 24 | 37% | 15 | 9 | 254 |
| 17 | `UILabel` | 23 | 35% | 9 | 14 | 1116 |
| 18 | `UIEdgeInsets` | 23 | 35% | 11 | 12 | 457 |
| 19 | `UISceneSession` | 23 | 35% | 14 | 9 | 97 |
| 20 | `UIWindowSceneDelegate` | 23 | 35% | 13 | 10 | 41 |
| 21 | `UITableView` | 22 | 34% | 7 | 15 | 590 |
| 22 | `UIImageView` | 22 | 34% | 7 | 15 | 387 |
| 23 | `UITapGestureRecognizer` | 22 | 34% | 10 | 12 | 137 |
| 24 | `UIImpactFeedbackGenerator` | 22 | 34% | 15 | 7 | 96 |
| 25 | `UITextView` | 21 | 32% | 10 | 11 | 268 |
| 26 | `UISceneConfiguration` | 21 | 32% | 14 | 7 | 76 |
| 27 | `NSLayoutConstraint` | 20 | 31% | 11 | 9 | 725 |
| 28 | `UIScrollView` | 20 | 31% | 10 | 10 | 310 |
| 29 | `UITraitCollection` | 20 | 31% | 12 | 8 | 273 |
| 30 | `UITextField` | 20 | 31% | 8 | 12 | 239 |
| 31 | `UIBarButtonItem` | 19 | 29% | 6 | 13 | 463 |
| 32 | `UIButton` | 18 | 28% | 3 | 15 | 716 |
| 33 | `UIAlertAction` | 18 | 28% | 4 | 14 | 563 |
| 34 | `UITableViewCell` | 18 | 28% | 3 | 15 | 478 |
| 35 | `UIAlertController` | 18 | 28% | 4 | 14 | 286 |
| 36 | `UIBezierPath` | 17 | 26% | 13 | 4 | 89 |
| 37 | `UIGestureRecognizer` | 16 | 25% | 10 | 6 | 139 |
| 38 | `UIGraphicsImageRenderer` | 16 | 25% | 12 | 4 | 47 |
| 39 | `UIEvent` | 15 | 23% | 7 | 8 | 92 |
| 40 | `UITouch` | 15 | 23% | 7 | 8 | 79 |
<!-- /generated:uikit -->

### UIKit: member

Member được gắn về kiểu UIKit qua khai báo biến (`let label = UILabel()`), qua `self`, `super` và lời gọi không có receiver bên trong lớp con, và qua truy cập tĩnh (`UIApplication.shared`). Member do app tự khai báo, kể cả trong extension của kiểu UIKit, không được tính.

<!-- generated:uikit-members -->
| # | API | App | % app | App SwiftUI (/50) | App UIKit (/15) | Lần dùng |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `UIApplication.shared` | 50 | 77% | 36 | 14 | 570 |
| 2 | `UIDevice.current` | 32 | 49% | 22 | 10 | 177 |
| 3 | `UIScreen.main` | 30 | 46% | 19 | 11 | 284 |
| 4 | `UIPasteboard.general` | 28 | 43% | 18 | 10 | 114 |
| 5 | `UIViewController.viewDidLoad` | 27 | 42% | 13 | 14 | 569 |
| 6 | `UIFont.systemFont` | 27 | 42% | 15 | 12 | 256 |
| 7 | `UIApplication.openSettingsURLString` | 26 | 40% | 18 | 8 | 49 |
| 8 | `UIView.addSubview` | 25 | 38% | 11 | 14 | 885 |
| 9 | `UIView.bounds` | 24 | 37% | 9 | 15 | 145 |
| 10 | `UIWindow.rootViewController` | 24 | 37% | 13 | 11 | 45 |
| 11 | `UIView.backgroundColor` | 23 | 35% | 9 | 14 | 534 |
| 12 | `UIViewController.view` | 21 | 32% | 10 | 11 | 483 |
| 13 | `UIView.init` | 21 | 32% | 9 | 12 | 157 |
| 14 | `UISceneSession.role` | 21 | 32% | 14 | 7 | 40 |
| 15 | `UILabel.text` | 20 | 31% | 6 | 14 | 761 |
| 16 | `UIViewController.viewWillAppear` | 20 | 31% | 7 | 13 | 245 |
| 17 | `UIColor.clear` | 20 | 31% | 12 | 8 | 179 |
| 18 | `UIColor.white` | 20 | 31% | 12 | 8 | 166 |
| 19 | `UIViewController.present` | 19 | 29% | 7 | 12 | 285 |
| 20 | `UIView.animate` | 19 | 29% | 8 | 11 | 154 |
| 21 | `UIImageView.image` | 19 | 29% | 5 | 14 | 148 |
| 22 | `UIViewController.viewDidAppear` | 19 | 29% | 8 | 11 | 137 |
| 23 | `UIView.frame` | 19 | 29% | 8 | 11 | 118 |
| 24 | `UIWindow.makeKeyAndVisible` | 19 | 29% | 10 | 9 | 21 |
| 25 | `UIAlertController.addAction` | 18 | 28% | 4 | 14 | 446 |
| 26 | `NSLayoutConstraint.activate` | 18 | 28% | 11 | 7 | 311 |
| 27 | `UIView.layer` | 18 | 28% | 6 | 12 | 225 |
| 28 | `UIViewController.init` | 18 | 28% | 8 | 10 | 180 |
| 29 | `UIFont.preferredFont` | 18 | 28% | 12 | 6 | 151 |
| 30 | `UIImage.size` | 18 | 28% | 14 | 4 | 55 |
<!-- /generated:uikit-members -->

### QuartzCore

<!-- generated:quartzcore -->
| # | API | App | % app | App SwiftUI (/50) | App UIKit (/15) | Lần dùng |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `CAMediaTimingFunction` | 8 | 12% | 4 | 4 | 29 |
| 2 | `CALayer` | 8 | 12% | 4 | 4 | 27 |
| 3 | `CACurrentMediaTime` | 8 | 12% | 6 | 2 | 25 |
| 4 | `CABasicAnimation` | 7 | 11% | 3 | 4 | 42 |
| 5 | `CAGradientLayer` | 7 | 11% | 4 | 3 | 36 |
| 6 | `CAShapeLayer` | 6 | 9% | 2 | 4 | 77 |
| 7 | `CATransaction` | 6 | 9% | 4 | 2 | 58 |
| 8 | `CADisplayLink` | 6 | 9% | 5 | 1 | 31 |
| 9 | `CAFrameRateRange` | 4 | 6% | 4 | 0 | 7 |
| 10 | `CAKeyframeAnimation` | 4 | 6% | 2 | 2 | 7 |
<!-- /generated:quartzcore -->

### Framework được import

Cột "Kế hoạch" cho biết plan phủ module đó ở đâu trên Linux. Nhóm "shim nhỏ" là phân loại của báo cáo này, plan chưa có task cho nó. Module của macOS, watchOS và tvOS chỉ có trong target không build cho iOS.

<!-- generated:frameworks -->
| # | Module | Kế hoạch | App | % app | File import |
| --- | --- | --- | --- | --- | --- |
| 1 | `Foundation` | có sẵn trong toolchain | 64 | 98% | 4644 |
| 2 | `SwiftUI` | OpenKit (P1-13, P1-16) | 56 | 86% | 4898 |
| 3 | `UIKit` | OpenKit (P1-13, P1-16) | 53 | 82% | 2306 |
| 4 | `Combine` | P1-17 | 38 | 58% | 454 |
| 5 | `WidgetKit` | chưa có kế hoạch, stub ở P1-18 | 28 | 43% | 223 |
| 6 | `UniformTypeIdentifiers` | shim nhỏ, chưa có task | 28 | 43% | 80 |
| 7 | `StoreKit` | P1-17 | 23 | 35% | 67 |
| 8 | `UserNotifications` | P1-17 | 22 | 34% | 68 |
| 9 | `os` | shim nhỏ, chưa có task | 21 | 32% | 161 |
| 10 | `AVFoundation` | overlay adapter (E2-10) | 18 | 28% | 126 |
| 11 | `WebKit` | overlay adapter (E2-10) | 18 | 28% | 78 |
| 12 | `SafariServices` | overlay adapter (E2-10) | 18 | 28% | 37 |
| 13 | `CoreGraphics` | OpenKit (P1-13, P1-16) | 18 | 28% | 32 |
| 14 | `CoreData` | E2-05 | 17 | 26% | 165 |
| 15 | `OSLog` | shim nhỏ, chưa có task | 16 | 25% | 129 |
| 16 | `AppIntents` | chưa có kế hoạch, stub ở P1-18 | 16 | 25% | 101 |
| 17 | `CryptoKit` | shim nhỏ, chưa có task | 16 | 25% | 27 |
| 18 | `SwiftData` | E2-05 | 15 | 23% | 334 |
| 19 | `Observation` | có sẵn trong toolchain | 15 | 23% | 130 |
| 20 | `CoreLocation` | P1-17 | 14 | 22% | 216 |
| 21 | `AppKit` | macOS/watchOS/tvOS, không build cho iOS | 14 | 22% | 214 |
| 22 | `Charts` | hướng 4, chưa có task | 14 | 22% | 42 |
| 23 | `MapKit` | overlay adapter (E2-10) | 13 | 20% | 64 |
| 24 | `AuthenticationServices` | chưa có kế hoạch, stub ở P1-18 | 12 | 18% | 25 |
| 25 | `Intents` | chưa có kế hoạch, stub ở P1-18 | 12 | 18% | 15 |
| 26 | `MessageUI` | chưa có kế hoạch, stub ở P1-18 | 10 | 15% | 14 |
| 27 | `MobileCoreServices` | shim nhỏ, chưa có task | 10 | 15% | 12 |
| 28 | `AVKit` | overlay adapter (E2-10) | 9 | 14% | 20 |
| 29 | `Network` | chưa có kế hoạch, stub ở P1-18 | 9 | 14% | 18 |
| 30 | `PhotosUI` | P1-17 | 8 | 12% | 23 |
| 31 | `ActivityKit` | chưa có kế hoạch, stub ở P1-18 | 8 | 12% | 21 |
| 32 | `LinkPresentation` | chưa có kế hoạch, stub ở P1-18 | 8 | 12% | 10 |
| 33 | `BackgroundTasks` | chưa có kế hoạch, stub ở P1-18 | 7 | 11% | 12 |
| 34 | `LocalAuthentication` | P1-17 | 7 | 11% | 12 |
| 35 | `ImageIO` | chưa có kế hoạch, stub ở P1-18 | 7 | 11% | 10 |
| 36 | `AudioToolbox` | chưa có kế hoạch, stub ở P1-18 | 7 | 11% | 8 |
| 37 | `Photos` | chưa có kế hoạch, stub ở P1-18 | 6 | 9% | 76 |
| 38 | `CloudKit` | chưa có kế hoạch, stub ở P1-18 | 6 | 9% | 36 |
| 39 | `CoreSpotlight` | chưa có kế hoạch, stub ở P1-18 | 6 | 9% | 19 |
| 40 | `CoreMotion` | chưa có kế hoạch, stub ở P1-18 | 6 | 9% | 17 |

Module Apple khác (83 module, kèm số app): `MediaPlayer` 6, `Security` 6, `CoreHaptics` 6, `CoreImage` 6, `TipKit` 5, `Vision` 4, `FoundationModels` 4, `Darwin` 4, `NaturalLanguage` 4, `WatchKit` 4, `AVFAudio` 4, `QuartzCore` 4, `XCTest` 4, `SceneKit` 3, `PDFKit` 3, `Contacts` 3, `Dispatch` 3, `SystemConfiguration` 3, `VideoToolbox` 3, `CoreText` 3, `SQLite3` 3, `EventKit` 2, `Metal` 2, `ApplicationServices` 2, `simd` 2, `CoreTransferable` 2, `NetworkExtension` 2, `RealityKit` 2, `WeatherKit` 2, `Cocoa` 2, `HealthKit` 2, `SpriteKit` 2, `Translation` 2, `Accelerate` 2, `QuickLook` 2, `Carbon` 2, `CoreML` 2, `IOKit` 2, `IntentsUI` 2, `NotificationCenter` 2, `ServiceManagement` 2, `FamilyControls` 1, `DeviceActivity` 1, `EventKitUI` 1, `CoreMedia` 1, `ManagedSettings` 1, `GameKit` 1, `PassKit` 1, `VisionKit` 1, `CoreVideo` 1, `FoundationNetworking` 1, `OpenGL` 1, `Swift` 1, `ClockKit` 1, `CoreNFC` 1, `CoreServices` 1, `PencilKit` 1, `Synchronization` 1, `ARKit` 1, `CarPlay` 1, `CoreAudio` 1, `CryptoTokenKit` 1, `JavaScriptCore` 1, `OpenGLES` 1, `SystemExtensions` 1, `AppClip` 1, `CallKit` 1, `GameplayKit` 1, `MachO` 1, `ManagedSettingsUI` 1, `MediaAccessibility` 1, `MetricKit` 1, `ObjectiveC` 1, `Playgrounds` 1, `RealityKitContent` 1, `RegexBuilder` 1, `ScreenCaptureKit` 1, `Social` 1, `Speech` 1, `TVServices` 1, `UserNotificationsUI` 1, `_PassKit_SwiftUI` 1, `dnssd` 1.

Module không thuộc SDK Apple (module của chính app hoặc thư viện): 558 module; nhiều app nhất: `NukeUI` 6, `Alamofire` 6, `SDWebImage` 6, `SnapKit` 5, `Nuke` 5, `ComposableArchitecture` 4, `DesignSystem` 4, `SVProgressHUD` 4, `KeychainSwift` 4, `SwiftSoup` 4, `WhatsNewKit` 4, `Sparkle` 4.
<!-- /generated:frameworks -->

### Objective-C trong code Swift

Linux không có ObjC runtime. Cột "Linux" là kết quả chạy `swiftc` 6.4.1 trong container trên từng đoạn code nhỏ:

| Cấu trúc | Đoạn code thử | Kết quả |
| --- | --- | --- |
| `@objc`, `@objcMembers` | `class A { @objc func f() {} }` | lỗi: `Objective-C interoperability is disabled` |
| `#selector` | `let s = #selector(A.f)` | lỗi: `'#selector' can only be used with the Objective-C runtime` |
| `#keyPath` | `let k = #keyPath(A.x)` | lỗi: `'#keyPath' can only be used with the Objective-C runtime` |
| `Selector` | `let s = Selector("foo")` | lỗi: `cannot find 'Selector' in scope` |
| `@IBOutlet` | `@IBOutlet weak var v: NSObject!` | lỗi: `'@IBOutlet' property cannot have non-'@objc' class type` |
| KVO | `A().observe(\A.x) { _, _ in }`, `addObserver(_:forKeyPath:options:context:)` | lỗi: `value of type 'A' has no member 'observe'` (và `'addObserver'`) |
| `@NSManaged` | `@NSManaged var name: String` | compile được nhưng lỗi link: thiếu getter và setter, vốn do Core Data sinh lúc chạy |
| `@IBAction`, `@IBInspectable`, `@IBDesignable`, `@IBSegueAction`, `@NSCopying`, `dynamic`, lớp con của `NSObject` | | compile ra file object |

`@IBAction` compile được, nhưng storyboard vẫn nối action theo tên selector. Vì vậy bộ nạp storyboard của P1-16 phải tự tra action theo tên.

<!-- generated:objc -->
| Cấu trúc | Linux (Swift 6.4.1) | App | % app | SwiftUI (/50) | UIKit (/15) | Lần dùng / số file |
| --- | --- | --- | --- | --- | --- | --- |
| `NSObject subclass` | compile được | 55 | 85% | 42 | 13 | 453 |
| `#selector` | lỗi compile | 44 | 68% | 29 | 15 | 1427 |
| `@objc` | lỗi compile | 42 | 65% | 27 | 15 | 2991 |
| `@IBOutlet` | lỗi compile | 15 | 23% | 4 | 11 | 1561 |
| `KVO` | lỗi compile | 15 | 23% | 11 | 4 | 97 |
| `Selector` | lỗi compile | 14 | 22% | 9 | 5 | 79 |
| `@IBAction` | compile được | 10 | 15% | 3 | 7 | 451 |
| `#keyPath` | lỗi compile | 7 | 11% | 4 | 3 | 158 |
| `dynamic` | compile được | 7 | 11% | 4 | 3 | 94 |
| `@NSManaged` | lỗi link | 6 | 9% | 2 | 4 | 181 |
| `@IBInspectable` | compile được | 3 | 5% | 1 | 2 | 48 |
| `@objcMembers` | lỗi compile | 3 | 5% | 1 | 2 | 20 |
| `@IBDesignable` | compile được | 3 | 5% | 1 | 2 | 12 |
| Có cấu trúc lỗi trên Linux |  | 47 | 72% | 32 | 15 |  |
| File Objective-C (`.m`, `.mm`) |  | 6 | 9% | 1 | 5 | 187 |
| Bridging header |  | 6 | 9% | 2 | 4 |  |
| **Không cần ObjC** |  | 18 | 28% | 18 | 0 |  |
| **Chỉ cần viết lại bằng SwiftSyntax** (`@objc`, `@objcMembers`, `#selector`, `#keyPath`, `Selector`, `@IBOutlet`) |  | 27 | 42% | 19 | 8 |  |
| **Cần ObjC runtime hoặc Core Data** (KVO, `@NSManaged`, file `.m`/`.mm`, bridging header) |  | 20 | 31% | 13 | 7 |  |
| File C/C++ (`.c`, `.cc`, `.cpp`) |  | 3 | 5% | 2 | 1 | 3 |
<!-- /generated:objc -->

## Ý nghĩa với thứ tự làm P1-13, P1-16, P1-17

### P1-13: lõi SwiftUI

1. **Đợt đầu là các API có trong hơn một nửa số app:** 79 API có trong ít nhất 33 app (51%), 53 API có trong ít nhất 60% app. Layout: `VStack`, `HStack`, `ZStack`, `Spacer`, `.padding`, `.frame`, `GeometryReader`. Chữ và ảnh: `Text`, `.font`, `Image` với `.resizable`, `Color`. Control: `Button`, `TextField`, `Toggle`, `Picker`. Danh sách: `ForEach`, `List`, `Section`, `ScrollView`. Shape: `RoundedRectangle`, `Rectangle`, `Circle`, `.fill`, `.stroke`, `.clipShape`. Thêm `.background`, `.overlay`, `.opacity`, `.sheet`, `.onAppear`, `.onChange`, và `.modifier` với `ViewModifier`.
2. **State.** Làm `@State`, `@Binding`, `@ViewBuilder` và `@Environment` trước, với các khoá `\.dismiss` (31 app), `\.colorScheme` (28), `\.scenePhase` (25), `\.openURL` (18). Sau đó làm cả `ObservableObject` lẫn `@Observable`, vì 51 app dùng ít nhất một trong hai. `@FocusState` có trong 27 app, `@AppStorage` trong 24 app.
3. **Điều hướng và trình bày.** `NavigationStack` có trong 34 app, nhưng `NavigationView` đã cũ vẫn có trong 23 app, và 13 app chỉ dùng `NavigationView`. Phải làm cả hai, cùng `NavigationLink` (39 app), `.toolbar` (40), `.navigationTitle` (39), `.alert` (31), `.contextMenu` (29), `TabView` (24).
4. **Vòng đời app và animation.** `App`, `Scene`, `WindowGroup` có trong 45–46 app, `@UIApplicationDelegateAdaptor` trong 17 app. `withAnimation` và `.animation` có trong 44 app, `.transition` trong 35 app.
5. **API mới đến rất nhanh.** 18 app đã dùng API iOS 26, riêng `.glassEffect` có trong 17 app. Fork không thể dừng ở API của iOS 13–15, mà phải theo kịp bản SwiftUI mới.
6. **Preview.** 52 app (80%) có `#Preview` hoặc `PreviewProvider`. P1-12 phải bỏ được cả hai kiểu, và P1-19 dùng lại cả hai.

### P1-16: UIKit

UIKit không chỉ dành cho 15 app UIKit. Nên làm theo hai lớp:

1. **Kiểu không phải view, cần cho gần như mọi app SwiftUI.** `UIApplication` (`.shared` có trong 50 app, `openSettingsURLString` trong 26), `UIColor` 51 app, `UIImage` 50, `UIFont` 38, `UIDevice` 36, `UIScreen` 30, `UIPasteboard` 28, `UIImpactFeedbackGenerator` 22, và vòng đời scene (`UIWindowScene` 39, `UISceneSession` 23, `UIWindowSceneDelegate` 23). Phần này rẻ, nên làm cùng đợt với P1-13: thiếu nó thì app SwiftUI không compile được.
2. **Cây view.** `UIView` có trong 39 app, `UIViewController` trong 38 (`viewDidLoad` 27). `UIViewRepresentable` và `UIViewControllerRepresentable` mỗi loại có trong 31 app, `UIHostingController` trong 28. View hay được bọc nhất là `UIActivityViewController` (27 app, dùng cho share sheet), `UITextView` (21), `UIScrollView` (20), `UITextField` (20).

Danh sách trong P1-16 khớp với số đo: `UINavigationController` 25 app, `UILabel` 23, `UITableView` 22, `UIImageView` 22, `NSLayoutConstraint` 20, `UIButton` 18, `UIStackView` 12. Cả 15 app UIKit đều dùng `UITableView`, `UIButton` và `UIImageView`. Nên thêm vào P1-16: `UIAlertController` (18 app), `UIBarButtonItem` (19), `UITabBarController` (15), `UIActivityViewController`, `UITextField` và `UITextView`. `UICollectionView` có trong 13 app, để ở E2-01 như plan là hợp lý. Storyboard hoặc XIB có trong 20 app, 7 app trong số đó là app SwiftUI.

Target-action cần được ưu tiên. `#selector` có trong 44 app, nhiều hơn mọi framework trừ Foundation, SwiftUI và UIKit (Combine chỉ có trong 38 app). Viết lại `@objc` và `#selector` bằng SwiftSyntax (hướng 6 của plan, phần "trước mắt") nâng trần compile từ 18 lên 39 app. Không đợt framework nào lợi bằng. Nên tách việc này thành một task Phase 1, làm cùng P1-12 (pipeline đã đi qua SwiftSyntax) và P1-16 (`addTarget(_:action:for:)`, `UIBarButtonItem(target:action:)`, gesture recognizer, `NotificationCenter`).

### P1-17: framework đợt 1

1. **Thứ tự theo mức dùng:** Combine (38 app) → StoreKit (23) → UserNotifications (22) → CoreLocation (14) → PhotosUI (8) → LocalAuthentication (7) → Security/Keychain (6). Danh sách của P1-17 đúng. Combine nên đi đầu vì gắn với `ObservableObject`.
2. **Nên thêm vài shim nhỏ:** UniformTypeIdentifiers (28 app), `os` và `OSLog` (21 và 16 app, `Logger` chỉ cần ghi ra stderr), CryptoKit (16 app, swift-crypto có cùng API), MobileCoreServices (10 app).
3. **WidgetKit và AppIntents:** WidgetKit có trong 28 app, AppIntents trong 16 app, phần lớn nằm trong widget extension (27 app có `@main` trên `WidgetBundle` hoặc `Widget`). Ở local chỉ cần build target app. P1-12 bỏ qua extension, còn P1-18 sinh stub cho các lời gọi còn lại từ app, ví dụ `WidgetCenter`.
4. **Lưu trữ:** Core Data hoặc SwiftData có trong 30 app (46%), nhưng E2-05 nằm ở Phase 2. Có stub thì các app này compile được nhưng không lưu được dữ liệu. Nên cân nhắc kéo E2-05 lên sớm hơn.
5. **Overlay adapter (E2-10):** AVFoundation, WebKit và SafariServices mỗi framework có trong 18 app, MapKit trong 13 app. Charts có trong 14 app (22%) và chưa có task.

## Inventory build

Đọc từ file project, không build gì. Mỗi dòng cho biết bao nhiêu app vướng một khoảng trống, và task nào trong plan lo khoảng trống đó.

<!-- generated:inventory -->
| Khoảng trống | App | % app | Task trong plan |
| --- | --- | --- | --- |
| Có `.xcodeproj` (phải đọc `.pbxproj`) | 65 | 100% | P1-12 |
| Không commit `.xcodeproj`, sinh bằng XcodeGen/Tuist | 0 | 0% | P1-12 |
| Chỉ có `Package.swift` (không `.xcodeproj`) | 0 | 0% | P1-12 |
| Local package (app chia nhiều module) | 26 | 40% | P1-12 |
| Gói SPM bên thứ ba (không tính công cụ build/test) | 46 | 71% | P1-12, E2-04 |
| CocoaPods hoặc Carthage (không tính công cụ build/test) | 9 | 14% | chưa có task |
| Binary vendored (`.xcframework`, `.framework`) | 2 | 3% | P0-09, P1-05 |
| File Objective-C (`.m`, `.mm`) hoặc bridging header | 7 | 11% | P0-07, E2-03 |
| File C/C++ | 3 | 5% | clang trong P1-12 |
| Storyboard/XIB giao diện (không tính launch screen) | 20 | 31% | P1-16 |
| Chỉ có launch screen storyboard | 16 | 25% | P1-12 (bỏ qua được) |
| Asset catalog (`.xcassets`) | 65 | 100% | P1-12 |
| String Catalog (`.xcstrings`) | 21 | 32% | P1-12 |
| Bản địa hoá kiểu cũ (`.strings`) | 23 | 35% | P1-12 |
| Core Data model (`.xcdatamodeld`) | 15 | 23% | E2-05 |
| Cấu hình StoreKit (`.storekit`) | 8 | 12% | P1-17 |
| Metal shader (`.metal`) | 1 | 2% | chưa có kế hoạch |
| `#Preview` | 32 | 49% | P1-12, P1-19 |
| `PreviewProvider` (kiểu cũ) | 33 | 51% | P1-12, P1-19 |
| SF Symbols (`systemName:`, `systemImage:`) | 58 | 89% | bộ icon thay thế |
| Widget extension (`@main` trên `WidgetBundle`/`Widget`) | 27 | 42% | chưa có kế hoạch |
| Code macOS/watchOS trong cùng repo (import AppKit, WatchKit…) | 18 | 28% | P1-12 (chọn target iOS) |

| iOS deployment target cao nhất | App |
| --- | --- |
| iOS 13 | 4 |
| iOS 14 | 7 |
| iOS 15 | 10 |
| iOS 16 | 6 |
| iOS 17 | 14 |
| iOS 18 | 13 |
| iOS 26 | 11 |

| Swift language mode (`SWIFT_VERSION` cao nhất, hoặc tools-version) | App |
| --- | --- |
| Swift 5 | 49 |
| Swift 6 | 16 |
<!-- /generated:inventory -->

Deployment target là giá trị cao nhất trong mọi target, kể cả widget, nên có thể cao hơn của target app. Binary vendored chỉ có ở 2 app: LeitnerBox (xcframework FFmpeg) và OpenFind (xcframework Realm).

### Gói bên thứ ba

<!-- generated:dependencies -->
| # | Gói | Qua | App |
| --- | --- | --- | --- |
| 1 | `swiftui-introspect` | SPM | 7 |
| 2 | `nuke` | SPM | 6 |
| 3 | `alamofire` | CocoaPods, SPM | 5 |
| 4 | `keychain-swift` | SPM | 4 |
| 5 | `kingfisher` | CocoaPods, SPM | 4 |
| 6 | `snapkit` | CocoaPods, SPM | 4 |
| 7 | `sparkle` | SPM | 4 |
| 8 | `svprogresshud` | Carthage, CocoaPods, SPM | 4 |
| 9 | `swift-collections` | SPM | 4 |
| 10 | `swift-composable-architecture` | SPM | 4 |
| 11 | `swiftsoup` | SPM | 4 |
| 12 | `firebase-ios-sdk` | SPM | 3 |
| 13 | `keychainaccess` | CocoaPods, SPM | 3 |
| 14 | `marqueelabel` | SPM | 3 |
| 15 | `sdwebimage` | CocoaPods, SPM | 3 |
| 16 | `swift-dependencies` | SPM | 3 |
| 17 | `toast-swift` | CocoaPods, SPM | 3 |
| 18 | `whatsnewkit` | CocoaPods, SPM | 3 |
| 19 | `acknowlist` | CocoaPods, SPM | 2 |
| 20 | `cocoalumberjack` | CocoaPods, SPM | 2 |
| 21 | `confettiswiftui` | SPM | 2 |
| 22 | `corestore` | CocoaPods, SPM | 2 |
| 23 | `dgcharts` | CocoaPods | 2 |
| 24 | `dropdown` | CocoaPods | 2 |
| 25 | `factory` | SPM | 2 |

270 gói khác nhau, 214 gói chỉ 1 app dùng. Công cụ build/test, không tính ở bảng này và ở các bảng khác: `swiftlint` 5, `swift-snapshot-testing` 4, `viewinspector` 3, `swiftformat` 2, `swiftlintplugins` 2, `licenseplist` 1, `mocker` 1, `nimble` 1, `ohhttpstubs` 1, `quick` 1, `rxblocking` 1, `swiftgen` 1, `swiftlintplugin` 1.
<!-- /generated:dependencies -->

Gói dùng nhiều nhất là `swiftui-introspect` (7 app). Gói này đào xuống cây view UIKit nằm dưới view SwiftUI. Trên OpenKit không có cây đó, nên compat registry (E2-04) phải có một bản thay thế. Danh sách của E2-04 trong plan (Alamofire, Kingfisher, SnapKit, Lottie, Realm, Firebase, Stripe) nên thêm `swiftui-introspect`, Nuke, SVProgressHUD, TCA, KeychainSwift và SwiftSoup. Mỗi gói này có trong 4–7 app.

## Tỉ lệ compile

### Trần ước lượng theo import (đã đo)

Với mỗi app, tool liệt kê các rào chắn: framework Apple được import (gom theo task trong plan), mức phụ thuộc Objective-C, và CocoaPods hoặc Carthage (plan chưa có task). Một app được tính ở một mức khi mọi rào chắn của nó đã được phủ ở mức đó. Đây là trần, không phải dự báo: cách tính coi như OpenKit đã có mọi API SwiftUI và UIKit mà app dùng, và các gói SPM bên thứ ba build được trên Linux. Module của target macOS, watchOS và tvOS không bao giờ chặn, vì bản build iOS không có chúng.

<!-- generated:readiness -->
| Mức phủ (cộng dồn) | App | % app | Trong đó cần gói SPM bên thứ ba |
| --- | --- | --- | --- |
| 1. SwiftUI, UIKit, Foundation và shim nhỏ (os, CryptoKit, UTType…), không dùng ObjC | 0 | 0% | 0 |
| 2. + framework đợt 1 (P1-17: Combine, StoreKit, PhotosUI, CoreLocation…) | 0 | 0% | 0 |
| 3. + stub cho mọi framework Apple còn lại (P1-18), kể cả SwiftData, MapKit, WebKit | 18 | 28% | 13 |
| 4. + viết lại `@objc`, `#selector`, `#keyPath`, `@IBOutlet` bằng SwiftSyntax | 39 | 60% | 26 |
| Còn lại: cần ObjC runtime/Core Data (KVO, `@NSManaged`, file `.m`) hoặc CocoaPods/Carthage | 26 | 40% |  |
| Đối chiếu: như mức 4 nhưng không có stub, E2-05, E2-10 và Charts làm thật | 7 | 11% | 3 |
<!-- /generated:readiness -->

- Mức 1 và 2 bằng 0, vì app nào cũng import ít nhất một framework ngoài phần đó. Chỉ tính framework (bỏ qua ObjC và CocoaPods), vẫn chỉ có 1 app ở mức 1, 3 app ở mức 2, và 11 app khi đã làm thật E2-05, E2-10 và Charts. Vì vậy stub ở P1-18 quyết định có tỉ lệ compile hay không.
- Ở mức 4 có 39 app, trong đó 26 app còn cần gói SPM bên thứ ba build được trên Linux (E2-04).
- 26 app còn lại: 17 app chỉ vướng ObjC runtime hoặc Core Data, 6 app chỉ vướng CocoaPods hoặc Carthage, 3 app vướng cả hai. Trong 20 app cần ObjC runtime, 10 app chỉ vì KVO, 3 app vì `@NSManaged`, 7 app có file `.m`/`.mm` hoặc bridging header.

### Compile thật với OpenKit (chưa đo)

<!-- generated:compile -->
_Chưa có số: `ios-corpus compile` chưa được chạy với OpenKit (chờ P0-05)._
<!-- /generated:compile -->

Bước này chờ P0-05, task đang làm song song. Sáng 15/10, `runtimes/ios` có thêm `Scripts/compile-app.sh <thư mục app> [tuỳ chọn swift build]`. Script này là bước compile mà corpus gọi cho từng app. Khi P0-05 xong, chạy trong cùng container Swift 6.4.1:

```sh
cd tools/ios-corpus
ios=$W/build/release/ios-corpus
$ios compile corpus.json $W/apps $W/out ../../runtimes/ios/Scripts/compile-app.sh
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md
```

Quy ước giữa hai bên:

- `ios-corpus compile` chạy `<lệnh> <thư mục app>` lần lượt cho từng app, với thư mục app là tham số cuối. Vì vậy không truyền thêm tham số nào sau tên script. Exit 0 nghĩa là compile được.
- Output của từng app ghi vào `$W/out/compile/<id>.log`. Kết quả gộp (`ok`, số giây) ghi vào `$W/out/compile.json`. Sau đó `analyze` điền bảng ở trên.
- Script cần các checkout của P0-05 (`Scripts/fetch-openswiftui.sh`, mặc định ở `~/.cache/irisrun/p0-05`). Mọi app dùng chung một thư mục build, nên OpenSwiftUI chỉ phải compile một lần.

Đã chạy thử đường nối này với một lệnh giả (`sh -c 'test -d "$0/.git"'`): ra đủ 65 log, `compile.json` và bảng compile. Lần thử đó ghi vào một thư mục riêng, nên `$W/out` không có `compile.json` giả.

Nên đọc số đầu tiên đúng như nó đo. Bản script hiện tại gom mọi file Swift trong checkout vào một module (trừ test, `Pods`, `Carthage`), bỏ `#Preview`, rồi alias `SwiftUI` sang OpenSwiftUI và `Observation` sang OpenObservation. Theo dữ liệu ở trên, mọi app đều import thêm UIKit, Combine, một framework khác hoặc một gói bên thứ ba. 27 app còn có widget extension, nên một module sẽ có hai `@main`. Kết quả dự kiến là 0/65 cho tới khi có ít nhất: kiểu UIKit không phải view, Combine, stub của P1-18, và bước chọn target của P1-12.

## SF Symbols

License của Apple không cho dùng SF Symbols trên máy không phải của Apple. Bộ icon thay thế cần phủ các tên dưới đây.

<!-- generated:sfsymbols -->
| Chỉ số | Giá trị |
| --- | --- |
| App dùng SF Symbols | 58 (89%) |
| Tên symbol khác nhau (chuỗi literal) | 741 |
| Lần gọi với tên không phải literal | 995 |
| Phổ biến nhất (số app) | `trash` 33, `checkmark` 27, `xmark` 27, `ellipsis` 24, `plus` 23, `chevron.right` 22, `pencil` 22, `checkmark.circle.fill` 21, `chevron.down` 21, `magnifyingglass` 21, `square.and.arrow.up` 20, `xmark.circle.fill` 18, `gear` 18, `calendar` 17, `gearshape` 16 |
<!-- /generated:sfsymbols -->

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Danh sách 65 app: repo, commit, license, tag, lý do chọn | `tools/ios-corpus/corpus.json` |
| Ba lệnh `fetch`, `analyze`, `compile`; checkout nông, blobless, sparse | `tools/ios-corpus/Sources/IOSCorpus/IOSCorpus.swift` |
| Inventory build: project, package manager, số file theo loại | `Inventory.swift` |
| Quét cú pháp bằng SwiftSyntax 604 | `Scanner.swift` |
| Quy tên về SwiftUI và UIKit theo từng app, mức phụ thuộc ObjC | `Analysis.swift` |
| Danh mục API viết tay, trạng thái ObjC đã đo trên Linux, công cụ build/test | `Catalog.swift` |
| Các bảng trong báo cáo, ghi đè khối được sinh | `Report.swift` |
| Test cho scanner và cách quy tên | `Tests/IOSCorpusTests/ScannerTests.swift` |

Lần chạy đầu tiên lộ ra một số chỗ sai, đã sửa trong lần này:

- Trước đây mọi cấu trúc ObjC đều bị coi là rào chắn, kể cả lớp con của `NSObject` (55 app) và `dynamic`, trong khi hai thứ đó compile được trên Linux. Giờ mỗi cấu trúc mang trạng thái đã đo, và app được chia thành ba mức: không cần ObjC, chỉ cần viết lại, cần runtime.
- Điều kiện `#if` từng bị quét như code, nên `UIKit` trong `#if canImport(UIKit)` bị đếm là một kiểu UIKit (10 app), còn `DEBUG`, `os` và `canImport` lọt vào danh sách tên. Giờ tool bỏ qua điều kiện, chỉ quét code trong các nhánh.
- Tên attribute giữ cả tham số generic và tên module (`FocusState<UUID?>`, `SwiftUI.State`). Giờ được chuẩn hoá về `FocusState` và `State`.
- Danh mục thiếu tên thật: `GridItem` (27 app), `.modifier` (45), `ObservableObject` (34), method của gesture, `Path`, `Font`, `Animation`, `AnyTransition`, `GlassEffectContainer`, `NSTextAlignment`. `@Parameter` và `@Property` là của AppIntents, `@Generable` của FoundationModels, `@Animatable` là macro iOS 26 của SwiftUI. `withAnimation` giờ được tính là hàm, không còn là modifier. 17 module Apple từng bị coi là thư viện bên thứ ba, ví dụ `SQLite3`, `simd`, `PassKit`, `VideoToolbox`, `ScreenCaptureKit`.
- SwiftLint, snapshot testing, ViewInspector và các công cụ build/test khác không còn được tính là phụ thuộc. Trước đó một app bị coi là dùng CocoaPods chỉ vì pod SwiftLint.
- Thư mục `scripts`, `fastlane` và `BuildTools` không còn bị quét. Riêng ai-dictation có 20 script dòng lệnh, và fastlane có `SnapshotHelper.swift` dùng `@objcMembers`.

## Chạy lại

```sh
W=~/.cache/irisrun/ios-corpus
cd tools/ios-corpus
swift build -c release -j 6 --scratch-path $W/build
ios=$W/build/release/ios-corpus
$ios fetch corpus.json $W/apps          # 4,5 phút, 523 MB; chạy lại nếu mạng lỗi
$ios analyze corpus.json $W/apps $W/out --report ../../docs/reports/p0-08-ios-corpus.md   # 14 s
swift test --scratch-path $W/build-test
```

Trên máy này mọi lệnh trên chạy trong image `irisrun-swift-dev:6.4.1` (gốc `swift:6.4.1-noble`), với `$HOME` được mount vào container. Build release lần đầu mất 527 s. Test phải dùng scratch path riêng: nếu dùng chung với bản release, swift-build sẽ build lại swift-syntax ở lần build release tiếp theo (990 s so với 34 s).

`analyze` ghi `$W/out/results.json` (inventory và số lần dùng của từng app) và `$W/out/tables.md` (mọi bảng, kèm danh sách tên chưa quy được để bổ sung `Catalog.swift`). Với `--report`, lệnh này ghi đè các khối được sinh trong báo cáo này. Phần chữ viết tay phải đọc lại mỗi khi số thay đổi.

Thử lại kết quả ObjC trên Linux:

```sh
cd "$(mktemp -d)"
probe() { printf 'import Foundation\n%s\n' "$2" > "$1.swift"; echo "$1: $(swiftc -c "$1.swift" -o "$1.o" 2>&1 | grep -m1 error: || echo ok)"; }
probe objc 'class A { @objc func f() {} }'
probe selector 'class A { func f() {} }; let s = #selector(A.f)'
probe keypath 'class A: NSObject { var x = 0 }; let k = #keyPath(A.x)'
probe selector_type 'let s = Selector("foo")'
probe iboutlet 'class A: NSObject { @IBOutlet weak var v: NSObject! }'
probe kvo 'class A: NSObject { var x = 0 }; let o = A().observe(\A.x) { _, _ in }'
probe ibaction 'class A: NSObject { @IBAction func tap(_ sender: Any) {} }'
probe dynamic 'class A { dynamic var x = 0 }'
printf 'import Foundation\nclass A: NSObject { @NSManaged var name: String }\nprint(A().name)\n' > m.swift
swiftc m.swift -o m   # lỗi link: undefined reference tới getter của name
```

## Giới hạn của phương pháp

1. Tool chỉ parse, không type-check. Tên được quy về SwiftUI hay UIKit theo danh mục viết tay và theo những gì app tự khai báo. Kiểu của biến chỉ biết khi có trong khai báo. Member viết tắt bằng dấu chấm (`.font(.title)`, `.transition(.opacity)`) không được tính, nên member tĩnh của `Font`, `Animation`, `AnyTransition` gần như không xuất hiện.
2. Mọi file Swift trong repo đều được tính, trừ test (thư mục có tên kết thúc bằng `Tests`, file `*Tests.swift`) và script build. Vì vậy số liệu gồm cả widget extension, target macOS/watchOS, thư mục lưu trữ cũ và app demo của từng module. Xác định file nào thuộc target nào là việc của P1-12. Code trong mọi nhánh `#if` đều được tính.
3. Tên SwiftUI chỉ được tính trong file có `import SwiftUI`; riêng `ObservableObject` được tính cả khi file chỉ import Combine. App re-export SwiftUI qua module riêng (`@_exported import SwiftUI`) hoặc qua WidgetKit sẽ bị đếm thiếu.
4. Danh mục API được viết tay từ tài liệu công khai, không lấy từ file nào trong SDK của Apple, nên có thể còn sót tên. Khối "unattributed" trong `tables.md` liệt kê các tên dùng nhiều mà danh mục chưa có.
5. Trần tỉ lệ compile chỉ dựa trên import, mức dùng ObjC và package manager. Nó không xét API cụ thể, không xét gói bên thứ ba có build được trên Linux không, và không xét API C chỉ có trên Darwin.
6. Trạng thái ObjC được đo trên đoạn code nhỏ, không trên chính các app. KVO qua Combine (`publisher(for: \.x)`) không được nhận ra; chỉ 1 app dùng cách này, và app đó đã nằm trong nhóm cần runtime.
7. CocoaPods và Carthage được đọc từ `Podfile` và `Cartfile` bằng regex. Gói SPM được đọc từ `repositoryURL` trong `.pbxproj` và từ `.package(url:)` trong `Package.swift`.
8. Corpus có thiên lệch: app được chọn tay, nghiêng về app còn được bảo trì và app lớn. Với 65 app, mỗi app là khoảng 1,5%.

## Phụ lục: từng app

Cột ObjC: "không" là không cần ObjC, "viết lại" là chỉ cần viết lại bằng SwiftSyntax, "runtime" là cần ObjC runtime hoặc Core Data. Cột SPM và Pods/Carthage không tính công cụ build/test.

<!-- generated:apps -->
| App | UI | File | Dòng | Project | iOS | Swift | SPM | Pods/Carthage | ObjC | `.m`/`.mm` | Storyboard/XIB | `.xcassets` | `.xcstrings` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ice-cubes | swiftui | 395 | 41549 | xcodeproj | 18.5 | 6.0 | 14 | 0 | viết lại | 0 | 0 | 5 | 1 |
| mlem | swiftui | 1176 | 90442 | xcodeproj | 26.0 | 5.0 | 10 | 0 | runtime | 0 | 0 | 3 | 3 |
| icysky | swiftui | 76 | 4099 | xcodeproj | 26.0 | 6.0 | 4 | 0 | viết lại | 0 | 0 | 3 | 0 |
| critical-maps | swiftui | 138 | 11466 | xcodeproj | 17.6 | 6.0 | 4 | 0 | viết lại | 0 | 0 | 3 | 1 |
| thunderbird | swiftui | 196 | 16340 | xcodeproj | 18.0 | 6.0 | 9 | 0 | không | 0 | 0 | 1 | 0 |
| foundation-chat | swiftui | 15 | 569 | xcodeproj | 26.0 | 5.0 | 1 | 0 | không | 0 | 0 | 1 | 0 |
| clendar | swiftui | 129 | 9267 | xcodeproj | 15.0 | 5.0 | 12 | 3 | viết lại | 0 | 2 | 5 | 2 |
| oscar-weather | swiftui | 357 | 48613 | xcodeproj | 26.0 | 6.0 | 5 | 0 | runtime | 0 | 0 | 6 | 7 |
| sky-wizard | swiftui | 69 | 3223 | xcodeproj | 18.0 | 5.0 | 4 | 0 | viết lại | 0 | 0 | 4 | 0 |
| harbour | swiftui | 210 | 17552 | xcodeproj | 18.0 | 6.0 | 3 | 0 | không | 0 | 0 | 4 | 3 |
| zeitgeist | swiftui | 77 | 8343 | xcodeproj | 17.6 | 5.0 | 2 | 0 | không | 0 | 0 | 2 | 1 |
| enchanted | swiftui | 87 | 6936 | xcodeproj | 17.0 | 5.0 | 9 | 0 | viết lại | 0 | 0 | 2 | 0 |
| gisthub | swiftui | 491 | 20832 | xcodeproj | 16.0 | 5.0 | 16 | 0 | viết lại | 0 | 0 | 2 | 0 |
| dime | swiftui | 94 | 28144 | xcodeproj | 15.0 | 5.0 | 7 | 0 | viết lại | 0 | 1 | 3 | 0 |
| inpenso | swiftui | 43 | 7958 | xcodeproj | 18.4 | 5.0 | 0 | 0 | viết lại | 0 | 0 | 2 | 0 |
| easy-crypto | swiftui | 94 | 4319 | xcodeproj | 16.0 | 5.0 | 0 | 0 | viết lại | 0 | 0 | 2 | 0 |
| go-cycling | swiftui | 83 | 8577 | xcodeproj | 15.0 | 5.0 | 1 | 0 | runtime | 0 | 0 | 2 | 0 |
| moodsnap | swiftui | 99 | 10009 | xcodeproj | 15.4 | 5.0 | 2 | 0 | không | 0 | 0 | 2 | 0 |
| pulse | swiftui | 68 | 6481 | xcodeproj | 26.6 | 5.0 | 0 | 0 | không | 0 | 0 | 1 | 2 |
| solstice | swiftui | 110 | 14462 | xcodeproj | 26.2 | 5.0 | 3 | 0 | viết lại | 0 | 0 | 3 | 5 |
| pilgrim | swiftui | 465 | 74567 | xcodeproj | 18.0 | 5.0 | 2 | 5 | viết lại | 0 | 0 | 2 | 0 |
| pompaddo | swiftui | 89 | 11730 | xcodeproj | 26.0 | 6.2 | 2 | 0 | không | 0 | 0 | 7 | 3 |
| foqos | swiftui | 218 | 28649 | xcodeproj | 18.5 | 5.0 | 2 | 0 | không | 0 | 0 | 5 | 0 |
| make-it-so | swiftui | 17 | 1642 | xcodeproj | 15.0 | 5.0 | 2 | 0 | không | 0 | 0 | 1 | 0 |
| ai-dictation | swiftui | 138 | 58552 | xcodeproj | 17.0 | 5.0 | 5 | 0 | viết lại | 0 | 0 | 2 | 0 |
| fingerspelling | swiftui | 21 | 1857 | xcodeproj | 13.2 | 5.0 | 0 | 0 | viết lại | 0 | 0 | 2 | 0 |
| detext | swiftui | 13 | 1009 | xcodeproj | 26.0 | 6.0 | 0 | 0 | không | 0 | 0 | 2 | 0 |
| leitnerbox | swiftui | 85 | 7107 | xcodeproj | 16.0 | 5.0 | 0 | 0 | viết lại | 0 | 1 | 3 | 0 |
| swiftui-2048 | swiftui | 48 | 2576 | xcodeproj | 15.0 | 5.0 | 0 | 0 | không | 0 | 0 | 2 | 0 |
| isowords | swiftui | 296 | 30185 | xcodeproj | 17.0 | 5.0 | 16 | 0 | runtime | 0 | 0 | 11 | 0 |
| construct | swiftui | 271 | 43861 | xcodeproj | 18.6 | 5.9 | 21 | 0 | không | 0 | 0 | 4 | 0 |
| swiftfin | swiftui | 789 | 80183 | xcodeproj | 18.6 | 5.0 | 26 | 0 | runtime | 0 | 0 | 3 | 0 |
| yattee | swiftui | 480 | 150466 | xcodeproj | 18.0 | 5.0 | 3 | 0 | runtime | 1 | 0 | 1 | 1 |
| movie-swiftui | swiftui | 103 | 7345 | xcodeproj | 14.0 | 5.0 | 1 | 0 | runtime | 0 | 0 | 4 | 0 |
| spotify-clone | swiftui | 140 | 9582 | xcodeproj | 14.5 | 5.0 | 0 | 2 | runtime | 0 | 0 | 2 | 0 |
| nytimes | swiftui | 24 | 1344 | xcodeproj | 14.0 | 5.0 | 3 | 0 | runtime | 0 | 0 | 2 | 0 |
| hipstapaper | swiftui | 131 | 11378 | xcodeproj | 17.0 | 6.0 | 2 | 0 | runtime | 0 | 2 | 1 | 0 |
| hackers | swiftui | 101 | 19041 | xcodeproj | 26.0 | 6.4 | 1 | 0 | runtime | 0 | 1 | 3 | 0 |
| scan-now | swiftui | 31 | 1669 | xcodeproj | 18.2 | 5.0 | 0 | 0 | viết lại | 0 | 0 | 2 | 0 |
| openfind | swiftui | 833 | 85840 | xcodeproj | 15.4 | 5.0 | 4 | 0 | runtime | 0 | 51 | 27 | 0 |
| backyard-birds | swiftui | 111 | 6976 | xcodeproj | 17.2 | 5.0 | 0 | 0 | không | 0 | 0 | 6 | 11 |
| food-truck | swiftui | 81 | 8545 | xcodeproj | 16.4 | 5.0 | 0 | 0 | không | 0 | 0 | 4 | 0 |
| clean-architecture-swiftui | swiftui | 36 | 2380 | xcodeproj | 18.1 | 5.0 | 1 | 0 | không | 0 | 0 | 2 | 1 |
| milestones | swiftui | 21 | 1068 | xcodeproj | 14.2 | 5.0 | 2 | 0 | không | 0 | 0 | 3 | 0 |
| betterblue | swiftui | 89 | 27684 | xcodeproj | 26.0 | 6.0 | 1 | 0 | runtime | 0 | 0 | 5 | 0 |
| basic-car-maintenance | swiftui | 58 | 5244 | xcodeproj | 26.0 | 5.0 | 1 | 0 | không | 0 | 0 | 3 | 1 |
| pet-note | swiftui | 90 | 6736 | xcodeproj | 17.5 | 6.0 | 3 | 0 | viết lại | 0 | 0 | 3 | 1 |
| ac-helper | swiftui | 206 | 16478 | xcodeproj | 14.0 | 5.0 | 5 | 0 | không | 0 | 0 | 6 | 0 |
| reddit-swiftui | swiftui | 37 | 1578 | xcodeproj | 13.0 | 5.0 | 1 | 0 | viết lại | 0 | 2 | 8 | 0 |
| swift-radio-pro | swiftui | 64 | 4741 | xcodeproj | 17.0 | 6.0 | 4 | 0 | viết lại | 0 | 0 | 1 | 1 |
| wikipedia | uikit | 1238 | 187757 | xcodeproj | 17.6 | 5.0 | 4 | 0 | runtime | 165 | 71 | 5 | 0 |
| netnewswire | uikit | 595 | 89681 | xcodeproj | 17.0 | 6.2 | 4 | 0 | runtime | 10 | 44 | 3 | 16 |
| bark | uikit | 128 | 12372 | xcodeproj | 17.0 | 5.0 | 1 | 21 | runtime | 0 | 2 | 2 | 1 |
| zlgithubclient | uikit | 249 | 36845 | xcodeproj | 14.0 | 5.0 | 0 | 28 | runtime | 9 | 4 | 2 | 0 |
| off-day | uikit | 99 | 14970 | xcodeproj | 16.6 | 5.0 | 7 | 0 | viết lại | 0 | 0 | 1 | 2 |
| swifthub | uikit | 187 | 21069 | xcodeproj | 15.0 | 5.0 | 0 | 42 | viết lại | 0 | 23 | 2 | 0 |
| pass | uikit | 110 | 9998 | xcodeproj | 13.0 | 5.0 | 10 | 0 | runtime | 1 | 11 | 3 | 0 |
| metax | uikit | 85 | 13805 | xcodeproj | 17.6 | 6.0 | 0 | 0 | viết lại | 0 | 0 | 1 | 2 |
| jotify | uikit | 60 | 6823 | xcodeproj | 14.0 | 5.0 | 0 | 8 | viết lại | 0 | 1 | 2 | 0 |
| authenticator | uikit | 44 | 5615 | xcodeproj | 16.0 | 5.0 | 0 | 2 | viết lại | 0 | 1 | 1 | 0 |
| say-their-names | uikit | 134 | 10897 | xcodeproj | 13.2 | 5.0 | 0 | 2 | viết lại | 0 | 2 | 2 | 0 |
| feeds4u | uikit | 85 | 10732 | xcodeproj | 18.0 | 6.0 | 4 | 0 | runtime | 0 | 4 | 2 | 1 |
| clean-architecture-mvvm | uikit | 70 | 3117 | xcodeproj | 15.0 | 5.0 | 0 | 0 | viết lại | 0 | 5 | 1 | 0 |
| racerunner | uikit | 76 | 7319 | xcodeproj | 17.0 | 5.0 | 4 | 0 | runtime | 1 | 2 | 1 | 0 |
| chess | uikit | 9 | 1328 | xcodeproj | 15.0 | 5.0 | 0 | 0 | viết lại | 0 | 1 | 1 | 0 |
<!-- /generated:apps -->
