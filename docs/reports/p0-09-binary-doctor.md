# P0-09 · Binary Doctor bản thử

14/10/2026 · Chạy trên WSL2 Ubuntu 20.04, x86_64. Quét 14 SDK thật (10 Android, 4 iOS), tổng cộng 105 binary.

## Kết luận

- **Đọc được đủ những gì plan cần** bằng goblin 0.10: kiến trúc của từng slice, ABI và API level của Android, nền tảng Apple và iOS tối thiểu (phân biệt máy thật với simulator), thư viện phụ thuộc, hàm JNI, có `.swiftinterface` hay không. Doctor mở được cả `.aar`, `.jar`, `.zip` lồng nhau, file fat, thư viện tĩnh `.a`, `.framework` và `.xcframework` (đọc `AvailableLibraries` trong Info.plist).
- **Android: 8 trên 9 SDK có code native ship sẵn bản x86_64**, nên chạy local qua loader bionic→glibc. Chỉ Huawei Scan Kit thiếu x86_64 và buộc lên cloud. Stripe Android không có dòng native nào.
- **2 SDK dùng GPU** (Filament, androidx graphics-core) cần `libEGL`/`libGLES`: local chỉ có JNI stub, muốn vẽ thật thì phải lên cloud.
- **iOS: 3 trên 4 SDK stub được ở local.** Lottie và FirebaseAnalytics có `.swiftinterface`; Realm (lõi ObjC/C++), ML Kit và GoogleAppMeasurement có header. RealmSwift bản Carthage là Swift nhưng không có `.swiftinterface`, nên buộc lên simulator cloud.
- **ML Kit iOS không có slice arm64 simulator** (file fat x86_64 + arm64 máy thật). Trên Mac Apple Silicon, simulator cloud chỉ chạy được ML Kit qua Rosetta.
- Quét toàn bộ 313 MB SDK mất 3,6–4,8 s, RAM tối đa 94 MB (bản release, 1 luồng).

## Đã làm

| Phần | Ở đâu |
| --- | --- |
| Kiểu dữ liệu (`Binary`, `Slice`, `Platform`), quy tắc chọn chiến lược | `crates/doctor/src/lib.rs` |
| Duyệt thư mục và zip lồng nhau, Info.plist của xcframework, ghép thông tin giữa các file | `crates/doctor/src/scan.rs` |
| Đọc ELF, Mach-O, fat, `.a` bằng goblin | `crates/doctor/src/object.rs` |
| Lệnh `irisrun doctor <PATH>...` | `crates/cli/src/main.rs` |

Doctor nhận ra binary theo magic number, không theo đuôi file. File fat có số kiến trúc từ 20 trở lên là file `.class` của Java (hai loại dùng chung magic `CAFEBABE`), nên bị bỏ qua. File dSYM cũng bị bỏ qua. Symlink trong thư mục không được đi theo (`Versions/Current` của framework macOS trỏ tới file đã quét).

Quy tắc chọn, theo đúng thứ tự trong plan. Tầng ghi trong bảng là tầng chạy được với binary đó:

| Nền tảng | Chiến lược | Doctor kiểm gì | Tầng |
| --- | --- | --- | --- |
| Android | (1) build lại từ NDK source | Binary không cho biết có source hay không, nên CLI chỉ in lời nhắc | local |
| | (4) JNI stub | `DT_NEEDED` có thư viện GPU/media/camera/audio: `libEGL`, `libGLESv1_CM/v2/v3`, `libvulkan`, `libnativewindow`, `libmediandk`, `libcamera2ndk`, `libaaudio`, `libOpenSLES`, `libOpenMAXAL`, `libneuralnetworks`, `libamidi`. Xét trước (2) và (3) vì loader trên host không cung cấp được các thư viện này | local (không có hành vi thật), cloud nếu cần hành vi thật |
| | (2) loader bionic→glibc | Cùng thư viện có bản x86_64: cùng tên file trong thư mục ABI anh em (`jni/<abi>`, `lib/<abi>`, prefab `android.<abi>`) | local |
| | (3) dịch CPU hoặc emulator cloud | Không có bản x86_64 | cloud |
| iOS | (1) stub từ `.swiftinterface` + compat registry | Framework (hoặc thư mục thư viện trong xcframework) có `.swiftinterface` | local |
| | (2) stub từ header | Không có section `__swift5_*` và có file `.h` | local |
| | (3) simulator cloud | Các trường hợp còn lại. CLI báo có slice arm64 simulator hay không, lấy từ `AvailableLibraries` hoặc từ chính các slice của file fat | cloud |
| Khác | bỏ qua | ELF dùng glibc (thư viện Linux desktop trong jar); Mach-O cho macOS, Catalyst, tvOS, watchOS, visionOS | — |

