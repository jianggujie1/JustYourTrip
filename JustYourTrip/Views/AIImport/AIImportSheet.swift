import SwiftUI
import CoreLocation

/// 小红书/社媒攻略 AI 导入浮层
struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var currentStepMessage: String = ""
    @State private var errorMessage: String?
    
    // 解析成功后的草稿数据
    @State private var parsedDraftDays: [DraftDay] = []
    @State private var parsedTripTitle: String = ""
    @State private var parsedDestination: String = ""
    @State private var parsedChecklist: [String] = []
    @State private var navigateToCalibration: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 顶部说明卡片
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.royalPurple)
                        Text("端侧无感智能提取")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("直接粘贴小红书笔记文案、游记攻略或短链接（如 xhslink.com/...）。端侧将自动嗅探正文并调用大模型提取结构化多模态路线。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .glassCard(cornerRadius: 18)
                .padding(.horizontal, 16)
                
                // 输入框区域
                VStack(alignment: .trailing, spacing: 8) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 140)
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
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
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
                
                // 处理中进度指示
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.indigoPrimary)
                        Text(currentStepMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .glassCard(cornerRadius: 16)
                }
                
                // 错误提示
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
                
                // 底部开始解析按钮
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
                    .shadow(color: AppTheme.indigoPrimary.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .navigationTitle("AI 攻略导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "key.fill")
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
    
    // MARK: - 业务逻辑
    
    private func checkClipboard() {
        if let string = UIPasteboard.general.string, !string.isEmpty {
            inputText = string
        }
    }
    
    private func startParsing() {
        guard SettingsManager.shared.isApiKeyConfigured else {
            errorMessage = "尚未配置 AI API Key，请点击右上角钥匙图标进行配置"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                var contentToParse = inputText
                
                // 步骤 1：检测是否为链接，若是则尝试端侧无头抓取
                if let url = WebSnifferService.extractURL(from: inputText) {
                    await MainActor.run {
                        currentStepMessage = "正在无头载入链接，嗅探笔记富文本..."
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
                    currentStepMessage = "大模型正在思考并提取多模态行程路线..."
                }
                let dto = try await LLMParserService.shared.parseTrip(from: contentToParse)
                
                // 步骤 3：原生地理编码反查所有节点坐标
                await MainActor.run {
                    currentStepMessage = "正在智能校准各个站点的经纬度坐标..."
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
