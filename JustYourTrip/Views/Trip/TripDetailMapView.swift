import SwiftUI
import MapKit
import SwiftData

/// 行程详情与攻略协同主页 (地图底板 + 上拉抽屉联动)
struct TripDetailMapView: View {
    @Bindable var trip: TripPlan
    @Environment(\.modelContext) private var modelContext
    
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
        ZStack {
            // MapKit 地图底板
            Map(position: $mapCameraPosition) {
                // 绘制相连路段多模态 Polyline
                ForEach(0..<max(0, sortedNodes.count - 1), id: \.self) { index in
                    let fromNode = sortedNodes[index]
                    let toNode = sortedNodes[index + 1]
                    let coords = [fromNode.coordinate, toNode.coordinate]
                    
                    switch toNode.incomingTransit {
                    case .walking:
                        MapPolyline(coordinates: coords)
                            .stroke(AppTheme.indigoPrimary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, dash: [6, 4]))
                    case .driving:
                        MapPolyline(coordinates: coords)
                            .stroke(AppTheme.sunsetCoral, lineWidth: 4)
                    case .transit:
                        MapPolyline(coordinates: coords)
                            .stroke(AppTheme.royalPurple, lineWidth: 5)
                    }
                }
                
                // 渲染所有节点图钉
                ForEach(sortedNodes) { node in
                    Annotation(node.title, coordinate: node.coordinate) {
                        NodeMarkerView(node: node, isSelected: selectedNodeId == node.id)
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
                if let firstNode = sortedNodes.first {
                    selectedNodeId = firstNode.id
                    focusCamera(on: firstNode.coordinate)
                }
            }
            .onChange(of: selectedDayIndex) { _, _ in
                if let firstNode = sortedNodes.first {
                    selectedNodeId = firstNode.id
                    focusCamera(on: firstNode.coordinate)
                }
            }
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
    
    private func focusCamera(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 1200,
                    longitudinalMeters: 1200
                )
            )
        }
    }
}
