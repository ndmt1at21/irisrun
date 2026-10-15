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

Không lưu bản tải về ở scratchpad nữa, vì `/tmp` bị dọn khi tiến trình thoát. Ngày 15/10 bản tải về của 31 artboard và các công cụ so design (`design-shot.mjs`, script interact của từng task) đã mất theo cách đó.
- Mỗi agent tự tải lại các artboard nó cần bằng công cụ Artifact: `read` với `url` của canvas ở đầu file và `paths: ["project/<Tên>.dc.html"]`. Kết quả cho biết đường dẫn file đã lưu.
- Công cụ dùng lại được thì để trong repo, ở `apps/web/scripts/` (như `shot.mjs`). Không để trong scratchpad.
- Cách đọc một artboard: HTML style inline; `{{...}}` lấy dữ liệu từ `renderVals()` ở cuối file; `<sc-for>` là vòng lặp; `<sc-if>` là điều kiện. Prop `theme` chỉ là theme mặc định khi xem; app phải đúng ở cả light lẫn dark.

## Task

Trạng thái: Chưa làm, Đang làm, Xong.

| ID | Việc | Artboard | File sở hữu (trong `apps/web/src`) | Phụ thuộc | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| UI-01 | Nền tảng: cài dependency, token, font, thành phần nền, router và placeholder, ConsoleLayout, gallery `/screens`, trang Foundations, `/live`, smoke test, script `shot` | Foundations, sidebar của MacHosts | `main.tsx`, `router.tsx`, `styles.css`, `lib/**`, `components/**`, `console/ConsoleLayout.tsx`, `gallery/**`, `mocks/scenarios/{types,index}.ts`, `device/DevicePage.tsx`, `device/LiveDevicePage.tsx`, `device/Screen.tsx` (chỉ style), `smoke.test.tsx`, cấu hình `apps/web` | — | Xong |
| UI-02 | Shell Device: header (Local, Cloud, Real device, hot reload, ghi hình, dock, theme), toolbar thiết bị, sân khấu, khung Android và iPhone, nút cứng, panel công cụ (tab, dock phải/dưới, kéo đổi cỡ), footer; panel Logs và trạng thái của nó; màn Kedai Android | Main; phần shell của IosRunning, IosUnsupported, CloudSession, CloudReconnecting; PanelStates (Logs) | `device/shell/**`, `device/panels/LogsPanel.tsx`, `mocks/scenarios/android.tsx`, `mocks/device/logs.ts`, `mocks/screens/AndroidHome.tsx` | UI-01 | Xong |
| UI-03 | Chuẩn bị: tải toolchain, license SDK, các bước build, build lỗi | PrepToolchain, PrepLicense, PrepBuild, PrepBuildFailed | `device/setup/**`, `mocks/scenarios/setup.tsx`, `mocks/device/setup.ts` | UI-01 | Xong |
| UI-04 | iOS: panel Inspector, panel Compatibility, dừng ở API chưa hỗ trợ (dock dưới, thẻ bên), trạng thái của 2 panel; màn Kedai iOS | IosRunning, IosCompat, IosUnsupported, PanelStates (Inspector, Compatibility) | `device/panels/{InspectorPanel,CompatPanel}.tsx`, `device/ios/**`, `mocks/scenarios/ios.tsx`, `mocks/device/{inspector,compat}.ts`, `mocks/screens/Ios{Discover,Product,StorePaused}.tsx` | UI-02 | Xong |
| UI-05 | Panel Network và Adapters (payment sheet trên máy, camera, vị trí, push, sinh trắc, lưu trữ, deep link), trạng thái của 2 panel | AndroidNetwork, Adapters, PanelStates (Network, Adapters) | `device/panels/{NetworkPanel,AdaptersPanel}.tsx`, `mocks/scenarios/tools.tsx`, `mocks/device/{network,adapters}.ts`, `mocks/screens/{AndroidProduct,IosCheckout}.tsx` | UI-02 | Xong |
| UI-06 | Trang Binary Doctor và gallery Previews | BinaryDoctor, IosPreviews | `device/pages/**`, `mocks/device/{binaries,previews}.ts` | UI-01 | Xong |
| UI-07 | Cloud: phiên đang chạy (popover chi tiết), đang nối lại, xem lại phiên | CloudSession, CloudReconnecting, SessionReplay | `mocks/scenarios/cloud.tsx`, `mocks/device/cloud.ts`, `mocks/screens/{IosLookAround,AndroidHomeReconnecting}.tsx`, `console/pages/SessionReplayPage.tsx`, `mocks/console/replay.ts` | UI-02 | Xong |
| UI-08 | Console: Mac hosts, thêm host (AWS, Mac bất kỳ), trạng thái trống và lỗi role AWS | MacHosts, HostWizardAws, HostWizardAnyMac, ConsoleStates | `console/pages/{MacHostsPage,AddHostPage}.tsx`, `console/hosts/**`, `mocks/console/hosts.ts` | UI-01 | Xong |
| UI-09 | Console: đăng nhập, onboarding, Projects, Devices và trạng thái của chúng | ConsoleLogin, Onboarding, Projects, Devices, ConsoleStates | `console/pages/{LoginPage,OnboardingPage,ProjectsPage,DevicesPage}.tsx`, `mocks/console/{projects,devices}.ts` | UI-01 | Xong |
| UI-10 | Console: Sessions, Members & roles, API keys (dialog key mới) và trạng thái | Sessions, Members, ApiKeys, ConsoleStates | `console/pages/{SessionsPage,MembersPage,ApiKeysPage}.tsx`, `mocks/console/{sessions,members,keys}.ts` | UI-01 | Xong |
| UI-11 | Console: Usage & billing (biểu đồ cột chồng bằng div), Data region, Audit log và trạng thái | Usage, DataRegion, AuditLog, ConsoleStates | `console/pages/{UsagePage,DataRegionPage,AuditLogPage}.tsx`, `mocks/console/{usage,region,audit}.ts` | UI-01 | Xong |
| UI-12a | Rà soát phía Device: so mọi kịch bản Device, `/binaries`, `/previews` và trang replay với design (light, dark, 1024, 390); thống nhất kích thước; hoàn thiện responsive cho shell (xem mục Brief UI-12) | Device UI | `device/**`, `mocks/**` (trừ `mocks/console`), `components/{TopBar,StatusFooter,RunStatusBadge,LatencyChip,LevelChip}.tsx`, `gallery/**` | UI-02 … UI-07 | Xong |
| UI-12b | Rà soát phía Console và primitive: so mọi trang Console và trạng thái với design (light, dark, 390); thống nhất kích thước; gom primitive (xem mục Brief UI-12) | Console, Foundations | `console/**`, `mocks/console/**`, `components/ui/**`, `components/{IrisLogo,ThemeToggle}.tsx` | UI-08 … UI-11 | Xong |
| UI-13 | Nối backend (để sau, ngoài đợt này): frame thật vào khung máy, log, trạng thái app, API của CLI cho toolchain, build, license, hot reload; fallback `index.html` ở `crates/engine` | — | — | UI-12 | Chưa làm |

