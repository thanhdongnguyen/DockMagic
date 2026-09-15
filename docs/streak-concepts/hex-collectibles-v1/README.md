# Hex Collectibles v1 — nghiên cứu và thiết kế badge

Ngày: 2026-09-09. Phạm vi: toàn bộ 10 mốc streak hiện có của DockMagic.
Đây là bộ thiết kế để duyệt, không phải thay đổi production.

## Kết quả và điểm còn mở

- Đủ 10 thiết kế riêng, mỗi ảnh 1254 × 1254. Xem [cả bộ](collection-review.png).
- Cả 10 ảnh đã có nền trong suốt thật, kiểm tra alpha ở cả bốn góc.
- 6 ảnh được tách nền bằng ImageGen: First Prompt, Spark, Builder, Flow,
  Century, Architect.
- Với Loop, Navigator, Keystone, Continuum, hai lượt tách nền bằng ImageGen
  vẫn giữ ô caro. Người dùng đã cho phép xóa nền cục bộ ngày 2026-09-09.
  Script `remove-checker-background.swift` chỉ xóa vùng xám liên thông với
  mép canvas; không đổi các pixel RGBA được giữ lại bên trong huy hiệu.
  [Báo cáo kiểm tra](local-cutout-checks.json) ghi nhận 0 pixel được giữ lại bị đổi.
  Bản gốc trước tách nền vẫn ở `references/opaque-originals/`.
- [Kiểm tra 1×](size-review-1x.png), [kiểm tra 2×](size-review-2x.png) và
  [kết quả alpha/kích thước](asset-checks.json) được tạo bằng AppKit.
  Script chỉ dàn ảnh để đối chiếu, không sửa pixel của tệp badge gốc.
- Đã xem lại bản 1× sau khi xóa nền: vật thể trung tâm giữ được khác biệt ở
  48/58 pt và thang xám. Mép bốn ảnh xử lý cục bộ không còn nền ô caro trên
  các mẫu nền sáng/tối.
  Các sao/phản sáng nhỏ là chi tiết thứ cấp; không dùng chúng làm dấu hiệu trạng thái.
- Bản 2× đã được xuất, chưa thay thế kiểm thử trực tiếp trên màn hình Retina.
- Một số lượt tách nền làm thay đổi khoảng trống ngoài huy hiệu; cần chuẩn hóa
  optical bounds khi chuẩn bị asset production. Các nét tô bóng raster còn chuyển
  sắc nhẹ; bản vector nếu làm tiếp nên rút gọn thành các mảng màu phẳng.
- Chưa kiểm thử SwiftUI, Increased Contrast, Reduce Transparency, VoiceOver hoặc
  locked state của bộ mới. Không có app build/release trong lượt thiết kế này.

## Hướng đã chọn

Ảnh người dùng cung cấp là nguồn định hướng chính:
[ảnh tham chiếu](references/user-style.png). Ảnh được dùng làm tham chiếu phong cách,
không sao chép nguyên biểu tượng, nội dung thẻ, tên huy hiệu hay hệ EXP của nguồn.

Phân tích trực quan:
- Khung lục giác bo nhẹ và viền vát nhiều mặt tạo một họ huy hiệu dễ nhận ra.
- Một vật thể chính ở giữa giúp mỗi thành tích có câu chuyện riêng.
- Mảng màu phẳng, nét đậm, highlight nhỏ tạo chiều sâu 2.5D mà không cần glow.
- Màu nằm trong huy hiệu; nền thẻ và chữ giữ trung tính.
- Sao nhỏ tạo cảm giác cấp bậc, nhưng hình trung tâm phải đủ khác nhau khi bỏ màu.

Khác với bộ Interlock Crown đang dùng, hướng mới thay cấu trúc đan trừu tượng
bằng vật thể minh họa cụ thể, thân thiện hơn. Không thay logo của Codex, Claude
Code hoặc Antigravity; badge tiếp tục trung lập với nhà cung cấp.

## Cơ sở thiết kế