Nhận diện ABI của ELF: có note `.note.android.ident` thì lấy API level từ note. Thư viện link `libc.so.6` hoặc dùng interpreter không phải `/system/bin/linker*` thì là glibc. Mọi ELF còn lại được coi là Android, vì doctor chỉ quét project mobile. Với Mach-O, nền tảng lấy từ `LC_BUILD_VERSION`. Binary cũ chỉ có `LC_VERSION_MIN_*` thì slice x86 được tính là simulator.

Ví dụ một mục trong output:

```
huawei-scan/scan-2.15.0.301.aar/jni/arm64-v8a/libscannative.so
  ELF shared library: arm64-v8a Android API 21
  needs libz.so, liblog.so, libm.so, libdl.so, libc.so
  JNI: 5 Java_* functions
  cloud: no x86_64 build: the cloud emulator, or CPU translation (FEX, box64, QEMU-user)
```

## Kết quả theo SDK

Android (cột "Binary" đếm mọi bản ABI):

| SDK | Binary | Kiến trúc | ABI, API tối thiểu | Phụ thuộc đáng chú ý | JNI | Chiến lược → tầng |
| --- | --- | --- | --- | --- | --- | --- |
| ML Kit Barcode Scanning 17.3.0 | 4 (`libbarhopper_v3.so`) | arm64-v8a, armeabi-v7a, x86, x86_64 | bionic, 21 | `libjnigraphics` | 8 `Java_*` | (2) loader → local |
| Firebase Crashlytics NDK 21.0.0 | 16 (4 thư viện; `libcrashlytics-trampoline.so` thực chất là file thực thi PIE) | 4 ABI | bionic, 24 | `libz` | chỉ `JNI_OnLoad` | (2) → local |
| SQLCipher for Android 4.19.1 | 4 | 4 ABI | bionic, 23 | — | chỉ `JNI_OnLoad` | (2) → local |
| Realm Java 10.19.0 | 4 (`librealm-jni.so`) | 4 ABI | bionic, 16 (32-bit) / 21 (64-bit) | `libandroid`, `libz` | `JNI_OnLoad` + 575 | (2) → local |
| Realm Kotlin 3.0.0 (`cinterop-android`) | 4 (`librealmc.so`) | 4 ABI | bionic, 16 / 21 | `libandroid` | `JNI_OnLoad` + 402 | (2) → local |
| Sentry Native NDK 0.17.3 | 16 (2 thư viện × 4 ABI, ở `jni/` và `prefab/`) | 4 ABI | bionic, 21 | — | 17 `Java_*` | (2) → local |
| Filament 1.77.3 | 4 | 4 ABI | bionic, 21 | `libEGL`, `libGLESv3`, `libandroid`, `libjnigraphics` | `JNI_OnLoad` + 862 | (4) JNI stub → local, không vẽ thật |
| androidx graphics-core 1.1.0-beta01 | 4 | 4 ABI | bionic, 24 | `libEGL`, `libGLESv2`, `libandroid` | `JNI_OnLoad` + 2 | (4) JNI stub → local, không vẽ thật |
| Huawei Scan Kit 2.15.0.301 (`scan`, `scanplus`) | 4 | **chỉ** arm64-v8a, armeabi-v7a | bionic, 21 | `libz` | 5 và 9 `Java_*` | (3) → **cloud** |
| Stripe Android 23.23.0 (12 AAR `com.stripe:*`) | 0 | — | — | — | — | không cần doctor |

