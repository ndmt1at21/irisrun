# P0-05 · OpenSwiftUI trên Linux

15/10/2026 · WSL2 Ubuntu 20.04, x86_64, 12 nhân, 15 GB RAM. Swift 6.4.1 chạy trong container `irisrun-swift-dev:6.4.1` (`swift:6.4.1-noble` thêm `libssl-dev`, `uuid-dev`). Máy build chung với P0-06, P0-07 và P0-08, nên load là 10–35 trên 12 nhân lúc đo; thời gian build trên máy rảnh sẽ ngắn hơn.

## Kết luận

- **Go cho hướng này.** Lõi của OpenSwiftUI chạy được trên Linux: AttributeGraph (backend Compute), layout, `@State`, `@Observable`, environment, preference, hit-test và gesture, display list. App mẫu `examples/ios-swiftui/IrisSample` compile **không sửa dòng nào** (file đem build giống hệt từng byte) nhờ `-module-alias SwiftUI=OpenSwiftUI -module-alias Observation=OpenObservation`.
- **App mẫu chạy với renderer stdout và cập nhật đúng.** Một kịch bản 7 lần chạm (`examples/ios-swiftui/session.txt`) qua hệ gesture thật cho thấy: bộ đếm `@State` tăng 0 → 1 → 2; thêm sách vào `Library` (`@Observable`) hiện dòng "Book 3"; đẩy và quay lại màn chi tiết, có tiêu đề từ `navigationTitle`; bấm yêu thích đổi chữ ngay trên màn chi tiết, quay lại thì dòng của sách có "★"; bộ đếm vẫn là 2 sau khi quay lại. `Scripts/check-sample.sh` kiểm 14 điểm, đều đạt.
- **Upstream 0.23.1 build trên Linux bằng Swift 6.4.1 mà không cần sửa gì** (398 s, bản debug, `-j 6`, gồm swift-syntax, swift-crypto/BoringSSL, Compute). Nhưng upstream trên Linux chỉ vẽ được ô màu: code tạo font gọi `_openSwiftUIPlatformUnimplementedFailure()` (crash), đo chữ ra 0, `Button` là stub rỗng, chưa có `List`, `NavigationStack`, `NavigationLink`, `navigationTitle`, và app chỉ vẽ một frame rồi thoát.
- **Cần 6 patch, tổng cộng khoảng 330 dòng:** 5 patch cho OpenSwiftUI (11 file, +324 −30) và 1 dòng cho macro của OpenObservation. Patch nằm trong `runtimes/ios/Patches/`, script lấy code áp chúng thành commit trên đúng SHA đã pin.
- **Số đo (máy đang tải, chi tiết ở mục Số đo):** build lần đầu app mẫu cùng toàn bộ OpenSwiftUI mất 641 s (debug) và 1740 s (release). Binary release 87 MB, còn 17 MB sau khi strip. Bản release lên frame đầu trong 0,05 s và chạy cả kịch bản 7 lần chạm trong 0,07 s, RAM tối đa 43 MB. Frame của bản release giống hệt bản debug.
- **Chưa được:** chữ chỉ được đo bằng ước lượng (mỗi ký tự rộng nửa cỡ chữ, chưa có font); `List` không cuộn; `Button` chưa có style và trạng thái nhấn; chưa có `ScrollView`, `TextField`, `sheet`, `alert`, `TabView`, `Form`, `Label`; chỉ có lệnh chạm, chưa có kéo, cuộn, gõ chữ; host chưa có đồng hồ khung hình nên animation và timer không chạy. Bản debug in 39 cảnh báo "is unimplemented" ra stderr cho frame đầu và 198 cho cả kịch bản, phần lớn là `Subgraph.index`, `ShapeStyleRendering` và `maxFontMetrics` của upstream.
- **Yêu cầu build trên Linux:** Swift 6.4.1, `libssl-dev` và `uuid-dev` (Compute cần `openssl/sha.h`, `uuid/uuid.h` và link `-lcrypto`), khoảng 1,5 GB cho thư mục build debug.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Lấy OpenSwiftUI 0.23.1 và 5 package anh em theo SHA đã pin, áp patch thành commit, cảnh báo khi patch đổi sau lần lấy trước | `runtimes/ios/Scripts/fetch-openswiftui.sh` |
| Cấu hình build cho Linux: backend Compute, dùng checkout local, tắt target GTK, đường dẫn header của toolchain | `runtimes/ios/Scripts/env.sh` |
| Patch cho OpenSwiftUI và OpenObservation | `runtimes/ios/Patches/openswiftui/`, `runtimes/ios/Patches/openobservation/` |
| Compile một thư mục app SwiftUI không sửa code: gom file Swift (bỏ test, Pods, Carthage), bỏ `#Preview`, sinh package SwiftPM, build | `runtimes/ios/Scripts/compile-app.sh`; từ P1-12 phần gom file và bỏ preview nằm trong công cụ `irisrun-ios-build` |
| Kịch bản chạm cho app mẫu, script build và kiểm tra | `examples/ios-swiftui/session.txt`, `runtimes/ios/Scripts/check-sample.sh` |
| Giữ khoảng trắng cuối dòng trong patch khi sửa bằng editor | `runtimes/ios/Patches/.editorconfig` |

