# Bằng chứng nghiên cứu shadcn bbVKHJo

Ngày lấy: 17/09/2026. CLI xác minh: `4.21.0`. Primitive được chọn rõ cho mẫu: `base`. Style do init ghi: `base-maia`.

- [Báo cáo nghiên cứu](../../SHADCN_PRESET_RESEARCH.md)
- [Bảng native mapping đủ 63 item](NATIVE_COMPONENT_MAP.md)
- [Preset decode](preset.json): kết quả CLI, không phải giải mã tự viết.
- [components.json](components.json): config init ghi trong scaffold tạm trước khi dependency install thất bại.
- [template-package.json](template-package.json): package scaffold tại thời điểm nghiên cứu; không có lockfile chứng minh cài thành công.
- [registry-catalog.txt](registry-catalog.txt): 216 item, lấy với limit 300.
- [registry-ui-source.json](registry-ui-source.json): payload registry của 63 UI item, 8.249 dòng source; `form` không có source file.
- [component-inventory.json](component-inventory.json): tóm tắt path, dependency, function symbol, slot, source-line count và docs từ payload. Regex dùng cho inventory, không phải phân tích ngữ nghĩa đầy đủ.
- [button-docs.txt](button-docs.txt): URL docs/examples do CLI resolve.
- [SHA256SUMS.txt](SHA256SUMS.txt): hash snapshot artifact.
- [UPSTREAM-LICENSE.md](UPSTREAM-LICENSE.md): MIT notice của source shadcn/ui.

## Cách thu thập

Lệnh gốc được thử trong `/private/tmp` với project name riêng và `--base base --no-monorepo --yes`, không chạy init tại repo Swift.

```sh
npx shadcn@latest init --preset bbVKHJo --template next \
  --base base --name dm-preset-bbvkhjo-20260917 --no-monorepo --yes
npx shadcn@latest preset decode bbVKHJo --json
npx shadcn@latest search @shadcn --limit 300
npx shadcn@latest view @shadcn/button @shadcn/card # và toàn bộ UI items
npx shadcn@latest docs button
```

Thực tế dùng npm cache tách biệt tại `/private/tmp/dm-shadcn-npm-cache`; sau khi tải CLI, các lệnh đọc chạy bằng `npx --offline --yes shadcn@latest`. `--offline` này giới hạn việc npm tìm package; CLI vẫn lấy registry qua network khi được phép. Payload lớn được redirect trực tiếp ra file để không bị mất đuôi output khi CLI kết thúc.

Để tái kiểm tra nên dùng `shadcn@4.21.0` và đối chiếu hash. Pin CLI không pin registry: chưa xác định upstream commit của HTTP payload.

## Các giới hạn quan trọng

1. Scaffold Next.js không hoàn tất: bước npm install báo `ERESOLVE`, có `react-dom@undefined`, version được khai báo `19.2.8`, Next `16.3.4`.
2. Lần init tiếp trên scaffold nhận diện Next/Tailwind v4/import alias, ghi config, đọc registry thành công; bước cài dependencies dừng với `ENOTCACHED` do npm offline cache chưa có `@base-ui/react`.
3. Source registry chưa qua đầy đủ installer transforms: có `IconPlaceholder` và import path nội bộ. Nó không phải output component đã cài vào app.
4. Config/preset/preview xác nhận HugeIcons; icon mặc định trong một số registry metadata không được dùng để kết luận ngược lại.
5. Preview chính thức đã quan sát Light/Dark và một mẫu Select/Escape/focus. Các số đo được ghi trong báo cáo là quan sát có chọn mẫu; chưa kiểm thử interaction của toàn bộ catalog.
6. Không có code production, rules hay active tokens nào được sửa trong nghiên cứu này. Không build/test DockMagic vì chưa triển khai UI mới.

Preview: [Create](https://ui.shadcn.com/create?preset=bbVKHJo), [Base Maia preview](https://ui.shadcn.com/preview/base/preview-02?preset=bbVKHJo&iconLibrary=hugeicons&style=maia&font=geist&radius=medium).
