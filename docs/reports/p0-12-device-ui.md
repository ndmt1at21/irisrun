# P0-12 · Device UI bản thử

14/10/2026 · Thử trên Chromium 148 headless (bản Playwright, không GPU) chạy trong WSL2 Ubuntu 20.04, x86_64. Thiết bị là hai app mẫu Android của P0-04 chạy bằng `irisrun start`.

## Kết luận

- **Dùng được cho demo P0-04.** Khung máy, frame vẽ lên canvas qua WebSocket, chuột thành chạm (bấm và kéo cuộn), phím (Backspace, Enter), gõ chữ thường, gõ tiếng Việt qua composition, nút Back và Restart, overlay fps, panel log đều chạy với cả app View lẫn app Compose.
- Từ lúc nhả chuột tới lúc canvas có frame mới: 32–59 ms, trung vị khoảng 35 ms (8 lần bấm nút trong app Compose, máy đã nóng).
- Khi kéo cuộn, UI vẽ được 16–34 fps, trong khi phía thiết bị gửi tới 50–55 fps. Chỗ nghẽn là giải mã JPEG 1078×2422 trong browser: trung vị 32 ms một frame trên Chromium headless không GPU.
- Thử thật đã lộ ra 2 lỗi chặn và 2 lỗi khó dùng; cả 4 đã sửa (bảng dưới).
- **Chưa có player WebRTC.** Phần này cần nguồn stream thật nên làm cùng P0-10 (cloud Android). Vì vậy task chưa đóng.
- Một session khác đang dựng UI mới theo design "Iris UI" ([ui-plan.md](../ui-plan.md)). Bản thử này chuyển sang route `/#/live` ở đó; phần nối thiết bị (`src/device/*`) được giữ để dùng lại.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Kết nối Device Protocol qua WebSocket, mỗi message một envelope, tự nối lại mỗi giây | `apps/web/src/device/connection.ts` |
| Trạng thái thiết bị (info, trạng thái app, log); frame đi thẳng tới canvas, không qua state của React | `apps/web/src/device/useDevice.ts` |
| Canvas: giải mã frame, không vẽ frame cũ đè frame mới, đếm fps; chuột thành chạm; textarea ẩn giữ focus để bộ gõ của hệ điều hành soạn chữ | `apps/web/src/device/Screen.tsx` |
| Chạm đa điểm (mỗi pointer một ID nhỏ nhất còn trống), phím nào gửi thành phím, phím nào để cho bộ gõ | `apps/web/src/device/input.ts`, `input.test.ts` |
| Trang: khung máy, nút cứng, overlay khi app dừng hoặc crash, tiêu đề trạng thái, panel log | `apps/web/src/App.tsx`, `app.css` |

Đường đi của chữ: bấm vào màn hình thì focus chuyển sang một textarea ẩn. `compositionupdate` gửi `setComposingText`, `compositionend` gửi `commitText`. Chữ gõ thường hoặc dán đi qua `input` thành `commitText`. Bộ gõ kiểu Unikey (gửi Backspace rồi chữ mới) đi qua cả hai đường. Phím Enter, Backspace, Delete, Tab, Escape, mũi tên, Home, End và tổ hợp Ctrl/Cmd gửi thành phím; phím bấm trong lúc đang soạn chữ thuộc về bộ gõ nên không gửi.

## Lỗi tìm thấy khi thử và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Phím không có tác dụng (Backspace không xoá) | `ViewRootImpl` bỏ mọi phím trừ Back khi cửa sổ không có window focus ("Dropping event (no window focus)"), mà `setup()` của Robolectric không trao window focus. Chạm không bị vì sự kiện con trỏ được miễn | Host trao window focus cho activity trên cùng và lấy lại của activity bị che (`runtimes/android/host/.../DeviceSession.kt`) |
| Sau khi bấm Restart, canvas đứng ở frame cũ | UI chỉ vẽ frame có `sequence` lớn hơn frame đã vẽ, mà runtime mới đếm lại từ 1 | Xếp frame theo thứ tự nhận được, không theo `sequence` (`Screen.tsx`) |
| Panel log không theo dòng mới | Danh sách cuộn bình thường, đứng ở đầu | Khung cuộn `flex-direction: column-reverse` nên vị trí cuộn bám đáy cho tới khi người dùng cuộn lên; thứ tự DOM vẫn theo thời gian (`app.css`) |
| Panel log ngập cảnh báo: 445 dòng sau 24 lần bấm | Robolectric ghi "RippleDrawable.STYLE_PATTERNED … not supported for a non-hardware accelerated Canvas" ở mỗi frame có ripple. Lỗi do runtime vẽ bằng canvas phần mềm, không phải do app | Host bỏ đúng cảnh báo này, có ghi chú `ponytail:`; hết hẳn khi chuyển sang renderer phần cứng (P1-08) |

