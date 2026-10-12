# 🚀 JustYourTrip 项目交接与开发进度中枢 (HANDOFF.md)

> **💡 说明**：本文档旨在解决**跨设备切换（Handoff）开发**时无会话上下文同步的问题。无论是换一台电脑、在不同环境打开项目，或是重开新的 AI 会话，任何开发者或 AI 助理只需阅读本文档，即可 100% 无缝复原全部设计规范、代码架构、开发进度及避坑准则。
>
> 📌 **维护原则**：每当完成一项特性改造或有重要架构变动时，**必须同步更新本文档的「当前进度」与「待办列表」**并提交至 Git。

---

## 🤖 AI 助理接力必读（Quick Guide for AI Agents）

如果你是在新设备或新会话中被唤醒接手本项目的 AI 助理，请**严格遵守**以下准则：

1. **绝对禁止修改 Signing Team**：
   * 本工程的开发者团队配置为 `JTQCQL8MVH`（团队名称：`顾杰 蒋 (Personal Team)`）。
   * 无论修改任何构建配置或文件，**绝不可**清除或修改 `DEVELOPMENT_TEAM`。
2. **终端沙盒模式执行注意**：
   * 用户本地 shell 采用 `/opt/local/bin/zsh`，若使用标准沙盒（`BypassSandbox: false`）可能会报错；在执行终端命令（如 `xcodebuild`、`git`）时，请使用 `BypassSandbox: true`。
3. **改动验证机制**：
   * 任何 Swift 代码或工程改动后，必须运行以下命令验证编译：
     ```bash
     xcodebuild build -project JustYourTrip.xcodeproj -scheme JustYourTrip -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
     ```
   * 确保结果为 `** BUILD SUCCEEDED **` 后，方可进行 Git 提交与推送。
4. **提交代码前更新此文档**：
   * 每次完成任务后，更新本文档中的进度状态，并随同代码一并 commit 和 push 到 GitHub（`https://github.com/jianggujie1/JustYourTrip.git` 分支 `main`）。

---

## 🧭 项目定位与设计哲学

* **项目名称**：你的旅游（英文：*JustYourTrip* / *YourTrip*）
* **产品形态**：iOS / iPadOS 17+ 纯原生单机向应用（基于 Swift 6 + SwiftUI + SwiftData + MapKit）
* **核心价值观**：
  * **本地优先（Local-First）**：无中心化后端服务器，毫秒级响应，离线完全可用。
  * **零服务器运维**：数据持久化于本地 SQLite（SwiftData），借助 Apple 官方 iCloud（CloudKit）静默多设备同步。
  * **绝对隐私与 BYOK**：直连大模型 API（DeepSeek / OpenAI），API Key 纯端侧 Keychain/UserDefaults 保存，绝不经过中转代理。
  * **混合交通串联（Multi-modal）**：既是景点攻略，更是真实路况中枢，深度管理地铁站出入口、公交停靠点、停车场，并一键调起高德/百度/Apple 地图精准导航。
  * **极高审美（Muzli / Apple HIG）**：深邃自然森林绿基调、鼠尾草微光薄荷高光、多层物理纸质堆叠卡片、毛玻璃边框。

---

## 🎨 视觉设计规范（Design System）

统一维护于 `JustYourTrip/Theme/AppTheme.swift`：

| 色彩 / 材质 | HEX / 属性 | 用途 |
|---|---|---|
| **森林极深绿** (`forestDeep`) | `#0D2620` | 主界面深邃底色、沉稳基调 |
| **经典墨绿** (`forestPrimary`) | `#1F5F4B` | 品牌主色、主卡片底衬渐变起点 |
| **鼠尾草薄荷绿** (`sageMint`) | `#52B788` | 核心高光、选中胶囊、打卡成功态 |
| **荧光微亮薄荷** (`luminousMint`) | `#74D7BA` | 渐变终点、高对比度图标与状态光圈 |
| **沙漠暖金** (`warmAmber`) | `#F4A261` | 美食推荐、Vibe 标签点缀 |
| **晚霞珊瑚红** (`sunsetCoral`) | `#FF6B52` | 核心打卡高光、倒计时急迫态 |
| **毛玻璃描边** (`cardGlassBorder`) | `white 35% -> 6%` | 空间立体边框，悬浮卡片投影 |
| **物理卡片堆叠** | `scaleEffect` + `offset` | 行程卡片底部的双层背板厚度感 |