Thứ tự chạy: UI-01 → (UI-02, UI-03, UI-06, UI-08, UI-09 song song) → (UI-04, UI-05, UI-07, UI-10, UI-11 song song) → (UI-12a, UI-12b song song) → cập nhật tài liệu (progress.md, tasks.md).

### Brief UI-12

Áp dụng cho cả hai nửa:
- Kích thước khớp với **kích thước design render ra**, không theo chiều cao khai báo. Artboard thiếu `box-sizing` reset, nên span hay hàng có viền cao hơn chiều cao khai báo. Đây là thứ người duyệt nhìn thấy. `box-content` cùng số của design là cách làm gọn nhất (UI-05, UI-06 đã dùng).
- Quy ước link:
  - trang có thật dùng `<Link to>`;
  - đích chưa có dùng `<Link to="." hash="…">`;
  - hành động trông như link dùng `Button variant="link"`;
  - URL ngoài dùng `<a href target="_blank" rel="noreferrer">`.
- Mỗi màn chụp ở light, dark, cỡ artboard và khổ hẹp. So với ảnh `design-shot`. Chạy lại script interact của task gốc trong `$SCRATCH/UI-xx/` để không làm hỏng hành vi đã có.
- Chỉ sửa file trong phần sở hữu của mình. Cần sửa file của nửa kia thì ghi vào báo cáo.

