# Tiến độ triển khai

Cập nhật 15/10/2026, session thứ năm (P1-15 xong, P1-13 đợt 1 xong). File này để session sau làm tiếp; cột trạng thái trong [tasks.md](tasks.md) đã cập nhật theo.

## Tổng quan

| Task | Trạng thái | Ghi chú |
| --- | --- | --- |
| P0-01 Monorepo + CI | Xong ở local | Rust, TS, Kotlin, Swift và `buf lint` đều xanh ở local. CI GitHub chưa chạy: cần push lên `origin` (github.com/ndmt1at21/irisrun) |
| P0-02 Device Protocol v0 | Xong ở local | `proto/irisrun/device/v1alpha1/`. buf lint không nhận hậu tố `v0` nên package là `v1alpha1`. Một lệnh sinh code: `pnpm proto:generate` |
| P0-03 Tải toolchain | Xong (Linux) | Xem [reports/p0-03-toolchain.md](reports/p0-03-toolchain.md). macOS chưa chạy thử |
| P0-04 Android runtime | Xong | App View và app Compose chạy không sửa code; chạm, gõ chữ, Back đều đúng. Số đo và giới hạn: [reports/p0-04-android-runtime.md](reports/p0-04-android-runtime.md) |
| P0-12 Device UI | Xong | Thử trên Chromium headless, sửa 4 lỗi; player WebRTC cho thiết bị cloud ở `/#/live?gateway=<url>` (`webrtc.ts`, `VideoScreen.tsx`). Xem [reports/p0-12-device-ui.md](reports/p0-12-device-ui.md). UI mới theo [ui-plan.md](ui-plan.md) đã xong với mock (UI-01 … UI-12, 60 test xanh); nối backend là UI-13 |
| P0-05 OpenSwiftUI trên Linux | Xong | Go: lõi OpenSwiftUI 0.23.1 chạy trên Linux với 6 patch (~330 dòng); app mẫu compile không sửa dòng nào, `@State`/`@Observable` cập nhật đúng; `check-sample.sh` đạt 14 điểm (kiểm lại ở session thứ ba sau khi xoá module cache cũ). Xem [reports/p0-05-openswiftui-linux.md](reports/p0-05-openswiftui-linux.md) |
| P0-07 Objective-C trên Linux | Xong | Go cho ObjC bằng clang + libobjc2 (demo 26/26 kiểm tra); no-go cho fork toolchain Swift bật ObjC interop (38–63 người-tuần). `@objc`, `#selector`, KVO nên viết lại source ở P1. Xem [reports/p0-07-objc-linux.md](reports/p0-07-objc-linux.md) |
| P0-08 Corpus iOS | Xong, trừ tỉ lệ compile | 65 app, bảng xếp hạng API, kiểm kê build, trần tỉ lệ compile ước từ import: 18 app (28%) nếu có stub cho mọi framework, 39 app (60%) nếu thêm bước viết lại `@objc`/`#selector`. Lệnh `compile` đã nối với `runtimes/ios/Scripts/compile-app.sh` của P0-05 nhưng script đó hiện compile được 0/65 app (thiếu UIKit, Combine, stub, chọn target). Xem [reports/p0-08-ios-corpus.md](reports/p0-08-ios-corpus.md) |
| P0-09 Binary Doctor | Xong | `crates/doctor`, lệnh `irisrun doctor <path>`; quét 14 SDK, xem [reports/p0-09-binary-doctor.md](reports/p0-09-binary-doctor.md) |
| P0-06 Render core | Xong | `crates/render`: cây layer kiểu CALayer, C ABI, lớp bọc Swift. OpenSwiftUI đo và vẽ chữ qua render core (patch 0006–0008): app mẫu ra 8 frame PNG, `check-sample.sh` đạt 14 điểm ở cả chế độ stdout và frame (kiểm lại ở session thứ tư). 2x: 32–55 fps từ display list ra JPEG. Xem [reports/p0-06-render-core.md](reports/p0-06-render-core.md) |
| P0-10 cloud Android | Xong ở local | Emulator Android 16 trong container trên KVM → scrcpy-server → `irisrun-gateway` (str0m) → WebRTC → Chromium; chạm, kéo, phím, chữ (cả tiếng Việt), Back đều chạy. Còn đo từ VN tới host Singapore. Xem [reports/p0-10-cloud-android.md](reports/p0-10-cloud-android.md) |
| P1-14 Render core v1 | Xong phần code | Chữ nhiều kiểu, metric chữ thật, bóng đổ, path, gradient, mask, ảnh theo `contentMode`, animation, hit-test, frame mã hoá ở luồng khác; OpenSwiftUI dùng metric thật (patch 0009). Còn so ảnh với simulator. Xem [reports/p1-14-render-core-v1.md](reports/p1-14-render-core-v1.md) |
| P1-15 Input iOS | Xong | Form đăng nhập mẫu gõ Telex được trong Device UI (sự kiện IME của Chromium). `DragGesture`, `ScrollView`, `List` cuộn; `TextField`/`SecureField`/`TextEditor` vẽ bằng SwiftUI, caret theo render core; `@FocusState`/`onSubmit` bản Iris; app chạy như thiết bị IrisProtocol qua stdio; `irisrun start` nhận project Xcode. Input → frame trung vị 17 ms. Compute nâng 0.6.0-bugfix.1 kèm patch. Chưa thử bộ gõ thật của hệ điều hành. Xem [reports/p1-15-ios-input.md](reports/p1-15-ios-input.md) |
| P1-13 Mở rộng OpenSwiftUI | Đang làm | Đợt 1 xong: path, nét viền, clip theo path, chữ nhiều kiểu, gradient, bóng đổ, ảnh từ asset catalog, `import SwiftUI` kéo theo Foundation (patch 0014–0018). Đợt 2 đang làm (patch 0019–0020: Toggle, Slider, ProgressView, Label, Section, Form, Stepper, lazy stack, NavigationView). Xem [reports/p1-13-openswiftui.md](reports/p1-13-openswiftui.md) |
| P1-12 Pipeline build iOS | Xong phần pipeline | `irisrun-ios-build` (Swift, chỉ Foundation) đọc `.pbxproj` kể cả thư mục đồng bộ của Xcode 16, chọn target iOS, gom source/resource/gói SPM, bỏ preview, `.xcstrings` → `.strings`, sinh SwiftPM; 65/65 app corpus đọc được; app mẫu build qua `IrisSample.xcodeproj`. Nửa UIKit chờ P1-16, P1-33. Xem [reports/p1-12-ios-build-pipeline.md](reports/p1-12-ios-build-pipeline.md) |
| P0-11 cloud iOS | Hoãn | Tầng dự phòng chạy simulator thật, cần Mac thuê (EC2 Mac hoặc MacStadium). Đường iOS chính (OpenKit trên Linux) không phụ thuộc nó. Người dùng chọn hoãn ngày 15/10 |
| P0-13, P0-14, P0-15, P0-16 | Không phải việc code | Pháp lý, đối tác, họp cổng 0, giữ chỗ tên |