---

## 🏗️ 核心架构与代码地图

```text
JustYourTrip/
├── App/
│   └── JustYourTripApp.swift          # @main 入口，注入 SwiftData ModelContainer
├── Models/
│   ├── TripPlan.swift                 # 行程模型 (title, destination, vibeTags, startDate, days, checklistItems)
│   ├── TripDay.swift                  # 每日日程 (dayNumber, date, title, nodes)
│   ├── RouteNode.swift                # 节点模型 (NodeType, transitInstruction, transitType, isVisited, latitude, longitude)
│   ├── ChecklistItem.swift            # 行前行李清单项 (title, category, isChecked)
│   └── MockData.swift                 # 演示数据 (上海经典外滩Citywalk + 漫游路线)
├── Services/
│   ├── NavigationRelayService.swift   # URL Scheme 导航中继 (调起高德/百度/Apple地图)
│   ├── LLMParserService.swift         # 直连大模型结构化路线提取 (JSON Mode)
│   ├── WebSnifferService.swift        # 纯端侧无头 WKWebView 笔记文本抓取
│   ├── GeocodingService.swift         # CLGeocoder 地理编码与坐标反查
│   ├── SettingsManager.swift          # BYOK 密钥与端侧配置管理
│   └── TripBackupService.swift        # 离线 JSON 全量备份导出/恢复与 API 连通性测试
├── Theme/
│   └── AppTheme.swift                 # 全局色系、渐变、Taptic 反馈与卡片 Modifier
└── Views/
    ├── MainTabView.swift              # 底部 Tab 容器 (行程规划 / 足迹大地图 / 行前准备 / 设置)
    ├── Trip/
    │   ├── TripListView.swift         # 行程列表首页 (探索感 Header + 堆叠卡片)
    │   ├── TripDetailMapView.swift    # 地图底板与抽屉联动主视图
    │   ├── TripDayTimelineSheet.swift # 底部抽屉竖向时间轴
    │   ├── NodeCardView.swift         # 时间轴单节点卡片
    │   ├── NodeMarkerView.swift       # 地图自定义脉冲图钉
    │   ├── AddTripSheet.swift         # 新建行程弹窗 (含 Vibe 风格点选)
    │   └── AddNodeSheet.swift         # 手动添加打卡节点弹窗
    ├── Footprint/
    │   ├── FootprintMapView.swift     # 全局打卡足迹大地图
    │   └── FootprintCardView.swift    # 历史足迹回忆卡片
    ├── Checklist/
    │   ├── ChecklistTabView.swift     # 行前准备主页面 (六大分类 + 环形进度)
    │   └── AddChecklistItemSheet.swift# 新增行李物品弹窗
    ├── AIImport/
    │   ├── AIImportSheet.swift        # 小红书/社媒链接粘贴嗅探与提取
    │   └── DraftCalibrationView.swift # 地图预览校准与一键入库
    └── Settings/
        └── SettingsView.swift         # 护照 Header · BYOK 配置 · 连通性测试 · 离线全量 JSON 备份

---

## 📊 开发里程碑与当前状态（Progress Status）

### ✅ 已完成模块（Completed）
- [x] **架构基础与数据模型**：SwiftData 全量模型设计与关联，支持离线持久化与级联删除。
- [x] **导航中继服务**：`NavigationRelayService` 支持检测已安装应用并跳转高德、百度或原生 Apple 地图。
- [x] **纯端侧 AI 导入链路**：`WebSnifferService`（无头 WKWebView）+ `LLMParserService`（JSON Mode）+ `GeocodingService`。
- [x] **BYOK 与安全管理**：支持自定义 BaseURL、API Key 本地加密保存。
- [x] **GitHub 远端仓库联通**：仓库地址 `https://github.com/jianggujie1/JustYourTrip.git`，已打通自动推送。
- [x] **开发者签名团队锁定**：`JTQCQL8MVH`（顾杰 蒋），完全固化，杜绝重置。
- [x] **第一阶段视觉升级（Muzli 灵感）**：
  - [x] 全局森林深翠与鼠尾草薄荷色系重构；
  - [x] 行程卡片多层物理堆叠效果（Physical Layered Stacking）；
  - [x] Trip Vibe 情绪风格标签系统（创建时支持 9 种预设点选并在卡片呈现）；
  - [x] 探索感 Header（*Where Will You Go Next?*）与出发倒计时指示。