Mọi thư viện Android ở trên đều cần `libc`, `libm`, `libdl` và `liblog`. Không SDK nào ship `libc++_shared.so`: tất cả đều link tĩnh C++ runtime.

iOS (chỉ tính slice iOS; các slice cho nền tảng Apple khác bị bỏ qua):

| SDK | Binary (iOS / tổng) | Kiến trúc | Nền tảng, iOS tối thiểu | Phụ thuộc đáng chú ý | Chiến lược → tầng |
| --- | --- | --- | --- | --- | --- |
| Realm Swift 20.0.6 (`Carthage.xcframework.zip`): Realm | 2 / 8, dynamic | máy thật arm64; simulator arm64 + x86_64 | iOS 15.0 | UIKit, Foundation, libc++, libz, libcompression | ObjC/C++, có header → (2) local |
| Realm Swift 20.0.6: RealmSwift | 2 / 8, dynamic | như trên | iOS 15.0 | Realm, SwiftUI, Combine, libswift* | Swift, **không có `.swiftinterface`** (chỉ có `.swiftmodule` nhị phân và `.abi.json`) → (3) **cloud**, có slice arm64 simulator |
| Lottie 4.6.1 (`Lottie.xcframework.zip`) | 2 / 8, dynamic | máy thật arm64; simulator arm64 + x86_64 | iOS 13.0 (arm64 simulator: 14.0) | SwiftUI, UIKit, CoreText, QuartzCore, libswift* | Swift + `.swiftinterface` → (1) local |
| ML Kit iOS: MLKitBarcodeScanning 8.0.0, MLKitVision 10.0.0, MLKitCommon 14.0.0 (pod binary) | 3 / 3, framework tĩnh dạng fat | x86_64 (simulator) + arm64 (máy thật), **không có arm64 simulator** | iOS 15.5; MLKitBarcodeScanning là một object đã prelink, không có `LC_BUILD_VERSION` nên doctor báo "unknown Apple platform" | (tĩnh, không có `LC_LOAD_DYLIB`) | ObjC, có header → (2) local |
| Firebase Analytics iOS 12.19.0: FirebaseAnalytics | 2 / 6, xcframework tĩnh | máy thật arm64; simulator arm64 + x86_64 | iOS 15.0 | (tĩnh) | Swift + `.swiftinterface` → (1) local |
| Firebase Analytics iOS 12.19.0: GoogleAppMeasurement, GoogleAppMeasurementIdentitySupport | 4 / 12, xcframework tĩnh | như trên | iOS 15.0 | (tĩnh) | ObjC/C++, có header → (2) local |

## Nhận xét

1. **x86_64 gần như luôn có:** 8/9 SDK Android có native ship x86_64 cho emulator, đúng giả định của plan. Vì vậy loader bionic→glibc (E2-09) là hướng đáng làm nhất. Huawei Scan Kit là ngoại lệ, chỉ ship ARM: cần đo thêm trên các SDK phổ biến ở châu Á (bản đồ, thanh toán, push).
2. **Buộc lên cloud:** 2/13 SDK có code native (Huawei Scan Kit; RealmSwift bản Carthage), cộng thêm 2 SDK GPU nếu cần vẽ thật. Riêng Realm Swift: khi dùng qua SPM, cả `Realm` (ObjC++) lẫn `RealmSwift` đều build từ source (`Package.swift` của v20.0.6), nên app dùng SPM không cần binary này. Đổi lại, phải chờ hướng Objective-C (P0-07).
3. **Việc cho ndk-host:** ngoài `liblog` và `libandroid` mà plan đã nêu, cần thêm `libjnigraphics` (ML Kit, Filament; đây là `AndroidBitmap_*`, chỉ thao tác trên CPU) và `libz` (dùng được bản của host).
4. **JNI stub sinh từ bảng symbol là chưa đủ:** Crashlytics và SQLCipher chỉ export `JNI_OnLoad` rồi đăng ký hàm qua `RegisterNatives`. Muốn sinh stub cho các thư viện này thì phải đọc khai báo `native` trong `classes.jar`.
5. **iOS:** cả 4 SDK đều ship header hoặc `.swiftinterface`, trừ RealmSwift. File `.abi.json` đi kèm RealmSwift mô tả API dưới dạng JSON, có thể dùng làm nguồn sinh stub khi không có `.swiftinterface`. Mọi xcframework đều có slice arm64 simulator. Ngược lại, pod ML Kit dạng fat thì không, nên cloud simulator trên Mac Apple Silicon phải chạy ML Kit qua Rosetta.
6. **Framework tĩnh không có danh sách phụ thuộc:** `LC_LOAD_DYLIB` chỉ có trong binary dynamic. Phụ thuộc của thư viện tĩnh nằm trong `LC_LINKER_OPTION` (autolink) hoặc trong podspec.

