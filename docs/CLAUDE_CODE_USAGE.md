# Nghiên cứu Claude Code usage limits

## Kết luận

DockMagic dùng `statusLine`, là contract local được Anthropic tài liệu hóa, thay
vì gọi một endpoint OAuth nội bộ hoặc đọc credential. Đây là đường lấy usage
limit phù hợp cho app desktop trực tiếp:

```text
Claude Code response
  -> statusLine JSON trên stdin
  -> bridge chỉ extract rate_limits
  -> ~/.claude/dockmagic-usage.json
  -> ClaudeCodeUsageStore
  -> Settings + NSDockTile
```

Claude Code cũng có `/usage`, nhưng đó là command tương tác trong session. Tài
liệu command mô tả nó là màn hình plan usage, limits và activity; không cung cấp
CLI output schema ổn định để một app khác poll.

## Contract chính thức

Tài liệu status line của Anthropic liệt kê bốn field:

- `rate_limits.five_hour.used_percentage`
- `rate_limits.five_hour.resets_at`
- `rate_limits.seven_day.used_percentage`
- `rate_limits.seven_day.resets_at`

`used_percentage` là phần đã dùng trong range `0...100`; DockMagic hiển thị phần
còn lại là `100 - used_percentage`. `resets_at` là Unix epoch seconds.

Các field có thể vắng. Theo tài liệu, `rate_limits` xuất hiện cho Claude.ai
Pro/Max sau API response đầu tiên; từng window cũng có thể vắng độc lập. Vì vậy
DockMagic không biến missing/null thành `0% used` hoặc `100% left`.

Nguồn chính thức:

- [Claude Code status line](https://code.claude.com/docs/en/statusline)
- [Claude Code commands — `/usage`](https://code.claude.com/docs/en/commands)
- [Claude Code cost and usage](https://code.claude.com/docs/en/costs)

## Bridge của DockMagic

Người dùng bật bridge ở `Settings -> Claude Code -> Enable Bridge`. DockMagic:

1. Backup object `statusLine` hiện có.
2. Cài `~/.claude/dockmagic-statusline.sh` và trỏ user settings vào wrapper.
3. Wrapper nhận JSON, dùng `/usr/bin/plutil` extract riêng `rate_limits` vào file
   tạm có permission riêng tư, rồi atomic move thành snapshot.
4. Nếu đã có command status line, wrapper chạy lại command đó với nguyên input
   để output cũ không đổi.
5. Disable khôi phục object cũ và xóa script, backup, snapshot.

Bridge không cache `cwd`, `session_id`, transcript path, model, prompt hoặc token.
Nó không gọi model và không dùng network. Nếu `disableAllHooks` đang bật thì
Claude Code cũng tắt status line, nên DockMagic từ chối cài và giải thích lỗi.

## Freshness và giới hạn

- Snapshot chỉ đổi khi Claude Code CLI chạy status line, thường sau response.
- Dữ liệu cũ hơn 15 phút được đánh dấu `stale`, không giả là live.
- Claude Desktop không chạy status line CLI nên không cập nhật bridge này.
- Project-level `statusLine` có thể override user settings. Khi đó bridge global
  không chạy trong project đó.
- Đây là quota subscription, không thay thế billing API-key/Console reporting.
