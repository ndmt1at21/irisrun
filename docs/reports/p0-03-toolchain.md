# P0-03 · Tự tải toolchain vào `~/.irisrun`

14/10/2026 · Đã thử trên Linux (máy dev và máy sạch). Chưa chạy trên macOS vì không có máy Mac.

## Kết luận

- **JDK 21 và license Android SDK: đạt "không cài gì".** Một lệnh tải, kiểm SHA-256, giải nén. JDK chạy ngay trên Ubuntu 24.04 gốc, không cần gói hệ thống nào.
- **Swift 6.4.1 trên Linux: chưa đạt.** Tải và giải nén được, nhưng toolchain cần khoảng 10 gói hệ thống mà máy sạch không có. Cách xử lý xem mục Việc cho P1-02.
- **Ubuntu 20.04 không có Swift 6.4.1** (swift.org bỏ bản 20.04 từ 6.2). CLI báo rõ lỗi và gợi ý 22.04 hoặc 24.04, đúng như plan.
- Lần đầu tải khoảng **1,33 GB** (JDK 207 MB và Swift 1125 MB), chiếm **3,9 GB** trên đĩa, khớp ước lượng 1–2 GB của plan. SDK package do AGP tự tải chiếm thêm khoảng 315 MB. Chưa tính Gradle, AGP và Robolectric (số đo ở báo cáo P0-04).

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Lệnh `irisrun toolchain install [jdk\|swift\|android-sdk]` và `irisrun toolchain list` | `crates/cli/src/main.rs` |
| Tải, kiểm hash, giải nén, đặt vào chỗ | `crates/engine/src/toolchain.rs` |
| Ma trận phiên bản: URL và SHA-256 được pin | `crates/engine/src/toolchain/manifest.rs` |
| Nhận diện OS, CPU, distro (`/etc/os-release`) | `crates/engine/src/toolchain/host.rs` |
| License Android SDK | `crates/engine/src/android/license.rs` |

Cách cài:

1. Tải về file tạm nằm cạnh thư mục đích, tính SHA-256 trong lúc tải. Hash sai thì dừng và xoá file.
2. Giải nén vào thư mục tạm rồi `rename` sang chỗ thật. Cài bị ngắt thì không để lại toolchain dở dang. Hai tiến trình cùng cài thì tiến trình xong sau dùng luôn bản đã có.
3. Đứt mạng hoặc server lỗi 5xx: thử lại tối đa 5 lần (chờ 2, 4, 8, 16 s) và tải tiếp từ byte đang dừng bằng HTTP `Range`.
4. Thư mục: `~/.irisrun/toolchains/jdk-21.0.12.1+1`, `~/.irisrun/toolchains/swift-6.4.1`, `~/.irisrun/android-sdk` (làm `ANDROID_HOME`). Đổi thư mục gốc bằng biến `IRISRUN_HOME`.

Ma trận phiên bản:

| Toolchain | Phiên bản | Nền tảng | Nguồn hash |
| --- | --- | --- | --- |
| JDK (Eclipse Temurin) | 21.0.12.1+1 | Linux x86_64/aarch64, macOS x86_64/arm64 | API Adoptium |
| Swift | 6.4.1 | Ubuntu 22.04 và 24.04 (x86_64, aarch64), macOS (pkg universal) | Tự tính bằng `curl … \| sha256sum`; swift.org chỉ phát hành chữ ký PGP |

**License Android SDK:** CLI tải `repository2-3.xml` của Google (421 KB, dưới 1 s), hiện toàn văn license và hỏi y/N; trong CI dùng cờ `--accept-android-sdk-license`. Khi user đồng ý, CLI ghi hash của license vào `android-sdk/licenses/android-sdk-license`, đúng định dạng file mà `sdkmanager --licenses` ghi.

Hash là SHA-1 của văn bản *sau khi* sdklib chuẩn hoá khoảng trắng: `TrimStringAdapter` bỏ dấu cách theo sau khoảng trắng, nối các dòng trong cùng đoạn, gộp dấu cách và trim. Lần đầu mình băm văn bản thô và AGP từ chối ("some licences have not been accepted"). Sau khi đọc bytecode của sdklib và làm đúng quy tắc trên, hash ra `24333f8a63b6825ea9c5514f83c2829b004d1fee`, trùng với hash quen thuộc trong các script CI. Văn bản license hiện tại đề ngày 16/01/2019.

**Đã kiểm chứng với AGP 9.4.1:** khi `ANDROID_HOME=~/.irisrun/android-sdk` chỉ có file license, AGP tự tải `platforms;android-36` (146 MB trên đĩa), `build-tools;36.0.0` (147 MB) và platform-tools (22 MB), và `assembleDebug` của `examples/android-views` chạy xong.

