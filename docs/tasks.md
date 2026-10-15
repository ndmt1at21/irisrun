# Tasks

> Tiến độ chi tiết và cách làm tiếp: [progress.md](progress.md).
>
> Bản xuất từ tab "Tasks" của tài liệu Claude Docs "Iris — Plan & Stack" ngày 14/10/2026. Bản gốc có cột trạng thái dạng dropdown: https://claude.ai/code/artifact/e38b9ae5-5779-42fc-a076-f9fb4416b193

Plan được chia thành 16 task cho Phase 0, 34 task cho Phase 1 (MVP) và 15 epic cho Phase 2–3. Epic sẽ được chia nhỏ ở cuối phase trước, khi có kết quả cổng.

**Cỡ:** S ≤ 3 ngày, M ≤ 2 tuần, L ≤ 1 tháng, XL > 1 tháng (tách nhỏ khi lên sprint). **Track:** PLT nền tảng CLI (Rust), AND Android, IOS iOS, CLD cloud, FE frontend, QA tương thích, BIZ pháp lý và đối tác.

## Phase 0 · Thử nghiệm kỹ thuật (3–4 tuần)

Mục tiêu: có câu trả lời go/no-go và số đo thật cho từng hướng trước khi vào MVP.

| ID | Task | Track | Cỡ | Phụ thuộc | Xong khi | Trạng thái |
| --- | --- | --- | --- | --- | --- | --- |
| P0-01 | Dựng monorepo: Cargo workspace, pnpm workspace, Gradle, SwiftPM, buf; CI GitHub Actions có runner Linux và macOS | PLT | S | — | CI xanh cho Rust, TS, Kotlin, Swift và `buf lint` | Xong ở local, chờ CI |
| P0-02 | Device Protocol v0 bằng Protobuf: frame, input (chạm, phím, chữ), vòng đời app, log, adapter request/response; sinh code cho Rust, TS, Kotlin, Swift | PLT | M | P0-01 | Code sinh tự động trong CI; `buf breaking` đã bật | Xong ở local, chờ CI |
| P0-03 | Thử tự tải toolchain vào `~/.irisrun`: JDK 21, Swift 6.4.1, license Android SDK cho AGP; kiểm tra checksum | PLT | M | P0-01 | Máy sạch Linux và macOS chạy được; có số đo dung lượng và thời gian tải | Xong (Linux) |
| P0-04 | Thử Android runtime: init script Gradle + Robolectric Native Graphics chạy 1 app View và 1 app Compose không sửa code | AND | M | P0-02, P0-03 | Chạm, gõ chữ, back hoạt động; có số đo build lần đầu, khởi động lại, fps | Xong |
| P0-05 | Fork OpenSwiftUI (dùng kèm OpenAttributeGraph), build trên Linux với Swift 6.4.1; app SwiftUI mẫu (đếm số, list, navigation) compile không sửa nhờ `-module-alias` | IOS | M | P0-01 | App mẫu chạy với renderer stdout; `@State`, `@Observable` cập nhật đúng | Xong |
| P0-06 | Thử render core Rust + rust-skia: API C cho layer tree; vẽ hình, chữ (dấu tiếng Việt, CJK), ảnh; Swift gọi qua C ABI; vẽ app mẫu của P0-05 thành frame | IOS | L | P0-05 | Frame xuất ra đúng app mẫu; có số đo fps | Xong |
| P0-07 | Đánh giá Objective-C trên Linux: build libobjc2 + clang, thử Swift toolchain bật ObjC interop | IOS | M | — | Báo cáo go/no-go kèm ước lượng công; demo nhỏ nếu khả thi | Xong |
| P0-08 | Corpus iOS: chọn khoảng 50 app SwiftUI từ open-source-ios-apps; script compile thử với OpenKit; xếp hạng API SwiftUI/UIKit theo mức dùng | QA | M | P0-05 | Có bảng xếp hạng API và tỉ lệ compile ban đầu | Xong, trừ tỉ lệ compile (chờ P0-05) |
| P0-09 | Binary Doctor bản thử (Rust + goblin): quét ELF/Mach-O của khoảng 10 SDK lớn (ML Kit, Firebase, Stripe, Realm, SQLCipher…) | PLT | S | P0-01 | Báo cáo kiến trúc, ABI, phụ thuộc, chiến lược cho từng SDK | Xong |
| P0-10 | Thử cloud Android: emulator trong container trên host KVM ở Singapore; stream H.264 qua str0m (WebRTC); input qua data channel | CLD | M | P0-02 | Điều khiển được từ browser ở VN; có số đo độ trễ và số emulator mỗi host | Xong ở local; còn đo từ VN tới host Singapore |
| P0-11 | Thử cloud iOS: simulator trên Mac thuê (EC2 Mac Singapore hoặc MacStadium); `idb video-stream` → WebRTC; input qua idb | CLD | M | P0-10 | Điều khiển được từ browser; có số đo độ trễ và số simulator mỗi Mac | Hoãn: chờ có Mac thuê (tầng dự phòng, không chặn đường iOS chính) |
| P0-12 | Device UI bản thử: khung máy, vẽ frame lên canvas qua WebSocket, player WebRTC, chuột thành chạm, phím, gõ tiếng Việt qua composition | FE | M | P0-02 | Dùng được cho demo của P0-04, P0-06, P0-10, P0-11 | Xong |
| P0-13 | Tư vấn pháp lý: danh mục API từ tài liệu Apple, mục 2.7 với dịch vụ simulator, image emulator có Google Play, license libhybris/bionic_translation; tra cứu nhãn hiệu Iris (Intel Iris, InterSystems IRIS) | BIZ | M | — | Có ý kiến pháp lý bằng văn bản, bảng rủi ro cập nhật, kết quả tra cứu nhãn hiệu Iris | Chưa làm |
| P0-14 | Khảo sát đối tác máy thật có data center châu Á (đo độ trễ từ VN) và các đời EC2 Mac ở Singapore/Tokyo | BIZ | S | — | Bảng so sánh giá, độ trễ, model máy | Chưa làm |
| P0-15 | Họp cổng 0: go/no-go từng hướng; chốt số mục tiêu cổng 1 (tỉ lệ corpus iOS, độ trễ) | Tất cả | S | P0-04 đến P0-14 | Biên bản quyết định; plan được cập nhật | Chưa làm |
| P0-16 | Giữ chỗ tên: org GitHub irisrun, gói npm và crates irisrun, tên miền irisrun.dev | BIZ | S | — | Đã đăng ký đủ 4 chỗ | Chưa làm |

