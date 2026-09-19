# Augment Analytics API — nghiên cứu tích hợp DockMagic

**Status:** Implemented in working tree — đã build/runtime và kiểm chứng parser/store/render; chưa có live-account acceptance.  
**Verified:** 2026-09-16.  
**Evidence:** tài liệu chính thức và source DockMagic trong working tree. Chưa gọi API bằng tài khoản Enterprise. Kết quả build/runtime/UI được tách riêng trong AUGMENT_USAGE.md.  
**Scope:** nhập API token trong Settings; Dock, hover dashboard, usage, các loại token và history. Phạm vi đã chốt: Organization, USD + token components; Dock mặc định Input/Output và Numbers.

## 1. Khuyến nghị

Triển khai provider `augment` theo hướng **analytics có ghi rõ kỳ dữ liệu**. Người dùng nhập service-account API token trong Settings. Bản đầu theo dõi toàn tổ chức. Không có user filter, GROUP_BY_USER hoặc danh sách email; không suy danh tính tenant từ token.

Phần cần chốt trước release là ý nghĩa “token sử dụng hiện tại”: có thể hiển thị các loại token mới nhất đã nhận cùng ngày dữ liệu; chưa đủ chứng cứ để hứa bộ đếm realtime hay tổng token của hôm nay. Không dùng credits hoặc USD để suy ngược token.