- [Apple HIG — Icons](https://developer.apple.com/design/human-interface-guidelines/icons):
  ưu tiên hình đơn giản, nhận ra ở nhiều kích thước và cân bằng trọng lượng thị giác.
  Áp dụng ở đây như nguyên tắc về khả năng nhận diện, không coi huy hiệu là app icon.
- [W3C — Use of Color](https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html):
  không dùng khác biệt màu làm phương tiện duy nhất truyền đạt thông tin.
  Mỗi mốc có vật thể riêng; tên/ngày/trạng thái khóa vẫn do UI cung cấp.
- [W3C — Non-text Contrast](https://www.w3.org/WAI/WCAG21/understanding/non-text-contrast.html):
  đối chiếu biên và phần đồ họa cần thiết để hiểu nội dung. Kiểm tra bitmap không
  thay thế đánh giá tương phản và trợ năng của giao diện tích hợp.
- Hợp đồng dự án: [màu](../../COLOR_DESIGN_SYSTEM.md), [component](../../DESIGN_SYSTEM.md).
  Màu đa sắc là nội dung bên trong silhouette badge, không phải palette mới cho UI.

## Hệ hình ảnh

Một khung point-up hexagon, nền navy, viền hai lớp, góc bo nhẹ. Không glow,
không gradient trang trí, không chi tiết li ti, không số ngày/chữ tên dính vào ảnh.
Khung phân nhóm theo tiến trình: xanh lam ở 1–7 ngày, tím ở 14–60 ngày,
vàng ở 100–365 ngày, platinum ở 730 ngày. Các màu này không đổi bất kỳ token UI nào.

Sao 0/1/2/3 là trang trí theo nhóm tiến trình, không phải điểm số hoặc điều kiện
mở khóa mới. Mốc thật vẫn lấy nguyên từ `TokenUsageStreakMilestone`.
Trạng thái locked không được suy ra từ màu khung hoặc số sao.

| Ngày | Tên hiển thị | Biểu tượng | Asset dự kiến |
| ---: | --- | --- | --- |
| 1 | First Prompt | Bong bóng prompt và tia khởi đầu | [PNG](assets/01-first-prompt.png) |
| 3 | Spark | Tia sáng | [PNG](assets/03-spark.png) |
| 7 | Loop | Hai mũi tên tuần hoàn | [PNG](assets/07-loop.png) |
| 14 | Builder | Ba khối xây dựng | [PNG](assets/14-builder.png) |
| 30 | Flow | Dải sóng chuyển động | [PNG](assets/30-flow.png) |
| 60 | Navigator | La bàn | [PNG](assets/60-navigator.png) |
| 100 | Century | Cúp | [PNG](assets/100-century.png) |
| 180 | Architect | Tháp kiến trúc | [PNG](assets/180-architect.png) |
| 365 | Keystone | Vòm đá và viên khóa đỉnh | [PNG](assets/365-keystone.png) |
| 730 | Continuum | Dải vô cực | [PNG](assets/730-continuum.png) |

Lưu ý: tên hiển thị của mốc 365 ngày là **Keystone**; khóa nội bộ vẫn là
`codexCore`, asset production vẫn tên `StreakBadgeCodexCore`. Không đổi định danh.

## Cách tạo và tệp bàn giao

- Built-in ImageGen, chế độ `stylized-concept`, một lần gọi riêng cho từng badge.
- Builder được dựng trước làm mẫu chuẩn. Các badge còn lại nhận cả ảnh người dùng
  và Builder làm tham chiếu để giữ khung, nét, tỷ lệ, cách tô bóng nhất quán.
- Prompt yêu cầu PNG 1024 × 1024; công cụ trả về bản 1254 × 1254. Giữ nguyên
  độ phân giải ảnh trả về, không phóng hoặc ép về kích thước đã yêu cầu.
- Bản tạo đầu chứa nền ô caro giả. Các lượt chỉnh sửa nền dùng chính ImageGen;
  kết quả alpha từng tệp được ghi riêng trong `asset-checks.json`.
- [Bộ prompt](prompts.md) ghi đầy đủ ràng buộc chung, directive từng mốc và đầu vào.
- [Manifest](manifest.json) ánh xạ ngày, tên hiển thị và tên asset production.
- Chưa ghi đè bất kỳ PNG nào trong `Assets.xcassets`, chưa sửa SwiftUI, logic streak
  hoặc preview SVG cũ.

## Ranh giới raster / SVG

ImageGen tạo bitmap, không tạo SVG vector thật. Bộ này là nguồn thiết kế raster:
các mảng lớn và nét gọn hỗ trợ việc dựng vector sau khi duyệt, nhưng đổi đuôi tệp
hoặc bọc PNG trong SVG không làm ảnh scale vô hạn.

Trước khi dùng production: duyệt đủ bộ; kiểm tra riêng 48/58/112/185 pt ở 1×/2×;
so Light, Dark, Increased Contrast, Reduce Transparency và grayscale/locked;
kiểm tra VoiceOver, lock overlay, màu selection và nội dung streak không đổi.