## Task giao subagent

P0-05, P0-07 và P0-08 do subagent làm trong session thứ hai, mỗi task chỉ sửa trong vùng của nó: `runtimes/ios/**` và `examples/ios-swiftui/**` (P0-05), `native/objc/**` (P0-07), `tools/ios-corpus/**` (P0-08), cùng báo cáo của mình. P0-07 và P0-08 đã bàn giao, và test đã chạy lại đạt. P0-05 xem mục "Làm tiếp".

## Làm tiếp

1. **P0-05** đã xong. Build của nó ở `~/.cache/irisrun/p0-05/build/apps-{debug,release}`; nếu báo "missing required module", xoá `out/ModuleCache.noindex` trong thư mục đó rồi build lại.
2. **P0-06** đã xong (subagent, session thứ ba và thứ tư). Từ đây mọi build OpenSwiftUI trên Linux, kể cả chế độ stdout và `ios-corpus compile`, cần `target/release/libirisrun_render.a` và font của render core. Chế độ frame: `swiftenv env IRISRUN_FRAMES=<thư mục> Scripts/check-sample.sh` (Docker không tự chuyển biến môi trường vào container). Việc còn lại thuộc P1-13, P1-14: mục "Việc cho P1-13 và P1-14" của báo cáo P0-06.
3. Player WebRTC cho Device UI đã xong (session thứ ba); session UI giữ phần còn lại của `apps/web`, chỉ chạm `LiveDevicePage`, `Screen`, `connection`, `input`, `useDevice`, `webrtc`, `VideoScreen` khi cần.
4. **Quyết định của người dùng ngày 15/10 (session thứ tư):** vào Phase 1 trước khi họp cổng 0, ưu tiên iOS không cần Mac theo thứ tự P1-14 render core v1 → P1-12 pipeline build iOS → P1-15 input iOS → P1-13 mở rộng OpenSwiftUI → P1-16 UIKit cơ bản; Android và server local (P1-03, P1-07, P1-08) làm xen khi iOS chờ build. P0-11 hoãn tới khi có Mac. `docs/tasks.md` là bản chuẩn của trạng thái task, không đồng bộ sang tab "Tasks" của Claude Docs.
5. Job `render` và job `rust` (gói fontconfig/freetype, font) trong CI chưa chạy trên GitHub.
6. **P1-15 xong (session thứ năm),** xem báo cáo. Patch `openswiftui/0010`–`0013` và `compute/0001`; Compute ghim ở 0.6.0-bugfix.1. Chạy app iOS trong Device UI: `IRISRUN_SWIFT_RUNNER=swiftenv target/debug/irisrun start examples/ios-swiftui`, rồi mở `/#/live`. **Tiếp theo: P1-13** (mở rộng OpenSwiftUI). Host IrisProtocol đã làm ở P1-15; còn nối ảnh, gradient, shape, clip tuỳ ý, bóng đổ, chữ nhiều kiểu vào render core, style iOS cho `List`/`Button`, các control theo bảng xếp hạng P0-08, dựng sẵn OpenKit, `check-sample.sh` vào CI. Rồi P1-16 (UIKit cơ bản); P1-03, P1-07, P1-08 làm xen khi iOS chờ build.