Checkout và thư mục build nằm ở `~/.cache/irisrun/p0-05` (đổi bằng biến `IRISRUN_IOS_WORK`), ngoài repo. `runtimes/ios/Package.swift` (IrisProtocol) giữ nguyên, `swift test` ở đó vẫn đạt.

Các pin, kiểm lại với upstream ngày 15/10/2026:

| Package | Pin | Nguồn |
| --- | --- | --- |
| OpenSwiftUI | `9a26fd83` | tag 0.23.1 (7/10/2026), tag mới nhất |
| OpenAttributeGraph | `46f2e1b8` | `Package.resolved` của OpenSwiftUI 0.23.1 |
| OpenCoreGraphics | `df5ab4c4` | như trên |
| OpenObservation | `51c52f31` | như trên |
| OpenRenderBox | `7a85270f` | như trên (HEAD hiện đã đi tiếp) |
| Compute | `ef29bc33` | tag 0.6.0, bản mà OpenAttributeGraph yêu cầu khi bật Compute |

Các dependency lấy qua mạng do SwiftPM tự resolve: swift-syntax 603.0.2, swift-crypto 3.15.1, swift-asn1 1.7.3, OpenCombine 0.17.0, swift-log 1.16.1.

**Vì sao chọn backend Compute.** OpenSwiftUI cần một AttributeGraph. Trên Linux có hai bản mở: OpenAttributeGraph (chưa xong, README của upstream ghi rõ) và Compute, bản viết lại AttributeGraph bằng C++ của jcmosc. Ví dụ stdout của upstream trên Linux cũng dùng Compute.

**Vì sao alias Observation sang OpenObservation.** OpenSwiftUI theo dõi `@Observable` qua OpenObservation, bản chép Observation của Swift có mở SPI cho SwiftUI. App mẫu dùng `import Observation`. Nếu để app dùng Observation thật của toolchain thì OpenSwiftUI không thấy được truy cập vào model, vì `ObservationRegistrar` của toolchain chỉ ghi lại truy cập vào một thread-local mà `withObservationTracking` của chính nó đặt, qua `_swift_observation_tls_get/set`, và `libswiftObservation.so` không export hai hàm này. Nên app được compile với `-module-alias Observation=OpenObservation`, giống cách alias SwiftUI.

## Chạy thử

`fetch-openswiftui.sh` chỉ cần git. Các lệnh còn lại cần Swift 6.4.1, `libssl-dev` và `uuid-dev`. Từ P0-06, OpenSwiftUI trên Linux đo chữ bằng render core, nên chúng cũng cần `target/release/libirisrun_render.a` (`cargo build -p irisrun-render --release`, cần `libfontconfig1-dev` và `libfreetype-dev`) cùng font của nó (`crates/render/fetch-fonts.sh`). Ở máy dev thì đặt `swiftenv` (wrapper `docker run` của image `irisrun-swift-dev:6.4.1`) trước mỗi lệnh, kể cả lệnh chạy binary:

```sh
cd runtimes/ios
Scripts/fetch-openswiftui.sh     # khoảng 25 s; checkout ở ~/.cache/irisrun/p0-05/checkouts
Scripts/check-sample.sh          # build app mẫu, chạy session.txt, in các frame, kiểm 14 điểm

# Từng bước:
bin=$(Scripts/compile-app.sh ../../examples/ios-swiftui/IrisSample)   # thêm "-c release" để build release
"$bin" < ../../examples/ios-swiftui/session.txt
"$bin"     # gõ lệnh tay, mỗi dòng một lệnh; Ctrl-D để thoát
```

