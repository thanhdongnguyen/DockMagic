# DockMagic

DockMagic là ứng dụng macOS biến icon của chính ứng dụng trên Dock thành một
màn hình trạng thái nhỏ, cập nhật trực tiếp. Ứng dụng không tạo status item ở
menu bar; click icon Dock hoặc nhấn `⌘,` sẽ mở cửa sổ Settings duy nhất.

## Tính năng hiện tại

- `CPU & RAM`: vòng ngoài là CPU toàn hệ thống, vòng trong là RAM đang dùng;
  lấy mẫu local ở `1 Hz`.
- `Network`: chart băng thông của primary network interface, upload ở phía trên
  và download ở phía dưới baseline. Hai hướng dùng chung thang tuyến tính tự
  nâng theo traffic; Dock giữ 30 mẫu gần nhất, Settings giữ 60 mẫu ở `1 Hz`.
- `Storage`: một vòng thể hiện dung lượng đã dùng của startup volume, tính từ
  total trừ available capacity và cập nhật local mỗi 5 giây.
- `Weather`: nhiệt độ và biểu tượng điều kiện thời tiết được render riêng cho
  kích thước Dock `32...128 pt`; tile lớn thêm nhiệt độ cao/thấp. DockMagic dùng
  Current Location của macOS và gọi Open-Meteo mỗi 10 phút khi Weather active,
  đồng thời giữ kết quả gần nhất nếu refresh lỗi.
- `Codex`: vòng ngoài là quota 5 giờ còn lại, vòng trong là quota tuần còn lại.
  DockMagic gọi `codex app-server --stdio` bằng Codex CLI đã cài và phiên đăng
  nhập hiện có. Nếu tài khoản không trả về cửa sổ 5 giờ, UI chỉ hiển thị vòng
  tuần thay vì suy đoán dữ liệu.
- `Claude Code`: hai vòng có cùng ý nghĩa 5 giờ/tuần. DockMagic dùng contract
  `statusLine` chính thức của Claude Code và cache local riêng object
  `rate_limits` sau mỗi response. Bridge được bật/tắt rõ ràng trong Settings,
  giữ nguyên command status line cũ và không gọi endpoint OAuth nội bộ.
- `General`: chọn chính xác một tính năng được chạy và hiển thị ở Dock.
- Mỗi renderer có appearance riêng: hai vòng cho CPU/RAM và quota, hai màu
  series cho Network, một vòng cho Storage. Thay đổi được persist và áp dụng
  ngay vào Dock khi tính năng đó đang active.
- Toàn bộ Settings dùng Light appearance cố định và semantic design system.

Màu mặc định của cả hai vòng Claude Code là coral `#D97757`, lấy trực tiếp từ
logo Claude Code được cung cấp; người dùng vẫn có thể đổi từng vòng độc lập.

## Privacy và phân phối

DockMagic hướng tới phân phối trực tiếp, không phải Mac App Store. CPU/RAM,
Network và Storage chỉ được xử lý trên máy; history Network chỉ sống trong bộ
nhớ và không được persist. Weather gửi tọa độ hiện tại qua HTTPS tới Open-Meteo
và chỉ lưu snapshot thành công cuối cùng để chịu lỗi, không lưu lịch sử vị trí.
Người dùng cấp quyền Location trực tiếp cho DockMagic qua prompt chuẩn của macOS.
Với Codex, DockMagic không đọc
hay lưu token, prompt hoặc account identifier; nó chỉ đọc rate-limit response
do Codex CLI trả về. Với Claude Code, cache
`~/.claude/dockmagic-usage.json` chỉ chứa `rate_limits`; app không đọc
transcript, OAuth token, API key hay Keychain.

App không cần Accessibility, Screen Recording, Full Disk Access hay quyền
administrator; riêng Weather cần Location và mạng. Trước khi phát hành cần
Developer ID signing, Hardened Runtime, notarization, stapling và Gatekeeper
smoke test trên máy sạch.

## Yêu cầu phát triển

- macOS 14.0+
- Xcode 15.4+
- Swift 5
- Location Services và kết nối mạng chỉ cần thiết nếu dùng mặt Weather; xem
  [contract Open-Meteo](docs/WEATHER_OPEN_METEO.md)
- Codex CLI chỉ cần thiết nếu dùng mặt Codex
- Claude Code CLI chỉ cần thiết nếu dùng mặt Claude Code; `rate_limits` cần
  subscription được Claude Code hỗ trợ và một response sau khi bật bridge

Đây là Xcode project, không phải Swift Package.

## Build và chạy

Từ thư mục gốc:

```bash
./script/build_and_run.sh
./script/build_and_run.sh --verify
```

Build độc lập, không ký:

```bash
xcodebuild \
  -project DockMagic/DockMagic.xcodeproj \
  -scheme DockMagic \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DockMagicDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Unit tests và UI tests nên dùng derived data riêng để tránh `build.db` contention.
Unit tests có thể build unsigned:

```bash
xcodebuild \
  -project DockMagic/DockMagic.xcodeproj \
  -scheme DockMagic \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DockMagicUnitTests \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DockMagicTests \
  test
```

UI tests trên macOS phải dùng một Apple Development signing identity hợp lệ;
không thêm `CODE_SIGNING_ALLOWED=NO`, vì AppleSystemPolicy sẽ chặn XCUI runner:

```bash
xcodebuild \
  -project DockMagic/DockMagic.xcodeproj \
  -scheme DockMagic \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/DockMagicUITests \
  -only-testing:DockMagicUITests \
  test
```

Xem [contract Weather Open-Meteo](docs/WEATHER_OPEN_METEO.md),
[nghiên cứu Claude Code usage](docs/CLAUDE_CODE_USAGE.md),
[kiến trúc](docs/ARCHITECTURE.md) và
[design system](docs/DESIGN_SYSTEM.md) để biết ownership, data flow, trạng thái
Codex/Claude Code, lifecycle cửa sổ và contract UI/accessibility.