## Số đo

Máy dev: WSL2, Ubuntu 20.04, mạng ở Việt Nam. Tốc độ tải dao động mạnh theo CDN, từ 0,2 đến 8 MB/s.

| | Tải về | Trên đĩa | Thời gian |
| --- | --- | --- | --- |
| JDK 21.0.12.1+1 (linux x64) | 207 MB | 346 MB | 207 s ở máy dev; 965 s ở lần chạy trên máy sạch (CDN GitHub chỉ đạt khoảng 0,2 MB/s) |
| Swift 6.4.1 (ubuntu24.04 x86_64) | 1125 MB | 3,5 GB | 670 s (khoảng 1,7 MB/s); 140 s khi CDN nhanh (khoảng 8 MB/s, lúc tính hash) |
| License Android SDK | 421 KB | dưới 1 KB | dưới 1 s |

Thời gian trong bảng gồm cả tải và giải nén; chưa đo riêng phần giải nén.

## Thử trên máy sạch

"Máy sạch" ở đây là rootfs `ubuntu:24.04` gốc, không cài thêm gói nào, chạy bằng bubblewrap không cần root:

```sh
bwrap --bind <rootfs> / --proc /proc --dev /dev --tmpfs /tmp \
  --ro-bind <repo> /repo --bind <home-trống> /root --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --setenv HOME /root /repo/target/debug/irisrun toolchain install --accept-android-sdk-license
```

Những gì tìm ra:

1. **Không có chứng chỉ CA.** Lỗi TLS "No CA certificates were loaded from the system". Đã sửa: CLI mang theo bộ root CA của Mozilla (`webpki-root-certs`) và gộp với kho của hệ thống. Kho hệ thống vẫn được dùng, nên proxy công ty có CA riêng vẫn chạy.
2. **JDK chạy ngay:** `openjdk version "21.0.12.1" 2026-08-18 LTS`.
3. **Mạng đứt khi đang tải Swift** ("peer closed connection without sending TLS close_notify"). Lỗi này dẫn tới việc thêm thử lại và tải tiếp; lần tải sau thành công.
4. **Swift không chạy được trên máy sạch:**

   ```
   swift: error while loading shared libraries: libncurses.so.6: cannot open shared object file
   ```

   Theo `ldd`, thư viện còn thiếu là libxml2.so.2, libncurses.so.6, libsqlite3.so.0, libcurl.so.4, libedit.so.2, libpanel.so.6, libform.so.6 và libpython3.12.so.1.0 (cho LLDB). Để compile còn cần header và crt của libc (`libc6-dev`), `libgcc-13-dev` và `libstdc++-13-dev`. Ubuntu Desktop có sẵn phần lớn thư viện runtime, nhưng thiếu các gói `-dev`.

## Việc cho P1-02

1. **Gói hệ thống cho Swift trên Linux.** Có hai hướng:
   - (a) CLI kiểm tra và in đúng lệnh `sudo apt-get install …` theo distro.
   - (b) Tải kèm các `.so` và một sysroot có header (qua `LD_LIBRARY_PATH` hoặc rpath), khỏi phải dùng sudo.

   Đề xuất làm (a) trước, đo dung lượng của (b), rồi chốt ở cổng 0.
2. **macOS:** chưa chạy thử. Code giải nén pkg bằng `pkgutil --expand-full`, không cài gì vào hệ thống. Compile cho host macOS cần macOS SDK từ Command Line Tools. Đây là phần mềm Apple chạy trên máy Apple nên hợp lệ, nhưng vẫn là một bước cài: cần kiểm chứng trên máy Mac thật và quyết định ở cổng 0.
3. Thêm distro Debian 12/13, Fedora 41, Amazon Linux 2023, UBI 9/10 (mỗi distro cần tính hash cho 2 kiến trúc).
4. Dọn cache, khoá khi hai lệnh cùng cài, tải ma trận phiên bản từ xa. Proxy công ty đã chạy được vì reqwest đọc `HTTPS_PROXY` và kho CA của hệ thống.
5. Muốn nâng phiên bản Swift nhanh thì có thể chuyển sang xác minh chữ ký PGP của swift.org thay vì tự tính hash.

## Chạy lại

```sh
cargo build -p irisrun
./target/debug/irisrun toolchain install jdk android-sdk --accept-android-sdk-license
./target/debug/irisrun toolchain install swift   # Ubuntu 22.04/24.04 hoặc macOS
./target/debug/irisrun toolchain list
```
