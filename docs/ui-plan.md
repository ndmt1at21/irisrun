# Iris UI: plan triển khai (UI trước, nối backend sau)

Cập nhật 14/10/2026. Đây là nguồn sự thật cho việc làm UI: kiến trúc, quy ước, danh sách task và trạng thái. Session mới đọc mục **Làm tiếp** ở cuối trước.

## Mục tiêu và phạm vi

- Làm toàn bộ UI theo design canvas **Iris UI** (https://claude.ai/artifact/DCptKjPNpgKiEk7BaSBdu2): 3 page, 31 artboard. Device UI 16 artboard, Console 14 artboard, Foundations 1 artboard.
- **Chưa nối backend.** Mọi dữ liệu là mock có kiểu rõ ràng. Hành vi thuần UI thì làm thật: theme, tab, dock panel, kéo đổi cỡ panel, lọc log, mở rộng dòng, dialog, menu. Nút gọi backend (Retry build, Accept license, Run on cloud…) để trống `onClick`.
- Phần logic thiết bị đã có (`src/device/connection.ts`, `input.ts`, `useDevice.ts`, `Screen.tsx`) giữ nguyên để nối sau. Bản Device UI cũ của P0-12 chuyển sang route `/#/live`, để test P0-04 vẫn có màn hình thật.

Liên quan tới task trong [tasks.md](tasks.md): P0-12, P1-28, P1-29, P1-30, P1-31, P1-32.

## Stack FE

Theo mục Frontend trong [plan-and-stack.md](plan-and-stack.md), chỉ cài thứ dùng ngay:

| Hạng mục | Chọn | Ghi chú |
| --- | --- | --- |
| Nền tảng | React 19, TypeScript, Vite (đã có) | |
| Style | Tailwind CSS v4 (`@tailwindcss/vite`), token CSS theo kiểu shadcn/ui | Token lấy đúng từ artboard Foundations |
| Component | Viết theo kiểu shadcn/ui (code nằm trong repo) trên `radix-ui`, `class-variance-authority`, `clsx`, `tailwind-merge` | Không chạy CLI shadcn; size và màu khớp design (body 13px) |
| Icon | `lucide-react` | SVG trong design là icon lucide |
| Font | `@fontsource-variable/geist`, `@fontsource-variable/geist-mono` | Đóng gói vào bản build, không gọi Google Fonts (CLI chạy offline) |
| Routing | TanStack Router, khai báo route bằng code, **hash history** | Server của CLI (`crates/engine`, `device_ui`) chưa trả `index.html` cho đường dẫn lạ. Khi có fallback thì đổi sang browser history, chỉ một dòng |
| Test | Vitest + Testing Library + jsdom: một smoke test render mọi route và mọi kịch bản mock | |
| Ảnh chụp | `playwright-core` + Chromium có sẵn trong `~/.cache/ms-playwright` | Script `pnpm shot` để tự so với design |

Chưa cài, thêm khi nối backend: TanStack Query và connect-es (gọi API), Zustand (state chung khi có dữ liệu thật), TanStack Virtual (log trăm nghìn dòng), TanStack Table (sắp xếp, phân trang thật), ECharts (biểu đồ Usage tạm vẽ bằng div).

## Kiến trúc

### Cây thư mục `apps/web/src`

```
main.tsx                    mount RouterProvider
router.tsx                  cây route (hash history), route gốc nhận search `mock`
styles.css                  Tailwind, token light/dark, base, utility `bg-stage-grid`
lib/utils.ts                cn()
lib/theme.ts                useTheme(): light/dark, lưu localStorage `iris-theme`
lib/mock.ts                 useMock(): đọc `?mock=` của route gốc
components/ui/*             primitive kiểu shadcn (button, badge, tabs, …)
components/*                thành phần dùng chung của app (IrisLogo, ThemeToggle, RunStatusBadge, …)
device/                     logic thiết bị có sẵn + UI Device
  DevicePage.tsx            route `/`: chọn kịch bản mock theo `?mock=` rồi render
  LiveDevicePage.tsx        route `/live`: Device UI cũ (P0-12), nối thật
  shell/*                   header, toolbar thiết bị, sân khấu, khung máy, panel công cụ, footer
  panels/*                  LogsPanel, NetworkPanel, InspectorPanel, AdaptersPanel, CompatPanel
  setup/*                   tải toolchain, license, build, build lỗi
  pages/*                   BinaryDoctorPage, PreviewsPage (trang riêng, có "Back to device")
console/
  ConsoleLayout.tsx         sidebar + vùng nội dung
  pages/*                   mỗi trang Console một file
gallery/                    `/screens`: danh sách mọi màn và trạng thái (để review), `/screens/foundations`
mocks/
  scenarios/                kịch bản Device: types.ts, index.ts và một file cho mỗi task
  screens/*                 màn hình app giả (Kedai) vẽ trong khung máy; xoá khi nối frame thật
  <khu>/*.ts                dữ liệu mock có kiểu, mỗi task một nhóm file
```

### Token và Tailwind

- Token là CSS variable trên `:root` (light) và `.dark` (dark), copy đúng giá trị trong artboard. Lấy hợp của mọi token xuất hiện trong các artboard (gồm `--popover`, `--ring`, `--code`, `--overlay`).
- `@theme inline` map token thành màu Tailwind: `bg-background`, `text-muted-foreground`, `border-input`, `bg-selection`, `text-link`, `text-success`, `bg-stage`, `bg-code`… `color-mix(in srgb, var(--x) N%, transparent)` trong design viết thành `bg-x/N`.
- Dark mode bằng class `.dark` trên `<html>` (`@custom-variant dark`). Mặc định theo hệ điều hành; nút đổi theme lưu lựa chọn. `index.html` có script nhỏ đặt class trước khi React chạy để không nháy.
- Chữ: `font-sans` = Geist, `font-mono` = Geist Mono. Body 13px, line-height 1.45. Cỡ chữ lẻ của design (11px, 11.5px, 12.5px, 15px, 17px, 22px) viết bằng giá trị tuỳ ý (`text-[11.5px]`); 12, 14, 16, 18, 20px dùng thang có sẵn.
- Bo góc: 4px `rounded-sm`, 6px `rounded-md`, 8px `rounded-lg`, 10px `rounded-[10px]`, 12px `rounded-xl`, pill `rounded-full`.

### Thành phần nền (UI-01 làm, task khác chỉ dùng)

`components/ui/`: Button (variant default/outline/secondary/ghost/destructive/link; size xs 28px, sm 30px, default 32px, lg 34px, xl 40px, icon-xs/icon-sm/icon), Badge (pill 22px, tone success/warning/destructive/info/primary/muted, có chấm) và Tag (ô viền nhỏ), Tabs (Radix Tabs, kiểu segmented), Segmented (Radix ToggleGroup một lựa chọn), ToggleGroup (nút liền viền, nhiều lựa chọn, như mức log), Input, SearchField (input có icon kính lúp), Textarea, Select, DropdownMenu, Popover, Dialog, AlertDialog, Switch, Checkbox (input gốc), RadioGroup (Radix, kiểu thẻ chọn), Progress, Alert (info/warning/destructive), Table (thẻ `<table>` thật), Skeleton, EmptyState, Card, Avatar (chữ tắt), Kbd, Separator.

`components/`: IrisLogo, ThemeToggle, TopBar (khung header 48px), StatusFooter (thanh trạng thái 26px chữ mono), RunStatusBadge (Running, Paused, Setting up, Building, Waiting for you, Reconnecting, Build failed), LatencyChip (dưới 80 ms xanh, 80–200 vàng, trên 200 đỏ, không có số thì nét đứt), LevelChip (V D I W E và P = paused).

Nếu thiếu một thành phần nền: tạo file cục bộ trong thư mục của task mình, ghi vào báo cáo. UI-12 gom lại sau.

### Mock và chỗ nối backend sau

- **Device:** mỗi kịch bản là `{ id, title, artboard, render }` trong `mocks/scenarios/<file>.tsx`; `index.ts` gộp mọi file. `DevicePage` render kịch bản theo `?mock=`, mặc định `android-running`. Kịch bản ghép shell (UI-02) với panel, dữ liệu và màn hình giả của nó. Khi nối backend, `DevicePage` lấy trạng thái thật từ `useDevice` và API của CLI thay cho kịch bản.
- **Panel:** mọi panel có chữ ký `function XPanel(props: { state?: string })`, tự đọc dữ liệu mock của nó. `state` là trạng thái trống, đang tải hoặc lỗi lấy từ artboard PanelStates. Nhờ vậy shell gọi được mọi panel mà không cần biết dữ liệu bên trong.
- **Console:** mỗi trang đọc `useMock()` để hiện trạng thái trong ConsoleStates (`empty`, `loading`, `error`…). Dữ liệu nằm trong `mocks/console/<trang>.ts`; sau này thay bằng query.
- Kiểu dữ liệu (view model) khai báo cạnh dữ liệu mock. Khi nối, ánh xạ message Protobuf hay API sang các kiểu này.

### Route và artboard

Mọi URL có dạng `/#/<đường dẫn>`. Trang `/#/screens` liệt kê đủ danh sách dưới đây.

| Route | Artboard | Task |
| --- | --- | --- |
| `/` `?mock=android-running` (mặc định) | Main | UI-02 |
| `/` `?mock=logs-empty`, `logs-loading`, `logs-error` | PanelStates (Logs) | UI-02 |
| `/` `?mock=setup-toolchain`, `setup-license`, `setup-build`, `setup-build-failed` | PrepToolchain, PrepLicense, PrepBuild, PrepBuildFailed | UI-03 |
| `/` `?mock=ios-inspector`, `ios-compat`, `ios-paused` | IosRunning, IosCompat, IosUnsupported | UI-04 |
| `/` `?mock=inspector-loading`, `inspector-unavailable`, `compat-all-clear` | PanelStates (Inspector, Compatibility) | UI-04 |
| `/` `?mock=android-network`, `ios-adapters` | AndroidNetwork, Adapters | UI-05 |
| `/` `?mock=network-empty`, `network-no-results`, `adapters-camera-blocked` | PanelStates (Network, Adapters) | UI-05 |
| `/binaries`, `/previews` | BinaryDoctor, IosPreviews | UI-06 |
| `/` `?mock=cloud-session`, `cloud-reconnecting` | CloudSession, CloudReconnecting | UI-07 |
| `/console/sessions/ses_7f2c91` | SessionReplay | UI-07 |
| `/console/hosts` (`?mock=empty`) | MacHosts, ConsoleStates | UI-08 |
| `/console/hosts/new` (`?mock=any-mac`, `aws-role-failed`) | HostWizardAws, HostWizardAnyMac, ConsoleStates | UI-08 |
| `/console/login` (`?mock=link-expired`), `/console/onboarding` | ConsoleLogin, Onboarding, ConsoleStates | UI-09 |
| `/console/projects` (`?mock=empty`), `/console/devices` (`?mock=error`) | Projects, Devices, ConsoleStates | UI-09 |
| `/console/sessions` (`?mock=loading`), `/console/members`, `/console/api-keys` (`?mock=new-key`, `empty`) | Sessions, Members, ApiKeys, ConsoleStates | UI-10 |
| `/console/usage` (`?mock=loading`), `/console/region`, `/console/audit-log` (`?mock=no-matches`) | Usage, DataRegion, AuditLog, ConsoleStates | UI-11 |
| `/screens`, `/screens/foundations` | Foundations | UI-01 |
| `/live` | (Device UI cũ, nối thật) | UI-01 |

Tab Binaries (Android) và Previews (iOS) trong panel công cụ dẫn sang `/binaries` và `/previews`, vì design chỉ có bản toàn trang.

### Kiểm tra

Chạy trong `apps/web` (pnpm qua corepack vì máy chưa `corepack enable`):

```sh
corepack pnpm typecheck && corepack pnpm lint && corepack pnpm test
corepack pnpm exec vite build --outDir "$SCRATCH/dist-check" --emptyOutDir   # không ghi vào dist/
corepack pnpm shot --theme light --size 1440x900 --out "$SCRATCH/shots" "/?mock=android-running" "/console/hosts"
```

- **Không build vào `apps/web/dist`**: CLI phục vụ UI từ thư mục đó, đang dùng để test P0-04.
- `shot` tự chạy Vite, mở từng URL bằng Chromium headless, chụp toàn trang ra PNG và in lỗi console của trang. Biến `CHROME_PATH` chọn Chromium; mặc định lấy bản mới nhất trong `~/.cache/ms-playwright`.
- Mỗi task tự chụp màn của mình ở light, dark và một khổ hẹp (1024 px), xem ảnh và so với source artboard trước khi báo xong.

### Quy tắc khi nhiều task chạy song song

- Chỉ sửa file trong cột "File sở hữu" của task mình. UI-01 tạo sẵn placeholder cho mọi file đó, nên task sau chỉ thay nội dung.
- Không thêm dependency. Không commit. Không sửa file ngoài `apps/web` (trừ khi task ghi rõ).
- Code theo cách viết của repo: TypeScript strict, named export, function component, ít comment. Chữ trên UI giữ đúng tiếng Anh như design. Giữ role và aria của design; widget tương tác dùng Radix.

### Design

Bản tải về của 31 artboard (đọc source HTML, không phải ảnh):
`/tmp/claude-1000/-home-ndmt1at21-app-engine/99803b62-3289-4980-af21-400d69e5a7b3/scratchpad/artifact-files/62d45b01-b2d9-4838-a62e-0444d3815919/project/<Tên>.dc.html`

Nếu thư mục đó đã bị xoá, tải lại bằng công cụ Artifact: `read` với `url` của canvas ở đầu file và `paths: ["project/<Tên>.dc.html"]`. Mỗi artboard là HTML style inline. `{{...}}` lấy dữ liệu từ `renderVals()` ở cuối file, `<sc-for>` là vòng lặp, `<sc-if>` là điều kiện. Prop `theme` chỉ là theme mặc định để xem; app phải đúng ở cả light lẫn dark.

## Task

Trạng thái: Chưa làm, Đang làm, Xong.

| ID | Việc | Artboard | File sở hữu (trong `apps/web/src`) | Phụ thuộc | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| UI-01 | Nền tảng: cài dependency, token, font, thành phần nền, router và placeholder, ConsoleLayout, gallery `/screens`, trang Foundations, `/live`, smoke test, script `shot` | Foundations, sidebar của MacHosts | `main.tsx`, `router.tsx`, `styles.css`, `lib/**`, `components/**`, `console/ConsoleLayout.tsx`, `gallery/**`, `mocks/scenarios/{types,index}.ts`, `device/DevicePage.tsx`, `device/LiveDevicePage.tsx`, `device/Screen.tsx` (chỉ style), `smoke.test.tsx`, cấu hình `apps/web` | — | Đang làm |
| UI-02 | Shell Device: header (Local, Cloud, Real device, hot reload, ghi hình, dock, theme), toolbar thiết bị, sân khấu, khung Android và iPhone, nút cứng, panel công cụ (tab, dock phải/dưới, kéo đổi cỡ), footer; panel Logs và trạng thái của nó; màn Kedai Android | Main; phần shell của IosRunning, IosUnsupported, CloudSession, CloudReconnecting; PanelStates (Logs) | `device/shell/**`, `device/panels/LogsPanel.tsx`, `mocks/scenarios/android.tsx`, `mocks/device/logs.ts`, `mocks/screens/AndroidHome.tsx` | UI-01 | Chưa làm |
| UI-03 | Chuẩn bị: tải toolchain, license SDK, các bước build, build lỗi | PrepToolchain, PrepLicense, PrepBuild, PrepBuildFailed | `device/setup/**`, `mocks/scenarios/setup.tsx`, `mocks/device/setup.ts` | UI-01 | Chưa làm |
| UI-04 | iOS: panel Inspector, panel Compatibility, dừng ở API chưa hỗ trợ (dock dưới, thẻ bên), trạng thái của 2 panel; màn Kedai iOS | IosRunning, IosCompat, IosUnsupported, PanelStates (Inspector, Compatibility) | `device/panels/{InspectorPanel,CompatPanel}.tsx`, `device/ios/**`, `mocks/scenarios/ios.tsx`, `mocks/device/{inspector,compat}.ts`, `mocks/screens/Ios{Discover,Product,StorePaused}.tsx` | UI-02 | Chưa làm |
| UI-05 | Panel Network và Adapters (payment sheet trên máy, camera, vị trí, push, sinh trắc, lưu trữ, deep link), trạng thái của 2 panel | AndroidNetwork, Adapters, PanelStates (Network, Adapters) | `device/panels/{NetworkPanel,AdaptersPanel}.tsx`, `mocks/scenarios/tools.tsx`, `mocks/device/{network,adapters}.ts`, `mocks/screens/{AndroidProduct,IosCheckout}.tsx` | UI-02 | Chưa làm |
| UI-06 | Trang Binary Doctor và gallery Previews | BinaryDoctor, IosPreviews | `device/pages/**`, `mocks/device/{binaries,previews}.ts` | UI-01 | Chưa làm |
| UI-07 | Cloud: phiên đang chạy (popover chi tiết), đang nối lại, xem lại phiên | CloudSession, CloudReconnecting, SessionReplay | `mocks/scenarios/cloud.tsx`, `mocks/device/cloud.ts`, `mocks/screens/{IosLookAround,AndroidHomeReconnecting}.tsx`, `console/pages/SessionReplayPage.tsx`, `mocks/console/replay.ts` | UI-02 | Chưa làm |
| UI-08 | Console: Mac hosts, thêm host (AWS, Mac bất kỳ), trạng thái trống và lỗi role AWS | MacHosts, HostWizardAws, HostWizardAnyMac, ConsoleStates | `console/pages/{MacHostsPage,AddHostPage}.tsx`, `console/hosts/**`, `mocks/console/hosts.ts` | UI-01 | Chưa làm |
| UI-09 | Console: đăng nhập, onboarding, Projects, Devices và trạng thái của chúng | ConsoleLogin, Onboarding, Projects, Devices, ConsoleStates | `console/pages/{LoginPage,OnboardingPage,ProjectsPage,DevicesPage}.tsx`, `mocks/console/{projects,devices}.ts` | UI-01 | Chưa làm |
| UI-10 | Console: Sessions, Members & roles, API keys (dialog key mới) và trạng thái | Sessions, Members, ApiKeys, ConsoleStates | `console/pages/{SessionsPage,MembersPage,ApiKeysPage}.tsx`, `mocks/console/{sessions,members,keys}.ts` | UI-01 | Chưa làm |
| UI-11 | Console: Usage & billing (biểu đồ cột chồng bằng div), Data region, Audit log và trạng thái | Usage, DataRegion, AuditLog, ConsoleStates | `console/pages/{UsagePage,DataRegionPage,AuditLogPage}.tsx`, `mocks/console/{usage,region,audit}.ts` | UI-01 | Chưa làm |
| UI-12 | Rà soát: so mọi màn với design ở light/dark và khổ hẹp, gom component trùng, a11y, cập nhật tài liệu | Tất cả | Mọi file UI | UI-02 … UI-11 | Chưa làm |
| UI-13 | Nối backend (để sau, ngoài đợt này): frame thật vào khung máy, log, trạng thái app, API của CLI cho toolchain, build, license, hot reload; fallback `index.html` ở `crates/engine` | — | — | UI-12 | Chưa làm |

Thứ tự chạy: UI-01 → (UI-02, UI-03, UI-06, UI-08, UI-09 song song) → (UI-04, UI-05, UI-07, UI-10, UI-11 song song) → UI-12.

## Làm tiếp

- Đọc bảng Task, làm task "Đang làm" hoặc "Chưa làm" đầu tiên có phụ thuộc đã xong. Báo cáo của mỗi task nằm ở mục Nhật ký bên dưới.
- Mỗi task giao cho một subagent (context mới). Context của session điều phối chạm khoảng 50% thì cập nhật file này, rồi `/compact` hoặc mở session mới và bảo nó đọc file này.

## Nhật ký

(Mỗi task xong ghi 2–5 dòng: đã làm gì, lệch design ở đâu, câu hỏi mở.)
