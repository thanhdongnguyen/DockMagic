# DockMagic input, chart và motion specification

> Historical research/proposal. The approved Maia implementation contract is
> [Design.md](../Design.md) and [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Earlier
> SF Pro, blue-action, glass and conflicting geometry recommendations are superseded.


Ngày: 17/09/2026.

**Trạng thái:** Font theo surface, color và background đã được người dùng
chốt trong [Design.md](../Design.md). Các thông số motion và hình thức
component ở tài liệu này là **đề xuất v1 để review**, chưa phải code đã chạy.
Không tự đổi toàn bộ UI khi chỉ được yêu cầu nghiên cứu.

## 1. Một component có quy chuẩn nghĩa là gì

Mỗi component có sáu phần: mục đích, anatomy/geometry, typography/color,
interaction states, data/validation states và mẫu tham chiếu. Component
`native` chỉ là nền API và hành vi; nó không tự quyết định mọi padding,
radius, density, axis hoặc error layout đúng cho DockMagic.

Khi triển khai cần có gallery dùng **cùng production component**, gồm Light,
Dark, Increased Contrast, Reduce Transparency, Reduce Motion, keyboard và
grayscale. Không dùng một mock nhìn đẹp nhưng khác code app làm bằng chứng.
Các minh họa font vòng trước chỉ kiểm tra typography, chưa phải gallery này.

### Những điều đã chốt, không mở lại trong proposal này

- Dashboard và Dock: SF Pro Rounded cho text; Settings: SF Pro.
- Settings preview của Dock giữ typography của production Dock renderer.
- Semantic `DesignTheme`, một họ action blue, nền neutral hiện tại.
- Không gradient/glow trang trí; data colors chỉ nằm trong plot/renderer.
- Unknown không trở thành zero; capability không được suy ra từ vẻ ngoài UI.

## 2. Motion của chart

### 2.1 Bảng event và transition

Các duration là lựa chọn thiết kế DockMagic. `easeInOut` dùng cho đổi hình
dữ liệu, `easeOut` dùng cho opacity/feedback. Không spring hoặc overshoot cho
giá trị định lượng. Mọi transition đều có thể bị ngắt, không khóa tương tác.

| Event | Transition và mapping | Axis, selection và kết thúc |
| --- | --- | --- |
| Mở panel, đã có dữ liệu cache | Render trạng thái cuối ngay, không vẽ line từ trái sang phải hoặc bar từ zero | Trục đúng ngay; không biến mỗi lần hover Dock thành intro |
| First load, chưa có dữ liệu | Giữ slot chart với label loading + native progress; khi có data, fade-in plot 160 ms | Không dựng graph placeholder như dữ liệu thật; chỉ cho inspect khi plot sẵn sàng |
| Giá trị thay đổi trong cùng bucket/series, cùng unit/domain | Morph 280 ms ease-in-out từ geometry đang hiển thị tới geometry mới; line giữ x, bar đổi đầu mút từ baseline | Stable ID = series + bucket timestamp; không tạo UUID mới ở mỗi refresh |
| Thêm điểm/bucket, topology và domain còn tương thích | Giữ các điểm đã có; fade-in mark/segment mới 160 ms ở tọa độ thật | Không mọc từ zero chưa từng đo; không tự cuộn nếu người dùng đang xem lịch sử |
| Data mới làm thay đổi domain hoặc cấu trúc đoạn/gap | Crossfade toàn nhóm plot + axes 180 ms | Hoán đổi scale, ticks và marks như một snapshot; không nội suy qua khoảng missing |
| Người dùng đổi range, metric, provider/model hoặc line/candle | Crossfade toàn chart + unit/range 180 ms | Không morph token thành USD hoặc bucket của hai timeframe thành nhau; giữ ID được chọn chỉ nếu còn cùng nghĩa và hợp lệ |
| Zoom/scroll bằng thao tác trực tiếp | Theo thao tác ngay; giữ behavior scrolling native | Không thêm easing chống lại tay/con trỏ; không để refresh reset viewport |
| Hover, keyboard inspect | Crosshair và giá trị theo selection ngay, không delay | Tooltip slot/anchor ổn định, không làm plot đổi kích thước |
| Refresh trả về cùng dữ liệu | Không animation | Chỉ cập nhật freshness thật nếu cần |
| Refresh thất bại nhưng còn data | Giữ chart cuối, đổi trạng thái stale/error và thời điểm | Không fade plot về zero; không rung cả card |
| Không còn dữ liệu đủ điều kiện | Thay chart bằng empty/unavailable trong cùng vùng bố cục | Không co bar xuống zero; lý do phải đọc được |
| Reduce Motion | Hiện snapshot cuối tức thì | Bỏ morph, slide và crossfade; còn focus, text status và timestamp |
| Panel offscreen/ẩn, app không trình bày chart | Không chạy display animation | Khi hiện lại dùng snapshot mới nhất, không phát bù hàng đợi |
| Dock renderer, Save/Copy/Share PNG | Frame cuối, không animation | Preview không được làm thay đổi kết quả raster/export |

Topology tương thích nghĩa là các mark tồn tại liên tục có cùng thứ tự/ID và
cùng cách mã hóa dữ liệu. Nếu không xác định được mapping an toàn, dùng
crossfade; không ép path interpolation chỉ vì trông mượt.

### 2.2 Giá trị, trục và dữ liệu realtime

- Store giữ observation thật. Giá trị trong frame chuyển tiếp chỉ là hình
  học để minh họa thay đổi; không ghi ngược vào model, tooltip, AX hoặc export.
- Summary và tooltip luôn dùng observation mới nhất đã nhận, không count-up
  qua hàng trăm giá trị giả. Nếu đang crossfade hai hệ trục, tạm bỏ inspect
  trên plot cũ, hoàn thành hoặc hủy transition ngay khi người dùng muốn inspect.
- Giữ ID selection theo timestamp/series. Khi bucket vẫn còn, refresh không
  nhảy selection sang bucket khác. Khi đổi unit/range làm selection vô nghĩa,
  clear selection và hiện summary đúng scope mới.
- Percentage có ý nghĩa 0-100 dùng domain cố định. Bar lượng sử dụng có zero
  baseline; trường hợp signed có baseline zero nằm trong domain. Price line
  có thể dùng domain động và phải có ticks rõ, không ép bắt đầu bằng zero.
- Domain động dùng các mốc tròn dễ đọc và headroom. Đề xuất mở rộng khi cần,
  giữ domain trong range đang xem khi max nhỏ đi; thu lại khi đổi range hoặc
  người dùng reset. Không co/giãn scale ở mỗi tick. Với cửa sổ trượt dài hạn,
  recompute domain khi phạm vi thời gian đổi và crossfade snapshot đồng bộ.
- Với nguồn refresh thưa (khoảng một giây trở lên), dùng morph 280 ms. Với
  stream dày, gom presentation snapshot tối đa khoảng 4 lần/giây (độ trễ
  do lớp render tối đa 250 ms), render ngay các snapshot đó; không chạy một
  morph 280 ms cho mỗi packet. Observation/history vẫn lưu theo acquisition
  contract, không bỏ data ở store để giảm motion.
- Bất kỳ feed nào cần độ trễ thấp hơn phải khai báo variant riêng; không áp
  giới hạn 250 ms âm thầm cho mọi provider. Chính sách này cần đo runtime.
- Khi một update đến giữa transition: retarget từ geometry đang trình bày
  hoặc hủy và hiện snapshot mới nhất; tuyệt đối không xếp hàng hoạt cảnh.
- Missing vẫn là gap suốt transition. Một điểm hợp lệ mới không cho phép
  nối qua missing khác. Partial có text/marker; không chỉ giảm opacity đến
  mức mark khó đọc.

### 2.3 Ranh giới SwiftUI

- Native `Swift Charts` phù hợp chart có axes/selection; renderer custom vẫn
  được dùng nếu có nhu cầu rõ và tuân thủ cùng contract. Không yêu cầu viết
  lại daily bar chart chỉ để đổi package.
- `.animation(..., value:)` phải scope theo **display snapshot**, tách khỏi
  hover/focus và layout của toàn dashboard. `value` chỉ phát động transaction,
  không tự bảo đảm geometry bất kỳ sẽ nội suy được.
- `Shape` custom cần mô hình `Animatable`/stable point mapping phù hợp. Snapshot
  khác topology không mặc nhiên morph đúng; dùng crossfade fallback.
- Domain/unit/topology là một phần của transition decision. Không chỉ so
  sánh array giá trị và để framework tự quyết.
- Token đề xuất: `chartValueChange` 280 ms, `chartDatasetChange` 180 ms,
  `chartMarkAppear` 160 ms. Đây là **tên cần bổ sung khi triển khai**, chưa có
  sẵn trong `DSMotion`. Native accessibility environment phải được kiểm tra.

## 3. Input specification

### 3.1 Anatomy và geometry

Áp dụng cho input do DockMagic sở hữu. Giữ text editing/selection/IME,
copy-paste, undo và accessibility của native `TextField`/`SecureField`.

| Phần | Giá trị đề xuất |
| --- | --- |
| Font Settings | SF Pro 14 pt regular, label 14 pt medium |
| Font nếu có input trong dashboard | SF Pro Rounded cùng role/cỡ |
| Single-line field | Min-height 36 pt, radius `DSRadius.control` 12 pt |
| Padding | Ngang 12 pt; dọc tối thiểu 8 pt, cho cao thêm nếu nội dung/font cần |
| Nền | `theme.opaqueSurfaceInset`, không blur/gradient |
| Border mặc định | `theme.outline`, 1 pt; Increased Contrast dùng `outlineStrong`, 1.5 pt |
| Label và helper | Label cách field 6 pt; helper/error 12 pt cách field 6 pt; khoảng giữa field groups 16 pt |
| Độ rộng | Field cùng loại căn chung cột; thường 280-420 pt trong Settings, không vượt available width; path/URL có thể full-width |
| Icon | SF Symbol 14 pt; leading chỉ khi giúp hiểu field; trailing là thao tác có tên AX |
| Trailing action hit area | Tối thiểu 28 x 28 pt cho pointer, nằm trong field 36 pt; không đè lên text |
| Multiline | Native multiline editor, cao đầu khoảng 88 pt/3 dòng; tăng tới 6 dòng rồi scroll nội bộ; không ép vào field 36 pt |

36 pt là min-height, không là fixed height. Radius/padding của custom wrapper
phải được tập trung thành token. Không giữ cả native bezel lẫn vẽ thêm một
border khiến input có hai viền. Nếu dùng `.plain` cho editor bên trong thì
wrapper chung phải cung cấp đầy đủ surface, focus và hit area.

### 3.2 State matrix

| State | Hình thức | Hành vi |
| --- | --- | --- |
| Empty | Placeholder là ví dụ, label vẫn hiện | Không dùng placeholder làm tên duy nhất của field |
| Default / filled | Border neutral, textPrimary | Không thêm check xanh chỉ vì có text |
| Hover | Border có thể lên `outlineStrong`; không đổi fill sang accent | Không scale hoặc di chuyển field |
| Focus | Một ring `theme.focus` 2 pt, reserve space/overlay không đổi layout | Tab order đúng; chỉ một focus indicator, không glow |
| Invalid, chưa focus | Border danger, icon + error rõ ở dưới | Không xóa input đã nhập; không báo đỏ trước khi người dùng tương tác |
| Invalid và focused | Giữ focus ring nhìn thấy; error icon/text dùng danger | Không dùng hai full chromatic fills; keyboard focus không biến mất khi lỗi |
| Validating | Indicator nhỏ ở trailing + helper đang kiểm tra | Không khóa nhập nếu có thể; hủy/ignore response cũ khi input đổi |
| Disabled | Role/appearance disabled tập trung, còn đọc được giá trị | Không editable, không focus/hover giả; có lý do khi cần |
| Read-only | Vẫn là text rõ; khác disabled | Có thể select/copy nếu tác vụ cần |
| Error mạng | Helper contextual + retry khi hợp lý | Phân biệt invalid format với không thể kiểm tra vì mạng |

Không dùng opacity tùy ý trên toàn group để tạo disabled. Placeholder và
helper phải qua contrast trên nền thật. Đề xuất v1 giữ label phía trên cho
text entry có helper/error; Toggle/Picker Settings vẫn dùng native row theo
composition hiện có.

### 3.3 Validation và variant

- API token/password dùng `SecureField`. Không log input, không hiển thị token
  trong tooltip/error. Reveal chỉ khi có nhu cầu được xác định, không mặc định.
- Validate cú pháp ở blur hoặc submit; lỗi đang hiển thị có thể được đánh giá
  lại khi sửa. Không phát request mạng trên mỗi phím; debounce/cancel theo
  tác vụ. Kết quả cũ không được gắn vào giá trị mới.
- Search: query thay đổi cập nhật theo nhịp phù hợp; clear button chỉ hiện khi
  có nội dung; giữ keyboard focus. Không biến empty search thành error.
- URL/path: helper nêu định dạng; trình chọn file native nếu tác vụ hỗ trợ.
  Nội dung dài scroll trong editor, không cắt mất prefix trong lúc sửa.
- Numeric: dùng parser/formatter theo locale, cho phép trạng thái đang nhập
  chưa hoàn chỉnh; commit chỉ khi hợp lệ. Không sửa caret bằng format lại
  toàn chuỗi ở mỗi phím.
- Không animate width/height hoặc shake field khi lỗi. Border phản hồi tối đa
  120 ms; helper xuất hiện trong bố cục ổn định, Reduce Motion đổi tức thì.

Đề xuất tạo một shared input wrapper với label/helper/error và slot action.
Tên kiểu/API sẽ chốt khi implementation; chưa có `DSTextInput` trong catalog
hiện tại. Không tạo các bản wrapper riêng ở từng provider.

## 4. Chart visual specification

### 4.1 Các variant cần phân biệt

| Variant | Geometry/mục tiêu | Axes và interaction |
| --- | --- | --- |
| Dashboard daily bars | Giữ column 46 pt + gap 8 pt, bar 27 pt; radius mark 3 pt là ngoại lệ chart đã có | Numeric y-axis, 3 grid lines, ngày/thứ; hover và keyboard inspect |
| Dashboard line/area | Plot-height mục tiêu 120 pt; compact 96 pt, detail 160 pt nếu cần thêm dữ liệu | 3-4 y ticks và khoảng 3-5 x ticks tùy width; nhãn không đè nhau |
| Dashboard candlestick | Cùng temporal domain với volume; hollow/filled phân biệt hướng | OHLC tooltip; không chỉ dựa vào đỏ/xanh |
| Dock chart | Hình học tỷ lệ với tile, giữ renderer production | Không nhét trục/tooltip như dashboard; label Rounded và kiểm tra ở kích thước thật |
| Export sparkline | Theo `AI_SHARE_ACTIVITY_CARD_LAYOUT.md` | Không thêm axes/legend/caption nếu contract export không có |

120/96/160 pt là **mục tiêu variant cần thử** trong panel thật, không phải
lý do tăng mọi chart đang tồn tại lên cùng chiều cao. Daily bars có viewport
riêng; không ép 30 ngày vào 7 slot hay thu chữ để vừa toàn range.

### 4.2 Marks và hierarchy

- Line chính 2 pt (compact 1.5 pt), round cap/join; linear interpolation mặc
  định. Không dùng smooth curve có thể vượt giá trị quan sát để làm đẹp.
- Area fill là tùy chọn, solid low-opacity, không gradient. Line là dấu hiệu
  đọc chính và phải đủ contrast; fill nhạt không mang thông tin duy nhất.
- Bar không viền trang trí; cùng baseline cho cùng measure. Zero có marker
  zero tại baseline hoặc label `0`, không tạo một bar dương có chiều cao giả.
- Grid neutral 0.5 pt, Increased Contrast 1 pt; khoảng 3 đường ngang là
  baseline. Không kẻ cả ô caro nếu không phục vụ đọc dữ liệu.
- Text Rounded: title 14 pt semibold, axis 11 pt regular, tooltip label 12 pt,
  tooltip value 14 pt semibold + tabular digits. Caption phụ không nhỏ hơn
  11 pt trong proposal này. Nếu chật, bớt tick/abbreviate có giải nghĩa.
- Padding plot đủ cho label dài nhất thực tế; không fixed-width axis rồi
  dùng `minimumScaleFactor` để che clipping. Đơn vị có thể ở title thay vì
  lặp trên mọi tick. Sắp xếp axis thống nhất giữa chart cùng module.
- Plot không có card/shadow riêng nếu đã ở panel/card. Group bằng title,
  metric, range và spacing. Data marks nổi hơn grid và chrome.
- Một series dùng một data color; hai series cần label/legend ổn định và
  cách phân biệt ngoài màu khi cần. User color vẫn được xử lý contrast trong
  renderer, không lan sang button/focus.

### 4.3 Inspect, tooltip và data states

- Line/candle crosshair theo vị trí thời gian, tooltip nêu rõ timestamp của
  sample thực đang chọn. Không trình bày giá trị nội suy như measurement.
- Daily bar chọn bucket, cả slot có hit area; `0` có thể inspect dù không có
  drill-down. Khả năng inspect khác khả năng mở chi tiết. Missing có thể
  được focus/read để biết thiếu dữ liệu nhưng không tạo action mở detail giả.
- Tooltip dùng nền opaque raised, radius 8 pt, padding 8-12 pt, outline;
  không glow. Clamp trong panel; không che mark đang chọn khi có chỗ thay thế.
- Tooltip gồm date/time + timezone nếu có ý nghĩa, giá trị, unit và
  partial/stale. Giá trị nguồn không bị rounded mất ý nghĩa; axis có thể rút gọn.
- First loading chưa có data: slot ổn định, label + progress. Refresh có
  cache: giữ data cũ và refresh status nhỏ. Không dựng fake peaks/bars loading.
- Empty: giải thích thiếu lịch sử và thao tác có ích. Missing sample: gap;
  known zero: zero. Partial: marker/text. Stale: giữ data + thời điểm.
- Keyboard phải inspect được data theo thứ tự thời gian; Escape bỏ inspect
  trước khi đóng panel theo interaction hiện có. Không làm VO đọc lại toàn
  chart ở mọi packet; cung cấp summary và giá trị theo yêu cầu.

## 5. Component khác và chất lượng hoàn thành

Button, select, segmented control, Toggle, Slider, card, badge, menu và
popover cũng cần cùng kiểu spec. V1 tập trung input/chart vì đó là vấn đề
được nêu. Chúng tiếp tục dùng shared/native components; không ngầm coi
catalog hiện tại đã có specimen được duyệt cho mọi state.

Khi triển khai v1, cần cung cấp:

1. Input gallery: empty, filled, focused, invalid, focused+invalid,
   validating, disabled, read-only, secure, multiline; chuỗi tiếng Việt dài.
2. Chart gallery: valid, all-zero, one point, missing gap, partial, stale,
   failed-with-cache, no data; cùng unit và đổi unit/range.
3. Bằng chứng motion chạy thực: data update cùng domain, đổi domain/range,
   interruption liên tiếp, hover trong refresh, Reduce Motion và hidden panel.
4. So sánh Light/Dark, Increased Contrast, Reduce Transparency, grayscale,
   keyboard/AX và clipping tại kích thước panel thật.
5. Migrate consumer về shared component và xóa style lặp trong phạm vi sửa;
   không chỉ thêm component đẹp vào gallery rồi giữ production như cũ.

Snapshot tĩnh không chứng minh motion. Build pass không chứng minh component
đẹp hoặc state đầy đủ. Mỗi handoff phải tách rõ spec, implementation và QA.

## 6. Căn cứ và giới hạn

Đã kiểm tra source: `AIUsageHistoryChart.swift` dùng custom bar geometry và
chưa khai báo animation cập nhật data; `BinancePriceChartView.swift` dùng
Swift Charts nhưng cũng chưa có data-update transition riêng. Settings có
field `.plain`, `.roundedBorder` và default; chưa có shared input wrapper.
Đây là bằng chứng chưa thống nhất, không thay thế visual audit app đang chạy.

Apple khuyến nghị chart có scale theo ý nghĩa, label/axis rõ và hỗ trợ nhận
biết thay đổi cho cả người tắt animation. Apple cũng hướng dẫn label/hint,
validation đúng lúc và native secure entry cho text fields. Các con số về
kích thước/thời gian trong proposal là lựa chọn DockMagic, không phải Apple
bắt buộc.

- [Apple HIG Charts](https://developer.apple.com/design/human-interface-guidelines/charts).
- [Apple HIG Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields).
- [Swift Charts](https://developer.apple.com/documentation/charts).
- [SwiftUI animation(_:value:)](https://developer.apple.com/documentation/swiftui/view/animation(_:value:)).
- [Apple HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion).
