# 「你的旅游」（YourTrip）

专属于个人的闭环出行管理中枢 —— **本地优先（Local-First）、零服务器开销、绝对隐私、丝滑互联**。
基于 Swift 6 + SwiftUI + SwiftData + MapKit 深度定制的 iOS / iPadOS 纯原生单机向应用。

---

## 🌟 核心特性与架构实现

### 1. 行程规划与攻略协同（主 Tab：行程即攻略）
- **地图底板 + 上拉抽屉（Bottom Sheet）联动**：基于 iOS 17+ 原生 `Map` 与 `.presentationDetents`（半屏、全屏与折叠多档位切换）。
- **多模态混合交通串联（Multi-modal）**：
  - 节点类型：景点（Attraction）、餐饮（Restaurant）、酒店（Hotel）、公交站（TransitBus）、地铁站/出入口（TransitSub）、停车场（ParkingLot）。
  - 路段连线按交通方式渲染：自驾/打车（实线）、公共交通（粗线）、步行（虚线）。
  - 节点间详细换乘指引（如：“乘地铁2号线往浦东机场方向，坐3站至陆家嘴站C口出”）。
- **打卡流转状态机**：点击一键打卡（`isVisited = true`），自动变灰归档并高亮引导下一路段。
- **混合导航中继**：集成 `NavigationRelayService`，一键呼起本机已安装的**高德地图**、**百度地图**或 **Apple 地图**，自动带入经纬度与交通出行方式。

### 2. 全局足迹大地图（成就与回忆 Tab）
- **独立全屏视觉展示**：在大地图上聚类渲染所有打卡历史。
- **智能中转过滤**：右上角提供“隐藏中转站”开关，自动剥离公交站和地铁口，足迹墙干净清晰。
- **点选回顾卡片**：轻触历史足迹图钉，弹出轻量卡片回顾打卡时间、所属行程及避坑随笔。

### 3. 行前准备（Checklist 打包助手 Tab）
- **分组归类**：按证件票务、数码装备、穿搭衣物、个人药品、个护洗漱、其他定制六大维度分类。
- **进度可视**：顶部实时圆形环状进度条与完成百分比。
- **模版一键复用**：内置 12 项经典旅行打包清单一键快速套用。

### 4. 小红书 / 社媒攻略 AI 导入 Skill
- **端侧无头抓取（WebSnifferService）**：利用后台无头 `WKWebView` 载入用户复制的短链接，利用 WebKit 引擎解析并提取页面标题与正文文本。
- **直连 LLM 结构化提取（LLMParserService）**：纯端侧使用 `URLSession` 直连大模型（DeepSeek / OpenAI 兼容协议），强制 JSON Mode 提取结构化多模态行程。
- **地理编码（GeocodingService）**：利用 `CLGeocoder` 自动将地名反查为经纬度。
- **人机校准与草稿预览（DraftCalibrationView）**：入库前在地图上直观预览，支持微调点位坐标、编辑交通指引与调整顺序后一键保存至 SwiftData。

### 5. BYOK 设置与绝对隐私
- 支持用户自带 API Key（DeepSeek / OpenAI / Moonshot 等），所有密钥仅持久化存储在端侧设备，绝不上报任何中转服务器。

---

## 📁 项目目录结构

```text
JustYourTrip/
├── JustYourTrip.xcodeproj/          # 完整的 Xcode 工程文件 (已配置 iOS 17.0+ 编译目标)
├── JustYourTrip/
│   ├── App/
│   │   └── JustYourTripApp.swift     # @main 入口与 SwiftData ModelContainer 初始化
│   ├── Models/
│   │   ├── TripPlan.swift            # 行程主模型
│   │   ├── TripDay.swift             # 每日日程模型
│   │   ├── RouteNode.swift           # 多模态节点模型 (包含 NodeType 与 TransitType)
│   │   ├── ChecklistItem.swift       # 行前准备清单模型
│   │   └── MockData.swift            # 首次启动演示数据 (上海经典与漫游路线)
│   ├── Services/
│   │   ├── NavigationRelayService.swift # URL Scheme 导航中继 (Apple/高德/百度)
│   │   ├── LLMParserService.swift       # 直连大模型结构化路线提取服务
│   │   ├── WebSnifferService.swift      # 纯端侧无头 WKWebView 网页嗅探服务
│   │   ├── GeocodingService.swift       # CLGeocoder 地理编码与坐标反查
│   │   └── SettingsManager.swift        # BYOK 设置与本地持久化
│   ├── Views/
│   │   ├── MainTabView.swift         # 底部 TabView 容器
│   │   ├── Trip/
│   │   │   ├── TripListView.swift       # 行程列表首页与卡片
│   │   │   ├── TripDetailMapView.swift  # MapKit 地图底板与抽屉联动主视图
│   │   │   ├── TripDayTimelineSheet.swift # 底部抽屉竖向时间轴
│   │   │   ├── NodeCardView.swift       # 时间轴单节点卡片
│   │   │   ├── NodeMarkerView.swift     # 地图自定义图钉标记
│   │   │   ├── AddTripSheet.swift       # 新建行程弹窗
│   │   │   └── AddNodeSheet.swift       # 添加节点弹窗
│   │   ├── Footprint/
│   │   │   ├── FootprintMapView.swift   # 全局足迹大地图
│   │   │   └── FootprintCardView.swift  # 足迹回忆回顾卡片
│   │   ├── Checklist/
│   │   │   ├── ChecklistTabView.swift   # 行前清单主页面与进度条
│   │   │   └── AddChecklistItemSheet.swift # 新增行李物品弹窗
│   │   ├── AIImport/
│   │   │   ├── AIImportSheet.swift      # AI 攻略导入浮层 (剪贴板嗅探与解析)
│   │   │   └── DraftCalibrationView.swift # 草稿人机校准与入库页
│   │   └── Settings/
│   │       └── SettingsView.swift       # BYOK 密钥配置与服务预设切换
│   └── Resources/
│       └── Info.plist                # 包含高德/百度 URL Schemes 白名单与定位权限
└── README.md
```

---

## 🚀 运行与构建

可以直接双击打开 `JustYourTrip.xcodeproj`，在 Xcode 中选择 iOS 模拟器（如 iPhone 16 Pro）或真机，按 `Cmd + R` 即可运行：

```bash
# 命令行编译验证 (iOS Simulator)
xcodebuild build -project JustYourTrip.xcodeproj -scheme JustYourTrip -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```
已通过 `xcodebuild` 验证，**BUILD SUCCEEDED**。
