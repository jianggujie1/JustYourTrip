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
                                Text("反查坐标")
                                    .font(.caption)
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
                
                Section("地理坐标 (GCJ-02 / WGS-84)") {
                    HStack {
                        Text("纬度")
                        TextField("例如 31.2304", text: $latitudeString)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("经度")
                        TextField("例如 121.4737", text: $longitudeString)
                            .keyboardType(.decimalPad)
                    }
                    if let error = geocodeError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
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