Emulator và gateway của P0-10 chạy lại theo mục "Chạy lại" của báo cáo. Image `irisrun-emulator:36` (4,6 GB) còn trong Docker. Gateway bị dừng bằng PID: `pkill -x` không khớp vì tên process bị cắt còn 15 ký tự (`irisrun-gateway`).

## Kế hoạch P1-13 (task XL, chia đợt)

Thứ tự theo bảng xếp hạng API của P0-08 (mục "Ý nghĩa với thứ tự làm P1-13"). Mỗi đợt là một hoặc vài patch OpenSwiftUI, có thêm bước vào `session.txt` hoặc app mẫu, và ảnh PNG để xem.

1. **Vẽ nốt display list bằng render core** (`DisplayListLayerRenderer.swift`): path tuỳ ý và nét viền (`Path`, `Capsule`, `.stroke`, `.strokeBorder`, nét đứt), `clipShape` theo path (mask), chữ nhiều kiểu (`Text + Text`, `.italic`, `.underline`, `.strikethrough`, `.kerning`, `.baselineOffset`), `.shadow`, gradient, ảnh từ `Assets.xcassets` (`Image("tên")`, `.resizable`, `.scaledToFit`/`Fill`), `Image(systemName:)` tạm bằng ô trống có kích thước đúng. Upstream 0.23.1: `StrokedPath` là stub rỗng (mất path và kiểu nét), `Gradient`/`LinearGradient`… chưa có (chỉ `Color.Resolved` là paint), `ORBPath(roundedRect:)` chưa làm trên Linux.
   **Xong (session thứ năm):** patch 0014–0018 và `compile-app.sh` chạy app từ thư mục có resource; xem [reports/p1-13-openswiftui.md](reports/p1-13-openswiftui.md). `session.txt` 25 điểm.
