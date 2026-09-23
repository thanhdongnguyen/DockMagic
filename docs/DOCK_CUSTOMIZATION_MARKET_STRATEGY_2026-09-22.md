# DockMagic — nghiên cứu thị trường Dock trả phí và định hướng sản phẩm

**Ngày chốt dữ liệu:** 2026-09-22

**Trạng thái:** nghiên cứu và đề xuất chiến lược; chưa phải yêu cầu sản phẩm lâu dài và chưa thay `RULES.md`

**Phạm vi:** ứng dụng macOS đang bán hoặc có paid tier, trực tiếp thay đổi, thay thế, mở rộng hay đặt một bề mặt Dock-like cạnh Apple Dock. Sản phẩm chỉ là launcher bàn phím/radial launcher không được tính vào thị trường lõi.

> Không có registry chính thức cho category này. Danh mục dưới đây là market scan
> best-effort dựa trên website chính thức, storefront, changelog, tài liệu sản phẩm,
> review độc lập và thảo luận người dùng tại thời điểm nghiên cứu. Giá khuyến mại,
> tỷ giá và chính sách update có thể đổi sau ngày chốt dữ liệu.

## 1. Quyết định điều hành

DockMagic **không nên trở thành một Dock replacement tổng quát** và không nên chạy đua ở custom icon, theme, window preview, Start menu, folder launcher, file shelf hay nhiều Dock trên nhiều màn hình.

Hướng nên sở hữu là:

> **DockMagic là lớp operational intelligence cho developer và người dùng AI,
> nằm trong Apple Dock mà họ đã tin dùng. Nó cho biết việc gì cần chú ý ngay lúc
> này — quota sắp hết, agent đang chờ, build thất bại, PR bị chặn hoặc task vừa
> hoàn tất — rồi đưa người dùng về đúng nơi để xử lý.**

Ba lớp sản phẩm đề xuất:

1. **Dock Active — flagship mặc định:** một live tile trong chính Apple Dock; ít quyền, ít cấu hình, giá trị xuất hiện ngay.
2. **Hover Intelligence — chiều sâu:** dashboard có nguồn dữ liệu, freshness, lịch sử, trạng thái missing/partial và hành động mở đúng provider/session/repo.
3. **Status Shelf — expert mode trả phí:** 2–4 tín hiệu chuyên sâu chạy song song. Shelf không trở thành app launcher hoặc bản sao Apple Dock.

Lý do chính:

- Thị trường replacement/taskbar đã đông và trưởng thành: DockDoor Pro, DockFix, Sidebar, uBar, DockApp, ActiveDock, boringBar và nhiều sản phẩm mới cùng cạnh tranh bằng window management và tùy biến.
- Thị trường widget Dock cũng đã rất rộng: Dockset và CoolDock có catalog AI/system/productivity lớn; DockDoor Pro còn có marketplace và widget Codex.
- DockX đã đặt giá sàn rất thấp cho generic system status trong chính Dock tile: **$3.99 lifetime**. CPU/RAM/network/clock không thể là moat.
- Khoảng trống rõ nhất là **độ sâu semantic, độ tin cậy và actionability** của developer/AI workflow.
- Bằng chứng QA trong repo cho thấy full Custom Dock có blast radius lớn: native Dock handoff còn một route mở, macOS 14/15 và notarization/stapling clean-machine chưa qua, và full UI suite chưa xanh. Mở rộng parity lúc này tạo thêm rủi ro nhưng không tạo khác biệt đủ mạnh.

## 2. Apple Dock là baseline nào?

