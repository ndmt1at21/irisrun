# P1-15 · Input iOS

15/10/2026 · Máy dev WSL2 Ubuntu 20.04 (12 nhân), dùng chung với các session khác. Swift 6.4.1 chạy trong container `irisrun-swift-dev:6.4.1`. Mọi số đo là của bản debug.

## Kết luận

- **Đạt tiêu chí "form đăng nhập mẫu dùng được với bàn phím tiếng Việt".** Trong Device UI (Chromium headless, sự kiện bộ gõ thật của Chromium qua `Input.imeSetComposition` và `Input.insertText`), gõ Telex vào form đăng nhập của app mẫu: chữ đang soạn hiện có gạch chân, được commit, Return chuyển sang ô mật khẩu, mật khẩu hiện dấu chấm, Return lần nữa thì đăng nhập và hiện "Xin chào, nguyễn Thị Ánh!". Chưa thử bộ gõ của hệ điều hành (Unikey, Telex của macOS), như P0-12.
- **Chạm thành gesture:** chạm (tap), kéo (`DragGesture` có vận tốc và điểm dừng dự đoán), cuộn (`ScrollView` có quán tính, kéo quá mép thì co giãn rồi bật về, phần bị cuộn khuất không nhận chạm). `List` giờ cuộn được. Kéo chuột trong Device UI cuộn danh sách 19 hàng.
- **Nhập chữ cho `TextField`, `SecureField`, `TextEditor`:** vẽ bằng chính SwiftUI vì trên Linux không có UIKit. Caret và gạch chân của chữ đang soạn đặt đúng chỗ render core dàn chữ (thêm hai hàm vào C API). Mọi thao tác tính theo đơn vị UTF-16 như giao thức: commit, chữ đang soạn, xoá quanh caret, phím Backspace, Delete, mũi tên, Home, End, Return. Chạm vào ô thì đặt caret vào ranh giới ký tự gần nhất.
- **`@FocusState`, `.focused(_:equals:)`, `onSubmit` chạy trên Linux.** Bản của upstream lấy focus từ responder của UIKit/AppKit nên Iris thay bằng bản riêng, giữ nguyên API. Form mẫu dùng đúng kiểu viết thường gặp: `.focused`, `onSubmit { focus = .password }`, `onAppear { focus = .account }`, `.keyboardType`, `.textContentType`, `.textInputAutocapitalization`, `.autocorrectionDisabled`, `.submitLabel`, `.textFieldStyle(.roundedBorder)`.
- **App iOS chạy được bằng `irisrun start <thư mục có .xcodeproj>`** và điều khiển từ Device UI. Để làm vậy, phần "host IrisProtocol thật chạy RunLoop" của P1-13 được làm luôn ở đây. Từ lúc gửi input tới lúc nhận frame mới qua WebSocket: trung vị 17 ms, chậm nhất 29 ms.
- **Sửa hai lỗi của Compute (bản AttributeGraph viết lại) làm app thật crash:** so sánh một phần giá trị đọc enum ở sai offset (crash khi body có `if`/`else`, đã có bản sửa ở upstream, nâng pin lên 0.6.0-bugfix.1), và `IAG::vector` release hai lần khi lớn quá 32 phần tử (crash khi `List` khoảng 16 hàng, upstream chưa sửa, thêm `Patches/compute/0001`).

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Vị trí caret theo byte UTF-8 của chữ đã dàn (dòng của ký tự, cả dòng trống sau `\n` và chữ rỗng) và offset gần nhất với điểm chạm | `crates/render/src/text.rs`, `Scene::text_caret`, `Scene::text_offset_at`; C API `iris_scene_text_caret`, `iris_scene_text_offset_at`; Swift `Scene.caret(in:…)`, `Scene.index(in:…)` |
| Hit-test hình bo góc bằng hình học (OpenRenderBox chưa có path bo góc trên Linux, chạm vào nền `RoundedRectangle` từng crash) | patch `openswiftui/0010` |
| `DragGesture` (theo kiểu `PubliclyPrimitiveGesture` của upstream), `ScrollView`, `List` cuộn, renderer cắt theo hình chữ nhật và bo góc | patch `openswiftui/0011` |
| `TextField` (một dòng, hoặc nhiều dòng với `axis: .vertical`), `SecureField`, `TextEditor`; trạng thái soạn chữ; `FocusState` và `focused` của Iris; `onSubmit`, `textFieldStyle` và các modifier gợi ý bàn phím; `NavigationLink` có tiêu đề | patch `openswiftui/0012` |
| Lệnh stdin mới cho kịch bản: `drag`, `fling`, `compose`, `type`, `delete`, `key` (bên cạnh `tap`); `DeviceInput` giao input như UIKit | patch `openswiftui/0012` |
| Chế độ thiết bị `IRISRUN_DEVICE=stdio`: envelope có độ dài varint trên stdin/stdout, output của app sang stderr, `DeviceInfo`, `AppStatus`, frame JPEG mã hoá ở luồng khác, RunLoop thật | patch `openswiftui/0013`; OpenSwiftUI phụ thuộc gói `runtimes/ios` (product `IrisProtocol`) qua `OPENSWIFTUI_IRIS_RUNTIME_PATH` trong `env.sh` |
| `irisrun start` nhận thư mục có `.xcodeproj`: build bằng `compile-app.sh`, chạy app với `IRISRUN_DEVICE=stdio`; `IRISRUN_SWIFT_RUNNER` chạy Swift qua wrapper trên máy Swift không chạy được | `crates/engine/src/ios.rs`, `crates/cli/src/main.rs` |
| Compute: pin 0.6.0-bugfix.1 và patch vector | `Scripts/fetch-openswiftui.sh`, `Patches/compute/0001` |
| App mẫu: màn "Đăng nhập" (`LoginView`), ghi chú `TextEditor` ở màn chi tiết sách; `session.txt` thêm đăng nhập bằng Telex, ghi chú nhiều dòng, cuộn danh sách: 24 điểm | `examples/ios-swiftui` |