2. **Control và container:** đang làm. Xong: patch 0019 (`Toggle` có tiêu đề, công tắc, `Slider`, `ProgressView` vẽ bằng SwiftUI trên Linux; trước đó Toggle và ProgressView crash, Slider trống), patch 0020 (`Label`, `Section`, `Form` kiểu inset grouped, `Stepper`, `LazyVStack`/`LazyHStack`, `NavigationView`, `NavigationLink(destination:)`); màn "Cài đặt" của app mẫu là một `Form`; `session.txt` 29 điểm. Còn: lưới (`LazyVGrid`, `GridItem`), `TabView`, `Picker`, `Menu` (cần lớp trình bày của đợt 3), `ScrollViewReader`. Danh sách đầy đủ ban đầu: `Toggle`, `Picker`, `Section`/`Form`, `Divider`, `Label`, `ProgressView`, `Menu`, `LazyVStack`/`LazyVGrid`, `TabView`, `NavigationView`, `Link`, `Slider`, `Stepper`, `ScrollViewReader`.
3. **Trình bày:** `.sheet`, `.fullScreenCover`, `.alert`, `.confirmationDialog`, `.toolbar`, `.contextMenu`, `\.dismiss`, `\.openURL`.
4. **Style iOS:** `Button` (tint, trạng thái nhấn, disabled, `.bordered`, `.borderedProminent`), `List`/`Form` inset grouped (nền, đường kẻ), thanh điều hướng (tiêu đề lớn/inline, toolbar), màu dark mode.
5. **Hạ tầng:** dựng sẵn OpenKit theo phiên bản Swift, `check-sample.sh` vào CI, đo lại corpus.

## Môi trường máy dev (WSL2, Ubuntu 20.04, mạng chậm và chập chờn)

- Rust 1.95, pin trong `rust-toolchain.toml`. Node 22 và pnpm 11.28.5 qua corepack (`corepack enable`); corepack của Node 22 chưa chạy được pnpm 12.
- JDK 21: `~/.irisrun/toolchains/jdk-21.0.12.1+1`. Android SDK: `~/.irisrun/android-sdk` (license đã chấp nhận). Host Android: `~/.irisrun/maven`. Robolectric tải `android-all-instrumented` vào `~/.m2` (204 MB cho SDK 36, 228 MB cho SDK 37).
- **Swift 6.4.1 không chạy trên Ubuntu 20.04.** Từ session thứ hai, Swift chạy qua Docker Desktop (đã bật cho WSL). Image `irisrun-swift-dev:6.4.1` dựng từ `swift:6.4.1-noble`, thêm cmake, ninja, pkg-config, python3 (libobjc2 cho P0-07), fontconfig và freetype (render core), OpenSSL và uuid (backend Compute của OpenSwiftUI):

  ```sh
  printf '%s\n' 'FROM swift:6.4.1-noble' \
    'RUN apt-get update && apt-get install -y --no-install-recommends cmake ninja-build pkg-config python3 libfontconfig1-dev libfreetype-dev libssl-dev uuid-dev' |
    docker build -t irisrun-swift-dev:6.4.1 -
  ```

  Wrapper `swiftenv` chạy một lệnh trong image đó với user hiện tại, ở thư mục hiện tại, chia sẻ `$HOME` và `/tmp`:

  ```sh
  #!/bin/sh
  exec docker run --rm -i --user "$(id -u):$(id -g)" -e HOME="$HOME" \
    -v "$HOME:$HOME" -v /tmp:/tmp -w "$PWD" irisrun-swift-dev:6.4.1 "$@"
  ```

  Ví dụ: `cd runtimes/ios && swiftenv swift test`. Bản lưu của wrapper và các công cụ thử nằm ở `~/.cache/irisrun/devtools/`: `bin/swiftenv`, `bin/pnpm` (gọi `corepack pnpm`, vì máy chưa `corepack enable`), `client/client.mts` (client WebSocket của P0-04, chạy `node --experimental-transform-types --import ./register.mjs client.mts …`), `cdp/ui.mjs` (driver Chromium qua DevTools Protocol của P0-12), `swift-dev/Dockerfile`. Checkout và build lớn để ở `~/.cache/irisrun/…`, không để trong `/tmp`.
