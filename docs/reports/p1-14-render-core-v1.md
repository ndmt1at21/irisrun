# P1-14 · Render core v1

15/10/2026 · Máy dev WSL2 Ubuntu 20.04 (12 nhân), dùng chung với các session khác nên load 6–9 lúc đo. Swift 6.4.1 chạy trong container `irisrun-swift-dev:6.4.1`.

## Kết luận

- **Render core có đủ phần P1-14 yêu cầu:** chữ nhiều kiểu trong một đoạn (đậm, nghiêng, gạch chân, gạch ngang, giãn chữ, nâng baseline, giãn dòng) với font dự phòng cho tiếng Việt và CJK; ảnh từ file mã hoá hoặc từ pixel RGBA, đặt theo `contentMode`; clip theo path; bóng đổ; path tô và viền (có nét đứt); gradient thẳng, tròn, nón; animation thuộc tính kiểu `CABasicAnimation`; hit-test kiểu `CALayer.hitTest`. Mọi thứ đi qua C API (`include/irisrun_render.h`) và lớp bọc Swift `IrisRender`.
- **Đo chữ trả đủ thông số layout cần:** rộng, cao, baseline đầu, baseline cuối, số dòng, có bị cắt bởi `max_lines` không, và metric của font (ascender, descender, cap height, x-height). OpenSwiftUI giờ dùng thẳng các số này (patch 0009), bỏ ước lượng baseline bằng 80% chiều cao dòng của P0-06. App mẫu vẫn đạt 14 điểm của `check-sample.sh` ở cả chế độ stdout lẫn chế độ frame, và khung chữ không đổi điểm nào, vì app mẫu không căn theo baseline.
- **Frame mã hoá được ở luồng khác.** `iris_scene_render` trả một frame bất biến; `iris_frame_encode` chạy ở bất kỳ luồng nào trong lúc scene vẽ frame sau. Ở 3x, màn effects của demo đạt 22 ms/frame (45 fps) khi mã hoá song song, so với 69 ms/frame (15 fps) khi vẽ rồi mã hoá nối tiếp.
- **Chưa đạt tiêu chí "ảnh so với simulator thật đạt ngưỡng chốt ở cổng 0":** chưa có ảnh tham chiếu từ simulator (P0-11 hoãn vì chưa có Mac) và ngưỡng chưa chốt (cổng 0 chưa họp). Ảnh tham chiếu lấy được bằng runner macOS của GitHub Actions khi repo lên GitHub (P1-20).

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Chữ theo run (byte range UTF-8 + kiểu), kiểu đoạn (căn lề, số dòng tối đa, giãn dòng), metric khi đo, metric của font | `crates/render/src/text.rs` |
| Nạp font bằng mmap (`Data::from_filename`): font CJK 18 MB chỉ tốn RAM cho glyph được vẽ | `Scene::add_font_file`, `iris_scene_add_font_file` |
| Inter Italic (OFL, 906 KB) cho chữ nghiêng, ghim SHA-256 như hai font kia | `crates/render/fetch-fonts.sh` |
| Bóng đổ, mask theo path, `contentMode` của ảnh, nội dung Shape và Gradient | `crates/render/src/lib.rs` |
| Animation: giá trị nội suy theo đường cong Bézier bậc ba (các đường của Core Animation), lặp, chạy ngược; đồng hồ của scene do bên gọi đặt | `crates/render/src/animation.rs` |
| Hit-test từ trước ra sau qua transform, bỏ layer ẩn và phần bị mask | `Scene::hit_test` |
| Frame tách khỏi scene để mã hoá ở luồng khác | `Scene::render`, `encode`, `iris_frame_*` |
| C API cho tất cả phần trên, lớp bọc Swift (`TextRun`, `ParagraphStyle`, `TextMetrics`, `Path`, `ShapeStyle`, `Gradient`, `Animation`, `ContentMode`, `Frame`) | `include/irisrun_render.h`, `src/ffi.rs`, `swift/Sources/IrisRender/IrisRender.swift` |
| Màn "effects" trong demo: vẽ mọi tính năng mới, chạy animation 0,6 s ở 60 fps, kiểm hit-test, đo mã hoá song song | `swift/Sources/render-demo/main.swift` |
| 16 test Rust (thêm 13), trong đó một test đi qua C API với struct thật | `src/tests.rs`, `src/animation.rs`, `src/ffi.rs` |
| OpenSwiftUI dùng metric chữ thật và nạp font bằng mmap | `runtimes/ios/Patches/openswiftui/0009-*.patch` |

## Quyết định

