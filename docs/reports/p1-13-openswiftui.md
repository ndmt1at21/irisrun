# P1-13 · Mở rộng OpenSwiftUI (đang làm)

Task XL, chia đợt theo bảng xếp hạng API của P0-08; kế hoạch các đợt ở mục "Kế hoạch P1-13" của [progress.md](../progress.md). Báo cáo này ghi từng đợt khi xong. Máy dev WSL2 Ubuntu 20.04, Swift 6.4.1 trong container `irisrun-swift-dev:6.4.1`, bản debug.

Phần "host IrisProtocol thật chạy RunLoop" của task đã làm ở P1-15 (patch 0013), cùng `ScrollView`, `TextField`, `@FocusState` (patch 0011, 0012); xem [p1-15-ios-input.md](p1-15-ios-input.md).

## Đợt 1 · Vẽ nốt display list bằng render core (15/10/2026)

### Kết luận

- **App dùng shape, nét viền, gradient, bóng đổ, chữ nhiều kiểu và ảnh từ asset catalog giờ vẽ ra đúng, thay vì crash hoặc mất nội dung.** Trước đợt này, trên Linux (và cả upstream trên mọi nền tảng) `Path` dựng bằng tay, `.stroke()` trên bất kỳ shape nào, tô bằng paint không phải một màu, và `Image("tên")` đều crash hoặc không vẽ gì.
- App mẫu có thêm `ProfileCard` ở màn đã đăng nhập (avatar tô `LinearGradient`, vòng `trim` có đầu bo, chữ "đăng nhập" đậm nghiêng và "Telex" gạch chân trong `Text + Text`, huy hiệu `Color.orange.gradient` cắt theo `Capsule`, dấu tích vẽ bằng `Path`, viền nét đứt, bóng đổ) và ảnh bìa sách từ `Assets.xcassets` ở mỗi dòng của danh sách. `session.txt` đạt 25 điểm.
- `import SwiftUI` giờ kéo theo Foundation và các kiểu CoreGraphics như trên iOS, nên file chỉ `import SwiftUI` mà dùng `CGPoint`, `Date`, `UUID` vẫn compile.

### Đã làm

| Patch | Nội dung |
| --- | --- |
| `0014` Build, stroke and trim paths in Swift | `Path` lưu phần tử bằng Swift (case `elements` mới) vì OpenRenderBox chưa giữ được path trên Linux: `move`, `addLine`, đường cong, cung (theo quy ước `clockwise` của CoreGraphics), hình chữ nhật, ellipse, hình bo góc (cả bo từng góc), `addPath`, `applying`, `offsetBy`, `currentPoint`, `description`. `strokedPath` giữ đường và kiểu nét, `trimmedPath` giữ đường và hai phân số, để renderer tự vẽ nét. Hit-test theo winding number, hoặc theo khoảng cách tới đường với path nét |
| `0015` Draw paths, strokes, path clips and styled text | Renderer vẽ shape bất kỳ thành layer hình của render core (fill theo luật tô; nét có độ dày, đầu, khớp, miter, nét đứt); clip theo path thành mask. Chữ được đo và vẽ theo run: cỡ, độ đậm, nghiêng, màu, gạch chân, gạch ngang, kerning, tracking, baseline; giãn dòng của đoạn. Font trên Linux mang thêm cờ nghiêng |
| `0016` Re-export Foundation and the CoreGraphics types on Linux | `@_exported import Foundation` và `OpenCoreGraphicsShims` trong OpenSwiftUI |
| `0017` Add gradients… and drop shadows | `Gradient` có stop; `LinearGradient`, `RadialGradient`, `AngularGradient`, `Color.gradient` là shape style và view, cùng các thành viên `.linearGradient(…)`…; tô shape bằng paint (trước là stub crash), opacity của style thành effect; bóng đổ thành shadow của layer nhóm |
| `0018` Show images from asset catalogs on Linux | Đọc imageset trong `.xcassets` của bundle (kể cả thư mục có namespace) và ảnh rời `tên.png`, `tên@2x.png`; chọn biến thể theo scale; nội dung `GraphicsImage` mới giữ file đã mã hoá, render core giải mã và đọc kích thước pixel từ header (`iris_image_size`) |
| `compile-app.sh` | App chạy từ thư mục riêng `<package>/run`: binary hard link cạnh resource, để `Bundle.main` thấy asset catalog và `.lproj` (việc P1-12 để lại) |

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| `cannot find 'CGPoint' in scope` ở file chỉ `import SwiftUI` | OpenSwiftUI trên Linux không re-export Foundation | Patch 0016 |
| Crash `ShapeStyleRendering.swift: Unimplemented yet` khi tô gradient | `render(paint:)` của upstream là stub | Tô theo path của shape (patch 0017) |
| Ảnh không hiện dù đã đọc được | Trên nền tảng không có CoreUI, cả `resolve(in:)` của ảnh có tên lẫn cache bitmap đều trả về rỗng; sau đó `effectiveAllowedDynamicRange` crash | Nhánh Linux cho cả hai chỗ; bỏ kiểm tra HDR khi không có CoreGraphics (patch 0018) |

