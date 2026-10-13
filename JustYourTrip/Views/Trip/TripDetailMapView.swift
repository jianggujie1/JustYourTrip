import SwiftUI
import MapKit
import SwiftData

/// 行程详情与攻略协同主页 (地图底板 + 内嵌抽屉联动 + 顶部悬浮控制岛)
/// 抽屉直接内嵌于本视图的 ZStack 层次中，在页面 Navigation Zoom 或 Push/Pop 转场退出时与地图浑然一体同步退出
struct TripDetailMapView: View {
    @Bindable var trip: TripPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDayIndex: Int = 1
    @State private var selectedNodeId: UUID?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var drawerDetent: DrawerDetent = .collapsed
    @State private var showAddNodeSheet = false

    // 地图连线视效偏好 (支持 UserDefaults 持久化)
    @AppStorage("map_use_curved_routes") private var useCurvedRoutes: Bool = true
    @AppStorage("map_show_direction_chevrons") private var showDirectionChevrons: Bool = true
    @AppStorage("map_highlight_selected_legs") private var highlightSelectedLegs: Bool = true
    @AppStorage("map_overview_show_all_titles") private var showAllTitlesInOverview: Bool = false

    // 🚀 高性能缓存池：彻底消除动画每帧重复排序、三角函数运算与大对象分配，保障 120Hz 丝滑流畅
    @State private var cachedDays: [TripDay] = []
    @State private var cachedNodes: [RouteNode] = []
    @State private var cachedRouteSegments: [RouteMapSegment] = []
    @State private var cachedDirectionSegments: [RouteMapSegment] = []

    private var isOverviewMode: Bool {
        selectedDayIndex == 0
    }

    private var isNodeSelected: Bool {
        selectedNodeId != nil
    }

