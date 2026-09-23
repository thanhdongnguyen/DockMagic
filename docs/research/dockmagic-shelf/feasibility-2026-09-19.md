# DockMagic Shelf — cổng kiểm chứng vị trí

> **Phạm vi đã bị thay thế:** Probe này chỉ thử panel nằm cạnh Dock. Yêu cầu
> hiện tại là từng feature nằm trong Apple Dock và vẽ bằng UI Dock tile hiện có;
> probe không chứng minh tính khả thi của yêu cầu đó. Xem
> [review kỹ thuật](review-2026-09-20.md).

**Ngày thử:** 2026-09-19  
**Môi trường:** macOS 26.2, hai màn hình (1920 × 1080 và 1512 × 982 pt), Dock có 25 mục, Accessibility đã được cấp cho bản Debug của DockMagic.  
**Trạng thái cập nhật 2026-09-20:** Qua cổng A trên macOS 26.2 ở các cấu hình đã thử; Shelf production đã được triển khai. Đây là kết quả khả thi trên một máy, chưa phải chứng nhận cho mọi phiên bản macOS. Xem [báo cáo nghiệm thu](acceptance-2026-09-20.md).

## Cách thử

Bản Debug dựng một `NSPanel` 110 × 56 pt cho Dock dưới (56 × 110 pt cho Dock dọc), đọc cây Accessibility của tiến trình Dock bằng `AXUIElement`, lấy frame của `AXList` chứa `AXApplicationDockItem`, đổi hệ tọa độ bằng `DockHoverScreenGeometry`, rồi thử đặt panel cách Dock 8 pt trong cùng hàng hoặc cột. Mẫu được lấy mỗi 0,5 giây. Chỉ dùng API công khai. Panel thử nghiệm không chứa dữ liệu feature.

Probe chỉ biên dịch trong Debug và chỉ chạy khi môi trường của tiến trình có `DOCKMAGIC_SHELF_PROBE=1`; bản Release và lần khởi động Debug thông thường không hiển thị panel hoặc lấy mẫu Dock.

## Quan sát

| Cấu hình | Dock AX list | Kết quả |
| --- | --- | --- |
| Dock dưới, tự ẩn tắt | x=407, y=10, rộng=1106, cao=58 pt trên màn hình 1920 × 1080 | Còn 407 pt bên trái; panel 110 pt đặt cùng hàng, cách Dock 8 pt. |
| Dock trái, tự ẩn tắt | x=-1502, y=28, rộng=49, cao=893 pt trên màn hình phụ 1512 × 982 | Phần trống đầu/cuối cột khoảng 28/61 pt; không đủ cho panel thử 56 pt cộng khoảng cách. |
| Dock phải, tự ẩn tắt | x=1857, y=32, rộng=53, cao=986 pt trên màn hình chính 1920 × 1080 | Phần trống đầu/cuối cột khoảng 32/62 pt; không đủ cho panel thử 56 pt cộng khoảng cách. |
| Dock dưới, tự ẩn bật và đang ẩn | Không tìm thấy AX list có app item | Panel được ẩn theo Dock. Chưa xác nhận Dock hiện lại khi chạm mép màn hình thì AX list và panel cùng hiện. |

Các kích thước trên chỉ là mẫu ở một máy và một cấu hình. Với Dock dọc dài, hành vi đúng theo kế hoạch là **ẩn Shelf** và giải thích rằng không đủ chỗ, không đặt nó phía trên hay chồng lên Dock.

## Kiểm chứng sau probe

XCUITest đã điều khiển con trỏ vật lý để xác nhận chu kỳ Dock tự ẩn → hiện → ẩn và Shelf production đi theo. Khi Dock dưới, Shelf nằm cùng hàng ở phía còn chỗ, cách vùng icon Dock; khi Dock dọc đang dài, Shelf ẩn và Settings báo thiếu chỗ. Thử Dock nhỏ và magnification trên cùng máy, cộng với unit test hình học cho hai cạnh Dock và tọa độ màn hình phụ. Panel Shelf và dashboard cũng đã được nhìn trong Light/Dark và các chế độ trợ năng ở [báo cáo nghiệm thu](acceptance-2026-09-20.md).

## Điều kiện còn thiếu trước phát hành

- Chạy kiểm thử trên macOS 14 và 15; cây Accessibility của Dock không có hợp đồng cấu trúc ổn định giữa các bản OS.
- Xác minh trực tiếp khi chuyển Spaces, Stage Manager, full-screen, Dock restart và khi Dock chuyển qua màn hình phụ. Unit test màn hình phụ chỉ chứng minh phép đổi tọa độ.
- Đo CPU, bộ nhớ, tần suất provider và xác nhận bản Developer ID đã notarize trên máy sạch. Các phép thử Debug/Release chưa ký không thay thế được bước này.

[`NSScreen.visibleFrame`](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe) không đủ để suy ra hình học Dock: Apple ghi rõ nó có thể nhỏ hơn toàn màn hình ngay cả khi Dock tự ẩn. [`AXUIElement`](https://developer.apple.com/documentation/applicationservices/axuielement_h) cho phép đọc cây Accessibility nhưng không bảo đảm cấu trúc AX riêng của Dock. Vì vậy, phụ thuộc vào AX list phải được kiểm chứng trên các phiên bản macOS mục tiêu trước khi phát hành.
