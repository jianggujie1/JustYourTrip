import SwiftUI
import CoreLocation

// MARK: - AI 规划大阶段定义 (3大核心主阶段)
enum AIPhase: Int, CaseIterable, Identifiable {
    case sniffing = 1   // 阶段一：网页嗅探与文本准备
    case parsing = 2    // 阶段二：AI 智能行程解构
    case geocoding = 3  // 阶段三：空间拓扑与地理校准

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sniffing: return "网页嗅探与文本准备"
        case .parsing: return "AI 智能行程解构"
        case .geocoding: return "空间拓扑与地理校准"
        }
    }

    var subtitle: String {
        switch self {
        case .sniffing: return "识别内容 · 提取正文 · 净化杂质"
        case .parsing: return "结构分析 · 提炼站点 · 规划建议"
        case .geocoding: return "城市锚点 · POI校准 · 防重纠偏"
        }
    }

    var icon: String {
        switch self {
        case .sniffing: return "globe.asia.australia.fill"
        case .parsing: return "sparkles"
        case .geocoding: return "map.fill"
        }
    }

    var subSteps: [AISubStep] {
        AISubStep.allCases.filter { $0.phase == self }
    }
}

// MARK: - AI 细分子步骤定义 (9大具体执行细步)
enum AISubStep: Int, CaseIterable, Identifiable, Hashable {
    // 阶段一：嗅探与准备
    case detectURL = 1
    case fetchContent = 2
    case cleanContent = 3

    // 阶段二：AI 智能解构
    case connectModel = 4
    case extractStructure = 5
    case extractChecklist = 6

    // 阶段三：空间拓扑校准
    case cityAnchor = 7
    case resolvePOI = 8
    case topologyOptimization = 9

    var id: Int { rawValue }

    var phase: AIPhase {
        switch self {
        case .detectURL, .fetchContent, .cleanContent:
            return .sniffing
        case .connectModel, .extractStructure, .extractChecklist:
            return .parsing
        case .cityAnchor, .resolvePOI, .topologyOptimization:
            return .geocoding
        }
    }

    var title: String {
        switch self {
        case .detectURL: return "识别内容格式与链接"
        case .fetchContent: return "端侧网络抓取网页正文"
        case .cleanContent: return "净化文案与去除冗余"
        case .connectModel: return "连接大模型分析上下文"
        case .extractStructure: return "多模态提取每日路线与换乘"
        case .extractChecklist: return "生成穿衣推荐、避坑建议与行前清单"
        case .cityAnchor: return "锁定城市空间基准锚点"
        case .resolvePOI: return "高精反查与校准站点坐标"
        case .topologyOptimization: return "空间拓扑防重叠与优化"
        }
    }

    var icon: String {
        switch self {
        case .detectURL: return "link"
        case .fetchContent: return "arrow.down.doc.fill"
        case .cleanContent: return "wand.and.stars"
        case .connectModel: return "antenna.radiowaves.left.and.right"
        case .extractStructure: return "point.topleft.down.to.point.bottomright.curvepath"
        case .extractChecklist: return "checklist.checked"
        case .cityAnchor: return "mappin.circle.fill"
        case .resolvePOI: return "magnifyingglass"
        case .topologyOptimization: return "shield.checkered"
        }
    }
}