Lệnh của runtime stdout, đọc từ stdin sau frame đầu:

- `tap <chữ>`: chạm vào giữa Text đầu tiên có đúng nội dung `<chữ>`.
- `tap <x> <y>`: chạm vào một điểm, đơn vị point, gốc ở góc trên bên trái.
- Dòng trống và dòng bắt đầu bằng `#` bị bỏ qua.

Mỗi lệnh được in lại sau dấu `> `, rồi tới frame mới nếu display list đổi. Ví dụ, sau `tap Add to favorites` trên màn chi tiết:

```
> tap Add to favorites
OpenSwiftUI backend: stdout
surface: 390.0x844.0
display-list-version: 49
rendered:
  - text x:16.0 y:12.0 w:51.0 h:21.0 #000000FF:"‹ Back"
  - text x:16.0 y:44.0 w:187.0 h:41.0 #000000FF:"Truyện Kiều"
  - text x:118.0 y:411.0 w:154.0 h:34.0 #000000FF:"Truyện Kiều"
  - text x:153.0 y:461.0 w:85.0 h:21.0 #3C3C4399:"★ Favorite"
  - text x:106.0 y:498.0 w:179.0 h:21.0 #000000FF:"Remove from favorites"
```

Màu `#3C3C4399` của "★ Favorite" là `.secondary` của iOS, do OpenSwiftUI tự tính. Biến `OPENSWIFTUI_PRINT_TREE=1` in thêm cả cây display list.

**Hook cho P0-08.** `compile-app.sh <app-dir>` là lệnh mà `ios-corpus compile` gọi cho từng app; thoát với mã 0 nghĩa là compile được:

```sh
cd tools/ios-corpus
$ios compile corpus.json $W/apps $W/out ../../runtimes/ios/Scripts/compile-app.sh
```

Mọi app dùng chung một thư mục build cho mỗi cấu hình (`$IRISRUN_IOS_WORK/build/apps-debug`, `apps-release`), nên OpenSwiftUI chỉ build một lần. App có `@main` hoặc `main.swift` được link thành file chạy; app khác chỉ compile tới module. Script gom mọi file `.swift` trong thư mục, nên repo có nhiều target (ví dụ macOS và iOS cùng có `ContentView.swift`) sẽ lỗi trùng tên file; chọn đúng file theo target là việc của P1-12.

## Số đo

`-j 6`, load 10–35 trên 12 nhân vì các task khác build cùng lúc. Thời gian là số SwiftPM báo ("Build complete"), chưa gồm khoảng 8 s đọc manifest.

| Mục | Debug | Release | Ghi chú |
| --- | --- | --- | --- |
| Build lần đầu, upstream chưa patch (ví dụ stdout của upstream) | 398 s | — | load khoảng 10 |
| Build lần đầu, app mẫu và OpenSwiftUI đã patch | 641 s | 1740 s | load 14–35 |
| Build lại sau khi sửa một file của OpenSwiftUI | 57–165 s | — | thời gian tổng của `check-sample.sh`, gồm cả manifest và chạy kịch bản |
| Build lại khi không có gì đổi | 13 s | — | |
| Build lại chỉ phần app | APP_ONLY | — | |
| Đổi cấu hình trong cùng một thư mục build | 121 s | 1414 s | macro (swift-syntax) được build lại, kéo theo mọi module dùng macro. Vì vậy `compile-app.sh` dùng thư mục riêng cho debug và release |
| Binary | 123 MB | 87 MB, 17 MB sau strip | OpenSwiftUI, Compute và BoringSSL link tĩnh; runtime Swift, Foundation (gồm ICU) và `libcrypto` link động |
| Lên frame đầu rồi thoát | 0,3–0,6 s | 0,04–0,05 s | stdin là `/dev/null` |
| Cả kịch bản: 8 frame, 7 lần chạm | 0,5–0,6 s | 0,06–0,07 s | |
| RAM tối đa | 55 MB | 43 MB | |
| Thư mục build | khoảng 1,5 GB | | checkout 81 MB |

## Patch và lý do

