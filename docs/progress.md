# Tiến độ triển khai

Cập nhật 14/10/2026, cuối session đầu tiên. File này để session sau làm tiếp; cột trạng thái trong [tasks.md](tasks.md) đã cập nhật theo.

## Tổng quan

| Task | Trạng thái | Ghi chú |
| --- | --- | --- |
| P0-01 Monorepo + CI | Xong ở local | Rust, TS, Kotlin, Swift và `buf lint` đều xanh ở local. CI GitHub chưa chạy: cần push lên `origin` (github.com/ndmt1at21/irisrun) |
| P0-02 Device Protocol v0 | Xong ở local | `proto/irisrun/device/v1alpha1/`. buf lint không nhận hậu tố `v0` nên package là `v1alpha1`. Một lệnh sinh code: `pnpm proto:generate` |
| P0-03 Tải toolchain | Xong (Linux) | Xem [reports/p0-03-toolchain.md](reports/p0-03-toolchain.md). macOS chưa chạy thử |
| P0-04 Android runtime | Đang làm | Xem mục P0-04 bên dưới |
| P0-12 Device UI | Đang làm | Code xong (`apps/web/src/device/`, `App.tsx`), lint/test/build xanh, chưa thử trên browser thật |
| P0-05 OpenSwiftUI trên Linux | Giao subagent, đang chạy lúc lưu | Chỉ được sửa `runtimes/ios/**` (trừ `Sources/IrisProtocol`), `examples/ios-swiftui/**`; báo cáo `reports/p0-05-openswiftui-linux.md` |
| P0-07 Objective-C trên Linux | Giao subagent, đang chạy lúc lưu | `native/objc/**`, `reports/p0-07-objc-linux.md` |
| P0-08 Corpus iOS | Giao subagent, đang chạy lúc lưu | `tools/ios-corpus/**`, `reports/p0-08-ios-corpus.md` |
| P0-09 Binary Doctor | Xong | `crates/doctor`, lệnh `irisrun doctor <path>`; quét 14 SDK, xem [reports/p0-09-binary-doctor.md](reports/p0-09-binary-doctor.md) |
| P0-06 Render core, P0-10 cloud Android, P0-11 cloud iOS | Chưa làm | P0-06 chờ P0-05. P0-10 làm được ở local vì máy có `/dev/kvm`. P0-11 cần Mac |
| P0-13, P0-14, P0-15, P0-16 | Không phải việc code | Pháp lý, đối tác, họp cổng 0, giữ chỗ tên |

**Với các task giao subagent:** nếu đã có file báo cáo trong `docs/reports/` thì task xong; đọc báo cáo, chạy lại lint và test của phần đó. Nếu chưa có báo cáo thì code có thể đang dở; xem file trong vùng được giao rồi làm tiếp.

## P0-04: làm tiếp từ đây

Đã có:

- App mẫu `examples/android-views` (2 activity, EditText) và `examples/android-compose` (TextField, LazyColumn, BackHandler). Cả hai dùng AGP 9.4.1 và Kotlin 2.4.21 built-in.
- Init script `runtimes/android/irisrun.gradle`. Script thêm `dev.irisrun.android:host` vào `testImplementation`, bật `includeAndroidResources` và ghi `.irisrun/build/<module>.launch` gồm 3 dòng: workingDir, classpath và `allJvmArgs` (tách bằng tab) của task `testDebugUnitTest`.
- Host `runtimes/android/host`: `HostMain` chạy JUnit; `DeviceSession` là vòng lặp thiết bị ở 30 fps, chạy trên main looper chế độ PAUSED, vẽ `decorView`, so frame và mã hoá PNG; `InputDispatcher` đưa chạm và phím qua `ViewRootImpl`, đưa chữ qua `InputConnection`. Mỗi lần sửa host phải publish lại: `cd runtimes/android && ./gradlew publish`, ghi vào `~/.irisrun/maven`.
- Rust: `crates/engine/src/android/project.rs` chạy Gradle và đọc file `.launch`; `crates/engine/src/device.rs` là cầu nối stdio ↔ WebSocket `/device`, phục vụ UI từ `apps/web/dist`, khởi động lại runtime và gửi lại frame cho client vào sau. Lệnh `irisrun start <project> [--port 7777]` nằm trong `crates/cli`.

Lỗi đã sửa trên đường đi:

- Đường dẫn project tương đối: giờ canonicalize ngay khi mở project.
- Robolectric đọc đường dẫn tài nguyên theo thư mục hiện tại: host giờ chạy ở `workingDir` của task test.
- Robolectric cần `--add-opens=java.base/java.io=ALL-UNNAMED`: giờ lấy từ `allJvmArgs`.

- Lỗi thứ tư: SDK 36 cần thêm `--add-opens=java.base/jdk.internal.access=ALL-UNNAMED`; CLI giờ luôn thêm cờ này.
- Lỗi thứ năm: `ViewRootImpl` tự recycle MotionEvent, nên host không được recycle lần nữa (lỗi "recycled twice").

**Đã chạy được** `irisrun start examples/android-views`:

