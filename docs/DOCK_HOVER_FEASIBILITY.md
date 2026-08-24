# Nghiên cứu khả thi: hiển thị chart/UI khi hover DockMagic trên Dock

**Ngày đánh giá:** 2026-08-25

**Phạm vi:** macOS 14 trở lên, bao gồm môi trường kiểm tra hiện tại macOS 26.2/Xcode 26.2; DockMagic phát hành trực tiếp bằng Developer ID, không qua Mac App Store.

> Báo cáo chuyên sâu về permission state machine, TCC, Dock observer recovery và mapping UI cho từng active feature: [DOCK_HOVER_ACCESSIBILITY_RESEARCH.md](DOCK_HOVER_ACCESSIBILITY_RESEARCH.md).

## Kết luận trực tiếp

Tính năng **khả thi có điều kiện** nếu sản phẩm chấp nhận cách triển khai sau:

1. DockMagic phát hiện người dùng đang hover đúng icon của mình thông qua Accessibility API.
2. DockMagic mở một `NSPanel` riêng, không kích hoạt app, neo theo vị trí icon trên Dock.
3. Panel chứa chart và SwiftUI tùy ý, dùng dữ liệu hiện có của `DockAppModel`.

Technical spike hiện tại đã vượt qua phép thử end-to-end trên macOS 26.2:
Accessibility được bật cho đúng Release, Dock phát selected-child event với
bundle `com.hypevibe.DockMagic`, frame icon được đọc thành công và panel được
present. Điều kiện còn lại trước khi ship là regression matrix đa phiên bản và
bản Developer ID/notarized, không còn là câu hỏi về khả thi cơ bản.

