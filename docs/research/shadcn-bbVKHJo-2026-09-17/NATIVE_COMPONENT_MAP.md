# Catalog ánh xạ native — preset bbVKHJo

Snapshot 17/09/2026, shadcn CLI 4.21.0, registry `base-maia`.

**63 registry UI item đã được thu thập; bảng này bao phủ 63/63.** Cột native là phương án, không phải tuyên bố tất cả type đã được triển khai. P0 = nền và component phổ biến; P1 = tiếp theo khi migrate surface; P2 = theo nhu cầu tính năng; Hoãn = chưa có use case đủ rõ. “Native” nghĩa là giữ hành vi control macOS, vẫn áp dụng shared composition/token khi phù hợp.

| Registry item | Anatomy/ý nghĩa đã đối chiếu | Ánh xạ DockMagic đề xuất | Ưu tiên |
| --- | --- | --- | --- |
| `accordion` | Item, trigger, content; expanded/collapsed | `DisclosureGroup` với shared section style; giữ keyboard disclosure | P1 |
| `alert` | Title, description, optional action | Mở rộng `DSStatusCard` với action/recovery slot và surface font | P0 |
| `alert-dialog` | Confirmation, title/description, cancel/action | Native alert/confirmationDialog; destructive role, default/cancel action rõ | P1 |
| `aspect-ratio` | Giữ tỷ lệ media | `.aspectRatio` trong artwork/preview container chung | P2 |
| `avatar` | Image, fallback, badge/group | Identity image container có fallback; logo bounded; không bắt logo service thành hình tròn | P1 |
| `badge` | Label/icon, emphasis variants | Mở rộng `DSStatusBadge`; tách neutral metadata badge và semantic status | P0 |
| `breadcrumb` | Ancestors/current page, separator | Chỉ thêm khi có navigation phân cấp thực; Settings hiện không cần breadcrumb web | Hoãn |
| `button` | Sáu variant, tám size, focus/disabled/invalid | Mở rộng `DSButtonStyle`/`DSIconButtonStyle`, giữ native Button/Link semantics | P0 |
| `button-group` | Ghép action liền nhau, separator | Shared action-group layout; không dùng thay segmented selection | P1 |
| `calendar` | Month/day navigation, selected/range states | Giữ calendar feature; dùng DatePicker native cho nhập ngày, calendar grid riêng khi cần agenda/range | P2 |
| `card` | Header/title/description/action/content/footer; default/sm | Card anatomy dùng chung; tái cấu trúc DSSettingsSection/metric container, tránh card lồng shadow | P0 |
| `carousel` | Viewport/items/previous/next | Chưa có nhu cầu monitoring rõ; không tạo carousel cho dashboard chỉ vì registry có | Hoãn |
| `chart` | Container/config/tooltip/legend, Recharts | Chart frame/legend/tooltip/state chung; Swift Charts hoặc renderer hiện có theo dữ liệu | P1 |
| `checkbox` | Checked/unchecked/invalid/disabled | Native checkbox Toggle + Field/row; bổ sung mixed state bằng adapter nếu thực sự cần | P1 |
| `collapsible` | Root/trigger/content | Native DisclosureGroup; có thể dùng cùng primitive với Accordion | P1 |
| `combobox` | Editable query/list/chips/clear | Search + native selection/list/popover; adapter riêng nếu cần multi-select, không giả thành menu Picker đơn giản | P2 |
| `command` | Search/groups/items/shortcut/empty | Command palette là feature riêng, chưa tạo trước nhu cầu | Hoãn |
| `context-menu` | Menu groups/items/submenu/check/radio | `.contextMenu`, native menu item semantics | P1 |
| `dialog` | Trigger/overlay/content/title/description/footer | Native sheet/window theo tác vụ; shared content layout, focus/default/cancel | P1 |
| `drawer` | Panel trượt/swipe handle/modal states | Không port bottom sheet điện thoại; dùng inspector/sheet native nếu có use case | Hoãn |
| `dropdown-menu` | Trigger/menu/group/item/submenu | Native `Menu`; dùng chung labels/intent/shortcut model khi cần | P1 |
| `empty` | Media/title/description/content/action | Shared `DSEmptyState` đề xuất, phân biệt chưa có data với unavailable | P0 |
| `field` | Set/legend/group/label/content/helper/error | Shared Field và validation presentation; native editor/control làm con | P0 |
| `form` | Item có metadata, **không có file source** ở snapshot này | Không giả định có implementation để port; dùng Field + Form native khi phù hợp | P0 |
| `hover-card` | Trigger/content/placement | Help/popover khi cần; Dock hover dùng host/delay hiện có, không lấy mặc định web | P1 |
| `input` | Single-line, focus/invalid/disabled | Shared text/secure/search wrapper trên native editor | P0 |
| `input-group` | Editor + addon/button/text | Leading/trailing accessory slots trong shared input, không chồng focus ring | P0 |
| `input-otp` | OTP group/slot/separator | Chưa có flow OTP native cần component này | Hoãn |
| `item` | Media/content/title/description/actions/header/footer | Mở rộng row composition: DSSettingsRow/DSActionRow và item row dùng chung | P0 |
| `label` | Label cho control | Role typography + association/AX của Field; không chỉ tạo Text trang trí | P0 |
| `menubar` | Menus, trigger, items, shortcuts | Native app menu/Commands; không dựng web menubar trong Settings | P1 |
| `navigation-menu` | Site navigation dropdowns/positioner | NavigationSplitView/sidebar/router hiện có; không port menu website | Hoãn |
| `pagination` | Previous/next/page/current | Shared pagination control khi table thực sự phân trang; không áp vào chart history scroll | P2 |
| `popover` | Trigger/content/header/title/description | Native popover host + shared content composition | P1 |
| `progress` | Track/indicator/label/value | Native ProgressView/shared track; phân biệt tiến trình tác vụ, quota và renderer ring | P0 |
| `radio-group` | Single choice root/item | Native radio-style Picker cho lựa chọn phù hợp; chart type vẫn segmented | P1 |
| `resizable` | Panel group/panel/handle | Native split view chỉ tại surface cho phép resize; không đổi fixed sidebar contract tự động | P2 |
| `scroll-area` | Viewport/scrollbar | Native ScrollView/NSScrollView; reuse DashboardNativeHistoryViewport cho lịch sử | P1 |
| `select` | Trigger/value/group/item/menu/scroll | Native Picker/menu với label/value; không viết lại keyboard selection | P1 |
| `separator` | Horizontal/vertical divider | `DSDivider` mở rộng orientation hoặc native Divider | P0 |
| `sheet` | Side content/overlay/header/footer | Native sheet/inspector/window theo semantics; không dịch từng CSS side thành macOS sheet | P1 |
| `sidebar` | Provider/header/content/footer/group/menu/collapse | NavigationSplitView + sidebar rows chung; giữ routing và typography Settings | P1 |
| `skeleton` | Placeholder có pulse | Chỉ placeholder vùng nội dung khi có lợi; chart dùng loading slot, Reduce Motion bỏ pulse | P1 |
| `slider` | Track/range/thumb, orientation, nhiều thumb | Native Slider cho scalar; range hai đầu cần component riêng khi có yêu cầu, không giả tương đương | P1 |
| `sonner` | Toast renderer dùng Sonner/next-themes | Không thêm dependency; cùng chính sách feedback host với Toast | P2 |
| `spinner` | Busy indicator có label | Native ProgressView + busy text/AX, ghép được trong action | P0 |
| `switch` | Toggle track/thumb, size, checked/disabled | Native Toggle + Settings row composition | P1 |
| `table` | Header/body/footer/row/cell/caption | Native Table/List với shared empty/loading/sort/filter presentation | P2 |
| `tabs` | List/trigger/content; default/line, orientation | Native TabView cho chuyển panel, shared segmented composition cho view mode; chart type theo UI-014 | P1 |
| `textarea` | Multiline, disabled/invalid/focus | Native multiline TextField/TextEditor + Field helper/error | P0 |
| `toast` | Provider/viewport/toast/content/actions, dismiss/swipe | Nếu cần, một host chung cho feedback không chặn; lỗi quan trọng vẫn inline, không biến mất tự động | P2 |
| `toggle` | Pressed/unpressed action | Native toggle/button style theo semantic; không trộn selection và action | P1 |
| `toggle-group` | Single/multiple choices, item, orientation/spacing | Segmented Picker cho single choice; checkbox/toggle group có label cho multiple choice | P1 |
| `tooltip` | Trigger/content, placement | `.help` cho text đơn; chart tooltip dùng shared inspection content có AX tương đương | P1 |
| `kbd` | Keycap/group | Shared keycap theo typography Settings/dashboard và shortcut thật | P1 |
| `native-select` | Native HTML select/options/optgroup | Native macOS Picker; cùng API composition với Select nếu semantics tương đương | P1 |
| `direction` | Re-export DirectionProvider/useDirection | SwiftUI layoutDirection/localization; không cần package React | P1 |
| `attachment` | Media/content/actions/group, upload states | Chỉ khi có attachment/import use case; export PNG hiện tại không đòi upload component | Hoãn |
| `bubble` | Chat bubble/content/reactions | Chưa có chat surface trong phạm vi monitoring hiện tại | Hoãn |
| `message-scroller` | Message viewport/content/item, scroll-to-edge button | Chưa có conversation; history chart có owner/behavior riêng | Hoãn |
| `questionnaire` | Progress/item/choices/input/submit | Chưa cần flow hỏi đáp nhiều bước; không thêm onboarding giả | Hoãn |
| `marker` | Icon/content/separator marker | Chỉ dùng nếu calendar/activity timeline cần marker chung | P2 |
| `message` | Avatar/header/content/footer/alignment/group | Chưa có messaging use case; không đổi status card thành chat message | Hoãn |

## Recipe ngoài 63 registry UI item

| Recipe trên docs | Phương án |
| --- | --- |
| Data Table | Table + filter/sort/pagination/selection; feature sở hữu data acquisition |
| Date Picker | Native DatePicker cho editor; range calendar chỉ nếu use case yêu cầu |
| Typography | DSTypography theo surface + role, monospaced digits; không bundle Geist mặc định |

Nguồn: [registry-catalog.txt](registry-catalog.txt), [registry-ui-source.json](registry-ui-source.json), [component-inventory.json](component-inventory.json), [docs catalog](https://ui.shadcn.com/docs/components). Xem [báo cáo chính](../../SHADCN_PRESET_RESEARCH.md) để biết giới hạn kiểm chứng và thứ tự migration.