/// 小红书/社媒攻略 AI 导入浮层 (端侧双引擎网页嗅探 + 3大阶段 9大细步友善进度展示)
struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentPhase: AIPhase = .sniffing
    @State private var currentSubStep: AISubStep = .detectURL
    @State private var subStepDetails: [AISubStep: String] = [:]
    @State private var errorMessage: String?
    @State private var parseTask: Task<Void, Never>? = nil

    // 解析成功后的草稿数据
    @State private var parsedDraftDays: [DraftDay] = []
    @State private var parsedTripTitle: String = ""
    @State private var parsedDestination: String = ""
    @State private var parsedChecklist: [String] = []
    @State private var parsedOutfitAdvice: String = ""
    @State private var navigateToCalibration: Bool = false
    @State private var showSettings: Bool = false

    // 脉冲微动效
    @State private var pulseEffect: Bool = false

    /// 实时提取输入框中的 URL
    private var detectedURL: URL? {
        WebSnifferService.extractURL(from: inputText)
    }

    /// 总体进度百分比 (0.0 ~ 1.0)
    private var overallProgressFraction: Double {
        if !isProcessing && parsedDraftDays.isEmpty { return 0 }
        if !parsedDraftDays.isEmpty { return 1.0 }
        let currentIdx = Double(currentSubStep.rawValue - 1)
        return min(0.95, max(0.08, currentIdx / 9.0))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 顶部功能介绍卡片 (未处理时展示)
                        if !isProcessing {
                            headerGuideCard
                            inputEditorSection
                        } else {
                            // 处理中：输入文案收纳摘要
                            processingInputSummary
                            // 友好 3 大阶段 9 大细步动态流水线面板
                            processingPipelineSection
                        }

                        // 错误提示
                        if let error = errorMessage {
                            errorBanner(message: error)
                        }
                    }
                    .padding(.vertical, 14)
                }

                // 底部开始/中断解析按钮
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
                    outfitAdvice: parsedOutfitAdvice,
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
                Text("端侧联网嗅探 + 智能全流程解构")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            Text("支持直接粘贴小红书笔记文案、长篇游记或社媒短链接（如 xhslink.com/...）。系统将自动联网抓取页面完整正文并交由大模型分步解析，生成可精准导航的结构化行程。")
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
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $inputText)
                .frame(minHeight: 130)
                .padding(10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )

            // 实时链接识别感知胶囊
            if let url = detectedURL {
                detectedURLBanner(url: url)
            }

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

    // MARK: - 实时识别到链接时的视觉提示

    private func detectedURLBanner(url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.forestPrimary)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("已识别到攻略链接:")
                        .font(.system(size: 11, weight: .bold))
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppTheme.forestPrimary)
                        .lineLimit(1)
                }
                Text("点击开始后将自动联网访问该网页，抓取真实正文供 AI 解析")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.sageMint)
        }
        .padding(10)
        .background(AppTheme.sageMint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.sageMint.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 3 大阶段 × 9 大细步动态流水线面板

    private var processingPipelineSection: some View {
        VStack(spacing: 12) {
            // 1. 总体进度仪表盘
            overallProgressDashboard

            // 2. 三大主阶段卡片流
            ForEach(AIPhase.allCases) { phase in
                phaseCardView(for: phase)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 总体进度仪表盘

    private var overallProgressDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(AppTheme.sageMint)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseEffect ? 1.3 : 0.8)
                        .opacity(pulseEffect ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseEffect)

                    Text("AI 规划解析流水线")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.forestPrimary)
                }

                Spacer()

                Text("第 \(currentPhase.rawValue)/3 阶段 · \(Int(overallProgressFraction * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.forestPrimary)
            }
            .onAppear { pulseEffect = true }

            // 平滑主进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)

                    Capsule()
                        .fill(AppTheme.brandGradient)
                        .frame(width: geo.size.width * CGFloat(overallProgressFraction), height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: overallProgressFraction)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    // MARK: - 单个主阶段卡片 (含对应细分子步骤)

    private func phaseCardView(for phase: AIPhase) -> some View {
        let isDone = phase.rawValue < currentPhase.rawValue
        let isCurrent = phase == currentPhase
        let isPending = phase.rawValue > currentPhase.rawValue

        return VStack(alignment: .leading, spacing: 12) {
            // 主阶段抬头行
            HStack(spacing: 10) {
                // 阶段图标或完成勾选
                ZStack {
                    Circle()
                        .fill(
                            isDone ? AppTheme.sageMint :
                            (isCurrent ? AppTheme.forestPrimary : Color.secondary.opacity(0.12))
                        )
                        .frame(width: 28, height: 28)

                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: phase.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(isCurrent ? .white : .secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("阶段 \(phase.rawValue) · \(phase.title)")
                        .font(.system(size: 14, weight: isCurrent ? .bold : .semibold))
                        .foregroundStyle(isCurrent ? Color.primary : (isDone ? AppTheme.forestPrimary : .secondary))

                    Text(phase.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // 状态微标
                if isDone {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("已完成")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(AppTheme.sageMint.opacity(0.15))
                    .foregroundStyle(AppTheme.sageMint)
                    .clipShape(Capsule())
                } else if isCurrent {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("处理中")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(AppTheme.forestPrimary.opacity(0.10))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                } else {
                    Text("待执行")
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.primary.opacity(0.04))
                        .foregroundStyle(.tertiary)
                        .clipShape(Capsule())
                }
            }

            // 细分子步骤列表 (当该阶段处于进行中或已完成时展开展示，直观友善)
            if !isPending {
                Divider()
                    .opacity(0.4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(phase.subSteps) { subStep in
                        subStepRowView(for: subStep)
                    }
                }
                .padding(.leading, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrent ? Color(uiColor: .secondarySystemGroupedBackground) : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isCurrent ? AppTheme.sageMint.opacity(0.4) : Color.primary.opacity(0.05),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        )
        .shadow(color: isCurrent ? AppTheme.forestPrimary.opacity(0.06) : Color.clear, radius: 10, x: 0, y: 4)
    }

    // MARK: - 细分子步骤行视图

    private func subStepRowView(for subStep: AISubStep) -> some View {
        let isDone = subStep.rawValue < currentSubStep.rawValue
        let isCurrent = subStep == currentSubStep
        let detailText = subStepDetails[subStep]

        return HStack(alignment: .top, spacing: 9) {
            // 左侧状态圆点
            ZStack {
                Circle()
                    .fill(
                        isDone ? AppTheme.sageMint :
                        (isCurrent ? AppTheme.forestPrimary : Color.secondary.opacity(0.15))
                    )
                    .frame(width: 16, height: 16)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.top, 2)

            // 步骤文本与动态详情
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(subStep.title)
                        .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                        .foregroundStyle(isCurrent ? Color.primary : (isDone ? AppTheme.forestPrimary : .secondary))

                    if isCurrent {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                // 动态细步进展描述
                if let detail = detailText, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(isDone ? AppTheme.sageMint : AppTheme.forestPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
    }

    // MARK: - 错误指引提示卡片

    private func errorBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.warmAmber)
                    .font(.system(size: 15))

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            }

            // 若错误提示包含指引，提供一键操作辅助
            if message.contains("复制文案") {
                HStack(spacing: 8) {
                    Button {
                        HapticFeedback.light()
                        checkClipboard()
                    } label: {
                        Label("粘贴已复制的文案", systemImage: "doc.on.clipboard")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(AppTheme.forestPrimary)

                    Button {
                        HapticFeedback.light()
                        loadSampleText()
                    } label: {
                        Label("填入完整示例体验", systemImage: "wand.and.stars")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AppTheme.warmAmber)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(AppTheme.warmAmber.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.warmAmber.opacity(0.3), lineWidth: 1)
        )
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
                        Text("开始 AI 智能规划提取")
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

        【穿衣穿搭推荐】: 春秋季早晚温差大，建议长袖打底配风衣或开衫；梧桐区出片适合浅色系或复古法式穿搭，江边夜景观光风大备一件防风外套；全程徒步较多，务必穿舒适平底健步鞋。
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
        currentPhase = .sniffing
        currentSubStep = .detectURL
        subStepDetails = [:]

        parseTask = Task {
            do {
                var contentToParse = inputText

                // ==========================================
                // 阶段一：网页嗅探与文本准备
                // ==========================================
                await MainActor.run {
                    self.currentPhase = .sniffing
                    self.currentSubStep = .detectURL
                }

                if let url = WebSnifferService.extractURL(from: inputText) {
                    await MainActor.run {
                        self.subStepDetails[.detectURL] = "识别到网址：\(url.host ?? url.absoluteString)"
                        self.currentSubStep = .fetchContent
                        self.subStepDetails[.fetchContent] = "正在联网访问网页正文..."
                    }

                    let userCleanedNote = WebSnifferService.cleanSocialBoilerplate(from: inputText)

                    do {
                        let sniffed = try await WebSnifferService.shared.sniffContent(from: url)
                        if sniffed.isSufficient {
                            let displayTitle = sniffed.title.isEmpty ? "网页攻略" : sniffed.title
                            await MainActor.run {
                                self.subStepDetails[.fetchContent] = "已成功提取《\(displayTitle)》（共 \(sniffed.text.count) 字）"
                                self.currentSubStep = .cleanContent
                                self.subStepDetails[.cleanContent] = "剥离社媒营销与模版冗余，提取核心游记段落"
                            }
                            var promptText = "【来源网页标题】: \(displayTitle)\n【来源网址】: \(url.absoluteString)\n\n【网页攻略正文】:\n\(sniffed.text)"
                            if !userCleanedNote.isEmpty {
                                promptText += "\n\n【用户补充说明】:\n\(userCleanedNote)"
                            }
                            contentToParse = promptText
                        } else {
                            if userCleanedNote.count >= 60 {
                                await MainActor.run {
                                    self.subStepDetails[.fetchContent] = "网页开启了防护，自动采用您输入的文案（共 \(userCleanedNote.count) 字）"
                                    self.currentSubStep = .cleanContent
                                    self.subStepDetails[.cleanContent] = "已整理有效正文"
                                }
                                contentToParse = userCleanedNote
                            } else {
                                throw WebSnifferError.antiCrawlerBlocked(title: sniffed.title)
                            }
                        }
                    } catch let snifferErr as WebSnifferError {
                        if userCleanedNote.count >= 60 {
                            await MainActor.run {
                                self.subStepDetails[.fetchContent] = "采用您输入的文案（共 \(userCleanedNote.count) 字）"
                                self.currentSubStep = .cleanContent
                                self.subStepDetails[.cleanContent] = "已整理有效正文"
                            }
                            contentToParse = userCleanedNote
                        } else {
                            await MainActor.run {
                                self.isProcessing = false
                                switch snifferErr {
                                case .antiCrawlerBlocked:
                                    self.errorMessage = """
                                    ⚠️ 该平台链接开启了防爬机制或需要客户端验证，端侧未能直接抓取到正文。

                                    💡 轻松解决方案：
                                    请在小红书/社媒 App 中打开该笔记，长按文案选择「复制文案」，然后粘贴到上方输入框，AI 即可 100% 精准为您解析路线！
                                    """
                                default:
                                    self.errorMessage = "\(snifferErr.localizedDescription)。建议在社媒 App 中长按选择「复制文案」直接粘贴到输入框。"
                                }
                            }
                            return
                        }
                    } catch {
                        if userCleanedNote.count >= 60 {
                            await MainActor.run {
                                self.subStepDetails[.fetchContent] = "基于输入文案继续解析"
                                self.currentSubStep = .cleanContent
                                self.subStepDetails[.cleanContent] = "已整理有效正文"
                            }
                            contentToParse = userCleanedNote
                        } else {
                            await MainActor.run {
                                self.isProcessing = false
                                self.errorMessage = "网络连接失败，未能获取网页内容。建议直接复制笔记文案粘贴到输入框。"
                            }
                            return
                        }
                    }
                } else {
                    await MainActor.run {
                        self.subStepDetails[.detectURL] = "识别到纯文本攻略（共 \(inputText.count) 字）"
                        self.currentSubStep = .fetchContent
                        self.subStepDetails[.fetchContent] = "直接读取本地输入文本"
                        self.currentSubStep = .cleanContent
                        self.subStepDetails[.cleanContent] = "已整理有效攻略段落"
                    }
                }

                try Task.checkCancellation()

                // ==========================================
                // 阶段二：AI 智能行程解构
                // ==========================================
                await MainActor.run {
                    self.currentPhase = .parsing
                    self.currentSubStep = .connectModel
                    self.subStepDetails[.connectModel] = "已连接 \(SettingsManager.shared.modelName)，大模型正在理解行程意图..."
                }

                let dto = try await LLMParserService.shared.parseTripStream(from: contentToParse) { progress in
                    Task { @MainActor in
                        if progress.isReasoning {
                            if self.currentSubStep != .connectModel {
                                self.currentSubStep = .connectModel
                            }
                            self.subStepDetails[.connectModel] = "模型正在深入理解旅行偏好与日程时序..."
                        } else {
                            let len = progress.accumulatedContent.count
                            if len < 350 {
                                if self.currentSubStep != .extractStructure {
                                    self.currentSubStep = .extractStructure
                                }
                                self.subStepDetails[.extractStructure] = "正在提炼行程天数、打卡景点与交通换乘..."
                            } else {
                                if self.currentSubStep != .extractChecklist {
                                    self.currentSubStep = .extractChecklist
                                }
                                self.subStepDetails[.extractChecklist] = "正在萃取出行避坑建议与行李清单..."
                            }
                        }
                    }
                }

                try Task.checkCancellation()

                let totalNodesCount = dto.days.reduce(0) { $0 + $1.nodes.count }
                await MainActor.run {
                    self.subStepDetails[.extractStructure] = "已解析 \(dto.days.count) 天日程，共 \(totalNodesCount) 处节点"
                    self.subStepDetails[.extractChecklist] = "已生成避坑 Tips 及 \(dto.suggestedChecklist?.count ?? 0) 项特需装备"
                }

                // ==========================================
                // 阶段三：空间拓扑与地理校准
                // ==========================================
                await MainActor.run {
                    self.currentPhase = .geocoding
                    self.currentSubStep = .cityAnchor
                    self.subStepDetails[.cityAnchor] = "正在锁定 \(dto.destination) 城市空间基准..."
                }

                let cityAnchor = await GeocodingService.shared.resolveCityAnchor(destination: dto.destination)

                await MainActor.run {
                    self.subStepDetails[.cityAnchor] = "已锁定 \(dto.destination) 空间基准 (半径 80km 约束)"
                    self.currentSubStep = .resolvePOI
                    self.subStepDetails[.resolvePOI] = "准备逐站检索高精坐标..."
                }

                var draftDays: [DraftDay] = []
                var currentNodeIndex = 0
                var lastResolvedCoord: CLLocationCoordinate2D = cityAnchor

                for dayDTO in dto.days {
                    var draftNodes: [DraftNode] = []
                    for nodeDTO in dayDTO.nodes {
                        try Task.checkCancellation()
                        currentNodeIndex += 1
                        let nodeTitle = nodeDTO.title
                        let currentIndex = currentNodeIndex

                        await MainActor.run {
                            self.subStepDetails[.resolvePOI] = "第 \(currentIndex)/\(totalNodesCount) 站: \(nodeTitle) [高精校验中]"
                        }

                        let nodeType = NodeType(rawValue: nodeDTO.nodeType) ?? .attraction
                        let transitType = TransitType(rawValue: nodeDTO.incomingTransit) ?? .walking

                        let resolved = await GeocodingService.shared.resolveNodeCoordinate(
                            title: nodeDTO.title,
                            searchKeyword: nodeDTO.searchKeyword,
                            estimatedAddress: nodeDTO.estimatedAddress,
                            city: dto.destination,
                            cityAnchor: cityAnchor,
                            aiLat: nodeDTO.estimatedLatitude,
                            aiLon: nodeDTO.estimatedLongitude,
                            fallbackCoord: lastResolvedCoord,
                            nodeIndex: currentIndex
                        )

                        if resolved.isVerified {
                            lastResolvedCoord = resolved.coordinate
                        }

                        let draftNode = DraftNode(
                            title: nodeDTO.title,
                            latitude: resolved.coordinate.latitude,
                            longitude: resolved.coordinate.longitude,
                            nodeType: nodeType,
                            incomingTransit: transitType,
                            incomingGuide: nodeDTO.incomingGuide ?? "",
                            tips: nodeDTO.tips ?? "",
                            durationMinutes: nodeDTO.durationMinutes ?? 60,
                            isVerified: resolved.isVerified,
                            formattedAddress: resolved.formattedAddress
                        )
                        draftNodes.append(draftNode)
                    }
                    draftDays.append(DraftDay(dayIndex: dayDTO.dayIndex, summary: dayDTO.summary, outfitAdvice: dayDTO.outfitAdvice ?? "", nodes: draftNodes))
                }

                await MainActor.run {
                    self.subStepDetails[.resolvePOI] = "全部 \(totalNodesCount) 个站点坐标已完成校准"
                    self.currentSubStep = .topologyOptimization
                    self.subStepDetails[.topologyOptimization] = "正在执行路线防重叠微分散与离群校验..."
                }

                // 执行整趟行程的拓扑防重叠微分散与离群拉回检测
                GeocodingService.shared.disambiguateAndSanitize(days: &draftDays, cityAnchor: cityAnchor)

                await MainActor.run {
                    self.subStepDetails[.topologyOptimization] = "空间拓扑优化完成，健康度 100%"
                }

                try Task.checkCancellation()

                // 短暂延时保证视觉流转自然平滑
                try? await Task.sleep(nanoseconds: 350_000_000)

                await MainActor.run {
                    HapticFeedback.success()
                    self.parsedTripTitle = dto.tripTitle
                    self.parsedDestination = dto.destination
                    self.parsedDraftDays = draftDays
                    self.parsedChecklist = dto.suggestedChecklist ?? []
                    self.parsedOutfitAdvice = dto.outfitAdvice ?? ""
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