### Giới hạn

- Gradient chưa dùng được cho chữ (lấy màu stop đầu) và cho nét viền (lấy màu đầu); chưa có `EllipticalGradient`, `MeshGradient`, không gian màu, animation của stop.
- Bóng đổ trong (inner shadow) và bóng của shape style (`.fill(.blue.shadow(…))`) chưa vẽ.
- Path: các phép boolean (`union`, `intersection`…) và `normalized` vẫn chưa làm; đường cong được làm phẳng thành 16 đoạn khi hit-test, tính bounds và trim.
- Ảnh: chưa có ảnh vector (PDF, SVG) trong asset catalog, appearance (dark), tô màu ảnh template, `resizable(capInsets:)`; SF Symbols cần font của Apple nên `Image(systemName:)` ra ảnh rỗng.

## Đợt 2 · Control và container (15/10/2026)

### Kết luận

- **Các control và container dùng nhiều nhất sau nhóm cơ bản giờ chạy và có dáng iOS:** `Toggle`, `Slider`, `ProgressView`, `Stepper`, `Label`, `Section`, `Form`, `Picker`, `TabView`, `LazyVGrid`/`LazyHGrid`, `LazyVStack`/`LazyHStack`, `NavigationView`, `Link`, `Divider`. Trước đợt này trên Linux, `Toggle` và `ProgressView` crash, `Slider` trống, còn lại không compile (upstream chưa có).
- Sửa 2 lỗi của upstream gặp mọi nền tảng: `subviews[a..<b]` trong `Layout` tự viết trả về mọi subview, và con của variadic view (`List`, `Form`, `Section`, `TabView`, `Picker`…) bị thay bằng con khác ở cùng vị trí thì vẫn hiện con cũ, còn con giữ nguyên thì mất `@State` mỗi lần container vẽ lại.
- App mẫu: màn "Cài đặt" là một `Form` (công tắc, thanh trượt có bước, stepper, picker segmented và picker menu, thanh tiến độ); màn "Bộ sưu tập" là `TabView` hai tab, tab đầu là lưới bìa sách `.adaptive(minimum: 100)`, tab sau có `Divider` và `Link`. `session.txt` đạt 37 điểm.

### Đã làm

