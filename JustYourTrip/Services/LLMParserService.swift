import Foundation

/// AI 结构化输出 DTO 数据模型
struct ParsedTripDTO: Codable {
    struct ParsedDayDTO: Codable {
        let dayIndex: Int
        let summary: String
        let nodes: [ParsedNodeDTO]
    }
    
    struct ParsedNodeDTO: Codable {
        let title: String
        let estimatedAddress: String?
        let nodeType: String // attraction, restaurant, hotel, transitBus, transitSub, parkingLot, other
        let incomingTransit: String // walking, driving, transit
        let incomingGuide: String?
        let tips: String?
        let durationMinutes: Int?
    }
    
    let tripTitle: String
    let destination: String
    let days: [ParsedDayDTO]
    let suggestedChecklist: [String]?
}

/// 直连大模型端侧解析服务 (支持 DeepSeek / OpenAI / Moonshot 等兼容接口)
final class LLMParserService {
    static let shared = LLMParserService()
    
    private init() {}
    
    /// 解析自然语言攻略正文
    func parseTrip(from rawText: String) async throws -> ParsedTripDTO {
        let settings = SettingsManager.shared
        guard settings.isApiKeyConfigured else {
            throw LLMError.missingApiKey
        }
        
        let cleanedBaseURL = settings.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanedBaseURL)/chat/completions") else {
            throw LLMError.invalidEndpoint
        }
        
        let systemPrompt = """
        你是一个资深旅行结构化规划助理。请从用户输入的攻略、游记或笔记文本中，提取出精确的行程规划结构化数据。
        必须严格输出合法的 JSON 格式，不要包含任何 markdown 代码块（如 ```json ），字段定义如下：
        {
          "tripTitle": "行程名称",
          "destination": "目的地城市（如：上海、北京、东京）",
          "days": [
            {
              "dayIndex": 1,
              "summary": "当日概览/主题",
              "nodes": [
                {
                  "title": "地点/站名/口名",
                  "estimatedAddress": "大概地址或所在区域",
                  "nodeType": "attraction | restaurant | hotel | transitBus | transitSub | parkingLot | other",
                  "incomingTransit": "walking | driving | transit",
                  "incomingGuide": "到达此处的交通换乘提示（例如：乘地铁2号线往浦东机场方向，坐3站至陆家嘴站C口出）",
                  "tips": "游玩建议/避坑提醒/预约门票说明",
                  "durationMinutes": 60
                }
              ]
            }
          ],
          "suggestedChecklist": ["特需必备物品1", "特需必备物品2"]
        }
        注意：
        1. 必须识别并保留公交站、地铁出口、停车场等中转节点作为独立 node，并将 nodeType 准确设置为 transitBus、transitSub 或 parkingLot。
        2. 节点间的换乘指示填写在 incomingGuide 中。
        """
        
        let requestBody: [String: Any] = [
            "model": settings.modelName,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": rawText]
            ],
            "temperature": 0.2
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.badServerResponse(statusCode: -1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        struct ChatCompletionResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard var jsonString = completion.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }
        
        // 清理可能误带的 markdown 标记
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
        }
        if jsonString.hasPrefix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.cannotParseJSON
        }
        
        return try JSONDecoder().decode(ParsedTripDTO.self, from: jsonData)
    }
}

enum LLMError: LocalizedError {
    case missingApiKey
    case invalidEndpoint
    case badServerResponse(statusCode: Int)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case cannotParseJSON
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "尚未配置 AI API Key，请在设置中输入后重试。"
        case .invalidEndpoint:
            return "API 地址格式不正确。"
        case .badServerResponse(let code):
            return "服务器响应异常 (HTTP \(code))。"
        case .apiError(let code, let msg):
            return "API 返回错误 (\(code)): \(msg)"
        case .emptyResponse:
            return "模型返回了空内容。"
        case .cannotParseJSON:
            return "无法将模型输出解析为有效结构化 JSON。"
        }
    }
}