| Patch | Sửa gì | Vì sao |
| --- | --- | --- |
| `openswiftui/0001` Measure text without CoreText | Trên Linux, font được resolve thành `CTFont` giả mang cỡ chữ và độ đậm. Cỡ chữ theo text style lấy từ bảng cỡ chữ iOS ở cỡ Dynamic Type mặc định (body 17, title 28, largeTitle 34…). Đo chữ bằng ước lượng: mỗi ký tự rộng nửa cỡ chữ, dòng cao 1,2 lần cỡ chữ, xuống dòng theo chiều rộng được đề xuất | Upstream crash (`_openSwiftUIPlatformUnimplementedFailure`) khi tạo font không có CoreText, và đo chữ ra 0 nên Text bị bỏ khỏi display list |
| `openswiftui/0002` Print text in the stdout renderer on Linux | In text run trên Linux (trước chỉ có macOS); đổi màu `NDColor` về `Color.Resolved`; đặt display list lồng nhau theo gốc của item chứa nó; thêm `stdoutFrame(ofText:)` | Không có text thì output không chứng minh được gì. Upstream bỏ qua toạ độ gốc của effect, nên các dòng của List bị in đè lên tiêu đề. Script cần tìm khung của Text để chạm |
| `openswiftui/0003` Drive the stdout app from stdin | Host stdout xuất cả responder và có `EventBindingManager`. Sau frame đầu, app đọc lệnh từ stdin cho tới khi stdin đóng. `tap` gửi `TouchEvent` began rồi ended qua hệ gesture thật, reset gesture graph, rồi render lại. Frame đầu được vẽ sau khi update đầu kết thúc, để các action như đổi preference có mặt trong frame đầu. Bề mặt mặc định trên Linux là 390×844 point | Upstream vẽ một frame rồi thoát, không có đường nào đưa input vào |
| `openswiftui/0004` Add Button, List and NavigationStack for Linux | `Button` chạy action khi chạm vào nhãn (`onTapGesture`); `List` xếp mỗi view con thành một dòng cao tối thiểu 44 point, qua `_VariadicView`; `NavigationStack` hiện một trang (gốc hoặc trang cuối được đẩy), trên có nút "‹ Back" và tiêu đề lớn; `NavigationLink`; `navigationTitle` ghi vào `NavigationTitleKey` sẵn có của upstream | `Button` trong 0.23.1 là stub rỗng; chưa có List và navigation. Đây là bản nhỏ nhất chạy được app mẫu |
| `openswiftui/0005` Re-export OpenObservation | `@_exported public import OpenObservation` | SwiftUI re-export Observation, nên app dùng `@Observable` chỉ với `import SwiftUI` |
| `openobservation/0001` Expand @Observable against the Observation alias | Macro sinh `Observation.ObservationRegistrar` thay vì `OpenObservation.ObservationRegistrar` | Khi đã `-module-alias Observation=OpenObservation`, code của app không được gọi module bằng tên thật, kể cả code do macro sinh ra (lỗi "cannot find 'OpenObservation' in scope") |

Sửa patch: sửa và commit trong checkout, rồi chạy `git format-patch --no-signature --zero-commit -o Patches/openswiftui 9a26fd83` (đầu `fetch-openswiftui.sh` có ghi lệnh này). Khi có `github.com/irisrun/OpenSwiftUI` thì đẩy các commit này lên fork, trỏ pin sang commit của fork và xoá thư mục patch.

## Rủi ro

