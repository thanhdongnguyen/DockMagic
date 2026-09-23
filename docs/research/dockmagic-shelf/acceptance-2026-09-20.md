# DockMagic Shelf — nghiệm thu triển khai

> **Không còn là nghiệm thu của yêu cầu Shelf.** Ngày 2026-09-20, người dùng
> làm rõ Shelf phải là nhóm các Dock tile thực sự trong Apple Dock, mỗi feature
> dùng đúng UI Dock tile hiện có. Các phép thử dưới đây chỉ xác nhận một panel
> riêng đặt cạnh Dock, tức là phương án sai. Không dùng kết luận "đạt" của tài
> liệu này để quyết định phát hành Shelf. Xem [review kỹ thuật](review-2026-09-20.md).

**Ngày:** 2026-09-20  
**Máy thử:** MacBook Pro, macOS 26.2 (25C56), hai màn hình; DockMagic Debug với Accessibility đã được cấp.  
**Kết luận:** Bản triển khai hoạt động trên cấu hình đã thử, nhưng **chưa đạt điều kiện phát hành** của kế hoạch vì thiếu xác minh đa phiên bản macOS, một số trạng thái desktop và bản Developer ID đã notarize.

## Phạm vi đã triển khai

- Shelf là `NSPanel` riêng theo Dock, chứa SwiftUI Maia nền opaque; không thay đổi `NSDockTile` hoặc dùng private Dock API. Mặc định tắt, danh sách rỗng. Trạng thái bật, thứ tự, vị trí tay nắm và tùy chọn ẩn giá trị được lưu riêng với feature của Dock tile.
- Đọc `AXList` và bounds của các Dock item qua Accessibility, quy đổi sang tọa độ AppKit; bố trí cùng hàng/cột, ưu tiên vùng trước Dock và dùng vùng sau nếu thích hợp. Dải 56 pt, control ít nhất 36 pt; thu gọn thành icon, rồi overflow. Khi không đủ chỗ cho tay nắm, `+` và overflow, Shelf ẩn và Settings nêu lý do.
- Picker dùng `DSSelectList` có tìm kiếm, chỉ đưa feature trong `DockFeature.availableCases` có dashboard, bỏ DockMagic và mục đã chọn. Settings hỗ trợ thêm, đổi thứ tự, xóa và ẩn giá trị nhạy cảm.
- Hover feature khoảng 400 ms hoặc click mở dashboard của chính feature; chỉ một dashboard, khoảng đệm con trỏ 350 ms, Escape/click ngoài để đóng. Dock icon giữ hover 1 giây và click mở Settings. Now Playing có Play/Pause, Next khi ô đủ rộng; quick controls không mở dashboard.
- Nhu cầu dữ liệu của Shelf được gộp với Dock tile và dashboard; khi Shelf ẩn thì bỏ interest Shelf. Quyền Accessibility chỉ được nhắc sau khi người dùng bật Shelf; thiếu hoặc mất quyền thì Shelf ẩn.

## Bằng chứng chạy trên máy thử

