# Augment API research examples

Tất cả số liệu và identity trong thư mục này là **synthetic**. Không có token,
response thật hoặc probe tài khoản.

- `requests/cost-query.json`: organization DAY query, không user filter/grouping.
- `fixtures/cost-day.json`: explicit zero ngày 14, ngày 13 missing, ngày 15 có dữ liệu.
- `fixtures/credit-day.json`: ví dụ nghiên cứu API credits; **không thuộc integration bản đầu**.
- `fixtures/empty-cost.json`: response rỗng hợp lệ, không suy usage bằng zero.

Executable parser/transport fixtures nằm trong `AugmentAnalyticsTests`; lifecycle/cache
tests trong `AugmentStoreTests`. `AugmentFixtures` chỉ có trong Debug, được inject bằng
`DockMagicUITesting` để render/UI test. Fixtures không chứng minh quyền truy cập hay
độ chính xác của dữ liệu tài khoản thật.

Xem [provider dossier](../AUGMENT_API_RESEARCH.md), [verification notes](../AUGMENT_USAGE.md)
và [API Reference](https://docs.augmentcode.com/analytics/api-reference).
