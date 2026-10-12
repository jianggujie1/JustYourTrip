import Foundation

/// AI 结构化输出 DTO 数据模型 (具备高容错解码能力)
struct ParsedTripDTO: Codable {
    struct ParsedDayDTO: Codable {
        var dayIndex: Int
        var summary: String
        var nodes: [ParsedNodeDTO]
        
        enum CodingKeys: String, CodingKey {
            case dayIndex, summary, nodes
        }
        
        init(dayIndex: Int = 1, summary: String = "", nodes: [ParsedNodeDTO] = []) {
            self.dayIndex = dayIndex
            self.summary = summary
            self.nodes = nodes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.dayIndex = (try? container.decode(Int.self, forKey: .dayIndex)) ?? 1
            self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
            self.nodes = (try? container.decode([ParsedNodeDTO].self, forKey: .nodes)) ?? []
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(dayIndex, forKey: .dayIndex)
            try container.encode(summary, forKey: .summary)
            try container.encode(nodes, forKey: .nodes)
        }
    }
    
    struct ParsedNodeDTO: Codable {
        var title: String
        var estimatedAddress: String?
        var nodeType: String // attraction, restaurant, hotel, transitBus, transitSub, parkingLot, other
        var incomingTransit: String // walking, driving, transit
        var incomingGuide: String?
        var tips: String?
        var durationMinutes: Int?
        
        enum CodingKeys: String, CodingKey {
            case title, estimatedAddress, nodeType, incomingTransit, incomingGuide, tips, durationMinutes
        }
        
        init(
            title: String,
            estimatedAddress: String? = nil,
            nodeType: String = "attraction",
            incomingTransit: String = "walking",
            incomingGuide: String? = nil,
            tips: String? = nil,
            durationMinutes: Int? = 60
        ) {
            self.title = title
            self.estimatedAddress = estimatedAddress
            self.nodeType = nodeType
            self.incomingTransit = incomingTransit
            self.incomingGuide = incomingGuide
            self.tips = tips
            self.durationMinutes = durationMinutes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = (try? container.decode(String.self, forKey: .title)) ?? "未知地点"
            self.estimatedAddress = try? container.decodeIfPresent(String.self, forKey: .estimatedAddress)
            self.nodeType = (try? container.decode(String.self, forKey: .nodeType)) ?? "attraction"
            self.incomingTransit = (try? container.decode(String.self, forKey: .incomingTransit)) ?? "walking"
            self.incomingGuide = try? container.decodeIfPresent(String.self, forKey: .incomingGuide)
            self.tips = try? container.decodeIfPresent(String.self, forKey: .tips)
            self.durationMinutes = try? container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(estimatedAddress, forKey: .estimatedAddress)
            try container.encode(nodeType, forKey: .nodeType)
            try container.encode(incomingTransit, forKey: .incomingTransit)
            try container.encodeIfPresent(incomingGuide, forKey: .incomingGuide)
            try container.encodeIfPresent(tips, forKey: .tips)
            try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        }
    }
    
    var tripTitle: String
    var destination: String
    var days: [ParsedDayDTO]
    var suggestedChecklist: [String]?
    
    enum CodingKeys: String, CodingKey {
        case tripTitle, destination, days, suggestedChecklist, title
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let t = try? container.decode(String.self, forKey: .tripTitle) {
            self.tripTitle = t
        } else if let t = try? container.decode(String.self, forKey: .title) {
            self.tripTitle = t
        } else {
            self.tripTitle = "定制旅行路线"
        }
        self.destination = (try? container.decode(String.self, forKey: .destination)) ?? "旅行目的地"
        self.days = (try? container.decode([ParsedDayDTO].self, forKey: .days)) ?? []
        self.suggestedChecklist = try? container.decodeIfPresent([String].self, forKey: .suggestedChecklist)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tripTitle, forKey: .tripTitle)
        try container.encode(destination, forKey: .destination)
        try container.encode(days, forKey: .days)
        try container.encodeIfPresent(suggestedChecklist, forKey: .suggestedChecklist)
    }
}

/// 流式进度更新包
struct StreamProgress: Sendable {
    let chunk: String
    let isReasoning: Bool
    let accumulatedReasoning: String
    let accumulatedContent: String
}

/// 直连大模型端侧解析服务 (支持 SSE 流式传输，兼容 DeepSeek / OpenAI / Kimi / 硅基流动等)
final class LLMParserService: Sendable {
    static let shared = LLMParserService()
    
