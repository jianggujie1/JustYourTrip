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

/// 小红书/社媒攻略 AI 导入浮层 (端侧无头抓取 + 直连 LLM 实时流式提取)
struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentStep: AIStep = .sniffing
    @State private var errorMessage: String?
    
    // 流式打字机状态 (类似 AI 问答)
    @State private var streamContent: String = ""
    @State private var streamReasoning: String = ""
    @State private var showReasoning: Bool = false
    @State private var isReasoningPhase: Bool = false
    @State private var geocodingInfo: String = ""
    @State private var parseTask: Task<Void, Never>? = nil
    
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 顶部功能介绍卡片
                        headerGuideCard
                        
                        // 2. 输入框区域 (未开始时展示完整输入框，处理中时收纳为摘要卡片)
                        if !isProcessing {
                            inputEditorSection
                        } else {
                            processingInputSummary
                        }
                        
                        // 3. 处理中动态流程指示卡片
                        if isProcessing {
                            processingPipelineCard
                            
                            // 实时 AI 问答打字机控制台
                            if currentStep == .reasoning {
                                streamingConsoleCard
                            }
                        }
                        
                        // 4. 错误提示
                        if let error = errorMessage {
                            errorBanner(message: error)
                        }
                    }
                    .padding(.vertical, 14)
                }
                
                // 5. 底部开始/中断解析按钮
                actionButton
            }
            .navigationTitle("AI 攻略导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        parseTask?.cancel()
                        dismiss()
                    }
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
                Text("端侧无感智能流式提取")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Text("支持直接粘贴小红书笔记文案、长篇游记或短链接（如 xhslink.com/...）。直连大模型采用 SSE 流式长连接输出，像对话问答一样实时展示构思细节，告别超时等待。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 处理中文案摘要胶囊
    
    private var processingInputSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.forestPrimary)
            
            Text(inputText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("共 \(inputText.count) 字")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
                
                Text(currentStep == .reasoning ? "AI 实时构思与路线提取中..." : (currentStep == .geocoding ? "地理编码校准中..." : "正在抓取网页内容..."))
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
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                                .foregroundStyle(isCurrent ? Color.primary : (isDone ? AppTheme.sageMint : .secondary))
                            
                            if isCurrent && step == .geocoding && !geocodingInfo.isEmpty {
                                Text(geocodingInfo)
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppTheme.sageMint)
                            }
                        }
                        
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
    
    // MARK: - 实时 AI 问答打字机控制台 (Streaming Console)
    
    private var streamingConsoleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 控制台抬头
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.sparkles.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.sageMint)
                    
                    Text(isReasoningPhase ? "AI 深度思考推理中..." : "AI 实时构思问答输出")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // 实时字数统计徽标
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppTheme.luminousMint)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseEffect ? 1.2 : 0.8)
                    
                    Text("\(streamContent.count + streamReasoning.count) 字")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.forestPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(AppTheme.forestPrimary.opacity(0.08))
                .clipShape(Capsule())
            }
            
            // 若包含 DeepSeek R1 思考过程 (reasoning_content)
            if !streamReasoning.isEmpty {
                DisclosureGroup(isExpanded: $showReasoning) {
                    ScrollView {
                        Text(streamReasoning)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 100)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.warmAmber)
                        Text("查看模型推理过程 (\(streamReasoning.count) 字)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.warmAmber)
                    }
                }
            }
            
            // 实时打字输出流视窗 (Typewriter AI Chat Bubble)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if streamContent.isEmpty && streamReasoning.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("已建立流式传输连接，等待模型输出首批词元...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 16)
                        } else {
                            HStack(alignment: .bottom, spacing: 2) {
                                Text(streamContent.isEmpty ? streamReasoning : streamContent)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineSpacing(3)
                                
                                // 打字机闪烁光标
                                Text("▊")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppTheme.sageMint)
                                    .opacity(pulseEffect ? 1.0 : 0.2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("STREAM_BOTTOM")
                        }
                    }
                    .padding(10)
                }
                .frame(minHeight: 110, maxHeight: 220)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
                )
                .onChange(of: streamContent) { _, _ in
                    scrollProxy.scrollTo("STREAM_BOTTOM", anchor: .bottom)
                }
            }
        }
        .padding(14)
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
        Group {
            if isProcessing {
                Button {
                    HapticFeedback.warning()
                    cancelParsing()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.circle.fill")
                        Text("中断解析")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.sunsetCoral.opacity(0.12))
                    .foregroundStyle(AppTheme.sunsetCoral)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            } else {
                Button {
                    HapticFeedback.medium()
                    startParsing()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("开始 AI 流式解析提取")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: AppTheme.sageMint.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    
    private func cancelParsing() {
        parseTask?.cancel()
        parseTask = nil
        isProcessing = false
        errorMessage = "已取消本次解析。"
    }
    
    private func startParsing() {
        guard SettingsManager.shared.isApiKeyConfigured else {
            errorMessage = "尚未配置 AI API Key，请点击右上角钥匙图标进行配置"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        currentStep = .sniffing
        streamContent = ""
        streamReasoning = ""
        isReasoningPhase = false
        geocodingInfo = ""
        
        parseTask = Task {
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
                
                try Task.checkCancellation()
                
                // 步骤 2：流式调用直连大模型提取结构化路线 (实时打字机效果)
                await MainActor.run {
                    currentStep = .reasoning
                }
                
                let dto = try await LLMParserService.shared.parseTripStream(from: contentToParse) { progress in
                    Task { @MainActor in
                        self.isReasoningPhase = progress.isReasoning
                        self.streamReasoning = progress.accumulatedReasoning
                        self.streamContent = progress.accumulatedContent
                    }
                }
                
                try Task.checkCancellation()
                
                // 步骤 3：原生地理编码反查所有节点坐标
                await MainActor.run {
                    currentStep = .geocoding
                }
                
                var draftDays: [DraftDay] = []
                let totalNodesCount = dto.days.reduce(0) { $0 + $1.nodes.count }
                var currentNodeIndex = 0
                
                for dayDTO in dto.days {
                    var draftNodes: [DraftNode] = []
                    for nodeDTO in dayDTO.nodes {
                        try Task.checkCancellation()
                        currentNodeIndex += 1
                        let nodeTitle = nodeDTO.title
                        let currentIndex = currentNodeIndex
                        
                        await MainActor.run {
                            self.geocodingInfo = "第 \(currentIndex)/\(totalNodesCount) 站: \(nodeTitle)"
                        }
                        
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
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.parsedTripTitle = dto.tripTitle
                    self.parsedDestination = dto.destination
                    self.parsedDraftDays = draftDays
                    self.parsedChecklist = dto.suggestedChecklist ?? []
                    self.isProcessing = false
                    self.navigateToCalibration = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isProcessing = false
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