| Patch | Nội dung |
| --- | --- |
| `0019` Draw switches, sliders and progress views on Linux | Không có UIKit để vẽ `UISwitch`, `UISlider`, `UIProgressView`, nên SwiftUI tự vẽ theo kích thước và màu mặc định của UIKit: công tắc 51 × 31, chạm để lật; thanh trượt kéo được, có `step`; thanh tiến độ 4 pt; vòng xoay 8 vạch (đứng yên). `Toggle` có tiêu đề |
| `0020` Add Label, Section, Form, Stepper, lazy stacks and NavigationView | `Label` và các `LabelStyle` hệ thống; `Section` có header (chữ hoa, xám) và footer; `Form` kiểu inset grouped (thẻ trắng bo góc trên nền `#F2F2F7`, đường kẻ giữa các dòng); `Stepper`; `LazyVStack`/`LazyHStack` (dựng hết một lần); `NavigationView` thành `NavigationStack`; `NavigationLink(destination:)`. `List` dùng chung cách xếp dòng |
| `0021` Fix slicing layout subviews and replacing view list children | `LayoutSubviews.subscript(bounds:)` chọn đúng range; `PlaceholderInfo.updateValue` so `id` khác nhau thay vì bằng nhau |
| `0022` Add grids, TabView, Picker and titled links | `GridItem` (`.fixed`, `.flexible`, `.adaptive`) và `LazyVGrid`/`LazyHGrid` bằng một `Layout`; `TabView` (thanh tab 49 pt, nhãn từ `.tabItem`, chọn theo `.tag` hoặc thứ tự, tab dựng khi chọn lần đầu và giữ state); `Picker` kiểu segmented, inline (danh sách có dấu tích) và menu; `Link(_:destination:)` |

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Lưới chỉ đặt 3 ô đầu, các ô khác chồng lên nhau | `subviews[start..<end]` của upstream trả về mọi subview | Patch 0021 |
| Picker menu không đổi giá trị hiện ra dù binding đã đổi | `PlaceholderInfo` chỉ cập nhật khi `id` *bằng* nhau, nên con ở cùng chỉ số nhưng `id` khác không được thay; cũng vì vậy con giữ nguyên bị reset state | Patch 0021 |
| Chạm tab không đổi tab | `TabView(selection:)` nhận `Binding?`; optional không phải `DynamicProperty`, nên chủ của state không biết binding đã được đọc và không vẽ lại | Lưu thành `Binding<SelectionValue?>` (patch 0022) |
| `.allowsHitTesting` không có | Upstream chưa làm | Tab ẩn dùng `.opacity(0)`, hit-test vốn bỏ qua view trong suốt; modifier này để đợt 4 |
| Dấu tích, mũi tên lên xuống của picker cần SF Symbols | Font của Apple | Vẽ bằng `Path` |

### Giới hạn

- `Picker` kiểu menu chạm thì chuyển sang lựa chọn kế tiếp, chờ lớp trình bày (đợt 3) để mở menu thật; `.wheel` vẽ như inline; chưa có style tự viết, chưa tự gắn tag theo `id` của `ForEach` (phải `.tag` rõ ràng); segmented chưa có vạch ngăn và animation.
- `TabView`: chưa có biểu tượng tab (SF Symbols), `.badge`, `.tabViewStyle(.page)`, API `Tab` của iOS 18, vùng an toàn dưới thanh tab.
- Lưới và lazy stack dựng mọi con cùng lúc; chưa có `pinnedViews`, `Grid`/`GridRow`.
- Vòng xoay của `ProgressView` đứng yên; `Toggle` chỉ có kiểu công tắc; `Form` chỉ có kiểu inset grouped.
- `Button` và `Link` trên Linux chưa tô màu tint (chữ đen), để đợt 4; mở URL bằng `Link` hay `\.openURL` chưa đi tới host (môi trường mặc định bỏ qua URL), để đợt 3.

## Đợt 3 · Điều hướng, trình bày và Button (15/10/2026)

### Kết luận