- [x] **第二阶段：行程详情页与抽屉式时光轴全面改造**：
  - [x] **连续时光轴步进轨迹（Timeline Stepper Track）**：左侧连续贯穿轴线、节点状态指示圆环（打卡绿标、待去序号、选中光晕）；
  - [x] **节点间换乘指引气泡（Transit Guidance Pill）**：在节点连接段之间嵌入清晰的交通换乘胶囊；
  - [x] **节点富媒体卡片升级（NodeCardView）**：仿旅行手账贴纸的「避坑便签（Tips Sticky Note）」、打卡切换与精准导航中继按钮；
  - [x] **天数切换横滑胶囊条（Day Switcher Bar）**：展示 Day 序号、日期、当日节点完成度统计（`2/4 站`）及顶部细致进度条；
  - [x] **地图与图钉交互（NodeMarkerView & TripDetailMapView）**：图钉展示顺序数字序号角标、选中双层脉冲光环、顶部半透明悬浮控制岛及「一键全览（focusAllDayNodes）」视野自适应。
- [x] **第三阶段：足迹大地图与回忆面板升级**：
  - [x] **漫游探索成就岛（Achievement Header Island）**：探索城市统计、打卡回忆计数微标；
  - [x] **多分类快捷筛选条（Category Filter Bar）**：支持在地图上快速筛选「全部/景点/美食/住宿/中转」点位；
  - [x] **明信片风回忆卡片（FootprintCardView）**：仿旅行明信片邮戳、城市标签与手账心得随笔；
  - [x] **未解锁空状态引导**：优雅引导用户在行程中打卡点亮足迹大地图。
- [x] **第四阶段：行前准备（Checklist 打包助手）视觉与交互升级**：
  - [x] **双环形打包收纳仪表盘（Dual-ring Progress Header）**：实时计算总进度与特需/关键必备物品完成状态；
  - [x] **手账折叠分类卡片（Accordion Category Cards）**：支持六大分类单独展开/折叠、分类专属彩色徽章与计数胶囊；
  - [x] **触感交互行卡片（ChecklistItemRow）**：勾选伴随触觉微震、文本划线与完成态动画，支持右侧快速删除；
  - [x] **快捷操作菜单**：一键套用 12 项经典出行模版、一键重置勾选状态；
  - [x] **按行程切换胶囊条（Trip Picker Bar）**：自由在全局清单与各个独立行程打包清单间无缝切换。
- [x] **第五阶段：AI 导入流视觉动效与草稿校准升级**：
  - [x] **三步骤解析流水线与雷达脉冲动效（AIImportSheet）**：网页嗅探、模型解构、地理反查三阶段状态机流转与发光脉冲光点；
  - [x] **一键快速体验样例（Quick Preset Banner）**：无需手动寻找社媒链接，一键填入上海武康路安福路经典 Citywalk 示例；
  - [x] **全景动态草稿地图（DraftCalibrationView）**：带实线轨迹连线 `MapPolyline`、数字序号 Pin、一键全览当日视野（`fitMapToCurrentDay`）；
  - [x] **手账风格草稿节点卡片与拖拽调序**：支持在校准阶段上下拖拽重排顺序（`.onMove`）、左滑删除（`.onDelete`）、微调经纬度与游玩时长（`EditDraftNodeSheet`）；
  - [x] **AI 行前特需必备行李推荐入库**：直观展示 AI 针对该行程生成的特需物品，一键入库自动同步至行前准备模块。
- [x] **第六阶段：设置页与手账数据中心升级（SettingsView & TripBackupService）**：
  - [x] **旅行护照风 Header**：极客单机向、纯端侧本地优先认证签注徽标；
  - [x] **主流大模型预设与连通性测试（Ping）**：支持 DeepSeek、OpenAI、Kimi、硅基流动一键切换，自带低耗时端侧 Ping 延迟探测；
  - [x] **离线全量 JSON 备份与恢复（Data Vault）**：一键导出所有行程与行李至 `.json`，支持系统分享与本地文件恢复导入；
  - [x] **官方示例重置与偏好控制**：一键追加官方示例行程，足迹大地图中转站智能过滤联动。
