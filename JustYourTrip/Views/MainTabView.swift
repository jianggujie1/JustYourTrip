import SwiftUI

/// iPad 侧边栏导航枚举
enum AppSidebarItem: String, CaseIterable, Identifiable, Hashable {
    case trips = "行程规划"
    case footprint = "足迹大地图"
    case checklist = "行前准备"
    case settings = "设置与数据"
    
    var id: String { rawValue }
    
    var systemIcon: String {
        switch self {
        case .trips: return "map.fill"
        case .footprint: return "location.north.circle.fill"
        case .checklist: return "checklist"
        case .settings: return "gearshape.fill"
        }
    }
}

/// 应用主导航容器 (根据屏幕宽度自适应 iPad NavigationSplitView 与 iPhone TabView)
struct MainTabView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: Int = 0
    @State private var selectedSidebarItem: AppSidebarItem? = .trips
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    @State private var showAIImportSheet: Bool = false
    @State private var showAddTripSheet: Bool = false

    var body: some View {
        if horizontalSizeClass == .regular {
            ipadSplitLayout
        } else {
            phoneTabLayout
        }
    }
    
    // MARK: - iPad 宽屏 NavigationSplitView 架构
    
    private var ipadSplitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedSidebarItem) {
                // 顶部品牌手账 Header
                Section {
                    sidebarBrandHeader
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                
                // 主导航功能项
                Section("探索与行囊") {
                    NavigationLink(value: AppSidebarItem.trips) {
                        Label {
                            Text(AppSidebarItem.trips.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        } icon: {
                            Image(systemName: AppSidebarItem.trips.systemIcon)
                                .foregroundStyle(AppTheme.forestPrimary)
                        }
                    }
                    .tag(AppSidebarItem.trips)
                    
                    NavigationLink(value: AppSidebarItem.footprint) {
                        Label {
                            Text(AppSidebarItem.footprint.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        } icon: {
                            Image(systemName: AppSidebarItem.footprint.systemIcon)
                                .foregroundStyle(AppTheme.sageMint)
                        }
                    }
                    .tag(AppSidebarItem.footprint)
                    
                    NavigationLink(value: AppSidebarItem.checklist) {
                        Label {
                            Text(AppSidebarItem.checklist.rawValue)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        } icon: {
                            Image(systemName: AppSidebarItem.checklist.systemIcon)
                                .foregroundStyle(AppTheme.sunsetCoral)
                        }
                    }
                    .tag(AppSidebarItem.checklist)
                }
                
                // 工具与偏好
                Section("系统与手账") {
                    NavigationLink(value: AppSidebarItem.settings) {
                        Label {
                            Text(AppSidebarItem.settings.rawValue)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        } icon: {
                            Image(systemName: AppSidebarItem.settings.systemIcon)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(AppSidebarItem.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("你的旅游")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        HapticFeedback.medium()
                        showAIImportSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                            Text("AI 导入")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.forestPrimary)
                    }
                    .ipadHoverEffect()
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.light()
                        showAddTripSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("新建行程")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.sageMint)
                    }
                    .ipadHoverEffect()
                }
            }
            .sheet(isPresented: $showAIImportSheet) {
                AIImportSheet()
            }
            .sheet(isPresented: $showAddTripSheet) {
                AddTripSheet()
            }
        } detail: {
            detailContentView
        }
        .tint(AppTheme.forestPrimary)
    }
    
    // MARK: - 侧边栏品牌 Header
    
    private var sidebarBrandHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.forestDeep)
                    .frame(width: 42, height: 42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                    )
                
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.luminousMint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("你的旅游")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                
                Text("专属于个人的闭环出行中枢")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - iPad Detail 主内容区
    
    @ViewBuilder
    private var detailContentView: some View {
        switch selectedSidebarItem ?? .trips {
        case .trips:
            TripListView()
        case .footprint:
            FootprintMapView()
        case .checklist:
            ChecklistTabView()
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
    
    // MARK: - iPhone / 窄屏分屏 TabView 布局
    
    private var phoneTabLayout: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 行程与攻略联动
            TripListView()
                .tabItem {
                    Label("行程", systemImage: "map.fill")
                }
                .tag(0)
            
            // Tab 2: 全局足迹大地图
            FootprintMapView()
                .tabItem {
                    Label("足迹", systemImage: "location.north.circle.fill")
                }
                .tag(1)
            
            // Tab 3: 行前打包清单
            ChecklistTabView()
                .tabItem {
                    Label("行前准备", systemImage: "checklist")
                }
                .tag(2)
        }
        .tint(AppTheme.forestPrimary)
        .onChange(of: selectedTab) { _, _ in
            HapticFeedback.selection()
        }
    }
}
