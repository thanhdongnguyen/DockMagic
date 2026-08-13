# DockMagic Design System

## 1. Contract

Design system tách foundation khỏi quyết định sản phẩm:

```text
DesignSystem
  ├─ typography, spacing, radius, motion
  ├─ semantic roles, surfaces, controls, status/settings components
  └─ không biết RGB/hex hoặc feature cụ thể

ProjectTheme
  ├─ map semantic roles sang DS… Color Set assets
  └─ cung cấp opaque fallback cho Reduce Transparency

DockMagicThemeRoot
  └─ cài theme, tint và appearance đã chọn ở scene/AppKit host boundary
```

Feature view không tạo one-off material, shadow, focus ring hoặc status color.
Màu ring/chart Dock là preference do product model sở hữu vì người dùng có thể
đổi; renderer chỉ nhận appearance model tương ứng qua input.

## 2. Appearance

DockMagic có ba lựa chọn color scheme persist: **System, Light và Dark**.
`DockMagicThemeRoot` áp dụng color scheme, semantic tint và surface contract ở
Settings scene lẫn Dock `NSHostingView`. Liquid Glass là chrome mặc định của cả
ba mode và chỉ áp dụng cho navigation/chrome; content chính giữ opaque. Trên
macOS 14/Xcode 15.4, glass dùng material fallback; native `glassEffect` chỉ là
nhánh availability-gated cho toolchain/macOS mới và chưa được xác minh trong
môi trường hiện tại.

Named assets phải đạt contrast trên opaque Light/Dark surfaces. Dock-specific
track/background/outline cũng cần compositor pass thật trước release.

## 3. Semantic roles

- Action: `action`, `onAction`.
- Accent foreground: các role `…Foreground` dùng cho text/icon trên content;
  base action/status sáng dùng cho fill.
- Status: `information`, `processing`, `warning`, `danger` và on-color tương ứng.
- Text: `textPrimary`, `textSecondary`, `textTertiary`.
- Structure: `focus`, `outline`, `outlineStrong`, `shadow`, `selectionFill`,
  `selectionOutline`.
- Surface: `surface`, `surfaceRaised`, `surfaceInset`, `surfaceChrome` và bốn
  opaque fallback.
- Dock chrome: `dockTrack`, `dockBackgroundRaised`, `dockBackgroundInset`,
  `dockOutline`.

Status luôn dùng semantic role. CPU/RAM/Network/Storage/Codex/Claude Code
renderer colors không được tái sử dụng làm status colors vì chúng là lựa chọn
cá nhân và có thể không đạt meaning nhất quán ngoài renderer. Weather condition
palette là một phần của renderer, còn freshness/error badge vẫn dùng semantic
warning/danger.

## 4. Foundation tokens

| Nhóm | Contract |
| --- | --- |
| Radius | 8 / 12 / 16 / 24 pt, capsule động và concentric radius |
| Spacing | 4 / 8 / 12 / 16 / 24 / 32 pt |
| Typography | title 32, headline 20, panel 16, body/section 14, metadata 12, caption 11, metric 24 pt |
| Motion | phản hồi 0.12–0.16 s, metric change 0.32 s; tôn trọng Reduce Motion |
| Rows | content/action row tối thiểu 46 pt; compact sidebar row tối thiểu 30 pt; full-row content shape và independent focus/selection |

Surface hierarchy là `shell → panel → raised → inset → chrome`. Nested card
không tự tạo shadow; outer floating host mới sở hữu elevation lớn.

## 5. Settings composition

- Primary window: default `1020 × 740`, minimum content `900 × 640`.
- Native `NavigationSplitView`, sidebar `210 / 232 / 272` pt.
- Destinations: General, CPU & RAM, Network, Storage, Weather, Codex,
  Claude Code, About.
- Detail content dùng `DSSettingsSection`, `DSStatusCard`, native `Picker`,
  `ColorPicker`, `Slider`, `LabeledContent` và `Button`.
- Preview dùng chính production Dock renderer, không có renderer mô phỏng riêng.
- Controls thay đổi preference ngay; nếu feature active, Dock update ngay.
- General có appearance picker; footer phản ánh mode hiện tại.

## 6. Dock composition

- Tile geometry luôn tỷ lệ theo cạnh, không dựa vào kích thước Settings preview.
- Outer/inner ring có default color riêng từng feature nhưng cùng model clamp.
- Storage dùng một ring; Network dùng hai series diverge quanh baseline, chung
  scale và không tái sử dụng ring metaphor.
- Weather không dùng ring: gradient, condition symbol và temperature tạo thứ tự
  đọc; H/L chỉ xuất hiện khi tile đủ lớn để không làm hỏng 32/48 pt.
- Track/background/outline lấy semantic assets.
- Progress không chỉ dựa vào màu: renderer có accessibility label/value đầy đủ.
- Loading/stale/unavailable có symbol và text semantics phù hợp.
- Animation được dùng trong preview nhưng tắt ở AppKit Dock host.

## 7. Accessibility

- Reduce Transparency đổi material sang matching opaque role.
- Increased Contrast tăng outline/focus khi component hỗ trợ.
- Reduce Motion bỏ animation không thiết yếu.
- Icon-only control phải có label, help và stable identifier.
- Decorative background, preview ornaments và active dots bị ẩn khỏi AX tree.
- Sidebar row là một accessibility element, có stable identifier và value
  `Active` khi feature tương ứng đang được hiển thị.
- Native menu `Picker` bảo đảm đúng một active feature và giữ keyboard/AX
  single-selection semantics.
- Không đặt identifier ở container quá cao nếu SwiftUI có thể propagate nó
  xuống nhiều descendants.

## 8. Checklist cho UI mới

1. Chọn owner và semantic role trước khi viết layout.
2. Dùng token/component hiện có; nếu thiếu, bổ sung shared primitive có state
   hover/pressed/focus/disabled/error phù hợp.
3. Kiểm tra Light/Dark/Liquid, increased contrast, Reduce Transparency, Reduce Motion,
   pointer, keyboard và nội dung dài.
4. Kiểm tra AX uniqueness/hittability, không chỉ existence.
5. Render Dock ở 32/48/64/128 pt và kiểm tra Settings runtime screenshot.
6. Trước release, quan sát system Dock thật ở nhiều size/position; snapshot hoặc
   AX tree không chứng minh output compositor cuối cùng.