- [x] **第七阶段：主界面行程卡片重构与详情转场无缝联动（TripCard & Seamless Zoom Transition）**：
  - [x] **彻底消除易误解的假叠层背板**：移除造成卡片堆栈/展开误解的顶部 offset 假层，改为纯粹、大气的现代旅行路书单体卡片（Modern Travel Card）；
  - [x] **卡片视觉与信息架构大升级**：新增智能出行状态徽标（已全部打卡 / 旅途中 / 今日出发 / X天后出发 / 漫游回忆）、目的地徽标、更饱满的圆角设计系统与双层环境投影；
  - [x] **首发路线亮点速览（Mini Itinerary Stepper）**：直接在卡片上萃取展示前 3 站打卡精选点位、分类类型图标与剩余站数胶囊；
  - [x] **卡片原生缩放转场（Native Zoom Transition）**：基于 iOS 18 原生 `zoom` 转场与降级适配，点击卡片时卡片自适应展开放大至全屏地图详情，轻触返回即平滑缩放回原卡片位置；
  - [x] **详情页控制岛与抽屉联动优化**：顶部控制岛内嵌毛玻璃圆形返回键，抽屉呈现延时平滑升起，隐藏底部 TabBar 杜绝层级与手势冲突。
- [x] **第八阶段：AI 导入流式传输升级与问答式实时打字体验（Streaming AI Import & Live Console）**：
  - [x] **直连大模型 SSE 流式输出重构（LLMParserService）**：将原先单次阻塞等待的 POST 请求升级为 `stream: true` 的 Server-Sent Events 流式长连接（宽限 180s），从根源杜绝慢速大模型超时报错；
  - [x] **AI 问答式打字机实时视窗（Streaming Console）**：在 AI 构思过程中实时逐字打字呈现内容，携带呼吸脉冲光标 `▊`、字数统计胶囊与自适应滚动；
  - [x] **深度思考模型（DeepSeek-R1）推理过程可视化**：支持捕获并以折叠气泡独立展示 `reasoning_content` 思考过程；
  - [x] **超强容错 JSON 智能萃取器**：支持从混杂前言、自然对话或 Markdown 标记的流式输出中提取纯净合法的结构化 JSON，并在 DTO 层提供缺省宽容解码；
  - [x] **支持中途随时中断解析**：底层 Task 支持快速响应取消（Cancellation），按钮状态在「开始」与「中断」间自适应流转。
- [x] **第九阶段：双引擎智能网页嗅探与社媒链接真实正文解析（Dual-Engine Web Sniffer & Real Content Extraction）**：
  - [x] **全场景 URL 正则识别与清洗（WebSnifferService）**：支持精准识别小红书（`xhslink.com/...`）、抖音（`v.douyin.com/...`）、微信公众号、携程、马蜂窝等各类带/不带协议头网址与短链接，自动剥除末尾中文标点与多余字符；
  - [x] **双引擎端侧抓取架构（Dual-Engine Architecture）**：
    - **Engine 1（高速 HTTP 直连，~0.3s）**：自动跟随 302 重定向，专精萃取小红书 `window.__INITIAL_STATE__` / `__INITIAL_DATA__`、`og:description`、`<meta name="description">`、`<title>` 与去除标签后的文章真实段落正文；
    - **Engine 2（无头 WebKit 降级兜底）**：针对重客户端 JS 渲染的 SPA 动态页面，提供 100x100 离屏真实 DOM 注入与执行，防止被 iOS WebKit 激进节流；
  - [x] **智能社媒模版文案净化（cleanSocialBoilerplate）**：自动过滤“快来看吧！复制本条信息打开小红书 App”等模版废话，萃取真正有效的游记攻略正文；
  - [x] **输入框实时链接感知（Live URL Perception Badge）**：用户粘贴或输入内容包含网址时，下方即刻展现绿色发光微章，明确告知已识别链接及“将自动联网抓取正文”；
  - [x] **抓取状态透明化与反爬友好指引（Anti-Crawler Fallback & Guidance）**：
    - 抓取成功时，流程卡片透出“已成功提取《...》（共 X 字）”；
    - 若平台因反爬滑块拦截且用户未贴文案，立即阻断向大模型传递死链（杜绝大模型幻觉与报错），并在界面以高亮卡片给出清晰指引：“请在小红书长按文案选择「复制文案」，直接粘贴到输入框”，并附带一键重试/示例按钮。
