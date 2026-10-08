import SwiftUI
import MapKit
import SwiftData

/// 可编辑的草稿节点对象 (用于入库前人机协同校准)
@Observable
final class DraftNode: Identifiable {
    let id = UUID()
    var title: String
    var latitude: Double
    var longitude: Double
    var nodeType: NodeType
    var incomingTransit: TransitType
    var incomingGuide: String
    var tips: String
    var durationMinutes: Int
    
    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    init(
        title: String,
        latitude: Double = 31.2304,
        longitude: Double = 121.4737,
        nodeType: NodeType = .attraction,
        incomingTransit: TransitType = .walking,
        incomingGuide: String = "",
        tips: String = "",
        durationMinutes: Int = 60
    ) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.nodeType = nodeType
        self.incomingTransit = incomingTransit
        self.incomingGuide = incomingGuide
        self.tips = tips
        self.durationMinutes = durationMinutes
    }
}

/// 可编辑的每日草稿
@Observable
final class DraftDay: Identifiable {
    let id = UUID()
    var dayIndex: Int
    var summary: String
    var nodes: [DraftNode]
    
    init(dayIndex: Int, summary: String = "", nodes: [DraftNode] = []) {
        self.dayIndex = dayIndex
        self.summary = summary
        self.nodes = nodes
    }
}