Sửa thêm: tiêu đề hiện "Android 16 · local runtime" thay cho tên enum thô "ANDROID 16 · LOCAL_RUNTIME".

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Nhả chuột → canvas vẽ frame mới | 32–59 ms, trung vị ~35 ms | Bấm nút đếm trong app Compose; đo trong trang bằng `pointerup` và `drawImage` |
| fps trên overlay khi kéo cuộn LazyColumn | 16–34 | Máy đã nóng. Ngay sau khi khởi động chỉ 8–12 fps (JIT phía host chưa nóng) |
| Frame nhận được khi kéo | 17–36 mỗi giây | Chromium gộp `pointermove` theo nhịp khung hình, nên ít hơn client WebSocket gửi đều 16 ms (50–55 fps ở P0-04) |
| Giải mã một frame JPEG 1078×2422 (~100 KB) bằng `createImageBitmap` | trung vị 32–36 ms, p90 44–66 ms | Headless, không GPU. Giải mã kèm `resizeWidth` 350 px còn chậm hơn (50 ms) |
| Bundle | 301 KB JS (92 KB gzip), 2 KB CSS | `vite build` |

## Cách thử

Chromium headless được điều khiển qua Chrome DevTools Protocol bằng một script Node nhỏ (không cần thêm dependency): `Input.dispatchMouseEvent` cho bấm và kéo, `Input.imeSetComposition` và `Input.insertText` để giả lập bộ gõ, `Input.dispatchKeyEvent` cho phím, `Page.captureScreenshot` để xem kết quả. Đã thử:

- App View: chạm vào EditText, soạn "Tiế" (có gạch chân), commit "Tiếng", gõ thêm " Việtt", Backspace còn "Tiếng Việt"; bấm Greet ra "Xin chào, Tiếng Việt!"; mở DetailActivity; Back quay lại; Back ở màn gốc hiện overlay "The app stopped."; Restart ra app mới.
- App Compose: soạn chữ trong OutlinedTextField ("Xin chào, Tiế!" cập nhật ngay trong lúc soạn); gõ phím thường "Iris" và Backspace; kéo cuộn list 20 mục; mở một mục; nút Back của UI gọi BackHandler.

## Giới hạn và việc tiếp

- Player WebRTC: làm cùng P0-10.
- Chưa thử bộ gõ thật của hệ điều hành (Unikey, EVKey, Telex của macOS, pinyin, kana) và chưa thử trên browser có GPU. Có thể tự thử: chạy `irisrun start examples/android-views` trong WSL rồi mở `http://127.0.0.1:7777` bằng Chrome hoặc Edge trên Windows.
- Đa điểm chạm chỉ thử bằng unit test; chuột chỉ cho một ngón. Pinch giả lập thuộc P1-28.
- Nút Home và Apps chưa làm gì với Android local runtime; host ghi log "not supported yet".
- Frame luôn gửi ở độ phân giải gốc, trong khi canvas chỉ hiện khoảng 350 px chiều ngang. P1-28 nên cho UI báo cỡ hiển thị (nhân devicePixelRatio) để thiết bị gửi frame nhỏ hơn. Mã hoá, truyền và giải mã sẽ giảm khoảng 4 lần.
- Log chỉ giữ 500 dòng cuối và không có virtual list. Phía host, `ShadowLog` giữ mọi log trong RAM và bị chép lại ở mỗi frame. Cả hai thuộc P1-29.
- Client vào sau chỉ nhận lại device info, trạng thái và frame mới nhất, không nhận log cũ.

## Chạy lại

```sh
pnpm build                                  # Device UI → apps/web/dist, CLI phục vụ ở http://127.0.0.1:7777
pnpm lint && pnpm typecheck && pnpm test
cargo build -p irisrun && ./target/debug/irisrun start examples/android-compose
```

Khi UI mới của [ui-plan.md](../ui-plan.md) xong bước UI-01, bản thử này nằm ở `http://127.0.0.1:7777/#/live`; `/` là UI mới chạy bằng dữ liệu giả.
