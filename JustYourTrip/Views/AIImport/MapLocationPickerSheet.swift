import SwiftUI
import MapKit
import CoreLocation

/// 工业级高精度地图交互选点与 POI 搜索确认组件
/// 支持：
/// 1. 全国级标准 POI 关键字搜索与候选列表快速定位
/// 2. 地图任意位置点按落点 (MapReader Tap-to-Pin)
/// 3. 实时逆地理编码 (Reverse Geocoding) 显示详细区划与地名
/// 4. 底部一键确认悬浮卡，告别繁琐手动输入经纬度
struct MapLocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // 输入参数
    let destination: String
    private var targetNode: DraftNode?
    private var onConfirmCoordinate: ((CLLocationCoordinate2D, String, String) -> Void)?
    
    // 地图与坐标状态
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var selectedTitle: String
    @State private var selectedAddress: String
    @State private var isReverseGeocoding: Bool = false
    
    // 搜索与候选列表状态
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearchListExpanded: Bool = false
    @State private var searchFeedbackMessage: String?
    
    // 快捷初始化器 1：针对草稿节点 DraftNode
    init(node: DraftNode, destination: String = "") {
        self.targetNode = node
        self.destination = destination
        self.onConfirmCoordinate = nil
        
        let initialCoord = node.coordinate
        _selectedCoordinate = State(initialValue: initialCoord)
        _selectedTitle = State(initialValue: node.title)
        _selectedAddress = State(initialValue: node.formattedAddress.isEmpty ? "点击地图任意位置可重新选点" : node.formattedAddress)
        _searchText = State(initialValue: GeocodingService.cleanPOIKeyword(title: node.title))
        
        let span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        let region = MKCoordinateRegion(center: initialCoord, span: span)
        _cameraPosition = State(initialValue: .region(region))
    }
    
    // 快捷初始化器 2：针对自定义坐标与回调
    init(
        initialCoordinate: CLLocationCoordinate2D,
        initialTitle: String = "",
        initialAddress: String = "",
        destination: String = "",
        onConfirm: @escaping (CLLocationCoordinate2D, String, String) -> Void
    ) {
        self.targetNode = nil
        self.destination = destination
        self.onConfirmCoordinate = onConfirm
        
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _selectedTitle = State(initialValue: initialTitle)
        _selectedAddress = State(initialValue: initialAddress.isEmpty ? "点击地图任意位置可重新选点" : initialAddress)
        _searchText = State(initialValue: GeocodingService.cleanPOIKeyword(title: initialTitle))
        
        let span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        let region = MKCoordinateRegion(center: initialCoordinate, span: span)
        _cameraPosition = State(initialValue: .region(region))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // MARK: - 1. 主地图交互区 (支持点击落点与手势平移缩放)
                mapCanvasSection
                
                // MARK: - 2. 顶部悬浮搜索栏与候选结果卡片
                VStack(spacing: 8) {
                    searchBarOverlay
                    
                    if isSearchListExpanded {
                        searchResultsDropdown
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // MARK: - 3. 底部选定位置确认悬浮卡片
                VStack {
                    Spacer()
                    bottomConfirmationCard
                }
            }
            .navigationTitle("地图搜索与选点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if selectedAddress.isEmpty || selectedAddress.contains("点击地图") {
                    triggerReverseGeocode(for: selectedCoordinate)
                }
            }
        }
    }
    
    // MARK: - 地图画布 (MapReader 支持点击拾取坐标)
    
    private var mapCanvasSection: some View {
        MapReader { reader in
            Map(position: $cameraPosition) {
                // 选定图钉标记 Pin
                Annotation(selectedTitle.isEmpty ? "选定位置" : selectedTitle, coordinate: selectedCoordinate) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.forestPrimary.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .fill(AppTheme.forestPrimary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 5, y: 3)
                        
                        Image(systemName: "mappin")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .onTapGesture { screenPoint in
                if let tappedCoordinate = reader.convert(screenPoint, from: .local) {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedCoordinate = tappedCoordinate
                        isSearchListExpanded = false
                    }
                    triggerReverseGeocode(for: tappedCoordinate)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - 顶部搜索胶囊栏
    
    private var searchBarOverlay: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.forestPrimary)
            
            TextField("输入地点/景点/火车站搜索(支持全国)", text: $searchText)
                .font(.system(size: 14))
                .submitLabel(.search)
                .onSubmit {
                    executeSearch()
                }
            
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                    isSearchListExpanded = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button("搜索") {
                executeSearch()
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.forestPrimary)
            .buttonStyle(.plain)
            .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - 搜索结果候选浮层列表
    
    private var searchResultsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let msg = searchFeedbackMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else if searchResults.isEmpty {
                Text("输入地标后点击搜索查看匹配地点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(searchResults, id: \.self) { item in
                            Button {
                                selectSearchResult(item)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(AppTheme.forestPrimary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "未知地标")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.primary)
                                        
                                        if let fullAddress = item.placemark.title {
                                            Text(fullAddress)
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - 底部确认卡片
    
    private var bottomConfirmationCard: some View {
        VStack(spacing: 12) {
            // 地点名称与地址信息
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(selectedTitle.isEmpty ? "已在地图选点" : selectedTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // 提示用户可直接在地图点按
                        Text("点击地图可重选")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.forestPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.forestPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    if isReverseGeocoding {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.mini)
                            Text("正在反查实际街道与地名...")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(selectedAddress)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // 坐标数值小标签 (仅作参考，无需用户干预)
                    Text(String(format: "%.5f°N, %.5f°E", selectedCoordinate.latitude, selectedCoordinate.longitude))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            
            // 一键确认采纳按钮
            Button {
                confirmSelection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认使用此地点坐标")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.brandGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.sageMint.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
    
    // MARK: - 交互操作逻辑
    
    /// 执行 POI 地图搜索
    private func executeSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSearching = true
        searchFeedbackMessage = nil
        isSearchListExpanded = true
        
        Task {
            let anchor = await GeocodingService.shared.resolveCityAnchor(destination: destination)
            let items = await GeocodingService.shared.searchPOISuggestions(query: trimmed, cityAnchor: anchor)
            
            await MainActor.run {
                self.isSearching = false
                self.searchResults = items
                if items.isEmpty {
                    self.searchFeedbackMessage = "未找到“\(trimmed)”的匹配地点，建议尝试添加城市或输入景区全称"
                }
            }
        }
    }
    
    /// 从搜索列表中采纳某个 POI
    private func selectSearchResult(_ item: MKMapItem) {
        HapticFeedback.success()
        let coord = item.placemark.coordinate
        selectedCoordinate = coord
        
        if let name = item.name, !name.isEmpty {
            selectedTitle = name
        }
        if let fullAddr = item.placemark.title {
            selectedAddress = fullAddr
        }
        
        // 地图相机平滑飞行居中到目标位置
        withAnimation(.easeInOut(duration: 0.6)) {
            let span = MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            cameraPosition = .region(MKCoordinateRegion(center: coord, span: span))
            isSearchListExpanded = false
        }
    }
    
    /// 逆地理编码获取实际文字地址
    private func triggerReverseGeocode(for coordinate: CLLocationCoordinate2D) {
        isReverseGeocoding = true
        Task {
            let address = await GeocodingService.shared.reverseGeocode(coordinate: coordinate)
            await MainActor.run {
                self.isReverseGeocoding = false
                if let addr = address, !addr.isEmpty {
                    self.selectedAddress = addr
                } else {
                    self.selectedAddress = "已选定经纬度坐标"
                }
            }
        }
    }
    
    /// 确认提交选点
    private func confirmSelection() {
        HapticFeedback.success()
        
        // 若绑定了 DraftNode，直接就地更新属性
        if let node = targetNode {
            node.latitude = selectedCoordinate.latitude
            node.longitude = selectedCoordinate.longitude
            node.isVerified = true
            node.formattedAddress = selectedAddress
            if !selectedTitle.isEmpty && (node.title == "未知地点" || node.title.isEmpty) {
                node.title = selectedTitle
            }
        }
        
        // 若有自定义回调，同步触发
        onConfirmCoordinate?(selectedCoordinate, selectedTitle, selectedAddress)
        
        dismiss()
    }
}
