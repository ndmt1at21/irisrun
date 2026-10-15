# P0-10 · Cloud Android: emulator trong container, stream qua WebRTC

15/10/2026 · Thử ở local trên máy dev WSL2 Ubuntu 20.04 (12 nhân, 15 GB RAM, Docker Desktop, KVM). Máy dùng chung với các session khác, trong đó có một bộ test chạy tới 625% CPU, nên load là 18–24 trên 12 nhân lúc đo. Chưa có host ở Singapore, nên phần "điều khiển từ browser ở VN" mới thử qua localhost.

## Kết luận

- **Chạy được đầu-cuối ở local.** Emulator Android 16 chạy headless trong container trên KVM của máy. `irisrun-gateway` lấy H.264 thẳng từ encoder của máy qua scrcpy-server, không giải mã hay mã hoá lại, rồi đưa ra WebRTC bằng str0m. Chromium hiển thị màn hình emulator. Chạm, kéo cuộn, phím (Backspace), chữ ASCII, tiếng Việt và nút Back đi qua data channel, dưới dạng envelope Device Protocol, và đều tác dụng lên app mẫu Compose cài trong emulator.
- **Độ trễ chạm → màn hình đổi:** tốt nhất 47–50 ms khi emulator đang rảnh (đo trong browser, từ `pointerdown` tới frame đầu tiên có vùng nút bấm đổi). Khi máy đang tải 18–24 thì 120–430 ms, có lúc vọt 1,2–2,4 s vì emulator xử lý không kịp. Kéo cuộn chỉ được 3,5–6 fps lúc đó. Phải đo lại trên host riêng mới có số đáng tin.
- **Phía browser không phải nút cổ chai:** giải mã 1,1–2,4 ms mỗi frame 576×1280, jitter buffer 6 ms, không rớt frame.
- **Mỗi emulator cần khoảng 4 GB RAM và 1 nhân khi rảnh.** Boot lạnh lần đầu mất 230 s (khi máy đang tải). Theo đó, một host 32 nhân, 128 GB chứa được khoảng 10–15 emulator đang dùng, khi GPU còn giả lập bằng phần mềm (swiftshader). Con số này chưa đo bằng nhiều emulator cùng lúc, vì máy dev chỉ có 15 GB RAM.
- **KVM chỉ dùng được trong container:** user của máy không thuộc nhóm `kvm`, còn container (`--device /dev/kvm`, chạy root) thì mở được. Cách này khớp với thiết kế cloud: mỗi emulator một container.

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Tải emulator 37.2.12 và system image `android-36;default;x86_64` r02 (AOSP, không có Google Play), kiểm SHA-1 theo repository XML của Google | `cloud/emulator/fetch.sh` |
| Image Ubuntu 24.04 chạy một emulator headless | `cloud/emulator/Dockerfile` |
| Tạo AVD 1080×2400, 420 dpi; chạy emulator trên KVM với `-gpu swiftshader_indirect`; mở adb ra cổng 5556 bằng socat, vì emulator chỉ nghe ở localhost | `cloud/emulator/start.sh` |
| Gateway: chờ máy boot, đẩy scrcpy-server v5.0.1 (Apache-2.0) qua adb, đọc luồng video, ghi message điều khiển | `crates/gateway/src/scrcpy.rs` |
| Phiên WebRTC: H.264 ra track video, envelope Device Protocol hai chiều trên data channel, `DeviceInfo` khi kênh mở, yêu cầu key frame khi có viewer mới hoặc khi nhận PLI/FIR | `crates/gateway/src/session.rs` |
| Ánh xạ input Device Protocol sang message của scrcpy: chạm nhiều ngón, phím (mã W3C → keycode Android), chữ, nút cứng | `crates/gateway/src/input.rs` |
| Lệnh `irisrun-gateway`, signaling qua HTTP (`POST /offer`), trang player thử ở `/` | `crates/gateway/src/main.rs`, `player.html` |

Đường đi của một frame: SurfaceFlinger → virtual display của scrcpy → MediaCodec (`c2.android.avc.encoder`, H.264 phần mềm) → socket qua `adb forward` → gateway gộp SPS/PPS vào trước key frame → broadcast cho mọi phiên → str0m đóng gói RTP (timestamp lấy theo đồng hồ lúc nhận, vì timestamp của máy đếm lại sau mỗi lần reset encoder) → UDP → browser.

Vì sao scrcpy-server: nó cho H.264 liên tục, không giới hạn 3 phút như `screenrecord`, và bơm input qua InputManager. `adb shell input` thì tốn khoảng 200 ms mỗi lệnh vì khởi động JVM. Gói server chỉ 720 KB, ghim theo phiên bản (SHA-256 nằm trong `docs/progress.md`).

## Lỗi gặp và cách sửa