- **Run tính theo byte UTF-8,** giống `NSRange` của chuỗi UTF-8 và SkParagraph. Range cắt giữa một ký tự được lùi về ranh giới ký tự gần nhất, vì bên gọi C dễ tính sai.
- **API chữ một kiểu (`TextStyle`) chỉ còn ở Swift,** dựng thành một run; C API chỉ có bản theo run. Patch 0007 vẫn compile mà không phải sửa.
- **`contentMode` dùng đúng raw value của `UIView.ContentMode`** (0 … 12), để UIKit (P1-16) truyền thẳng.
- **Animation không đổi giá trị của layer,** như Core Animation: frame hiện giá trị nội suy cho tới khi animation hết, sau đó hiện giá trị của layer. Một layer chỉ có một animation cho mỗi thuộc tính; thêm cái mới thay cái cũ. Đồng hồ do bên gọi đặt (`iris_scene_set_time`), nên host thật dùng đồng hồ thật còn test dùng đồng hồ ảo.
- **Hit-test dùng giá trị của layer, không dùng giá trị đang animate,** như `CALayer.hitTest`.
- **Bóng đổ có hai đường.** Layer có nền đục, không mask, không có gì tràn ra ngoài: vẽ hình chữ nhật bo góc làm mờ, rất rẻ. Còn lại: vẽ cả nhóm vào một lớp offscreen rồi làm mờ. Hai đường cho cùng kết quả (có test so ở scale 2).
- **Không thêm encoder JPEG khác.** Crate `jpeg-encoder` (Rust thuần, AVX2) nhanh hơn encoder của Skia khoảng 1,7 lần nhưng file lớn hơn 17%. libjpeg-turbo có SIMD cần `nasm` lúc build, cả máy dev lẫn image Swift đều chưa có.

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Màn có bóng đổ vẽ 280 ms/frame ở 3x | `save_layer` không có bounds nên Skia dựng lớp offscreen bằng cả màn hình rồi làm mờ toàn bộ; opacity theo nhóm cũng vậy | Bounds là vùng cây con thực sự vẽ (nội dung, sublayer, bóng của sublayer); thêm đường nhanh cho bóng của hình bo góc đục. Còn 69 ms/frame, phần lớn là JPEG |
| Bóng ở đường nhanh hẹp hơn đường nhóm | `MaskFilter::blur` với `respect_ctm = false` tính sigma theo pixel thiết bị, không nhân scale 3x | `respect_ctm = true`; test so hai đường, và test này báo lỗi khi đổi lại `false` |
| Đo chữ căn giữa với bề rộng vô hạn ra 0 dòng | SkParagraph không tạo dòng khi phải căn giữa hoặc căn phải trong bề rộng vô hạn (rộng, cao vẫn đúng nên bản cũ không lộ) | Khi bề rộng vô hạn thì đo với căn trái; căn lề không đổi thông số nào |
| Baseline đầu và baseline cuối của chữ một dòng lệch 0,4 pt | `alphabetic_baseline()` bỏ một phần leading; line metrics cho chỗ glyph thật sự được vẽ | Lấy cả hai baseline từ line metrics |
| Test C API abort ở bản debug | `set_font_families` với danh sách rỗng (scene chưa nạp font) đọc slice qua con trỏ null | Chỉ đặt family khi đã có font |

## Số đo

Demo chạy release, 3x (1179×2556 px), load 6–9:

| Mục | Số đo |
| --- | --- |
| Màn danh sách: vẽ + JPEG q90 nối tiếp | 49–51 ms/frame (20 fps) |
| Màn effects (bóng, gradient, path, mask, ảnh, animation): vẽ + JPEG nối tiếp | 69 ms/frame (15 fps); trước khi sửa bounds 280 ms |
| Màn effects, JPEG mã hoá ở luồng khác | 22 ms/frame (45 fps) |
| Chỉ mã hoá JPEG q90 một frame effects | Skia 65–80 ms (137 KB); `jpeg-encoder` 33–47 ms (160 KB) |
| App mẫu qua OpenSwiftUI, 2x: display list → JPEG q90 | 16–20 ms/frame (50–61 fps), 26–33 KB |
| Build lại OpenSwiftUI sau patch 0009 (release / debug, kèm chạy kịch bản) | 317 s / 119 s |
| Test Rust của render core | 16 test, 0,06 s |

## Giới hạn và việc tiếp

- **Chưa nối vào OpenSwiftUI** (việc của P1-13): chữ nhiều kiểu (`Text + Text`, `AttributedString`), `.italic()`, ảnh, gradient, path tuỳ ý cho `Shape`, `clipShape`, `shadow`, `rotationEffect`. Render core đã có đủ API cho các phần này; patch 0009 mới nối metric chữ và font.
- **Animation:** chưa có spring (`CASpringAnimation`, dùng nhiều trong UIKit), keyframe, và animation của transform đang nội suy từng phần tử ma trận (đúng cho dời và co giãn, sai cho xoay lớn). Chỉ năm thuộc tính: opacity, frame, transform, màu nền, bo góc.
- **Bóng đổ:** sigma lấy bằng nửa `shadowRadius` theo mắt; chưa có `shadowPath`. Cần so với simulator.
- **Ảnh:** thu nhỏ chưa dùng mipmap nên ảnh lớn thu nhiều lần bị răng cưa; chưa có ảnh vector, SF Symbols, emoji màu.
- **Mã hoá JPEG vẫn là phần chậm nhất:** 65–80 ms ở 3x khi máy tải. Nên stream ở 2x (đủ cho màn hình devicePixelRatio 2 của Device UI) hoặc thêm libjpeg-turbo có SIMD khi image build có `nasm`.
- **So ảnh với simulator:** cần ảnh tham chiếu từ simulator thật (runner macOS của GitHub Actions ở P1-20, hoặc Mac thuê ở P0-11) và ngưỡng chốt ở cổng 0.

## Chạy lại

```sh
crates/render/fetch-fonts.sh
LIBRARY_PATH=$HOME/.cache/irisrun/devlibs cargo test -p irisrun-render
cargo build -p irisrun-render --release
cd crates/render/swift && swift build -c release -Xlinker -L"$PWD/../../../target/release"
.build/release/render-demo /tmp/frames   # effects.png, animation-midway.jpg, số fps
```

Ở máy dev, Swift chạy qua `swiftenv` (xem `docs/progress.md`); `LIBRARY_PATH` chỉ cần khi máy không có gói `libfontconfig1-dev`, `libfreetype-dev`.
