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

/// AI 解析后的人机校准预览与入库页 (全景路线小地图 + 序号连线 + 手账卡片调序)
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
                // MARK: - 顶部可编辑行程概要条
                tripSummaryBanner
                
                // MARK: - 上半部分：全景动态小地图 (路线连线 + 序号 Pin + 悬浮控制器)
                mapPreviewSection
                
                // MARK: - 天数快速切换胶囊条
                daySelectorBar
                
                // MARK: - 下半部分：节点卡片调序列表与行前准备
                draftNodesListSection
            }
            .background(AppTheme.canvasBackground.ignoresSafeArea())
            .navigationTitle("路线草稿校准")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("放弃") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        commitToSwiftData()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("确认入库")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.forestPrimary)
                    }
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
    
    // MARK: - 顶部行程概要条 (手账名牌纸)
    
    private var tripSummaryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.sageMint)
            
            TextField("输入行程自定义名称...", text: $editableTitle)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.primary)
            
            if !destination.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                    Text(destination)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(AppTheme.forestPrimary.opacity(0.1))
                .foregroundStyle(AppTheme.forestPrimary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - 上半部分小地图区域
    
    private var mapPreviewSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $mapCameraPosition) {
                if let nodes = currentDay?.nodes {
                    // 节点间路线连线 (实线轨迹)
                    if nodes.count >= 2 {
                        MapPolyline(coordinates: nodes.map(\.coordinate))
                            .stroke(
                                AppTheme.sageMint,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                            )
                    }
                    
                    // 带序号数字与类型的自定义标记 Pin
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        Annotation(node.title, coordinate: node.coordinate) {
                            draftMapMarker(node: node, index: index + 1)
                        }
                    }
                }
            }
            .frame(height: 220)
            
            // 右下角全览居中悬浮按钮
            Button {
                HapticFeedback.light()
                fitMapToCurrentDay()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                    Text("全览当日")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
    
    // MARK: - 地图标记视图
    
    private func draftMapMarker(node: DraftNode, index: Int) -> some View {
        let isSelected = selectedNodeId == node.id
        return ZStack {
            if isSelected {
                Circle()
                    .stroke(AppTheme.sageMint.opacity(0.5), lineWidth: 4)
                    .frame(width: 38, height: 38)
            }
            
            Circle()
                .fill(isSelected ? AppTheme.forestPrimary : badgeColor(for: node.nodeType))
                .frame(width: isSelected ? 30 : 26, height: isSelected ? 30 : 26)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            Text("\(index)")
                .font(.system(size: isSelected ? 12 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            HapticFeedback.selection()
            selectedNodeId = node.id
            editingNode = node
        }
    }
    
    // MARK: - 天数快速切换胶囊条
    
    private var daySelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    let isSelected = selectedDayIndex == day.dayIndex
                    Button {
                        HapticFeedback.selection()
                        selectedDayIndex = day.dayIndex
                        selectedNodeId = nil
                        fitMapToCurrentDay()
                    } label: {
                        HStack(spacing: 5) {
                            Text("Day \(day.dayIndex)")
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            
                            Text("(\(day.nodes.count)站)")
                                .font(.system(size: 11))
                                .opacity(isSelected ? 0.9 : 0.6)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(AppTheme.cardBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .shadow(color: isSelected ? AppTheme.forestPrimary.opacity(0.25) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppTheme.canvasBackground)
    }
    
    // MARK: - 节点卡片列表与行前准备
    
    private var draftNodesListSection: some View {
        List {
            if let day = currentDay {
                Section {
                    ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                        DraftNodeCardRow(
                            node: node,
                            index: index + 1,
                            isSelected: selectedNodeId == node.id,
                            onEdit: {
                                editingNode = node
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNodeId = node.id
                            centerMap(on: node.coordinate)
                        }
                    }
                    .onDelete { offsets in
                        day.nodes.remove(atOffsets: offsets)
                        fitMapToCurrentDay()
                    }
                    .onMove { indices, newOffset in
                        day.nodes.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    HStack {
                        Text("第 \(day.dayIndex) 天路线规划")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("点击卡片编辑 · 长按拖拽调序")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            }
            
            // 行前准备推荐 (若有)
            if !suggestedChecklist.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppTheme.warmAmber)
                            Text("AI 行程特别推荐必备行李")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("入库后自动进入行前清单")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider().opacity(0.5)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(suggestedChecklist, id: \.self) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.sageMint)
                                    Text(item)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.primary.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.warmAmber.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.warmAmber.opacity(0.2), lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("行前打包建议")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 2)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - 地图移动与视角自适应
    
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.35)) {
            mapCameraPosition = .region(
                MKCoordinateRegion(center: coordinate, latitudinalMeters: 1600, longitudinalMeters: 1600)
            )
        }
    }
    
    private func fitMapToCurrentDay() {
        guard let nodes = currentDay?.nodes, !nodes.isEmpty else { return }
        let coords = nodes.map(\.coordinate)
        if coords.count == 1 {
            centerMap(on: coords[0])
            return
        }
        
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude
        
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.02, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.02, (maxLon - minLon) * 1.5)
        )
        
        withAnimation(.easeInOut(duration: 0.4)) {
            mapCameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    // MARK: - 持久化入库 SwiftData
    
    private func commitToSwiftData() {
        HapticFeedback.success()
        let calendar = Calendar.current
        let today = Date()
        let endDate = calendar.date(byAdding: .day, value: max(1, days.count - 1), to: today) ?? today
        
        let plan = TripPlan(
            title: editableTitle.isEmpty ? tripTitle : editableTitle,
            destination: destination,
            startDate: today,
            endDate: endDate,
            vibeTags: ["✨ AI定制路线", "🗺️ 漫游规划"]
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
    
    private func badgeColor(for type: NodeType) -> Color {
        switch type {
        case .attraction: return AppTheme.sunsetCoral
        case .restaurant: return AppTheme.warmAmber
        case .hotel: return AppTheme.royalPurple
        case .transitBus: return AppTheme.skyTeal
        case .transitSub: return AppTheme.indigoPrimary
        case .parkingLot: return Color.brown
        case .other: return Color.gray
        }
    }
}

// MARK: - 精致手账风格的草稿节点卡片行 (DraftNodeCardRow)

struct DraftNodeCardRow: View {
    let node: DraftNode
    let index: Int
    let isSelected: Bool
    var onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 节点主体行 (序号 + 标题 + 分类徽标 + 编辑按钮)
            HStack(spacing: 12) {
                // 序号圆形指示标
                ZStack {
                    Circle()
                        .fill(isSelected ? AppTheme.forestPrimary : badgeColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppTheme.sageMint : badgeColor.opacity(0.3), lineWidth: 1.2)
                        )
                    
                    Text("\(index)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : badgeColor)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(node.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        
                        // 分类胶囊
                        HStack(spacing: 3) {
                            Image(systemName: node.nodeType.systemIcon)
                                .font(.system(size: 9))
                            Text(node.nodeType.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.12))
                        .foregroundStyle(badgeColor)
                        .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 8) {
                        Label("\(node.durationMinutes)分钟", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        
                        if node.incomingTransit != .walking || !node.incomingGuide.isEmpty {
                            Label(node.incomingTransit.title, systemImage: node.incomingTransit.systemIcon)
                                .font(.system(size: 11))
                                .foregroundStyle(transitColor)
                        }
                    }
                }
                
                Spacer()
                
                // 编辑按钮
                Button {
                    HapticFeedback.light()
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.sageMint)
                }
                .buttonStyle(.plain)
            }
            
            // 换乘指引详细条 (若有)
            if !node.incomingGuide.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(transitColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: node.incomingTransit.systemIcon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    
                    Text(node.incomingGuide)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(transitColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            
            // 避坑贴士便签 (仿手账贴纸风格，若有)
            if !node.tips.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppTheme.warmAmber)
                        .frame(width: 2.5)
                        .padding(.vertical, 1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Text("💡")
                                .font(.system(size: 10))
                            Text("避坑指南")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.warmAmber)
                        }
                        
                        Text(node.tips)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.warmAmber.opacity(0.06))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AppTheme.cardBackground : AppTheme.cardBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? AppTheme.sageMint.opacity(0.7) : Color.primary.opacity(0.05),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? AppTheme.sageMint.opacity(0.12) : Color.black.opacity(0.03),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: 2
        )
    }
    
    private var badgeColor: Color {
        switch node.nodeType {
        case .attraction: return AppTheme.sunsetCoral
        case .restaurant: return AppTheme.warmAmber
        case .hotel: return AppTheme.royalPurple
        case .transitBus: return AppTheme.skyTeal
        case .transitSub: return AppTheme.indigoPrimary
        case .parkingLot: return Color.brown
        case .other: return Color.gray
        }
    }
    
    private var transitColor: Color {
        switch node.incomingTransit {
        case .walking: return AppTheme.skyTeal
        case .driving: return AppTheme.sunsetCoral
        case .transit: return AppTheme.indigoPrimary
        }
    }
}

// MARK: - 编辑草稿节点弹窗 (EditDraftNodeSheet)

struct EditDraftNodeSheet: View {
    @Bindable var node: DraftNode
    @Environment(\.dismiss) private var dismiss
    
    @State private var latString: String = ""
    @State private var lonString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("地点与类型") {
                    TextField("地点名称", text: $node.title)
                    Picker("地点类型", selection: $node.nodeType) {
                        ForEach(NodeType.allCases) { type in
                            Label(type.title, systemImage: type.systemIcon).tag(type)
                        }
                    }
                    Stepper("建议游玩: \(node.durationMinutes) 分钟", value: $node.durationMinutes, in: 15...360, step: 15)
                }
                
                Section("交通换乘指示") {
                    Picker("前序交通方式", selection: $node.incomingTransit) {
                        ForEach(TransitType.allCases) { transit in
                            Label(transit.title, systemImage: transit.systemIcon).tag(transit)
                        }
                    }
                    TextField("具体换乘指引 (如：乘2号线至陆家嘴站)", text: $node.incomingGuide, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("避坑贴士与游玩建议") {
                    TextField("避坑提示/最佳打卡机位/预约要求", text: $node.tips, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("经纬度坐标微调 (反查校验)") {
                    HStack {
                        Text("纬度 (Latitude)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("纬度", text: $latString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("经度 (Longitude)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("经度", text: $lonString)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
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
                        HapticFeedback.light()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.forestPrimary)
                }
            }
            .onAppear {
                latString = String(format: "%.6f", node.latitude)
                lonString = String(format: "%.6f", node.longitude)
            }
        }
    }
}
