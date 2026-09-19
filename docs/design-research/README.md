# DockMagic design research specimens

Nghiên cứu ngày 17/09/2026. Định hướng và quyết định nằm trong
[Design.md](../../Design.md).

Sau vòng so sánh, người dùng đã chốt **SF Pro Rounded cho dashboard/Dock**
và **SF Pro cho Settings**. Các ảnh ở đây là specimen của vòng nghiên cứu
ban đầu; nhãn “Khuyên dùng” trong ảnh không ghi đè quyết định mới. Chúng chưa
phải gallery kiểm chứng component hoặc motion production.

## Định dạng Design.md cho AI

Root [Design.md](../../Design.md) dùng
[Google DESIGN.md alpha](https://github.com/google-labs-code/design.md/blob/9bf8eae67128b6cc55ad9bf86665767deb4c11cd/docs/spec.md),
đối chiếu ngày 17/09/2026: YAML token và tám mục Markdown theo canonical order.
Motion nằm trong Components vì alpha chưa có nhóm motion token. Quyết định
đã chốt nằm trong phần active; proposal input/chart/motion vẫn ở prose và
[spec riêng](../UI_COMPONENT_MOTION_SPEC.md), không đưa vào YAML.

Kiểm tra từ repository root, không thêm dependency vào app:

```sh
npx --yes @google/design.md@0.4.0 lint Design.md
```

Lần chuyển định dạng chạy CLI chính thức `@google/design.md@0.4.0`, đối chiếu
SHA-512 gói tải về với npm metadata, chạy bản bundle bằng Node từ `/tmp`.
Lint báo **0 errors, 16 warnings, 1 info**. Toàn bộ warning là
`orphaned-tokens`: một số màu semantic trong foundation chưa có tham chiếu
ở YAML `components`; mapping và cách dùng của chúng được mô tả trong Colors.
Ví dụ outline có vai trò native nhưng alpha chưa có property chuẩn
`borderColor`. Giữ token có ý nghĩa thay vì tạo component giả để xóa warning.
Không có lỗi reference, section order hoặc cảnh báo contrast cho các cặp
component được khai báo. Linter chỉ kiểm tra phạm vi tài liệu, không chứng
minh app đã đổi font, đạt accessibility hoặc chạy đúng motion.

Giữ tên file `Design.md` theo repository; CLI nhận đường dẫn trực tiếp.
YAML dùng đơn vị `px` hợp schema, adapter của DockMagic ánh xạ giá trị số sang
SwiftUI layout point. Đây không phải hướng dẫn dùng CSS trong app native.

## Những chỗ source chưa khớp contract

Snapshot audit ngày 17/09/2026, giữ lại từ báo cáo nghiên cứu trước khi root
file chuyển sang định dạng Google. Đọc lại source trước khi sửa; bảng không
phải xác nhận trạng thái runtime hiện tại hoặc yêu cầu sửa trong lượt này.

| Quan sát | Migration cần thiết |
| --- | --- |
| `DSTypography` chưa phân chia đủ font theo surface | Rounded cho dashboard/Dock, SF Pro cho Settings; kiểm tra cả explicit font trong descendant và AppKit/CoreText |
| `DSControls.swift` có `LinearGradient` trong viền button; `DSSurface.swift` có gradient trên material | Bỏ lớp trang trí, giữ semantic surface và native material/fallback |
| `CodexHoverDashboardView.swift` có cỡ 8–10.5 pt | Phân biệt decorative/caption với thông tin phải đọc; migrate theo role |
| Swatch vẫn scale khi pressed dù Reduce Motion bỏ animation | Gate cả transform, giữ focus/hit area |
| Input trộn `.plain`, `.roundedBorder` và mặc định | Shared primitive dùng native text editing với cùng geometry/state contract |
| `AIUsageHistoryChart` và `BinancePriceChartView` chưa có policy data-update animation | Tách data event khỏi hover/layout; review proposal trước migration |
| `DSMetricCard` đổi non-finite thành zero và tự chọn action tint | Không dùng nguyên trạng cho metric nullable; sửa semantics tại shared model/component |
| Checklist cũ nói “Liquid appearances” | System/Light/Dark là ba mode; Liquid Glass chỉ là chrome |

## Mẫu trực quan

- [Typography Light](fonts-light.png), [Typography Dark](fonts-dark.png).
- [Increased Contrast Light](fonts-light-contrast.png),
  [Increased Contrast Dark](fonts-dark-contrast.png).
- [Grayscale](fonts-grayscale.png).
- [Palette Light](palette-light.png), [Palette Dark](palette-dark.png).

Đây là SwiftUI specimen độc lập có dữ liệu minh họa, xuất qua `ImageRenderer`
ở 2x. Không phải ảnh dashboard đang chạy. Typography board có kích thước
1060 x 1008 pt, file 2120 x 2016 px. Palette có kích thước 1060 x 386 pt,
file 2120 x 772 px. Mở ở 50% kích thước pixel để xem gần kích thước layout;
retina/display scaling của trình xem có thể khác.

Cả bốn phương án dùng cùng nội dung, cùng nominal size và weight. Kích thước
optical thực tế khác nhau là đặc trưng của font. Tên font và lời chú thích
ngoài phần mẫu dùng system font để khung so sánh giữ ổn định.

Palette specimen lấy các hex được tài liệu hóa từ assets, làm tròn về 8-bit.
Script contrast đọc trực tiếp component thập phân và alpha trong assets;
không tính từ pixel của PNG. Bảng màu có nhãn primary/secondary chỉ minh họa
cách phối màu, không phải control production hay bài kiểm tra tương tác.

## Dựng lại

Chạy từ repository root trên macOS có SwiftUI và Xcode command-line tools:

```sh
xcrun swiftc -parse-as-library -module-cache-path /tmp/dockmagic-design-module-cache docs/design-research/render-specimens.swift -o /tmp/dockmagic-render-specimens
/tmp/dockmagic-render-specimens
python3 docs/design-research/audit-palette.py
```

Font custom chỉ đăng ký `.process`. Không cài vào Font Book, không thêm vào
app bundle hoặc sửa Xcode project. Binary và compiler cache nằm ở `/tmp`.

## Font provenance và license

| Font | Nguồn | Revision dùng trong mẫu | License |
| --- | --- | --- | --- |
| SF Pro / SF Pro Rounded | System font qua `NSFont` và SwiftUI | Phiên bản hệ thống máy render | Không sao chép/bundle file font Apple |
| Geist Regular / Medium / SemiBold | [vercel/geist-font](https://github.com/vercel/geist-font/tree/10dc7658f13c38a474cde201bb09a4617267545b/fonts/Geist/otf) | `10dc7658f13c38a474cde201bb09a4617267545b` | [OFL 1.1](fonts/Geist-OFL.txt), copyright The Geist Project Authors |
| IBM Plex Sans Regular / Medium / SemiBold | [IBM/plex](https://github.com/IBM/plex/tree/78cd4223d8de9fcb78cba84eadecb269c56093c5/packages/plex-sans/fonts/complete/ttf) | `78cd4223d8de9fcb78cba84eadecb269c56093c5` | [OFL 1.1](fonts/IBMPlex-LICENSE.txt), copyright IBM Corp., Reserved Font Name Plex |

Các font custom là binary nguyên bản, không đổi tên hoặc sửa outlines.
Giữ license/copyright đi kèm nếu chuyển bộ specimen sang nơi khác.

PostScript name của Plex khác tên file: Regular = `IBMPlexSans`, Medium =
`IBMPlexSans-Medm`, SemiBold = `IBMPlexSans-SmBld`. Renderer dùng tên được
đọc từ CoreText font descriptor, không đoán family theo tên file.

## Kiểm tra đã chạy

- Renderer compile/run thành công bằng Xcode 15.4.
- Có 24 phép kiểm coverage: bốn family, ba weight, hai normalization NFC/NFD.
- 18 phép kiểm đủ toàn bộ chuỗi mẫu. Sáu phép kiểm của Geist cùng thiếu
  `U+20AB` (ký hiệu `₫`), không thiếu các dấu tiếng Việt trong chuỗi mẫu.
  [font-validation.json](font-validation.json) lưu tên font và missing codepoint.
- 42 cặp text/background qua kiểm tra sRGB contrast trên nền opaque đều
  đạt 4.5:1; [contrast-audit.json](contrast-audit.json) lưu từng cặp.
- Counterexample: trắng trên Light `DSAction` chỉ đạt khoảng 3.52:1;
  `DSOnAction` hiện là đen, đạt khoảng 5.96:1.

Increased Contrast trong specimen là biến thể renderer tăng outline và dùng
primary text cho secondary; không phải capture khi bật setting hệ thống.
Grayscale là `.saturation(0)` trên specimen, không thay thế mô phỏng mọi loại
color vision deficiency. Tất cả specimen có nền đặc nên không thể chứng minh
nhánh material/Reduce Transparency của app. Chưa kiểm thử accessibility tree,
keyboard, motion hay compositor production trong lượt này.

## Nguồn nghiên cứu Apple

Đã đọc [SwiftUI](https://developer.apple.com/documentation/swiftui),
[Typography](https://developer.apple.com/design/human-interface-guidelines/typography),
[Color](https://developer.apple.com/design/human-interface-guidelines/color),
[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
và [Motion](https://developer.apple.com/design/human-interface-guidelines/motion).
Với trang yêu cầu JavaScript, nội dung lấy từ endpoint DocC JSON trên cùng
domain `developer.apple.com`, gồm `/tutorials/data/documentation/swiftui.json`
và `/tutorials/data/design/human-interface-guidelines/{topic}.json`.
Không lưu bản sao toàn văn Apple vào repository.
