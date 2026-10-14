# P0-04 · Android runtime trên Robolectric

14/10/2026 · Chạy trên WSL2 Ubuntu 20.04, x86_64, 12 nhân, 15 GB RAM. AGP 9.4.1, Gradle 9.8.1, Kotlin 2.4.21, Robolectric 4.17 (Native Graphics), JDK 21.0.12.

## Kết luận

- **Đạt.** Hai app mẫu chạy mà không sửa code: `examples/android-views` (2 activity, EditText) và `examples/android-compose` (OutlinedTextField, LazyColumn, BackHandler). Chạm, gõ chữ, Back và chuyển màn hình đều đúng. Chữ đang compose cũng đúng: "Tiế" → "Tiến" hiện có gạch chân, commit "Tiếng" thì hết gạch chân.
- Một lệnh: `irisrun start <project>`. App được build bằng Gradle của chính project, qua một init script, nên không file nào của project bị sửa; irisrun chỉ ghi vào `.irisrun/`.
- Build khi cache Gradle đã có: 34–86 s cho lần `start` đầu của một project, 8–12 s khi sửa một file. Lần đầu trên máy sạch mất khoảng 20 phút, gần hết là thời gian tải AGP và thư viện qua mạng chậm.
- Khởi động lại (từ lúc chạy JVM tới frame đầu): 8,5–9,3 s khi máy đã nóng. Lần đầu tiên trên máy mất khoảng 43 s, vì Robolectric phải tải `android-all-instrumented` (khoảng 200 MB cho mỗi SDK).
- fps khi kéo cuộn LazyColumn: 50–55. Từ lúc gửi input tới khi có frame mới: Back 23–35 ms, gõ chữ 28–65 ms, bấm nút Compose 73–143 ms, mở activity mới 190–210 ms. Lần chạm đầu tiên sau khi khởi động chậm hơn hẳn (0,6–1,6 s) vì JIT chưa nóng.
- Mã hoá PNG là nút cổ chai: 96–406 ms cho một frame 1078×2422. Đã chuyển sang JPEG chất lượng 90, mất 10–29 ms; chữ nhìn không khác PNG.
- Robolectric 4.17 đã có SDK 37 (Android 17). App đặt `targetSdk = 37` chạy trên SDK 37 mà không phải build lại host.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Init script: thêm host vào `testImplementation`, bật `includeAndroidResources`, ghi `.irisrun/build/<module>.launch` gồm thư mục làm việc, classpath và JVM args của task `testDebugUnitTest` | `runtimes/android/irisrun.gradle` |
| Host: chạy app trong một test JUnit không kết thúc; vòng lặp thiết bị trên main looper chế độ PAUSED; vẽ `decorView`, so với frame trước, mã hoá JPEG | `runtimes/android/host/.../DeviceSession.kt`, `HostMain.kt` |
| Input: chạm và phím qua `ViewRootImpl.dispatchInputEvent`, chữ qua `InputConnection` của view đang focus, nút Back và âm lượng | `runtimes/android/host/.../InputDispatcher.kt` |
| Chạy Gradle, đọc file `.launch`, dựng lệnh JVM | `crates/engine/src/android/project.rs` |
| Cầu nối stdio ↔ WebSocket `/device`; phục vụ Device UI; khởi động lại runtime; gửi lại device info, trạng thái và frame mới nhất cho client vào sau | `crates/engine/src/device.rs` |
| Lệnh `irisrun start <project> [--port 7777]` | `crates/cli/src/main.rs` |
| App mẫu | `examples/android-views`, `examples/android-compose` |

Robolectric chỉ khởi động bên trong một test, nên host là một test JUnit (`DeviceSession`) chạy mãi. CLI chạy `java … dev.irisrun.android.host.HostMain` với classpath của unit test và nói Device Protocol qua stdin, stdout. `HostMain` chuyển `System.out` sang stderr, để chữ app in ra không lẫn vào protocol.

Vòng lặp thiết bị chạy trên một luồng, cũng là main thread của Android:

1. Xử lý input trong hàng đợi.
2. Gọi `idleFor(thời gian thật đã trôi)`, để đồng hồ của Robolectric đi theo giờ thật.
3. Mở activity mà app yêu cầu, bỏ activity đã finish.
4. Gửi log mới.
5. Vẽ `decorView` vào bitmap. Frame giống frame trước thì bỏ.
6. Chờ tới frame sau (30 fps) hoặc tới khi có input. Có input là quay lại bước 1 ngay, nên lúc kéo, fps theo nhịp input.

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Không tìm thấy resource khi project được gọi bằng đường dẫn tương đối | Robolectric đọc đường dẫn resource theo thư mục hiện tại | Canonicalize đường dẫn khi mở project; host chạy ở `workingDir` của task test |
| `InaccessibleObjectException` lúc khởi động | Robolectric cần `--add-opens` trên JDK mới | Lấy `allJvmArgs` của task test |
| SDK 36 không khởi động | `ApplicationSharedMemory` dùng `SharedSecrets` | CLI luôn thêm `--add-opens=java.base/jdk.internal.access=ALL-UNNAMED` |
| "MotionEvent recycled twice" | `ViewRootImpl` tự recycle event sau khi xử lý | Host không recycle nữa |
| Chữ không vào EditText dù EditText đã có focus | `activity.currentFocus` luôn trả null, vì `ShadowActivity` trả về một field của riêng nó chứ không hỏi cây view | Lấy focus bằng `window.decorView.findFocus()` |
| App Compose không build | Compose BOM 2026.09.00 (Compose 1.12.1) đòi `compileSdk` từ 37 | App mẫu lên `compileSdk = 37`, giữ `targetSdk = 36` |
| Mỗi frame mất 100–400 ms | Mã hoá PNG | Chuyển sang JPEG chất lượng 90 |

Bài học từ lỗi focus: đừng hỏi trạng thái qua API mà Robolectric shadow lại. Hỏi thẳng cây view hoặc code thật của framework.

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Build lần đầu trên máy sạch | ~20 phút | Gần hết là tải AGP và thư viện qua mạng chậm (đo ở session đầu) |
| Build ở lần `start` đầu của một project, cache Gradle đã có | Views 34,4 s và 86,2 s; Compose 57,8 s | Lần 86 s chạy cùng lúc với việc kéo một image Docker 1 GB. Lần 57,8 s gồm cả tải platform `android-37` |
| Build lại sau khi sửa 1 file Kotlin | 11,7 s | Gradle daemon và configuration cache đã nóng |
| Build lại sau khi sửa `targetSdk` | 7,9 s | |
| Frame đầu, lần đầu tiên trên máy | 43,6 s (SDK 36), 42,1 s (SDK 37) | Gồm tải `android-all-instrumented` vào `~/.m2`: 204 MB cho SDK 36, 228 MB cho SDK 37 |
| Frame đầu, lần chạy đầu sau khi build | 15,7–37,2 s | Tuỳ cache đĩa và việc khác đang chạy trên máy |
| Khởi động lại (nút Restart), máy đã nóng | Views 8,5–8,6 s; Compose 8,5–9,3 s | 3 lần cho mỗi app |
| fps khi kéo cuộn LazyColumn | 49,5–54,5 | 99–109 frame trong 2 s, input gửi mỗi 16 ms |
| fps tối đa khi không có input | 30 | Nhịp chờ của vòng lặp |
| Input → frame mới, máy đã nóng | Back 23–35 ms; chữ 28–65 ms; bấm nút Compose 73–143 ms; mở activity 190–210 ms; chạm để focus EditText ~320 ms | Đo ở client. Số của chạm đã gồm 50 ms từ lúc nhấn tới lúc nhả |
| Input đầu tiên sau khi khởi động | 0,6–1,6 s | JIT và nạp class lần đầu |
| Vẽ `decorView` bằng canvas phần mềm | 3–150 ms | Màn hình đơn giản 3–7 ms, màn hình chính của app Compose 60–150 ms |
| Mã hoá một frame 1078×2422 | PNG 96–406 ms, 76 KB; JPEG q85 10–25 ms, 74 KB; JPEG q95 11–29 ms, 99 KB; WebP lossless 88 ms, 290–430 KB; WebP lossy q80 ~155 ms, 25 KB | Chọn JPEG q90 |
| RAM của tiến trình host | ~600 MB RSS | App Compose |

