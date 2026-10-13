import Foundation
import SwiftUI

/// 用户本地设置管理 (BYOK 模型参数、Keychain 硬件级加密 API Key、偏好设置持久化)
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    // 持久化存储键
    private let kApiKey = "App_BYOK_ApiKey"
    private let kBaseURL = "App_BYOK_BaseURL"
    private let kModelName = "App_BYOK_ModelName"
    private let kFilterTransitFootprint = "App_FilterTransitFootprint"
    
    /// 大模型 API Key (使用 iOS Keychain 硬件级 AES-256 加密存储，拒绝 UserDefaults 明文暴露)
    var apiKey: String {
        didSet {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainHelper.delete(key: kApiKey)
            } else {
                KeychainHelper.save(key: kApiKey, value: trimmed)
            }
            // 确保旧版 UserDefaults 中不再残留任何明文 Key
            if UserDefaults.standard.object(forKey: kApiKey) != nil {
                UserDefaults.standard.removeObject(forKey: kApiKey)
            }
        }
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
        // 1. 优先从硬件加密 Keychain 中读取 API Key
        let secureKey = KeychainHelper.read(key: kApiKey)
        
        if let key = secureKey, !key.isEmpty {
            self.apiKey = key
            // 若历史版本曾在 UserDefaults 中遗留过明文，主动彻底抹除
            if UserDefaults.standard.object(forKey: kApiKey) != nil {
                UserDefaults.standard.removeObject(forKey: kApiKey)
            }
        } else if let legacyKey = UserDefaults.standard.string(forKey: kApiKey), !legacyKey.isEmpty {
            // 2. 平滑自动迁移：检测到旧版明文存储，迁移入 Keychain 并彻底删除明文
            self.apiKey = legacyKey
            KeychainHelper.save(key: kApiKey, value: legacyKey)
            UserDefaults.standard.removeObject(forKey: kApiKey)
        } else {
            self.apiKey = ""
        }
        
        self.baseURL = UserDefaults.standard.string(forKey: kBaseURL) ?? "https://api.deepseek.com/v1"
        self.modelName = UserDefaults.standard.string(forKey: kModelName) ?? "deepseek-chat"
        self.filterTransitInFootprint = UserDefaults.standard.bool(forKey: kFilterTransitFootprint)
    }
    
    /// 是否已配置有效的 API Key
    var isApiKeyConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
