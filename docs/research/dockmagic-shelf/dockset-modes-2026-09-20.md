# Dock Active / Shelf — nghiên cứu kỹ thuật trước khi triển khai

**Ngày:** 2026-09-20  
**Trạng thái:** Nghiên cứu và brief thiết kế; chưa thay runtime UI.  
**Quyết định sản phẩm của người dùng:** Dock Active và Shelf là hai mode loại trừ; Shelf giống cách Dockset cung cấp Custom Dock. Một feature có thể xuất hiện nhiều lần.

## Ranh giới sản phẩm

Dockset phân biệt **Apple Dock** với **Custom Dock của Dockset**. Widget chỉ sống trong Custom Dock; chế độ `Both` dùng hai bề mặt, còn chế độ `Custom Dock + auto-hide macOS Dock` đặt Custom Dock làm bề mặt chính nhưng Apple Dock vẫn có thể hiện ra. [Trang sản phẩm](https://dockset.app/), [chọn setup](https://dockset.app/manual/choose-your-dock-setup), [hướng dẫn Custom Dock](https://dockset.app/manual/use-custom-docks).

Shelf của DockMagic vì thế sẽ là **Custom Dock do ứng dụng vẽ** ở cạnh màn hình, có thể cùng hàng/cột và được cảm nhận như một segment của Dock. Không gọi nó là subview do Apple Dock sở hữu. `NSDockTile` chỉ cung cấp tile cho một app hoặc cửa sổ thu nhỏ; API công khai không mô tả thao tác nhúng một segment nhiều hit target vào nền Dock. Đây là suy luận từ phạm vi [NSDockTile](https://developer.apple.com/documentation/appkit/nsdocktile), chưa phải kết quả thử nghiệm placement mới.

## Hợp đồng UI của hai mode

| Nội dung | Dock Active | Shelf |
| --- | --- | --- |
| Bề mặt | Icon DockMagic trong Apple Dock | Một segment Custom Dock của DockMagic ở cạnh màn hình |
| Nội dung | Một `activeFeature` | Dãy slot có ID riêng, mỗi slot chứa một `DockFeature`; cho phép lặp |
| Hình feature | `DockTilePresentation` → `DockTileView` → `DockApplicationIconRenderer` | Cùng pipeline và appearance của feature ở Dock Active, được cache theo snapshot/appearance; từng ô vuông có hit target riêng |
| Thêm | Chọn một active feature trong Settings | Ô cuối là `+` vuông, bo góc, viền nét đứt; chọn feature xong ô đó được thay bằng UI tile và `+` xuất hiện ở vị trí kế tiếp |
| Hover | Giữ `UI-015`: 1 giây rồi mở dashboard nếu có | Khoảng 400 ms hoặc click ô; gắn vị trí popup với **slot ID**, chỉ một dashboard mở; slot trùng feature vẫn là hai target độc lập |
| Quản lý | Settings hiện hành | Picker tìm kiếm, sắp xếp/xóa từng **bản sao** bằng ID; `+` và cửa sổ Settings là đường quay lại khi icon DockMagic ẩn |

Bản đầu giữ điều kiện `DockFeature.availableCases` và `hasHoverDashboard` của kế hoạch Shelf đã chốt; không tạo dashboard mới. Now Playing trong slot dùng đúng hình tile hiện hành; điều khiển playback nằm trong dashboard, không ghép UI phụ vào cạnh tile rồi gọi là parity. Chế độ ẩn giá trị nhạy cảm, nếu giữ lại, phải được thiết kế là một biến thể render rõ ràng thay vì thay tile bằng nhãn text.

## Khả thi bằng mã hiện có

- `DockTileView(presentation:)` là nguồn hình; `DockApplicationIconRenderer` dùng `ImageRenderer` trên canvas 512 pt, raster 2× và `contentFraction` dùng chung. Đưa `DockAppModel.dockPresentation` từ `switch preferences.activeFeature` thành `presentation(for feature:)` cho cả hai mode, không thay đổi setting active khi thêm Shelf.
- `DockShelfConfiguration.orderedFeatures: [DockFeature]` hiện dùng `Set` để bỏ trùng; picker cũng loại feature đã chọn. Thay bằng `slots: [ShelfSlot]`, mỗi `ShelfSlot` có `id: UUID` và `feature`. Add luôn tạo ID mới; move/remove/hover/dashboard/accessibility dùng ID. Cùng loại feature có thể chia sẻ snapshot và ảnh render nhưng không chia sẻ danh tính UI.
- `DockAppModel` đang gộp một phần nhu cầu dữ liệu Shelf bằng `Set<DockFeature>`, nhưng nhiều store chỉ chạy theo `activeFeature`. Tính `Set` feature của các slot **đang hiển thị**, gộp với Dock Active/dashboard để start/stop từng store; duplicate không tăng polling. Cập nhật `Weather`, `Clock`, `Batteries`, `GitHub` và những nhánh hiện còn phụ thuộc activeFeature.
- `DockHoverDashboardRoot(appModel:feature:)` đã nhận feature độc lập; coordinator mới cần anchor theo slot ID. UI cũ dùng `firstIndex(of: feature)`, `openFeature` và `pointedFeature` theo feature nên sẽ nhầm hai bản sao cùng loại.
- `DockShelfCoordinator` hiện dùng AX đọc Dock để đặt panel **bên cạnh** và `DockShelfView` tự vẽ `DSIcon` + tóm tắt. Có thể tham khảo phép đổi tọa độ và quan sát Dock, nhưng phải thay layout, presentation, trạng thái, picker và bằng chứng QA. `DockShelfPlacementEngine` không chứng minh một Custom Dock segment cảm nhận như nằm trong Dock.

## Cửa sổ, Dock và quyền

Ứng viên là một `NSPanel` borderless, nonactivating, host SwiftUI và bề mặt opaque theo Maia. AppKit hỗ trợ [nonactivating panel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) và [collectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct), nhưng tổ hợp Space/Stage Manager/full-screen cần thử trên máy thật. [NSScreen.frame](https://developer.apple.com/documentation/appkit/nsscreen/frame) bao gồm vùng Dock; [visibleFrame](https://developer.apple.com/documentation/appkit/nsscreen/visibleframe) loại vùng Dock và có thể vẫn chừa dải khi auto-hide, nên không đủ một mình để suy ra bounds/trạng thái Dock. Đọc AX của Dock chỉ sau khi người dùng chọn mode cần bám Dock và cấp quyền; [API kiểm tra quyền](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) hỗ trợ kiểm tra không bật prompt trước.

Trong Shelf mode, ẩn icon DockMagic gốc bằng `NSApplication.setActivationPolicy(.accessory)` là **ứng viên cần thử**, không phải kết luận. Policy `regular` hiện icon, `accessory` không hiện icon nhưng vẫn có thể mở UI từ cửa sổ; thay đổi policy có thể thất bại và làm mất đường mở Settings nếu không chuẩn bị fallback. [Activation policy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum), [setActivationPolicy](https://developer.apple.com/documentation/appkit/nsapplication/setactivationpolicy%28_%3A%29). Prototype phải có đường mở Settings ổn định qua `+`/menu của segment, và phục hồi Dock icon khi quay lại Dock Active.

Không dùng `NSWindow.Level.dock` để giả vờ là Apple Dock: [Apple đánh dấu deprecated và không có replacement](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct/dock). Cần thử cùng cạnh với Dock trong khoảng trống thật; nếu Dock phủ kín cạnh, thử UX Custom Dock chính với **người dùng chủ động** bật auto-hide cho Apple Dock. Không âm thầm thay đổi cài đặt Dock của macOS. Nếu không thể giữ phân tách hit target, focus và auto-hide ổn định, chưa đưa mode Shelf vào production.

## Gate kỹ thuật trước khi viết UI production

1. **Placement spike:** một panel segment rỗng, một `+`, cùng cạnh Apple Dock; thử bottom/left/right, Dock dài/ngắn, magnification, auto-hide, multi-display, Spaces, Stage Manager, full-screen, Dock restart, sleep/wake. Ghi frame và video thực tế, xác nhận không che/chặn icon Apple Dock.
2. **Mode spike:** chuyển `regular ↔ accessory` khi Settings đang mở/đóng, khi Dock restart, khi app launch-at-login và sau crash; luôn có đường mở Settings. Test Developer ID app sau ký và notarize; đừng giả định kết quả của debug build.
3. **Parity spike:** hai slot CPU & RAM giống nhau, một slot Weather và `+`; so ảnh pixel với Dock Active cùng snapshot, appearance và 32/48/64/128 pt. Hover hai slot trùng phải anchor đúng ô, remove một bản sao không xóa bản còn lại, data polling không nhân đôi.
4. **UX/QA gate:** focus, VoiceOver, bàn phím, picker thêm lặp, reorder, overflow, loading/stale/error, CPU/bộ nhớ khi Shelf tắt/bật; Light, Dark, Increased Contrast, Reduce Transparency, grayscale, Reduce Motion trên macOS 14/15/26. Giữ `UI-009`, `UI-015`, `UI-017`.

## Brief thiết kế ở lượt này

Giữ Maia: Geist, HugeIcons cho controls, neutral-first, nền app-owned opaque; màu dữ liệu chỉ bên trong tile renderer và dashboard. Thiết kế ba biến thể để đánh giá **segment Custom Dock**: (1) dải dưới cùng và dashboard, (2) Settings chọn mode/picker, (3) cột ở cạnh phải. Trong mọi biến thể, mỗi feature là ô vuông có hình **Dock tile thực**, `+` vuông bo góc viền nét đứt luôn ở cuối; không vẽ lại thành nhãn/ring ngang. Các hình là đề xuất, chưa chứng minh placement runtime.

### Hình phác thảo

1. [Segment cùng hàng với Dock, dashboard hover](shelf-mode-segment-concept.png).
2. [Settings chọn mode, preview và picker `+`](shelf-mode-settings-concept.png).
3. [Bố cục khi Apple Dock ở cạnh phải](shelf-mode-side-concept.png).

Các ảnh do công cụ tạo để thảo luận bố cục, không phải pixel reference hay ảnh chụp ứng dụng. Chúng có thể vẽ sai chi tiết macOS/feature (ví dụ nội dung popup, ngày trên menu bar); hợp đồng nguồn vẫn là `DockTileView` và UI thực phải được đối chiếu bằng ảnh runtime. Bản cạnh phải chỉ khảo sát khả năng đổi trục, không xác nhận z-order hay dashboard.
