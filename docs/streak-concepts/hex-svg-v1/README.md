# Hex Collectibles — SVG v1

Bộ 10 collectible mới được dựng lại thành **SVG vector thật**, dựa trên PNG
trong `../hex-collectibles-v1/assets/`. Cả 10 SVG master đã thay asset production;
tên asset và logic streak được giữ nguyên. Pilot hai badge cũ ở `../svg-pilot/`
vẫn được giữ nguyên làm tư liệu.

## Nội dung

- 10 SVG master + 10 SVG compact trong `assets/`, nền trong suốt, viewBox 1024×1024.
- `index.html`: so sánh PNG concept/SVG, slider 24–512 px, mẫu 32/48/58/112 px,
  Master/Compact/Auto, Light/Dark, grayscale, tăng tương phản, nền đục và khóa.
- `manifest.json`: mapping tên, mốc ngày, tên asset tương ứng trong app, cấp khung,
  số sao, đường dẫn nguồn và dung lượng mỗi SVG.
- `native-collection-*.png`: bộ sưu tập render bằng SwiftUI từ asset catalog đã compile.
- `native-sizes-page-*.png`: đối chiếu 10 PNG concept với 20 SVG ở 1× và 2×.
- `native-*-3072.png`: xuất thử First Prompt, Builder và Continuum ở 3072×3072.
- `production-streak-badges-{light,dark}.png`, `production-continuum-dark.png`:
  ảnh từ chính `StreakDetailView` production do XCTest render sau khi tích hợp.
- `asset-catalog-info.json`, `validation.json`: bằng chứng 20 vector được giữ lại
  trong asset catalog, kiểm tra cấu trúc SVG, dung lượng và SHA-256.
- `hex-badges-svg.zip`: gói 20 SVG, manifest, kết quả kiểm tra và README để tải về.

## Cách chuyển thiết kế

Đây là bản diễn giải vector có chủ đích, không phải trace hàng nghìn điểm và cũng
không nhúng ảnh PNG vào thẻ SVG. Khung lục giác bo góc, biểu tượng, nhóm vật liệu và
số sao được giữ lại. Tô bóng raster được thay bằng mặt màu phẳng, đường Bézier và
đường viền. Khung được chuẩn hóa chung, các biểu tượng cân chỉnh bằng mắt theo mẫu.

| Mốc | Badge | Biểu tượng | Khung | Sao |
| --- | --- | --- | --- | --- |
| 1 | First Prompt | Bong bóng `>_` + tia sáng | Tím/periwinkle | 0 |
| 3 | Spark | Tia sáng + sét | Tím/periwinkle | 0 |
| 7 | Loop | Hai mũi tên xoay vòng | Tím/periwinkle | 0 |
| 14 | Builder | Ba khối lập phương | Tím/periwinkle | 1 |
| 30 | Flow | Ba dải sóng | Tím/periwinkle | 1 |
| 60 | Navigator | La bàn | Tím/periwinkle | 1 |
| 100 | Century | Cúp | Vàng | 2 |
| 180 | Architect | Tháp kiến trúc | Vàng | 2 |
| 365 | Keystone | Vòm đá + khóa đỉnh | Vàng | 2 |
| 730 | Continuum | Dải vô cực | Bạch kim + viền vàng | 3 |

Master giữ các mặt sáng và chi tiết phụ. Compact tăng độ dày đường viền và bỏ
các vệt sáng nhỏ; vẫn giữ cùng silhouette, biểu tượng và cấp sao. Ngưỡng Auto
≤60 px là đề xuất trong trang review. App hiện dùng SVG master ở mọi kích thước
với interpolation chất lượng cao; compact vẫn là phương án dự phòng.

Màu chỉ nằm trong artwork, theo ngoại lệ collectible ở §7 của
`docs/COLOR_DESIGN_SYSTEM.md`. Không có gradient, glow, font, `<image>`, filter,
script, tham chiếu ngoài hoặc CSS phụ thuộc môi trường. Ký hiệu `>_` là hình học.