UI-12a (Device):
- TopBar cao 49px như design (hiện là 48px, mọi trang lệch 1px).
- Dưới 768px shell tự chuyển sang dock dưới. Bỏ vùng chết khi kéo panel trên màn hẹp. Ở 390px không được tràn ngang.
- Footer của shell thành tuỳ chọn (artboard Adapters không có footer). Pane chi tiết của Network cần chiều cao tối thiểu khi dock dưới.
- Xoá placeholder không còn dùng (`gallery/Placeholder.tsx`, nếu không còn chỗ nào gọi).
- Cho phép đổi tab từ ngoài shell (prop `tab` có điều khiển hoặc `onTabChange`). Khi đó link "7 APIs not in the local runtime" ở footer và "See all 7 in Compatibility" mở được tab Compatibility (UI-04 cần).

UI-12b (Console và primitive):
- Hàng bảng theo chiều cao render: Mac hosts 56 → khoảng 68px; Devices 50 → 59px; Sessions, Members, Keys +1px. Ô search theo bề rộng render.
- Primitive cần thêm:
  - `DropdownMenuCheckboxItem` vào `components/ui/dropdown-menu`, thay bản cục bộ trong `AuditLogPage` và `MacHostsPage`;
  - variant `underline` cho `Tabs` (Members đang làm bằng className);
  - `Dialog` và `AlertDialog` có `leading-normal` (portal nằm ngoài ConsoleLayout).
- Tabs không hiện focus ring khi bấm chuột lần đầu.
- Link Replay dùng id của từng phiên (`params={{ sessionId }}`).
- Sidebar `h-screen sticky` của ConsoleLayout: kiểm tra khi cuộn trang dài.

Sau UI-12, điều phối:
- cập nhật `docs/progress.md` và trạng thái P0-12, P1-28 … P1-32 trong `docs/tasks.md` (UI xong với mock, chưa nối backend);
- gom các câu hỏi mở trong Nhật ký thành một danh sách gửi user.

## Làm tiếp

- Đọc bảng Task, làm task "Đang làm" hoặc "Chưa làm" đầu tiên có phụ thuộc đã xong. Báo cáo của mỗi task nằm ở mục Nhật ký bên dưới.
- **Trạng thái 15/10:** đợt UI xong (UI-01 … UI-12). Việc tiếp theo là UI-13, nối backend, khi user đồng ý. Trước đó cần user trả lời mục "Câu hỏi mở cho user" ở cuối Nhật ký.
- Mỗi task giao cho một subagent (context mới). Context của session điều phối chạm khoảng 50% thì cập nhật file này, rồi `/compact` hoặc mở session mới và bảo nó đọc file này.
- Quy tắc 50% áp dụng cho cả subagent. Nếu context của subagent chạm khoảng 50% (500K token) khi chưa xong, nó dừng ở chỗ sạch, ghi `$SCRATCH/UI-xx/handoff.md` (đã làm, còn lại, cách kiểm tra, lưu ý) rồi báo "PARTIAL". Điều phối giao phần còn lại cho một subagent mới, kèm file handoff đó.

## Nhật ký

(Mỗi task xong ghi 2–5 dòng: đã làm gì, lệch design ở đâu, câu hỏi mở.)

