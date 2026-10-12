import SwiftUI
import CoreLocation
import SwiftData

/// 手动添加行程节点弹窗
struct AddNodeSheet: View {
    let day: TripDay
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var nodeType: NodeType = .attraction
    @State private var incomingTransit: TransitType = .walking
    @State private var incomingGuide: String = ""
    @State private var tips: String = ""
    @State private var durationMinutes: Int = 60
    
    @State private var latitudeString: String = "31.2304"
    @State private var longitudeString: String = "121.4737"
    @State private var isGeocoding = false
    @State private var geocodeError: String?

    @State private var showMapPicker: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("地点基础信息") {
                    HStack {
                        TextField("地点/车站/停车场名称", text: $title)
                        
                        Button {
                            geocodeTitle()
                        } label: {
                            if isGeocoding {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("智能定位")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                    }
                    
                    Picker("地点类型", selection: $nodeType) {
                        ForEach(NodeType.allCases) { type in
                            Label(type.title, systemImage: type.systemIcon).tag(type)
                        }
                    }
                    
                    Stepper("预计游玩耗时: \(durationMinutes) 分钟", value: $durationMinutes, in: 10...360, step: 10)
                }
                
                Section {
                    Button {
                        showMapPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.forestPrimary.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "map.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.forestPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("在全景地图中搜索 / 点击选点")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                Text("当前坐标: \(latitudeString), \(longitudeString)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    
                    if let error = geocodeError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("地图选点与空间定位 (推荐)")
                } footer: {
                    Text("支持直接在地图中拖拽、点击任意位置精准选点，无需手动查询填写经纬度。")
                        .font(.caption2)
                }
                
                Section("抵达交通方式与指引") {
                    Picker("交通工具", selection: $incomingTransit) {
                        ForEach(TransitType.allCases) { transit in
                            Label(transit.title, systemImage: transit.systemIcon).tag(transit)
                        }
                    }
                    
                    TextField("例如：地铁2号线往浦东机场方向坐3站，C口出", text: $incomingGuide, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("避坑提醒与打卡攻略") {
                    TextField("例如：建议提前3天微信预约，周一闭馆", text: $tips, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("添加行程节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        saveNode()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                let lat = Double(latitudeString) ?? 31.2304
                let lon = Double(longitudeString) ?? 121.4737
                MapLocationPickerSheet(
                    initialCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    initialTitle: title,
                    destination: day.trip?.destination ?? ""
                ) { coord, newTitle, address in
                    latitudeString = String(format: "%.6f", coord.latitude)
                    longitudeString = String(format: "%.6f", coord.longitude)
                    if (title.isEmpty || title == "未知地点") && !newTitle.isEmpty {
                        title = newTitle
                    }
                }
            }
        }
    }
    
    private func geocodeTitle() {
        isGeocoding = true
        geocodeError = nil
        Task {
            do {
                let city = day.trip?.destination
                let coordinate = try await GeocodingService.shared.geocode(locationName: title, city: city)
                await MainActor.run {
                    latitudeString = String(format: "%.6f", coordinate.latitude)
                    longitudeString = String(format: "%.6f", coordinate.longitude)
                    isGeocoding = false
                }
            } catch {
                await MainActor.run {
                    geocodeError = "未找到精确坐标，请手动微调经纬度"
                    isGeocoding = false
                }
            }
        }
    }
    
    private func saveNode() {
        let lat = Double(latitudeString) ?? 31.2304
        let lon = Double(longitudeString) ?? 121.4737
        let newOrder = (day.nodes.map(\.sortOrder).max() ?? -1) + 1
        
        let node = RouteNode(
            title: title,
            latitude: lat,
            longitude: lon,
            sortOrder: newOrder,
            nodeType: nodeType,
            incomingTransit: incomingTransit,
            incomingTransitGuide: incomingGuide,
            tips: tips,
            durationMinutes: durationMinutes
        )
        node.day = day
        modelContext.insert(node)
        dismiss()
    }
}

// MARK: - 编辑行程节点弹窗 (EditNodeSheet)

struct EditNodeSheet: View {
    @Bindable var node: RouteNode
    var destination: String = ""
    var onDelete: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var nodeType: NodeType = .attraction
    @State private var incomingTransit: TransitType = .walking
    @State private var incomingGuide: String = ""
    @State private var tips: String = ""
    @State private var durationMinutes: Int = 60
    
    @State private var latitudeString: String = "31.2304"
    @State private var longitudeString: String = "121.4737"
    @State private var isGeocoding = false
    @State private var geocodeError: String?
    @State private var showMapPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    init(node: RouteNode, destination: String = "", onDelete: (() -> Void)? = nil) {
        self.node = node
        self.destination = destination
        self.onDelete = onDelete
        _title = State(initialValue: node.title)
        _nodeType = State(initialValue: node.nodeType)
        _incomingTransit = State(initialValue: node.incomingTransit)
        _incomingGuide = State(initialValue: node.incomingTransitGuide)
        _tips = State(initialValue: node.tips)
        _durationMinutes = State(initialValue: node.suggestedDurationMinutes)
        _latitudeString = State(initialValue: String(format: "%.6f", node.latitude))
        _longitudeString = State(initialValue: String(format: "%.6f", node.longitude))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("地点基础信息") {
                    HStack {
                        TextField("地点/车站/餐厅名称", text: $title)
                        
                        Button {
                            geocodeTitle()
                        } label: {
                            if isGeocoding {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("智能定位")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isGeocoding)
                    }
                    
                    Picker("地点类型", selection: $nodeType) {
                        ForEach(NodeType.allCases) { type in
                            Label(type.title, systemImage: type.systemIcon).tag(type)
                        }
                    }
                    
                    Stepper("预计游玩耗时: \(durationMinutes) 分钟", value: $durationMinutes, in: 10...360, step: 10)
                }
                
                Section {
                    Button {
                        showMapPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.forestPrimary.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "map.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.forestPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("在全景地图中搜索 / 点击选点")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.primary)
                                Text("当前坐标: \(latitudeString), \(longitudeString)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    
                    if let error = geocodeError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("地图选点与空间定位")
                } footer: {
                    Text("支持在全景地图中直接拖拽、点击任意位置精准更新落点坐标。")
                        .font(.caption2)
                }
                
                Section("抵达交通方式与指引") {
                    Picker("交通工具", selection: $incomingTransit) {
                        ForEach(TransitType.allCases) { transit in
                            Label(transit.title, systemImage: transit.systemIcon).tag(transit)
                        }
                    }
                    
                    TextField("例如：地铁2号线往浦东机场方向坐3站，C口出", text: $incomingGuide, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("避坑提醒与打卡攻略") {
                    TextField("例如：建议提前3天微信预约，周一闭馆", text: $tips, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                if let onDelete = onDelete {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("删除此地点")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("删除后将从当前天日程中移除，后续节点序号将自动重排。")
                            .font(.caption2)
                    }
                }
            }
            .navigationTitle("编辑地点信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                let lat = Double(latitudeString) ?? node.latitude
                let lon = Double(longitudeString) ?? node.longitude
                MapLocationPickerSheet(
                    initialCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    initialTitle: title,
                    destination: destination.isEmpty ? (node.day?.trip?.destination ?? "") : destination
                ) { coord, newTitle, address in
                    latitudeString = String(format: "%.6f", coord.latitude)
                    longitudeString = String(format: "%.6f", coord.longitude)
                    if (title.isEmpty || title == "未知地点") && !newTitle.isEmpty {
                        title = newTitle
                    }
                }
            }
            .confirmationDialog(
                "确定删除此地点？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除「\(node.title)」", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后不可恢复，确定要删除吗？")
            }
        }
    }
    
    private func geocodeTitle() {
        isGeocoding = true
        geocodeError = nil
        Task {
            do {
                let city = destination.isEmpty ? node.day?.trip?.destination : destination
                let coordinate = try await GeocodingService.shared.geocode(locationName: title, city: city)
                await MainActor.run {
                    latitudeString = String(format: "%.6f", coordinate.latitude)
                    longitudeString = String(format: "%.6f", coordinate.longitude)
                    isGeocoding = false
                }
            } catch {
                await MainActor.run {
                    geocodeError = "未找到精确坐标，请手动在地图中选点"
                    isGeocoding = false
                }
            }
        }
    }
    
    private func saveChanges() {
        let lat = Double(latitudeString) ?? node.latitude
        let lon = Double(longitudeString) ?? node.longitude
        
        node.title = title
        node.nodeType = nodeType
        node.incomingTransit = incomingTransit
        node.incomingTransitGuide = incomingGuide
        node.tips = tips
        node.suggestedDurationMinutes = durationMinutes
        node.latitude = lat
        node.longitude = lon
        
        HapticFeedback.success()
        try? modelContext.save()
        dismiss()
    }
}

