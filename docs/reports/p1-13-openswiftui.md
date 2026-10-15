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