## Phase 1 · MVP (~3 tháng)

Mục tiêu: một lệnh chạy được app mẫu và corpus ở local, cùng emulator và simulator trên cloud; qua cổng 1 với mục tiêu đã chốt ở cổng 0.

| ID | Task | Track | Cỡ | Phụ thuộc | Xong khi | Trạng thái |
| --- | --- | --- | --- | --- | --- | --- |
| P1-01 | CLI `irisrun start` và `doctor`: nhận diện project Android (Gradle) và iOS (Xcode, SwiftPM), chọn tầng chạy theo kết quả Doctor | PLT | M | P0-15 | Chạy được cả 4 app mẫu trong `examples/` bằng một lệnh | Chưa làm |
| P1-02 | Bộ tải toolchain bản chính thức: ma trận phiên bản, checksum, tải tiếp khi đứt mạng, proxy công ty, dọn cache | PLT | M | P0-03 | Máy sạch lên app đầu tiên không cần thao tác tay | Chưa làm |
| P1-03 | Server local (axum): nhúng Device UI, cầu nối WebSocket với runtime qua stdio | PLT | M | P0-02 | Device UI nhận frame từ cả runtime Android lẫn iOS | Chưa làm |
| P1-04 | Hot reload: theo dõi file → build incremental → khởi động lại runtime | PLT | M | P1-03 | Sửa code là thấy kết quả, không cần chạy lại lệnh; có số đo | Chưa làm |
| P1-05 | Binary Doctor v1 trong luồng `start`, báo cáo hiện trong Device UI | PLT | M | P0-09, P1-03 | App có binary chưa giải được thì CLI đề xuất cloud | Chưa làm |
| P1-06 | Phát hành bằng cargo-dist (shell, Homebrew, npm), tự cập nhật, telemetry opt-in | PLT | S | P1-01 | `npx irisrun` và `brew install` chạy được | Chưa làm |
| P1-07 | Init script chạy ổn trên AGP 8.x/9.x, Gradle 8/9, KTS và Groovy, nhiều module, version catalog | AND | M | P0-04 | Build được nowinandroid và compose-samples | Chưa làm |
| P1-08 | Host vẽ mọi window (activity, dialog, popup, toast), so frame, mã hoá frame | AND | M | P0-04 | Dialog và popup hiện đúng vị trí | Chưa làm |
| P1-09 | Input Android: đa điểm chạm, phím cứng, gõ chữ qua InputConnection cho View và Compose | AND | M | P1-08 | Gõ tiếng Việt vào EditText và TextField đều đúng | Chưa làm |
| P1-10 | ActivityManager giả: back stack, `startActivityForResult`, router intent ngầm (mở URL, chia sẻ, camera) | AND | M | P1-08 | Luồng nhiều màn hình và kết quả trả về hoạt động | Chưa làm |
| P1-11 | Adapter Android: lưu trữ (giữ dữ liệu, AndroidKeyStore giả), camera intent, Play Billing, quyền, vị trí, push, sinh trắc | AND | L | P1-10, P1-29 | Mỗi adapter có app mẫu chạy qua | Chưa làm |
| P1-12 | Pipeline build iOS: đọc `.pbxproj` (target, file, resource, gói SPM), sinh SwiftPM, bỏ `#Preview`, `-module-alias`, Assets.xcassets, `.xcstrings` | IOS | L | P0-05 | App mẫu SwiftUI và UIKit build được, không sửa code | Xong phần pipeline; app mẫu SwiftUI build qua `.xcodeproj`; app mẫu UIKit chờ P1-16, P1-33 |
| P1-13 | Fork OpenSwiftUI: nối backend Linux với render core; làm các API SwiftUI dùng nhiều nhất theo bảng xếp hạng corpus | IOS | XL | P0-06, P0-08 | Đạt mục tiêu cổng 1 về tỉ lệ corpus chạy được | Chưa làm |
| P1-14 | Render core v1: chữ bằng SkParagraph với font dự phòng (Việt, CJK), ảnh, clip, bóng, animation cơ bản, hit-test | IOS | L | P0-06 | Ảnh so với simulator thật đạt ngưỡng chốt ở cổng 0 | Xong phần code; còn so ảnh với simulator (chưa có ảnh tham chiếu, ngưỡng chờ cổng 0) |
| P1-15 | Input iOS: chạm thành gesture (tap, kéo, cuộn); nhập chữ cho TextField và TextEditor qua IME | IOS | M | P1-14 | Form đăng nhập mẫu dùng được với bàn phím tiếng Việt | Chưa làm |
| P1-16 | UIKit cơ bản: UIView, UIViewController, UINavigationController, UILabel, UIButton, UIImageView, UIStackView, UIScrollView, UITableView, Auto Layout (Cassowary), UIViewRepresentable, nạp storyboard/XIB | IOS | XL | P1-14 | App UIKit mẫu chạy được | Chưa làm |
| P1-17 | Framework iOS đợt 1: Combine, StoreKit 2 (đọc `.storekit`), PhotosPicker, UserDefaults/@AppStorage/FileManager, Keychain, CoreLocation, UserNotifications, LocalAuthentication | IOS | L | P1-13, P1-29 | Mỗi framework có app mẫu chạy qua adapter | Chưa làm |
| P1-18 | Sinh stub API ("compile mọi app") và báo API thiếu khi chạy | IOS | L | P0-13, P1-12 | Corpus compile được; Device UI liệt kê API thiếu | Chưa làm |
| P1-19 | Gallery `#Preview`: compile từng `#Preview` thành entry riêng và hiện trong Device UI | IOS | M | P1-12, P1-13 | Thấy đủ preview của app mẫu | Chưa làm |
| P1-20 | CI corpus hằng đêm: compile, chạy, chụp ảnh so với simulator thật trên runner macOS | QA | M | P0-08, P1-12 | Bảng điểm tương thích cập nhật mỗi ngày | Chưa làm |
| P1-21 | Control plane: đăng nhập OIDC, tổ chức, thành viên, API key, project, phiên, lease (Postgres `SKIP LOCKED`), audit log | CLD | L | P0-02 | Đăng nhập Console và tạo được phiên | Chưa làm |
| P1-22 | Build trên cloud: tải source theo diff, builder Linux (Gradle + SDK) có cache; build iOS cho simulator trên Mac của user | CLD | L | P1-21 | Sửa 1 file thì build lại nhanh hơn build đầu (có số đo) | Chưa làm |
| P1-23 | Host agent (Rust): đăng ký bằng token + mTLS, vòng đời thiết bị (adb, emulator gRPC, simctl, idb), kiểm tra sức khoẻ, dọn dẹp sau phiên, metric | CLD | L | P0-10, P0-11 | Phiên sau không thấy dữ liệu của phiên trước | Chưa làm |
| P1-24 | Media gateway (Rust, str0m): H.264 không mã hoá lại, input qua data channel, TURN (coturn), ghi video phiên lên S3 | CLD | M | P0-10 | Độ trễ dưới 150 ms ở Đông Nam Á | Chưa làm |
| P1-25 | Pool emulator Android ở Singapore: host bare-metal KVM, Kubernetes, image không có Play, snapshot để khởi động nhanh | CLD | L | P1-23 | Có emulator sẵn sàng ngay khi dev mở phiên | Chưa làm |
| P1-26 | Mac do user thuê: kết nối AWS (IAM role, cấp EC2 Mac, tính tối thiểu 24 giờ), script cài agent cho Mac bất kỳ, xếp nhiều simulator trên một Mac | CLD | L | P1-23 | User tự thêm Mac trong Console và mở được phiên iOS | Chưa làm |
| P1-27 | Giám sát: Prometheus, Grafana, Loki, OpenTelemetry; dashboard độ trễ và lỗi | CLD | S | P1-21 | Có cảnh báo khi độ trễ vượt ngưỡng | Chưa làm |
| P1-28 | Device UI: khung máy theo profile, xoay, dark mode, ngôn ngữ, cỡ chữ; nút cứng; pinch giả lập; IME (Việt, Trung, Nhật, Hàn) | FE | L | P0-12 | Dùng hằng ngày được cho cả Android và iOS | Đang làm: UI xong với mock, chưa nối backend ([ui-plan.md](ui-plan.md)) |
| P1-29 | Panel: log (virtual list), adapter (camera qua `getUserMedia` hoặc file, payment sheet, vị trí, push, sinh trắc), chụp màn hình, quay video | FE | L | P1-28 | Mỗi adapter có giao diện điều khiển | Đang làm: UI xong với mock, chưa nối backend ([ui-plan.md](ui-plan.md)) |
| P1-30 | Riêng iOS: báo cáo tương thích (API thiếu) và gallery `#Preview` | FE | M | P1-18, P1-19 | Bấm vào API thiếu thấy vị trí trong code | Đang làm: UI xong với mock, chưa nối backend ([ui-plan.md](ui-plan.md)) |
| P1-31 | Console MVP: đăng nhập, tổ chức, thêm Mac host (AWS hoặc cài agent), danh sách phiên, API key | FE | L | P1-21 | Người mới tự onboard được, không cần hỗ trợ | Đang làm: UI xong với mock, chưa nối backend ([ui-plan.md](ui-plan.md)) |
| P1-32 | Player phiên cloud: WebRTC, tự nối lại, hiện độ trễ | FE | M | P1-24 | Mất mạng ngắn vẫn tự nối lại | Đang làm: UI xong với mock, chưa nối backend ([ui-plan.md](ui-plan.md)) |
| P1-33 | App mẫu trong `examples/`: Android View, Compose, iOS SwiftUI, iOS UIKit; mỗi app dùng đủ adapter | QA | M | P0-01 | Chạy trong CI cho mọi PR | Chưa làm |
| P1-34 | Họp cổng 1: đánh giá theo mục tiêu đã chốt ở cổng 0 | Tất cả | S | P1-01 đến P1-33 | Biên bản; quyết định vào Phase 2 | Chưa làm |