- GitHub API không đăng nhập chỉ có 60 request mỗi giờ: dùng URL tải trực tiếp hoặc `git ls-remote`.
- Đừng dùng `pgrep -f` với chuỗi có trong chính lệnh đang chạy (nó tự kill shell của mình); dùng `pgrep -x irisrun`.
- Shell là zsh: biến không có ngoặc không bị tách từ (`$STEPS` là một đối số). Dùng `${=STEPS}` hoặc chạy bằng bash khi ghép lệnh từ biến.
- Docker Desktop có thể đã tắt (vd. sau khi máy khởi động lại): bật bằng `cmd.exe /c start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"` rồi chờ `docker info`.
- Sau khi sửa host Android: `cd runtimes/android && ./gradlew publish`, rồi bấm Restart trong UI. Không cần build lại app, vì classpath trong `.irisrun/build/app.launch` trỏ thẳng vào jar trong `~/.irisrun/maven`.
- **Render core trên host:** máy không có gói `libfontconfig1-dev`, `libfreetype-dev`, nên thư mục `~/.cache/irisrun/devlibs` chứa symlink `libfontconfig.so`, `libfreetype.so` tới bản `.so.1`, `.so.6` của hệ thống. Mọi lệnh cargo cần link crate này (kể cả `cargo test --workspace`) chạy với `LIBRARY_PATH=$HOME/.cache/irisrun/devlibs`. Font cho test và demo: `crates/render/fetch-fonts.sh` (vào `~/.irisrun/fonts`).
- Gói Swift của render core build và chạy trong container: `cd crates/render/swift && swiftenv swift build -c release --scratch-path ~/.cache/irisrun/render-swift -Xlinker -L$PWD/../../../target/release`, rồi `swiftenv ~/.cache/irisrun/render-swift/release/render-demo <thư mục ra>`. Trong container `NSHomeDirectory()` trả `/home/ubuntu`, nên code đọc `$HOME` trước.

## Quyết định kỹ thuật

Session đầu:

- Code sinh từ proto được commit cho cả 4 ngôn ngữ (dùng remote plugin của BSR). CI fail nếu code sinh ra cũ hơn proto. Java và Kotlin dùng bản lite.
- Swift: các type có prefix `Iris` (`IrisHostMessage`…). Java package là `dev.irisrun.device.v1alpha1`.
- Tên message tránh trùng DOM và Android: `Input`, `TouchInput`, `TouchPoint`, `KeyInput`, `LocationUpdate`.
- Toolchain: URL và SHA-256 được pin trong `manifest.rs`; hash Swift tự tính vì swift.org chỉ có chữ ký PGP.
- Tại máy dev, tiến trình CLI ↔ runtime nói chuyện qua stdio; host chuyển `System.out` sang stderr. Server bảo vệ trước rác trên stdout bằng giới hạn envelope 64 MB.

Session thứ hai:

