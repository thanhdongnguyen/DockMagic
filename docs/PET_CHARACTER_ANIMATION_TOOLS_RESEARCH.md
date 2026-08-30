# Nghiên cứu công cụ thiết kế và animation cho Pet

**Ngày nghiên cứu:** 2026-08-30
**Đối tượng:** DockMagic trên macOS, cụ thể là Codex và Claude Code hover dashboard
**Mục tiêu:** chọn pipeline tạo character, rig, animation và runtime cho một virtual pet được “cho ăn” bằng token; mỗi pet có thể gắn với agent Codex hoặc Claude Code.

## Kết luận trực tiếp

Với kiến trúc hiện tại của DockMagic, lựa chọn tốt nhất cho bản đầu tiên là:

> **Blender làm source of truth → render animation thành PNG sequence/sprite atlas → chạy bằng SwiftUI hoặc SpriteKit.**

Đây là đường ngắn nhất vì repo đã có robot Blender được rig và có sẵn các action `Idle`, `Thinking`, `Typing`, `Testing`, `WaitingApproval`. Pipeline này không thêm runtime bên thứ ba, có thể tự động hóa bằng Python và hoạt động ổn định cả trong dashboard lẫn khi cần raster hóa ra Dock icon.

Nếu Pet chỉ sống trong hover dashboard và muốn chuyển state mượt, tương tác trực tiếp với dữ liệu token, **Rive** là lựa chọn 2D tốt nhất. Rive có state machine, data binding, SwiftUI/AppKit runtime và hỗ trợ macOS 13.1+. Tuy nhiên, DockMagic nên giữ một bản sprite fallback nếu sau này đưa Pet vào Dock icon.

Không nên bắt đầu bằng real-time 3D. Nếu 3D thật sự tạo khác biệt sau khi MVP được chứng minh, dùng **Blender → USDZ → RealityKit**. Không dùng SceneKit cho code mới vì Apple đã deprecated framework này.

## Những ràng buộc riêng của DockMagic

