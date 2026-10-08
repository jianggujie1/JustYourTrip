import SwiftUI

/// 系统设置页 (BYOK API Key、模型服务配置与隐私声明)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = SettingsManager.shared
    
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var modelName: String = ""
    @State private var isKeyVisible: Bool = false
    @State private var showSavedToast: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("端侧绝对隐私 · 零中间商")
                                .font(.headline)
                            Text("所有 API Key 仅保存在本机端侧安全存储，请求直连大模型官方服务器，无任何第三方代理。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    HStack {
                        Text("API Key")
                            .frame(width: 80, alignment: .leading)
                        
                        if isKeyVisible {
                            TextField("sk-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-...", text: $apiKey)
                        }
                        
                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("接口地址")
                            .frame(width: 80, alignment: .leading)
                        TextField("例如 https://api.deepseek.com/v1", text: $baseURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    HStack {
                        Text("模型名称")
                            .frame(width: 80, alignment: .leading)
                        TextField("例如 deepseek-chat 或 gpt-4o", text: $modelName)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("大模型配置 (BYOK 自带 Key)")
                } footer: {
                    Text("推荐使用 DeepSeek（超高性价比）或 OpenAI 官方兼容接口。")
                }
                
                Section("推荐预设一键切换") {
                    Button("DeepSeek (官方标准)") {
                        baseURL = "https://api.deepseek.com/v1"
                        modelName = "deepseek-chat"
                    }
                    
                    Button("OpenAI (官方标准)") {
                        baseURL = "https://api.openai.com/v1"
                        modelName = "gpt-4o"
                    }
                    
                    Button("月之暗面 (Kimi / Moonshot)") {
                        baseURL = "https://api.moonshot.cn/v1"
                        modelName = "moonshot-v1-8k"
                    }
                }
                
                Section("关于 你的旅游 (YourTrip)") {
                    HStack {
                        Text("应用定位")
                        Spacer()
                        Text("iOS 原生单机向本地优先")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("数据同步")
                        Spacer()
                        Text("Apple iCloud (CloudKit)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置与偏好")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        settings.apiKey = apiKey
                        settings.baseURL = baseURL
                        settings.modelName = modelName
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = settings.apiKey
                baseURL = settings.baseURL
                modelName = settings.modelName
            }
        }
    }
}
