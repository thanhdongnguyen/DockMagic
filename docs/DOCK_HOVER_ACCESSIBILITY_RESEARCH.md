# Nghiên cứu chuyên sâu: quyền Accessibility cho Dock hover dashboard

**Ngày đánh giá:** 2026-08-25

**Phạm vi:** DockMagic trên macOS 14+, phát hành trực tiếp bằng Developer ID; hover UI chỉ hiển thị feature đang được chọn.

**Trạng thái:** Spike đã được triển khai và kiểm chứng end-to-end trên macOS
26.2. Permission UI mở đúng `Privacy & Security → Accessibility`; popup Codex
đã qua render/visual QA; một Release ad-hoc đã nhận event hover thật từ Dock và
trình bày panel. Trước khi phát hành vẫn phải lặp lại ma trận với bản Developer
ID/notarized cài ở path ổn định.

## Cập nhật triển khai 2026-08-24

Những phần đã có trong source hiện tại:

- setting opt-in, tắt mặc định, cùng permission state machine
  `disabled → needsPermission → awaitingUserAction → authorized`;
- lời giải thích phạm vi quyền và các CTA `Allow Accessibility…`,
  `Open System Settings`, `Check Again`;
- `DockAccessibilityObserver` cho `com.apple.dock`, lọc fail-closed theo
  `AXApplicationDockItem` và bundle ID `com.hypevibe.DockMagic`;
- health check/reattach khi Dock PID hoặc tree thay đổi, đồng thời đọc lại
  selected child mỗi 5 giây làm fallback nếu notification bị bỏ lỡ;
- `NSPanel` thụ động, non-activating, được clamp theo màn hình/cạnh Dock;
- popup Codex 440×304 gồm 5-hour/weekly rate limits, lifetime tokens và chart
  daily token usage cuộn ngang tối đa 30 ngày đọc từ Codex App Server
  `account/usage/read`;
- fallback an toàn khi Codex CLI chưa hỗ trợ method usage mới;
- unit tests cho parser, permission state machine, panel placement và
  reference-render test cho popup.

Kiểm tra runtime đã chứng minh app gọi đúng public TCC flow và xuất hiện trong
danh sách Accessibility. Sau khi reset **chỉ** entry
`com.hypevibe.DockMagic`, bật lại quyền cho đúng Release ad-hoc và giữ setting
hover ở trạng thái bật, log ngày 2026-08-24/25 ghi nhận đầy đủ:

```text
Attached Dock hover observer to pid 612
Selected Dock item subrole=AXApplicationDockItem bundle=com.hypevibe.DockMagic
Hovering DockMagic at x=1328 y=1012 width=46 height=58
Presented hover dashboard at x=1171 y=92
```

Điều này xác nhận chuỗi permission → Dock AX notification → bundle filter →
frame conversion → `NSPanel` hoạt động thật. Trước đó, một grant của build Apple
Development không áp dụng cho binary ad-hoc có requirement theo `cdhash`; đó là
identity mismatch được dự đoán ở mục 3, không phải lý do để thêm entitlement
riêng hoặc sửa TCC database trong ứng dụng.

## Kết luận điều hành

Phương án **khả thi** và phù hợp với kiến trúc hiện tại:

1. Người dùng chủ động bật `Show dashboard on Dock hover` trong Settings.
2. DockMagic giải thích phạm vi sử dụng rồi gọi `AXIsProcessTrustedWithOptions` để macOS hướng dẫn người dùng bật quyền Accessibility.
3. Khi đã có quyền, DockMagic quan sát selected child của accessibility tree thuộc process `com.apple.dock`.
4. Khi selected child là application Dock item có bundle identifier `com.hypevibe.DockMagic`, app mở một `NSPanel` không kích hoạt app, neo theo frame của icon.
5. Panel render một `DockHoverPresentation` được tạo từ **feature đang active và store đang chạy sẵn**.

Những giới hạn phải chấp nhận:

- Không thể nhúng chart vào hoặc thay thế tooltip native “DockMagic” bằng public `NSDockTile` API. Hover dashboard là cửa sổ do DockMagic sở hữu; label native có thể vẫn xuất hiện.
- Accessibility là quyền rộng do người dùng kiểm soát. DockMagic chỉ cần đọc hierarchy/frame của Dock, nhưng macOS không cấp một quyền hẹp “chỉ đọc Dock”.
- Apple công khai Accessibility API, nhưng không xuất bản cấu trúc con của accessibility tree trong Dock như một contract versioned riêng. Integration phải fail closed và được kiểm tra lại theo các bản macOS.
- Prompt cấp quyền chạy bất đồng bộ. Không có callback “user vừa bật xong”; app phải tự kiểm tra lại và attach observer sau khi quyền thực sự có hiệu lực.

Đánh giá:

| Hạng mục | Kết quả | Độ tin cậy |
| --- | --- | --- |
| Xin quyền trong bản Developer ID | Khả thi | Cao |
| Phát hiện hover đúng icon DockMagic | Khả thi bằng AX selected-child notification | Trung bình-cao |
| Hiển thị UI tương ứng feature active | Phù hợp trực tiếp với model hiện tại | Cao |
| Không khởi chạy thêm sampler/provider | Khả thi | Cao |
| Loại bỏ hoàn toàn label native | Không cam kết bằng public API | Cao |
| Không cần Screen Recording/Input Monitoring | Đúng với scope hiện tại | Cao |

## 1. Quyền Accessibility thực sự hoạt động thế nào

### 1.1 API kiểm tra và yêu cầu quyền

API đúng là [`AXIsProcessTrustedWithOptions`](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions). Với option `kAXTrustedCheckOptionPrompt = true`, macOS có thể thông báo rằng app chưa được tin cậy và dẫn người dùng đến nơi cấp quyền.

Điểm quan trọng nhất trong contract của Apple:

- hàm trả về trạng thái **tại thời điểm gọi**;
- prompt xuất hiện **bất đồng bộ**;
- việc prompt không làm thay đổi return value của lần gọi đó.

Ví dụ, lần đầu người dùng nhấn Enable:

```swift
let options = [
    kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
] as CFDictionary

let isTrustedNow = AXIsProcessTrustedWithOptions(options)
```

`isTrustedNow == false` là kết quả bình thường dù prompt vừa được mở. Không được start observer ngay chỉ vì đã gọi API.