- **App iOS điều hướng và trình bày như trên iPhone:** `NavigationStack` có path (`NavigationPath` hoặc mảng), `navigationDestination`, `NavigationLink(value:)`, thanh điều hướng có tiêu đề lớn hoặc inline, nút back mang tiêu đề trang dưới, toolbar (`ToolbarItem`, `ToolbarItemGroup`, `navigationBarItems`, thanh dưới), `\.dismiss`; `.sheet` (detent, thanh kéo, kéo xuống để đóng), `.fullScreenCover`, `.popover`, `.alert`, `.confirmationDialog` (kể cả API cũ `Alert`, `ActionSheet`), `Menu`, `.contextMenu`, `onLongPressGesture`, picker kiểu menu mở menu thật.
- **Button làm lại theo hệ style của OpenSwiftUICore:** `buttonStyle` với `ButtonStyle`/`PrimitiveButtonStyle` tự viết, các style hệ thống (`automatic`, `plain`, `borderless`, `bordered`, `borderedProminent`), `role`, trạng thái nhấn, `.disabled`, `.tint`. Nút giờ tô màu tint như iOS thay vì chữ đen.
- **Trang dưới giữ state khi trang khác đè lên:** trước đây NavigationStack tháo trang gốc khỏi graph khi push, nên quay lại thì list cuộn về đầu và `@State` trong trang gốc mất. Giờ mọi trang ở lại graph, chỉ trang trên cùng hiện.
- Sửa thêm 1 lỗi upstream: `ViewAlias` đếm 0 view khi không thấy nguồn trong input đếm, làm List bỏ mất dòng có Button.
- App mẫu: link theo value và `navigationDestination`, toolbar "Giới thiệu"/"Thêm", trang sách title inline với nút "Xong" gọi `dismiss`, sheet "Giới thiệu" (detent medium/large, toolbar, alert bên trong, nút `borderedProminent`), confirmationDialog "Khôi phục" ở Cài đặt, context menu trên dòng sách và trên chữ trạng thái. `session.txt` đạt 51 điểm.

### Đã làm

| Patch | Nội dung |
| --- | --- |
| `0023` Keep navigation pages, push values and draw toolbars | `NavigationStack` mới: trang ở lại graph (ẩn bằng opacity, hit-test bỏ qua), path binding, `navigationDestination(for:)`, `(isPresented:)`, `(item:)`; thanh điều hướng mỗi trang (tiêu đề lớn 34 đậm hoặc inline 17 đậm, back có chevron vẽ bằng `Path`, item trái/phải/giữa); thanh dưới; `toolbar(.hidden, for:)`, `navigationBarHidden`, `navigationBarBackButtonHidden`, `navigationBarTitleDisplayMode`; `DismissAction`, `\.isPresented`, `\.presentationMode`; dòng List/Form là `NavigationLink` có chevron; nền Form lộ ra sau thanh điều hướng |
| `0024` Make buttons with button styles | `Button` qua `StyleableView` + `ViewAlias` của Core: style gần nhất, nhãn thành `configuration.label`; `PressableButton` (tap + `DragGesture` đo trạng thái nhấn); style hệ thống, `buttonBorderShape`, `controlSize`; `Button(role:)`, `Button(_:systemImage:)`, `Button(configuration)`. Sửa `ViewAlias._viewListCount` |
| `0025` Present sheets, covers, alerts and dialogs | View được trình bày đi lên bằng preference tới host ở gốc scene (`StdoutApp`), hiện trên app với environment của view trình bày; `presentationDetents` (+ selection), `presentationDragIndicator`, `interactiveDismissDisabled`, `presentationCornerRadius`, `presentationBackground`; alert 270 pt, 2 nút nằm ngang; dialog có nút Cancel tách riêng (tự thêm nếu thiếu) |
| `0026` Add menus, context menus and long presses | `Menu` (panel 250 pt cạnh nhãn, dưới hoặc trên tuỳ chỗ trống, menu lồng mở panel mới), `contextMenu` (nhấn giữ, chạy được cả trong ScrollView, không kích hoạt tap của view), picker kiểu menu; `LongPressGesture` ghép từ `EventListener` + `duration` + `DistanceGesture`; lệnh `hold` cho runner stdin |

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| `tint` trong view trỏ nhầm sang method `View.tint(_:)` | Hằng `tint` cấp file bị member của `View` che | Đổi tên hằng thành `systemBlue` |
| Chevron của link trong List không hiện | Environment đặt lên con của variadic view không tới `@Environment` của view trong con (Text vẫn nhận font) — chưa rõ vì sao | Đặt `irisListRow` ở ngoài cây variadic (List, Form). Còn mở, xem Giới hạn |
| Sau khi làm lại Button, List mất một số dòng | `_GraphInputsModifier` không ghi vào input đếm, nên `ViewAlias._viewListCount` không thấy nguồn và trả 0 | Trả `nil` (chưa biết) — patch 0024 |
| `.foregroundStyle(.primary)` vẫn ra màu tint | `.primary` là cấp đầu của style đang kế thừa, không phải màu chữ | Dùng `Color.primary` |