- Host Android gửi frame JPEG chất lượng 90 thay cho PNG: mã hoá nhanh hơn 5–10 lần, chữ nhìn như nhau.
- Host lấy view đang focus bằng `window.decorView.findFocus()`, vì `activity.currentFocus` bị Robolectric shadow và luôn trả null.
- App mẫu Compose dùng `compileSdk = 37` (Compose BOM 2026.09.00 đòi vậy), vẫn giữ `targetSdk = 36`. List có 20 mục để cuộn được.
- Render core chỉ dùng font được nạp vào scene, không dùng font của máy: Inter (Latin, tiếng Việt) và Noto Sans SC (Trung, kana Nhật), đều OFL. Font biến thiên lấy độ đậm từ trục `wght`.
- Id layer trong C ABI có số thế hệ, nên id của layer đã huỷ không bao giờ trỏ nhầm sang layer mới.

Session thứ năm (P1-15):

- **Compute nâng lên 0.6.0-bugfix.1** (`212355dc`): bản 0.6.0 so sánh một phần giá trị ở sai offset (`find_partial`), đọc nhầm case của enum và crash khi body có `if`/`else`. Thêm `Patches/compute/0001`: `IAG::vector` giữ phần tử inline trong mảng `T`, khi lớn quá 32 phần tử thì chép ra heap bằng `memcpy` mà vẫn huỷ bản cũ, nên `cf_ptr` bị release hai lần (crash khi `List` khoảng 16 hàng). Upstream chưa sửa lỗi thứ hai.
- **Đọc `@State` hay `Binding` trong action/callback trả giá trị của lần update trước** khi nhiều sự kiện xử lý giữa hai lần render (callback của gesture, `blur` của focus). Trạng thái mà callback đọc lại phải nằm trong một reference Observable (`ScrollState`, `FocusBox`, `TextEditingSession`), không trong `@State` giá trị.
- `.frame(minHeight:)` bị chặn bởi kích thước được đề xuất (đúng ngữ nghĩa SwiftUI), nên ScrollView đo nội dung bằng `onGeometryChange` *trước* frame đó. Preference từ `GeometryReader` trong `.background` không tới `onPreferenceChange` bên ngoài `GeometryReader` cha.
- `@FocusState` của upstream lấy giá trị từ responder đang focus của UIKit/AppKit; trên Linux Iris thay bằng `FocusBox` (giữ `#if canImport(Darwin)` cho bản upstream). `TextInputFocus.shared.session` là field đang nhận bàn phím.
- `Path.contains` cho hình bo góc gọi OpenRenderBox (chưa có trên Linux) và crash: patch 0010 tính bằng hình học.
- Host stdout render lại cả khi graph đổi trong lúc đang render (`graphDidChange`), vì thay đổi trong `onAppear` trước đó bị bỏ qua.
- Checkout OpenSwiftUI và Compute có `git config user.name irisrun`, `user.email irisrun@localhost` để commit patch; nhớ ghi lại stamp `.git/irisrun-patches` sau khi `format-patch`.

Session thứ tư:

- Render core: run chữ tính theo byte UTF-8; `contentMode` dùng raw value của `UIView.ContentMode`; animation không đổi giá trị của layer (như Core Animation), đồng hồ do bên gọi đặt; bóng đổ có đường nhanh cho hình bo góc đục; chưa thêm encoder JPEG khác (libjpeg-turbo SIMD cần `nasm`, máy chưa có).
- OpenSwiftUI có thêm patch 0009 (metric chữ thật, font mmap). Sửa patch: commit trong checkout `~/.cache/irisrun/p0-05/checkouts/OpenSwiftUI`, rồi `git format-patch --no-signature --zero-commit -o Patches/openswiftui 9a26fd83` và ghi lại stamp (sha256 16 ký tự đầu của các patch) vào `.git/irisrun-patches` của checkout.
- Pipeline iOS viết bằng Swift chỉ dùng Foundation, trong package `runtimes/ios`; asset catalog chép nguyên vì OpenKit sẽ đọc `Contents.json` lúc chạy; `.xcstrings` đổi sang `.lproj/*.strings`; bỏ preview bằng quét dòng, chưa cần SwiftSyntax.