Apple Support mô tả đúng luồng người dùng: app hiển thị alert, người dùng chọn **Open System Settings**, sau đó tự bật app trong **Privacy & Security → Accessibility**. Người dùng cũng có thể từ chối, tắt lại sau này, hoặc thêm app thủ công. Xem [Allow accessibility apps to access your Mac](https://support.apple.com/en-gb/guide/mac-help/mh43185/mac).

### 1.2 App không thể tự cấp quyền

DockMagic không có public API để:

- tự bật toggle Accessibility;
- đọc trạng thái chi tiết `notDetermined` / `denied` / `authorized` như một số framework khác;
- ép prompt xuất hiện lại liên tục;
- sửa trực tiếp TCC database.

`AXIsProcessTrusted()` chỉ trả về Boolean. Trạng thái “đang chờ người dùng”, “người dùng vừa từ chối” hay “đã từng cấp rồi thu hồi” phải là trạng thái UX do DockMagic tự quản lý, không phải trạng thái mà TCC công khai.

### 1.3 Không có Accessibility entitlement

Apple DTS xác nhận:

- không có entitlement `com.apple.security.accessibility` để thêm;
- quyền được người dùng điều khiển trong System Settings;
- app sandboxed không dùng được cross-process AX theo thiết kế này.

Nguồn: [Apple DTS — Commonly Hallucinated Entitlements](https://developer.apple.com/forums/topics/code-signing-topic/code-signing-topic-entitlements).

Cấu hình Release hiện tại của DockMagic đã phù hợp:

| Build setting | Giá trị hiện tại |
| --- | --- |
| `ENABLE_APP_SANDBOX` | `NO` |
| `ENABLE_HARDENED_RUNTIME` | `YES` |
| `MACOSX_DEPLOYMENT_TARGET` | `14.0` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.hypevibe.DockMagic` |
| `DEVELOPMENT_TEAM` | `S35WXF7W5L` |

Đây là cấu hình đúng cho Developer ID direct distribution. Không cần và không nên chuyển sang App Sandbox chỉ để xin quyền này.

### 1.4 Không có purpose string dành riêng cho Accessibility

SDK macOS 26.2 hiện tại không chứa `NSAccessibilityUsageDescription` hay `NSAccessibilityDescription`, và Apple không liệt kê một Accessibility purpose-string key trong nhóm protected resources của Info.plist.

Hệ quả:

- không thêm một key không tồn tại vào `Info.plist`;
- không dựa vào system alert để giải thích đầy đủ use case;
- phải có pre-permission UI do DockMagic viết, trước khi gọi prompt.

Nội dung đề xuất:

> DockMagic uses Accessibility to detect when the pointer is over its own Dock icon and to read that icon’s position. It does not read keystrokes, inspect other app windows, or capture the screen.

Phải tránh wording “quyền chỉ cho Dock” vì quyền mà macOS cấp rộng hơn cách DockMagic dự định sử dụng.

### 1.5 Không cần Screen Recording hoặc Input Monitoring

Với scope này, DockMagic chỉ:

- đọc selected Dock accessibility element và frame;
- render chart từ dữ liệu nội bộ đang có.

Vì vậy không cần:

- Screen & System Audio Recording;
- Input Monitoring;
- global `NSEvent` monitor;
- `CGEventTap`.

Apple DTS phân biệt Input Monitoring với Accessibility tại [thread này](https://developer.apple.com/forums/thread/828052). DockMagic thậm chí không cần event listening toàn hệ thống: notification từ AX list của Dock là đủ cho hover MVP.

Nếu sau này feature mở rộng sang thumbnail của cửa sổ app khác, chụp màn hình hoặc hotkey toàn hệ thống, phải đánh giá quyền lại như một scope riêng.

## 2. Permission UX và state machine đề xuất

### 2.1 Setting sản phẩm

Thêm setting lưu bền:

```text
Show dashboard on Dock hover        [toggle]
Status: Accessibility required / Ready / Temporarily unavailable
```

Feature nên tắt mặc định. Không prompt khi app launch lần đầu.

### 2.2 Trạng thái nội bộ

| State | Ý nghĩa | Hành vi |
| --- | --- | --- |
| `disabled` | Setting tắt | Không kiểm tra định kỳ, không observer, panel bị ẩn |
| `needsPermission` | Setting bật nhưng `AXIsProcessTrusted() == false` | Hiện giải thích và nút Continue/Open Settings |
| `awaitingUserAction` | Đã gọi prompt nhưng chưa thấy quyền | Recheck có giới hạn; không attach observer |
| `attaching` | Đã trusted, đang tìm Dock/list và đăng ký notification | Panel vẫn ẩn |
| `ready` | Observer hoạt động | Cho phép show panel khi hover |
| `degraded(reason)` | Có quyền nhưng Dock tree/observer tạm lỗi | Ẩn panel, retry có backoff |

Không cần state `denied` như một sự thật của hệ thống vì API không cung cấp đủ thông tin để phân biệt. `awaitingUserAction` chỉ nói rằng DockMagic đã hướng dẫn người dùng nhưng vẫn chưa được trusted.

### 2.3 Luồng lần đầu

1. Người dùng bật setting.
2. DockMagic gọi `AXIsProcessTrusted()` không prompt để tránh alert thừa nếu quyền đã có.
3. Nếu đã trusted, attach observer ngay.
4. Nếu chưa trusted, hiện explanation card/sheet.
5. Chỉ sau khi người dùng nhấn Continue, gọi `AXIsProcessTrustedWithOptions(...prompt: true)` đúng một lần cho hành động đó.
6. Chuyển sang `awaitingUserAction`; không dựa vào return value để kết luận người dùng đã cấp.
7. Recheck khi DockMagic trở thành active trở lại và, trong lúc permission UI còn hiện, poll nhẹ khoảng mỗi giây với timeout hữu hạn.
8. Khi `AXIsProcessTrusted()` chuyển sang true, dừng polling và attach observer.

Không nên gọi prompt ở mọi launch. Nếu setting đã bật nhưng quyền không còn, app khởi động ở `needsPermission` và chỉ hiện trạng thái trong Settings.

### 2.4 Sau khi người dùng cấp quyền có cần restart không?

Apple không ghi yêu cầu restart cho `AXIsProcessTrustedWithOptions`; yêu cầu relaunch trong tài liệu thuộc API root-only cũ `AXMakeProcessTrusted`, không phải flow người dùng hiện tại.

Khuyến nghị sản phẩm:

- không yêu cầu restart mặc định;
- recheck trạng thái và tạo mới toàn bộ AX observer sau khi trusted;
- nếu `AXIsProcessTrusted() == true` nhưng AX calls tiếp tục lỗi, đưa ra nút **Relaunch DockMagic** như troubleshooting, không coi relaunch là bước bắt buộc.

Điểm này phải được xác nhận bằng technical spike trên các bản macOS được hỗ trợ.

### 2.5 Thu hồi quyền khi app đang chạy

Nếu người dùng tắt DockMagic trong Accessibility:

1. `AXIsProcessTrusted()` sẽ trở về false hoặc AX messaging trả `.apiDisabled`.
2. Hủy notification subscription và run-loop source.
3. Ẩn panel ngay.
4. Giữ setting sản phẩm là bật, nhưng chuyển state về `needsPermission`.
5. Dock icon, sampler active và Settings vẫn hoạt động bình thường.

Không reset setting của người dùng chỉ vì quyền bị thu hồi; như vậy nếu họ bật lại quyền, feature có thể phục hồi sau lần recheck tiếp theo.

## 3. Code signing, update và TCC

TCC cần nhận diện version mới là cùng một sản phẩm. Apple DTS giải thích rằng quyết định privacy dựa vào stable code-signing identity; unsigned hoặc ad-hoc builds khiến hệ thống khó nhận version N+1 là cùng code và có thể tạo prompt lặp. Xem [On File System Permissions](https://developer.apple.com/forums/tags/files-and-storage).

Áp dụng cho DockMagic:

- Release phải giữ nguyên bundle ID `com.hypevibe.DockMagic`;
- ký mọi bản bằng cùng Developer ID Application identity/team;
- giữ designated requirement ổn định qua update;
- notarize và staple theo pipeline direct distribution;
- không đánh giá permission persistence chỉ bằng Debug build chạy từ các DerivedData path khác nhau.

Kết quả thử nghiệm local xác nhận điểm cuối: một grant đang bật trong System
Settings vẫn không áp dụng cho build ad-hoc mới nếu requirement đổi. Release QA
phải dùng app Developer ID được cài tại một path ổn định; tuyệt đối không thêm
logic tự reset TCC hoặc coi công tắc hiển thị trong System Settings là bằng chứng
đủ nếu `AXIsProcessTrusted()` vẫn là `false`.

Apple không công bố một guarantee đơn giản rằng Accessibility sẽ luôn được giữ qua mọi thay đổi path/signature/version. Vì vậy đây là release test bắt buộc, không phải giả định kiến trúc.

Ma trận update tối thiểu:

1. Cài bản A đã ký/notarize vào `/Applications`.
2. Cấp Accessibility và xác minh hover.
3. Update in-place sang bản B cùng bundle ID/Developer ID.
4. Xác minh quyền còn hiệu lực và observer attach lại.
5. Lặp với clean VM, app được tải từ Downloads rồi chuyển vào Applications.
6. Thử một build ký khác để chắc chắn test có thể phát hiện identity mismatch.

Apple DTS khuyến nghị dùng VM snapshot sạch cho TCC testing vì reset bằng command line không phải lúc nào cũng tái tạo được trạng thái người dùng thực. Một lỗi Privacy & Security ở macOS 26.1 từng ảnh hưởng cả Accessibility; xem [Apple DTS discussion](https://developer.apple.com/forums/thread/808897). Do đó phải test các point release thực tế, không chỉ major version.

## 4. Phát hiện hover icon DockMagic

### 4.1 Observer flow

Luồng public API đề xuất:

1. Resolve process đang chạy có bundle identifier `com.apple.dock`.
2. Tạo `AXUIElement` cho PID của Dock.
3. Duyệt children để tìm element có role `AXList`; không hard-code tuyệt đối “child đầu tiên”.
4. Tạo `AXObserver` cho PID.
5. Đăng ký `kAXSelectedChildrenChangedNotification` trên Dock list.
6. Add `AXObserverGetRunLoopSource` vào run loop do controller sở hữu.
7. Trong callback, đọc `kAXSelectedChildrenAttribute`.
8. Chỉ chấp nhận child có subrole application Dock item.
9. Đọc `kAXURLAttribute`, tạo `Bundle(url:)`, so bundle ID với `com.hypevibe.DockMagic`.
10. Đọc `kAXPositionAttribute` và `kAXSizeAttribute`, chuyển sang AppKit screen coordinates rồi show/reposition panel.
11. Nếu selected child trống hoặc thuộc app khác, hide panel.

### 4.1.1 Kết quả spike thực tế

Tài liệu Apple định nghĩa `kAXSelectedChildrenChangedNotification` theo nghĩa
chung là tập child “được chọn” thay đổi. Dock trên macOS 26.2 thực tế cập nhật
`AXSelectedChildren` khi con trỏ đi qua các Dock item: log lần lượt ghi nhận
Hermes, DockMagic và FocuSee khi con trỏ di chuyển ngang Dock. Vì vậy observer
event-driven hiện tại đủ để phát hiện hover mà không cần global mouse monitor,
Input Monitoring hoặc Screen Recording. Health check 5 giây vẫn đọc lại
selected child để phục hồi trường hợp một notification đơn lẻ bị bỏ lỡ.

Apple mô tả [`AXUIElement`](https://developer.apple.com/documentation/applicationservices/axuielement) là object cung cấp hierarchy, vị trí trên display, chi tiết và notification. [`AXObserverCreate`](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate) là API observer công khai.

[DockDoor](https://github.com/ejbills/DockDoor/blob/main/DockDoor/Utilities/DockObserver.swift) đang dùng selected-child notification này để phát hiện hovered Dock item. Đây là bằng chứng triển khai thực tế, không phải giấy phép copy: DockDoor dùng GPL-3.0 và DockMagic phải triển khai clean-room chỉ dựa trên public API/contract.

### 4.2 Nhận dạng theo bundle ID, không theo title

Không so chuỗi `DockMagic` vì title có thể thay đổi theo localization, bundle metadata hoặc hành vi Dock.

Điều kiện an toàn:

```text
subrole == AXApplicationDockItem
AND AXURL resolves to Bundle
AND bundle.bundleIdentifier == com.hypevibe.DockMagic
```

Nếu URL, role hoặc bundle ID không đọc được, **không hiển thị panel**. Đây là fail-closed behavior để không show UI nhầm khi hover app khác.

### 4.3 Threading và timeout

AX attribute reads là synchronous cross-process messaging. SDK cho phép đặt timeout bằng `AXUIElementSetMessagingTimeout`; `.cannotComplete` có thể xảy ra khi messaging lỗi hoặc process đích bận.

Khuyến nghị:

- làm AX parsing trên một serial executor/queue riêng;
- callback chỉ thu thập event rồi chuyển kết quả UI về `MainActor`;
- đặt timeout ngắn, nhưng chọn con số sau profiling trong spike thay vì hard-code theo cảm tính;
- coalesce các hover event liên tiếp để không xếp hàng stale work;
- không giữ một AX call block main thread.

### 4.4 Dock restart và tree rebuild

Các reference AX gắn với PID/tree cũ. Khi Dock restart hoặc rebuild UI, observer có thể im lặng vì element không còn hợp lệ.

Health check khi feature bật nên:

- kiểm tra `AXIsProcessTrusted()`;
- resolve PID hiện tại của `com.apple.dock` và so với PID đã attach;
- probe role của subscribed list;
- reattach khi PID đổi hoặc nhận `.invalidUIElement` / `.cannotComplete` lặp lại;
- dùng exponential backoff khi Dock chưa sẵn sàng.

Không nên chỉ dựa vào `NSWorkspace.didLaunchApplicationNotification`: Apple ghi notification này không được phát cho background apps, nên nó không phải recovery contract đủ chắc cho Dock. Có thể dùng workspace/session notifications như trigger bổ sung, nhưng health check vẫn là nguồn phục hồi chính. Xem [Apple — didLaunchApplicationNotification](https://developer.apple.com/documentation/appkit/nsworkspace/didlaunchapplicationnotification).

DockDoor hiện dùng health check 5 giây để so PID và xác minh subscribed element. DockMagic có scope nhỏ hơn, nên có thể dùng cùng order-of-magnitude trong spike và đo overhead thực tế.

### 4.5 Magnification, auto-hide và nhiều màn hình

Frame AX là frame tại thời điểm đọc. Với Dock magnification, icon có thể tiếp tục dịch chuyển/phóng to sau event ban đầu.

Panel controller nên:

- đọc frame ngay khi enter;
- re-read một lần sau animation delay ngắn hoặc khi nhận event tiếp theo;
- tìm `NSScreen` chứa midpoint của AX frame;
- chuyển hệ tọa độ top-left AX sang AppKit cẩn thận với screen origin âm;
- clamp panel vào `visibleFrame` của đúng screen;
- suy ra cạnh Dock từ vị trí icon so với screen, không giả định luôn ở bottom.

## 5. Hover UI tương ứng feature đang chọn

### 5.1 Kiến trúc hiện tại hỗ trợ tốt

[`DockAppModel`](../DockMagic/DockMagic/Stores/DockAppModel.swift) đã có hai đặc điểm đúng với yêu cầu:

- `preferences.activeFeature` chọn đúng một feature;
- `applyPreferences()` chỉ start store của feature đó và stop/pause mọi store khác.

Vì vậy mở hover panel **không được** gọi `start()` hay `refresh()` cho store khác. Vòng đời dữ liệu vẫn do `activeFeature` quyết định, không do panel visibility quyết định.

### 5.2 Không dùng thẳng `DockTilePresentation`

`DockTilePresentation` tối ưu cho icon vuông. Nó không đủ dữ liệu cho hover dashboard phong phú: ví dụ case system metrics chỉ chứa snapshot hiện tại, trong khi `SystemMetricsStore` đã có history 60 mẫu.

Nên thêm model riêng:

```text
DockAppModel.hoverPresentation
    -> DockHoverPresentation
    -> DockHoverDashboardView
```

`DockHoverPresentation` switch theo đúng `activeFeature`, nhưng lấy state giàu hơn trực tiếp từ active store. Không để panel tự đọc cả mười store và không mở rộng `DockTilePresentation` bằng dữ liệu mà icon không dùng.

### 5.3 Mapping chi tiết

| Active feature | State hiện có | Hover UI đề xuất | Lưu ý |
| --- | --- | --- | --- |
| DockMagic | Không có provider | Logo, tên app, lời nhắc chọn feature hoặc trạng thái hover | Không bịa chart |
| CPU & RAM | `current`, `history` tối đa 60 mẫu/1 giây | Hai số hiện tại + dual-series chart 60 giây + RAM used/total | System history hiện không clear khi restart; filter continuous recent tail hoặc break line tại gap |
| Network | `current`, `history` tối đa 60 mẫu/1 giây | Download/upload hiện tại + chart 60 giây + interface | `NetworkHistoryChart`/scale có thể tái sử dụng; history clear khi store start |
| Storage | Snapshot volume | Used/available/total + progress bar/ring | Không có history, không giả lập trend |
| Weather | `idle/loading/live/stale/unavailable` | Condition, temperature, feels-like, high/low, precipitation, location | Hiện stale/error rõ ràng |
| Batteries | Danh sách device snapshot | Mac và accessories, phần trăm, charging state | Có thể nhiều hơn 4 device; panel rộng phù hợp hơn Dock icon |
| GitHub | History tối đa 7 ngày, poll 15 phút khi active | Stars/forks hiện tại + delta + 7-day trend | Không hiển thị token; empty/not-configured state riêng |
| Codex | Five-hour/weekly snapshot + aggregate account usage | Remaining %, reset time, lifetime tokens và daily token chart cuộn ngang tối đa 30 ngày | Đọc `account/rateLimits/read` và experimental `account/usage/read`; không inspect prompt/conversation |
| Claude Code | Cùng normalized usage model | Remaining %, reset time, bridge/status | Không hiển thị path/secret nội bộ |
| Search Console | Snapshot có dated points và config time range/metric/mode | Chart hoặc numbers theo config đang chọn + property label rút gọn | Không render private key/client email trong hover card |

### 5.4 Reuse UI đúng lớp

Không nên nhúng nguyên [`DockTileView`](../DockMagic/DockMagic/Views/Dock/DockMetricsView.swift) vào panel rồi scale lớn. Các Dock view hiện tại dùng square geometry, icon typography và density dành cho tile.

Nên tái sử dụng:

- snapshot/state models;
- formatters như `MetricsFormatting`;
- chart scale và color/appearance config;
- chart primitives có layout linh hoạt, ví dụ [`NetworkHistoryChart`](../DockMagic/DockMagic/Views/Settings/NetworkHistoryChart.swift) sau khi tách theme/layout phù hợp.

Tạo dedicated hover views để có title, timestamp, loading/stale/error và accessibility labels đúng với card 320×180/200.

### 5.5 Chuyển feature khi panel đang mở

`hoverPresentation` phải là observable derived state giống `dockPresentation` hiện tại.

Khi người dùng đổi active feature trong Settings:

1. `DockAppModel.applyPreferences()` stop store cũ và start store mới.
2. `hoverPresentation` đổi sang loading/current state của feature mới.
3. Panel đang visible update tại chỗ, không cần hide/show lại.
4. Panel không chủ động refresh ngoài lifecycle của store.

## 6. Panel behavior

Sử dụng một `NSPanel` sống lâu, không tạo cửa sổ mới ở mỗi hover:

- style mask `.borderless`, `.fullSizeContentView`, `.nonactivatingPanel`;
- SwiftUI content qua `NSHostingView`;
- không gọi `NSApp.activate`;
- collection behavior phù hợp Spaces/full-screen;
- hide ngay khi quyền mất hoặc Dock observer không còn chắc chắn.

Apple mô tả [`.nonactivatingPanel`](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) là panel không kích hoạt app sở hữu.

MVP nên read-only. Nếu UI cần click/scroll:

- thêm grace period khi chuột rời icon;
- tracking area trong panel;
- corridor từ icon tới panel để tránh flicker;
- kiểm tra panel không đánh cắp keyboard focus.

Label native “DockMagic” có thể vẫn xuất hiện. Public [`NSDockTile`](https://developer.apple.com/documentation/appkit/nsdocktile) không có API thay tooltip bằng view hoặc tắt riêng label của một tile. Thiết kế panel nên đặt cao hơn label và coi label là phần UI hệ thống, không cố che bằng private API.

## 7. Phân rã component đề xuất

| Component | Trách nhiệm |
| --- | --- |
| `DockHoverPreference` | Lưu setting enable/disable; không lưu trạng thái TCC như sự thật |
| `AccessibilityPermissionController` | Check/prompt/recheck, publish permission UX state |
| `DockAccessibilityObserver` | Resolve Dock PID/list, subscribe selected-child, parse đúng DockMagic item |
| `DockObserverHealthMonitor` | Phát hiện revoke, Dock PID/tree invalid, retry/backoff |
| `DockItemFrameResolver` | AX frame → AppKit screen/frame, clamp multi-monitor |
| `DockHoverPanelController` | Sở hữu/reuse nonactivating panel, show/hide/reposition |
| `DockHoverPresentation` | Rich state cho duy nhất active feature |
| `DockHoverDashboardView` | Switch sang view tương ứng feature và render loading/stale/error |

`AppDelegate` đang sở hữu `DockTileController` và vòng đời app, nên có thể sở hữu một top-level `DockHoverCoordinator`. Không đưa AX/window logic vào `DockTileController`; controller đó nên tiếp tục chỉ chịu trách nhiệm render icon.

## 8. Failure policy

| Tình huống | Phản ứng an toàn |
| --- | --- |
| User chưa cấp/từ chối | Icon và Settings hoạt động; panel không hiện; trạng thái permission có CTA |
| User thu hồi quyền | Hide panel, teardown observer, state `needsPermission` |
| Dock chưa chạy/đang restart | Hide panel, retry với backoff |
| AX element invalid | Bỏ reference, resolve tree mới |
| AX call `.cannotComplete` một lần | Bỏ event đó, retry nhẹ; không block UI |
| `.cannotComplete` lặp hoặc PID đổi | Full reattach |
| `.apiDisabled` | Xử lý như revoke |
| Không đọc được URL/bundle ID | Fail closed, không show |
| Active provider loading/error | Panel vẫn hiện card loading/error của đúng feature |
| Native tooltip overlap | Reposition panel; không can thiệp Dock/private API |

## 9. Test plan bắt buộc

### Permission/TCC

- clean user/VM chưa từng cài DockMagic;
- allow, deny, dismiss, allow later;
- revoke khi panel đang visible;
- quit/relaunch sau allow và sau revoke;
- update signed/notarized A → B;
- Debug vs Developer ID Release để phát hiện identity assumptions;
- app trong Downloads, sau đó `/Applications`;
- macOS 14, 15 và các 26.x point release hỗ trợ thực tế.

### Dock integration

- Dock bottom/left/right;
- auto-hide, magnification, các icon size;
- Dock restart (`killall Dock`) trong test môi trường;
- một/nhiều màn hình, origin âm, Dock chuyển màn hình;
- sleep/wake, fast user switching, session active;
- Stage Manager, Spaces, full-screen app;
- hover nhanh qua các icon và ra/vào DockMagic;
- DockMagic pinned/unpinned và app đang chạy.

### Feature mapping

- đủ 10 active feature;
- loading/live/stale/unavailable/disconnected;
- switch feature khi panel visible;
- CPU history có gap sau switch away/back;
- network history mới start chưa đủ 2 mẫu;
- GitHub/Search Console không cấu hình và lỗi network;
- battery không có device ngoài Mac và có nhiều accessories;
- không lộ credential, token, private key hoặc email không cần thiết.

### UX/accessibility

- panel không activate DockMagic hoặc làm app hiện tại mất focus;
- Reduce Motion, Increase Contrast, VoiceOver;
- text scaling/localization dài;
- native label không che nội dung chính;
- interactive corridor nếu MVP có tương tác.

## 10. Technical spike khuyến nghị

Spike nên giới hạn để trả lời các rủi ro platform trước khi đầu tư UI:

1. Thêm internal feature flag, không bật mặc định.
2. Implement permission state machine và pre-permission screen.
3. Attach AX observer chỉ khi trusted; log enter/exit, role, bundle ID, frame và AX errors — không log dữ liệu nhạy cảm.
4. Hiển thị panel read-only với title của active feature và một placeholder/state thật đơn giản.
5. Chứng minh không dùng Input Monitoring/Screen Recording và không chiếm focus.
6. Chứng minh revoke + Dock restart tự teardown/reattach.
7. Thử system metrics và network charts để xác minh live derived presentation.
8. Ký Developer ID, notarize, staple và test trong clean VM.

Tiêu chí go/no-go:

- enter/exit đúng icon ≥ 99% trong test hover lặp;
- không show nhầm app khác;
- không block main thread đáng kể;
- phục hồi sau Dock restart và revoke/regrant;
- panel ổn định với Dock ở ba cạnh và multi-monitor;
- permission UX hiểu được, không prompt lặp;
- native label coexistence được sản phẩm chấp nhận.

## 11. Ước lượng đã điều chỉnh

| Giai đoạn | Phạm vi | Ước lượng |
| --- | --- | --- |
| Platform spike | Permission, AX observer, frame, passive panel, recovery | 2–3 ngày |
| Active-feature MVP | 10 presentation states, read-only views, Settings, unit tests | 5–8 ngày |
| Interaction + hardening | Mouse corridor, multi-monitor, full-screen, TCC/update QA | 1,5–3 tuần |

Ước lượng chưa gồm thiết kế visual hoàn chỉnh và localization. Phần rủi ro lớn nhất không phải chart, mà là độ bền của Dock AX integration qua môi trường/macOS point releases.

## Quyết định khuyến nghị

**Go** cho technical spike theo kiến trúc:

```text
user opt-in
→ Accessibility permission controller
→ Dock AX selected-child observer
→ verify DockMagic bundle ID + resolve icon frame
→ nonactivating NSPanel
→ DockHoverPresentation của activeFeature
```

Giữ các nguyên tắc:

- không prompt tự động lúc launch;
- không thêm entitlement/purpose string không tồn tại;
- không yêu cầu Screen Recording/Input Monitoring;
- không start store ngoài active feature;
- không copy mã GPL của DockDoor;
- không dùng CoreDock/SkyLight/private API, injection hay vô hiệu hóa SIP;
- không cam kết loại bỏ hoàn toàn label native.

Với các điều kiện đó, đây là một feature phù hợp với đường phát hành Developer ID hiện tại của DockMagic và có thể triển khai bằng public macOS APIs, dù cần regression QA định kỳ cho accessibility tree của Dock.
