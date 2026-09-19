# Evidence nghiên cứu Binance — 16/09/2026

Đọc [phương án tích hợp](../../BINANCE_INTEGRATION_RESEARCH.md).

- `manifest.json`: repository/commit đã đối chiếu, hash tài liệu tải về và toolchain.
- `rest-results.json`: URL thực tế, HTTP status, metadata và kiểm tra cấu trúc nến.
- `websocket-results.json`: thống kê 39,41 giây và payload cuối của bốn stream.
- `probe_rest.py`: chương trình GET công khai đã chạy.
- `probe_websocket.swift`: chương trình Foundation WebSocket đã compile và chạy.

Các giá và số lượng symbol là dữ liệu tại thời điểm probe, không phải giá hiện tại. Đây là bằng chứng kết nối và cấu trúc dữ liệu; không phải kết quả test UI, test tải hay quyền sử dụng thương mại.

Để tái lập trên macOS có Python 3 và Xcode command-line tools, copy probe vào thư mục tạm trước. Các lệnh cần truy cập internet và không cần API key:

```sh
mkdir -p /tmp/dockmagic-binance-research-20260916
cp /Users/dongnt/Desktop/github/dockmagic/docs/research/binance-2026-09-16/probe_rest.py /tmp/dockmagic-binance-research-20260916/probe_rest.py
cp /Users/dongnt/Desktop/github/dockmagic/docs/research/binance-2026-09-16/probe_websocket.swift /tmp/dockmagic-binance-research-20260916/probe_websocket.swift
python3 /tmp/dockmagic-binance-research-20260916/probe_rest.py
xcrun swiftc -parse-as-library -module-cache-path /tmp/dockmagic-binance-research-20260916/swift-cache /tmp/dockmagic-binance-research-20260916/probe_websocket.swift -o /tmp/dockmagic-binance-research-20260916/probe_websocket
/tmp/dockmagic-binance-research-20260916/probe_websocket
```

Chạy lại thay evidence trong thư mục tạm; các JSON đã lưu trong repository giữ nguyên snapshot ban đầu. Probe REST cũng tải các payload công khai vào thư mục tạm để kiểm tra; repository chỉ giữ bản kết quả gọn. Probe WebSocket tự kết thúc sau khoảng 40 giây.
