# Now Playing — nghiên cứu và đề xuất cho DockMagic

Ngày kiểm tra: 16/09/2026. Trạng thái: đề xuất; chưa triển khai tính năng.

Cập nhật quyết định thiết kế: người dùng đã chọn **phương án 3**, icon đĩa nhạc và dashboard ngang. Kích thước/bố cục MVP hiện theo [kế hoạch triển khai](NOW_PLAYING_IMPLEMENTATION_PLAN.md); các kích thước gợi ý ban đầu bên dưới là bối cảnh nghiên cứu.

## Quyết định đề xuất

Thêm feature `Now Playing` cho Spotify desktop và ứng dụng Music trên macOS. Ô Dock hiển thị ảnh bìa cùng trạng thái; hover mở bộ điều khiển khoảng 440 × 360 pt. Có chế độ mở/ghim để thao tác lâu hơn và dùng bàn phím. Kết nối ứng dụng qua Apple Events, ưu tiên ScriptingBridge với lớp adapter riêng cho mỗi nguồn.

Bản đầu tập trung vào xem bài đang phát, play/pause, previous/next, tua khi được hỗ trợ, và volume của ứng dụng đang chọn. Không cần thiết kế đăng nhập tài khoản Spotify/Apple Music bên trong DockMagic cho đường điều khiển local này. Người dùng vẫn cần cài, đăng nhập và sử dụng ứng dụng nguồn theo yêu cầu của ứng dụng đó.

## Dockset thực sự mô tả gì?

