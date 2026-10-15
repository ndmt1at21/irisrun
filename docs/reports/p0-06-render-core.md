# P0-06 · Render core Rust + rust-skia

15/10/2026 · WSL2 Ubuntu 20.04, x86_64, 12 nhân, 15 GB RAM. rust-skia 0.153.3 (Skia m153, bản dựng sẵn), Swift 6.4.1 trong container Ubuntu 24.04. Lúc đo, máy đang build OpenSwiftUI cho P0-05 nên load là 10–15 trên 12 nhân; số đo trên máy rảnh sẽ tốt hơn.

## Kết luận

- **Đạt phần render core.** Crate `irisrun-render` giữ một cây layer kiểu `CALayer` và vẽ nó bằng Skia trên CPU. Swift gọi qua C ABI (`include/irisrun_render.h`) và vẽ đúng hai màn của app mẫu `examples/ios-swiftui`: danh sách Library (bộ đếm, sách, nút) và màn chi tiết, cả hiệu ứng push giữa hai màn.
- **Chữ đúng:** dấu tiếng Việt chồng nhau (ắ ằ ẳ ẵ ặ), tiếng Trung và kana Nhật qua font dự phòng, đủ độ đậm từ 100 tới 900, xuống dòng, cắt dòng có "…". Ảnh, bo góc, viền, clip, xoay và opacity theo nhóm đều đúng.
- **Đạt phần "vẽ app mẫu của P0-05".** Display list của OpenSwiftUI giờ điều khiển cây layer của render core. App mẫu `IrisSample` compile không sửa dòng nào và ra một PNG cho mỗi bước của `session.txt`: 8 frame 1170×2532 px. Chữ và vị trí trong frame khớp output của renderer stdout; một script đối chiếu cả 8 frame với khung chữ của display list và không thấy chỗ lệch. Chi tiết ở mục [Nối với OpenSwiftUI](#nối-với-openswiftui).
- **Layout đo chữ bằng chính render core,** với cùng font, cỡ chữ và độ đậm khi vẽ, nên chữ vừa khung: không xuống dòng hay bị cắt ngoài ý muốn. Khung chữ lệch 1–15% so với ước lượng của P0-05 (ví dụ "Add book" 68 → 78 pt).
- **Từ display list ra JPEG q90 đạt 32–55 fps ở 2x, 17–35 fps ở 3x** với các màn của app mẫu, lúc máy load 7–10. Dựng lại toàn bộ layer chỉ tốn 0,1–0,2 ms, phần còn lại là vẽ và mã hoá. OpenSwiftUI cập nhật sau một lần chạm mất 2–15 ms (release).
- **Cái giá:** binary release 109 MB (33 MB sau strip), lớn hơn P0-05 22 MB vì có Skia. Frame đầu tới sau 0,15–0,24 s thay vì 0,05 s, RAM tối đa 83 MB thay vì 43 MB, phần lớn do nạp font.
- **Vẽ nhanh, mã hoá chậm.** Vẽ một màn danh sách mất 7,5–9,4 ms ở 3x (1179×2556 px), tức hơn 100 fps. Mã hoá JPEG của Skia mới là nút cổ chai: khoảng 105 ms ở 3x khi máy đang tải. Cả vòng (vẽ + JPEG) đạt 14–20 fps ở 3x, 18–22 fps ở 2x, 73–77 fps ở 1x.
- libjpeg-turbo đi kèm Skia không có SIMD trên x86_64. Pillow, dùng libjpeg-turbo có SIMD, mã hoá cùng frame trong 31 ms lúc máy đang tải như vậy, tức nhanh gấp ba. Crate `jpeg-encoder` (Rust thuần, AVX2) không nhanh hơn Skia.
- Hướng cho P1-14: mã hoá bằng libjpeg-turbo có SIMD, và gửi frame ở scale mà Device UI cần (2x là đủ cho màn retina, vì canvas chỉ rộng khoảng 350 px). Vẽ chỉ chiếm vài ms nên 60 fps là trong tầm tay.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Cây layer, vẽ, mã hoá PNG/JPEG, đo chữ | `crates/render/src/lib.rs` |
| Font và paragraph (SkParagraph): chỉ dùng font đã nạp, dự phòng theo thứ tự nạp, độ đậm qua trục `wght` | `crates/render/src/text.rs` |
| C API | `crates/render/src/ffi.rs`, `crates/render/include/irisrun_render.h` |
| Tải font Inter và Noto Sans SC (OFL 1.1), ghim commit và SHA-256 | `crates/render/fetch-fonts.sh` |
| Lớp bọc Swift kiểu `CALayer`, demo vẽ app mẫu và đo fps | `crates/render/swift/` |
| CI: gói hệ thống và font cho job Rust; job `render` build lib, build gói Swift, chạy demo, tải frame lên artifact | `.github/workflows/ci.yml` |

Một layer có: `frame` (theo toạ độ layer cha, đơn vị point), `transform` affine quanh tâm (thứ tự của `CGAffineTransform`), `opacity` áp cho cả nhóm, `hidden`, màu nền, bo góc, viền, `masksToBounds`, cùng một nội dung là chữ hoặc ảnh. Thứ tự vẽ giống Core Animation: nền, nội dung, layer con, rồi viền nằm trên cùng, bên trong bounds.

Quyết định đáng chú ý:

- **Id có thế hệ.** `IrisLayer` là `uint64_t` gồm chỉ số ô và số thế hệ. Ô của layer đã huỷ được dùng lại dưới id mới, nên id cũ không bao giờ trỏ nhầm sang layer khác; hàm nhận id cũ chỉ trả `false`.
- **Huỷ một layer không huỷ layer con.** Layer con chỉ mất cha, vì phía Swift mỗi đối tượng giữ id của chính nó. Phía Swift, layer cha giữ layer con như `CALayer`, còn layer chỉ giữ tham chiếu `weak` tới scene, nên không có vòng tham chiếu. Scene mất rồi thì layer còn lại không làm gì cả.
- **Chỉ dùng font đã nạp, không dùng font của máy.** Nhờ vậy frame giống nhau trên mọi máy. SF Pro không dùng được ngoài máy Apple, nên Inter thay cho chữ Latin và tiếng Việt, Noto Sans SC cho chữ Trung và kana Nhật. Font biến thiên lấy độ đậm từ trục `wght` qua `FontArguments`, không cần nạp từng độ đậm.
- **Code `unsafe` chỉ nằm trong `ffi.rs`.** Workspace cấm `unsafe`; riêng module C ABI được mở và kiểm tra con trỏ null ở mọi hàm.

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Vẽ màn danh sách (không mã hoá) | 3x: 7,5–9,4 ms; 2x: 2,3–2,4 ms; 1x: 0,7–0,8 ms | 1179×2556, 786×1704, 393×852 px |
| Vẽ + JPEG q90 bằng Skia | 3x: 113 ms (9 fps); 2x: 45–54 ms (18–22 fps); 1x: 13–14 ms (73–77 fps) | Load 13–15 |
| Demo Swift, cả vòng qua C ABI ở 3x | Frame tĩnh 74 ms (14 fps), bộ đếm tăng mỗi frame 61 ms (16 fps), hiệu ứng push 50 ms (20 fps) | Load ~10. Lần chạy lúc load 15: 115 ms (9 fps) |
| Vẽ + PNG | 3x: 380 ms; 1x: 45 ms | Chỉ dùng để lưu ảnh |
| Cùng frame 3x, libjpeg-turbo có SIMD (Pillow) | 31 ms, 96 KB | Cùng lúc máy tải như trên |
| Cùng frame 3x, crate `jpeg-encoder` | 111 ms, 150 KB | Không nhanh hơn Skia |
| Cỡ frame JPEG q90 | 67–75 KB ở 3x | |
| `libirisrun_render.a` (release) | 79 MB | Gồm cả Skia. Binary demo sau khi link chỉ còn 22 MB, vì linker bỏ phần không dùng |
| Build | Lần đầu ~1 phút (tải Skia dựng sẵn); gói Swift 5–9 s | |

## Giới hạn và việc cho P1-13, P1-14

- Chưa có: bóng đổ, gradient, path tuỳ ý (cho `Shape`), blur và material, animation ngầm như Core Animation, hit-test, chữ nhiều kiểu trong một đoạn (`AttributedString`), giãn dòng và giãn chữ, emoji (cần Noto Color Emoji), bộ icon thay SF Symbols, chế độ co giãn ảnh (aspect fit/fill).
- Mỗi frame vẽ lại toàn bộ cây. Vẽ theo vùng bẩn chưa cần, vì vẽ chỉ tốn vài ms; mã hoá mới đáng tối ưu trước.
- Scene chỉ dùng trên một luồng. Vẽ và mã hoá ở luồng riêng để luồng chính của app không chờ là việc của P1-14.
- Bản Skia dựng sẵn trên Linux link `libfontconfig` và `libfreetype` của hệ thống, nên máy build cần gói `-dev` của chúng. Khi đóng gói OpenKit cho người dùng, nên tự build Skia không dùng fontconfig (chỉ font manager tuỳ biến), để máy dev không phải cài gì.
- Build trên macOS chưa thử. Ở đó Skia dùng CoreText thay fontconfig, nên `Package.swift` mới chỉ khai báo thư viện cho Linux.
- Màu đang cố định theo chế độ sáng; dark mode, Dynamic Type và profile thiết bị khác iPhone 16 thuộc P1-13, P1-28.

## Chạy lại

```sh
crates/render/fetch-fonts.sh                 # ~/.irisrun/fonts, 18 MB
cargo test -p irisrun-render                  # 3 test: vẽ, id cũ, chữ Việt/CJK/độ đậm/xuống dòng
cargo build -p irisrun-render --release
cd crates/render/swift
swift build -c release -Xlinker -L"$PWD/../../../target/release"
.build/release/render-demo /tmp/frames        # in fps, ghi library.png, push-midway.jpg, detail.png, typography.png
```

Trên Linux cần `libfontconfig1-dev` và `libfreetype-dev`. Máy dev hiện tại (Ubuntu 20.04) không có gói này và không có Swift 6.4.1, nên lib Rust build trên host với `LIBRARY_PATH` trỏ tới thư mục symlink `~/.cache/irisrun/devlibs`, còn gói Swift build và chạy trong container (xem [progress.md](../progress.md)).

## Nối với OpenSwiftUI

Làm sau khi P0-05 xong, cùng ngày, cùng máy. Lúc đo, máy chạy chung với các task khác nên load là 7–10 trên 12 nhân; số đo trên máy rảnh sẽ tốt hơn. Số đo là của bản release, trừ khi ghi khác.

### Kết luận

- **App mẫu của P0-05 ra frame qua render core.** Mỗi bước của `session.txt` ra một PNG, 8 frame 1170×2532 px (bề mặt 390×844 point của P0-05, ở 3x). `check-sample.sh` vẫn đạt 14 điểm ở cả chế độ stdout lẫn chế độ frame.
- **Frame khớp output của renderer stdout.** Ở chế độ frame, app in đúng từng dòng như chế độ stdout, kể cả số version của display list. Một script so từng PNG với khung chữ đã in: mực của mỗi chữ bắt đầu ở cạnh trái khung và nằm trong khung, ngoài khung không có mực. Cả 8 frame đều đạt; dịch khung đi 3% là script báo lỗi. Frame của bản debug và release giống nhau từng byte.
- **Đo chữ thật ở cả hai chế độ.** OpenSwiftUI đo chữ bằng `iris_scene_measure_text` của scene dùng để vẽ, nên khung do layout tính vừa đúng chữ được vẽ. Một app thử có đoạn văn bốn dòng, `lineLimit(2)` có "…" và chữ căn giữa nhiều dòng: số dòng vẽ ra khớp chiều cao khung.
- **Nhanh đủ cho Device UI ở 2x.** Từ display list ra JPEG q90 mất 18–31 ms ở 2x (32–55 fps), 28–60 ms ở 3x (17–35 fps), 5–6,5 ms ở 1x. Dựng lại toàn bộ layer mỗi frame chỉ tốn 0,1–0,2 ms, nên chưa cần cập nhật layer theo từng phần. Phần còn lại là vẽ và mã hoá JPEG; theo mục Số đo ở trên, mã hoá chiếm phần lớn.
- **Có vòng lặp khung hình.** Host giữ yêu cầu update của view graph, trước đây bị bỏ qua. Sau mỗi lệnh, app render tiếp theo đồng hồ ảo 60 Hz cho tới khi hết yêu cầu: trong app thử, một `withAnimation` chạy hết và frame ghi lại trạng thái cuối (chữ còn 30% opacity).
- **Chưa được:** baseline và số dòng chỉ là ước lượng; mỗi Text chỉ một kiểu chữ; clip, mask, `rotationEffect`, ảnh, gradient và bóng đổ chưa vẽ; frame chưa gửi theo thời gian thật; app chưa chạy RunLoop, nên timer và `DispatchQueue.main.async` không chạy. Frame giống display list hiện có chứ chưa giống iOS: `List` chưa có nền nhóm và đường kẻ, `Button` chưa có màu xanh.

### Đã làm

| Phần | Ở đâu |
| --- | --- |
| Font có modifier (`.bold()`, `.fontWeight(_:)`) lấy độ đậm từ font gốc rồi áp modifier, không cần CoreText. Trước đây chúng crash trên Linux | `runtimes/ios/Patches/openswiftui/0006` |
| OpenSwiftUI trên Linux phụ thuộc gói Swift `crates/render/swift`. App tạo scene của cửa sổ lúc khởi động, nạp Inter và Noto Sans SC | `0007`: `Package.swift`, `DisplayListLayerRenderer.swift`, `StdoutApp.swift` |
| Đo chữ bằng render core thay cho ước lượng nửa cỡ chữ của P0-05 | `0007`: `Text+StringDrawingContext.swift` |
| `LayerRenderer`, renderer mặc định trên Linux: mỗi display list mới thành cây layer (bảng dưới) | `0007`: `DisplayListLayerRenderer.swift`, `DisplayListViewRenderer.swift` |
| Chế độ frame: `IRISRUN_FRAMES=<dir>` ghi mỗi bước thành `frame-NNN.png`, `IRISRUN_SCALE` đặt số pixel mỗi point (mặc định 3), `IRISRUN_BENCH=<n>` đo n lần dựng layer, vẽ và mã hoá JPEG ở mỗi bước | `0007`: `StdoutApp.swift` |
| Vòng lặp khung hình: host giữ `requestUpdate(after:)`, app render theo đồng hồ ảo 60 Hz tới khi hết update, tối đa 2 s thời gian app | `0008`: `StdoutRendererHost.swift`, `StdoutApp.swift` |
| `env.sh` trỏ OpenSwiftUI tới gói Swift của render core; `compile-app.sh` link `libirisrun_render.a` và báo rõ khi chưa build nó; `check-sample.sh` ghi cách chạy chế độ frame | `runtimes/ios/Scripts/` |

Patch 0001–0005 được sinh lại bằng lệnh `format-patch` ghi trong `fetch-openswiftui.sh`; nội dung giữ nguyên, chỉ số trong dòng Subject đổi từ n/5 sang n/8. Áp 8 patch lên OpenSwiftUI 0.23.1 gốc ra đúng cây file đã build và đo. Code của render core (`crates/render`) không đổi: C API hiện có là đủ cho app mẫu.

Cách display list thành layer:

| Display list | Layer |
| --- | --- |
| `.color` | Layer có màu nền |
| `.shape` một màu: chữ nhật, chữ nhật bo góc, hình tròn | Màu nền và bo góc. Path khác chưa vẽ |
| `.text` | Layer chữ với font và màu của run đầu, `multilineTextAlignment`, `lineLimit` |
| `.flattened`, `.states` | Đặt các item con từ gốc của item chứa chúng |
| Effect `.opacity` | Layer nhóm có opacity |
| Effect `.transform(.affine)` | Layer nhóm có transform. Display list biến đổi quanh gốc của item, render core quanh tâm layer, nên phần dịch được tính lại |
| Effect khác | Vẽ nội dung như không có effect |

Quyết định đáng chú ý:

- **Renderer mặc định trên Linux là render core.** `_RendererConfiguration.Renderer.default` vốn là renderer của nền tảng (UIKit, AppKit), nên trên Linux nó tạo `LayerRenderer`. Không phải thêm case mới vào enum public của SwiftUI.
- **Một scene cho cửa sổ, dùng cho cả đo lẫn vẽ.** Font chỉ nạp một lần. Đo chữ thật dùng cả ở chế độ stdout, nên hai chế độ ra cùng một layout.
- **Dựng lại toàn bộ layer mỗi khi display list đổi,** thay vì giữ layer theo identity như `ViewUpdater` của SwiftUI. Đơn giản hơn nhiều, và với màn của app mẫu chỉ tốn 0,1–0,2 ms.
- **Baseline ước lượng bằng 80% chiều cao dòng,** gần đúng tỉ lệ ascent của cả Inter lẫn Noto Sans SC, vì C API chỉ trả rộng và cao. App mẫu không căn theo baseline nên không bị ảnh hưởng.

So với ước lượng của P0-05, chữ đổi chiều rộng còn chiều cao giữ nguyên (21 pt cho cỡ 17, 34 pt cho cỡ 28, 41 pt cho cỡ 34):

| Chữ | P0-05 (ước lượng) | Bây giờ (render core) |
| --- | --- | --- |
| "Library" (34 pt) | x 16, rộng 119 | x 16, rộng 113 |
| "Increment" | x 297, rộng 77 | x 293, rộng 81 |
| "Add book" | rộng 68 | rộng 78 |
| "Dế Mèn phiêu lưu ký" | rộng 162 | rộng 165 |
| "Truyện Kiều" (28 pt, màn chi tiết) | x 118, rộng 154 | x 116, rộng 159 |
| "Remove from favorites" | x 106, rộng 179 | x 104, rộng 182 |

### Chạy thử

```sh
cargo build -p irisrun-render --release     # libirisrun_render.a, app link vào
crates/render/fetch-fonts.sh                # Inter và Noto Sans SC vào ~/.irisrun/fonts
cd runtimes/ios
Scripts/fetch-openswiftui.sh                # nếu báo patch đã đổi: xoá ~/.cache/irisrun/p0-05/checkouts/OpenSwiftUI rồi chạy lại
IRISRUN_FRAMES=/tmp/frames Scripts/check-sample.sh      # chạy session.txt qua render core, ghi 8 PNG, kiểm 14 điểm
IRISRUN_FRAMES=/tmp/frames IRISRUN_BENCH=30 IRISRUN_SCALE=2 Scripts/check-sample.sh -c release
```

Không có `IRISRUN_FRAMES` thì `check-sample.sh` chạy như ở P0-05, chỉ khác là chữ được đo thật. Ở chế độ frame, sau mỗi bước app in display list như renderer stdout, rồi một dòng cho frame, có `IRISRUN_BENCH` thì thêm một dòng số đo:

```
frame: /tmp/frames/frame-003.png (update 2.9 ms, draw and PNG 95.8 ms)
bench: 30 frames, layers 0.1 ms, drawing and JPEG 29.6 ms (33 fps), 55 KB
```

`update` là thời gian OpenSwiftUI xử lý lệnh: gesture, layout có đo chữ, display list và dựng layer. Ở máy dev, Docker không chuyển biến môi trường vào container, nên chạy `swiftenv env IRISRUN_FRAMES=/tmp/frames Scripts/check-sample.sh`.

### Số đo

Số fps lấy từ `IRISRUN_BENCH=30`: 30 frame cho mỗi bước của kịch bản, 3 lần chạy ở 3x và 2x, 1 lần ở 1x.

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Display list → JPEG q90 (dựng layer, vẽ, mã hoá) | 3x: 28–60 ms (17–35 fps); 2x: 18–31 ms (32–55 fps); 1x: 5–6,5 ms (150–195 fps) | Từ lần nhanh nhất tới trung vị. Lúc máy tải nặng có frame tới 82 ms ở 3x, 74 ms ở 2x. Màn danh sách và màn chi tiết gần như nhau |
| Trong đó dựng lại toàn bộ layer | 0,1–0,2 ms | Tối đa 0,6 ms |
| Cỡ frame JPEG q90 | 3x: 46–56 KB; 2x: 26–33 KB; 1x: 9–12 KB | Nền trắng nên nhỏ hơn màn làm tay ở trên (67–75 KB) |
| OpenSwiftUI xử lý một lần chạm | 2–15 ms, trung vị 7–9 ms | Lúc máy tải có lần tới 87 ms. Bản debug: 6–19 ms |
| Render đầu tiên | 35–55 ms | Gồm layout lần đầu. Lúc máy tải tới 100 ms |
| Vẽ + PNG (chỉ để lưu ảnh) | 3x: 87–200 ms; 2x: 54–120 ms; 1x: 15–26 ms | Lúc máy tải tới 370 ms |
| Frame đầu rồi thoát | Chế độ stdout: 0,15–0,24 s (P0-05: 0,04–0,05 s). Chế độ frame, PNG 3x: 0,27–0,35 s | stdin là `/dev/null`. Thay Noto Sans SC bằng một bản Inter: 0,10–0,14 s. Bản debug gần như bằng bản release, vì phần lớn thời gian là nạp font và Skia |
| Cả kịch bản: 8 frame, 7 lần chạm | Chế độ stdout: 0,20–0,26 s. Chế độ frame, PNG 3x: 1,1–2,1 s | Mã hoá PNG chiếm phần lớn |
| RAM tối đa | 83 MB ở cả hai chế độ, với frame đầu hay cả kịch bản (P0-05: 43 MB) | Thay Noto Sans SC bằng một bản Inter: 50 MB. File font 18 MB bị chép ba lần lúc nạp (`Data`, `[UInt8]`, rồi Skia giữ một bản) |
| Binary | Release 109 MB, 33 MB sau strip (P0-05: 87 MB và 17 MB). Debug 150 MB (P0-05: 123 MB) | Thêm Skia; link động thêm `libfontconfig`, `libfreetype` |
| Build | Debug: 173 s lần đầu sau khi thêm render core, 67 s sau khi sửa vài file của OpenSwiftUICore. Release: 1087 s lần đầu, 88 s sau khi sửa một file của module OpenSwiftUI | Release lần đầu phải build lại cả Compute và swift-crypto, vì package graph đổi |

### Rủi ro

1. **Baseline và số dòng là ước lượng.** C API chỉ trả rộng và cao. Baseline đặt ở 80% chiều cao dòng, số dòng là chiều cao chia cho chiều cao một dòng. `.firstTextBaseline`, `.lastTextBaseline` và khoảng cách mặc định giữa các Text có thể lệch vài point; `maxFontMetrics` vẫn chưa có trên Linux (cảnh báo ở stderr).
2. **Một kiểu chữ cho mỗi Text.** Render core nhận một style cho cả đoạn, nên `Text + Text` hay `AttributedString` nhiều màu, nhiều font lấy font và màu của run đầu.
3. **Thay đổi state không tự gọi render.** OpenSwiftUI xếp thay đổi vào transaction rồi flush bằng observer của RunLoop (`GraphDelegate.beginTransaction`). App chưa chạy RunLoop vì chặn ở `readLine`, nên vẫn render ngay sau mỗi lần chạm như P0-05: bỏ lệnh render đó thì frame không đổi nữa. `Timer` và `DispatchQueue.main.async` cũng chưa chạy.
4. **Đồng hồ ảo.** Animation chạy hết trong thời gian ảo rồi frame mới được ghi. Hợp cho ảnh chụp và test, nhưng chưa phải 60 fps theo thời gian thật. Animation không dừng bị cắt sau 2 s thời gian app.
5. **Mọi build OpenSwiftUI trên Linux giờ cần render core,** kể cả chế độ stdout và `ios-corpus compile`: phải chạy `cargo build -p irisrun-render --release` và `fetch-fonts.sh` trước, máy build cần `libfontconfig1-dev`, `libfreetype-dev`. CI của `check-sample.sh` (P1-13) phải thêm hai bước này.
6. **Effect không hỗ trợ được vẽ như không có effect,** nên sai mà không báo: clip, mask, filter, `rotationEffect` (không phải transform affine trong display list). Ảnh, gradient, bóng đổ và path tuỳ ý chưa vẽ gì.
7. **Nạp font tốn 0,05 s và 33 MB RAM chỉ cho Noto Sans SC,** ở mỗi lần chạy app.
8. **Một scene toàn cục.** Đủ cho app một cửa sổ. Nhiều cửa sổ cần scene theo từng host.
9. `Font.custom(_:size:)` vẫn crash trên Linux: cần nạp font của app (P1-12) rồi mới đo được.

### Việc cho P1-13 và P1-14

P1-14, render core:

1. Đo chữ trả thêm baseline đầu, baseline cuối, số dòng, có bị cắt hay không, và metric của font (ascender, descender, cap height) cho `maxFontMetrics`; rồi bỏ ước lượng 80%. Đây là thay đổi C API đầu tiên nên làm.
2. Chữ nhiều kiểu trong một đoạn; path và stroke cho `Shape`; ảnh từ `GraphicsImage`; clip theo shape (`masksToBounds` đã có cho chữ nhật và bo góc); transform cho `rotationEffect`.
3. Mã hoá JPEG bằng libjpeg-turbo có SIMD, ở luồng riêng. Ở 2x đã đạt 30 fps cho màn của app mẫu.
4. Nạp font không chép: mmap, hoặc C API nhận đường dẫn file; nạp font CJK khi cần đến.

P1-13, fork OpenSwiftUI:

1. Host thật nói IrisProtocol qua stdio thay cho lệnh chữ trên stdin, chạy RunLoop chính, render theo đồng hồ thật khi view graph yêu cầu (`requestedUpdate` đã có) và gửi JPEG mỗi khi display list đổi.
2. Kích thước bề mặt và scale lấy từ profile thiết bị (hiện là 390×844 point và `IRISRUN_SCALE`).
3. `List`, `Button`, `NavigationStack` có style như iOS, để frame giống simulator chứ không chỉ giống display list.
4. Giữ layer theo identity của item khi màn đủ lớn để việc dựng lại hiện ra trong thời gian frame.
