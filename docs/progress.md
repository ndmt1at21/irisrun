# Tiến độ triển khai

Cập nhật 14/10/2026, session thứ hai. File này để session sau làm tiếp; cột trạng thái trong [tasks.md](tasks.md) đã cập nhật theo.

## Tổng quan

| Task | Trạng thái | Ghi chú |
| --- | --- | --- |
| P0-01 Monorepo + CI | Xong ở local | Rust, TS, Kotlin, Swift và `buf lint` đều xanh ở local. CI GitHub chưa chạy: cần push lên `origin` (github.com/ndmt1at21/irisrun) |
| P0-02 Device Protocol v0 | Xong ở local | `proto/irisrun/device/v1alpha1/`. buf lint không nhận hậu tố `v0` nên package là `v1alpha1`. Một lệnh sinh code: `pnpm proto:generate` |
| P0-03 Tải toolchain | Xong (Linux) | Xem [reports/p0-03-toolchain.md](reports/p0-03-toolchain.md). macOS chưa chạy thử |
| P0-04 Android runtime | Xong | App View và app Compose chạy không sửa code; chạm, gõ chữ, Back đều đúng. Số đo và giới hạn: [reports/p0-04-android-runtime.md](reports/p0-04-android-runtime.md) |
| P0-12 Device UI | Xong, trừ player WebRTC | Đã thử trên Chromium headless qua DevTools Protocol, sửa 4 lỗi: [reports/p0-12-device-ui.md](reports/p0-12-device-ui.md). Player WebRTC làm cùng P0-10. Một session khác đang dựng UI mới theo [ui-plan.md](ui-plan.md); bản thử chuyển sang `/#/live` |
| P0-05 OpenSwiftUI trên Linux | Dở, subagent dừng giữa chừng | Xem mục "Task giao subagent" |
| P0-07 Objective-C trên Linux | Dở, subagent dừng giữa chừng | Như trên |
| P0-08 Corpus iOS | Dở, subagent dừng giữa chừng | Như trên |
| P0-09 Binary Doctor | Xong | `crates/doctor`, lệnh `irisrun doctor <path>`; quét 14 SDK, xem [reports/p0-09-binary-doctor.md](reports/p0-09-binary-doctor.md) |
| P0-06 Render core, P0-10 cloud Android, P0-11 cloud iOS | Chưa làm | P0-06 chờ P0-05. P0-10 làm được ở local vì máy có `/dev/kvm`. P0-11 cần Mac |
| P0-13, P0-14, P0-15, P0-16 | Không phải việc code | Pháp lý, đối tác, họp cổng 0, giữ chỗ tên |

## Task giao subagent (P0-05, P0-07, P0-08)

Session thứ hai giao lại ba task này cho subagent chạy nền. Cả ba dừng giữa chừng vì tài khoản chạm giới hạn phiên (hết giới hạn lúc 2 giờ sáng giờ Việt Nam). Code dở nằm đúng vùng được giao, chưa có báo cáo:

| Task | Được sửa | Báo cáo | Đã có |
| --- | --- | --- | --- |
| P0-05 | `runtimes/ios/**` (trừ `Sources/IrisProtocol`, là code sinh), `examples/ios-swiftui/**` (không sửa file Swift của app mẫu) | `reports/p0-05-openswiftui-linux.md` | `Scripts/fetch-openswiftui.sh` pin OpenSwiftUI 0.23.1 và các gói anh em; `Patches/openswiftui/` còn trống. `runtimes/ios/.irisrun/checkouts` là symlink hỏng trỏ vào scratchpad đã bị dọn: xoá rồi fetch lại |
| P0-07 | `native/objc/**` | `reports/p0-07-objc-linux.md` | `build.sh`, `MiniFoundation.h/.m`, `demo.m`, `README.md`. Subagent báo `build.sh` chạy qua trong 22 s ("all checks passed") nhưng chưa kiểm lại kết quả; `build.sh` có thay đổi chưa commit. Phần thử Swift bật ObjC interop chưa làm |
| P0-08 | `tools/ios-corpus/**` | `reports/p0-08-ios-corpus.md` | Tool, `corpus.json` (65 app) và test đã commit. Chưa fetch corpus, chưa chạy `analyze`, chưa viết báo cáo |

Có báo cáo trong `docs/reports/` nghĩa là task xong: đọc báo cáo, chạy lại lint và test của phần đó. Chưa có báo cáo thì đọc file trong vùng được giao rồi làm tiếp.

## Làm tiếp

1. Ba task giao subagent ở trên: cho chạy tiếp (sau 2 giờ sáng, khi hết giới hạn phiên).
2. P0-06 render core (Rust + rust-skia): phần Rust và C API làm được trước; bước vẽ app mẫu cần P0-05.
3. P0-10 cloud Android: emulator trên KVM của máy dev, stream H.264 qua str0m, input qua data channel; làm luôn player WebRTC còn thiếu của P0-12.
4. `apps/web/**` đang do session UI (ui-plan.md) giữ: đừng build hay sửa ở đó khi session đó chưa báo xong UI-01.

## Môi trường máy dev (WSL2, Ubuntu 20.04, mạng chậm và chập chờn)

- Rust 1.95, pin trong `rust-toolchain.toml`. Node 22 và pnpm 11.28.5 qua corepack (`corepack enable`); corepack của Node 22 chưa chạy được pnpm 12.
- JDK 21: `~/.irisrun/toolchains/jdk-21.0.12.1+1`. Android SDK: `~/.irisrun/android-sdk` (license đã chấp nhận). Host Android: `~/.irisrun/maven`. Robolectric tải `android-all-instrumented` vào `~/.m2` (204 MB cho SDK 36, 228 MB cho SDK 37).
- **Swift 6.4.1 không chạy trên Ubuntu 20.04.** Từ session thứ hai, Swift chạy qua Docker Desktop (đã bật cho WSL). Image `irisrun-swift-dev:6.4.1` dựng từ `swift:6.4.1-noble` thêm cmake, ninja, pkg-config, python3:

  ```sh
  printf '%s\n' 'FROM swift:6.4.1-noble' \
    'RUN apt-get update && apt-get install -y --no-install-recommends cmake ninja-build pkg-config python3' |
    docker build -t irisrun-swift-dev:6.4.1 -
  ```

  Wrapper `swiftenv` chạy một lệnh trong image đó với user hiện tại, ở thư mục hiện tại, chia sẻ `$HOME` và `/tmp`:

  ```sh
  #!/bin/sh
  exec docker run --rm -i --user "$(id -u):$(id -g)" -e HOME="$HOME" \
    -v "$HOME:$HOME" -v /tmp:/tmp -w "$PWD" irisrun-swift-dev:6.4.1 "$@"
  ```

  Ví dụ: `cd runtimes/ios && swiftenv swift test`. Wrapper nằm trong scratchpad của session nên mất khi `/tmp` bị dọn; image thì còn trong Docker. Checkout và build lớn để ở `~/.cache/irisrun/…`, không để trong `/tmp`.
- GitHub API không đăng nhập chỉ có 60 request mỗi giờ: dùng URL tải trực tiếp hoặc `git ls-remote`.
- Đừng dùng `pgrep -f` với chuỗi có trong chính lệnh đang chạy (nó tự kill shell của mình); dùng `pgrep -x irisrun`.
- Sau khi sửa host Android: `cd runtimes/android && ./gradlew publish`, rồi bấm Restart trong UI. Không cần build lại app, vì classpath trong `.irisrun/build/app.launch` trỏ thẳng vào jar trong `~/.irisrun/maven`.

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