**UI-01 (Xong, 15/10).** Đã cài dependency, viết token, 25 primitive trong `components/ui`, 7 thành phần app, router (hash), ConsoleLayout (dưới 768 px gập thành thanh trên có nút Menu), gallery `/screens`, trang `/screens/foundations`, `/live` (mang theo bản sửa của P0-04: frame xếp theo thứ tự đến, nhãn PLATFORMS/KINDS, log dính đáy) và smoke test chạy mọi entry của gallery (55 test xanh). Commit `528565d` do người khác tạo đã gồm một phần file của UI-01.

Ghi chú cho các task sau:
- Line-height mặc định là 1.45 như Main. Artboard Console, Prep*, Login, Onboarding dùng 1.5: thêm `leading-normal` ở root. ConsoleLayout đã có sẵn.
- Header của bảng Console là 12px: thêm `text-xs` vào `TableHead`. Nút 36px (wizard, onboarding) dùng `className="h-9"`.
- Artboard không có `box-sizing` reset, nên span có viền cao hơn 2px so với chiều cao khai báo. Code dùng đúng chiều cao khai báo.
- Token thêm ngoài Foundations: `--sidebar`, `--side`, `--skeleton`, `--series-1`, `--series-2`, `--grid`.
- Công cụ so design, trong `$SCRATCH/tools/`: `design-shot.mjs <file.dc.html> <light|dark> <WxH> <out.png>` render artboard tại chỗ, cùng kích thước với ảnh `shot`. Ngoài ra có `interact-shot.mjs` và `overflow-check.mjs` (đọc comment đầu file). `$SCRATCH` = `/tmp/claude-1000/-home-ndmt1at21-app-engine/99803b62-3289-4980-af21-400d69e5a7b3/scratchpad`.

**UI-03 (Xong).** 4 màn chuẩn bị trong `device/setup/` (SetupLayout dùng chung, ToolchainScreen, LicenseScreen, BuildScreen, BuildFailedScreen). View model nằm ở `mocks/device/setup.ts`: `ToolchainDownload`, `BuildRun`, `BuildFailure`, `CompilerError`. Lệch design:
- dialog license tự nhận focus thay vì nút Decline;
- các link `#…` trong design thành nút có kiểu link, vì `#…` làm hash router nhảy sang trang không tồn tại;
- icon của bước đang chạy quay tròn.

Câu hỏi mở: Copy errors có cần báo "Copied" không; nội dung license do CLI gửi; ⌘R có thành phím tắt thật không; link file:line có mở editor qua CLI không.

**UI-09 (Xong).** Đăng nhập, Onboarding, Projects, Devices cùng các trạng thái `link-expired`, `empty`, `error`. View model: `Project`, `CloudDevice`, `SetupStep`, `DeviceChoice`. Lệch design:
- Country là Select chọn một (design gợi ý chọn nhiều);
- Segmented dùng role radio của Radix;
- link chưa có đích dùng `<Link to="." hash="…">`.

Câu hỏi mở: tên project dẫn tới đâu (chưa có trang project); URL thật của Docs, Terms, Privacy, SSO; danh sách ngôn ngữ.

**Sửa smoke test (điều phối).** Test "marks the current Console page" giờ chỉ tìm trong sidebar, vì breadcrumb "Mac hosts" của UI-08 làm trùng tên link.

**UI-06 (Xong).** Trang `/binaries` và `/previews`, cùng header chung `device/pages/PageLayout.tsx`. View model: `BinaryReport`, `NativeBinary`, `PreviewGallery`, `Preview`. Thumbnail trong gallery là màn mock, sau này thay bằng ảnh mà bộ compile preview gửi về. Đo theo hộp phần tử, hai trang khớp design ở 1440 và 1024, cả light lẫn dark. Riêng TopBar lệch 1px, sẽ xem lại ở UI-12. Màu dark của mini render là tự chọn, chưa có design.

Câu hỏi mở: "Back to device" của trang Previews có nên về màn iOS không.

**UI-08 (Xong).** Mac hosts và wizard Add host, file trong `console/hosts/`: AwsFlow, AnyMacFlow, Wizard. View model: `MacHost`, `AwsRegion`, `InstanceType`, `AwsAccount`, `AgentToken`. Lọc combine AND giữa các menu, OR trong một menu. Bộ đếm host cập nhật Summary. Checkbox 24 giờ chặn Continue. Copy command có báo "Copied".