| Hạng mục | Kết quả |
| --- | --- |
| Dock dưới, khoảng trống trái/phải, Dock dài/ngắn | UI test và ảnh desktop: Shelf cùng hàng, không đè Dock; Settings báo thiếu chỗ khi cần. Unit test kiểm tra khoảng cách với Dock, overflow và trường hợp chỉ còn control. |
| Dock trái/phải | Đã chuyển Dock thật sang hai cạnh: với Dock dài Shelf ẩn và nêu lý do. Unit test xác nhận bố cục dọc khi đủ chỗ. Bố cục dọc trên Dock ngắn chưa được chụp runtime. |
| Dock tự ẩn | XCUITest di chuyển con trỏ đến mép: Shelf hiện, ẩn rồi hiện theo Dock; đã khôi phục auto-hide về tắt. |
| Magnification | Đã thử với magnification 0.5 và kiểm tra Shelf/dashboard không va icon; đã khôi phục về 0. |
| Thêm, tìm kiếm, mở dashboard | `testShelfPickerAddsDashboardWithoutChangingDockFeature` qua trong Dark và khi Reduce Motion bật; click/hover mở Weather, Escape đóng, dashboard không đè Shelf, bộ chọn Active Dock feature vẫn là CPU & RAM. |
| Settings và Now Playing | `testShelfSettingsReorderHideValuesAndRemoveFeature`, `testShelfNowPlayingQuickControlsKeepDashboardClosed`, `testShelfHandleMovesWithinFreeDockSegment` qua. |
| Light/Dark và trợ năng hình ảnh | UI test Light và Dark qua; đã chạy Light khi Increased Contrast, Reduce Transparency và grayscale bật. Reduce Motion UI test qua. Mọi thiết lập macOS thay đổi tạm thời đã trả về trạng thái ban đầu. |
| Hồi quy Dock | `DockHoverDelayTests` (5 test), kiểm thử permission và `UI-017` qua. |
| Build | Debug UI/unit tests và Release build `CODE_SIGNING_ALLOWED=NO` thành công. Release còn cảnh báo Swift concurrency hiện có ở các phần khác của dự án. `git diff --check` qua. |

`@google/design.md@0.4.0 lint` đã chạy bằng đúng gói 0.4.0 lấy từ npm cache vì môi trường không phân giải được `registry.npmjs.org`: **0 lỗi, 20 cảnh báo orphaned color tokens** thuộc contract hiện có và không phát sinh từ Shelf. Kiểm tra dự phòng cũng đã parse YAML, xác nhận đủ tám phần của Design.md và các tham chiếu token đều tồn tại.

Ảnh chụp desktop được giữ trong attachment của các `.xcresult` tương ứng. Không đưa ảnh desktop vào repository vì có thể chứa nội dung cá nhân.

## Chưa được chứng minh

- **macOS 14/15 và Developer ID notarized:** Máy hiện tại chỉ chạy macOS 26.2; Release build chưa ký không chứng minh quyền Accessibility hay vị trí Dock của bản phân phối. Phải chạy bản Developer ID có Hardened Runtime, notarize/staple trên máy sạch trước phát hành.
- **Desktop states:** Chưa chạy thực tế chuyển Spaces, Stage Manager, full-screen, Dock restart hoặc chuyển Dock sang màn hình phụ. Code dùng `canJoinAllSpaces`/`fullScreenAuxiliary` và tính toán tọa độ màn hình phụ, nhưng đây chưa phải bằng chứng runtime.
- **Accessibility hoàn chỉnh:** Click, keyboard path cơ bản và AX tree đã được kiểm tra; chưa có vòng kiểm thử VoiceOver và Full Keyboard Access thủ công trên mọi control, đặc biệt menu overflow và panel dashboard.
- **Hiệu năng:** Chưa đo CPU/bộ nhớ và tần suất cập nhật provider giữa Shelf tắt/ẩn/hiện trên bản ký. Các store đã dùng interest riêng, nhưng cần số đo trước phát hành.
- **Dữ liệu biên:** Chưa thực hiện ma trận runtime cho mọi provider ở trạng thái loading, stale, lỗi, chưa cấu hình và mất mạng; dashboard hiện có dùng lại presentation của từng feature.
- **Khả năng tương thích Dock AX:** macOS không cam kết cấu trúc cây Accessibility của Dock; mỗi bản OS mục tiêu phải kiểm chứng lại. Khi đọc bounds/permission thất bại, Shelf ẩn an toàn và Settings báo trạng thái.

## Tiêu chí chốt phát hành

Giữ feature sau cờ bật mặc định tắt. Chỉ chốt phát hành khi ma trận còn thiếu ở trên qua trên macOS 14, 15, 26 và bản Developer ID đã notarize. Nếu ở một cấu hình Dock Shelf không thể duy trì cùng hàng/cột hoặc tự ẩn cùng Dock bằng API công khai, giữ Shelf ẩn ở cấu hình đó và không đánh dấu tính năng đạt nghiệm thu phát hành.
