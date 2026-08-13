# Sigma-inspired Design System for DockMagic

## 1. Phạm vi và nguồn sự thật

DockMagic áp dụng **các nguyên tắc và token công khai** của Sigma Design System
3 (DS3) vào một design system SwiftUI/AppKit riêng. Đây không phải bản port,
clone hay tuyên bố tương thích chính thức với Sigma.

Nguồn nghiên cứu công khai:

- [Sigma Design System](https://www.thesigma.co/designsystem) và
  [Design System Library](https://www.thesigma.co/designsystem-library).
- Foundation: [Principle](https://www.thesigma.co/designsystem-library/foundation/principle),
  [Colors](https://www.thesigma.co/designsystem-library/foundation/colors),
  [Dark mode](https://www.thesigma.co/designsystem-library/foundation/darkmode),
  [Material](https://www.thesigma.co/designsystem-library/foundation/material),
  [Shapes](https://www.thesigma.co/designsystem-library/foundation/shapes),
  [Elevation](https://www.thesigma.co/designsystem-library/foundation/elevation),
  [Typography](https://www.thesigma.co/designsystem-library/foundation/typography)
  và [Icons](https://www.thesigma.co/designsystem-library/foundation/icons).
- Organization/components: [Card](https://www.thesigma.co/designsystem-library/components/layout-and-organizations/card),
  [Lists](https://www.thesigma.co/designsystem-library/components/layout-and-organizations/lists)
  và [Toolbar](https://www.thesigma.co/designsystem-library/components/menus-and-actions/toolbar).

Sigma DS3 là thư viện Figma có licence; quyền sử dụng sản phẩm được Sigma mô tả
trong [Terms of use](https://www.thesigma.co/Termsofuse). DockMagic **không tải,
nhúng, sao chép hay phân phối lại** file Figma trả phí, component source, icon
pack hoặc font asset của Sigma. Implementation chỉ dùng thông tin xuất hiện
trên các trang công khai, rồi diễn giải lại bằng SwiftUI, SF Symbols và
semantic Color Set do DockMagic sở hữu.

## 2. Các nguyên tắc được chuyển dịch

Sigma công khai bốn nguyên tắc: đơn giản/có chủ đích, chú ý tới chi tiết, hài
hòa và nhất quán. Cấu trúc thị giác của DS3 được mô tả theo ba lớp:

```text
Canvas
  └─ Content layer
       └─ Navigation layer
```

DockMagic ánh xạ như sau:

| Lớp Sigma | DockMagic | Quy tắc |
| --- | --- | --- |
| Canvas | nền cửa sổ Settings | Không thêm material hoặc shadow trang trí. |
| Content | section, status card, metric, preview và form control | Surface đặc/opaque để nội dung luôn ổn định và dễ đọc. |
| Navigation | sidebar header/footer và navigation chrome | Là lớp duy nhất đủ điều kiện dùng glass trong mọi color scheme. |

Glass biểu đạt thứ bậc, không phải texture phủ lên mọi card. Nested content
không tự thêm glass hoặc shadow; elevation thuộc outer host có vai trò nổi rõ
ràng. Radius lồng nhau dùng quan hệ concentric
`childRadius = max(0, parentRadius - padding)`.

## 3. Token công khai và token do DockMagic suy diễn

### 3.1 Được xác nhận từ tài liệu công khai

Sigma công khai cặp màu Light/Dark sau:

| Hue | Light | Dark |
| --- | --- | --- |
| Red | `#FF383C` | `#FF4245` |
| Orange | `#FF8D28` | `#FF9230` |
| Yellow | `#FFCC00` | `#FFD600` |
| Lime | `#9DCC29` | `#A0CC33` |
| Green | `#34C759` | `#30D158` |
| Mint | `#00C8B3` | `#00DAC3` |
| Teal | `#00C3D0` | `#00D2E0` |
| Cyan | `#00C0E8` | `#3CD3FE` |
| Blue | `#0088FF` | `#0091FF` |
| Indigo | `#6155F5` | `#6B5DFF` |
| Purple | `#CB30E0` | `#DB34F2` |
| Pink | `#FF2D55` | `#FF375F` |
| Brown | `#AC7F5E` | `#B78A66` |

Các neutral công khai được ánh xạ trực tiếp vào semantic assets:

| Role công khai | Light | Dark |
| --- | --- | --- |
| Background primary | `#FFFFFF` | `#000000` |
| Background secondary | `#F5F4F2` | `#1F1E1E` |
| Background elevated | `#FFFFFF` | `#1F1E1E` |
| Text primary | `#000000` | `#FFFFFF` |
| Text secondary | `#434242` @ 60% | `#F5F3F0` @ 60% |
| Text tertiary | cùng base @ 30% | cùng base @ 30% |
| Text quaternary | cùng base @ 18% | cùng base @ 18% |
| Glass fill | `#FFFFFF` @ 80% | `#1F1E1E` @ 80% |

Typography scale công khai gồm Billboard `80/64/48`, Title `40/32/24`,
Headline `20`, Body `16/14`, Caption `16`, và link `16/14` có underline. Sigma
cũng công khai các nhóm shape Fixed/Capsule/Concentric, hai cấp elevation và
icon line/fill nhất quán.

### 3.2 Quyết định triển khai của DockMagic

Các trang công khai không cung cấp đầy đủ spacing scale, radius theo point,
shadow blur/offset, blur material, motion timing, hit target, font
weight/line-height hay toàn bộ state matrix. Vì vậy các giá trị sau là
**DockMagic-derived**, không được mô tả là token Sigma chính xác:

| Nhóm | Quyết định DockMagic |
| --- | --- |
| Font | System font/SF của macOS; không bundle General Sans. |
| Radius | `8 / 12 / 16 / 24`, capsule động; concentric tính từ parent/padding. |
| Spacing | `4 / 8 / 12 / 16 / 24 / 32`. |
| Type dùng trong app | Title `32`, headline `20`, panel `16`, section/body `14`, metadata `12`, caption `11`, metric rounded `24`. |
| Motion | Phản hồi `0.12–0.16 s`, metric `0.32 s`; bỏ animation không thiết yếu khi Reduce Motion. |
| Elevation | `none`, `primary` (`10 pt`, y `5`) và `secondary` (`5 pt`, y `2`). |
| Layout | Window tối thiểu `900 × 640`; sidebar `210/232/272`; detail tối đa `800`; preview `152`. |
| On-colors/outline/selection/shadow | Derived theo contrast và ngữ cảnh DockMagic, không sao chép token ẩn. |
| Text hierarchy | Giữ base neutral công khai nhưng tăng alpha runtime: secondary `80% / 60%`, tertiary `75% / 50%` (Light/Dark), để chữ nhỏ đạt tối thiểu `4.5:1` trên content surfaces. |
| Semantic foreground | Tách accent dùng trên content khỏi fill công khai: foreground được làm tối ở Light và giữ palette sáng ở Dark; fill/on-color vẫn theo cặp public palette + black. |

Màu ring/chart là preference do người dùng sở hữu. Default mới lấy cảm hứng từ
public palette, nhưng giá trị đã persist của người dùng không bị ghi đè.

## 4. Appearance contract

Preference `DockMagicAppearanceMode` có ba color scheme. Liquid Glass chrome
được tích hợp trong cả ba thay vì là mode thứ tư:

| Mode | Color scheme | Chrome/navigation | Content |
| --- | --- | --- | --- |
| `System` | Theo macOS | Native/fallback glass | Opaque |
| `Light` | Cố định Light | Native/fallback glass | Opaque |
| `Dark` | Cố định Dark | Native/fallback glass | Opaque |

`DockMagicThemeRoot` cài semantic theme và appearance ở cả Settings scene lẫn
AppKit Dock host boundary. `DSSurfaceKind.chrome` là surface duy nhất có
`isGlassEligible == true`; `shell`, `panel`, `raised` và `inset` luôn dùng
opaque semantic fill. Cách này giữ Canvas/Content ổn định khi người dùng đổi
mode và tránh chuỗi material lồng nhau.

## 5. Tương thích macOS 14 và Liquid Glass native

DockMagic vẫn có deployment target macOS 14 và build bằng Xcode 15.4/Swift
5.10. Vì toolchain này không biết API Liquid Glass của macOS 26, chrome hiện
dùng SwiftUI material công khai (`thinMaterial`) cộng semantic tint, outline và
specular edge.

Native path được cô lập trong `DSSurface`: chỉ compile khi
`compiler(>=6.2)`, sau đó mới kiểm tra `#available(macOS 26.0, *)` trước khi gọi
`glassEffect`. Nếu compiler hoặc OS không đáp ứng, code quay về material
fallback. Nhánh native này chưa được compiler/runtime hiện tại xác minh; bằng
chứng test trong repo chỉ bao phủ fallback. Không nâng deployment target, không thêm private API, entitlement
hoặc phụ thuộc Mac App Store. Quy tắc này phù hợp distribution trực tiếp bằng
Developer ID.

## 6. Component mapping

- `DSSurface` sở hữu material/opaque fallback, outline, semantic border và
  elevation.
- `DSSettingsSection` tạo một nhóm nội dung rõ ràng; `DSStatusCard` biểu đạt
  live/loading/stale/error bằng semantic role và nội dung, không chỉ bằng màu.
- `DSButtonStyle`/`DSIconButtonStyle` xử lý pressed/disabled; interactive rows
  xử lý hover/focus/selection. Tất cả tôn trọng accessibility preference phù hợp
  với state mà component sở hữu.
- Native `NavigationSplitView`, `Picker`, `Toggle`, `Slider`, `ColorPicker`,
  `LabeledContent` và `Button` giữ keyboard/VoiceOver behavior của macOS.
- Settings preview gọi đúng production Dock renderer; không có renderer mô
  phỏng thứ hai.
- SF Symbols thay cho icon assets trả phí. Icon trang trí bị ẩn khỏi AX tree;
  icon-only control có label/help/identifier.

## 7. Accessibility behavior

- **Reduce Transparency:** glass fill/material chuyển sang matching opaque
  surface; semantic outline vẫn được giữ để bảo toàn ranh giới control.
- **Increase Contrast:** outline/focus tăng độ mạnh và độ dày; trạng thái vẫn có
  text/symbol thay vì chỉ phân biệt bằng màu.
- **Reduce Motion:** bỏ animation press/focus/metric không thiết yếu.
- Dock renderer cung cấp label/value cho CPU/RAM, Network, Storage, Weather,
  Codex và Claude Code; loading/stale/unavailable có semantics riêng.
- Sidebar row là một accessibility element có identifier ổn định và value
  `Active`/selected; appearance picker công bố label/value hiện tại.
- Native controls được ưu tiên để giữ keyboard navigation, focus và state
  disabled chuẩn của macOS.

Automated AX/render tests không thay thế kiểm tra thủ công VoiceOver, keyboard
traversal, Reduce Motion và output cuối của system Dock compositor.

## 8. Toàn bộ UI thuộc phạm vi migration

### Settings do DockMagic sở hữu

Một `WindowGroup` Settings với tám destination:

1. General — appearance và active Dock feature.
2. CPU & RAM — preview, Chart/Numbers, màu, ring width và live metrics.
3. Network — preview, throughput hiện tại, interface, history và màu series.
4. Storage — preview, capacity, Chart/Numbers và appearance.
5. Weather — preview, freshness, permission/setup, refresh và attribution.
6. Codex — quota preview, Chart/Numbers, CLI detection/selection và refresh.
7. Claude Code — quota preview, Chart/Numbers, status-line bridge và refresh.
8. About — version, privacy, distribution và appearance summary.

### Dock do DockMagic sở hữu

Bảy presentation: logo DockMagic, CPU/RAM, Network, Storage, Weather, Codex và
Claude Code. Live, loading, zero/empty, stale, weekly-only và unavailable/error
được renderer thể hiện khi feature tương ứng có state đó.

Không có `MenuBarExtra`, `NSStatusItem`, onboarding, popover, sheet, custom
alert hoặc custom Dock context menu trong codebase hiện tại. `NSOpenPanel`,
Location permission prompt, System Settings và browser là UI do macOS sở hữu;
DockMagic không skin các surface này.

## 9. QA matrix

| Lớp | Coverage bắt buộc | Bằng chứng |
| --- | --- | --- |
| Foundation | mode persistence/fallback, color mapping, concentric radius, surface glass eligibility | Unit assertions |
| Appearance render | System, Light và Dark với glass fallback; Reduce Transparency và Increased Contrast | Offscreen render + window-only image attachments + sampled-pixel difference assertions |
| Settings | Tám destination trong cả ba mode, appearance persistence, active-feature icon/exclusivity, Chart/Numbers controls và production preview | Unit render + signed XCUI identifiers/values/clicks |
| Dock | Logo; CPU/RAM; Network; Storage; Weather; Codex; Claude ở các state hợp lệ, ba mode, Chart/Numbers và `32/48/64/128 pt` | Renderer matrix + non-text contrast assertions |
| Accessibility | Label/value/identifier, selected/active state, Reduce Transparency và Increased Contrast | XCUI/AX + render/contrast assertions; disabled, keyboard/VoiceOver và Reduce Motion còn là manual audit |
| Build | Debug build macOS 14 target với Xcode 15.4; compiler-gated native adapter không phá toolchain cũ | Clean isolated DerivedData build |
| Runtime | Signed app launch, Settings open/focus, close Settings nhưng process/Dock tile còn sống | Launch smoke + process/window observation |
| System compositor | Tile ở Dock thật, nhiều Dock size/position và wallpaper; Light/Dark | Manual screenshot/visual QA |
| Release | Developer ID, Hardened Runtime, notarization, stapling và Gatekeeper | Release pipeline evidence |

Mỗi báo cáo phải tách rõ source review, build, unit/render, XCUI, signed runtime
và manual compositor/VoiceOver. Một lớp pass không được dùng làm bằng chứng cho
lớp khác; đặc biệt offscreen snapshot không chứng minh pixel cuối của Dock.