URL tạm cần xác nhận: `https://irisrun.dev/docs/mac-hosts`, `https://get.irisrun.dev/agent.pkg`.

Câu hỏi mở: ở `aws-role-failed`, bước 1 có nên quay về "current" và Continue có nên bị chặn không.

**Việc cho UI-12 (thống nhất kích thước).** Các task xử lý chuyện artboard thiếu `box-sizing` theo hai kiểu:
- UI-08 dùng chiều cao khai báo, nên hàng bảng cao 56px so với 69px design render ra;
- UI-06 dùng `box-content` để khớp đúng kích thước render.

Chọn một cách. Đề xuất: khớp kích thước design render ra, vì đó là thứ người duyệt nhìn thấy. Kiểm tra thêm hai chỗ:
- sidebar `h-screen sticky` của ConsoleLayout bị cắt khi chụp toàn trang;
- TopBar lệch 1px (48px so với 49px).

**UI-02 (Xong).** Shell Device nằm trong `device/shell/`:
- `DeviceWorkspace`: props platform, project, status, target, hotReload, recording, remote (cloud và máy thật: latency, region, endsIn, popover chi tiết), banner, toolbar, screen, stageAside, hardwareButtons, dock, panelWidth, tabs, tab, panels, panelState, footer;
- `DeviceHeader`, `DeviceToolbar`;
- `frames.tsx` với `AndroidFrame`, `IPhoneFrame`, `HardwareButtons`;
- `tabBar.tsx` với `TabBarSlot`, để panel đưa control của mình lên thanh tab.

Cách dùng mẫu: `mocks/scenarios/android.tsx`.

`LogsPanel` nhận `{ state, logs, counts, packages, variant: full|compact, tagWidth }`. `LogRow` có 3 loại: line, stack, separator. Đã có test cho logic lọc.

Lệch design:
- dòng log cao cố định, không xuống dòng;
- bỏ nút "Panel options";
- dock và theme vẫn hiện ở header cloud.

Câu hỏi mở cho UI-12:
- dưới 768px panel bị ép, có nên tự chuyển sang dock dưới không;
- bấm vào dòng log có mở rộng ra không.

**UI-10 (Xong).** Sessions, Members & roles, API keys, với các trạng thái `loading`, `new-key`, `empty`. View model: `LiveSession`, `EndedSession`, `Member`, `Invite`, `Permission`, `ApiKey`, `NewApiKey`.

Lệch design:
- LatencyChip thu gọn trong thẻ phiên;
- dialog key mới mở ở trạng thái thật: nút Copy, checkbox chưa tick;
- tab gạch chân làm bằng className. UI-12 có thể đưa thành variant của Tabs;
- tab Pending invites tự thiết kế;
- bộ lọc thời gian chưa lọc.

Ghi chú: dialog render dưới `<body>`, nằm ngoài `leading-normal` của ConsoleLayout, nên tự thêm `leading-normal`.

Câu hỏi mở:
- nút Open của phiên đang chạy dẫn về `/?mock=cloud-session`?
- Revoke, End, Remove có cần hỏi xác nhận không?
- link Replay có nên dùng id của từng phiên không? Chỉ cần sửa một dòng.

**UI-11 (Xong).** Usage & billing, Data region, Audit log, với các trạng thái `loading` và `no-matches`. View model: `BillingCycle`, `UsageDay`, `ProjectUsage`, `DataRegion`, `StoredData`, `AuditActor`, `AuditCategory`, `AuditChange`, `AuditEvent`.
- Biểu đồ cột chồng vẽ bằng div. Đổi được 7/30/90 ngày. Tooltip theo con trỏ hoặc phím mũi tên; khi không trỏ vào cột nào thì hiện ngày Oct 13 như design.
- Ô xác nhận tên `acme-mobile` chặn nút Start move.
- Audit log có dòng mở rộng hiện JSON. Bộ lọc Actor và Category dùng menu checkbox.