| Lỗi | Nguyên nhân | Sửa |
| --- | --- | --- |
| Emulator báo "Broken AVD system path" | Emulator chỉ nhận SDK root có thư mục `platform-tools` | Image tạo thư mục rỗng `platform-tools` và `platforms`; adb chạy bên ngoài |
| Gõ "Iris Tiếng Việt" ra "ttttttttt" | Mỗi ký tự là một lần đặt clipboard rồi paste; app đọc clipboard khi xử lý paste, lúc đó clipboard đã bị ký tự sau ghi đè | Chữ ASCII đi bằng `INJECT_TEXT` (key event, giữ thứ tự); chữ có dấu thì mỗi lần commit chỉ một lần paste |
| Đo độ trễ bằng "frame mới đầu tiên" ra số vô nghĩa | Encoder của scrcpy lặp lại frame cũ khi màn hình đứng yên, nên luôn có frame mới | Đo theo nội dung: vẽ frame lên canvas nhỏ và lấy lúc vùng quanh nút bấm thực sự đổi |

## Số đo

| Mục | Số đo | Ghi chú |
| --- | --- | --- |
| Tải về | 333 MB emulator + 805 MB system image | Khoảng 1 phút mỗi file trên mạng của máy dev |
| Image `irisrun-emulator:36` | 4,6 GB (lần đầu 7 GB, khi file zip còn nằm trong lớp `COPY`); build 9–16 phút, phần lớn là giải nén và export layer | File zip giờ vào qua `RUN --mount=type=bind` |
| Boot lạnh | 189–230 s tới `sys.boot_completed` | Lúc máy đang tải; ngay sau boot System UI hay báo ANR một lần |
| RAM của một emulator | 3,4–4,0 GB cho cả container; Android dùng 1,3 GB trên 2,5 GB | `hw.ramSize` 2048 MB |
| CPU của một emulator | khoảng 10 nhân lúc boot; 0,9–1 nhân lúc rảnh có viewer | |
| Video | 576×1280 (cạnh dài giới hạn 1280), H.264 phần mềm, bitrate trần 4 Mbps; thực tế 61–105 kbps khi màn hình gần như đứng yên | |
| Phía browser | Giải mã 1,1–2,4 ms/frame, jitter buffer 6–6,4 ms, 0 frame rớt | `getStats()` của Chromium headless |
| Chạm → màn hình đổi | 47–50 ms khi emulator rảnh; 120–430 ms khi máy tải 18–24, có lần 1,2–2,4 s | Đo trong browser, qua localhost |
| Kéo cuộn | 3,5–6 fps | Khi máy tải 18–24 |

## Giới hạn và việc tiếp

- **Chưa có host thật:** cần dựng một host KVM bare-metal ở Singapore, mở UDP, đo độ trễ từ Việt Nam, và thêm TURN (coturn) cho mạng có NAT chặt (P1-24, P1-25). Signaling và gateway hiện chưa có xác thực; adb chỉ mở ở 127.0.0.1 (P1-21, P1-23).
- **Số emulator mỗi host** mới là ước lượng từ một emulator. Cần chạy N emulator cùng lúc trên host riêng. Nên thử GPU thật hoặc `-gpu guest` thay swiftshader, vì vẽ bằng phần mềm ăn CPU nhiều nhất.
- **Chữ:** chưa có chữ đang compose. Nhiều lần commit chữ có dấu liền nhau vẫn có thể giành clipboard của nhau. Cách gốc là một IME của irisrun cài trên máy, nhận chữ trực tiếp; cùng cách đó dùng được cho Android local (P1-09).
- **Video:** viewer mới gây reset encoder để có key frame, nên mọi viewer khác thấy giật một chút. Encoder lặp frame khi màn hình đứng yên, tốn băng thông dù ít. Chưa có âm thanh.
- **Boot:** dùng snapshot để boot nhanh thay vì boot lạnh 189–230 s, và tránh hộp thoại ANR của System UI ngay sau boot (P1-25).
- **Device UI:** Device UI thật đã nối được: `/#/live?gateway=http://127.0.0.1:7780`, gateway chạy với `--allow-origin http://127.0.0.1:7777` (xem báo cáo P0-12). Trang player ở `/` của gateway vẫn giữ để thử nhanh.

## Chạy lại

```sh
cd cloud/emulator && ./fetch.sh && docker build -t irisrun-emulator:36 .
docker run -d --name iris-emu --device /dev/kvm -p 127.0.0.1:15556:5556 irisrun-emulator:36

# scrcpy-server v5.0.1 từ https://github.com/Genymobile/scrcpy/releases/tag/v5.0.1
cargo run -p irisrun-gateway -- --serial 127.0.0.1:15556 \
  --adb ~/.irisrun/android-sdk/platform-tools/adb --server scrcpy-server-v5.0.1
# Mở http://127.0.0.1:7780. Trong console: pressButton(1) là Back, typeText("Tiếng Việt") gửi một lần commit.
```

Để cài app mẫu: `cd examples/android-compose && ./gradlew assembleDebug && adb -s 127.0.0.1:15556 install -r app/build/outputs/apk/debug/app-debug.apk`.