## Số đo

Bản release, 1 luồng, cache đĩa đã nóng. Máy dùng chung với các build khác nên thời gian dao động.

| Quét | Dữ liệu | Thời gian | RAM tối đa |
| --- | --- | --- | --- |
| Toàn bộ (`dl/` + `x/`) | 207 MB file nén + 106 MB pod đã giải nén, 105 binary | 3,6–4,8 s | 94 MB |
| `Lottie.xcframework.zip` | 55 MB nén (212 MB giải nén) | 1,35–1,46 s | 92 MB |
| `Carthage.xcframework.zip` (Realm Swift) | 49 MB nén (166 MB giải nén) | 0,82–1,13 s | 80 MB |
| 12 AAR Stripe (đọc cả `classes.jar` lồng bên trong) | 17,7 MB | 0,71 s | 33 MB |
| Một AAR cỡ vừa (Realm Java) | 13,7 MB | 0,54 s | 29 MB |

Tải về khoảng 216 MB (81 MB Android, 135 MB iOS).

## Giới hạn của bản thử

1. Binary không cho biết có NDK source hay không, nên (1) chỉ được in thành lời nhắc.
2. Coi máy chạy là Linux x86_64. Trên host arm64, bản arm64-v8a mới là bản chạy thẳng được.
3. Mỗi container được đọc hết vào RAM. Ổn với SDK; IPA cỡ vài GB thì phải đọc thẳng từ đĩa. Doctor không mở `.tar.gz`: pod của CocoaPods phải giải nén trước, giống như trong `Pods/`.
4. Quy tắc GPU dựa trên tên thư viện trong `DT_NEEDED`, chưa xét symbol nào thực sự được dùng. Chưa đọc `LC_LINKER_OPTION`. Info.plist dạng nhị phân chưa đọc được (mọi xcframework đã gặp đều dùng XML).
5. Code Swift được nhận ra qua section `__swift5_*`. Header được tìm trong framework, hoặc trong thư mục thư viện của xcframework.
6. Bản build của cùng một thư viện cho các ABI khác nhau chỉ được ghép khi chúng nằm trong thư mục ABI anh em. Output in từng file một, nên 4 ABI thành 4 mục. Chưa có output JSON.

## Việc cho P1-05

1. Chạy doctor trong `irisrun start` trên đúng binary mà build sẽ dùng: AAR trong classpath Gradle mà init script ghi ra; `Pods/`, `.build/artifacts` và các xcframework của Xcode. Nếu có binary ở tầng cloud thì CLI đề xuất `--target cloud`.
2. Gộp output theo thư viện và theo SDK (các ABI vào một dòng). Thêm output dạng Protobuf để Device UI hiển thị.
3. Nhận kiến trúc của host. Xác định (1) bằng cách tìm `externalNativeBuild`, `CMakeLists.txt` hoặc `Android.mk` trong project.
4. So `DT_NEEDED` và các symbol chưa định nghĩa với danh sách mà ndk-host và loader cung cấp, rồi báo thư viện hoặc symbol còn thiếu.
5. Đọc khai báo `native` trong `classes.jar` để sinh JNI stub cho thư viện dùng `RegisterNatives`.
6. iOS: đọc `LC_LINKER_OPTION`; dùng `.abi.json` khi thiếu `.swiftinterface`; dùng metadata trong podspec cho object đã prelink mà không có `LC_BUILD_VERSION`.

