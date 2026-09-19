# Nghiên cứu dữ liệu có thể truy xuất từ OpenCode CLI

**Status:** Proposed — đủ bằng chứng cho một tích hợp lịch sử local có giới hạn; chưa phải tích hợp đã triển khai.  
**Verified:** 2026-09-16.  
**Phạm vi:** `anomalyco/opencode`, CLI đang cài `1.18.4`, mã nguồn tag `v1.18.4`, commit `49c69c5ed3ccf706b61b3febb43c8aaff7f8325e`. Không khẳng định đây là release mới nhất.  
**Plans tested:** Không kiểm tra tài khoản/plan online, không gửi prompt. Database local được đọc bằng SQLite read-only; các session quan sát được mang version `1.1.14`–`1.1.34`.

## Kết luận

OpenCode có nguồn dữ liệu tốt cho **hoạt động coding local**: session, message metadata, token, model/provider, tool, todo, lỗi và thời gian. Có thể dựng lịch sử theo ngày/giờ, phân bố model và hoạt động gần đây. HTTP API, SDK, SSE và plugin bổ sung thông tin đang chạy khi kết nối đúng instance.

Không có bằng chứng về một lệnh/API CLI chung trả về **quota tài khoản còn lại, phần trăm 5 giờ/tuần, số dư hoặc gói thuê bao của mọi provider**. OpenCode là client của nhiều provider; OpenCode Go/Zen chỉ là những dịch vụ có thể dùng qua client đó. Go thực sự có giới hạn 5 giờ/tuần/tháng, nhưng điều này không chứng minh CLI cung cấp snapshot quota của tài khoản. Không tính quota từ local token/cost. [Tài liệu Go](https://opencode.ai/docs/go/)

Khuyến nghị cho DockMagic: bắt đầu bằng token/history/model từ metadata local; cost là khả năng có điều kiện; active work là giai đoạn riêng cần kết nối instance/event. Chưa bật quota, balance, plan hay goal như thể đã được hỗ trợ.

## Các đường truy xuất

| Đường truy xuất | Lấy được gì | Điều kiện và giới hạn |
| --- | --- | --- |
| `opencode --version`, `--help` | Version, capability CLI | Đã chạy trên máy; không chứng minh database đã migrate |
| `opencode stats --models --tools 10` | Tổng session/message, token, cost, model và số lần gọi tool | Output dạng bảng; không có `--format json` trong bản khảo sát; là tổng của dữ liệu local còn giữ |
| `opencode stats --days 7 --project ""` | Stats lọc project hiện tại, session cập nhật trong 7 ngày | Không phải token phát sinh chính xác trong 7 ngày; xem bẫy thời gian bên dưới |
| `opencode session list --format json --max-count 100` | `id`, `title`, `created`, `updated`, `projectId`, `directory` | Code dùng `roots: true`, scope project hiện tại; mặc định tầng list giới hạn 100. Không dùng làm inventory toàn bộ lịch sử/subagent |
| `opencode export <sessionID> --sanitize` | Session + `messages[].info` + `parts[]`, với nhiều trường được redaction | Nguồn transcript rộng; không cần cho dashboard metadata. Sanitize không phải bảo đảm loại hết mọi dữ liệu nhạy cảm |
| `opencode db path` | Đường dẫn database thực tế | Có `XDG_DATA_HOME`, `OPENCODE_DB`, tên DB theo channel; không hard-code duy nhất một đường dẫn |
| `opencode db '<SELECT ...>' --format json` | SQL projection nhỏ, có cấu trúc | Bản 1.18.4 mở database service và chạy migrations; bản thân command không bảo đảm read-only. Với nghiên cứu dữ liệu cũ, dùng SQLite `mode=ro` |
| `opencode providers list` / `opencode auth list` | Provider có credential local, loại `api`/`oauth` và tên biến môi trường được nhận diện | Không in giá trị secret trong list handler; không kiểm tra credential còn hợp lệ; không có plan/quota |
| `opencode console orgs` | Console organization, email tài khoản, org đang active | Command có trong source nhưng nhóm `console` bị ẩn khỏi help chính; không dùng làm contract ổn định của mọi provider |
| `opencode models [provider] --verbose` | ID/name, giới hạn context/output, capabilities, giá model và metadata cấu hình | Output gồm dòng `provider/model` xen JSON, không phải một JSON array. Là catalog, không phải model usage hay account entitlement |
| `opencode agent list`, `mcp list`, `debug paths`, `debug skill` | Agent, MCP status, đường dẫn, skill | Có thể khởi tạo plugin/config hoặc kết nối MCP; là công cụ chẩn đoán, không nên poll toàn bộ |
| `opencode run --format json ...` | Event của lượt chạy mới | Có thực thi agent và tiêu thụ model; không dùng làm lệnh đọc usage thụ động |
| `opencode serve` + HTTP/SDK/SSE | Session, message, todo, status, provider, event | Phải chọn đúng process/project/server; khởi động một server mới không biến nó thành observer của TUI khác |

[CLI docs](https://opencode.ai/docs/cli/), [stats source](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/cli/cmd/stats.ts), [session CLI source](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/cli/cmd/session.ts), [database command](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/cli/cmd/db.ts).

## Capability dossier

Các profile P1–P6 bên dưới là phần chung của từng dòng: điều kiện, freshness, completeness, privacy/distribution và fixture. `supported` xác nhận nguồn/field trong phạm vi ghi rõ; không khẳng định đã kiểm thử mọi provider hay mọi đường chạy V2.

| Capability | Status | Giá trị sử dụng | Nguồn/provenance, exact fields | Semantics | Profile và evidence |
| --- | --- | --- | --- | --- | --- |
| `cli.presence.version` | supported | Settings setup | Official local: `--version`, `--help` | Version executable, độc lập schema/session version | P1; probe local 1.18.4 |
| `identity.provider` | supported | Biết model đang qua nhà cung cấp nào | Official local: `models`; HTTP `/provider`; message `providerID`, `modelID` | Provider ID khác model ID; không gộp cùng model giữa các provider | P1/P2; [provider handler](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/server/routes/instance/httpapi/handlers/provider.ts) |
| `auth.configured` | supported | Setup/connection hint | Official local `providers list`: tên provider, `type`, tên env var; HTTP `connected[]` | Configured/available, không tương đương validated login | P1; [list handler](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/cli/cmd/providers.ts#L248) |
| `auth.valid` | unknown | Auth còn hợp lệ | Chưa có status probe chung cho mọi provider trong surface khảo sát | Không suy ra credential hợp lệ từ configured/connected | P6; không có live-account fixture |
| `identity.plan` | unknown | Tên gói thuê bao | Chưa có contract plan chung cho mọi provider trong surface khảo sát | Không suy ra plan từ OAuth, model hay tên provider | P6; không có live-account fixture |
| `identity.console.org` | supported, experimental | Console organization nếu thực sự cần | Official local API `/experimental/console`: `activeOrgName`, `consoleManagedProviders`, `switchableOrgCount`; `/experimental/console/orgs`: email/org metadata | Chỉ OpenCode Console; không phải profile của Anthropic/OpenAI/Copilot | P4; [schema](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/server/routes/instance/httpapi/groups/experimental.ts#L22) |
| `quota.window` | unknown | Quota Dock | Không có query snapshot chung trong CLI/help/API schemas khảo sát; nguồn riêng từng provider chưa xác lập | Go có limit không có nghĩa client có remaining snapshot | P6; [retry source](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/retry.ts#L68) |
| `quota.reset` | unknown | Reset countdown | Không có snapshot reset chung được xác minh | Retry delay của một lỗi không phải reset toàn tài khoản | P6; retry source |
| `balance` | unknown | Số dư còn lại | Không có balance query chung được xác minh qua CLI/public local API | Không lấy balance ban đầu trừ local cost để suy remaining | P6 |
| `usage.tokens.breakdown` | supported có điều kiện | Token Dock/hover | Local metadata / official local API: `tokens.input`, `.output`, `.reasoning`, `.cache.read`, `.cache.write`; legacy `.total?` | Các bucket đã chuẩn hóa; không cộng `total` thêm lần nữa; trường 0 có thể đã được upstream mặc định hóa | P2; [V1 schema](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/schema/src/v1/session.ts#L453), [V2 schema](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/schema/src/session-message.ts#L164) |
| `usage.daily.tokens` | supported, derived | Biểu đồ ngày | Metadata assistant + `time.created`, optional `time.completed`, các token bucket | Gom theo thời gian message/step, timezone lựa chọn; là lịch sử quan sát trên máy | P2/P5; queries kèm báo cáo |
| `usage.hourly.tokens` | supported, derived | Drill-down giờ | Cùng assistant timestamp và token metadata | Bucket theo giờ, cần timezone/DST policy; không phân bổ tùy ý qua các giờ của một lượt chạy | P2/P5; V1/V2 message schemas |
| `usage.lifetime.local` | supported, partial | Tổng lịch sử còn lưu | Tập assistant metadata hoặc session counter đã được kiểm tra schema | Không phải toàn bộ usage tài khoản từ trước tới nay; deletion/import/fork có thể đổi tổng | P2; [DB schema](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/core/src/session/sql.ts) |
| `usage.model` | supported | Top models/provider | `providerID`, `modelID`; V2 `model.providerID`, `model.id`; token/cost của từng assistant | Không dùng model hiện tại của session để gán toàn bộ quá khứ | P2; V1/V2 message schemas |
| `cost.recorded` | supported có điều kiện | Cost estimate/recorded | Legacy assistant `.cost`; session counter `.cost`; V2 `.cost?` | USD theo pipeline upstream; đa số legacy tính từ price catalog; V2 runner có nhánh ghi 0. Không bảo đảm billed cost | P2; [getUsage](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/session.ts#L338), [V2 runner](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/core/src/session/runner/llm.ts#L325) |
| `work.session.history` | supported | Session gần đây | `id`, `parentID`, `projectID`, `time`, `agent`, model reference; title/path có nhưng không cần lưu cho metric | Parent có thể là fork/child; không mặc định tất cả child là subagent | P2; session schemas |
| `work.session.active` | supported theo instance | Busy/retry/idle, active count | Legacy `GET /session/status`: `type`, retry `attempt`, `next`; V2 `/api/session/active`: `type: running`; SSE | Trạng thái process, không suy từ timestamp DB; disconnect = unavailable/stale | P3; [status implementation](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/status.ts) |
| `work.todo` | supported khi có dữ liệu | Task count/progress | `/session/:id/todo` hoặc bảng `todo`: `status`, `priority`, `position`; `content` có nhưng bỏ khỏi collector | Todo do agent lưu; không bảo đảm task bao phủ mọi công việc | P2/P3; DB schema |
| `work.goal` | unknown | Goal progress | Chưa xác lập một object goal độc lập trong surface khảo sát | Không suy goal từ title, prompt hay todo | P6 |
| `work.tool` | supported | Tool count/status/duration | Legacy part `type=tool`, `tool`, `callID`, `state.status`, `state.time`; V2 assistant tool content | `pending`, `running`, `completed`, `error`; duration chỉ khi đủ timestamps | P2/P3; [tool schemas](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/schema/src/v1/session.ts#L259) |
| `work.diff.summary` | supported khi có giá trị | Số file/dòng đổi | Local session `summary_additions`, `summary_deletions`, `summary_files`; API session summary | Snapshot summary, không phải số thay đổi đã commit/ship; absent khác 0 | P2; session SQL schema |
| `work.diff.full` | unknown về coverage hiện tại | Xem code diff nếu có scope riêng | Có route `/session/:id/diff`, nhưng legacy `Session.diff` trong tag khảo sát trả mảng rỗng | Endpoint tồn tại không chứng minh có diff thật; không cần collect code cho dashboard | P6; [implementation](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/session.ts#L825) |
| `usage.tool.tokens` | unsupported trong schema chung khảo sát | Token riêng từng tool | Không có bucket token chuẩn theo tool; có tool calls | Không chia token message cho số tool để tạo metric | P6; tool/message schemas |
| `work.needsAttention` | supported theo instance | Cần người dùng xử lý | `GET /permission`, `GET /question`, corresponding events; chỉ lấy count/type | Request đang chờ, khác API error; không tự approve | P3; server API groups permission/question |
| `context.usage` | supported, estimate có điều kiện | Độ đầy context session | Latest assistant usage + model `limit.context`; ACP `usage_update.used`, `size`, `cost` | Context không phải quota. ACP implementation dùng `input + cache.read`; không gọi đó là account remaining | P3; [ACP usage](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/acp/usage.ts) |
| `environment.capabilities` | supported | Chẩn đoán | Models, agents, skills, MCP/LSP/formatter, project/VCS metadata | Cấu hình/capability của instance; có thể chạm config nhạy cảm nếu đọc quá rộng | P1/P3; [server docs](https://opencode.ai/docs/server/) |
| `service.health.local` | supported | Tình trạng server | `GET /global/health`: `healthy`, `version` | Chỉ server OpenCode local; không chứng minh upstream provider khỏe | P3; server docs |
| `service.health.upstream` | unknown trong nghiên cứu này | Status provider | Chưa xác minh một nguồn official chung cho mọi provider OpenCode | Cần mapping riêng từng provider; không dùng local health làm outage signal | P6 |
| `engagement` | supported, derived khi đủ dữ liệu | Streak/intensity | Daily token có provenance/coverage | Là DockMagic-derived; không phải thành tích do OpenCode xác nhận | P5; contract DockMagic |
| `export.activity` | supported, derived khi đủ dữ liệu | Activity card | Daily token/trend có provenance/coverage | Phải qua eligibility contract riêng; không phải screenshot transcript | P5; contract DockMagic |
| `credential.raw`, `transcript.raw` cho dashboard | prohibited | Không cần | Không đọc trực tiếp `auth.json`, credential DB/config; không thu prompt/answer/tool I/O | Có khả năng kỹ thuật không đồng nghĩa được phép thu thập cho mục tiêu metadata | P6; contract DockMagic |

### Điều kiện, freshness, completeness, privacy và fixture theo profile

| Profile | Conditions | Freshness/timestamps | Completeness | Privacy/distribution | Fixture |
| --- | --- | --- | --- | --- | --- |
| P1 discovery/config | CLI tương thích; catalog/provider tùy config; chưa test login live | Đề xuất refresh lúc mở Settings, đổi config/version; có `observedAt` | List provider không bảo đảm credential hợp lệ hay mọi model có quyền sử dụng | Chỉ output allowlist; CLI tự quản lý auth; không lấy secret. Không cần capability App Store | Version/help đã chạy; fixture `observed-metadata.json` |
| P2 persisted usage | Có database/API tương thích; pin field/schema. Local đã kiểm tra V1 history; V2 chỉ source-level | `time.created/completed/updated` epoch ms; đề xuất event trigger + refresh 30–60s khi active, backoff khi idle | Local retained history; import/fork/deletion/compaction/multi-device có blind spots; missing khác zero | SQLite `mode=ro`, allowlist JSON paths; không lấy nội dung. Tương thích hướng Developer ID bằng local file/subprocess, chưa có app runtime verification | Fixture metadata local + `synthetic-message-metadata.json`; SQL đã chạy trên DB read-only |
| P3 runtime | Server đang chạy, đúng endpoint/project/process; API credentials do server flow quản lý; plugin chỉ khi opt-in | SSE + baseline snapshot, timestamp nhận event, reconnect/reconcile; TTL đề xuất 15–30s cho busy | Process khác không tự chia sẻ busy state; event disconnect không chứng minh idle | Loopback, HTTP Basic auth cho server có dữ liệu thật, không publish mDNS mặc định; event filter bỏ text/args/results | Chưa có fixture live active; cần smoke test trước ship. Source schemas làm chuẩn |
| P4 Console | Đã đăng nhập Console; experimental routes; không tương đương provider login | Refresh theo user action; lỗi không xóa usage local | Chỉ account/org Console, không plan của mọi provider | Không lưu email/org ID cho dashboard nếu không có user value rõ; không trực tiếp đọc account DB | Chưa có live fixture/account verification; không ship ở MVP |
| P5 derived | P2 có sample hợp lệ và policy coverage/timezone | Recompute idempotent theo message ID và local day; rebuild khi timezone đổi | Không chứng minh ngày vắng row là ngày không sử dụng ở nơi khác | Persist aggregate cần thiết, không xuất paths/IDs/text; theo activity-card contract | Dữ liệu tổng hợp giả định trong fixture; chưa có module/app test |
| P6 absent/rejected | Chưa có nguồn được phép đủ nghĩa hoặc ngoài mục tiêu | Không poll/infer; không điền 0 | Negative/unknown finding chỉ áp dụng surface và version đã khảo sát | Không credential extraction, private billing endpoint, prompt kiểm tra usage hay transcript mining | Không có fixture là có chủ ý: capability chưa được xác lập hoặc bị loại |

Không có rate limit polling local được công bố trong nguồn đã đọc; các interval trên là **đề xuất DockMagic**, không phải SLA của OpenCode. Minimum version cho từng field chưa được truy nguyên theo release đầu tiên: hiện chỉ bảo đảm bằng chứng ở các version ghi trong báo cáo, không ghi một minimum version suy đoán.

## Ngữ nghĩa dễ bị hiểu sai

1. **`stats --days` không phải daily ledger.** Code lọc `session.time.updated >= cutoff`, rồi lấy toàn bộ session tokens/cost. Session kéo dài nhiều ngày, hôm nay chỉ vừa cập nhật, có thể mang toàn bộ cost/token cũ vào kết quả. `--days 0` đặt cutoff ở đầu ngày local nhưng vẫn có vấn đề đó. `Avg Cost/Day` chỉ là phép chia tổng đã chọn cho số ngày.
2. **Cộng đúng một nguồn usage.** Legacy assistant message có tổng token/cost; `step-finish` part cũng có usage. Không cộng cả hai, hoặc cộng thêm session counters. V2 có bảng `session_message` riêng; không UNION mọi bảng mà chưa xác định lineage/precedence.
3. **Tách cache/reasoning.** Legacy `getUsage` trừ cache read/write khỏi input và reasoning khỏi output. Công thức tổng bucket là `input + output + reasoning + cache.read + cache.write`. `stats --models` lại gộp reasoning vào output trong trình bày model; parser từ bảng sẽ mất sự tách biệt này.
4. **Cost chỉ có nghĩa trong pipeline cụ thể.** Legacy thường tính bằng token × price catalog, pricing tiers và metadata provider. Copilot có nhánh quy đổi metadata billing riêng. V2 runner `Step.Ended` trong bản source khảo sát ghi `cost: 0`. Vì vậy không hiển thị mọi số 0 thành “miễn phí” hay “không tốn tiền”; không tính lại giá hiện tại để giả làm billed cost lịch sử.
5. **Zero có thể mất provenance.** Upstream dùng giá trị mặc định 0 khi provider không trả một số token fields. Adapter downstream không luôn phân biệt được reasoning=0 thật với reasoning chưa được provider báo. Ghi “tokens recorded by OpenCode”, không tự tuyên bố đã bao phủ mọi loại token.
6. **Context khác account quota.** Context là mức dùng của cửa sổ model ở lượt/session gần nhất. Không lấy lifetime tokens chia `limit.context` để làm % quota.
7. **History không phải billing ledger bất biến.** Session bị xóa, fork/import sao chép history, revert/compaction và dữ liệu trên máy khác ảnh hưởng coverage. Không dùng tổng này làm bằng chứng chi tiêu tài khoản. Không suy reset từ `retry-after` ngoài lỗi cụ thể đó.
8. **Không chỉ dựa vào `time_updated` của message để incremental sync.** Legacy projector có nhánh conflict cập nhật `data` mà không ghi rõ `time_updated`; dùng event invalidation và re-scan session đang chạy/recent window, upsert theo ID.

Nguồn: [stats aggregation](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/cli/cmd/stats.ts#L92), [token/cost normalization](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/session.ts#L338), [projector](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/core/src/session/projector.ts#L262).

## HTTP, SDK, events và khác biệt V1/V2

API được tài liệu hóa cho client truyền thống:

```text
GET /global/health
GET /project
GET /provider
GET /provider/auth
GET /session?directory=<project-directory>
GET /session/status?directory=<project-directory>
GET /session/<id>/message
GET /session/<id>/todo
GET /session/<id>/children
GET /permission
GET /question
GET /event
GET /global/event
GET /doc
```

Tài liệu server mô tả OpenAPI và SDK để truy cập các endpoint này. Runtime status legacy được giữ trong map theo instance; mở một `opencode serve` độc lập có thể đọc cùng history nhưng không nhận busy state của TUI khác. Cần kết nối server người dùng đang dùng hoặc plugin bên trong instance đó. [Server docs](https://opencode.ai/docs/server/), [status map](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/opencode/src/session/status.ts#L28)

Source 1.18.4 còn có protocol V2 được đánh dấu experimental:

```text
GET /api/session
GET /api/session/<id>/message
GET /api/session/active
GET /api/event
```

V2 trả `{ data, cursor: { previous?, next? } }` cho list/message; message `type: assistant` thay vì V1 `role: assistant`, dùng `model` reference, `tokens`/`cost` optional. Không parse response V2 bằng parser V1. Endpoint availability thực tế phải probe `/doc`/version/server trước khi dùng; chưa thực hiện live HTTP trong nghiên cứu này. [Message protocol](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/protocol/src/groups/message.ts), [session protocol](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/protocol/src/groups/session.ts), [V2 event](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/protocol/src/groups/event.ts).

Plugin là extension point chính thức, có các event như `session.status`, `message.updated`, `message.part.updated`, `todo.updated`, `permission.asked`, cùng hook `tool.execute.before/after`. Một plugin opt-in có thể phát **chỉ metadata** sang DockMagic. Đây là phương án đề xuất, chưa cài vào cấu hình người dùng. [Plugins docs](https://opencode.ai/docs/plugins/)

## Database và truy vấn mẫu

Đường dẫn mặc định macOS theo XDG trong source là `~/.local/share/opencode/opencode.db`; kiểm tra override/channel trước khi dùng. Schema V1 có `session`, `message`, `part`, `todo`, `project`. Source mới thêm session token counters và `session_message`, `session_input`, v.v. Không scan `SELECT *` toàn DB: có thể có dữ liệu account/credential và transcript. [Path resolution](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/core/src/database/database.ts#L44), [schema](https://github.com/anomalyco/opencode/blob/49c69c5ed3ccf706b61b3febb43c8aaff7f8325e/packages/core/src/session/sql.ts)

Các `SELECT` trong [opencode-research/metadata-queries.sql](fixtures/opencode-research/metadata-queries.sql) đã được chạy trên DB thật qua `mode=ro`. Chúng chỉ chiếu metadata và aggregate, không trả prompt/answer/title/path/tool input-output. Ví dụ dùng CLI trên một database đã migrate bình thường:

```sh
opencode db "SELECT json_extract(data, '$.providerID') AS provider, json_extract(data, '$.modelID') AS model, COUNT(*) AS assistant_messages FROM message WHERE json_extract(data, '$.role') = 'assistant' GROUP BY 1, 2" --format json
```

Với collector read-only, mở SQLite trực tiếp bằng `SQLITE_OPEN_READONLY`, dùng busy timeout và snapshot transaction phù hợp WAL. Không chạy migration, không dùng `immutable=1` với database đang thay đổi, không chỉ copy file `.db` mà bỏ WAL. SQL mẫu áp dụng legacy `message` đã quan sát; nó không tự bao phủ V2 `session_message`.

## Kết quả kiểm tra trên máy

- Executable: `1.18.4`; help xác nhận `stats`, `db --format json`, session JSON, `export --sanitize`, `providers`/`auth`.
- DB mặc định tồn tại. Read-only: 4 session, 63 message gồm 57 assistant, 285 parts, 0 todo; 114 tool parts gồm 113 completed và 1 error.
- Cả 57 assistant có object tokens và field cost. Có 3 cặp provider/model: `anthropic/claude-sonnet-4-5`, `opencode/big-pickle`, `opencode/glm-4.7-free`. Đây là lịch sử đã ghi, không xác nhận provider nào hiện còn đăng nhập.
- Session version `1.1.14`–`1.1.34`; schema local chưa có session token counters hoặc `session_message`. Không tự migrate database người dùng trong nghiên cứu.
- `opencode db path` ở môi trường hiện tại bị chặn khi CLI mở file log: `Unknown: FileSystem.open (.../opencode/log/opencode.log)`. Đây là hạn chế filesystem sandbox của lần probe, không phải bằng chứng CLI thiếu command.
- Đã chạy CLI `db --format json` trong XDG/database tạm tách biệt, tắt auto-update/model fetch và dùng `--pure`: `SELECT 1 AS metadata_probe, sqlite_version() AS sqlite_version` thành công, JSON trả `metadata_probe: 1`, SQLite `3.43.2`.
- Không đọc credential store, không chạy login/logout, không export transcript thật, không gửi prompt hoặc tạo usage. Chưa kiểm tra API/SSE/ACP với session đang chạy; chưa kiểm tra account quota hay app UI.

## Surface map và phương án tích hợp

**Settings:** discovery/version, nguồn database, last observed, trạng thái history. “Có provider cấu hình” là thông tin riêng với “token history đọc được”. Chỉ thêm login flow khi scope sản phẩm thật sự cần.

**Dock:** token quan sát hôm nay hoặc active session count khi đủ bằng chứng; chưa có quota rings.

**Hover:** daily/hourly history, total retained history, top provider/model, token breakdown; cost conditional với nhãn đúng provenance. Active sessions/todo/tools dùng runtime source riêng.

**Drill-down:** chọn ngày/model; chỉ đưa thông tin đủ ích lợi, tránh đưa title/path/todo content vào layer metrics.

**Export:** activity card khi có activity/trend hợp lệ theo contract; không export account IDs, paths, transcript, task text. Chưa có quota-card vì chưa có quota snapshot được xác minh.

**Acquisition đề xuất:** ưu tiên public CLI/API khi trả đúng metadata và scope; với history legacy, SQLite read-only có projection nhỏ phù hợp hơn việc export transcript. Tách `HistoryReader`, `RuntimeObserver`, `ProviderConfiguration` và normalized snapshot. Pin schema, xử lý unsupported version rõ ràng. Khi mất runtime server, history vẫn có thể live; khi history lỗi, giữ snapshot trước dưới trạng thái stale.

Hướng subprocess/file/loopback không yêu cầu Mac App Store capability trong thiết kế này. Nếu DockMagic bật App Sandbox, phải kiểm tra quyền đọc file và kết nối cụ thể; chưa có build/signing/notarization/runtime test cho tích hợp OpenCode.

## Unknowns, rejected approaches và verification tiếp theo

Chưa xác minh live Console account/org, quota/balance API riêng cho Go/Zen, official status source chung, coverage của V2 và custom plugins, minimum version chính xác của từng field, retention đầy đủ, hoặc accounting khi fork/import trên mọi phiên bản. Không coi “không tìm thấy API chung” là bằng chứng mọi provider đều không có quota API riêng.

Loại bỏ: suy quota từ tokens/cost, đọc OAuth/API key trực tiếp, gọi private web billing endpoints, gửi prompt thử để tạo số liệu, hoặc coi DB updated gần đây là busy state.

Trước triển khai cần fixture cho legacy/V2, null/zero/absent usage, partial/error/cancel, fork/import, session qua nửa đêm, timezone, message update nhiều lần, duplicate step totals, WAL đang ghi và schema unsupported. Sau đó smoke-test đúng server với SSE reconnect, active/idle/retry/needs-attention, cùng UI/accessibility theo contract. Đây là kế hoạch kiểm thử còn lại, không phải kết quả đã pass.

## Implementation follow-up — 2026-09-16

The approved local-history scope is implemented in DockMagic. The maintained
capability/lifecycle dossier, source files and verification boundaries are in
[OPENCODE_USAGE.md](OPENCODE_USAGE.md). Production collection uses system SQLite
read-only, not `opencode db` or `stats --days`. Real legacy metadata smoke confirms
57 records and 1,766,159 recorded tokens with idempotent reconciliation; V2 remains
source/fixture-verified rather than a live-account claim.