## Quyết định

- **Ô nhập vẽ bằng SwiftUI, hình học chữ lấy từ render core.** Ô dựng `Text` như thường; caret và gạch chân là hình chữ nhật đặt theo `iris_scene_text_caret`, với style chữ resolve từ đúng `Text` đó trong environment của ô (`resolveAttributedString` rồi `irisTextStyle`), nên khớp với chữ được vẽ. Ô một dòng cuộn ngang để caret luôn trong khung; `TextEditor` có inset như `UITextView` (8, 5).
- **Offset tính theo UTF-16, ranh giới theo ký tự.** Giao thức và bộ gõ đếm UTF-16; xoá hay di chuyển caret không bao giờ cắt giữa một ký tự (lùi hoặc tiến tới ranh giới gần nhất). C API của render core vẫn nhận byte UTF-8 như run chữ.
- **Binding chỉ nhận chữ đã commit,** chữ đang soạn nằm trong session của ô, như `TextField` của SwiftUI không cập nhật binding khi còn marked text. Return ở ô một dòng thôi soạn rồi chạy `onSubmit`, nên `onSubmit { focus = .password }` chuyển ô như trên iOS; ở `TextEditor` Return xuống dòng.
- **Trạng thái mà callback đọc phải nằm trong reference Observable.** Đọc `@State` hay `Binding` trong action hoặc callback của gesture trả giá trị của lần update trước khi nhiều sự kiện được xử lý giữa hai lần render. `FocusState` (Linux), `ScrollView` và session soạn chữ đều giữ trạng thái trong reference (`FocusBox`, `ScrollState`, `TextEditingSession`).
- **`ScrollView` dựng từ các phần SwiftUI:** nội dung có kích thước lý tưởng theo trục cuộn, dịch bằng `offset`, cắt bằng `clipped()` và một modifier che luôn vùng nhận chạm (`clipped()` chỉ cắt phần vẽ). Kéo dùng `highPriorityGesture` với `DragGesture` chỉ nhận theo trục cuộn, nên chạm vào nút trong danh sách vẫn ăn khi không kéo, kéo thì nút không ăn, và ScrollView dọc lồng ScrollView ngang vẫn đúng hướng. Quán tính theo tốc độ giảm của `UIScrollView` (0,998 mỗi ms), co giãn ngoài mép theo công thức của UIKit.
- **Host chạy theo đồng hồ `systemUptime`, như host UIKit.** Gesture bên trong view (như `TapGesture`) đo thời gian bằng đồng hồ của view graph, nên trước khi giao input host render để đưa đồng hồ lên hiện tại. Render tối đa 60 lần mỗi giây khi view graph yêu cầu; frame chỉ mã hoá khi display list đổi; encoder chậm thì bỏ frame cũ.
- **Chế độ thiết bị mặc định 2x** (780×1688 px), đủ cho Device UI; `IRISRUN_SCALE` đổi được.
- **`UIKeyboardType`, `UITextContentType` tạm nằm trong OpenSwiftUI** để form compile được; chuyển sang module UIKit khi có (P1-16).
- **`irisrun start` cho iOS dùng `compile-app.sh` của repo** (đường dẫn lúc build CLI, hoặc `IRISRUN_IOS_RUNTIME`); bản phát hành sẽ dùng OpenKit dựng sẵn (P1-13, P1-06).

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Chạm vào ô nhập crash (`ORBPath.swift: Unimplemented yet`) | `Path.contains` của hình bo góc gọi OpenRenderBox, chưa làm trên Linux | Tính bằng hình học: trong hình chữ nhật và, ở góc, trong ellipse của góc (patch 0010) |
| `onAppear { focus = .account }` không hiện caret | Thay đổi xảy ra trong lúc render; host bỏ qua `graphDidChange` khi đang render | Host luôn hẹn render lại (patch 0012) |
| Return không chuyển sang ô mật khẩu | `blur` của ô đọc `Binding` ra giá trị cũ (`.account`) nên reset focus về `nil`, đè lên `.password` | `FocusState` của Iris giữ giá trị trong `FocusBox` |
| Vào trang đăng nhập thì crash trong Compute (`LayoutDescriptor::Compare::Enum`) | `find_partial` trả vị trí tuyệt đối mà `compare_partial` dùng như tương đối, nên so sánh lệch offset và đọc nhầm case của `_ConditionalContent` | Nâng Compute lên 0.6.0-bugfix.1 (upstream sửa ngày 11/10) |
| Thêm sách tới khoảng 16 hàng thì crash (`swift_deallocClassInstance` trong `~stack`) | `IAG::vector` giữ phần tử inline trong mảng `T`; khi chép ra heap bằng `memcpy` thì bản inline vẫn bị huỷ thêm lần nữa, `cf_ptr` release hai lần | Xoá trắng bộ đệm inline sau khi chuyển (`Patches/compute/0001`) |
| Thả tay sau khi kéo thì danh sách trôi về đầu | Callback của gesture đọc `@State` ra giá trị cũ | `ScrollState` (reference Observable) |
| Kích thước nội dung đo ra bằng khung (759 pt) | `.frame(minHeight:)` bị chặn bởi kích thước được đề xuất (đúng ngữ nghĩa SwiftUI); preference từ `GeometryReader` trong `.background` không tới được `onPreferenceChange` | Đo bằng `onGeometryChange` ngay sau `fixedSize`, trước frame |
| Qua giao thức, chạm vào hàng không mở trang | Render xen giữa `began` và `ended` làm đồng hồ view graph nhảy; `TapGesture` lấy mốc bắt đầu từ lần render cũ nên tưởng đã giữ quá 0,75 s | Host render theo `systemUptime` trước khi giao input (patch 0013) |

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Input → frame qua WebSocket | Trung vị 17 ms, chậm nhất 29 ms | 22 lần commit một ký tự vào ô; gồm xử lý, render, JPEG, WebSocket |
| Frame JPEG q85 ở 2x | 28–31 KB | Màn đăng nhập, màn danh sách |
| Frame đầu sau khi chạy app | 0,5–3,4 s | Gồm `docker run`; lâu hơn ngay sau khi Docker khởi động |
| `irisrun start` khi đã build | 26–55 s | Phần lớn là SwiftPM lập kế hoạch build trong container |
| Kịch bản `check-sample.sh` | 24 điểm, 42 s | Build tăng dần và chạy 44 lệnh |
| Patch OpenSwiftUI mới | 0010: +17 −4; 0011: +423 −8; 0012: +1202 −2; 0013: +264 −1 | Compute: +7 |
| Test | Render core 17 (thêm 1); `runtimes/ios` 7 + 1; workspace Rust xanh, clippy sạch | |

