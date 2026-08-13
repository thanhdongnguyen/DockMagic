# Weather Open-Meteo cho DockMagic

## Quyết định tích hợp

DockMagic được phân phối trực tiếp bằng Developer ID, không qua Mac App Store.
Weather dùng Core Location public của macOS để lấy tọa độ hiện tại rồi gọi trực
tiếp Open-Meteo Forecast API qua HTTPS. Người dùng không phải tạo Shortcut, cài
helper app hay đăng nhập tài khoản.

Open-access endpoint mặc định:

```text
https://api.open-meteo.com/v1/forecast
```

Một request lấy đủ current condition và daily summary:

```text
latitude=<lat>
longitude=<lon>
current=temperature_2m,apparent_temperature,weather_code,is_day
daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max
temperature_unit=celsius
timezone=auto
forecast_days=1
```

Các field này map vào `WeatherSnapshot`; `weather_code` dùng bảng WMO chính thức
của Open-Meteo. Nhiệt độ, xác suất mưa, tọa độ và HTTP response được validate
trước khi chạm UI.

Nguồn chính thức: [Open-Meteo Forecast API](https://open-meteo.com/en/docs),
[pricing/authentication](https://open-meteo.com/en/pricing),
[terms](https://open-meteo.com/en/terms) và
[CC BY 4.0 licence](https://open-meteo.com/en/licence).

## Authentication và licence

Build mặc định dùng open-access endpoint và không gửi API key. Theo điều khoản
hiện tại của Open-Meteo, endpoint này chỉ dành cho non-commercial use, dưới
10.000 API calls/ngày, 5.000/giờ và 600/phút; không có uptime guarantee.

Commercial plan dùng endpoint riêng:

```text
https://customer-api.open-meteo.com/v1/forecast?...&apikey=<key>
```

`OpenMeteoWeatherProvider` đã hỗ trợ inject customer endpoint và `apikey`, có
unit test cho query authentication. Trước khi phát hành DockMagic theo mô hình
commercial, product owner phải mua plan phù hợp và chọn cách cấp key. Key nhúng
trong desktop binary/Info.plist có thể bị trích xuất; proxy do DockMagic kiểm soát
là boundary bảo mật tốt hơn nếu cần giữ key bí mật.

Dữ liệu Open-Meteo là CC BY 4.0. Weather Settings luôn hiển thị link
`Open-Meteo · CC BY 4.0`; attribution này là product contract và không được loại
bỏ khi tinh giản UI.

## Location, polling và state

Khi người dùng mở Weather Settings hoặc chọn Weather làm active Dock feature,
DockMagic tự refresh. Lần refresh đầu gọi `requestWhenInUseAuthorization()` và
macOS hiển thị permission prompt dựa trên `NSLocationUsageDescription`; Settings
không có connection/setup form riêng. Khi được phép, app dùng one-shot
`requestLocation()` với accuracy ở mức ba kilomet, timeout sau 20 giây và không
chạy location tracking liên tục.

Core Location reverse-geocode tọa độ thành tên locality và country để hiển thị
trong hàng `Location` của Weather Dock preview. Nếu reverse geocoding không trả
về tên trong 3 giây, app hủy bước này và dùng locality suy ra từ timezone của
Open-Meteo trước khi fallback về `Current Location`; việc tìm tên không được giữ
toàn bộ vòng refresh vô thời hạn.

Nếu quyền chưa hợp lệ, request bị chặn trước provider nên không gọi Open-Meteo
và không gửi tọa độ. Khi người dùng cấp lại quyền trong System Settings rồi quay
lại DockMagic, Weather tự kiểm tra và refresh.

- Chỉ khi Weather là feature active, `WeatherStore` refresh ngay rồi poll mỗi
  10 phút (`600` giây).
- Sau khi Mac wake hoặc user session active lại sau unlock, Weather active được
  re-arm và refresh ngay thay vì đợi chu kỳ kế tiếp.
- Forecast request bỏ qua local URL cache và yêu cầu revalidation để mỗi chu kỳ
  đọc dữ liệu hiện tại từ provider.
- Nút refresh gọi cùng provider và được deduplicate với refresh đang chạy.
- Đổi feature hoặc quit sẽ cancel cả polling task và refresh/location request.
- Snapshot có `observedAt` cũ hơn 45 phút bị đánh dấu `stale`.
- Nếu refresh lỗi, snapshot thành công gần nhất vẫn hiển thị với clock badge.
- Chưa từng thành công thì Dock/Settings báo `unavailable`, không tạo dữ liệu giả.

## Privacy

Mỗi refresh gửi latitude/longitude hiện tại tới Open-Meteo qua HTTPS. DockMagic
chỉ persist snapshot đã chuẩn hóa để chịu lỗi; app không giữ location history,
API credential, prompt hay account identifier. Theo privacy terms của Open-Meteo,
server logs có thể chứa IP và tọa độ phục vụ troubleshooting và được xóa sau 90
ngày.

Cache Open-Meteo dùng namespace riêng; snapshot legacy từ Weather Shortcut không
được restore để tránh gắn attribution Open-Meteo lên dữ liệu Apple Weather cũ.

Người dùng có thể thu hồi quyền tại `System Settings > Privacy & Security >
Location Services`. Khi Location Services tắt hoặc quyền bị từ chối, Weather
preview hiển thị trạng thái Location tương ứng và cache cũ vẫn ở trạng thái stale
nếu có.

## Verification contract

- Unit: URL/query, free endpoint không key, paid endpoint có `apikey`, JSON
  current/daily, WMO mapping, time-zone conversion, invalid payload, HTTP error,
  cache/stale/dedup/cancel, Location permission preflight/recovery, location-name
  resolution và default polling 600 giây.
- Integration: gọi endpoint thật bằng tọa độ test công khai, không phụ thuộc
  permission của máy test.
- Runtime: launch app ký local, kiểm tra prompt Location, allow/deny flow,
  refresh thật và attribution trong Settings.
- Release: kiểm tra plan/licence, Developer ID, Hardened Runtime, notarization,
  Gatekeeper và pixel thật ở system Dock.

Offscreen renderer hoặc AX tree không thay thế việc quan sát pixel do system Dock
compositor tạo ra và kiểm tra VoiceOver thủ công trước release.
