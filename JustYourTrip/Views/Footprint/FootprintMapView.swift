import SwiftUI
import MapKit
import SwiftData

/// 全局足迹大地图 (成就与回忆 Tab - 探索勋章与悬浮空间感)
struct FootprintMapView: View {
    @Query(filter: #Predicate<RouteNode> { $0.isVisited }, sort: \RouteNode.visitedAt, order: .reverse)
    private var visitedNodes: [RouteNode]
    
    @State private var filterTransitOnly: Bool = true
    @State private var selectedNode: RouteNode?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showNavigationDialog: Bool = false
    
    private var displayedNodes: [RouteNode] {
        if filterTransitOnly {
            return visitedNodes.filter { !$0.nodeType.isTransitOnly }
        } else {
            return visitedNodes
        }
    }
    
    private var uniqueCitiesCount: Int {
        Set(visitedNodes.compactMap { $0.day?.trip?.destination }).count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // MapKit 足迹底板
                Map(position: $cameraPosition) {
                    ForEach(displayedNodes) { node in
                        Annotation(node.title, coordinate: node.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.sunsetGradient)
                                    .frame(width: selectedNode?.id == node.id ? 40 : 30, height: selectedNode?.id == node.id ? 40 : 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedNode?.id == node.id ? 2.5 : 2)
                                    )
                                    .shadow(color: AppTheme.sunsetCoral.opacity(0.4), radius: selectedNode?.id == node.id ? 8 : 4, x: 0, y: 2)
                                
                                Image(systemName: node.nodeType.systemIcon)
                                    .font(.system(size: selectedNode?.id == node.id ? 17 : 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .scaleEffect(selectedNode?.id == node.id ? 1.15 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedNode?.id)
                            .onTapGesture {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedNode = node
                                    cameraPosition = .region(
                                        MKCoordinateRegion(
                                            center: node.coordinate,
                                            latitudinalMeters: 1800,
                                            longitudinalMeters: 1800
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
                
                // 顶部悬浮空间组件：漫游探索成就岛
                VStack {
                    HStack {
                        // 统计指标
                        HStack(spacing: 14) {
                            HStack(spacing: 6) {
                                Image(systemName: "globe.asia.australia.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.indigoPrimary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(uniqueCitiesCount)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Text("探索城市")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Divider()
                                .frame(height: 20)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundStyle(AppTheme.sunsetCoral)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(displayedNodes.count)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Text("足迹打卡")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassCard(cornerRadius: 20)
                        
                        Spacer()
                        
                        // 中转过滤切换微胶囊
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                filterTransitOnly.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: filterTransitOnly ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 11))
                                Text(filterTransitOnly ? "已隐中转" : "全部站点")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(filterTransitOnly ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color.secondary.opacity(0.15)))
                            .foregroundStyle(filterTransitOnly ? Color.white : Color.primary)
                            .clipShape(Capsule())
                            .shadow(color: filterTransitOnly ? AppTheme.indigoPrimary.opacity(0.3) : .clear, radius: 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                
                // 底部选中的回忆轻量卡片
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
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
}