## Tái tạo và kiểm tra

Chạy từ repository root:

```sh
node script/generate_streak_hex_svg.mjs
bash script/verify_streak_hex_svg.sh
```

Generator chỉ ghi vào thư mục nguồn này; tham số tùy chọn là đường dẫn asset
catalog tạm. Script verify dùng `mktemp` trong `/private/tmp`, compile bằng
`actool` cho macOS 14.0+, đọc `assetutil`, rồi render bằng harness SwiftUI độc lập.
Script này không launch DockMagic. Việc thay production được kiểm tra thêm bằng
cách so byte 10 SVG master với 10 imageset thực tế.

Kết quả kiểm tra ngày 2026-09-10:

- 20 SVG qua `xmllint` và allowlist; không có bitmap hoặc tài nguyên bên ngoài.
  Tái chạy generator cho SHA-256 giống hệt cả 20 file. Tổng 82,197 byte,
  mỗi file 3,086–5,951 byte (khoảng 3–6 KB).
- 20 mục `AssetType: Vector` được giữ trong asset catalog kiểm thử, cùng raster cache do
  Xcode tự sinh. Cả 30 asset gồm PNG tham chiếu và SVG đều load native thành công.
- Có render ở 32/48/58/112 pt tại 1× và 2×; collection ở 200 pt.
- Ba SVG được render lớn hơn viewBox lên 3072×3072. Harness xác nhận alpha ở
  bốn góc bằng 0 và tâm badge opaque, không chỉ kiểm tra cờ “has alpha”.
- Đã review fixture Light, Dark, Increased Contrast, grayscale, locked và
  Reduce Transparency. Đây là fixture cô lập, **không phải QA toàn app hoặc thay
  đổi thiết lập accessibility của hệ thống**. Nền của fixture luôn đục; bản
  Reduce Transparency xác nhận artwork không cần backdrop trong suốt. Grayscale
  được áp dụng bằng CGContext vì saturation của ImageRenderer headless không
  ổn định trong môi trường này. Locked thêm biểu tượng khóa và nhãn.
- Xcode có in cảnh báo dịch vụ CoreSimulator trong sandbox; tác vụ macOS
  `actool`, trình render native và kiểm tra vector đều hoàn tất với exit code 0.
- Browser local tải đủ 10 card / 60 ảnh, không có ảnh lỗi hoặc tràn ngang trang
  ở viewport 1265 px. Đã thử Compact, Dark, Locked và Auto ở 24 px: các mẫu
  ≤60 px dùng compact, 112 px vẫn dùng master, đủ 10 nhãn khóa.
- 10 imageset production chỉ còn `Contents.json` và một SVG; không còn PNG.
  Mỗi Contents khai báo `preserves-vector-representation: true`, và nội dung SVG
  khớp byte-for-byte với bản master trong manifest.
- Ảnh SVG production được tạo từ bản sao `NSImage` với `cacheMode = .never`.
  Điều này ngăn AppKit tái dùng cache raster của badge 48 pt khi chuyển sang card
  112 pt, từng gây mất một số lớp ở lần render Dark đầu tiên. Regression test
  render cả 10 badge theo chuỗi 48 → 112 → 112 pt và yêu cầu hai bản lớn giống hệt.

## Trạng thái tích hợp

Các imageset giữ đúng tên cũ trong manifest nên enum milestone không đổi. File
PNG 1× đã được thay bằng SVG master không có scale cố định và bật giữ vector.
`StreakBadgeView` dùng interpolation `.high` cho SVG ở mọi kích thước.

Nếu sau này chọn compact riêng cho ≤60 pt, cần thêm imageset compact và chọn theo
kích thước trong view. SVG không bị vỡ do phóng lớn như PNG; ở cỡ rất nhỏ vẫn
chịu giới hạn số pixel của màn hình, nên compact và cân chỉnh quang học vẫn có ích.
