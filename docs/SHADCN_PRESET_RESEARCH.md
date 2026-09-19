# Nghiên cứu preset shadcn `bbVKHJo` cho DockMagic

> Historical research/proposal. The approved Maia implementation contract is
> [Design.md](../Design.md) and [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Earlier
> SF Pro, blue-action, glass and conflicting geometry recommendations are superseded.


Ngày kiểm tra: **17/09/2026**. Trạng thái: **nghiên cứu và đề xuất**, chưa phê duyệt thay đổi thiết kế, chưa triển khai component Swift mới.

## 1. Kết luận và phương án đề xuất

**Có thể xây bộ component native do DockMagic sở hữu source, dùng thống nhất cho toàn dự án, lấy preset này làm mẫu về anatomy, variant và cách ghép component.** Cách phù hợp nhất là mở rộng `DesignSystem` hiện có, giữ SwiftUI/AppKit làm nền hành vi, rồi chuyển từng tính năng sang bộ dùng chung.

Đây là một lần xây dựng design system và di chuyển các nơi sử dụng, không chỉ thay màu hoặc thêm một package. Lệnh `init --template next` tạo ứng dụng React/Next.js; nó không tạo SwiftUI component. Preset quy định một tổ hợp thiết kế, không phải một danh sách tính năng cần đưa hết vào DockMagic.

Đề xuất lựa chọn **Maia được điều chỉnh cho DockMagic**:

- Tiếp thu phân cấp nội dung, cách chia Card/Field/Item, hệ variant, spacing có chủ đích và các trạng thái tương tác của Maia.
- Giữ chính sách đã chốt: Settings SF Pro; Dashboard/Dock SF Pro Rounded; SF Symbols; warm neutrals và một action blue.
- Component thường dùng phải có API chung; tính năng chỉ truyền nội dung, binding, action và presentation model.
- Control native giữ semantics và hành vi bàn phím. Chỉ bổ sung wrapper/style chung khi giải quyết nhu cầu thực tế.
- Tách component thuần giao diện khỏi module có ý nghĩa nghiệp vụ như quota, token history, giá thị trường, calendar và playback.

Nếu mục tiêu sau nghiên cứu là **giống nguyên bản preset cả font, màu và dáng capsule**, cần ghi nhận đó là quyết định thiết kế mới và đồng bộ `RULES.md`, `Design.md`, các contract và token khi triển khai. Nghiên cứu này không tự thay đổi những quyết định đang có hiệu lực.

## 2. Preset chính xác

Giải mã bằng **CLI chính thức `shadcn 4.21.0`**, đối chiếu với trang Create đang render. Không tự suy đoán ý nghĩa chuỗi preset. [Trang preset](https://ui.shadcn.com/create?preset=bbVKHJo), [CLI chính thức](https://ui.shadcn.com/docs/cli).

| Thuộc tính | Giá trị xác minh | Ý nghĩa |
| --- | --- | --- |
| Mã / version | `bbVKHJo` / `b` | Snapshot cấu hình; không phải version của package |
| Style | `maia` | Phong cách mềm, bo góc và khoảng cách rộng |
| Base color | `neutral` | Bảng neutral nền |
| Theme | `neutral` | Primary mặc định là đen/trắng tùy appearance |
| Chart color | `neutral` | Năm bậc xám cho token chart |
| Font | `geist` | Font nội dung web |
| Heading | `inherit` | Kế thừa Geist, không chọn font heading riêng |
| Icon library | `hugeicons` | Không phải Lucide |
| Radius | `medium` | Base radius `0.625rem`; từng component dùng bậc riêng |
| Menu color | `default` | UI hiển thị “Default / Solid” |
| Menu accent | `subtle` | Selection/hover nhẹ |
| Template trong lệnh | `next` | Scaffold Next.js |
| Primitive trong mẫu nghiên cứu | `base` → `base-maia` | Chọn rõ `--base base`, khớp preview chính thức |

**Mã preset không chứa lựa chọn Base UI/Radix/React Aria hoặc template.** Kết quả `preset decode` không có các trường đó. Lệnh người dùng chưa chỉ định `--base`; báo cáo này dùng nhánh Base UI được trang preview thể hiện, không khẳng định mã preset tự khóa primitive library.

Maia là một style thay đổi cả component, không chỉ theme màu. Mô tả chính thức cũng phân biệt Maia với Nova/Mira thiên về mật độ cao. [Thông báo shadcn Create](https://ui.shadcn.com/docs/changelog/2025-12-shadcn-create).

## 3. Token và hình học thực tế

### 3.1 Palette

Bảng dưới được đọc từ computed CSS của preview chính thức trong Light/Dark. Đây là token web để tham chiếu, **không phải token Swift mới**. `oklch(...)` không được chép nguyên thành RGB hoặc dùng trong feature view.

| Token | Light | Dark | Vai trò DockMagic đề xuất |
| --- | --- | --- | --- |
| background | `oklch(1 0 0)` | `oklch(0.145 0 0)` | `opaqueSurface` |
| foreground | `oklch(0.145 0 0)` | `oklch(0.985 0 0)` | `textPrimary` |
| card, popover | `oklch(1 0 0)` | `oklch(0.205 0 0)` | `opaqueSurfaceRaised` |
| card/popover foreground | `oklch(0.145 0 0)` | `oklch(0.985 0 0)` | `textPrimary` |
| primary | `oklch(0.205 0 0)` | `oklch(0.922 0 0)` | Ý nghĩa action; giữ màu `action` của DockMagic |
| primary foreground | `oklch(0.985 0 0)` | `oklch(0.205 0 0)` | `onAction`, kiểm tra tương phản trên fill native |
| secondary, muted, accent | `oklch(0.97 0 0)` | `oklch(0.269 0 0)` | Neutral surface/hover theo ngữ cảnh |
| secondary/accent foreground | `oklch(0.205 0 0)` | `oklch(0.985 0 0)` | `textPrimary` |
| muted foreground | `oklch(0.556 0 0)` | `oklch(0.708 0 0)` | `textSecondary` |
| destructive | `oklch(0.577 0.245 27.325)` | `oklch(0.704 0.191 22.216)` | `danger` / `dangerForeground` theo fill hay text |
| border | `oklch(0.922 0 0)` | `oklch(1 0 0 / 10%)` | `outline`, tăng thành `outlineStrong` khi cần |
| input | `oklch(0.922 0 0)` | `oklch(1 0 0 / 15%)` | Viền/nền input phải tách semantic role native |
| ring | `oklch(0.708 0 0)` | `oklch(0.556 0 0)` | `focus` |
| sidebar | `oklch(0.985 0 0)` | `oklch(0.205 0 0)` | Chrome native, opaque fallback |
| sidebar foreground | `oklch(0.145 0 0)` | `oklch(0.985 0 0)` | `textPrimary` |
| sidebar primary | `oklch(0.205 0 0)` | `oklch(0.488 0.243 264.376)` | Resolve qua action/selection native |
| sidebar primary foreground | `oklch(0.985 0 0)` | `oklch(0.985 0 0)` | On-color theo nền thực tế |
| sidebar accent / foreground | Như accent / accent foreground | Như accent / accent foreground | Selection native |
| sidebar border / ring | Như border / ring | Như border / ring | Outline/focus native |
| chart 1…5, cả hai mode | `oklch(0.87 0 0)`, `oklch(0.556 0 0)`, `oklch(0.439 0 0)`, `oklch(0.371 0 0)`, `oklch(0.269 0 0)` | Cùng dãy Light | Chỉ trong plot/legend; không thay renderer preferences |

Hai điểm không được ánh xạ máy móc:

1. `accent` của shadcn ở đây là nền trung tính cho hover/selection; nó **không đồng nghĩa** với action blue của DockMagic.
2. Dù chọn Neutral, preview Dark vẫn trả về token `sidebar-primary` có sắc xanh. Đây là một token kế thừa quan sát được, không chứng minh mọi sidebar đang vẽ màu đó. Native adapter phải đi theo semantic owner của DockMagic.

Các token dùng cặp background/foreground và CSS variables là mô hình tham khảo hữu ích. [Theming](https://ui.shadcn.com/docs/theming).

### 3.2 Radius, spacing, type, size

Base `--radius = 0.625rem`; với root 16 px của preview: sm 6, md 8, lg 10, xl 14, 2xl 18, 3xl 22, 4xl 26 px. CSS radius lớn hơn nửa chiều cao sẽ tạo hình gần capsule. `Medium` không có nghĩa tất cả đều bo 10 px.

| Component/mẫu | Source và số đo web | Khuyến nghị native |
| --- | --- | --- |
| Button default | Cao 36; ngang 12; gap 6; radius 26; chữ 14 medium | Giữ minimum 36 pt hiện có; bổ sung variant, chọn radius trong contract native |
| Button xs/sm/lg | Cao 24/32/40; icon có các size tương ứng | Đừng lấy 24 px làm hit target mặc định của macOS; tách visual size/hit size |
| Input/Select default | Cao 36; radius 26; padding ngang 12 | Dùng native editor/picker và geometry chung; capsule là lựa chọn cần chốt |
| Textarea | Radius 14; padding 12; mẫu Notes đo cao 100 | Chiều cao 100 thuộc mẫu; source chỉ quy định min-height, native multiline tự tăng/scroll |
| Card | Radius 18; spacing/padding 24; `size=sm` dùng 16 | `DSCard` hoặc mở rộng composition hiện có; Settings/dashboard có density riêng |
| Card title/description | 16 medium / 14 regular | Ánh xạ role và surface; không nhập Geist vào native mặc định |
| FieldGroup | Gap 28; nhóm con có gap 16 | Không copy 28 vào từng feature; lựa chọn scale chung khi triển khai |
| Tabs list | Cao 36, padding 3, radius 26; trigger radius 14 | Tab nội dung dùng native TabView/wrapper; chart type vẫn segmented Picker |
| Checkbox | Hình vuông 16, radius 6 | Native checkbox; hit area/label đi cùng control |
| Switch default | Track 32 × 18.4; có hit area mở rộng qua CSS | Giữ native Toggle; không sao chép track nhỏ và bỏ hit area |
| Slider | Track dày 12; thumb 16 | Native Slider với row/label/value thống nhất |

Số đo lấy ở desktop preview hiện hành, không đại diện mọi breakpoint/variant. Hình học web là căn cứ để chọn thiết kế native, không phải phép quy đổi CSS `rem` trực tiếp vào Swift. Các dimension đã được chốt trong `Design.md` mới theo adapter 1 đơn vị = 1 SwiftUI pt.

### 3.3 Trạng thái và motion

Source Button có sáu variant `default`, `outline`, `secondary`, `ghost`, `destructive`, `link`; tám size gồm nhóm icon. Có focus ring, disabled, invalid và pressed. Loading được ghép bằng spinner, không có prop loading riêng trong Button. [Button](https://ui.shadcn.com/docs/components/base/button).

Field tách label/content/description/error, có orientation vertical/horizontal/responsive. Đây là mẫu nên học để thống nhất form Settings. [Field](https://ui.shadcn.com/docs/components/base/field).

Menu/Popover/Dialog dùng primitive quản lý mở/đóng, focus và semantics web. Skeleton có pulse; Button có dịch 1 px khi nhấn; dialog có fade/zoom 100 ms; Toast có transform khoảng 500 ms trong source đã lấy. Những animation này không tự trở thành motion contract của DockMagic. Giữ Reduce Motion và proposal chart/input hiện tại; không bê pulse/zoom/slide vào mọi surface.

Đã quan sát Light/Dark và mẫu Select mở menu, nhấn Escape đóng, focus trở lại trigger; mẫu disabled hiện trong AX tree. Chưa thử toàn bộ trạng thái của 63 component. Accessibility do Base UI hỗ trợ trên web không được coi là bằng chứng VoiceOver của bản SwiftUI. [Base UI accessibility](https://base-ui.com/react/overview/accessibility).

## 4. Phạm vi catalog và dependencies

Registry trong cấu hình `base-maia` trả về **216 item tổng**, trong đó **63 item loại `registry:ui`**. Đã lưu payload đầy đủ và inventory; 63 item này chứa **8.249 dòng source**, riêng `form` không có file triển khai trong payload. Không gọi chúng là 63 component đã cài/chạy thành công.

[Bảng ánh xạ đủ 63 item](research/shadcn-bbVKHJo-2026-09-17/NATIVE_COMPONENT_MAP.md) ghi rõ item nào mở rộng component hiện có, item nào dùng native adapter, item nào có thể hoãn vì chưa có nhu cầu.

Ngoài registry UI, trang docs còn có các recipe như **Data Table, Date Picker, Typography**: lần lượt là composition từ table/sort/filter, calendar/popover, và quy tắc type. Không cộng chúng vào con số 63 item UI. Blocks như login/dashboard/sidebar là ví dụ ghép component, không phải yêu cầu thêm những màn hình đó vào DockMagic. [Catalog chính thức](https://ui.shadcn.com/docs/components).

| Lớp web đã xác minh từ payload | Vai trò | Phương án DockMagic |
| --- | --- | --- |
| React/Next.js, Tailwind, `cn`, CVA, `tw-animate-css` | Render, variants, CSS | SwiftUI, token/style/Environment native |
| `@base-ui/react` | Control behavior, overlay, focus | Native SwiftUI/AppKit; không đưa React runtime vào app |
| HugeIcons | Icon lựa chọn của preset | SF Symbols theo UI-005 |
| `recharts@3.8.0` | Chart primitive/container | Swift Charts hoặc renderer có sẵn tùy loại dữ liệu |
| `react-day-picker`, `date-fns` | Calendar | DatePicker, Calendar/Foundation và calendar view riêng theo nhu cầu |
| `cmdk` | Command palette | Hoãn đến khi có use case; có thể dùng search + native list |
| `embla-carousel-react` | Carousel | Chưa cần cho ứng dụng monitoring |
| `react-resizable-panels` | Split panes | Native split view nếu cần |
| `sonner`, `next-themes`; Base UI Toast | Hai lựa chọn toast web trong registry | Một feedback host dùng chung nếu có nhu cầu, ưu tiên inline status |
| `input-otp`, `@shadcn/react` | OTP, questionnaire/message scroller | Chưa có nhu cầu sản phẩm hiện tại |

`view` trả về source registry trước một số bước biến đổi của installer; còn `IconPlaceholder` và import nội bộ. Metadata của style có thể chứa icon dependency mặc định. **Không lấy chúng làm bằng chứng preset dùng Lucide**: `preset.json`, config sinh bởi init và UI đều chọn HugeIcons. Snapshot này dùng để nghiên cứu, không phải bundle sẵn chạy.

shadcn/ui công bố MIT. Giữ attribution/notice khi sao chép hoặc port phần code đáng kể; license của dependency/icon/font cần kiểm tra riêng nếu sau này phân phối chúng. Đề xuất native hiện tại không thêm các dependency web đó. [License nguồn](https://github.com/shadcn-ui/ui/blob/main/LICENSE.md).

## 5. Nền hiện có của DockMagic và khoảng trống

Đã đối chiếu source đang nằm trong working tree, gồm các thay đổi chưa commit; không giả định HEAD phản ánh trạng thái app hiện tại.

| Khu vực | Đã có | Khoảng trống cần xử lý khi triển khai |
| --- | --- | --- |
| Foundation | `DesignTheme`, `ProjectTheme`, spacing/radius/type/motion, `DockMagicThemeRoot` | Thêm semantic geometry/density cần thiết; giữ một nguồn token |
| Actions | `DSButtonStyle`, `DSIconButtonStyle`, `dsInteractiveRow` | ButtonKind mới có neutral/primary/destructive; thiếu API thống nhất cho outline/ghost/link/size/loading composition |
| Settings | `DSSettingsSection`, `DSSettingsRow`, `DSActionRow`, `DSSettingsLinkRow` | Chưa có Field chung với label/helper/error/validation và input accessory |
| Status/content | `DSStatusBadge`, `DSStatusCard`, `DSMetricCard`, `DSDivider`, `DSIconPlate` | Empty/loading/stale/partial/retry chưa thành catalog thống nhất |
| Typography | Có `DSTypography.Dashboard` và ButtonStyle nhận surface | Badge/status/row còn gọi role mặc định trực tiếp; chưa thể coi cả app đã chuyển đúng surface |
| Surface | `dsSurface`, `DSElevation` | `DSSurface.swift` còn `LinearGradient` ở chrome; đây là legacy debt trái UI-008, không được nhân bản |
| Metric | `DSMetricCard` hiển thị phần trăm | Nhận `Double`, clamp 0…1; non-finite bị đổi thành 0. Không dùng làm metric tổng quát cho unavailable/unknown |
| Dashboard shell | `DockHoverChrome`, pointer và card shared | Các định nghĩa này nằm trong `CodexHoverDashboardView.swift`; nên chuyển về owner dùng chung |
| AI modules | `UsageLimitHoverRow`, momentum, intensity, top models, history | Nhiều provider dùng type mang tên Codex; tách presentation model trung lập trước khi đổi API |
| Charts | `AIUsageHistoryChart`, history viewport AppKit, daily bars, Binance charts | Cần contract chung cho axis/tooltip/state; không ép candle, quota và token bars thành một chart |
| Renderer preferences | `DSColorPalettePicker`, shared palette, production preview | Giữ nguyên ownership của lựa chọn màu, persistence và Reset Defaults |

Ví dụ source cụ thể:

- [DSControls.swift](../DockMagic/DockMagic/DesignSystem/Components/DSControls.swift): các style action và palette picker.
- [DSComponents.swift](../DockMagic/DockMagic/DesignSystem/Components/DSComponents.swift): badge/status/card/row/section và logic normalize metric.
- [DSSurface.swift](../DockMagic/DockMagic/DesignSystem/Components/DSSurface.swift): material, opaque fallback, legacy gradient.
- [DesignTokens.swift](../DockMagic/DockMagic/DesignSystem/Foundation/DesignTokens.swift): type theo surface và scale hiện hành.
- [CodexHoverDashboardView.swift](../DockMagic/DockMagic/Views/Hover/CodexHoverDashboardView.swift), [OpenCodeHoverDashboardView.swift](../DockMagic/DockMagic/Views/Hover/OpenCodeHoverDashboardView.swift), [GrokBuildHoverDashboardView.swift](../DockMagic/DockMagic/Views/Hover/GrokBuildHoverDashboardView.swift): định nghĩa và sử dụng chéo của module.

Đây là nhận xét từ source, không phải kết quả chạy app. Không sửa các điểm trên trong giai đoạn nghiên cứu.

## 6. Kiến trúc bộ component đề xuất

Giữ tên và thư mục `DesignSystem`; không dựng song song một theme engine `ShadcnTheme` cạnh `DesignTheme`.

```text
DesignSystem/
  Foundation/       token, theme, typography surface, geometry, state, motion
  Components/
    Actions/        ButtonStyle, IconButtonStyle, ButtonGroup, Keycap
    Forms/          Field, TextInput, SecureInput, TextArea, SearchField
    Selection/      ToggleRow, CheckboxRow, PickerRow, SliderRow
    Containers/     Card anatomy, SettingsSection, ItemRow, Divider
    Feedback/       Badge, StatusCard, EmptyState, LoadingState, Progress
    Presentation/   sheet/popover content composition, tooltip content
    Data/           Metric, ChartFrame, ChartLegend, ChartTooltip, TableState
  Gallery/          production components + fixtures, debug/development only

SharedUI/           vị trí đề xuất cho composition mang nghĩa sản phẩm
  Settings/         FeaturePreviewSection, RendererColorSection, ConnectionSection
  Dashboards/       DockHoverChrome, DashboardHeader, Freshness, CapabilitySlot
  AIUsage/          QuotaRow, DailyUsage, Momentum, Intensity, TopModels
  Export/           shared action chrome; renderer artifact vẫn có contract riêng
```

Tên file/type ở cây trên là đề xuất, chưa tồn tại đầy đủ. Khi triển khai ưu tiên di chuyển/mở rộng type sẵn có và giữ adapter tương thích trong quá trình migrate.

### 6.1 Quy tắc API

- Shared component không đọc trực tiếp store của Codex/Claude/Binance, không tự lưu UserDefaults hoặc gọi mạng.
- Feature truyền `Binding`, action, value đã format, unit, scope, freshness và accessibility description.
- Chọn typography bằng surface/role, có thể qua environment scoped tại Settings/dashboard host. Renderer Dock giữ type theo kích thước riêng.
- Phân biệt `intent` (normal/destructive) và `emphasis` (primary/secondary/outline/ghost/link); không tạo enum gồm mọi tổ hợp trạng thái.
- Loading, unavailable, partial, stale và failed-with-last-value phải là trạng thái rõ. `nil`, NaN, không có quyền và “provider không hỗ trợ” không được biến thành số 0.
- Feature chỉ điều chỉnh bố cục ngoài component. Màu, radius, focus, padding nội bộ dùng token/style chung; ngoại lệ cần variant có tên và được ghi vào catalog.
- Card có slot header/title/description/action/content/footer; không ép mọi nội dung có đủ tất cả slot.
- Native text editor giữ IME tiếng Việt, caret, selection, clipboard, undo; wrapper không thay thành view bắt từng phím.

Ví dụ **API định hướng, chưa phải code có thể build**:

```swift
DSField("API token", message: validationMessage) {
    DSSecureInput(text: $token)
}

Button("Connect", action: connect)
    .buttonStyle(DSButtonStyle(emphasis: .primary, surface: .settings))

DSMetric(
    title: "Tokens today",
    content: observedTokenPresentation,
    surface: .dashboard
)
```

Các tên/parameter mới phải được chốt khi triển khai. Có thể giữ `kind:` cũ và tạo overload/adapter để không buộc toàn bộ callers đổi cùng lúc.

### 6.2 Thành phần ưu tiên

| Ưu tiên | Thành phần | Lợi ích trực tiếp |
| --- | --- | --- |
| P0 | Theme/typography surface, geometry, state model, gallery | Nền chung trước khi sửa hàng loạt màn hình |
| P0 | Action variants, field/input/secure/multiline, row/section/card anatomy | Chuẩn hóa phần lặp lại nhiều nhất trong Settings |
| P0 | Status/empty/loading/retry/freshness, metric unknown-aware | Tránh mỗi provider tự dựng trạng thái và diễn giải missing sai |
| P1 | Picker/toggle/slider composition, tooltip/menu/sheet content | Hình thức chung nhưng giữ interaction native |
| P1 | Dashboard shell/header, chart frame/legend/inspect | Tái sử dụng ở hệ thống, AI, Binance, Weather |
| P1 | Extract AI modules và connection/renderer-color sections | Giảm phụ thuộc xuyên file provider và lặp form |
| P2 | Table/search/filter, calendar layout, media controls | Thực hiện theo use case cụ thể |
| Khi cần | OTP, carousel, messaging, questionnaire, command palette | Có mapping trong catalog; chưa cần code production |

“Dùng cho toàn bộ dự án” nghĩa là mọi feature có đường dùng component chung và cùng tiêu chí chất lượng. Không có nghĩa xây ngay mọi component web hoặc buộc từng feature phải hiện cùng một dashboard.

## 7. Áp dụng theo tính năng

Inventory Settings hiện có **18 destination enum**; feature flag có thể làm một số mục không hiện ở runtime. About/update/support cần rà qua composition của General/chrome, không dựa vào danh sách cũ trong docs để kết luận số màn hình.

| Nhóm | Component chung cần dùng | Phần vẫn đặc thù |
| --- | --- | --- |
| General, navigation, About/update | Sidebar rows, PickerRow, action/status, section | Routing, updater, launch-at-login |
| CPU & RAM, Network, Storage, Batteries | Metric, progress, chart frame, legend, preview/color section | Sampling, ring/network geometry, units/thresholds |
| Weather, Clock | Header/metric/status, settings rows, preview | Weather condition content, clock/digit renderer |
| Calendar | Field/input/multiline, DatePicker/Picker rows, empty/retry, sheet footer | EventKit permissions, timezone, calendar/reminder semantics |
| Now Playing | Identity/artwork container, icon actions, slider/value, connection state | Playback commands, artwork, source selection |
| GitHub, Search Console | Connection form, metric/table states, period selection, charts | Provider auth, repository/property data, aggregation |
| Codex, Claude Code, Antigravity | Dashboard shell, quota/history/freshness/status, export actions | Capability và evidence của từng provider; không suy quota từ activity |
| OpenCode, Grok Build, Augment | Shared history/insight modules, breakdown, connection/source section | Local observation và token bucket/provider khác nhau |
| Binance | Search/select, segmented chart type, metric/table/tooltip/chart frame | Candlestick, volume, feed update, scale và symbol semantics |
| Dock tile + Settings preview | Foundation/renderer primitives phù hợp | Raster proportional, không nhét form/button vào tile |
| Save/Copy/Share | Shared action và state | Dedicated artifact renderer, kích thước và điều kiện export riêng |

Chart type luôn dùng `Picker(...).pickerStyle(.segmented)` theo UI-014. Chỉ chia sẻ anatomy/style với Tabs/ToggleGroup, không thay control này bằng hàng button tự quản selection.

## 8. Trình tự triển khai sau nghiên cứu

| Giai đoạn | Công việc | Tiêu chí qua giai đoạn |
| --- | --- | --- |
| 0. Chốt adapter | Đối chiếu Maia nguyên bản với bản native; quyết định radius/density/variant. Giữ font/màu/icon hiện tại trừ quyết định mới rõ ràng | Một component contract được duyệt; proposal chưa duyệt không vào YAML |
| 1. Foundation + gallery | Mở rộng DS*, sửa legacy shared style trong phạm vi, tạo fixture các state thật bằng production component | Light/Dark/AX/keyboard/accessibility modes trên gallery native |
| 2. Pilot | Một Settings có form/connection, một dashboard AI, một chart market; Calendar editor bổ sung test IME/date | Chứng minh cả UI và behavior; API không buộc provider giả dữ liệu |
| 3. Settings toàn dự án | Migrate theo nhóm bảng mục 7, dùng bridge cho API cũ, giữ persistence | Các row/form/preview/color/reset thống nhất, không đổi dữ liệu đã lưu |
| 4. Dashboard + data | Extract module khỏi file provider, chuẩn hóa shell/status/chart inspection | Freshness/unknown/partial/gap và scrolling không hồi quy |
| 5. Dock + exports + đóng migration | Kiểm tra renderer ở nhiều cỡ, dedicated PNG; bỏ adapter cũ sau khi hết caller | Không còn component trùng hoặc feature-local style mới; docs khớp source |

Không đề xuất viết lại tất cả trong một patch. Di chuyển nguồn dùng chung và đổi thiết kế diện rộng cùng lúc làm tăng khó khăn khi xác định hồi quy. Pilot phải dùng API cuối dự kiến để tránh làm gallery xong lại viết component khác cho app.

## 9. Verification và quản trị lâu dài

Mỗi component trong catalog cần: mục đích, anatomy, variant/size, semantic token, surface, state matrix, keyboard/AX, ví dụ production và tình trạng kiểm thử. Một thay đổi shared component phải có danh sách consumers bị ảnh hưởng.

| Kiểm tra | Nội dung cần chứng minh |
| --- | --- |
| Appearance | Light, Dark, Increased Contrast, Reduce Transparency, grayscale |
| Motion | Reduce Motion; không animate Dock/export; update data không tạo observation giả |
| Input | Tab/Shift-Tab, Enter/Escape, IME tiếng Việt, copy/paste/undo, helper/error dài, invalid + focused, read-only |
| Actions | Hover/pressed/disabled/loading; prevent duplicate action; icon có label/help/hit target |
| Overlays | Escape/default action/focus restoration; popover host không gây mất hover dashboard ngoài ý muốn |
| Data | Zero thật, unknown, unavailable, partial, stale có cache, failed không cache; missing tạo gap |
| Charts | Unit/domain/selection/tooltip ổn định; keyboard inspect; không reset viewport khi refresh |
| Rendering | Production Dock 32/48/64/128 pt; Settings preview cùng renderer; PNG export đúng contract |
| Integration | Update preferences tức thì, persist/relaunch/reset; không làm lẫn provider credentials/data |
| Source | Không palette/gradient/style cục bộ mới; không raw font/color khi có role; catalog phủ consumers |

Dùng `DSAccessibilityOverrides` hiện có cho fixture deterministic, rồi kiểm tra bổ sung trên môi trường accessibility thật. Không coi override hoặc ảnh web là bằng chứng runtime macOS.

Khi thay active design contract, đồng bộ `Design.md`, `docs/DESIGN_SYSTEM.md`, `docs/COLOR_DESIGN_SYSTEM.md` và tokens; chạy linter Design.md theo UI-004. Research lần này không sửa các file đó nên không có thay đổi format cần lint.

## 10. Bằng chứng, giới hạn và khả năng tái kiểm tra

Đã thực hiện:

- Đọc `RULES.md`, `Design.md`, component/color contract và proposal input/chart/motion.
- Dùng CLI 4.21.0 giải mã preset, tạo được `components.json` với `base-maia`, liệt kê đầy đủ registry và lấy source của 63 UI item.
- Kiểm tra DOM/computed CSS và screenshot preview chính thức trong Light/Dark; thử Select mở/Escape/focus restoration.
- Đọc foundation/shared component, các điểm dùng lại giữa provider và đại diện Settings/chart/editor của DockMagic.
- Lưu snapshot nguồn, inventory, config, mapping và hash trong [thư mục bằng chứng](research/shadcn-bbVKHJo-2026-09-17/README.md).

**Chưa được xác minh:** bản Next.js tạo từ lệnh gốc build/run thành công; đầy đủ interaction của 63 component; native implementation mới; build/test/runtime/visual QA của DockMagic sau migration; đầy đủ license dependency nếu chọn phân phối chúng.

Mẫu tạm được tạo tại `/private/tmp/dm-preset-bbvkhjo-20260917`. Lần scaffold đầu dừng ở `npm install` với `ERESOLVE`, output nêu `react-dom@undefined` cho dependency `19.2.8` và Next `16.3.4`. Lần chạy tiếp trên scaffold ghi được config và kiểm tra registry, nhưng cài dependency dừng do `ENOTCACHED` khi dùng npm offline cache. Không dùng `--force` hoặc đổi version dependency để rồi tuyên bố lệnh gốc thành công. Các lỗi này không làm mất bằng chứng preset decode/source/preview, nhưng giới hạn bằng chứng build của template.

`@latest` và remote registry có thể thay đổi. CLI đã được ghi version, payload có SHA-256; chưa xác định upstream Git commit của payload nên không coi version CLI là pin toàn bộ registry.

Các nguồn web chính: [Preset](https://ui.shadcn.com/create?preset=bbVKHJo), [CLI](https://ui.shadcn.com/docs/cli), [Theming](https://ui.shadcn.com/docs/theming), [Components](https://ui.shadcn.com/docs/components), [Maia/Create](https://ui.shadcn.com/docs/changelog/2025-12-shadcn-create), [Button](https://ui.shadcn.com/docs/components/base/button), [Field](https://ui.shadcn.com/docs/components/base/field), [Chart](https://ui.shadcn.com/docs/components/base/chart), [Base UI accessibility](https://base-ui.com/react/overview/accessibility), [SwiftUI controls](https://developer.apple.com/documentation/swiftui/controls-and-indicators).