## Chạy lại

```sh
cargo build --release -p irisrun
mkdir sdk && cd sdk
curl -fLO https://dl.google.com/android/maven2/com/google/mlkit/barcode-scanning/17.3.0/barcode-scanning-17.3.0.aar
curl -fLO https://dl.google.com/android/maven2/com/google/firebase/firebase-crashlytics-ndk/21.0.0/firebase-crashlytics-ndk-21.0.0.aar
curl -fLO https://repo1.maven.org/maven2/net/zetetic/sqlcipher-android/4.19.1/sqlcipher-android-4.19.1.aar
curl -fLO https://repo1.maven.org/maven2/io/realm/realm-android-library/10.19.0/realm-android-library-10.19.0.aar
curl -fLO https://repo1.maven.org/maven2/io/realm/kotlin/cinterop-android/3.0.0/cinterop-android-3.0.0.aar
curl -fLO https://repo1.maven.org/maven2/io/sentry/sentry-native-ndk/0.17.3/sentry-native-ndk-0.17.3.aar
curl -fLO https://repo1.maven.org/maven2/com/google/android/filament/filament-android/1.77.3/filament-android-1.77.3.aar
curl -fLO https://dl.google.com/android/maven2/androidx/graphics/graphics-core/1.1.0-beta01/graphics-core-1.1.0-beta01.aar
curl -fLO https://developer.huawei.com/repo/com/huawei/hms/scan/2.15.0.301/scan-2.15.0.301.aar
curl -fLO https://developer.huawei.com/repo/com/huawei/hms/scanplus/2.15.0.301/scanplus-2.15.0.301.aar
for a in stripe-android payments-core paymentsheet stripe-core stripe-ui-core payments-ui-core payments-model \
         stripe-3ds2-android financial-connections-core financial-connections-lite hcaptcha attestation; do
  curl -fLO https://repo1.maven.org/maven2/com/stripe/$a/23.23.0/$a-23.23.0.aar
done
curl -fLO https://github.com/realm/realm-swift/releases/download/v20.0.6/Carthage.xcframework.zip
curl -fLO https://github.com/airbnb/lottie-ios/releases/download/4.6.1/Lottie.xcframework.zip
# Pod binary: URL lấy từ podspec trên cdn.cocoapods.org (MLKitBarcodeScanning 8.0.0, ...)
for url in https://dl.google.com/dl/cpdc/8464320924888ef3/MLKitBarcodeScanning-8.0.0.tar.gz \
           https://dl.google.com/dl/cpdc/4e1652530984149e/MLKitVision-10.0.0.tar.gz \
           https://dl.google.com/dl/cpdc/00f258dabdb58dfa/MLKitCommon-14.0.0.tar.gz \
           https://dl.google.com/firebase/ios/analytics/f02e7923f9b32c38/FirebaseAnalytics-12.19.0.tar.gz \
           https://dl.google.com/firebase/ios/analytics/aa72db15c887f5f9/GoogleAppMeasurement-12.19.0.tar.gz; do
  name=$(basename "$url" .tar.gz); mkdir "$name"; curl -fL "$url" | tar xz -C "$name"
done
../target/release/irisrun doctor .
```

Danh sách 12 AAR của Stripe là bao đóng các phụ thuộc `com.stripe:*` (scope compile/runtime) trong POM của `stripe-android` 23.23.0. Các phụ thuộc còn lại là androidx, Google Play Services và Kotlin. Unit test: `cargo test -p irisrun-doctor`. Test tự dựng một zip chứa ELF Android cho 2 ABI và một xcframework, gồm Mach-O, Info.plist và `.swiftinterface`.