    private var sortedDays: [TripDay] {
        if !cachedDays.isEmpty { return cachedDays }
        return trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })
    }

    private var currentDay: TripDay? {
        if isOverviewMode {
            return sortedDays.first
        }
        return trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }

    private var sortedNodes: [RouteNode] {
        if !cachedNodes.isEmpty { return cachedNodes }
        if isOverviewMode {
            return sortedDays.flatMap(\.sortedNodes)
        }
        return currentDay?.sortedNodes ?? []
    }

    private func connectsToSelected(_ segment: RouteMapSegment) -> Bool {
        guard let selectedId = selectedNodeId else { return false }
        return segment.fromNode.id == selectedId || segment.toNode.id == selectedId
    }

    /// 高效异步/事件驱动刷新几何缓存
    private func updateRouteCache() {
        let days = trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })
        self.cachedDays = days

        let nodes: [RouteNode]
        if isOverviewMode {
            nodes = days.flatMap(\.sortedNodes)
        } else {
            let cur = days.first(where: { $0.dayIndex == selectedDayIndex })
            nodes = cur?.sortedNodes ?? []
        }
        self.cachedNodes = nodes

        var rawSegments: [RawRouteSegment] = []

        if isOverviewMode {
            for day in days {
                let dayNodes = day.sortedNodes
                let dayColor = AppTheme.dayColor(for: day.dayIndex)
                for index in 0..<max(0, dayNodes.count - 1) {
                    let from = dayNodes[index]
                    let to = dayNodes[index + 1]
                    let strokeStyle: StrokeStyle
                    switch to.incomingTransit {
                    case .walking:
                        strokeStyle = StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4])
                    case .driving:
                        strokeStyle = StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round)
                    case .transit:
                        strokeStyle = StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
                    }
                    rawSegments.append(
                        RawRouteSegment(
                            id: "overview-d\(day.dayIndex)-\(index)-\(from.id)-\(to.id)",
                            fromNode: from,
                            toNode: to,
                            dayIndex: day.dayIndex,
                            transitType: to.incomingTransit,
                            color: dayColor,
                            isCrossDay: false,
                            strokeStyle: strokeStyle
                        )
                    )
                }
            }

            for dayIdx in 0..<max(0, days.count - 1) {
                let fromDay = days[dayIdx]
                let toDay = days[dayIdx + 1]
                if let lastNode = fromDay.sortedNodes.last,
                   let firstNode = toDay.sortedNodes.first {
                    let loc1 = CLLocation(latitude: lastNode.latitude, longitude: lastNode.longitude)
                    let loc2 = CLLocation(latitude: firstNode.latitude, longitude: firstNode.longitude)
                    if loc1.distance(from: loc2) >= 15 {
                        let strokeStyle = StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [8, 6])
                        let transitionColor = AppTheme.dayColor(for: fromDay.dayIndex)
                        rawSegments.append(
                            RawRouteSegment(
                                id: "crossday-\(fromDay.dayIndex)-to-\(toDay.dayIndex)",
                                fromNode: lastNode,
                                toNode: firstNode,
                                dayIndex: fromDay.dayIndex,
                                transitType: .transit,
                                color: transitionColor,
                                isCrossDay: true,
                                strokeStyle: strokeStyle
                            )
                        )
                    }
                }
            }
        } else {
            for index in 0..<max(0, nodes.count - 1) {
                let from = nodes[index]
                let to = nodes[index + 1]
                let strokeColor: Color
                let strokeStyle: StrokeStyle

                switch to.incomingTransit {
                case .walking:
                    strokeColor = AppTheme.skyTeal
                    strokeStyle = StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4])
                case .driving:
                    strokeColor = AppTheme.sunsetCoral
                    strokeStyle = StrokeStyle(lineWidth: 4.0, lineCap: .round, lineJoin: .round)
                case .transit:
                    strokeColor = AppTheme.indigoPrimary
                    strokeStyle = StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
                }

                rawSegments.append(
                    RawRouteSegment(
                        id: "day\(selectedDayIndex)-\(index)-\(from.id)-\(to.id)",
                        fromNode: from,
                        toNode: to,
                        dayIndex: selectedDayIndex,
                        transitType: to.incomingTransit,
                        color: strokeColor,
                        isCrossDay: false,
                        strokeStyle: strokeStyle
                    )
                )
            }
        }

        let segments = RouteArcCalculator.buildNonOverlappingSegments(
            rawSegments: rawSegments,
            useCurvedRoutes: useCurvedRoutes
        )
        self.cachedRouteSegments = segments
        
        let minDistance: Double = isOverviewMode ? 80 : 50
        self.cachedDirectionSegments = segments.filter { $0.distanceMeters > minDistance }
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            let topSafeArea = geometry.safeAreaInsets.top

            ZStack(alignment: .bottom) {
                // 1. MapKit 地图底板 (全景铺满)
                Map(position: $mapCameraPosition) {
                    // ① 路线底轨与主色轨迹 (双层高对比防护，直接读取高性能预构建缓存)
                    ForEach(cachedRouteSegments) { segment in
                        let connects = connectsToSelected(segment)
                        let isHighlighted = connects
                        let isDimmed = isNodeSelected && !connects && highlightSelectedLegs

                        // 底层高对比度保护描边 (消除重叠与交叉混色)
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(
                                colorScheme == .dark ? Color.black.opacity(0.85) : Color.white.opacity(0.92),
                                style: StrokeStyle(
                                    lineWidth: isHighlighted ? (segment.strokeStyle.lineWidth + 4.5) : (segment.strokeStyle.lineWidth + 2.8),
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )

                        // 顶层主色彩轨迹
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(
                                segment.color.opacity(isDimmed ? 0.22 : 1.0),
                                style: isHighlighted ?
                                    StrokeStyle(
                                        lineWidth: segment.strokeStyle.lineWidth + 1.8,
                                        lineCap: segment.strokeStyle.lineCap,
                                        lineJoin: segment.strokeStyle.lineJoin,
                                        dash: segment.strokeStyle.dash
                                    ) : segment.strokeStyle
                            )
                    }

                    // ② 路线中点流向指示徽标 (预过滤缓存按需渲染)
                    if showDirectionChevrons {
                        ForEach(cachedDirectionSegments) { segment in
                            let connects = connectsToSelected(segment)
                            let isHighlighted = connects
                            let isDimmed = isNodeSelected && !connects && highlightSelectedLegs

                            Annotation("", coordinate: segment.midCoordinate) {
                                RouteDirectionBadge(
                                    segment: segment,
                                    isHighlighted: isHighlighted,
                                    isDimmed: isDimmed,
                                    isOverviewMode: isOverviewMode
                                )
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        selectedNodeId = segment.toNode.id
                                        drawerDetent = .medium
                                        focusCamera(on: segment.toNode.coordinate)
                                    }
                                }
                            }
                        }
                    }

                    // ③ 节点图钉层 (带智能 LOD：全景密集点位收敛为紧凑精致图钉，点选智能弹出名称卡片，彻底避免大面积毛玻璃离屏渲染卡顿)
                    if isOverviewMode {
                        ForEach(sortedDays) { day in
                            let dayColor = AppTheme.dayColor(for: day.dayIndex)
                            ForEach(Array(day.sortedNodes.enumerated()), id: \.element.id) { index, node in
                                let isSelected = selectedNodeId == node.id
                                let showTitle = isSelected || showAllTitlesInOverview || (sortedNodes.count <= 10)
                                Annotation(node.title, coordinate: node.coordinate) {
                                    NodeMarkerView(
                                        node: node,
                                        index: index + 1,
                                        indexText: "D\(day.dayIndex)-\(index + 1)",
                                        dayColor: dayColor,
                                        isSelected: isSelected,
                                        showTitle: showTitle
                                    )
                                    .onTapGesture {
                                        HapticFeedback.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            if selectedNodeId == node.id {
                                                selectedNodeId = nil
                                            } else {
                                                selectedNodeId = node.id
                                                drawerDetent = .medium
                                                focusCamera(on: node.coordinate)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                            let isSelected = selectedNodeId == node.id
                            Annotation(node.title, coordinate: node.coordinate) {
                                NodeMarkerView(
                                    node: node,
                                    index: index + 1,
                                    isSelected: isSelected,
                                    showTitle: true
                                )
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                        if selectedNodeId == node.id {
                                            selectedNodeId = nil
                                        } else {
                                            selectedNodeId = node.id
                                            drawerDetent = .medium
                                            focusCamera(on: node.coordinate)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }
                .ignoresSafeArea()
                .onAppear {
                    updateRouteCache()
                    focusAllDayNodes()
                }
                .onChange(of: selectedDayIndex) { _, _ in
                    selectedNodeId = nil
                    updateRouteCache()
                    focusAllDayNodes()
                }
                .onChange(of: useCurvedRoutes) { _, _ in
                    updateRouteCache()
                }
                .onChange(of: trip.days) { _, _ in
                    updateRouteCache()
                }

                // 2. 顶部悬浮控制岛 (返回导航、全景视角聚焦与天数微标)
                VStack {
                    topFloatingBar
                        .padding(.horizontal, 16)
                        .padding(.top, max(topSafeArea, 12) + 4)
                    Spacer()
                }
                .ignoresSafeArea(.all, edges: .top)

                // 3. 底部联动抽屉 (原生作为视图内子组件，与地图一体化进出转场)
                TripDayTimelineDrawer(
                    trip: trip,
                    selectedDayIndex: $selectedDayIndex,
                    selectedNodeId: $selectedNodeId,
                    drawerDetent: $drawerDetent,
                    screenHeight: screenHeight,
                    bottomSafeArea: bottomSafeArea,
                    onNodeSelected: { node in
                        focusCamera(on: node.coordinate)
                    },
                    onAddNode: {
                        showAddNodeSheet = true
                    }
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddNodeSheet) {
            if let day = currentDay {
                AddNodeSheet(day: day)
            }
        }
    }

    // MARK: - 顶部悬浮控制岛

    private var topFloatingBar: some View {
        HStack(spacing: 8) {
            // 返回按钮 (触发平滑缩放回缩与触感微震，地图与抽屉一体退出)
            Button {
                HapticFeedback.light()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // 当前天数与路线标题胶囊
            HStack(spacing: 6) {
                if isOverviewMode {
                    Image(systemName: "map.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.sageMint)

                    Text("全景总览")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("• 共 \(trip.days.count) 天 \(trip.totalNodesCount) 站")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Circle()
                        .fill(AppTheme.dayColor(for: selectedDayIndex))
                        .frame(width: 8, height: 8)

                    Text("Day \(selectedDayIndex)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if !sortedNodes.isEmpty {
                        Text("• \(sortedNodes.count) 站")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)

            Spacer()

            // 聚焦所选地点快捷取消胶囊 (当有地点聚焦时呈现)
            if let selectedId = selectedNodeId,
               let selectedNode = sortedNodes.first(where: { $0.id == selectedId }) {
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        selectedNodeId = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "scope")
                            .font(.system(size: 10, weight: .bold))
                        Text(selectedNode.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.forestPrimary.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }

            // 路线视效控制菜单 (防重叠双轨 / 流向箭头 / 选中聚焦 开关)
            Menu {
                Toggle(isOn: $useCurvedRoutes) {
                    Label("智能防重叠双轨", systemImage: "arrow.triangle.swap")
                }

                Toggle(isOn: $showDirectionChevrons) {
                    Label("显示路线流向指示", systemImage: "arrowshape.forward.fill")
                }

                Toggle(isOn: $highlightSelectedLegs) {
                    Label("聚焦高亮选中路线", systemImage: "scope")
                }

                Toggle(isOn: $showAllTitlesInOverview) {
                    Label("总览常驻全部地点名称", systemImage: "text.bubble")
                }

                if selectedNodeId != nil {
                    Divider()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            selectedNodeId = nil
                        }
                    } label: {
                        Label("重置高亮聚焦", systemImage: "arrow.counterclockwise")
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.2.square")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }

            // 全景居中按钮 (一键将今日所有点自适应装入视野，并智能折叠抽屉以最大化地图视野)
            Button {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    drawerDetent = .collapsed
                    selectedNodeId = nil
                }
                focusAllDayNodes()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                    Text("全览")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundStyle(.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 镜头移动

    private func focusCamera(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
            )
        }
    }

    private func focusAllDayNodes() {
        guard !sortedNodes.isEmpty else { return }

        if sortedNodes.count == 1, let single = sortedNodes.first {
            selectedNodeId = single.id
            focusCamera(on: single.coordinate)
            return
        }

        let lats = sortedNodes.map { $0.latitude }
        let lons = sortedNodes.map { $0.longitude }
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.015),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.015)
        )

        withAnimation(.easeInOut(duration: 0.6)) {
            mapCameraPosition = .region(
                MKCoordinateRegion(center: center, span: span)
            )
        }
    }
}