/// AI 解析后的人机校准预览与入库页
struct DraftCalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var tripTitle: String
    var destination: String
    var days: [DraftDay]
    var suggestedChecklist: [String]
    var onSaved: () -> Void
    
    @State private var editableTitle: String = ""
    @State private var selectedDayIndex: Int = 1
    @State private var selectedNodeId: UUID?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var editingNode: DraftNode?

    init(
        tripTitle: String,
        destination: String,
        days: [DraftDay],
        suggestedChecklist: [String] = [],
        onSaved: @escaping () -> Void
    ) {
        self.tripTitle = tripTitle
        self.destination = destination
        self.days = days
        self.suggestedChecklist = suggestedChecklist
        self.onSaved = onSaved
        _editableTitle = State(initialValue: tripTitle)
    }

    private var currentDay: DraftDay? {
        days.first(where: { $0.dayIndex == selectedDayIndex })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 上半部分：地图预览与图钉校准
                Map(position: $mapCameraPosition) {
                    if let nodes = currentDay?.nodes {
                        ForEach(nodes) { node in
                            Annotation(node.title, coordinate: node.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(selectedNodeId == node.id ? AppTheme.indigoPrimary : AppTheme.sunsetCoral)
                                        .frame(width: selectedNodeId == node.id ? 36 : 28, height: selectedNodeId == node.id ? 36 : 28)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(color: AppTheme.sunsetCoral.opacity(0.35), radius: 5)
                                    Image(systemName: node.nodeType.systemIcon)
                                        .font(.system(size: selectedNodeId == node.id ? 14 : 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .scaleEffect(selectedNodeId == node.id ? 1.15 : 1.0)
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    selectedNodeId = node.id
                                    editingNode = node
                                }
                            }
                        }
                    }
                }
                .frame(height: 220)
                
                // 下半部分：天数选择与节点校准列表
                VStack(spacing: 0) {
                    // 天数切换
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(days) { day in
                                let isSelected = selectedDayIndex == day.dayIndex
                                Button {
                                    HapticFeedback.selection()
                                    selectedDayIndex = day.dayIndex
                                    fitMapToCurrentDay()
                                } label: {
                                    Text("Day \(day.dayIndex)")
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .shadow(color: isSelected ? AppTheme.indigoPrimary.opacity(0.3) : .clear, radius: 4)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    Divider()
                    
                    // 节点卡片列表
                    List {
                        if let day = currentDay {
                            Section("第 \(day.dayIndex) 天路线规划 (可上下拖拽调序或点击编辑)") {
                                ForEach(day.nodes) { node in
                                    DraftNodeRow(node: node)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedNodeId = node.id
                                            editingNode = node
                                            centerMap(on: node.coordinate)
                                        }
                                }
                                .onDelete { offsets in
                                    day.nodes.remove(atOffsets: offsets)
                                }
                                .onMove { indices, newOffset in
                                    day.nodes.move(fromOffsets: indices, toOffset: newOffset)
                                }
                            }
                        }
                        
                        if !suggestedChecklist.isEmpty {
                            Section("AI 推荐特需必备行李") {
                                ForEach(suggestedChecklist, id: \.self) { item in
                                    Label(item, systemImage: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("路线草稿校准")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("放弃") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认入库") {
                        commitToSwiftData()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                fitMapToCurrentDay()
            }
            .sheet(item: $editingNode) { node in
                EditDraftNodeSheet(node: node)
            }
        }
    }
    
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation {
            mapCameraPosition = .region(
                MKCoordinateRegion(center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)
            )
        }
    }
    
    private func fitMapToCurrentDay() {
        guard let firstNode = currentDay?.nodes.first else { return }
        centerMap(on: firstNode.coordinate)
    }
    
    /// 将校准后的草稿正式持久化入库到 SwiftData
    private func commitToSwiftData() {
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: max(1, days.count - 1), to: today) ?? today
        
        let plan = TripPlan(
            title: editableTitle.isEmpty ? tripTitle : editableTitle,
            destination: destination,
            startDate: today,
            endDate: endDate
        )
        modelContext.insert(plan)
        
        for draftDay in days {
            let targetDate = calendar.date(byAdding: .day, value: draftDay.dayIndex - 1, to: today) ?? today
            let day = TripDay(dayIndex: draftDay.dayIndex, date: targetDate, summary: draftDay.summary)
            day.trip = plan
            modelContext.insert(day)
            
            for (index, draftNode) in draftDay.nodes.enumerated() {
                let node = RouteNode(
                    title: draftNode.title,
                    latitude: draftNode.latitude,
                    longitude: draftNode.longitude,
                    sortOrder: index,
                    nodeType: draftNode.nodeType,
                    incomingTransit: draftNode.incomingTransit,
                    incomingTransitGuide: draftNode.incomingGuide,
                    tips: draftNode.tips,
                    durationMinutes: draftNode.durationMinutes
                )
                node.day = day
                modelContext.insert(node)
            }
        }
        
        // 自动入库 AI 推荐的行李项
        for item in suggestedChecklist {
            let checklistItem = ChecklistItem(name: item, category: .documents, isEssential: true)
            checklistItem.trip = plan
            modelContext.insert(checklistItem)
        }
        
        onSaved()
        dismiss()
    }
}

/// 草稿单行视图
struct DraftNodeRow: View {
    let node: DraftNode
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.nodeType.systemIcon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(node.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(node.nodeType.title)
                        .font(.system(size: 10))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                
                if !node.incomingGuide.isEmpty {
                    Text("换乘: \(node.incomingGuide)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// 编辑草稿节点弹窗
struct EditDraftNodeSheet: View {
    @Bindable var node: DraftNode
    @Environment(\.dismiss) private var dismiss
    
    @State private var latString: String = ""
    @State private var lonString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("地点与分类") {
                    TextField("地点名称", text: $node.title)
                    Picker("地点类型", selection: $node.nodeType) {
                        ForEach(NodeType.allCases) { type in
                            Label(type.title, systemImage: type.systemIcon).tag(type)
                        }
                    }
                }
                
                Section("经纬度坐标微调") {
                    HStack {
                        Text("纬度")
                        TextField("纬度", text: $latString)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("经度")
                        TextField("经度", text: $lonString)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("交通换乘指示") {
                    Picker("交通工具", selection: $node.incomingTransit) {
                        ForEach(TransitType.allCases) { transit in
                            Label(transit.title, systemImage: transit.systemIcon).tag(transit)
                        }
                    }
                    TextField("换乘指引", text: $node.incomingGuide, axis: .vertical)
                }
                
                Section("游玩提示") {
                    TextField("避坑提示/建议时长", text: $node.tips, axis: .vertical)
                }
            }
            .navigationTitle("微调节点信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        if let lat = Double(latString), let lon = Double(lonString) {
                            node.latitude = lat
                            node.longitude = lon
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                latString = String(format: "%.6f", node.latitude)
                lonString = String(format: "%.6f", node.longitude)
            }
        }
    }
}
