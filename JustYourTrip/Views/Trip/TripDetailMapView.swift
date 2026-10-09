import SwiftUI
import MapKit
import SwiftData

/// 行程详情与攻略协同主页 (地图底板 + 上拉抽屉联动 + 顶部悬浮控制岛)
struct TripDetailMapView: View {
    @Bindable var trip: TripPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDayIndex: Int = 1
    @State private var selectedNodeId: UUID?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var sheetDetent: PresentationDetent = .height(220)
    @State private var showAddNodeSheet = false
    
    private var currentDay: TripDay? {
        trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }
    
    private var sortedNodes: [RouteNode] {
        currentDay?.sortedNodes ?? []
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. MapKit 地图底板
            Map(position: $mapCameraPosition) {
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
                
                // 渲染所有节点图钉 (携带顺序序号与选中状态)
                ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                    Annotation(node.title, coordinate: node.coordinate) {
                        NodeMarkerView(node: node, index: index + 1, isSelected: selectedNodeId == node.id)
                            .onTapGesture {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selectedNodeId = node.id
                                    sheetDetent = .medium
                                    focusCamera(on: node.coordinate)
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
            .onAppear {
                focusAllDayNodes()
            }
            .onChange(of: selectedDayIndex) { _, _ in
                focusAllDayNodes()
            }
            
            // 2. 顶部悬浮控制岛 (全景视角聚焦与天数微标)
            topFloatingBar
                .padding(.horizontal, 16)
                .padding(.top, 10)
        }
        .navigationBarTitleDisplayMode(.inline)
        // 上拉抽屉联动
        .sheet(isPresented: .constant(true)) {
            TripDayTimelineSheet(
                trip: trip,
                selectedDayIndex: $selectedDayIndex,
                selectedNodeId: $selectedNodeId,
                onNodeSelected: { node in
                    focusCamera(on: node.coordinate)
                },
                onAddNode: {
                    showAddNodeSheet = true
                }
            )
            .presentationDetents([.height(220), .medium, .large], selection: $sheetDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showAddNodeSheet) {
            if let day = currentDay {
                AddNodeSheet(day: day)
            }
        }
    }
    
    // MARK: - 顶部悬浮控制岛
    
    private var topFloatingBar: some View {
        HStack {
            // 当前天数与路线标题胶囊
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.sageMint)
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
            
            // 全景居中按钮 (一键将今日所有点自适应装入视野)
            Button {
                HapticFeedback.light()
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