## Giới hạn của bản thử

- Chỉ vẽ cửa sổ của activity trên cùng. Dialog, popup và toast chưa hiện (P1-08).
- Frame được vẽ bằng canvas phần mềm, nên thiếu những gì Android chỉ vẽ qua RenderNode khi tăng tốc phần cứng: bóng đổ elevation, `RenderEffect`, hiệu ứng kéo giãn khi cuộn quá đầu hoặc cuối list (kéo quá cuối list không ra frame nào), ripple dạng patterned (Robolectric ghi log "STYLE_PATTERNED … not supported for a non-hardware accelerated Canvas").
- Đa điểm chạm: mỗi sự kiện chỉ đổi một ngón (có ghi chú `ponytail:` trong `InputDispatcher.kt`). Pinch cần tách sự kiện (P1-09).
- Back đi qua `KEYCODE_BACK`. App bật predictive back (`android:enableOnBackInvokedCallback="true"`) chưa được thử.
- Protobuf của host nằm chung classpath với app. App dùng protobuf bản khác có thể xung đột, nên cần shade `com.google.protobuf` (P1-07).
- Robolectric chọn SDK theo `targetSdk` của app, nên mỗi mức `targetSdk` mới lại tải thêm khoảng 200 MB ở lần đầu. Muốn mọi app chạy trên cùng một "máy Android 17" thì ghim SDK bằng `@Config(sdk = …)` trong host. Quyết định này thuộc P1-28 (profile thiết bị).
- Intent ngầm (mở URL, chia sẻ, camera) chỉ được ghi log rồi bỏ qua (P1-10).
- CLI chỉ chạy module tên `app` hoặc module application duy nhất. Chưa thử nhiều module, Groovy DSL hay version catalog phức tạp (P1-07).
- Mỗi lần khởi động lại tốn 8,5 s cho JVM, Robolectric và app. Hot reload phải cắt được khoản này (P1-04).

## Việc cho Phase 1

- P1-04 (hot reload): giữ JVM và sandbox Robolectric sống, chỉ nạp lại class của app; hoặc thử AppCDS, CRaC để giảm 8,5 s khởi động.
- P1-07: shade protobuf; build được nowinandroid và compose-samples.
- P1-08: vẽ mọi window của `WindowManagerGlobal`; thử renderer phần cứng của Robolectric Native Graphics (`robolectric.screenshot.hwrdr.native`) để có bóng đổ và hiệu ứng RenderNode; mã hoá frame ở luồng khác để vòng lặp không phải chờ.
- P1-09: tách sự kiện đa điểm; thử IME với `BasicTextField(TextFieldState)` mới của Compose.
- P1-33: biến client dùng để đo (mục dưới) thành test E2E chạy trong CI.

## Chạy lại

```sh
(cd runtimes/android && ./gradlew publish)   # host → ~/.irisrun/maven; chạy lại sau mỗi lần sửa host
cargo build -p irisrun
pnpm build                                   # Device UI cho http://127.0.0.1:7777
./target/debug/irisrun start examples/android-views
./target/debug/irisrun start examples/android-compose
```

Mở `http://127.0.0.1:7777`. Classpath trong `.irisrun/build/app.launch` trỏ thẳng vào jar trong `~/.irisrun/maven`, nên sau khi publish lại host chỉ cần bấm Restart, không phải build lại app.

Số đo input và fps lấy bằng một client tạm. Client nối vào `ws://127.0.0.1:7777/device`, gửi chạm, kéo, chữ và Back theo kịch bản, ghi lại lúc nhận từng frame và lưu frame ra file. Client này viết bằng TypeScript, import code sinh từ `apps/web/src/gen`, và nằm ngoài repo; P1-33 sẽ đưa nó vào repo thành test E2E.
