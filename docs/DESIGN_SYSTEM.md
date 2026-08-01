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
  └─ cài theme và Light appearance ở scene/AppKit host boundary
```

Feature view không tạo one-off material, shadow, focus ring hoặc status color.
Màu ring/chart Dock là preference do product model sở hữu vì người dùng có thể
đổi; renderer chỉ nhận appearance model tương ứng qua input.

## 2. Appearance

DockMagic hiện dùng **Light mode cố định**. `DockMagicThemeRoot` áp dụng
`.preferredColorScheme(.light)` đúng một lần ở Settings scene và Dock
`NSHostingView`. Không có appearance picker hay persisted System/Dark option.

Named assets vẫn cần contrast hợp lý trên opaque Light surface. Dock-specific
track/background/outline cũng phải đọc được trên các wallpaper và Dock material
khác nhau; bước đó cần compositor pass thật trước release.

## 3. Semantic roles

- Action: `action`, `onAction`.
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
| Radius | keycap 6, control 8, inset 10, row 12, panel 16, large panel 20 pt |
| Spacing | compact 6, standard 10, section 14, panel 16 pt |
| Typography | panel 14 semibold, section 13 semibold, body 12, metadata 10.5, Settings title 24 bold |
| Motion | press/focus 0.10 s, row hover 0.12 s, metric change 0.35 s |
| Rows | minimum 46 pt, full-row content shape, independent focus/selection |

Surface hierarchy là `shell → panel → raised → inset → chrome`. Nested card
không tự tạo shadow; outer floating host mới sở hữu elevation lớn.

## 5. Settings composition

- Primary window: default `980 × 720`, minimum content `860 × 620`.
- Native `NavigationSplitView`, sidebar 190–260 pt.
- Destinations: General, CPU & RAM, Network, Storage, Weather, Codex,
  Claude Code, About.
- Detail content dùng `DSSettingsSection`, `DSStatusCard`, native `Picker`,
  `ColorPicker`, `Slider`, `LabeledContent` và `Button`.
- Preview dùng chính production Dock renderer, không có renderer mô phỏng riêng.
- Controls thay đổi preference ngay; nếu feature active, Dock update ngay.
- Footer “Light appearance” chỉ mô tả contract, không phải control.

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
- Radio group bảo đảm đúng một active feature và sử dụng native keyboard/AX
  semantics.
- Không đặt identifier ở container quá cao nếu SwiftUI có thể propagate nó
  xuống nhiều descendants.

## 8. Checklist cho UI mới

1. Chọn owner và semantic role trước khi viết layout.
2. Dùng token/component hiện có; nếu thiếu, bổ sung shared primitive có state
   hover/pressed/focus/disabled/error phù hợp.
3. Kiểm tra Light, increased contrast, Reduce Transparency, Reduce Motion,
   pointer, keyboard và nội dung dài.
4. Kiểm tra AX uniqueness/hittability, không chỉ existence.
5. Render Dock ở 32/48/64/128 pt và kiểm tra Settings runtime screenshot.
6. Trước release, quan sát system Dock thật ở nhiều size/position; snapshot hoặc
   AX tree không chứng minh output compositor cuối cùng.