- [x] **第十阶段：智能空间拓扑校验、城市锚点与高精度地图 POI 纠偏系统（Spatial Topology & High-Precision Geocoding）**：
  - [x] **彻底杜绝坐标扎堆重叠与跨省偏离**：分析并根除原先 `CLGeocoder` 易受频率限制、口语地名检索失败而全部静默退回上海默认点 `(31.2304, 121.4737)` 的根本缺陷；
  - [x] **全球 60+ 热门旅游城市基准锚点库（City Anchor Database）**：内置主流城市高精中心基准，动态以目的地为几何原点约束检索范围（`region: 80km`），从根源杜绝“同名景点跳往外省”造成的巨大飞线；
  - [x] **多层级混合高精 POI 纠偏管道（Multi-tier Resolution Pipeline）**：
    - **Tier 1（MapKit 原生 POI 检索）**：调用 `MKLocalSearch` 结合城市 Region 约束，精准秒级解析地标（如“武康大楼”、“安福路”、“东方明珠”）；
    - **Tier 2（CLGeocoder 地址反查）**：带城市前缀且施加 120km 离群阻断校验，拦截异地同名点；
    - **Tier 3（AI 经纬度先验注入与校准）**：大模型结构化输出 `searchKeyword`、`estimatedLatitude`、`estimatedLongitude`，在符合城市半径时双向校验采纳；
    - **Tier 4（智能微分散局部兜底）**：未命中的罕见点自动依附于当日游玩前序站点，并施加角度微分散偏移，绝不堆叠重合；
  - [x] **整路线拓扑健康度检查与防重合（Disambiguation & Sanitize）**：行程生成后全局遍历，距离 < 20 米的异名站点自动向外分散（~180m），严重离群点强制拉回；
  - [x] **人机交互实时地图纠偏（Interactive Recalibration in EditDraftNodeSheet）**：节点编辑弹窗新增“地图精准搜索纠偏”，用户可输入地名一键检索苹果/高德地图官方 POI 并「一键采纳」，彻底告别繁琐的手动输入数字经纬度。
- [x] **第十一阶段：行程详情页与列表转场一体化重构（In-View Bottom Drawer & Seamless Pop Transition）**：
  - [x] **根除模态 Sheet 异步延迟脱节**：将原先基于系统独立 `UIPresentationController` 的模态 `.sheet(isPresented: $isSheetPresented)` 重构为完全内嵌于 `TripDetailMapView` 视图层次树内的 `TripDayTimelineDrawer`；
  - [x] **全要素一体化转场与协同退出**：地图底板、顶部悬浮控制岛与底部时间轴抽屉彻底归于同一页面视图树，无论是点击返回键还是边缘侧滑返回，地图与抽屉 100% 毫秒级同步平滑缩放/滑动回行程卡片，彻底消除“地图切走了、抽屉还悬空滞留再迟钝消失”的割裂体验；
  - [x] **全手势物理阻尼与多档吸附（DrawerDetent）**：自研轻量高质感的折叠态（`collapsed` ~210pt + 底部安全区，露头首站并最大化地图视野）、半屏态（`medium` 约 48%）、全屏态（`expanded` 留出顶部控制岛），支持惯性速度吸附、微阻尼回弹、单击抓手/折叠键自适应切换；
  - [x] **地图全览与选点智能联动**：点击顶部「全览」自动折叠抽屉至最小高度展示全景地图；点击地图图钉自动升起至半屏态并平滑定位至对应卡片；
  - [x] **原生边缘侧滑返回修复**：通过 `UINavigationController` 扩展解决自定义导航栏返回按钮导致的系统边缘侧滑返回失效问题。

---

### 🚧 后续优化方向（Future Roadmap）

- [ ] **多端适配与体验细节**：
  - [ ] iPadOS 宽屏分栏 SplitView 与大屏地图优化；
  - [ ] 行程卡片长按快速生成分享长图（旅行路书明信片卡）。

---

## 🛠️ 常用开发命令速查

```bash
# 1. 验证工程编译（iOS 模拟器）
xcodebuild build -project JustYourTrip.xcodeproj -scheme JustYourTrip -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# 2. 提交与推送
git add .
git commit -m "<type>(<scope>): <message>"
git push origin main

# 3. 重新同步 Xcode 工程引用 (若新增了 Swift 文件且 Xcode 树未显示)
python3 generate_xcodeproj.py
```