## Phase 2–3 · Epic

Epic chưa có cỡ và tiêu chí xong; chia nhỏ thành task ở cuối phase trước, khi có kết quả cổng.

| ID | Epic | Track | Phụ thuộc |
| --- | --- | --- | --- |
| E2-01 | UIKit mở rộng: UICollectionView (compositional layout, diffable data source), hệ thống chữ, các control còn lại | IOS | P1-16 |
| E2-02 | Hoàn thiện stub "compile mọi app" theo danh mục API | IOS | P1-18 |
| E2-03 | Toolchain Objective-C interop (nếu cổng 0 cho go) | IOS | P0-07 |
| E2-04 | Compat registry cho các package phổ biến nhất theo corpus (Alamofire, Kingfisher, SnapKit, Lottie, Realm, Firebase, Stripe…) | IOS | P1-18 |
| E2-05 | SwiftData và CoreData trên SQLite | IOS | P1-17 |
| E2-06 | Chạy XCTest và Swift Testing trên Linux; debug LLDB trong VS Code | IOS | P1-12 |
| E2-07 | Máy thật qua đối tác: tích hợp API, ký app bằng App Store Connect API key của dev, máy riêng | CLD | P0-14, P1-21 |
| E2-08 | Test tự động: endpoint Appium 2, chạy Maestro, ghi thao tác thành flow, tích hợp CI | CLD | P1-23 |
| E2-09 | Native Android: ndk-host, loader bionic, JNI stub | AND | P1-05 |
| E2-10 | Overlay adapter (WebView, bản đồ, video) và camera live (CameraX, AVCapture) | AND, IOS, FE | P1-29 |
| E2-11 | Network inspector (mitmproxy) và giả lập mạng chậm | CLD, FE | P1-24 |
| E3-01 | Farm máy thật riêng cho các model hàng đầu châu Á: hub USB, MDM và device owner, VLAN | CLD | Cổng 2 |
| E3-02 | Đo hiệu năng: CPU, RAM, FPS, pin | CLD, FE | E3-01 |
| E3-03 | Phiên nhiều người cùng xem | CLD, FE | P1-24 |
| E3-04 | Thêm region Tokyo và Mumbai | CLD | P1-25 |