- Build bằng init script mất 50–70 s khi cache Gradle đã có. Lần đầu tiên mất khoảng 20 phút vì tải AGP qua mạng chậm.
- Frame đầu tiên đến 18,6 s sau khi JVM khởi động (43,6 s lần đầu, khi Robolectric còn phải tải `android-all`). Frame 1078×2422, vẽ đúng giao diện Material 3.
- Chạm hoạt động (bấm Greet ra "Xin chào, Iris!"). `startActivity` mở được DetailActivity, và Back quay về màn chính.

**Lỗi còn mở:** chữ gửi qua `InputConnection` (setComposingText, commitText) chưa vào EditText, dù EditText đã có focus sau khi chạm. Hướng tìm: kiểm tra `activity.currentFocus` trong `InputDispatcher.text()` có null không (có thể cửa sổ chưa có window focus trong Robolectric); thử `ShadowInputMethodManager`, hoặc gọi `view.onCreateInputConnection` sau khi `imm.showSoftInput`.

Còn lại:

1. Sửa lỗi gõ chữ ở trên, rồi thử lại "Tiếng Việt" (setComposingText rồi commitText).
2. Cách kiểm tra đang dùng: một client tạm kết nối `ws://127.0.0.1:7777/device`, gửi chạm/chữ/Back và lưu frame PNG ra để xem. Session đầu viết nó bằng tsx trong scratchpad (`scratchpad/client/client.mts`), import code sinh ra từ `apps/web/src/gen`. Nên biến nó thành test E2E cho P1-33. Mở UI thật ở `http://127.0.0.1:7777` sau khi chạy `pnpm build`.
3. Làm tương tự với `examples/android-compose`. Rủi ro: IME của Compose, back trên API 36 (predictive back đi qua `OnBackInvokedDispatcher`).
4. Đo: thời gian build lần đầu (CLI in `built in`), khởi động lại (bấm Restart, CLI in `first frame`) và fps (overlay trong UI). Robolectric tự tải `android-all-instrumented` SDK 36 (213 MB) vào `~/.m2` ở lần chạy đầu.
5. Viết `docs/reports/p0-04-android-runtime.md`.
6. Ghi vào rủi ro: protobuf của host nằm chung classpath với app (cần shade `com.google.protobuf` ở P1-07); multi-touch mới xử lý một chạm đổi trạng thái mỗi sự kiện.

## Môi trường máy dev (WSL2, Ubuntu 20.04, mạng chậm và chập chờn)

- Rust 1.95, pin trong `rust-toolchain.toml`. Node 22 và pnpm 11.28.5 qua corepack (`corepack enable`); corepack của Node 22 chưa chạy được pnpm 12.
- JDK 21: `~/.irisrun/toolchains/jdk-21.0.12.1+1`. Android SDK: `~/.irisrun/android-sdk` (license đã chấp nhận). Host Android: `~/.irisrun/maven`.
- **Swift 6.4.1 không chạy trên Ubuntu 20.04.** Session đầu kéo image `swift:6.4.1-noble` từ Docker Hub (API registry, không cần Docker) thành rootfs rồi chạy bằng bubblewrap, không cần root:

  ```sh
  bwrap --bind <rootfs> / --proc /proc --dev /dev --tmpfs /tmp --bind $HOME $HOME \
    --ro-bind /etc/resolv.conf /etc/resolv.conf --setenv HOME $HOME \
    --setenv PATH /usr/bin:/bin --chdir "$(pwd)" swift build
  ```

  Rootfs đó (4 GB) nằm ở `/tmp/claude-1000/-home-ndmt1at21-app-engine/a48b40eb-327b-4620-b1c4-93f10e962e6d/scratchpad/tools/noble`, cùng wrapper `scratchpad/bin/swiftenv`; mất nếu `/tmp` bị dọn.
- GitHub API không đăng nhập chỉ có 60 request mỗi giờ: dùng URL tải trực tiếp hoặc `git ls-remote`.
- Đừng dùng `pgrep -f` với chuỗi có trong chính lệnh đang chạy (nó tự kill shell của mình); dùng `pgrep -x irisrun`.

## Quyết định kỹ thuật trong session đầu

- Code sinh từ proto được commit cho cả 4 ngôn ngữ (dùng remote plugin của BSR). CI fail nếu code sinh ra cũ hơn proto. Java và Kotlin dùng bản lite.
- Swift: các type có prefix `Iris` (`IrisHostMessage`…). Java package là `dev.irisrun.device.v1alpha1`.
- Tên message tránh trùng DOM và Android: `Input`, `TouchInput`, `TouchPoint`, `KeyInput`, `LocationUpdate`.
- Toolchain: URL và SHA-256 được pin trong `manifest.rs`; hash Swift tự tính vì swift.org chỉ có chữ ký PGP.
- Tại máy dev, tiến trình CLI ↔ runtime nói chuyện qua stdio; host chuyển `System.out` sang stderr. Server bảo vệ trước rác trên stdout bằng giới hạn envelope 64 MB.