    private init() {}
    
    /// 流式解析自然语言攻略正文 (就像 AI 实时问答打字机)
    func parseTripStream(
        from rawText: String,
        onProgress: @Sendable @escaping (StreamProgress) -> Void
    ) async throws -> ParsedTripDTO {
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
        必须严格输出合法的 JSON 格式，字段定义如下：
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
        3. 请直接输出符合上述规范的有效 JSON 文本。
        """
        
        var requestBody: [String: Any] = [
            "model": settings.modelName,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": rawText]
            ],
            "temperature": 0.2
        ]
        
        // 针对非 reasoning 模型开启 json_object 模式约束
        let lowerModel = settings.modelName.lowercased()
        if !lowerModel.contains("r1") && !lowerModel.contains("reasoner") {
            requestBody["response_format"] = ["type": "json_object"]
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 180 // 流式保持 180 秒宽限，每个数据块到达都会重置传输倒计时
        
        let (asyncBytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw LLMError.requestTimedOut
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.badServerResponse(statusCode: -1)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in asyncBytes {
                errorData.append(byte)
            }
            let errorText = String(data: errorData, encoding: .utf8) ?? ""
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }
        
        var accumulatedContent = ""
        var accumulatedReasoning = ""
        
        struct StreamChunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable {
                    let content: String?
                    let reasoning_content: String?
                }
                let delta: Delta?
            }
            let choices: [Choice]?
        }
        
        for try await line in asyncBytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }
            
            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" {
                break
            }
            
            guard let payloadData = payload.data(using: .utf8) else { continue }
            
            if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: payloadData),
               let choice = chunk.choices?.first,
               let delta = choice.delta {
                
                if let reasoning = delta.reasoning_content, !reasoning.isEmpty {
                    accumulatedReasoning += reasoning
                    onProgress(StreamProgress(
                        chunk: reasoning,
                        isReasoning: true,
                        accumulatedReasoning: accumulatedReasoning,
                        accumulatedContent: accumulatedContent
                    ))
                }
                
                if let content = delta.content, !content.isEmpty {
                    accumulatedContent += content
                    onProgress(StreamProgress(
                        chunk: content,
                        isReasoning: false,
                        accumulatedReasoning: accumulatedReasoning,
                        accumulatedContent: accumulatedContent
                    ))
                }
            }
        }
        
        guard !accumulatedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.emptyResponse
        }
        
        let jsonString = Self.extractJSONString(from: accumulatedContent)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.cannotParseJSON
        }
        
        do {
            return try JSONDecoder().decode(ParsedTripDTO.self, from: jsonData)
        } catch {
            print("解析 JSON DTO 失败: \(error), 提取的文本: \(jsonString)")
            throw LLMError.cannotParseJSON
        }
    }
    
    /// 向后兼容的非流式直接解析
    func parseTrip(from rawText: String) async throws -> ParsedTripDTO {
        try await parseTripStream(from: rawText) { _ in }
    }
    
    /// 从可能混杂自然语言或 Markdown 代码块的文本中稳健提取 JSON
    static func extractJSONString(from text: String) -> String {
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 如果包含 ```json ... ```，截取块内文本
        if let startRange = cleanText.range(of: "```json") {
            let afterStart = cleanText[startRange.upperBound...]
            if let endRange = afterStart.range(of: "```") {
                return String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cleanText = String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if let startRange = cleanText.range(of: "```") {
            let afterStart = cleanText[startRange.upperBound...]
            if let endRange = afterStart.range(of: "```") {
                return String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cleanText = String(afterStart).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 2. 截取从第一个 '{' 到最后一个 '}'
        if let firstBrace = cleanText.firstIndex(of: "{"),
           let lastBrace = cleanText.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            return String(cleanText[firstBrace...lastBrace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return cleanText
    }
}

enum LLMError: LocalizedError {
    case missingApiKey
    case invalidEndpoint
    case badServerResponse(statusCode: Int)
    case apiError(statusCode: Int, message: String)
    case emptyResponse
    case cannotParseJSON
    case requestTimedOut
    
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
            return "模型返回了空内容，请重试或检查模型状态。"
        case .cannotParseJSON:
            return "无法将模型输出解析为有效结构化路线，建议重试或切换模型。"
        case .requestTimedOut:
            return "模型响应耗时过长已超时，建议检查网络或使用更轻量快速的模型。"
        }
    }
}