- Codex dashboard hiện có kích thước `440 × 522 pt`; Claude Code dashboard là `440 × 760 pt`. Pet nên có một vùng identity riêng khoảng `120–160 pt`, không làm dashboard biến thành game canvas toàn màn hình.
- Dock tile được render bằng SwiftUI `ImageRenderer` thành ảnh 1024 px. Apple ghi rõ `ImageRenderer` không bao gồm phần lớn AppKit/UIKit view hoặc nội dung được composited bằng Core Animation. Rive, Spine và RealityKit đều dùng view/layer hoặc Metal renderer, nên không được giả định rằng chúng có thể chụp trực tiếp vào Dock icon. Xem [ImageRenderer — Apple](https://developer.apple.com/documentation/swiftui/imagerenderer).
- Repo hiện không có package dependency ngoài. Thêm Rive/Spine là quyết định kiến trúc và release, không chỉ là thêm một asset.
- Cả Codex và Claude Code đã quy về các model token dùng chung như `CodexTokenBreakdown` và `CodexAccountTokenUsage`; không cần một telemetry pipeline hoàn toàn mới chỉ để nuôi Pet.
- Theo color contract của DockMagic, màu pet/agent phải nằm trong vùng character/identity. Không dùng màu pet để thay thế selection, focus, button hoặc trạng thái semantic của dashboard; tránh gradient, glow và tinted card trang trí.

## Shortlist và quyết định

| Stack/công cụ | Điểm mạnh | Chi phí/license tại thời điểm nghiên cứu | Fit với DockMagic | Quyết định |
| --- | --- | --- | --- | --- |
| **Blender → PNG sequence → SwiftUI/SpriteKit** | 3D character, rig, animation, render, Python/headless; repo đã có asset nền | Miễn phí; artwork/output được dùng thương mại | Rất cao; không thêm runtime, tương thích raster pipeline | **Chọn cho MVP** |
| **Rive + Apple runtime** | Vector rig, state machine, blend, data binding trực tiếp với token/state | Cadet: US$17/tháng hoặc US$108/năm; runtime MIT | Rất cao trong dashboard; trung bình cho Dock icon | **Chọn nếu ưu tiên interactive 2D** |
| **Aseprite + SpriteKit/GameplayKit** | Pixel/Tamagotchi style, state tags, CLI export atlas/JSON | Aseprite khoảng US$19.99; native runtime không phí | Rất cao nếu chọn pixel art | Lựa chọn style-specific |
| **Spine + spine-ios** | Skeletal 2D chuyên nghiệp, skin/IK/physics, CLI, SwiftUI/AppKit runtime | Essential US$69; Professional đang niêm yết US$379; có điều kiện Enterprise | Cao, nhưng phức tạp và đắt hơn Rive/MVP sprite | Chỉ chọn khi animation skeletal là lợi thế cốt lõi |
| **Blender → USDZ → RealityKit** | Real-time 3D native, animation và interaction trong dashboard | Không có runtime royalty | Trung bình; cần POC hiệu năng và animation clip | Roadmap v2 |
| **Live2D Cubism** | Mascot/portrait anime có face, ears/tail và physics rất biểu cảm | Editor + Publication License tùy quy mô/use case | Kỹ thuật và license phức tạp | Không khuyến nghị cho v1 |
| **Unity** | Full game engine, Animator, physics, cross-platform | Personal miễn phí dưới ngưỡng; Pro cao hơn | Thấp cho một view trong app SwiftUI/AppKit | Chỉ cân nhắc nếu Pet thành mini-game độc lập |

## Công cụ theo từng giai đoạn

### 1. Concept và character sheet

**Krita** là lựa chọn miễn phí tốt nhất cho sketch, silhouette, turnaround, expression sheet và frame-by-frame thử nghiệm. Krita có animation workspace, onion skin, image-sequence export và Python extension; phần mềm là free/open source. Xem [Krita Features](https://krita.org/en/features/).

**Clip Studio Paint** phù hợp nếu artist thiên illustration/manga. PRO làm concept/character art và animation ngắn; EX có full-length animation. Bản Windows/macOS perpetual được niêm yết US$63 cho PRO và US$277 cho EX; có thể xuất PNG image sequence. Xem [Clip Studio Animation](https://www.clipstudio.net/en/animation/) và [Product Lineup](https://www.clipstudio.net/en/lineup/).

**Inkscape** hữu ích để làm sạch body parts dạng SVG trước khi import vào Rive. Nó miễn phí, có CLI/headless batch export, nhưng không phải animation editor.

AI image generation có thể giúp tạo nhanh moodboard và silhouette alternatives, nhưng không nên coi một ảnh AI duy nhất là character source of truth. Production cần turnaround trước/sau, tỷ lệ nhất quán, vùng deform rõ và chỉnh sửa thủ công để tăng tính sở hữu, độ nhất quán và khả năng rig.

### 2. 2D rigging và animation

#### Rive — lựa chọn interactive 2D tốt nhất

Rive kết hợp vector drawing, bones/weighting, timeline, animation mixing và visual state machine. Data binding hỗ trợ number, boolean, trigger, enum, string, color, image và nested view model; vì vậy app có thể truyền `foodLevel`, `agent`, `workState` và `celebrate` mà không nhồi logic animation vào Swift. [Rive State Machines](https://rive.app/docs/editor/state-machine/state-machine) và [Data Binding](https://rive.app/docs/editor/data-binding/overview) mô tả đúng kiểu contract mà Pet cần.

Apple runtime hỗ trợ SwiftUI/AppKit, Swift Package Manager và macOS 13.1+. Runtime là open source/MIT. Lưu ý API Apple mới được Rive ghi là **experimental**, còn API legacy ở maintenance mode; cần pin version và có regression test. Xem [Rive Apple Runtime](https://rive.app/docs/runtimes/apple/apple), [runtime licensing](https://rive.app/docs/runtimes/getting-started) và [pricing](https://rive.app/docs/account-admin/pricing).

Rive nên dùng cho Pet trong dashboard. Nếu Pet xuất hiện ở Dock tile, export thêm PNG sequence từ cùng file để tránh phụ thuộc vào việc snapshot một Metal/AppKit-backed view.

#### Aseprite — tốt nhất cho pixel pet

Aseprite hỗ trợ tags theo state, frame-by-frame animation và CLI batch export thành PNG spritesheet + JSON. CLI có `--split-tags`, `--sheet`, `--data` và packed atlas, phù hợp đưa vào build tool. Xem [Aseprite CLI](https://www.aseprite.org/docs/cli/) và [Sprite Sheets](https://www.aseprite.org/docs/sprite-sheet/).

Đường native đơn giản là xuất từng PNG frame vào Xcode Sprite Atlas, dùng `SKTextureAtlas` và `SKAction` để phát animation; `GKStateMachine` quản lý `idle/hungry/eating/sleeping/celebrating`. [SpriteKit](https://developer.apple.com/documentation/spritekit) chạy native trên macOS và được tăng tốc bằng Metal.

#### Spine — mạnh nhưng chỉ đáng giá ở production animation nặng

Spine có editor skeletal chuyên sâu, mesh deformation, skin, IK/physics, JSON/binary + texture atlas và CLI headless. `spine-ios` cung cấp SwiftUI/AppKit runtime bằng Metal trên macOS qua SPM. Xem [spine-ios](https://us.esotericsoftware.com/spine-ios), [CLI](https://en.esotericsoftware.com/spine-command-line-interface) và [export formats](https://us.esotericsoftware.com/spine-export/).

License không đơn giản như một thư viện MIT: cần Spine Editor license tại thời điểm tích hợp runtime; editor/runtime phải khớp `major.minor`, và doanh nghiệp có doanh thu/funding trên US$500.000 phải dùng Enterprise. Xem [Spine Purchase](https://us.esotericsoftware.com/spine-purchase) và [Spine Runtimes License](https://en.esotericsoftware.com/spine-runtimes-license).

#### Live2D — chỉ chọn khi phong cách anime/VTuber là yêu cầu cốt lõi

Live2D rất mạnh ở breathing, face, expressions và secondary motion từ một illustration. SDK có macOS/OpenGL/Metal, nhưng không có SwiftUI wrapper cao cấp như Rive/Spine. Đáng chú ý, Live2D có Publication License riêng; ứng dụng AI/chatbot và “Expandable Application” có quy trình review/fee riêng, kể cả trong một số trường hợp doanh nghiệp nhỏ. Một hệ Pet có nhiều model hoặc cho phép mở rộng có thể chạm định nghĩa này. Xem [SDK License](https://www.live2d.com/en/sdk/license/), [Expandable Applications](https://www.live2d.com/en/sdk/license/expandable/) và [platform support](https://docs.live2d.com/en/cubism-sdk-manual/platform/).

### 3. 3D modeling, rigging và motion

#### Blender — source of truth khuyến nghị

Blender bao phủ modeling, sculpting, retopology, UV, rigging, IK/FK, NLA, shape keys, render và Python automation. Blender miễn phí/GPL nhưng artwork tạo ra thuộc người tạo và có thể dùng thương mại. Xem [Blender Features](https://www.blender.org/features/), [Animation & Rigging](https://www.blender.org/features/animation/) và [License](https://www.blender.org/about/license/).

Repo đã có một lợi thế rất lớn: [`add_factory_characters.py`](../artifacts/factory_blender/add_factory_characters.py) tạo armature và năm action; [`factory_character_preview.png`](../artifacts/factory_blender/factory_character_preview.png) xác nhận visual robot đã tồn tại. Nên tái sử dụng rig/action contract, nhưng thiết kế lại silhouette để nhân vật đọc được như “pet”, không chỉ như factory worker.

Blender có thể:

- render transparent PNG sequence cho MVP;
- đóng gói nhiều animation action qua NLA;
- export glTF/GLB để trao đổi với tool khác;
- export USD/USDZ cho RealityKit;
- chạy batch bằng `--background --python`, rất phù hợp tạo atlas cho nhiều pet/agent variant.

#### Mixamo — trợ giúp nhanh cho mascot hai chân

Mixamo miễn phí với Adobe ID và cho phép dùng character/animation royalty-free trong dự án thương mại. Nó chỉ auto-rig **biped humanoid**; tail, wing, extra limb, proportion quá biến dạng hoặc mesh rời có thể thất bại. Phù hợp robot hiện tại, không phù hợp pet chó/mèo bốn chân. Xem [Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) và [Upload and Rig](https://helpx.adobe.com/creative-cloud/help/mixamo-rigging-animation.html).

#### Cascadeur — polish motion, đặc biệt quadruped

Cascadeur có AI-assisted posing, physics và animation editing. Nó chạy trên Apple Silicon/macOS 13.3+, nhưng không thay thế Blender ở skeleton creation/skinning. Paid tiers xuất FBX/DAE/USD/glTF. Indie là US$96/năm với ngưỡng doanh thu/funding dưới US$100.000; Pro là US$396/năm và có AutoPosing cho quadruped. Xem [Cascadeur Plans](https://cascadeur.com/plans), [FAQ](https://cascadeur.com/help/faq) và [System Requirements](https://cascadeur.com/help/installation/system_requirements).

#### Meshy và Tripo — chỉ dùng để explore, không làm source of truth

Hai dịch vụ này có thể đi từ image/text sang mesh, texture, rig và animation; API trả GLB/FBX, và Tripo còn quảng bá USDZ. Chúng giúp thử nhanh silhouette hoặc tạo base mesh, nhưng output vẫn cần retopo, cleanup, rig/weight QA và chỉnh style trong Blender.

- Meshy Rigging API hiện tập trung vào humanoid và trả GLB/FBX + basic walk/run. Paid-plan customer có quyền với output; free output dùng CC BY 4.0. Xem [Meshy Rigging API](https://docs.meshy.ai/en/api/rigging) và [commercial-use terms](https://help.meshy.ai/en/articles/9992001-can-i-use-meshy-assets-commercially-license-copyright-explained).
- Tripo có text/image/multiview-to-3D, retopology, auto-rig và animation API. Paid users có quyền thương mại rộng hơn; free tier giữ lại nhiều quyền cho nhà cung cấp. Xem [Tripo Developer API](https://developers.tripo3d.ai/en/), [Pricing](https://www.tripo3d.ai/pricing) và [Terms](https://www.tripo3d.ai/terms).

Với asset thương mại, lưu snapshot Terms, plan, invoice, generation date và input reference; thực hiện thay đổi có tính sáng tạo rõ ràng trong Blender thay vì ship raw AI output.

### 4. Runtime 3D trên macOS

**RealityKit** là hướng native hiện tại của Apple cho 3D trên macOS, iOS, tvOS và visionOS. Nó hỗ trợ model, skeleton/animation, physics và USD/USDZ. Xem [RealityKit](https://developer.apple.com/documentation/realitykit).

**SceneKit không nên được chọn cho code mới.** Apple đã deprecated/soft-deprecated SceneKit và hướng dự án dài hạn sang RealityKit; USD là format được khuyến nghị khi chuyển đổi asset. Xem [SceneKit](https://developer.apple.com/documentation/scenekit/) và [Bringing SceneKit projects to RealityKit](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit).

Unity chỉ có ý nghĩa nếu Pet phát triển thành một mini-game lớn, cần gameplay editor, nhiều scene, physics phức tạp hoặc đa nền tảng. Nhúng một engine riêng vào app SwiftUI/AppKit hiện hữu làm tăng build, binary, lifecycle và release complexity quá mức cho một companion view.

## Pipeline đề xuất

### Pipeline A — MVP khuyến nghị: “3D-authored, 2D-shipped”

1. **Concept:** Krita/Clip Studio hoặc image generation để tạo 6–10 silhouette; chọn một silhouette đọc rõ ở 32–64 px.
2. **Character sheet:** front/side/back, neutral pose, 6 expression, prop/agent badge trong identity boundary.
3. **Model/rig:** Blender; tái sử dụng rig/action contract hiện có.
4. **Animation contract:** `idle`, `working`, `thinking`, `eatingToken`, `happy`, `hungry`, `sleeping`, `waitingApproval`, `error`, `levelUp`.
5. **Export:** camera/crop/pivot cố định, nền alpha; PNG sequence riêng cho từng state, 12–15 fps là đủ cho mascot nhỏ; đóng gói atlas trong build step.
6. **Runtime:** SwiftUI `TimelineView`/`Canvas` hoặc SpriteKit. Dừng animation khi panel ẩn; Reduce Motion dùng pose tĩnh hoặc crossfade.

Ưu điểm: nhanh, ít rủi ro, giữ được look 3D, dễ review pixel-perfect trong Light/Dark/grayscale, không thêm runtime dependency.

### Pipeline B — interactive vector: Rive

1. Vẽ body parts bằng Inkscape/Illustrator/Krita và import SVG/PNG vào Rive.
2. Rig bone/mesh, tạo state machine và blend state.
3. Expose data model tối thiểu:

   - `agent`: `codex | claudeCode`
   - `foodLevel`: `0...1`
   - `activity`: `idle | working | thinking | waitingApproval | error`
   - `eat`: trigger
   - `celebrate`: trigger
   - `reduceMotion`: boolean

4. Swift chỉ gửi normalized state; designer sở hữu transition/mixing trong `.riv`.
5. Pin runtime version; tạo screenshot/state regression test; giữ PNG fallback cho surface cần `ImageRenderer`.

### Pipeline C — real-time 3D v2

1. Blender low-poly source → USDZ.
2. RealityKit viewport chỉ chạy khi dashboard đang hiển thị.
3. POC bắt buộc xác minh clip naming/looping, alpha/background, load time, CPU/GPU/RAM và behavior trên Intel/Apple Silicon theo deployment policy.
4. Dock icon vẫn dùng pre-rendered sprite; không cố snapshot RealityKit bằng SwiftUI `ImageRenderer`.

## Mô hình token-as-food

Không nên đổi token thành thức ăn theo tỷ lệ 1:1; điều đó vừa tạo số quá lớn, vừa vô tình khuyến khích lãng phí token. Nên dùng delta theo agent đã chọn và một hàm có diminishing returns, ví dụ:

```text
foodUnits = min(dailyCap, log1p(weightedTokenDelta / 1_000))
```

`weightedTokenDelta` nên phân biệt input/output/cache theo dữ liệu thực tế, không giả vờ rằng token Codex và Claude Code có chi phí hoặc giá trị ngang nhau. Token chỉ là tín hiệu activity trong game; UI vẫn hiển thị số token thực ở dashboard hiện có.

Mỗi pet nên có cấu hình độc lập:

```text
PetDefinition
  id
  assetPackID
  selectedAgent: codex | claudeCode
  animationContractVersion
  feedingPolicyVersion
```

Khi telemetry stale/unavailable, không trừ “sức khỏe” như một hình phạt. Giữ last-known state và dùng animation unavailable/sleeping trung tính.

## POC nên làm trước khi sản xuất

1. Dùng robot hiện có, thêm `EatingToken`, `Happy`, `Hungry`, `Sleeping` trong Blender.
2. Export một atlas PNG và đặt cùng một `PetView` vào cả Codex lẫn Claude Code dashboard.
3. Thử cùng contract bằng một file Rive nhỏ; đo binary size, load time, CPU khi idle và khi hover.
4. So sánh hai hướng ở Light, Dark, Increased Contrast, Reduce Transparency, Reduce Motion và grayscale; state không được chỉ dựa vào màu.
5. Chỉ chọn real-time 3D sau khi RealityKit POC chứng minh rằng chất lượng tăng đủ lớn so với sprite nhưng vẫn giữ background work bounded.

## Rủi ro và điểm chưa xác minh

- Chưa có POC chứng minh `ImageRenderer` của DockMagic có thể chụp bất kỳ Rive/Spine/RealityKit view nào; tài liệu Apple cho thấy không nên kỳ vọng điều này.
- Rive Apple API mới còn experimental; cần pin version và không upgrade tự động trong release branch.
- Blender → USDZ có thể cần chuẩn hóa cách đóng gói nhiều animation clip; phải kiểm tra trực tiếp với asset Pet thật.
- Giá SaaS và điều khoản AI/animation tool có thể thay đổi; cần kiểm tra lại trước khi mua hoặc release.
- Live2D có rủi ro license đặc thù cho AI/chatbot/expandable application; cần xác nhận bằng văn bản nếu vẫn muốn chọn.
- Mixamo chỉ biped; Cascadeur/AI mocap không thay thế weight painting và deformation QA.

## Nguồn và phương pháp

Nghiên cứu ưu tiên tài liệu chính thức của Apple, Blender Foundation và nhà cung cấp; kiểm tra macOS support, format export, automation, license/giá và runtime trước khi xếp hạng. Các trang giá/license được truy cập ngày 2026-08-30. Dừng nghiên cứu khi ba pipeline có đủ bằng chứng để quyết định, các claim ảnh hưởng release đã có nguồn chính thức, và việc thêm công cụ khác không thay đổi shortlist.
