import SwiftUI
import CoreLocation

/// AI 解析步骤状态
enum AIStep: Int, CaseIterable, Identifiable {
    case sniffing = 1
    case reasoning = 2
    case geocoding = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .sniffing: return "嗅探笔记富文本"
        case .reasoning: return "提取结构化多模态路线"
        case .geocoding: return "反查并校准站点地理坐标"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .sniffing: return "network"
        case .reasoning: return "sparkles"
        case .geocoding: return "mappin.and.ellipse"
        }
    }
}

/// 小红书/社媒攻略 AI 导入浮层 (端侧无头抓取 + 直连 LLM 路线提取)
struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentStep: AIStep = .sniffing
    @State private var errorMessage: String?
    
    // 解析成功后的草稿数据
    @State private var parsedDraftDays: [DraftDay] = []
    @State private var parsedTripTitle: String = ""
    @State private var parsedDestination: String = ""
    @State private var parsedChecklist: [String] = []
    @State private var navigateToCalibration: Bool = false
    @State private var showSettings: Bool = false
    
    // 脉冲动效
    @State private var pulseEffect: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 1. 顶部功能介绍卡片
                headerGuideCard
                
                // 2. 输入框区域
                inputEditorSection
                
                // 3. 处理中动态流程指示卡片
                if isProcessing {
                    processingPipelineCard
                }
                
                // 4. 错误提示
                if let error = errorMessage {
                    errorBanner(message: error)
                }
                
                Spacer()
                
                // 5. 底部开始解析按钮
                actionButton
            }
            .navigationTitle("AI 攻略导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "key.fill")
                            .foregroundStyle(AppTheme.warmAmber)
                    }
                }
            }
            .onAppear {
                checkClipboard()
            }
            .navigationDestination(isPresented: $navigateToCalibration) {
                DraftCalibrationView(
                    tripTitle: parsedTripTitle,
                    destination: parsedDestination,
                    days: parsedDraftDays,
                    suggestedChecklist: parsedChecklist,
                    onSaved: {
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    // MARK: - 顶部说明卡片
    
    private var headerGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.sageMint)
                Text("端侧无感智能提取")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Text("支持直接粘贴小红书笔记文案、长篇游记或短链接（如 xhslink.com/...）。系统纯端侧直接解析并提取出多模态交通路线与打卡点。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 输入框区域
    
    private var inputEditorSection: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $inputText)
                .frame(minHeight: 130)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            
            HStack {
                // 快捷剪贴板读取
                Button {
                    HapticFeedback.light()
                    checkClipboard()
                } label: {
                    Label("粘贴剪贴板", systemImage: "doc.on.clipboard")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppTheme.forestPrimary)
                
                // 示例测试文案填充
                Button {
                    HapticFeedback.light()
                    loadSampleText()
                } label: {
                    Label("填入示例", systemImage: "wand.and.stars")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppTheme.warmAmber)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button("清空") {
                        inputText = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 处理流程动画卡片
    
    private var processingPipelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                // 动态脉冲光点
                Circle()
                    .fill(AppTheme.sageMint)
                    .frame(width: 10, height: 10)
                    .scaleEffect(pulseEffect ? 1.3 : 0.8)
                    .opacity(pulseEffect ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseEffect)
                
                Text("AI 正在提取路线...")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.forestPrimary)
            }
            .onAppear { pulseEffect = true }
            
            // 三步骤指示条
            VStack(alignment: .leading, spacing: 8) {
                ForEach(AIStep.allCases) { step in
                    let isDone = currentStep.rawValue > step.rawValue
                    let isCurrent = currentStep == step
                    
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(isDone ? AppTheme.sageMint : (isCurrent ? AppTheme.forestPrimary : Color.secondary.opacity(0.15)))
                                .frame(width: 20, height: 20)
                            
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: step.systemIcon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(isCurrent ? .white : .secondary)
                            }
                        }
                        
                        Text(step.title)
                            .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                            .foregroundStyle(isCurrent ? Color.primary : (isDone ? AppTheme.sageMint : .secondary))
                        
                        Spacer()
                        
                        if isCurrent {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 16)
    }
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.sunsetCoral)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.sunsetCoral)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 底部操作按钮
    
    private var actionButton: some View {
        Button {
            HapticFeedback.medium()
            startParsing()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("开始 AI 解析提取")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.brandGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.sageMint.opacity(0.35), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
        .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing ? 0.6 : 1.0)
    }
    
    // MARK: - 业务逻辑
    
    private func checkClipboard() {
        if let string = UIPasteboard.general.string, !string.isEmpty {
            inputText = string
        }
    }
    
    private func loadSampleText() {
        inputText = """
        【上海周末2日慢游路线】
        Day 1:
        1. 早上9点武康大楼打卡，梧桐区慢走，停留1小时。
        2. 步行至安福路吃Brunch，特色面包咖啡，停留1.5小时。
        3. 乘地铁10号线坐4站至豫园站，逛城隍庙与九曲桥，注意节假日排队避坑。
        4. 傍晚步行至外滩观景台看万国建筑群与陆家嘴夜景。

        Day 2:
        1. 早上轮渡过黄浦江至陆家嘴站C口出，打卡东方明珠脚下三件套。
        2. 随后打车前往浦东美术馆看展，顶楼露台拍照极佳。

        特需打包清单：充电宝、轻便步行鞋、晴雨伞。
        """
    }
    
    private func startParsing() {
        guard SettingsManager.shared.isApiKeyConfigured else {
            errorMessage = "尚未配置 AI API Key，请点击右上角钥匙图标进行配置"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        currentStep = .sniffing
        
        Task {
            do {
                var contentToParse = inputText
                
                // 步骤 1：检测是否为链接，若是则尝试端侧无头抓取
                if let url = WebSnifferService.extractURL(from: inputText) {
                    await MainActor.run {
                        currentStep = .sniffing
                    }
                    do {
                        let sniffed = try await WebSnifferService.shared.sniffContent(from: url)
                        contentToParse = "标题: \(sniffed.title)\n\n正文:\n\(sniffed.text)\n\n补充用户输入:\n\(inputText)"
                    } catch {
                        // 抓取失败降级为直接解析原输入文案
                    }
                }
                
                // 步骤 2：调用直连大模型提取结构化路线
                await MainActor.run {
                    currentStep = .reasoning
                }
                let dto = try await LLMParserService.shared.parseTrip(from: contentToParse)
                
                // 步骤 3：原生地理编码反查所有节点坐标
                await MainActor.run {
                    currentStep = .geocoding
                }
                
                var draftDays: [DraftDay] = []
                for dayDTO in dto.days {
                    var draftNodes: [DraftNode] = []
                    for nodeDTO in dayDTO.nodes {
                        let nodeType = NodeType(rawValue: nodeDTO.nodeType) ?? .attraction
                        let transitType = TransitType(rawValue: nodeDTO.incomingTransit) ?? .walking
                        
                        var coord = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
                        if let resolvedCoord = try? await GeocodingService.shared.geocode(
                            locationName: nodeDTO.title,
                            city: dto.destination
                        ) {
                            coord = resolvedCoord
                        }
                        
                        let draftNode = DraftNode(
                            title: nodeDTO.title,
                            latitude: coord.latitude,
                            longitude: coord.longitude,
                            nodeType: nodeType,
                            incomingTransit: transitType,
                            incomingGuide: nodeDTO.incomingGuide ?? "",
                            tips: nodeDTO.tips ?? "",
                            durationMinutes: nodeDTO.durationMinutes ?? 60
                        )
                        draftNodes.append(draftNode)
                    }
                    draftDays.append(DraftDay(dayIndex: dayDTO.dayIndex, summary: dayDTO.summary, nodes: draftNodes))
                }
                
                await MainActor.run {
                    self.parsedTripTitle = dto.tripTitle
                    self.parsedDestination = dto.destination
                    self.parsedDraftDays = draftDays
                    self.parsedChecklist = dto.suggestedChecklist ?? []
                    self.isProcessing = false
                    self.navigateToCalibration = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