Việc cho UI-12: đưa checkbox item cục bộ của dropdown (trong `AuditLogPage`, có comment `ponytail:`) vào `components/ui`.

Câu hỏi mở:
- danh sách category thật của audit;
- "Showing N of 412" lấy số từ server;
- Invoices và Change plan dẫn tới đâu;
- con số thật cho "[AMOUNT]".

**UI-07 (Xong).** Hai kịch bản `cloud-session` (popover chi tiết mở sẵn) và `cloud-reconnecting` (banner, overlay "Reconnecting", dòng phân cách trong log), cùng trang replay `/console/sessions/$sessionId`. Trang replay có:
- play/pause theo tốc độ;
- tua bằng nút, kéo timeline hoặc phím mũi tên;
- highlight "now";
- bật/tắt dấu chạm;
- tab Logs, Network, Events có Follow playback.

View model: `SessionReplay`, `ReplayRow`, `ReplayTap`, `ReplayMark`.

Sửa shell (cộng thêm, không đổi API cũ): `RemoteSession.details.defaultOpen`. Khi mở sẵn lúc tải trang thì không cướp focus.

Lệch design:
- log của cloud dùng variant compact, nên ở 500px toolbar xuống 2 dòng;
- dock, theme, settings vẫn có trong header cloud;
- các bộ đếm (next try, offline) là số tĩnh.

Câu hỏi mở: bấm vào một dòng log trong replay có tua video tới đó không; video replay có đổi màn hình theo thời gian không.

**UI-05 (Xong).** Panel Network và panel Adapters, hai màn mock `AndroidProduct` và `IosCheckout` (payment sheet dùng chung state với panel), cùng 5 kịch bản. Có test `NetworkPanel.test.tsx`. View model: `NetworkRequest`, `NetworkCapture`, `PaymentResult`, `PaymentRequest`, `StorageArea`. Đã khớp kích thước render của design: filter 32px, dòng 29px.

Câu hỏi mở:
- panel Adapters luôn có nội dung iOS (Face ID, Keychain), vậy Android có cần bản riêng không;
- khi dock dưới ở 260px, pane chi tiết request không còn chỗ;
- footer của shell nên tuỳ chọn, để artboard Adapters (không có footer) khớp hẳn.

**UI-04 (Xong).** Panel Inspector và panel Compatibility, phần `device/ios/paused.tsx` (gồm PausedDialog trong máy và PausedCards bên cạnh), 3 màn iOS mock, 6 kịch bản. Có test `InspectorPanel.test.tsx`.
- Inspector: tree đi được bằng bàn phím, ô Find lọc tree. Viền chọn và viền hover vẽ trên màn mock, đi theo node đang chọn (`useViewSelection`).
- Compatibility: dòng mở rộng được, lọc text kết hợp với segmented, Copy as Markdown.

View model: `ViewNode`, `UnsupportedApi`, `CompatReport`, `PausedCall`.

Câu hỏi mở:
- Select mode và Bounds có thao tác trên máy không;
- trạng thái Unavailable có nên chuyển target sang Real device không;
- sau khi nối frame thật, viền chọn sẽ do Iris vẽ theo frame của view.

**UI-12b (Xong).** Toàn bộ mục trong brief đã làm.
- Primitive mới: `DropdownMenuCheckboxItem`, Tabs có variant `underline`. Dialog có `leading-normal`. Hết focus ring khi bấm chuột. `Tag` cao 22px.
- `console/FacetFilter.tsx` là chip lọc dùng chung cho Audit log và Mac hosts.
- Hàng bảng theo chiều cao render: hosts 69, Devices 59, Sessions 47, Members 53, Keys 49. Ô search dùng `box-content`.
- Sidebar sticky đúng khi cuộn. Link Replay theo id từng phiên.
- Sau khi sửa, phần lớn trang Console lệch artboard dưới 0,4% pixel.

