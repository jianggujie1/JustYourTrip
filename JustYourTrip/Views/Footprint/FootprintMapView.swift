import SwiftUI
import MapKit
import SwiftData

/// 足迹大地图分类筛选器
enum FootprintCategoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "全部"
    case attraction = "景点"
    case restaurant = "美食"
    case hotel = "住宿"
    case transit = "中转"
    
    var id: String { rawValue }
    
    var systemIcon: String {
        switch self {
        case .all: return "sparkles"
        case .attraction: return "star.fill"
        case .restaurant: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .transit: return "tram.fill"
        }
    }
}

/// 全局足迹大地图 (成就与回忆 Tab - 探索勋章与悬浮空间感)
struct FootprintMapView: View {
    @Query(filter: #Predicate<RouteNode> { $0.isVisited }, sort: \RouteNode.visitedAt, order: .reverse)
    private var visitedNodes: [RouteNode]
    
    @State private var selectedCategory: FootprintCategoryFilter = .all
    @State private var hideTransit: Bool = true
    @State private var selectedNode: RouteNode?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showNavigationDialog: Bool = false
    
    private var displayedNodes: [RouteNode] {
        visitedNodes.filter { node in
            // 过滤中转站
            if hideTransit && node.nodeType.isTransitOnly {
                return false
            }
            // 分类筛选
            switch selectedCategory {
            case .all:
                return true
            case .attraction:
                return node.nodeType == .attraction
            case .restaurant:
                return node.nodeType == .restaurant
            case .hotel:
                return node.nodeType == .hotel
            case .transit:
                return node.nodeType.isTransitOnly
            }
        }
    }
    
    private var uniqueCitiesCount: Int {
        Set(visitedNodes.compactMap { $0.day?.trip?.destination }.filter { !$0.isEmpty }).count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // 1. MapKit 足迹底板
                Map(position: $cameraPosition) {
                    ForEach(displayedNodes) { node in
                        Annotation(node.title, coordinate: node.coordinate) {
                            markerView(for: node)
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        selectedNode = node
                                        cameraPosition = .region(
                                            MKCoordinateRegion(
                                                center: node.coordinate,
                                                latitudinalMeters: 1600,
                                                longitudinalMeters: 1600
                                            )
                                        )
                                    }
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapUserLocationButton()
                    MapScaleView()
                }
                
                // 2. 顶部悬浮空间组件：漫游探索成就岛与分类筛选
                VStack(spacing: 8) {
                    achievementHeaderIsland
                    
                    categoryFilterBar
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // 3. 底部选中的回忆明信片卡片
                if let selected = selectedNode {
                    FootprintCardView(
                        node: selected,
                        onClose: {
                            withAnimation(.spring) {
                                self.selectedNode = nil
                            }
                        },
                        onNavigate: {
                            showNavigationDialog = true
                        }
                    )
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // 4. 空足迹状态引导浮层
                if visitedNodes.isEmpty {
                    emptyFootprintOverlay
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
                }
            }
            .navigationTitle("全局足迹大地图")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "请选择导航应用",
                isPresented: $showNavigationDialog,
                titleVisibility: .visible
            ) {
                if let target = selectedNode {
                    let relay = NavigationRelayService.shared
                    ForEach(relay.availableApps) { app in
                        Button(app.rawValue) {
                            HapticFeedback.light()
                            relay.launchNavigation(
                                to: target.coordinate,
                                destinationName: target.title,
                                mode: target.incomingTransit,
                                app: app
                            )
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
            } message: {
                if let target = selectedNode {
                    Text("重游目的地：\(target.title)")
                }
            }
        }
    }
    
    // MARK: - 地图标记 Pin
    
    @ViewBuilder
    private func markerView(for node: RouteNode) -> some View {
        let isSelected = selectedNode?.id == node.id
        let color = markerColor(for: node)
        
        ZStack {
            if isSelected {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 52, height: 52)
                    .blur(radius: 4)
            }
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2.5 : 2)
                )
                .shadow(color: color.opacity(isSelected ? 0.45 : 0.25), radius: isSelected ? 8 : 4, x: 0, y: 2)
            
            Image(systemName: node.nodeType.systemIcon)
                .font(.system(size: isSelected ? 16 : 12, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
    
    private func markerColor(for node: RouteNode) -> Color {
        switch node.nodeType {
        case .attraction: return AppTheme.sunsetCoral
        case .restaurant: return AppTheme.warmAmber
        case .hotel: return AppTheme.royalPurple
        case .transitBus: return AppTheme.skyTeal
        case .transitSub: return AppTheme.indigoPrimary
        case .parkingLot: return Color.brown
        case .other: return AppTheme.sageMint
        }
    }
    
    // MARK: - 顶部探索成就统计岛
    
    private var achievementHeaderIsland: some View {
        HStack {
            // 城市与足迹计数
            HStack(spacing: 16) {
                HStack(spacing: 7) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.sageMint)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(uniqueCitiesCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("探索城市")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                    .frame(height: 22)
                
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.warmAmber)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(displayedNodes.count)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("打卡回忆")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 20)
            
            Spacer()
            
            // 中转过滤开关
            Button {
                HapticFeedback.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    hideTransit.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: hideTransit ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11))
                    Text(hideTransit ? "已隐中转" : "全部站点")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(hideTransit ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                .foregroundStyle(hideTransit ? Color.white : Color.primary)
                .clipShape(Capsule())
                .shadow(color: hideTransit ? AppTheme.sageMint.opacity(0.3) : .clear, radius: 4)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 分类筛选胶囊栏
    
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FootprintCategoryFilter.allCases, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: category.systemIcon)
                                .font(.system(size: 10))
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(AppTheme.forestPrimary) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85)))
                        )
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? AnyShapeStyle(AppTheme.sageMint.opacity(0.6)) : AnyShapeStyle(AppTheme.cardGlassBorder), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 空状态提示浮层
    
    private var emptyFootprintOverlay: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.forestPrimary.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "map.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(AppTheme.sageMint)
            }
            
            Text("足迹墙尚未解锁")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            
            Text("在行程中点击标记打卡节点，就能在这张大地图上永久点亮你的城市探险回忆。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
    }
}