Apple Dock đã cung cấp launcher/switcher theo ứng dụng, app/file/folder/Trash, badge, running indicator, recent apps, Handoff, magnification, kích thước, vị trí trái/dưới/phải và auto-hide. Apple không cung cấp một API công khai để app thứ ba chèn nhiều widget có hit target vào nền Dock; [`NSDockTile`](https://developer.apple.com/documentation/appkit/nsdocktile) chỉ cho phép một ứng dụng cập nhật tile và badge của chính nó.

Vì vậy, sản phẩm trên thị trường dùng một trong bốn kiến trúc:

1. **Tile của chính app trong Apple Dock** — ít rủi ro nhất, ví dụ DockX và DockMagic Dock Active.
2. **Điều khiển layout Apple Dock** — đổi danh sách/preset rồi restart Dock, ví dụ DockFlow và một phần Dockset.
3. **App-owned Dock/Shelf chạy song song** — ví dụ ExtraDock, CoolDock, Another Dock, Dockside.
4. **App-owned Dock replacement** — dựng thanh mới và đẩy Apple Dock vào auto-hide/delay, ví dụ DockDoor Pro, DockFix, Sidebar, uBar. Đây là nhóm có chi phí parity và QA cao nhất.

## 3. Bản đồ thị trường

### 3.1 Năm niche chính

| Niche | Người dùng mua để giải quyết gì? | Đối thủ tiêu biểu | Mức liên quan tới DockMagic |
| --- | --- | --- | --- |
| Native-looking Dock replacement | Muốn Apple Dock nhưng đẹp hơn, nhiều setting, preview và widget hơn | DockDoor Pro, DockFix, DockApp, ActiveDock | Cao nếu DockMagic làm replacement; thấp hơn với Dock Active |
| Windows/taskbar workflow | Muốn nhìn từng cửa sổ, title, grouping và taskbar trên mọi màn hình | uBar, Sidebar, boringBar, Mac Taskbar | Không nên cạnh tranh |
| Multi-Dock/context launcher | Muốn Dock riêng theo màn hình, Space, project hoặc workflow | ExtraDock, MultiDock, SpeedDock, Dock Float, Dock Star | Chỉ liên quan đến placement/Shelf |
| Native Dock organization | Muốn giữ Apple Dock nhưng có profile, folder/group, shortcut hoặc preview | DockFlow, DockView, DockPops, Otterdock, FolderDock, DockGroups | Cạnh tranh ở trust và low-friction |
| Status/widget Dock | Muốn dữ liệu live, widget, AI usage và action ngay ở mép màn hình | Dockset, CoolDock, DockDoor Pro, DockX | Đối thủ trực tiếp nhất |

### 3.2 Danh mục paid-market phát hiện được

Giá dưới đây là giá vào cửa hoặc gói cá nhân phổ biến tại ngày nghiên cứu; không quy đổi tiền tệ và không coi sale là giá vĩnh viễn.

| Sản phẩm | Niche chính | Giá tham chiếu | Quan hệ với Apple Dock | Ghi chú chiến lược |
| --- | --- | ---: | --- | --- |
| [DockDoor Pro](https://pro.dockdoor.net/) | Full replacement + widgets + window manager | $20 một lần / 3 Mac | App-owned replacement | Đối thủ breadth mạnh nhất; marketplace đã có Codex/System widgets |
| [DockFix](https://www.dockfix.app/) | Native-looking replacement + theme | €14.99 một lần | App-owned replacement | Mạnh ở personalization/community presets |
| [DockApp](https://dockapp.app/) | Replacement + preview + snapping | $9.99 early-bird | App-owned replacement | Giá thấp, chỉ macOS 26+/Apple Silicon |
| [Sidebar](https://sidebarapp.net/) | Taskbar/window management | €19.99 lifetime | App-owned replacement | Sản phẩm trưởng thành, settings rất sâu |
| [ActiveDock 2](https://noteifyapp.com/activedock/) | Dock/Launchpad replacement | từ $19.99 | App-owned replacement | Window preview, groups, themes, Start Menu |
| [uBar](https://ubarapp.com/) | Windows-style taskbar | $30 personal | App-owned replacement | Tồn tại từ 2009; window-centric rõ nhất |
| [boringBar](https://boringbar.app/) | Taskbar theo Space | $29.99 perpetual | App-owned replacement | Current-desktop windows, desktop switcher |
| [Mac Taskbar](https://mac-taskbar.com/) | Windows-style taskbar | $9.90 một lần | App-owned replacement | 1–4 rows/display, badges và media controls |
| [Dockish](https://appish.app/blog/dockish-is-out) | Native-like replacement | $6.99 một lần | App-owned replacement | Multi-monitor và iPhone-style folders |
| [MaxiDock](https://maxidock.macupdate.com/) | Multiple/custom docks | $19 một lần | App-owned replacement/add-on | Traction/review công khai còn yếu |
| [ExtraDock](https://extradock.app/) | Multi-monitor/multiple docks | từ $14.99/1 năm | Song song hoặc replacement | Đối thủ rất mạnh nếu Shelf thành launcher tổng quát |
| [CoolDock](https://cooldock.app/) | Second Dock chứa widget | từ $14.99/1 năm | Song song hoặc gần-replacement | Catalog AI/system/productivity rất rộng |
| [Another Dock](https://anotherdock.ahrisy.com/) | Second Dock tối giản | $5 Pro | Song song | Unlimited items/groups; giá rất thấp |
| [MultiDock 2](https://noteifyapp.com/multidock/) | Panels theo context | Paid sau trial | Song song | Apps/files/folders, tabs, groups, nhiều panel |
| [SpeedDock](https://speeddock.app/) | Multiple dock launcher | khoảng $9.99 | Song song | Float/edge, Space/display, tabs và hotkeys |
| [Dock Float](https://apps.apple.com/us/app/dock-float-dock-companion/id6761350104?mt=12) | Context-aware multiple docks | $6.99 | Song song | Group, Flow, file shelf và iOS remote |
| [Dock Star](https://dockstar.app/) | Desktop docks/scenes | $20 | Song song | DragThing-style; apps/files/folders/Shortcuts |
| [DockThings](https://apps.apple.com/us/app/dockthings/id6748681978?mt=12) | Tile launcher | $9.99 | Dock-like companion | Adjacent hơn là đối thủ trực tiếp |
| [Dockset](https://dockset.app/) | Apple Dock profiles + Custom Dock widgets | từ $14.99 early-bird | Hybrid | Đối thủ trực tiếp nhất về profile + AI widget + Shelf |
| [Dockify](https://offfwhite.design/dockify) | Native Dock presets + widgets | $9.99 / 1 Mac | Giữ Apple Dock | Focus/network/Shortcuts automation |
| [DockFlow](https://dockflowapp.io/pricing) | Native Dock presets | từ $14.99/1 năm | Giữ Apple Dock | Native Dock + Focus/Shortcut/hotkey workflow |
| [DockView 2](https://noteifyapp.com/dockview/) | Window preview cho Apple Dock | $14.99 | Tăng cường Apple Dock | Giữ mental model native, xin AX/Screen Recording |
| [DockX](https://dockx.app/) | Live status trong Dock tile/menu bar | $3.99 Pro lifetime | Tile của chính app | Đối thủ trực tiếp nhất của generic Dock Active |
| [DockPops](https://dockpops.com/) | App/file folders trong Dock | $1.99 Premium | Nhiều tile của app/companion | Giá sàn cho organization; freemium rõ ràng |
| [Otterdock](https://otterdock.savetimefor.fun/en) | Workflow groups trong Dock | $6.99 Pro | Giữ Apple Dock | Direct và App Store có capability khác nhau |
| [FolderDock](https://apps.apple.com/us/app/folderdock/id6764864120?mt=12) | iOS-style folders | $2.99 | Nhiều Dock icons | Niche hẹp, proposition rất dễ hiểu |
| [TinyFolder](https://tinyfolder.app/) | Custom app folders | $21 lifetime / 2 Mac | Tile/folder của app | Design Studio, preset và keyboard shortcut |
| [DockGroups](https://www.dockgroups.com/) | Workflow app groups | $9.99 Pro | Group có Dock icon riêng | Launch/close whole group; free tier đủ thử |
| [Dockside](https://thedockside.app/dockside-app) | File shelf cạnh Dock | $5.99 lifetime | Companion cạnh Dock | Niche hẹp nhưng giải quyết job rất cụ thể |
| [DockLock Plus](https://apps.apple.com/us/app/docklock-plus/id6743010619?mt=12) | Lock/automate Dock display | $39.99 lifetime | Điều khiển Apple Dock | Multi-monitor pain có willingness-to-pay cao |
| [DockSolo](https://docksolo.com/) | Ghim Dock vào một màn hình | €4.99 lifetime | Điều khiển Apple Dock | Một pain duy nhất, thông điệp cực rõ |
| [cDock](https://www.macenhance.com/cdock) | Legacy Dock theming | từ $9.99 | Can thiệp legacy | Cũ, yêu cầu giảm bảo vệ hệ thống; không phải benchmark tương lai |
| [DockMate](https://www.macenhance.com/dockmate) | Legacy Dock previews | từ $14.99 | Tăng cường Apple Dock | Bản cuối 2021; nhu cầu preview vẫn còn nhưng implementation cũ |

### 3.3 Watchlist không tính vào paid-market hiện tại

- [Docky](https://www.getdocky.com/) — replacement native-feeling nhưng đã chuyển thành free/open source.
- [docktor](https://docktorapp.com/) — widget cạnh Dock, hiện miễn phí; terms nói có thể có paid feature sau.
- [Dockspace](https://getdockspace.app/) — widget Dock miễn phí tại thời điểm kiểm tra.
- [Taskbar by Lawand](https://lawand.io/taskbar/) — miễn phí tới 19/12/2026, sau đó dự kiến $25 một lần.
- [Superdock](https://www.superdock.site/) — $5.99 dự kiến nhưng chưa phát hành.

## 4. Những gì người dùng thực sự trả tiền để giải quyết

### 4.1 Sáu pain cluster lặp lại

| Pain | Evidence qua sản phẩm | Mức bão hòa | Cơ hội DockMagic |
| --- | --- | --- | --- |
| Không chọn được đúng cửa sổ từ Dock | DockDoor, Sidebar, uBar, DockFix, DockApp, DockView | Rất cao | Không tham gia |
| Dock quá dài, không có folder/group | DockPops, FolderDock, TinyFolder, Otterdock, DockGroups, Dockish | Rất cao | Không tham gia |
| Dock chỉ ở một màn hình/khó kiểm soát display | ExtraDock, uBar, Sidebar, Dockish, DockLock Plus, DockSolo | Cao | Chỉ bảo đảm status surface đặt đúng màn hình |
| Muốn theme/icon/animation riêng | DockFix, DockDoor, Sidebar, DockApp, DockX | Rất cao | Chỉ cho tùy biến signal có giới hạn |
| Cần app/file/folder theo workflow | ExtraDock, MultiDock, DockFlow, Dockify, Dock Star, Dock Float | Cao | Không biến thành launcher |
| Phải mở nhiều app/dashboard để biết trạng thái | Dockset, CoolDock, DockDoor widgets, DockX | Đang tăng nhanh | **Cơ hội chính, nhưng phải đi sâu developer/AI** |

### 4.2 Willingness-to-pay và packaging

- Utility hẹp/freemium thường neo ở **$1.99–$9.99**.
- Native Dock manager hoặc replacement phổ thông tập trung ở **$14.99–$20**.
- Taskbar/window-management trưởng thành lên tới **$30–$50**.
- Thị trường thiên mạnh về **mua một lần**; một số vendor bán permanent license nhưng chỉ kèm một năm update. Subscription thuần túy không phải chuẩn category.
- Trial thật là lợi thế: DockFix, Sidebar, uBar, boringBar có 7–14 ngày; DockDoor Pro/CoolDock/Dockset/DockApp dựa nhiều hơn vào refund window.

Hệ quả: DockMagic không thể biện minh giá chỉ bằng “nhiều widget”. Giá trị phải gắn với một outcome chuyên môn: giảm context switch, không bỏ lỡ agent, quota, build hoặc review cần xử lý.

## 5. Deep-dive cạnh tranh

### 5.1 DockDoor Pro — breadth leader

- $20/3 Mac, 300+ settings, profiles/per-display, live previews, window actions, file tray, widgets và marketplace.
- Marketplace đã có Codex Usage, Codex Tracker, CPU/Memory và Network Monitor.
- Lợi thế: free DockDoor có khoảng 6.1k GitHub stars làm funnel; native SwiftUI/AppKit; tốc độ ship nhanh.
- Rủi ro: product còn trẻ, full replacement khó ổn định, cần Screen Recording/Accessibility/Automation; widget native bundle mở thêm security surface.
- Hàm ý: DockMagic không thể thắng bằng “có widget Codex”. Phải thắng bằng multi-provider semantic, provenance, history, attention state và action sâu.

### 5.2 DockFix — personalization leader

- €14.99 lifetime, 7-day full trial, all future updates và dùng trên mọi Mac cá nhân theo pricing hiện tại.
- Mạnh ở theme, opacity, animation, custom icons, community presets, window preview, file shelf.
- Rủi ro: native Dock vẫn tồn tại bên dưới; Mission Control/fullscreen/restore defaults và permission messaging còn edge case.
- Hàm ý: không đầu tư theme marketplace/custom app icon; dùng “giữ Apple Dock nguyên bản” làm trust proposition.

### 5.3 ExtraDock — multi-monitor leader

- Nhiều Dock độc lập, mỗi màn hình/Space/workflow có app, folder, file và widget riêng.
- Hệ widget đã có CPU/GPU/RAM, battery, timer, Stripe, file shelf và Live Dock mirror.
- Rủi ro: không thể đạt parity badge/Handoff/reserved work area; permission footprint rộng; pricing phức tạp.
- Hàm ý: Shelf generic sẽ bị ExtraDock áp đảo. Shelf của DockMagic chỉ nên là status strip chuyên ngành.

### 5.4 Dockset và CoolDock — đối thủ trực tiếp nhất

Dockset kết hợp native Apple Dock profiles với Custom Dock chứa app/widget; CoolDock là second Dock/dashboard với catalog tích hợp rất rộng. Cả hai đã có Codex, Claude và nhiều AI/provider widgets.

Điểm yếu chung:

- Sản phẩm rất mới và đang mở rộng nhanh.
- Breadth lớn tạo rủi ro data semantics, API maintenance, permission và UX inconsistency.
- Widget chỉ sống trong app-owned surface, không nằm trong Apple Dock thật.
- Không có bằng chứng public mạnh về retention hoặc paid scale.

Khoảng trống DockMagic:

- Dock Active nằm trong Apple Dock thật.
- Không đọc cookie/private endpoint; ưu tiên CLI/status-line/public integration.
- Missing/stale/partial là first-class state.
- Tập trung attention/action thay vì widget catalog.

### 5.5 DockX — đối thủ trực tiếp của Dock Active phổ thông

- $3.99 lifetime, freemium, macOS 11+, App Store và direct.
- Trùng CPU, RAM, network, battery, storage, weather, clock và custom Dock tile.
- Không có dashboard sâu, history, domain semantics hay workflow action.
- Hàm ý: generic system monitor nên là onboarding/demo, không phải thông điệp bán hàng hay moat.

### 5.6 uBar và Sidebar — bài học không nên đi vào

Hai sản phẩm cho thấy willingness-to-pay thật cho window-centric workflow. Nhưng đổi lại là nhiều năm xử lý Accessibility, Screen Recording, app-specific AX behavior, Spaces, fullscreen, multiple displays, CPU/GPU và restore Apple Dock.

DockMagic không nên làm window previews, snapping, Start menu hay taskbar labels. Đây vừa là red ocean vừa làm loãng promise “glance, understand, act”.

### 5.7 DockFlow — native Dock vẫn có giá trị

DockFlow chứng minh người dùng trả tiền để giữ Apple Dock thật nhưng đổi context bằng preset, Focus, Shortcuts và hotkey. DockMagic không nên làm một profile manager khác; nên cung cấp App Intents/URL scheme để DockMagic tự đổi signal theo workflow và có thể sống bên trong mọi DockFlow preset.

### 5.8 DockPops và Dockish — organization đã thành commodity

DockPops bán iPhone-style app folders với paid tier chỉ $1.99; Dockish bán một native-like replacement có multi-monitor và folder với mức $6.99/7-day trial theo launch page. Đây là bằng chứng rằng app grouping/folder không tạo pricing power cho DockMagic. Mô hình nhiều native Dock tile bằng helper applet đáng nghiên cứu kỹ thuật, nhưng chi phí signing, notarization, cleanup và trust không phù hợp để trở thành ưu tiên hiện tại.

### 5.9 Dockside và DockLock Plus — thắng bằng một pain hẹp

Dockside tập trung sâu vào file staging/drop automation cạnh Dock; DockLock Plus chỉ giải quyết vị trí Dock trên multi-monitor. Hai sản phẩm củng cố một bài học: utility hẹp có problem statement rõ thường dễ mua hơn một “better Dock” chung chung. DockMagic nên áp dụng điều này vào developer attention, không sao chép file shelf hoặc Dock locking. Multi-monitor correctness vẫn là quality bar bắt buộc.

## 6. Niche DockMagic nên chiếm

### 6.1 Ideal customer profile

**Primary:** developer/tech lead/indie maker dùng từ hai AI coding tool trở lên, thường có terminal, IDE, GitHub/CI và deploy dashboard mở song song.

**Secondary:** power user cần theo dõi một số service có trạng thái quan trọng nhưng không muốn thêm menu bar clutter hoặc một Dock replacement.

Không phải ICP chính:

- Người chủ yếu muốn theme/icon/animation.
- Người cần Windows taskbar trên Mac.
- Người cần nhiều launcher/panel cho file và app.
- Người chỉ muốn CPU/RAM/weather/clock.

### 6.2 Problem statement

> Trạng thái AI agent, quota, build, PR và deploy đang phân tán giữa nhiều CLI,
> web dashboard và app. Developer phải context-switch chỉ để kiểm tra “có gì cần
> mình xử lý không”, dễ bỏ lỡ agent đang chờ hoặc workflow thất bại. DockMagic
> đưa đúng tín hiệu cần chú ý vào Apple Dock và mở thẳng nguồn xử lý, không thay
> Dock, không đọc nội dung nhạy cảm và không tạo thêm một dashboard phải quản lý.

### 6.3 Promise và nguyên tắc

**Promise:** `Glance. Know what needs you. Act.`

Nguyên tắc sản phẩm:

1. **Attention, not decoration.** Tile đổi khi ý nghĩa thay đổi, không chỉ vì số liệu dao động.
2. **Depth, not catalog size.** Ít integration nhưng có provenance, history, freshness và action.
3. **Apple Dock first.** Core value chạy mà không thay Dock hệ thống.
4. **Local and explicit.** Không đọc prompt/answer/token bí mật; từng quyền gắn với một lợi ích rõ.
5. **Bounded resources.** Chỉ provider được active/Shelf/dashboard quan tâm mới chạy.
6. **Safe missing states.** Không biến missing thành zero hoặc suy đoán quota.

## 7. Product strategy đề xuất

### 7.1 North-star experience

Trong ba giây, người dùng nhìn DockMagic và trả lời được:

- Có việc gì cần mình ngay không?
- AI quota/context còn an toàn không?
- Agent/build/review nào vừa hoàn tất hoặc thất bại?
- Nếu click/hover, mình sẽ đi đâu để xử lý?

### 7.2 P0 — củng cố lõi hiện tại

- Giữ Dock Active là default và hero trong onboarding/website.
- Tạo **Attention model** dùng chung: `normal`, `watch`, `needsAction`, `stale`, `unavailable`.
- Chuẩn hóa mọi snapshot với `source`, `observedAt`, `freshness`, `confidence/completeness`, `deepLink` và `recommendedAction`.
- Thêm một **AI Pulse** presentation tổng hợp nhiều provider thay vì bắt người dùng chọn từng provider liên tục.
- Tạo click-through/deep-link tới đúng Codex task, Claude session, repo, build hoặc provider page khi API/public contract cho phép.
- Viết compatibility/privacy matrix công khai cho từng integration.

### 7.3 P1 — developer operations wedge

Ưu tiên theo giá trị:

1. Agent/session: running, waiting for input, completed, failed, last activity.
2. Quota/context: remaining, reset time, pressure, anomaly và threshold.
3. GitHub/CI: PR cần review, checks fail, build/test status.
4. Deploy/service health: latest deploy, failure, rollback/incident link.
5. Calendar/on-call chỉ khi liên kết trực tiếp tới developer workflow.

Không ưu tiên mở rộng thêm weather/clock/media/finance nếu không phục vụ activation hoặc bundle completeness.

### 7.4 P2 — Status Shelf có giới hạn

- Tối đa mặc định 4 slot nhìn thấy; overflow có chủ đích.
- Mỗi slot phải là status signal có dashboard/action, không phải app icon launcher.
- Cho phép duplicate slot nếu phục vụ nhiều account/project nhưng identity phải độc lập.
- Profile theo project/focus có thể đến sau khi core signal chứng minh retention.
- Cờ feature mặc định tắt cho tới khi release matrix qua.

### 7.5 P3 — extensibility an toàn

Thay vì marketplace native bundle như DockDoor Pro, thử một adapter declarative:

- Local command/JSON/Shortcuts input.
- Schema giới hạn: identity, primary value, state, timestamp, detail rows, deep link.
- Timeout, resource budget, signature/path visibility và permission explanation.
- Không cho arbitrary in-process native code ở giai đoạn đầu.

Điều này cho phép cộng đồng nối CI nội bộ hoặc tool niche mà không biến DockMagic thành widget supermarket.

## 8. Những gì nên dừng hoặc đóng băng

### Không xây thêm

- Window preview/switcher/snapping/saved workspace.
- App launcher, Start menu, running-app mirror, Trash parity.
- Custom app icon catalog, theme marketplace, wallpaper và animation sticker.
- Generic file shelf/clipboard manager.
- Unlimited Dock/panel trên mọi màn hình.
- Integration chỉ để tăng số lượng mà không có semantic/action rõ.

### Custom Dock hiện tại

Không xóa công việc đã có, nhưng **đóng băng scope parity**. Chỉ tiếp tục nếu phục vụ Status Shelf và qua release gate. Nếu route handoff Apple Dock không đạt zero-overlap bằng public API trên matrix mục tiêu trong timebox, không quảng bá nó như replacement; quay về app-owned status strip cạnh Dock hoặc giữ internal/experimental.

## 9. Kế hoạch triển khai theo gate

### Phase 0 — 1 tuần: chốt định vị và đo baseline

- Phỏng vấn 8–12 developer dùng ít nhất hai AI coding tools.
- Ghi lại số lần/ngày họ mở CLI/web để kiểm tra quota/agent/build.
- Đặt telemetry local-first/opt-in cho activation, feature use và error class; không thu prompt/answer/path nhạy cảm.
- Chốt 3 event thành công: `noticed`, `openedAction`, `resolved/returned`.

**Gate:** ít nhất 60% người được phỏng vấn gặp pain hàng ngày; ít nhất 5 người đồng ý thử build trong workflow thật.

### Phase 1 — 2–3 tuần: AI Pulse MVP

- Attention model và normalized provider snapshot.
- Codex + Claude Code + Antigravity trong một tile tổng hợp.
- Hover dashboard: quota/reset, agent state, freshness và action.
- Local notification chỉ cho `needsAction`, có quiet hours.

**Gate:** median time-to-understand < 3 giây; ≥30% active days có hover/action hữu ích; false alert < 5% trong cohort thử.

### Phase 2 — 2–4 tuần: action loop

- Deep link tới đúng task/session/provider.
- GitHub PR/check status; sau đó một CI/deploy integration phổ biến dựa trên user cohort.
- Threshold/policy theo user, nhưng có preset tốt để không tạo settings overload.

**Gate:** ≥25% alert dẫn tới action; ≥40% tester giữ ít nhất hai integration active sau 14 ngày.

### Phase 3 — song song, timebox 2 tuần: Shelf release gate

- Không thêm feature parity mới.
- Đóng các gap đã biết: non-pointer Dock reveal/handoff, macOS 14/15, Spaces, Stage Manager, fullscreen, sleep/wake, Dock restart, Developer ID notarized/stapled clean Mac.
- Đo CPU, memory, wakeups và provider request rate với Shelf off/on.

**Gate:** không overlap/chặn click trong matrix; safe fallback luôn trả về Dock Active; full relevant suite xanh hoặc failure được quarantine có lý do. Không đạt timebox thì Shelf tiếp tục experimental.

### Phase 4 — packaging và launch

- Free: Dock Active + system demo + một integration chuyên sâu.
- Pro: nhiều provider, history/alerts/action, AI Pulse và Status Shelf khi đủ gate.
- Mức giá thử nghiệm hợp lý: **$14.99–$19.99 one-time launch** cho 1–3 Mac, kèm một năm update; grandfather early adopters. Chỉ cân nhắc subscription nếu có server/API cost thực và giá trị liên tục đã được chứng minh.
- Bắt đầu bằng free trial 7–14 ngày hoặc freemium đủ thấy core value; tránh purchase-first/refund-only.

## 10. KPI và tiêu chí quyết định

### Activation

- Cài xong và có signal thật đầu tiên trong < 3 phút.
- Tỷ lệ kết nối ít nhất một AI provider.
- Tỷ lệ người giữ DockMagic tile trong Dock sau 7 ngày.

### Retention/value

- Weekly active days có signal được xem.
- Số `needsAction` chính xác trên mỗi user/week.
- Tỷ lệ hover/click dẫn tới deep-link/action.
- Số lần tránh mở dashboard thủ công, tự báo cáo trong cohort.

### Trust/quality

- False alert, stale display và missing-as-zero: mục tiêu bằng 0 cho lỗi semantic nghiêm trọng.
- Crash-free sessions, CPU idle, wakeups và network requests/provider.
- Permission denial/revoke luôn có safe fallback.
- Support tickets theo OS/display/provider.

### Kill criteria

- Nếu user chủ yếu dùng Weather/Clock/CPU nhưng không dùng AI/developer signal sau 30 ngày, định vị chưa đúng hoặc ICP quá hẹp.
- Nếu AI provider contracts thay đổi làm dữ liệu thường xuyên stale/sai mà không có nguồn chính thức, không quảng bá signal đó là first-class.
- Nếu Shelf không qua release matrix bằng public API, không tiếp tục đầu tư replacement parity.
- Nếu adapter cộng đồng không thể sandbox/resource-bound hợp lý, giữ integrations first-party.

## 11. Kết luận cuối

DockMagic đang đứng trước hai con đường:

1. Trở thành một Dock replacement nhiều tính năng — thị trường đông, giá bị neo thấp, quyền rộng và chi phí compatibility vĩnh viễn.
2. Trở thành lớp attention/observability đáng tin cho developer và AI workflow — hẹp hơn, khác biệt hơn và phù hợp trực tiếp với năng lực hiện có.

Nghiên cứu ủng hộ rõ ràng con đường thứ hai. Dock Active là moat phân phối/UI; dữ liệu semantic, trust và action loop mới là moat sản phẩm. Shelf chỉ đáng làm khi nó khuếch đại moat đó, không phải khi nó biến DockMagic thành một launcher nữa.

## 12. Cách tổ chức team nghiên cứu

Ba research agent làm việc theo năm vòng; mỗi agent chỉ phân tích một sản phẩm trong một lượt để tránh trộn dữ liệu và kết luận. Tổng cộng có **14 deep-dive hoàn tất** và một lượt Another Dock bị dừng do quá thời gian; agent chính hoàn thiện mục đó ở mức fact sheet từ website chính thức. Mọi kết quả sau đó được đối chiếu với storefront và tài liệu/QA hiện có của DockMagic.

| Agent stream | Sản phẩm đã phân tích |
| --- | --- |
| Replacement/widget stream | DockDoor Pro, CoolDock, Sidebar, DockFlow; Another Dock ở mức fact sheet |
| Native/status/organization stream | DockFix, Dockset, DockX, DockPops, Dockish |
| Multi-Dock/workflow stream | ExtraDock, DockApp, uBar, Dockside, DockLock Plus |

Các sản phẩm còn lại trong inventory được rà soát ở mức fact sheet để phủ thị trường. Kết luận chiến lược chỉ được đưa ra khi pattern lặp lại qua nhiều stream và khớp với bằng chứng kỹ thuật trong repo.

## 13. Nguồn nền tảng

- [Apple — Desktop & Dock settings](https://support.apple.com/en-nz/guide/mac-help/mchlp1119/mac)
- [Apple — `NSDockTile`](https://developer.apple.com/documentation/appkit/nsdocktile)
- [DockMagic Custom Dock implementation QA](CUSTOM_DOCK_IMPLEMENTATION_QA_2026-09-21.md)
- [DockMagic Custom Dock Gate 0 QA](CUSTOM_DOCK_GATE0_QA_2026-09-20.md)
- [DockMagic Dock Active/Shelf technical research](research/dockmagic-shelf/dockset-modes-2026-09-20.md)
