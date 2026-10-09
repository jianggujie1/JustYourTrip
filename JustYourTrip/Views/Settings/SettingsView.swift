import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 系统设置与数据中枢页 (护照风 Header、BYOK API 配置与连通性测试、全量离线 JSON 导入导出)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allTrips: [TripPlan]
    
    @State private var settings = SettingsManager.shared
    
    // 表单状态
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var isKeyVisible: Bool = false
    @State private var filterTransit: Bool = false
    
    // 连通性测试状态
    @State private var isTestingConnectivity: Bool = false
    @State private var connectivityResult: (success: Bool, latencyMs: Int, message: String)?
    
    // 数据备份与导入状态
    @State private var showExportShareSheet: Bool = false
    @State private var exportFileURL: URL?
    @State private var showFileImporter: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showResetMockConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 1. 旅行护照风品牌 Header 卡片
                    passportHeaderCard
                    
                    // MARK: - 2. 大模型配置 (BYOK 自带 Key)
                    llmConfigurationCard
                    
                    // MARK: - 3. 手账数据中心 (离线 JSON 备份与恢复)
                    dataVaultCard
                    
                    // MARK: - 4. 显示与偏好设置
                    preferenceCard
                    
                    // MARK: - 5. 关于与系统信息
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppTheme.canvasBackground.ignoresSafeArea())
            .navigationTitle("设置与偏好")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.forestPrimary)
                }
            }
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showExportShareSheet) {
                if let url = exportFileURL {
                    ShareActivityView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .confirmationDialog("确定重置为演示行程？", isPresented: $showResetMockConfirm, titleVisibility: .visible) {
                Button("重置并写入官方示例", role: .destructive) {
                    resetMockData()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作将追加写入上海经典 Citywalk 示例行程。")
            }
        }
    }
    
    // MARK: - 1. 旅行护照风 Header
    
    private var passportHeaderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JUST YOUR TRIP")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(AppTheme.luminousMint.opacity(0.85))
                        .tracking(1.5)
                    
                    Text("你的旅游 · 旅行手账")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // 护照认证徽章
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.luminousMint)
            }
            
            Text("纯原生本地优先出行助手。数据永存本地设备与您的私有 iCloud，零中心化服务器介入，零数据追踪。")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(3)
            
            // 极客特性药丸条
            HStack(spacing: 8) {
                passportPill(icon: "lock.shield.fill", title: "本地优先")
                passportPill(icon: "icloud.fill", title: "iCloud 同步")
                passportPill(icon: "key.fill", title: "零中转 BYOK")
            }
        }
        .padding(18)
        .background(AppTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: AppTheme.forestPrimary.opacity(0.3), radius: 12, x: 0, y: 5)
    }
    
    private func passportPill(icon: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(.white)
    }
    
    // MARK: - 2. 大模型配置卡片 (BYOK)
    
    private var llmConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.sageMint)
                
                Text("大模型接入配置 (BYOK)")
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                Text("支持 OpenAI 协议")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            // 常用服务商一键预设
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetButton(title: "DeepSeek 官方", baseURL: "https://api.deepseek.com/v1", model: "deepseek-chat")
                    presetButton(title: "OpenAI 官方", baseURL: "https://api.openai.com/v1", model: "gpt-4o")
                    presetButton(title: "月之暗面 Kimi", baseURL: "https://api.moonshot.cn/v1", model: "moonshot-v1-8k")
                    presetButton(title: "硅基流动", baseURL: "https://api.siliconflow.cn/v1", model: "deepseek-ai/DeepSeek-V3")
                }
            }
            
            Divider().opacity(0.6)
            
            // 表单字段
            VStack(spacing: 12) {
                // API Key 输入
                VStack(alignment: .leading, spacing: 5) {
                    Text("API Key (密钥)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        if isKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .font(.system(size: 13, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                                .font(.system(size: 13, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        
                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        
                        if !apiKey.isEmpty {
                            Button {
                                apiKey = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // 接口地址
                VStack(alignment: .leading, spacing: 5) {
                    Text("接口基地址 (Base URL)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("https://api.deepseek.com/v1", text: $baseURL)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // 模型名称
                VStack(alignment: .leading, spacing: 5) {
                    Text("模型代号 (Model)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextField("deepseek-chat", text: $modelName)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            
            // 连通性测试操作与结果指示
            VStack(spacing: 8) {
                Button {
                    testConnectivity()
                } label: {
                    HStack(spacing: 6) {
                        if isTestingConnectivity {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在连接服务器...")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 14))
                            Text("测试网络与密钥连通性")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(AppTheme.forestPrimary.opacity(0.1))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .disabled(isTestingConnectivity || baseURL.isEmpty)
                
                if let result = connectivityResult {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(result.success ? AppTheme.sageMint : AppTheme.sunsetCoral)
                        
                        Text(result.message)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(result.success ? AppTheme.sageMint : AppTheme.sunsetCoral)
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((result.success ? AppTheme.sageMint : AppTheme.sunsetCoral).opacity(0.08))
                    )
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func presetButton(title: String, baseURL: String, model: String) -> some View {
        Button {
            HapticFeedback.light()
            self.baseURL = baseURL
            self.modelName = model
            self.connectivityResult = nil
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(self.baseURL == baseURL ? AppTheme.forestPrimary.opacity(0.12) : Color(uiColor: .tertiarySystemFill))
                .foregroundStyle(self.baseURL == baseURL ? AppTheme.forestPrimary : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(self.baseURL == baseURL ? AppTheme.sageMint.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. 手账数据中心 (离线 JSON 导入与导出)
    
    private var dataVaultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.warmAmber)
                
                Text("手账数据管理与离线备份")
                    .font(.system(size: 15, weight: .bold))
                
                Spacer()
                
                Text("共 \(allTrips.count) 个行程")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            
            Text("支持将所有旅行路线、每日行程、经纬度与打包清单完整导出为标准 JSON 格式，便于换机迁移、无网归档或离线分享。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(2)
            
            Divider().opacity(0.6)
            
            VStack(spacing: 10) {
                // 导出按钮
                Button {
                    exportTrips()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                        Text("导出全量行程备份 (.json)")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // 导入按钮
                Button {
                    HapticFeedback.light()
                    showFileImporter = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                        Text("从 JSON 备份文件恢复导入")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                
                // 重置/写入示例数据
                Button {
                    HapticFeedback.light()
                    showResetMockConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.sageMint)
                        Text("重新写入上海经典 Citywalk 示例")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - 4. 显示与偏好设置
    
    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("地图偏好")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            
            Toggle(isOn: $filterTransit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("足迹大地图隐藏纯中转站")
                        .font(.system(size: 14, weight: .medium))
                    Text("开启后，地铁出入口和公交站点将自动从全局回忆足迹中过滤")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.sageMint)
            .onChange(of: filterTransit) { _, newValue in
                settings.filterTransitInFootprint = newValue
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - 5. 关于与系统信息
    
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关于 你的旅游 (JustYourTrip)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                infoRow(label: "应用版本", value: "1.0.0 (Build 1)")
                infoRow(label: "核心架构", value: "Swift 6 · SwiftUI · SwiftData")
                infoRow(label: "多端接力", value: "支持 Handoff 与无缝本地导出")
                infoRow(label: "开发者团队", value: "顾杰 蒋 (JTQCQL8MVH)")
            }
            .padding(12)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - 操作逻辑
    
    private func loadSettings() {
        apiKey = settings.apiKey
        baseURL = settings.baseURL
        modelName = settings.modelName
        filterTransit = settings.filterTransitInFootprint
    }
    
    private func saveSettings() {
        HapticFeedback.success()
        settings.apiKey = apiKey
        settings.baseURL = baseURL
        settings.modelName = modelName
        settings.filterTransitInFootprint = filterTransit
    }
    
    private func testConnectivity() {
        HapticFeedback.light()
        isTestingConnectivity = true
        connectivityResult = nil
        
        Task {
            let result = await TripBackupService.shared.testAPIConnectivity(baseURL: baseURL, apiKey: apiKey)
            await MainActor.run {
                isTestingConnectivity = false
                connectivityResult = result
                if result.success {
                    HapticFeedback.success()
                } else {
                    HapticFeedback.warning()
                }
            }
        }
    }
    
    private func exportTrips() {
        HapticFeedback.light()
        do {
            let url = try TripBackupService.shared.exportAllTrips(from: modelContext)
            exportFileURL = url
            showExportShareSheet = true
        } catch {
            alertMessage = "导出失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }
            do {
                let count = try TripBackupService.shared.importTrips(from: fileURL, into: modelContext)
                HapticFeedback.success()
                alertMessage = "成功恢复导入 \(count) 个行程！"
                showAlert = true
            } catch {
                HapticFeedback.warning()
                alertMessage = "导入失败: \(error.localizedDescription)"
                showAlert = true
            }
        case .failure(let error):
            HapticFeedback.warning()
            alertMessage = "选择文件失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func resetMockData() {
        HapticFeedback.success()
        _ = MockData.createSampleTrip(in: modelContext)
        alertMessage = "已成功添加上海经典 Citywalk 示例行程！"
        showAlert = true
    }
}

// MARK: - 系统分享面板 UIViewControllerRepresentable

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