Điều kiện tiếp cận là Enterprise và token do quản trị viên cung cấp. Việc một người xem được My Usage trên web không chứng minh người đó tự tạo được token Analytics. [Analytics API](https://docs.augmentcode.com/analytics/analytics-api), [Service Accounts](https://docs.augmentcode.com/cli/automation/service-accounts), [My Usage](https://docs.augmentcode.com/analytics/credit-dashboard-and-quotas#my-usage).

## 2. Bằng chứng API quan trọng

### Điều kiện và token

Analytics đang ở preview, dành cho Enterprise. Endpoint dùng `https://api.augmentcode.com` và Bearer token. Luồng tạo: mở Service Accounts → tạo service account → tạo API token → sao chép giá trị được hiển thị một lần. [Hướng dẫn chính thức](https://docs.augmentcode.com/analytics/analytics-api).

Chỉ tenant administrator quản lý service accounts; token không tự hết hạn theo tài liệu hiện tại. Xóa token trên Augment mới thu hồi nó; Disconnect trong DockMagic chỉ xóa bản lưu cục bộ. Service account có thể dùng cho automation nên không gọi token này là “chỉ đọc” khi chưa chứng minh được quyền phía server. [Vòng đời token](https://docs.augmentcode.com/cli/automation/service-accounts).

### Bản đồ giao diện dữ liệu

Các tên dưới đây là định danh schema để triển khai; số liệu trong fixtures là tự tạo.

| API | Dữ liệu cần dùng | Ràng buộc đáng chú ý |
| --- | --- | --- |
| `POST /analytics/v0/cost-analytics` | `cost_metrics.{input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,billed_amount_usd,estimated_customer_cost_usd}` | DAY/TOTAL; lọc user; nhóm resource/product/BYOK; 90 ngày/request, lookback 2 năm, page tối đa 1000 |
| `GET /analytics/v0/credit-usage-by-user` | `records[].{credits_consumed,date,model_name,user_email,service_account_name}` | `by_date`, `by_model`; đến hôm nay UTC; độ trễ khoảng 90 phút; page tối đa 500 |
| `GET /analytics/v0/daily-usage` | `daily_usage[].metrics` | Organization |
| `GET /analytics/v0/user-activity` | `users[].metrics` | Tổng theo user trong kỳ |
| `POST /analytics/v0/get-user-budget-overrides` | `overrides[].{resource,period,config.limit}` | Chỉ override |

Cost/credit: 30 request/phút. Cost/credit phân trang bằng `has_more` và `next_cursor`. Cost dùng decimal string cho tiền; token lớn có thể là string. Reference không xác lập cadence riêng cho cost hoặc công thức cộng cache thành total. Không có quota 5h/weekly, token balance, hourly/session history trong schema đã kiểm tra. [API Reference](https://docs.augmentcode.com/analytics/api-reference).

DAU/activity/usage thông thường là dữ liệu ngày UTC, công bố khoảng 02:00 UTC ngày sau. Không áp quy tắc chung này máy móc lên ngoại lệ credit. [Data availability](https://docs.augmentcode.com/analytics/analytics-api#important-considerations).

Usage dashboard phân biệt billing bằng USD và hợp đồng credits cũ. Budget có cấp tổ chức, mặc định user và override; enforcement là cấu hình riêng. Context Engine MCP hiện không xuất hiện trong dashboard; chưa xác lập coverage của API tương ứng. [Usage Dashboards & Budgets](https://docs.augmentcode.com/analytics/credit-dashboard-and-quotas).

Giá token có các loại input, output, cache read, cache write; chi phí có thể còn gồm compute và phí dịch vụ. Vì vậy đề xuất hiển thị chi phí provider trả về, không tự nhân token với bảng giá để dựng billing. [Token-Based Pricing](https://docs.augmentcode.com/models/token-based-pricing).

## 3. Capability dossier

Các cột dùng chung sau áp dụng cho **từng dòng** bên dưới, trừ ngoại lệ ghi tại dòng:

- **Conditions:** Enterprise Analytics access, API token hợp lệ; không cần Auggie CLI. Quyền từng endpoint phải được kiểm tra độc lập.
- **Provenance/evidence:** official public API, các link ở mục 2, kiểm tra tài liệu ngày 2026-09-16; không có live-account evidence.
- **Semantics:** Organization + khoảng ngày UTC; số đo used, không phải remaining. USD giữ nguyên đơn vị. Explicit zero khác missing.
- **Freshness/completeness:** F1 là cost/token (TTL local 6 giờ, mục 5); F2 là credit và F3 là activity bổ sung (chỉ nghiên cứu, ngoài implementation). Hoàn tất pagination không tự chứng minh dữ liệu upstream đã ổn định.
- **Privacy/distribution:** policy P1 ở mục 7; dữ liệu tổng hợp, không transcript; URLSession + Keychain riêng DockMagic, không yêu cầu App Store.
- **Fixture:** `augment-api-research/fixtures/cost-day.json`, `credit-day.json`, `empty-cost.json` cho schema lõi. Các capability ngoài MVP chưa có fixture vì chưa có adapter/UI được đề xuất ship; phải bổ sung trước khi bật module.

| Capability | Status | Giá trị / surface | Nguồn và trường | Semantics / điều kiện riêng | Freshness / coverage / fixture |
| --- | --- | --- | --- | --- | --- |
| `auth.connection` | supported, conditional | Settings kết nối/retry | HTTP response của cost query | Xác thực khả năng đọc; không chứng minh user identity | Probe khi Connect; AugmentAnalyticsTests |
| `identity.provider` | supported | Augment / logo | Đăng ký cục bộ | Chỉ identity thương hiệu | AugmentFixtures; logo official docs favicon |
| `identity.accountPlan` | unknown | Không hiện tên tenant/gói suy đoán | Chưa có identity/plan endpoint trong tập tài liệu | Không suy tên tenant hoặc chủ token | Omit |
| `tool.presence` | unsupported trong flow API | Không có Install CLI | Không phụ thuộc local tool | Không đọc session của Auggie | N/A |
| `usage.daily.input` | supported, conditional | Dashboard/detail; Dock mặc định IN/OUT | `cost_metrics.input_tokens` | Giữ riêng loại token | F1; cost fixture |
| `usage.daily.output` | supported, conditional | Dashboard/detail; Dock mặc định IN/OUT | `cost_metrics.output_tokens` | History mặc định Output; Dock giữ IN/OUT cùng ngày | F1; cost fixture |
| `usage.daily.cacheRead` | supported, conditional | Token detail | `cost_metrics.cache_read_tokens` | Không tự cộng vào input | F1; cost fixture |
| `usage.daily.cacheWrite` | supported, conditional | Token detail | `cost_metrics.cache_write_tokens` | Không tự cộng vào input | F1; cost fixture |
| `usage.daily.total` | unknown | Chưa có metric Total tokens | Không có total field đã xác lập | Chờ xác nhận quan hệ bốn loại token | Omit, không chế công thức |
| `usage.current.realtime` | unknown | Không gắn nhãn Live tokens | Cadence/today của cost cần xác nhận | “Latest reported”, ngày chính xác | Live probe bắt buộc nếu muốn bật |
| `usage.history` | supported, conditional | 7/30/90 ngày, chi tiết ngày | Cost DAY | Lịch sử tổng hợp usage, không lịch sử hội thoại | F1; gap/zero fixtures |
| `usage.lifetime` | unknown | Không có Lifetime | Range hữu hạn không phải lifetime | Dùng “Selected period” | Omit |
| `cost.billedUSD` | supported, conditional | Dock/dashboard/history | `billed_amount_usd` | Chi phí được provider báo; không phải balance | F1; Decimal |
| `cost.estimatedUSD` | supported, conditional | Detail khi hữu ích | `estimated_customer_cost_usd` | Nhãn Estimated riêng, không thay billed | F1; Decimal |
| `usage.credits` | supported, conditional | Ngoài scope bản đầu | Credit records | Chưa có adapter hoặc UI credits | F2; credit fixture |
| `usage.model` | supported, conditional | Tối đa 3 model + detail | Cost RESOURCE | Lọc resource là model; xếp theo metric đã chọn | F1; AugmentAnalyticsTests + AugmentFixtures |
| `usage.product` | supported, conditional | Detail tùy chọn | Cost PRODUCT | Không mặc định chỉ CLI | F1; phase sau |
| `usage.messages` / `usage.toolCalls` | supported, conditional | Activity detail tùy chọn | Daily usage / user activity metrics | Cùng target/range; không gọi số tool calls là tool tokens | F3; ngoài MVP lõi |
| `quota.window` / `quota.remaining` | unsupported qua API đã xét | Omit ring, reset countdown | Không có nguồn phù hợp | Budget override không đủ dựng quota khả dụng | N/A |
| `budget.override` | supported, conditional | Chỉ nghiên cứu read-only detail | `config.limit`, `resource`, `period` | Không có override không có nghĩa unlimited | Ngoài MVP |
| `detail.hourly` / `work.active` | unsupported qua API đã xét | Omit hourly/tasks/goals/context | Không có nguồn phù hợp | Daily buckets không thể tách giờ | N/A |
| `usage.reasoning` / `usage.toolTokens` | unknown | Omit token detail tương ứng | Chưa xác lập field | Không mượn semantics provider khác | N/A |
| `service.statusLink` | supported | Header link | Official status page | Health tách data freshness | Link trong MVP |
| `service.healthSnapshot` | unknown ở integration | Chưa hiện đèn Operational | Chưa kiểm tra structured feed/parser | Không suy outage từ API auth error | Phase sau |
| `dailyIntensity` | supported, derived | Output intensity theo UTC | Cost DAY `output_tokens` | Missing khác measured zero; không đổi theo history metric selector | Unit + render fixtures |
| `continuity.organization` | supported, derived | Activity run cấp organization | Cost DAY token/cost fields | Không gọi là personal streak, không badge, không realtime | Zero/missing/UTC fixtures |
| `shipMomentum` | unknown về eligibility | Không chọn trong manifest | Derived | Chưa có contract score/rank phù hợp organization aggregate | Chờ contract riêng |
| `export.activityCard` | unknown về eligibility | Không chọn trong manifest đầu | Derived artifact | Chưa đủ total/current-day semantics của layout chuẩn | Không dùng quota để lấp chỗ |
| `auth.extractOtherAppSecrets` | prohibited | Không triển khai | Browser cookies / `~/.augment/session.json` | Ngoài flow người dùng nhập token | Không có fixture |

## 4. Triển khai đã chốt

`DockFeature.augment` đăng ký trong sidebar AI, General picker và Dock menu. Settings có Connection, production Dock preview, Display và Data. Preview dashboard dùng sheet native có Done để tránh popover mất focus khi đổi nội dung. Token nhập bằng SecureField; probe một ngày trước khi ghi Keychain. Thay token thất bại giữ kết nối cũ; response rỗng hợp lệ được kết nối nhưng không biến thành zero. Disconnect xóa bản local; link quản lý service account hướng dẫn revoke phía Augment.

Dock mặc định Numbers với IN/OUT từ cùng latest reported UTC bucket. Missing component hiện `—`, explicit zero hiện `0`. Trend có hai sparkline bảy ngày giữ gaps; Billed USD có renderer riêng. Ngày UTC, loading, stale và accessibility đi cùng giá trị.

Dashboard dùng DockHoverChrome rộng 440 pt, cao tối đa 650 pt và giới hạn theo màn hình, nội dung cuộn. Manifest chọn identity, status link, daily usage, organization continuity, Output Daily intensity, daily detail và model ranking. History mặc định 30 ngày/Output; selector 7/30/90 ngày và Input/Output/Cache read/Cache write/Billed USD. Top 3 models theo metric + khoảng ngày, View all, chọn ngày xem bốn loại token và billed/estimated USD riêng. Compute không vào bảng model; overview USD vẫn giữ chi phí API báo. Không cộng breakdown vào overview.

`AIUsageHistoryChart` nhận Decimal?, UTC/timezone, partial state và data-series color do caller cung cấp. `AIUsageTokenHistoryChart` là adapter dùng chung cho integer token buckets; không chuyển tiền thành token. `AIUsageDailyIntensityCard` hiển thị riêng Output token theo UTC và giữ ngày thiếu khác measured zero. Augment truyền màu appearance đã lưu qua contrast resolution vào các chart dùng chung. `StreakContinuityStrip` dùng presentation organization activity để chia sẻ geometry/day states nhưng không hiển thị badge hoặc gọi đó là personal streak. Color/appearance dùng DesignTheme và shared components. Không đăng ký quota, total token, credits, personal streak/badges, Ship momentum hoặc export.

## 5. API, cache và lifecycle

- `AugmentAnalyticsClient`: fixed HTTPS `api.augmentcode.com/analytics/v0/cost-analytics`, DAY overview không filters/grouping; RESOURCE + TOTAL cho model trong kỳ hoặc một ngày. Request mẫu: [cost-query.json](augment-api-research/requests/cost-query.json).
- `AugmentMetrics`: Int64 token components, Decimal billed/estimated USD, nil khác zero. Không tự tính total/billing. Decimal → Double chỉ ở tọa độ render.
- Cursor tuần tự, kiểm tra cursor lặp/effective range/row count/duplicate bucket, tối đa 100 trang và 8 MiB mỗi trang. Chỉ publish khi toàn bộ query hoàn tất; lỗi giữ snapshot hoàn chỉnh trước đó.
- `AugmentUsageStore`: một refresh in-flight, request model/detail độc lập. Generation tăng khi hủy/đổi kỳ/đổi token; response cũ không thể ghi cache hoặc state mới. Đổi token thành công tạo UUID connection mới, xóa cache trước đó.
- `AugmentHistoryCache`: normalized overview trong Application Support/DockMagic/Augment/organization-v1.json, version + connection UUID. File 0600, thư mục 0700; không raw response, header, token hoặc email. Resource breakdown cache trong RAM.
- Tự refresh tối đa mỗi 6 giờ khi Dock chọn Augment hoặc Settings/dashboard hiện. Mở lại/wake/network recovery kiểm tra hạn; lỗi không biến thành polling mỗi phút. Manual cooldown 30 giây. Đổi range là query theo thao tác người dùng.
- Request spacing tối thiểu 2 giây giữa các lần gửi, 429 có Retry-After/backoff+jitter, retry hữu hạn. 401/403 dừng tự retry và yêu cầu sửa kết nối. Model detail lỗi không xóa overview.

Mặc định đến hôm qua UTC là chính sách thận trọng của DockMagic, không khẳng định API cấm query hôm nay. TTL 6 giờ là policy local, không phải cadence hoặc SLA của upstream. `generated_at` chỉ là metadata response; latest reported day lấy từ bucket thực nhận.

## 6. Credential, privacy và distribution

`AugmentCredentialVault` có protocol và in-memory double. Keychain item riêng: service `com.hypevibe.DockMagic.augment`, account `augment.access-token`. Không đọc browser session, token Auggie hoặc credential của ứng dụng khác. Không ghi token vào preferences, log hay cache.

URLSession ephemeral, không cookie/cache, chặn mọi redirect kể cả same-origin. Base URL không cấu hình bởi người dùng. UI error dùng thông báo normalize, không hiển thị response body. Disconnect hủy request, xóa credential/cache local. Clear local history giữ credential; Reset appearance chỉ reset renderer.

Không thêm entitlement/CLI/helper cho Augment. Production tiếp tục Developer ID, Hardened Runtime, notarization và stapling. Keychain acceptance phải dùng app signed; fixtures không chứng minh quyền tài khoản thật.

## 7. Source map

| Trách nhiệm | Source |
| --- | --- |
| Model/manifest/presentation | Models/AugmentUsage.swift, AugmentPresentation.swift |
| API/Keychain/cache | Services/AugmentAnalyticsClient.swift, AugmentCredentialVault.swift, AugmentHistoryCache.swift |
| Lifecycle | Stores/AugmentUsageStore.swift, DockAppModel.swift |
| Preferences | Stores/DockPreferencesStore.swift |
| Settings | Views/Settings/AugmentSettingsView.swift, SettingsView.swift |
| Dock | Views/Dock/DockAugmentView.swift, DockMetricsView.swift |
| Dashboard/chart | Views/Hover/AugmentHoverDashboardView.swift, AIUsageHistoryChart.swift; CodexHoverDashboardView adapter |
| Hover placement | Services/DockHoverCoordinator.swift |
| Test-only fixtures | Services/AugmentFixtures.swift, guarded by DEBUG; DockMagicUITesting environment only |
| Tests | AugmentAnalyticsTests, AugmentStoreTests, AugmentIntegrationTests, AugmentUITests |

Source paths ở trên tính từ DockMagic/DockMagic, trừ test targets. Không mở rộng thành shared registry/refactor toàn bộ providers.

## 8. Evidence và acceptance

- Research: tài liệu chính thức kiểm tra ngày 2026-09-16; các nguồn mục 2.
- Parser/store: có standalone lane `./script/test_augment_foundation.sh` cho mock transport/cache/lifecycle. Fixtures synthetic; không credential thật.
- Full app: Xcode build, signed-host Keychain test, render matrix và UI automation được ghi kết quả trong [AUGMENT_USAGE.md](AUGMENT_USAGE.md).
- Live acceptance chưa xác minh: nhập Enterprise token trong Settings, so Input/Output/USD/model breakdown với web cùng Organization và UTC period. Không đưa token vào chat/log/test fixture.
- Chưa xác lập cost today/freshness, total token/cache overlap, coverage Context Engine MCP hoặc tenant identity. Bản đầu không phụ thuộc các giả định đó.

## 9. Hợp đồng nội bộ

[AI_PROVIDER_FEATURE_CONTRACT.md](AI_PROVIDER_FEATURE_CONTRACT.md), [AI_DASHBOARD_DESIGN_SYSTEM.md](AI_DASHBOARD_DESIGN_SYSTEM.md), [COLOR_DESIGN_SYSTEM.md](COLOR_DESIGN_SYSTEM.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md). Activity export không được chọn trong manifest, vì vậy không áp layout export để ép metric không có nguồn.