[Tài liệu Now Playing](https://dockset.app/manual/now-playing), ghi cập nhật 14/09/2026, mô tả:

- Bật Spotify, Apple Music hoặc cả hai; nhấn Connect riêng từng ứng dụng và chấp thuận Automation của macOS.
- Tự theo dõi playback từ các nguồn đã bật.
- Hai bố cục Mini/Full; tùy chọn previous/next và lùi/tiến theo khoảng 5, 10, 15, 30 hoặc 60 giây. Play/pause luôn có trong bố cục.
- Khi thiếu playback, kiểm tra nguồn, kết nối và quyền tại System Settings → Privacy & Security → Automation.
- Chỉ hỗ trợ ứng dụng đã cài trên Mac; playback trong browser không thuộc phạm vi.

Trang này không cung cấp mã nguồn, đặc tả cách chọn nguồn khi hai app cùng phát, hoặc bằng chứng về queue, lyrics, Spotify Connect và cấu trúc backend. Cách dùng Apple Events ở DockMagic là đề xuất dựa trên quyền được mô tả và API công khai, không phải kết luận về nội bộ Dockset. Đã đọc nội dung trực tiếp trong trình duyệt; chưa chạy ứng dụng Dockset.

## Trải nghiệm đề xuất

### 1. Ô Dock

- Ảnh bìa vuông; thiếu ảnh thì dùng biểu tượng âm nhạc trung tính.
- Một chỉ báo nhỏ phân biệt phát/tạm dừng. Không dùng màu làm tín hiệu duy nhất.
- Không nhồi tên bài dài, nút transport hoặc thanh volume vào ô 32–48 pt.
- Đổi ảnh khi bài đổi; không cần vẽ lại ảnh Dock theo từng khung hình. Bản đầu không cần vòng tiến độ hay equalizer chuyển động.
- Chọn Now Playing như các `DockFeature` hiện có. Bản đầu không tự thay thế feature người dùng đang chọn khi có nhạc.

DockMagic hiện cập nhật `applicationIconImage` và gọi `dockTile.display()`; ảnh đó cũng ảnh hưởng giao diện Command-Tab theo chủ đích hiện tại trong `DockTileController`. Cần chấp nhận hệ quả này khi dùng album art, hoặc mở hạng mục kiến trúc riêng nếu muốn Command-Tab luôn giữ logo DockMagic.

Không ánh xạ Mini/Full của Dockset thành widget kéo ngang bên trong Dock hệ thống: kiến trúc DockMagic hiện dùng một application tile. Mini nên là ô Dock; Full nên là panel bên ngoài ô. [NSDockTile](https://developer.apple.com/documentation/appkit/nsdocktile) cho phép tùy biến nội dung tile; [size](https://developer.apple.com/documentation/appkit/nsdocktile/size) là thuộc tính chỉ đọc.

### 2. Dashboard hover

Bố cục mặc định:

1. Header: Now Playing, nguồn hiện tại, nút ghim.
2. Ảnh bìa 80–88 pt bên cạnh tên bài, nghệ sĩ, album; dành tối đa hai dòng cho tên bài.
3. Thời gian đã phát/tổng thời lượng, thanh tua khi có duration và có thể seek.
4. Previous · lùi 15 giây · Play/Pause · tiến 15 giây · Next. Hai nút tua có thể tắt trong Settings.
5. Volume của Spotify/Music và đường mở ứng dụng nguồn.

Play/Pause là hành động nổi bật. Album art giữ màu nguyên bản trong vùng ảnh; nền, nút và focus dùng `DesignTheme`, không lấy màu từ ảnh bìa. Không thêm gradient, glow hay nền nhuộm màu theo album. Áp dụng `docs/COLOR_DESIGN_SYSTEM.md` và `docs/DESIGN_SYSTEM.md`; không áp dụng bố cục dashboard AI cho trình phát nhạc.

### 3. Mở/ghim và bàn phím

Hover vẫn không làm gián đoạn ứng dụng đang dùng. Để điều khiển bằng bàn phím, cần đường mở panel bằng menu Dock hoặc lệnh mở rõ ràng; chế độ đó được phép nhận key focus, có Escape để đóng và thứ tự Tab hợp lý. Khi ghim, rời chuột không đóng panel.

Đây là thay đổi cần triển khai: `DockHoverPanel.canBecomeKey` hiện trả `false`; chỉ thêm một nút ghim vào view chưa giải quyết được bàn phím. Dock click hiện mở Settings qua `applicationShouldHandleReopen`; MVP có thể giữ hành vi này và thêm mục `Open Now Playing` trong menu Dock.

### 4. Nguồn và trạng thái

- Lựa chọn: Auto / Spotify / Apple Music. Header luôn ghi app nhận lệnh.
- Auto chỉ xét nguồn đã bật và đã kết nối. Ưu tiên app đang phát; nếu cả hai đang phát thì giữ nguồn đang chọn để tránh nhảy qua lại. Khi chưa có lựa chọn, dùng ưu tiên đã lưu hoặc cho người dùng chọn.
- Nếu không app nào đang phát, giữ nguồn vừa dùng nếu còn snapshot hợp lệ; tạm dừng không đồng nghĩa mất kết nối.
- Khi người dùng kéo seek hoặc volume, giữ cố định source và track cho tới hết thao tác. Bỏ lệnh seek nếu track đã đổi.
- Không tự pause app còn lại khi đổi nguồn. Đổi nơi điều khiển không có nghĩa là chuyển playback.
- Phân biệt chưa cài, chưa kết nối, bị từ chối quyền, app chưa chạy, chưa có bài, tạm dừng, timeout, và dữ liệu cũ. Một nguồn lỗi không làm mất dữ liệu của nguồn còn lại.
- Chỉ hỏi quyền sau thao tác Connect. Polling không tự mở ứng dụng nhạc hay lặp hộp thoại xin quyền.

## Bằng chứng về khả năng local

Đã đọc scripting dictionary đi kèm các app trên máy; không gửi lệnh đọc tài khoản, không đổi playback hay cấp quyền:

- Spotify `1.3.0.277`, bundle ID `com.spotify.client`: `/Applications/Spotify.app/Contents/Resources/Spotify.sdef`.
- Music `1.4.4`, bundle ID `com.apple.Music`: `/System/Applications/Music.app/Contents/Resources/com.apple.Music.sdef`.

| Tính năng | Spotify dictionary | Music dictionary | Phạm vi đề xuất |
| --- | --- | --- | --- |
| Bài, nghệ sĩ, album | Có | Có | MVP; trường thiếu có fallback |
| Artwork | `artwork url`; `artwork` đã deprecated | `artworks`, `data`, `raw data` | MVP; tải/cache riêng, không chặn metadata |
| Play/pause, previous/next | Có lệnh | Có lệnh | MVP; cần test trên tài khoản/nội dung thật |
| Seek, lùi/tiến theo giây | `player position` đọc/ghi | `player position` đọc/ghi | MVP có điều kiện; clamp và đọc lại kết quả |
| Volume ứng dụng | `sound volume`, 0–100 | `sound volume`, 0–100 | MVP; không gọi đây là volume hệ thống |
| Shuffle | Boolean, có field báo khả dụng | Enabled và mode | Sau MVP hoặc trong menu phụ |
| Repeat | Boolean | Off / one / all | Không ép Spotify thành ba chế độ |
| Lyrics | Không thấy trong dictionary đã đọc | Có trường lyrics ở track | Hoãn; có field không chứng minh lyrics đồng bộ hoặc đầy đủ cho streaming |
| Queue đang chờ phát | Không thấy API queue | Có playlist, không đủ để kết luận queue Up Next | Hoãn; không lấy playlist thay queue |
| Browser / điều khiển thiết bị từ xa | Không được chứng minh bởi hai adapter | Không được chứng minh bởi hai adapter | Ngoài MVP |

Đây là bằng chứng về giao diện scripting của phiên bản cài trên máy, chưa chứng minh mọi lệnh chạy đúng với mọi nội dung/tài khoản. Đặc biệt cần đo và chuẩn hóa đơn vị `duration` của Spotify so với `player position` bằng bài có thời lượng biết trước; không suy đoán từ tên trường hoặc chỉ dựa mô tả dictionary. Quảng cáo, podcast, radio, bài chưa có trong thư viện, streaming, file local và trường hợp Spotify đang điều khiển thiết bị khác cần được kiểm thử riêng.

## Kiến trúc triển khai

```text
SpotifyPlaybackProvider ─┐
                        ├─ NowPlayingStore ─┬─ NowPlayingDockTile
AppleMusicPlaybackProvider ┘                └─ NowPlayingDashboardView
                              ↑
                       PlaybackCommandRouter
```

- `NowPlayingSnapshot`: source, track ID, metadata optional, artwork reference, playback state, position/duration optional, observedAt, volume optional và các capability hiện tại.
- Tách trạng thái permission/connection khỏi playback; dữ liệu cũ không trở thành `stopped`, duration không biết không thành 0.
- `PlaybackCapabilities`: play, pause, previous, next, seek, volume; mở rộng shuffle và repeat theo semantics thật của nguồn.
- Provider dùng Apple Events qua ScriptingBridge, với wrapper chuyển kết quả thành các value snapshot. Không để `SBObject` sống trong SwiftUI state hay truyền giữa executor tùy ý.
- Giao tiếp qua worker tuần tự riêng, timeout hữu hạn, xử lý lỗi provider; publish UI trên MainActor. Cần prototype threading/error handling trước khi chốt wrapper.
- Khởi điểm polling đề xuất: khoảng 1 giây khi panel mở và đang phát; 3–5 giây khi chỉ cần theo dõi bài đổi cho ô Dock; backoff khi pause/không có bài; ngừng khi feature không được dùng và không có panel ghim. Đây là tham số thử nghiệm, chưa có đo CPU/pin.
- Theo dõi app launch/quit bằng NSWorkspace để tránh thăm dò ứng dụng chưa chạy. Có thể đánh giá playback notifications để tối ưu sau, không phụ thuộc notification chưa được xác minh.
- Thanh thời gian nội suy từ position + thời gian đơn điệu khi đang phát; ngừng nội suy khi paused/stale. Đọc lại sau lệnh và sau wake để đồng bộ.
- Khi kéo seek: preview tại UI, gửi lệnh cuối khi thả, kiểm tra source/track vẫn khớp; lỗi thì phục hồi giá trị đã xác nhận. Không phát Apple Event ở mọi pixel kéo.
- Artwork chỉ tải lại khi khóa source/track/artwork đổi. Giới hạn kích thước/tốc độ tải, hủy kết quả của bài cũ, có placeholder; không tải ảnh lại mỗi nhịp polling.

[Scripting Bridge](https://developer.apple.com/documentation/scriptingbridge) là API Apple công khai để điều khiển ứng dụng có scripting interface bằng Apple Events. Không cần dùng đường đọc/điều khiển toàn hệ thống qua framework private cho phạm vi hai app này.

### Điểm tích hợp vào code hiện có

| Nơi | Thay đổi dự kiến |
| --- | --- |
| `Models/DockConfiguration.swift` | Thêm `.nowPlaying`, tên/icon, `hasHoverDashboard` |
| `Stores/DockAppModel.swift` | Sở hữu store, khởi động/dừng theo feature và panel |
| `Stores/DockPreferencesStore.swift` | Nguồn bật, Auto/manual, nút tua, khoảng tua |
| `Services/DockTileController.swift` và renderer hiện tại | Artwork/trạng thái cho presentation mới |
| `Views/Hover/CodexHoverDashboardView.swift` | Gắn view vào `DockHoverDashboardRoot` đang nằm trong file này |
| `Services/DockHoverCoordinator.swift` | Kích thước panel, vòng đời, ghim, chế độ nhận focus |
| `Views/Settings/SettingsView.swift` | Mục Now Playing và Connect từng ứng dụng |
| `App/DockMagicApp.swift` | Menu `Open Now Playing`, hành động transport nếu phù hợp |
| `Info.plist`, `DockMagic.entitlements` | Usage description và Apple Events entitlement |

## Phân phối trực tiếp và lựa chọn API

Dự án hiện bật Hardened Runtime; entitlement đang có chưa khai báo Apple Events. Cần thêm `com.apple.security.automation.apple-events` và `NSAppleEventsUsageDescription`. Apple mô tả Apple Events là quyền truy cập được bật trong Hardened Runtime; đây là đường phù hợp để kiểm chứng cho bản Developer ID, không phụ thuộc phân phối Mac App Store. Bản ký thật vẫn phải được kiểm tra cấp/từ chối/thu hồi quyền, notarization và stapling theo quy trình DockMagic. [Apple Events Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.automation.apple-events), [Usage Description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsappleeventsusagedescription).

`MPNowPlayingInfoCenter` được Apple mô tả là nơi công bố thông tin media mà ứng dụng của mình phát. Framework Now Playing cũng hướng tới công bố các session của ứng dụng. Không lấy hai API đó làm bằng chứng rằng có thể đọc và điều khiển Spotify/YouTube/toàn hệ thống. [Media Player](https://developer.apple.com/documentation/mediaplayer), [Now Playing](https://developer.apple.com/documentation/nowplaying).

Spotify Web API chỉ nên nghiên cứu khi có yêu cầu riêng về playback từ xa hoặc thiết bị. Endpoint Start/Resume Playback dùng OAuth và yêu cầu Spotify Premium; các điều kiện Web API không tự động chứng minh điều kiện của local Apple Events. MVP local không nên bị gắn thêm OAuth chỉ vì cần play/pause trên máy. [Spotify Start/Resume Playback](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback).

## Thứ tự thực hiện và điều kiện hoàn thành

1. **Prototype local:** lấy snapshot từ mỗi app và thử play/pause/seek/volume trong build ký bằng danh tính DockMagic. Đo timeout, đơn vị thời gian, thiếu artwork, và cấp/từ chối/thu hồi Automation. Ghi capability nào đã chạy thật.
2. **MVP UI:** store/router, Settings Connect, ảnh Dock, dashboard hover, đường mở bằng bàn phím và ghim. Kiểm tra hai app cùng chạy, bài đổi giữa lúc seek, app quit, sleep/wake và lỗi một nguồn.
3. **Hoàn thiện:** shuffle/repeat theo từng nguồn, lựa chọn bố cục album lớn nếu cần, tối ưu polling dựa trên đo CPU/pin. Browser, queue, lyrics đồng bộ, global hotkey và tự đổi feature theo nhạc là hạng mục riêng.

Validation khi triển khai: unit test chọn nguồn, chuẩn hóa thời gian, stale state, command routing; integration với hai app thật; UI ở Light/Dark, Increased Contrast, Reduce Transparency, Reduce Motion và grayscale. Kiểm tra bàn phím, tên bài dài, ảnh lỗi, Dock 32/48/64/128 pt và Dock ở dưới/trái/phải. Build/test hoặc snapshot không thay thế việc kiểm tra Automation trong app ký thật và tương tác trên Dock hệ thống.

## Ranh giới bằng chứng của lượt nghiên cứu này

Đã đọc trang Dockset trực tiếp, tài liệu Apple/Spotify, code và hai scripting dictionary hiện có. Chưa thực hiện lệnh playback, chưa xin/cấp Automation, chưa kiểm chứng tài khoản Free/Premium, chưa build tính năng hay đo hiệu năng. Mockup trong cuộc trò chuyện dùng dữ liệu minh họa và chỉ mô phỏng tương tác.