1. **Upstream đổi nhanh.** 0.23.1 ra ngày 7/10/2026 và `main` đã đi tiếp. Patch đụng file hay đổi (`StdoutApp.swift`, `Font.swift`). Nên gửi lên upstream phần dùng chung (text trên Linux, toạ độ display list lồng nhau, input cho host stdout), giữ ở fork phần riêng của Iris.
2. **`Button`, `List`, `NavigationStack` là bản tạm của Iris.** Khi upstream có bản thật thì bỏ bản của mình và chạy lại corpus.
3. **Compute** là bản viết lại AttributeGraph của một người. Nếu graph sai hoặc chậm thì khó sửa; OpenAttributeGraph trên Linux chưa dùng được để thay.
4. **Alias Observation.** Package bên thứ ba có `import Observation` cũng phải compile với cùng alias, nếu không `@Observable` của nó không được theo dõi. P1-12 build package từ source nên làm được; module dựng sẵn dùng Observation thật thì không.
5. **Đo chữ là ước lượng,** nên khung của Text lệch so với iOS cho tới khi render core đo bằng font thật.
6. **Build nặng.** Build lần đầu mất 7–11 phút, thư mục build khoảng 1,5 GB, binary debug 123 MB. Không thể bắt user build OpenSwiftUI từ source: phải ship OpenKit dựng sẵn theo từng phiên bản toolchain.
7. Swift 6.4.1 báo khoảng 1100 warning trong code upstream (concurrency, isolation). Compiler sau có thể biến một phần thành lỗi.
8. Dependency qua mạng (swift-syntax, swift-crypto, OpenCombine, swift-log) chưa pin, lần resolve sau có thể lấy bản khác.
9. SwiftPM 6.4.1 build bằng backend swift-build mới. Một lần build bị crash (SIGSEGV trong `_dispatch_event_loop_drain` của libdispatch) ngay lúc lập kế hoạch build; chạy lại thì qua. Nếu còn gặp thì thử `--build-system native`.
10. Compute cần `libssl-dev` và `uuid-dev` khi build. Ship OpenKit dựng sẵn thì user không cần; nếu không thì phải bỏ hai phụ thuộc này (SHA-1 cho chữ ký kiểu, uuid cho trace).

## Việc cho P0-06 và P1-13

P0-06 đã có render core (`crates/render`, C API `iris_scene_*`, `iris_layer_*`) nhưng còn dựng bố cục bằng tay. Phần nối với OpenSwiftUI:

1. **Renderer mới bên cạnh `StdoutRenderer`.** `DisplayListStdoutRenderer.swift` là mẫu: một `ViewRendererBase` duyệt `DisplayList` (đã sửa cách tính toạ độ ở patch 0002). Map: `.content(.color)` và shape màu đơn thành nền layer; `.content(.text)` thành `iris_layer_set_text` (run lấy từ `NSAttributedString` trong `StyledTextContentView`, có `kitFont` mang cỡ chữ và độ đậm, `kitForegroundColor` là `NDColor`); `.effect(.opacity)`, `.effect(.transform)` và clip thành opacity, transform, `masksToBounds` của layer. Thêm một case vào `_RendererConfiguration.Renderer` và một host giống `StdoutRendererHost`.
2. **Đo chữ thật.** Thay nhánh `#else` trong `NSAttributedString.measured(...)` (`Text+StringDrawingContext.swift`) bằng `iris_scene_measure_text`, và cho `fontCache` trên Linux (`Font.swift`) giữ đủ thông tin để dựng `IrisTextStyle`. Đo và vẽ phải dùng cùng font, nếu không chữ sẽ bị cắt hoặc lệch dòng.
3. **Vòng lặp khung hình.** `StdoutRendererHost.requestUpdate(after:)` đang rỗng, nên animation, `TimelineView` và timer không chạy. Host thật phải gọi `render(interval:)` theo đồng hồ.
4. **Input và giao thức.** Thay lệnh chữ trên stdin bằng IrisProtocol qua stdio như host Android. `TouchInput` map thẳng sang `TouchEvent` (began, moved, ended) gửi qua `EventBindingManager`, rồi reset khi pha kết thúc, như lệnh `tap` đang làm. Bản debug in một dòng "ViewRendererVendor" ra stdout; phải chuyển sang stderr trước khi stdout mang protobuf.

P1-13:

1. Làm các control còn thiếu theo bảng xếp hạng của P0-08: `ScrollView` và lazy stack (để `List` cuộn được), style cho `Button`, `TextField` cùng IME, `sheet`, `alert`, `TabView`, `Form`, `Section`, `Label`, `Image` có asset, `NavigationStack` có `path`, toolbar và hiệu ứng chuyển trang.
2. Lập fork `github.com/irisrun/OpenSwiftUI` từ các patch này, rebase theo mỗi release của upstream, gửi phần dùng chung lên upstream.
3. Dựng sẵn OpenKit (`.swiftmodule` và thư viện) trong CI cho mỗi phiên bản Swift, để app của user chỉ phải compile phần của mình; pin luôn các dependency qua mạng.
4. Thêm `Scripts/check-sample.sh` vào CI (container `swift:6.4.1-noble` cần thêm `libssl-dev`, `uuid-dev`, cùng render core và font như job `render`; nên cache thư mục build vì build lần đầu mất vài phút).