Còn lệch: caret của Select là chevron, Console vẽ "▾"; profile ở sidebar nằm đáy màn hình. Câu hỏi mới:
- Country trong Devices có chuyển sang chọn nhiều không (FacetFilter đã có sẵn);
- caret Select thống nhất một kiểu cho cả app.

**Ngoài plan (session P0, 15/10).** Session app-engine-b5 đã thêm player WebRTC cho `/#/live`, là phần cuối của P0-12:
- `device/webrtc.ts`, `device/VideoScreen.tsx`;
- `useDevice(url, transport)` có `stream`;
- `?gateway=<url>` chọn WebRTC.

UI-13 dùng lại phần này khi nối khung máy (local qua WebSocket, cloud qua WebRTC).

**UI-12a (Xong).** Toàn bộ mục trong brief đã làm.
- TopBar 49px, StatusFooter 27px.
- Dưới 768px tự chuyển sang dock dưới. Kéo panel không còn vùng chết. 23 route Device không tràn ngang ở 390px.
- Footer tuỳ chọn. Pane chi tiết của Network có chiều cao tối thiểu 160px.
- Shell có `tab` điều khiển được và `onTabChange`. Prop cũ đổi tên thành `defaultTab`. Link "7 APIs…" và "See all 7…" mở tab Compatibility.
- Dòng log của variant full xuống dòng như Main.
- Đã xoá `gallery/Placeholder.tsx`. Công cụ so design `apps/web/scripts/design-shot.mjs` giờ nằm trong repo.

60 test xanh.

**Hoàn tất đợt UI (15/10).** UI-01 tới UI-12 đã xong, còn UI-13 (nối backend) chờ user quyết. Kiểm tra cuối cùng: typecheck, lint, 60 test và build đều xanh.

### Câu hỏi mở cho user

Device UI:
1. Tab Binaries và Previews mở trang riêng (đang làm vậy) hay hiện ngay trong panel?
2. Thanh kéo panel 1px (đang làm) hay rãnh 14px như vài artboard?
3. Header cloud và máy thật giữ nút dock, theme, settings (đang làm) hay rút gọn như artboard?
4. Số đếm của tab Compatibility là pill (đang làm) hay chữ thường?
5. Dòng log `iris` luôn màu link (theo Main) hay chỉ dòng paused?
6. Trang `/binaries` và `/previews` có giữ nút đổi theme không?
7. Dưới 768px: thu cho vừa màn hình (đang làm) hay cho trang cuộn?
8. Khi dock dưới, chi tiết request của Network có đặt cạnh bảng không?
9. Panel Adapters có cần bản Android (vân tay, SharedPreferences) không? Cần design.
10. Nút "Back to device" ở trang Previews có về màn iOS không?
11. Inspector: Select mode và Bounds có thao tác thật trên máy không? Trạng thái Unavailable có chuyển target sang Real device không?
12. Build failed:
    - Copy errors có báo "Copied" không?
    - ⌘R có thành phím tắt thật không?
    - link file:line có mở editor qua CLI không?
    - nội dung license do CLI gửi?
13. Replay: bấm vào một dòng log có tua video tới đó không? Video có đổi màn hình theo thời gian không?

Console:
14. URL thật của Docs, Terms, Privacy, SSO, `irisrun.dev/docs/mac-hosts`, `get.irisrun.dev/agent.pkg`.
15. Tên project dẫn tới đâu? Design chưa có trang project.
16. Danh sách ngôn ngữ cho Select ngôn ngữ.
17. Country ở trang Devices có chuyển sang chọn nhiều (FacetFilter) không?
18. Caret của Select: chevron cho toàn app (đang làm) hay "▾" ở Console?
19. `aws-role-failed`: bước 1 có quay về "current" và Continue có bị chặn không?
20. Sessions: nút Open của phiên đang chạy dẫn tới đâu? Revoke, End, Remove có cần hỏi xác nhận không?
21. Billing và audit:
    - danh sách category thật của audit log;
    - số đếm lấy từ server;
    - Invoices và Change plan dẫn tới đâu;
    - con số thật cho "[AMOUNT]".
