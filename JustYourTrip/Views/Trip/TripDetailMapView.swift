import SwiftUI
import MapKit
import SwiftData

/// 行程详情与攻略协同主页 (地图底板 + 内嵌抽屉联动 + 顶部悬浮控制岛)
/// 抽屉直接内嵌于本视图的 ZStack 层次中，在页面 Navigation Zoom 或 Push/Pop 转场退出时与地图浑然一体同步退出
struct TripDetailMapView: View {
    @Bindable var trip: TripPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDayIndex: Int = 1
    @State private var selectedNodeId: UUID?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var drawerDetent: DrawerDetent = .collapsed
    @State private var showAddNodeSheet = false

    private var isOverviewMode: Bool {
        selectedDayIndex == 0
    }

    private var sortedDays: [TripDay] {
        trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })
    }

    private var currentDay: TripDay? {
        if isOverviewMode {
            return sortedDays.first
        }
        return trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }

    private var sortedNodes: [RouteNode] {
        if isOverviewMode {
            return sortedDays.flatMap(\.sortedNodes)
        }
        return currentDay?.sortedNodes ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let bottomSafeArea = geometry.safeAreaInsets.bottom
            let topSafeArea = geometry.safeAreaInsets.top

            ZStack(alignment: .bottom) {
                // 1. MapKit 地图底板 (全景铺满)
                Map(position: $mapCameraPosition) {
                    if isOverviewMode {
                        // 【全景总览模式】
                        // 1. 各天内部路段折线 (按各天专属主题色渲染)
                        ForEach(sortedDays) { day in
                            let dayNodes = day.sortedNodes
                            let dayColor = AppTheme.dayColor(for: day.dayIndex)
                            ForEach(0..<max(0, dayNodes.count - 1), id: \.self) { index in
                                let fromNode = dayNodes[index]
                                let toNode = dayNodes[index + 1]
                                let coords = [fromNode.coordinate, toNode.coordinate]

                                switch toNode.incomingTransit {
                                case .walking:
                                    MapPolyline(coordinates: coords)
                                        .stroke(dayColor.opacity(0.85), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4]))
                                case .driving:
                                    MapPolyline(coordinates: coords)
                                        .stroke(dayColor, lineWidth: 4)
                                case .transit:
                                    MapPolyline(coordinates: coords)
                                        .stroke(dayColor, lineWidth: 5)
                                }
                            }
                        }

                        // 2. 跨日过渡衔接虚线 (Day K 终点 ➔ Day K+1 起点，渐变虚线无缝衔接)
                        ForEach(0..<max(0, sortedDays.count - 1), id: \.self) { dayIdx in
                            let fromDay = sortedDays[dayIdx]
                            let toDay = sortedDays[dayIdx + 1]
                            if let lastNode = fromDay.sortedNodes.last,
                               let firstNode = toDay.sortedNodes.first {
                                MapPolyline(coordinates: [lastNode.coordinate, firstNode.coordinate])
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.dayColor(for: fromDay.dayIndex),
                                                AppTheme.dayColor(for: toDay.dayIndex)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3.2, lineCap: .round, dash: [8, 6])
                                    )
                            }
                        }

                        // 3. 所有天的图钉 (携带 D1-1, D2-1 角标与对应日色彩)
                        ForEach(sortedDays) { day in
                            let dayColor = AppTheme.dayColor(for: day.dayIndex)
                            ForEach(Array(day.sortedNodes.enumerated()), id: \.element.id) { index, node in
                                Annotation(node.title, coordinate: node.coordinate) {
                                    NodeMarkerView(
                                        node: node,
                                        index: index + 1,
                                        indexText: "D\(day.dayIndex)-\(index + 1)",
                                        dayColor: dayColor,
                                        isSelected: selectedNodeId == node.id
                                    )
                                    .onTapGesture {
                                        HapticFeedback.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            selectedNodeId = node.id
                                            drawerDetent = .medium
                                            focusCamera(on: node.coordinate)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // 【单日专注模式】
                        // 绘制相连路段多模态 Polyline
                        ForEach(0..<max(0, sortedNodes.count - 1), id: \.self) { index in
                            let fromNode = sortedNodes[index]
                            let toNode = sortedNodes[index + 1]
                            let coords = [fromNode.coordinate, toNode.coordinate]

                            switch toNode.incomingTransit {
                            case .walking:
                                MapPolyline(coordinates: coords)
                                    .stroke(AppTheme.skyTeal, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4]))
                            case .driving:
                                MapPolyline(coordinates: coords)
                                    .stroke(AppTheme.sunsetCoral, lineWidth: 4)
                            case .transit:
                                MapPolyline(coordinates: coords)
                                    .stroke(AppTheme.indigoPrimary, lineWidth: 5)
                            }
                        }

                        // 渲染单日节点图钉 (携带顺序序号与选中状态)
                        ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                            Annotation(node.title, coordinate: node.coordinate) {
                                NodeMarkerView(node: node, index: index + 1, isSelected: selectedNodeId == node.id)
                                    .onTapGesture {
                                        HapticFeedback.selection()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            selectedNodeId = node.id
                                            drawerDetent = .medium
                                            focusCamera(on: node.coordinate)
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
                    focusAllDayNodes()
                }
                .onChange(of: selectedDayIndex) { _, _ in
                    focusAllDayNodes()
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

            // 全景居中按钮 (一键将今日所有点自适应装入视野，并智能折叠抽屉以最大化地图视野)
            Button {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    drawerDetent = .collapsed
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
