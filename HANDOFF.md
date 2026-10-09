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
│   └── SettingsManager.swift          # BYOK 密钥与端侧配置管理
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
        └── SettingsView.swift         # BYOK 模型服务商与 API Key 设置
```

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

---

### 🚧 进行中 / 下一阶段目标（Next Up）

- [ ] **第三阶段：足迹大地图与回忆面板升级**：
  - [ ] 足迹成就统计悬浮药丸（去过 X 城、打卡 Y 处地标）；
  - [ ] 智能过滤控制台（一键隐藏交通枢纽点）；
  - [ ] 历史回忆卡片的沉浸式图文排版。

- [ ] **第四阶段：行前准备（Checklist 打包助手）视觉与交互升级**：
  - [ ] 分组卡片折叠/展开、完成度环形指示器；
  - [ ] 模版一键套用与滑动快速勾选。

- [ ] **第五阶段：AI 导入流视觉动效**：
  - [ ] 类似雷达扫描与网页解构的波纹动画；
  - [ ] 校准草稿页的节点直接拖拽重排与地图拖拽纠偏。

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