## Giới hạn và việc tiếp

- **Ô nhập:** chưa có chọn chữ, copy và dán, caret nhấp nháy, bàn phím ảo, tự cuộn `TextEditor` khi chữ dài hơn khung, né bàn phím; chưa có `TextField(value:format:)`, style tuỳ biến (`_body(configuration:)`), Tab sang ô sau, Ctrl/Cmd+A. Gạch chân của chữ đang soạn chỉ vẽ trên dòng của caret.
- **Cuộn:** chưa có thanh cuộn, paging, `ScrollViewReader`, `scrollPosition`, `refreshable`; chạm trong lúc đang trôi không dừng ở chỗ đang hiện (animation của SwiftUI không cho đọc giá trị đang hiện).
- **Đa điểm chạm:** gesture của SwiftUI nhận một ngón; pinch giả lập là việc của P1-28.
- **Chế độ thiết bị bỏ qua `DeviceConfig`** (xoay, dark mode, ngôn ngữ, cỡ chữ) và tin nhắn adapter; màn hình cố định 390×844 pt.
- **Chưa thử bộ gõ thật của hệ điều hành** và chưa đo bản release (build release lần đầu sau khi đổi package graph mất khoảng 20 phút).
- `String(describing:)` một `Text` đệ quy vô hạn rồi crash (lỗi của upstream ở `AnyTextStorage.debugDescription`); app in `Text` ra log sẽ crash.
- `IRISRUN_SWIFT_RUNNER` chỉ cho máy dev; mỗi lần chạy app là một `docker run`.
- **P1-13 tiếp theo:** host giao thức đã xong ở đây. Còn nối ảnh, gradient, shape, clip tuỳ ý, bóng đổ và chữ nhiều kiểu vào render core; style iOS cho `List` và `Button` (trạng thái nhấn, màu tint, disabled); các control còn thiếu theo bảng xếp hạng của P0-08 (`sheet`, `alert`, `TabView`, `Form`, `Section`, `Label`, `Image` có asset); dựng sẵn OpenKit và đưa `check-sample.sh` vào CI.

## Chạy lại

```sh
crates/render/fetch-fonts.sh
LIBRARY_PATH=$HOME/.cache/irisrun/devlibs cargo test -p irisrun-render
cargo build -p irisrun-render --release
cd runtimes/ios
Scripts/fetch-openswiftui.sh          # checkout có sẵn từ trước: xoá OpenSwiftUI và Compute trong ~/.cache/irisrun/p0-05/checkouts rồi chạy lại
Scripts/check-sample.sh               # session.txt: 24 điểm; IRISRUN_FRAMES=<dir> để có PNG

# Chạy app mẫu trong Device UI (Swift qua wrapper ở máy dev):
cd ../.. && cargo build -p irisrun
IRISRUN_SWIFT_RUNNER=swiftenv target/debug/irisrun start examples/ios-swiftui
# mở http://127.0.0.1:7777/#/live
```

Ở máy dev, đặt `swiftenv` trước mỗi lệnh Swift (xem `docs/progress.md`). Driver Chromium để thử Device UI: `~/.cache/irisrun/devtools/cdp/ui.mjs` (`CHROME` trỏ tới `chrome-headless-shell` trong `~/.cache/ms-playwright`); đo độ trễ: `~/.cache/irisrun/devtools/client/latency.mts`.