Tính năng **không khả thi bằng public API** nếu yêu cầu chính xác là thay nội dung tooltip native do Dock vẽ — tức biến chính bong bóng chữ “DockMagic” thành một SwiftUI view/chart thực sự. `NSDockTile` chỉ cho phép đổi hình ảnh/nội dung bên trong tile, badge và yêu cầu redraw; API không có callback hover, thuộc tính tooltip, hoặc view tùy biến cho label. [Tài liệu `NSDockTile` của Apple](https://developer.apple.com/documentation/appkit/nsdocktile) liệt kê đầy đủ các điểm tùy biến công khai này.

Vì vậy, quyết định sản phẩm nên được diễn đạt là:

> Hiển thị một hover dashboard của DockMagic được neo vào icon trên Dock, thay vì cố sửa tooltip thuộc sở hữu của tiến trình Dock.

Độ tin cậy của kết luận:

- **Cao:** Không có public API để nhúng UI tùy ý vào tooltip native của Dock.
- **Trung bình-cao:** Có thể tạo trải nghiệm hover dashboard bằng Accessibility + `NSPanel`.
- **Trung bình:** Có thể làm người dùng cảm nhận panel như “thay thế” label; không thể đảm bảo label native biến mất hoàn toàn trên mọi phiên bản macOS.

## DockMagic hiện đang làm gì

`DockTileController` đặt `NSDockTile.contentView = nil`, render một `NSImage` độ phân giải cao, gán nó vào `NSApplication.applicationIconImage`, rồi gọi `dockTile.display()`. Đây là cách đúng để cập nhật pixel của icon, nhưng không tạo ra một view tương tác nằm trong Dock: [DockTileController.swift](../DockMagic/DockMagic/Services/DockTileController.swift).

`AppDelegate` chạy app với activation policy `.regular`, giữ app sống sau khi đóng Settings và cập nhật Dock presentation từ `DockAppModel`: [DockMagicApp.swift](../DockMagic/DockMagic/App/DockMagicApp.swift).

`DockAppModel` hiện chỉ chạy provider của feature đang active. Điều này phù hợp nếu hover card hiển thị chi tiết của feature đang được chọn. Nếu hover card cần một dashboard chứa đồng thời CPU, network, storage, weather, GitHub…, vòng đời sampler phải được thiết kế lại để tránh tăng CPU, I/O, network và quyền riêng tư: [DockAppModel.swift](../DockMagic/DockMagic/Stores/DockAppModel.swift).

## Vì sao không thể sửa tooltip native

### 1. `NSDockTile` không có bề mặt hover

Theo Apple, `NSDockTile` cho phép:

- tự vẽ nội dung tile bằng `contentView`;
- đọc kích thước tile;
- đặt badge;
- gọi `display()` để redraw.

Không có API nhận `mouseEntered`/`mouseExited` cho icon Dock, không có thuộc tính thay tooltip bằng view, và cũng không có API lấy frame của application tile trên màn hình. `contentView` là nguồn vẽ cho backing store của Dock, không phải một cửa sổ của app nhận event chuột. Xem [Apple — NSDockTile](https://developer.apple.com/documentation/appkit/nsdocktile).

### 2. Dock menu không phải hover UI

`applicationDockMenu(_:)` chỉ trả về `NSMenu` hiển thị khi người dùng mở Dock menu, thường bằng secondary click. Nó không được gọi khi hover và Dock menu item cũng không phải chỗ chứa arbitrary SwiftUI UI. Xem [Apple — `applicationDockMenu(_:)`](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationdockmenu%28_%3A%29) và [Human Interface Guidelines — Dock menus](https://developer.apple.com/design/human-interface-guidelines/dock-menus).

### 3. Tên app do Dock quản lý

Tài liệu Accessibility cũ của Apple mô tả Dock item có `Title` là chuỗi hiển thị khi con trỏ hover, cùng các thuộc tính `Position`, `Size` và `URL`. Đây là metadata của accessibility object do Dock xuất bản, không phải customization point của `NSDockTile`. Bản lưu trữ: [Accessibility Overview, “Dock Item Role”, trang 42](https://leopard-adc.pepas.com/documentation/Accessibility/Conceptual/AccessibilityMacOSX/AccessibilityMacOSX.pdf).

Đổi `CFBundleName`/`CFBundleDisplayName` thành chuỗi trống không giải quyết được yêu cầu: đó vẫn chỉ là chuỗi, có thể bị hệ thống fallback, và còn làm hỏng tên app ở Finder, menu, Command-Tab, thông báo và accessibility. Apple định nghĩa `CFBundleName` là tên ngắn hiển thị cho người dùng: [Apple — CFBundleName](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlename).

## Phương án khuyến nghị: Accessibility observer + nonactivating panel

### Luồng kỹ thuật

1. Khi người dùng bật “Hover dashboard”, gọi `AXIsProcessTrustedWithOptions` để kiểm tra và, nếu cần, yêu cầu người dùng cấp quyền Accessibility. Apple xác nhận hàm này kiểm tra trạng thái trusted accessibility client và có tùy chọn hiển thị prompt bất đồng bộ: [Apple — `AXIsProcessTrustedWithOptions`](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).
2. Tìm process `com.apple.dock` bằng `NSRunningApplication`.
3. Tạo `AXUIElement` cho process Dock, tìm accessibility list chứa các Dock item.
4. Tạo `AXObserver`, đăng ký `kAXSelectedChildrenChangedNotification`. Apple định nghĩa notification này là sự thay đổi tập con children đang được chọn: [Apple — notification](https://developer.apple.com/documentation/applicationservices/kaxselectedchildrenchangednotification) và [`AXObserverCreate`](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate).
5. Khi selected item thay đổi, đọc URL/title/subrole, resolve bundle và chỉ tiếp tục nếu bundle identifier bằng `com.hypevibe.DockMagic`.
6. Đọc `AXPosition` và `AXSize` của item để có icon rectangle. `AXUIElement` công khai vị trí, kích thước, loại và hành động của accessibility object: [Apple — AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement).
7. Chuyển tọa độ AX (gốc trên-trái) sang AppKit screen coordinates, xác định màn hình và cạnh Dock từ frame, sau đó neo một `NSPanel` phía trên/bên cạnh icon.
8. Panel dùng style `.borderless`, `.fullSizeContentView`, `.nonactivatingPanel`; chứa `NSHostingView` với hover dashboard. Apple mô tả `.nonactivatingPanel` là panel không kích hoạt app sở hữu: [Apple — `nonactivatingPanel`](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel).
9. Khi selected Dock item không còn là DockMagic, lên lịch đóng panel sau một grace period ngắn. Nếu chuột đã đi vào panel, hủy lịch đóng để người dùng có thể tương tác.
10. Khi Dock restart, quyền bị thu hồi, màn hình thay đổi hoặc session wake, hủy observer cũ và đăng ký lại an toàn.

### Kiến trúc đề xuất trong DockMagic

| Thành phần | Trách nhiệm |
| --- | --- |
| `DockHoverPermissionController` | Kiểm tra/trình bày UX cấp Accessibility; không prompt khi launch nếu feature chưa bật |
| `DockHoverObserver` | Theo dõi accessibility tree của `com.apple.dock`, nhận hover state chỉ cho DockMagic |
| `DockItemFrameResolver` | Đọc AX position/size, chuyển hệ tọa độ, xử lý nhiều màn hình và Dock magnification |
| `DockHoverPanelController` | Sở hữu một `NSPanel` dài hạn, show/hide/reposition, không chiếm focus |
| `DockHoverDashboardView` | SwiftUI view cho chart/UI, chỉ render state do model truyền vào |
| `DockHoverPresentation` | Model nhỏ, tách biệt khỏi `DockTilePresentation` hình vuông dành cho icon |

Không nên nhét logic hover vào `DockTileController`; controller hiện có contract rõ ràng là render icon. `AppDelegate` nên sở hữu cả `DockTileController` và `DockHoverPanelController` trong suốt vòng đời process.

### Bằng chứng triển khai thực tế

[DockDoor](https://github.com/ejbills/DockDoor) là một ứng dụng mã nguồn mở đang hiển thị preview khi hover icon Dock. Mã hiện tại của nó:

- tạo AX observer cho process `com.apple.dock`;
- subscribe `kAXSelectedChildrenChangedNotification` trên Dock list;
- đọc selected child, `AXURL`, position và size;
- hiển thị một `NSPanel` non-activating neo theo icon.

Xem [DockObserver.swift](https://github.com/ejbills/DockDoor/blob/main/DockDoor/Utilities/DockObserver.swift) và [SharedPreviewWindowCoordinator.swift](https://github.com/ejbills/DockDoor/blob/main/DockDoor/Views/Hover%20Window/Shared%20Components/SharedPreviewWindowCoordinator.swift). Đây là bằng chứng mạnh rằng UX overlay hoạt động thực tế; nó không biến overlay thành tooltip native.

DockDoor là GPL-3.0 và trong các phần khác còn dùng private API. DockMagic không nên copy mã hoặc lấy toàn bộ app làm bằng chứng về khả năng notarize. Chỉ nên dùng nó như bằng chứng hành vi và tự triển khai clean-room bằng public `ApplicationServices`/AppKit API. Xem [license của DockDoor](https://github.com/ejbills/DockDoor/blob/main/LICENSE).

## Quyền, Developer ID và notarization

DockMagic hiện build với App Sandbox tắt và Hardened Runtime bật. Đây là cấu hình phù hợp với phân phối trực tiếp. Apple nêu rằng app notarized ngoài Mac App Store bắt buộc Hardened Runtime, còn App Sandbox là tùy chọn: [Apple — Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) và [Apple — Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

Đối với Accessibility client trên macOS:

- quyền được người dùng kiểm soát tại **System Settings → Privacy & Security → Accessibility**;
- không có entitlement `com.apple.security.accessibility` cần thêm;
- app sandboxed không phù hợp với cách dùng AX cross-process này.

Apple DTS ghi rõ các điểm trên trong [Commonly Hallucinated Entitlements](https://developer.apple.com/forums/topics/code-signing-topic/code-signing-topic-entitlements). Cấu hình direct distribution, non-sandboxed hiện tại của DockMagic tránh được xung đột này.

Tính năng chỉ đọc hover state/frame của Dock và vẽ chart từ dữ liệu DockMagic đã có, nên **không cần Screen Recording**. Không nên yêu cầu Input Monitoring hoặc Screen Recording nếu scope không mở rộng sang chụp thumbnail cửa sổ hay chặn event toàn hệ thống.

Về UX quyền:

- để feature tắt mặc định hoặc trình bày rõ lợi ích trước khi prompt;
- chỉ gọi prompt sau một hành động chủ động như bật “Show dashboard on Dock hover”;
- nếu bị từ chối/thu hồi, Dock icon và Settings vẫn hoạt động bình thường;
- không lặp prompt ở mỗi lần launch.

## Native label “DockMagic” sẽ ra sao

Public API không cung cấp cách tắt label cho riêng một Dock item. Có ba lựa chọn sản phẩm:

1. **Khuyến nghị:** Đặt card cao hơn label native, dùng khoảng cách đủ để cả hai không đè nhau. Trải nghiệm vẫn rõ và ổn định nhất.
2. Đặt panel ở window level cao và che vùng label. Cách này chỉ là che hình ảnh, không thật sự tắt label; z-order có thể thay đổi giữa các bản macOS và accessibility vẫn thấy title.
3. Dùng private API/injection để can thiệp tiến trình Dock. Không khuyến nghị: dễ hỏng sau cập nhật, tăng rủi ro bảo mật/notarization, có thể xung đột SIP và đi ngược contract phân phối của dự án.

Nếu tiêu chí bắt buộc là “chữ DockMagic tuyệt đối không được xuất hiện”, kết quả nghiên cứu là **không nên cam kết** với public API. Nếu tiêu chí là “hover sẽ thấy chart/UI của DockMagic”, có thể cam kết sau khi technical spike vượt qua ma trận QA.

## So sánh phương án

| Phương án | Hover thật | UI tùy ý | Quyền | Độ bền | Kết luận |
| --- | ---: | ---: | --- | --- | --- |
| Sửa `NSDockTile`/`contentView` | Không | Chỉ pixel trong icon | Không | Cao | Không đáp ứng |
| Custom Dock menu | Không; secondary click | Hạn chế `NSMenu` | Không | Cao | Fallback tốt, không đúng UX |
| AX observer + `NSPanel` | Có | Có | Accessibility | Trung bình-cao | **Khuyến nghị** |
| Poll mouse + đoán vị trí Dock | Có thể | Có | Có thể không | Thấp | Sai khi magnification/autohide/multi-monitor |
| Private CoreDock/SkyLight/injection | Có | Có | Có thể thêm quyền/rủi ro | Thấp | Loại bỏ |

## Rủi ro và cách giảm thiểu

### Accessibility tree của Dock là dependency hành vi

Các API AX là public, nhưng Apple không cam kết cấu trúc con nội bộ của process Dock như một API sản phẩm cho app tiện ích. Cần cô lập parser trong một module nhỏ, fail closed, log nhẹ và có cơ chế đăng ký lại observer. Changelog của DockDoor từng ghi nhận lỗi preview dưới Dock, preview mở lại ngoài ý muốn và cần reattach sau khi Dock restart; đây là bằng chứng rằng phần integration cần QA liên tục: [DockDoor changelog](https://github.com/ejbills/DockDoor/blob/main/CHANGELOG.md).

### Tọa độ và Dock magnification

AX sử dụng hệ tọa độ gốc trên-trái; AppKit dùng hệ tọa độ màn hình khác. Màn hình phụ có thể có origin âm. Frame icon thay đổi khi Dock magnification chạy. Phải đọc frame tại thời điểm show, clamp card vào đúng screen và có unit test cho conversion.

### Chuyển chuột từ icon sang card

Nếu đóng panel ngay khi DockMagic không còn selected, panel sẽ biến mất trước khi con trỏ tới được card. Cần grace period khoảng 150–250 ms, tracking area trong panel và một vùng “corridor” từ icon tới panel. Card chỉ đọc dữ liệu sẽ đơn giản và ổn định hơn card nhiều nút tương tác.

### Focus và Spaces

Panel không được kích hoạt DockMagic hay làm app hiện tại mất focus. Nên dùng nonactivating panel, `orderFront`/`orderFrontRegardless` thay vì kích hoạt app, và collection behavior phù hợp với Spaces/full-screen. Cần kiểm tra với Stage Manager và app full-screen.

### Dữ liệu dashboard

Nếu card chỉ hiển thị feature đang active, có thể dùng state hiện tại gần như trực tiếp. Nếu card hiển thị nhiều feature cùng lúc, cần một quyết định sản phẩm riêng về tần suất sampler, cache và network request; không nên tự động start mọi store chỉ vì panel đang hover.

## Technical spike đề xuất

Thực hiện spike sau trước khi thiết kế UI hoàn chỉnh:

1. Thêm feature flag nội bộ; chưa bật mặc định.
2. Xin Accessibility chỉ sau khi người dùng bật flag.
3. Quan sát đúng DockMagic item và log enter/exit, bundle URL, position, size.
4. Hiển thị một panel thụ động 320×180 chứa CPU/network chart giả lập hoặc state đang active.
5. Chứng minh panel không chiếm focus và có thể đưa chuột từ icon vào panel mà không flicker.
6. Khi quyền bị thu hồi hoặc Dock restart, feature tắt an toàn và tự phục hồi sau khi quyền/process quay lại.
7. Build Developer ID Release, notarize và staple bản spike để kiểm tra đúng đường phân phối thực tế.

### Ma trận nghiệm thu tối thiểu

- macOS 14, 15 và 26;
- Dock ở bottom/left/right;
- auto-hide bật/tắt;
- magnification bật/tắt và nhiều kích thước Dock;
- một và nhiều màn hình, Dock chuyển màn hình, màn hình có origin âm;
- Spaces, Stage Manager, full-screen app;
- Accessibility allowed/denied/revoked;
- Dock restart, sleep/wake, user session switch;
- Reduce Motion, VoiceOver và keyboard focus;
- hover nhanh qua nhiều icon và đường di chuyển icon → panel.

### Ước lượng

Đây là ước lượng kỹ thuật, không phải cam kết lịch:

- spike đọc AX + panel thụ động: **1–2 ngày**;
- MVP có setting, permission UX, chart của active feature và test cơ bản: **4–6 ngày**;
- phiên bản tương tác, ổn định multi-monitor/autohide/magnification, regression QA và release hardening: **1,5–3 tuần**.

## Quyết định khuyến nghị

**Go** cho một technical spike dùng **public Accessibility API + nonactivating `NSPanel`**, với wording sản phẩm là “Dock hover dashboard”.

**No-go** cho hướng thay tooltip native, sửa tên bundle để giấu label, dùng private CoreDock/SkyLight, inject vào Dock hoặc yêu cầu vô hiệu hóa SIP.

Điều kiện trước khi ship:

- UX chấp nhận native label có thể vẫn tồn tại;
- Accessibility là opt-in có giải thích;
- spike chạy ổn trên ít nhất macOS 14, 15 và 26;
- release Developer ID đã qua notarization/stapling và kiểm tra trên máy sạch.