### Giới hạn

- Chưa có animation push/pop, vuốt từ mép để back, animation hiện/ẩn sheet và alert; tiêu đề lớn không thu lại khi cuộn.
- Trang ở dưới không nhận `onDisappear`/`onAppear` khi bị đè rồi lộ lại (khác iOS); view push bằng `NavigationLink(destination:)` giữ destination lúc chạm.
- `NavigationLink(isActive:)`, `NavigationLink(tag:selection:)` (đã cũ), `NavigationSplitView` chưa có.
- Alert chưa đổi thứ tự nút theo role (cancel bên trái), chưa có TextField trong alert; menu chưa có `Section`/`Divider` kiểu iOS (vạch xám dày), `primaryAction` chưa mở được menu.
- `\.openURL` và `Link` chưa đưa URL tới host: cần message trong Device Protocol, làm cùng router intent của Android (P1-10).
- `Anchor<CGRect>.Source.bounds` chưa có, nên `popover(attachmentAnchor: .rect(.bounds))` không compile.
- Lỗi environment trên con của variadic view (dòng thứ hai của bảng trên) còn phải tìm nguyên nhân: style hay environment đặt trong `body(children:)` của root tự viết có thể không tới con.

## Đợt 4 · Style iOS: List và hành vi dòng (15/10/2026, đang làm)

### Kết luận

- **`List` giờ có dáng iOS 16+ mặc định (inset grouped):** nền xám, các dòng chung một thẻ trắng bo góc có đường kẻ giữa dòng; `.listStyle(.grouped/.plain/.inset/.insetGrouped/.sidebar)` đổi dáng. Trước đây List là các dòng trắng phẳng không đường kẻ, khác hẳn iPhone.
- Vuốt ngang dòng List hiện `swipeActions` (cả hai cạnh), `ForEach.onDelete` thêm nút Delete; nhấn nút xoá dòng. `.allowsHitTesting(false)` (hạng 59, 37% app) chạy.
- Chạm chỗ nào trên dòng NavigationLink cũng mở link (trước chỉ chạm được chữ). Đường kẻ mảnh 0,5 pt không còn mất ở dòng xen kẽ.
- `session.txt` đạt 53 điểm.

### Đã làm

| Patch | Nội dung |
| --- | --- |
| `0027` Style lists, swipe rows and turn hit testing off | `IrisGroupedList` dùng chung cho Form và List (thẻ inset hoặc full width, gom các dòng ngoài section vào một thẻ); `IrisListRow` (inset, nền, đường kẻ theo trait); `listRowBackground`, `listRowSeparator`, `listRowInsets`, `scrollContentBackground`; `List(data)`, `List(data, id:)`, `List(range)`; `swipeActions` thành trait để dòng vẽ phần vuốt cao bằng cả dòng; `onDelete`, `onMove` (chưa kéo được); `allowsHitTesting` bằng một responder bọc ngoài mà hit-test bỏ qua; trạng thái nhấn của Button dùng gesture "nhấn" tự fail khi ngón tay đi quá 10 pt; host stdout layout theo `displayScale` bằng scale vẽ frame; lệnh `swipe <chữ>` cho runner stdin |

### Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Đường kẻ 0,5 pt chỉ hiện ở dòng xen kẽ | Host stdout layout ở `displayScale` 1 trong khi vẽ 2x, nên đường mảnh rơi vào nửa điểm bị làm tròn mất | Đặt `displayScale` của environment host bằng scale vẽ |
| Vuốt dòng không ăn | Điểm chạm rơi vào khoảng `Spacer` của nhãn link, không có hình để hit-test; thêm nữa `DragGesture(minimumDistance: 0)` đo trạng thái nhấn của Button không bao giờ fail nên giữ touch | `contentShape` cho nhãn link trong dòng; gesture nhấn tự fail khi đi quá 10 pt |
| Nút Delete chỉ cao bằng nội dung | `swipeActions` gắn bên trong khung dòng | Đổi thành trait, dòng List vẽ phần vuốt quanh cả dòng |
| Bước session chạm "Book 3" trượt | Bản dump frame có cả chữ đã cuộn ra sau thanh điều hướng | Chọn dòng đang thấy trong session |

### ScrollViewReader (patch 0028)

`ScrollViewReader` và `ScrollViewProxy.scrollTo(_:anchor:)` (hạng 36, 32% app). Mỗi ScrollView giữ khung của các đích theo id: con của `LazyVStack`/`LazyHStack` (giờ là root variadic) và dòng List, id lấy từ phần tử `ForEach` hoặc `.id(_:)`. Cuộn theo anchor (điểm anchor của đích trùng điểm anchor của view) hoặc vừa đủ để thấy; trong `withAnimation` thì có animation; đích chưa layout (gọi trong `onAppear`) thì cuộn khi đo xong. Id Optional được mở ra như SwiftUI. Giới hạn: con của `VStack` thường không là đích (`VStack` là của upstream). App mẫu có tab "Tên sách" với nút "Về cuối"; `session.txt` 54 điểm.

### Còn lại của đợt 4

`.refreshable`, `.searchable`, chọn dòng (`List(selection:)`, `EditButton`, kéo để sắp xếp), `toolbar(.hidden, for: .tabBar)`, biểu tượng tab bar, dark mode (`\.colorScheme`, `preferredColorScheme`), full swipe.

## Đợt 5 · Hạ tầng (15/10/2026, một phần)

- **CI:** workflow `.github/workflows/ios-sample.yml` chạy `runtimes/ios/Scripts/check-sample.sh` trong container `swift:6.4.1-noble`: cài thư viện hệ thống, dựng render core, tải font, lấy OpenSwiftUI và các gói anh em theo pin rồi áp patch, build app mẫu và chạy `session.txt` với mọi `# expect`. Chỉ chạy khi `runtimes/ios/**`, `examples/ios-swiftui/**`, `crates/render/**` hoặc chính workflow đổi; checkout và thư mục build được cache theo hash của `Patches/**` và `fetch-openswiftui.sh`. Đã chạy cùng script ở chế độ chữ (không `IRISRUN_FRAMES`) trên máy dev: 54 điểm đạt. Chưa chạy trên GitHub (lần push tới sẽ chạy).
- **Chưa làm:** OpenKit dựng sẵn theo phiên bản Swift (cần nơi phát hành bản build; gộp được với P1-06); đo lại corpus — vẫn 0/65 cho tới khi có kiểu UIKit không phải view, Combine và stub (P1-16, P1-17, P1-18), như P0-08 và P1-12 đã chỉ ra.

## Tổng kết P1-13

API SwiftUI trong bảng xếp hạng P0-08 mà app mẫu dùng giờ chạy được và có dáng iOS, từ vẽ (path, gradient, bóng, ảnh) tới control, container, điều hướng, trình bày và List. 28 patch trên OpenSwiftUI 0.23.1, trong đó 4 sửa lỗi upstream gặp trên mọi nền tảng (Compute ở patch compute/0001; `LayoutSubviews[range]`, `PlaceholderInfo` ở 0021; `ViewAlias._viewListCount` ở 0024). Tiêu chí của task (tỉ lệ corpus chạy được ở cổng 1) còn phụ thuộc P1-16–P1-18.
