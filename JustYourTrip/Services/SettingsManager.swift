import Foundation
import SwiftUI

/// 用户本地设置管理 (BYOK 模型参数、API Key、本地持久化)
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    // UserDefaults 键
    private let kApiKey = "App_BYOK_ApiKey"
    private let kBaseURL = "App_BYOK_BaseURL"
    private let kModelName = "App_BYOK_ModelName"
    private let kFilterTransitFootprint = "App_FilterTransitFootprint"
    
    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: kApiKey) }
    }
    
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: kBaseURL) }
    }
    
    var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: kModelName) }
    }
    
    var filterTransitInFootprint: Bool {
        didSet { UserDefaults.standard.set(filterTransitInFootprint, forKey: kFilterTransitFootprint) }
    }

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: kApiKey) ?? ""
        self.baseURL = UserDefaults.standard.string(forKey: kBaseURL) ?? "https://api.deepseek.com/v1"
        self.modelName = UserDefaults.standard.string(forKey: kModelName) ?? "deepseek-chat"
        self.filterTransitInFootprint = UserDefaults.standard.bool(forKey: kFilterTransitFootprint)
    }
    
    /// 是否已配置有效的 API Key
    var isApiKeyConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
