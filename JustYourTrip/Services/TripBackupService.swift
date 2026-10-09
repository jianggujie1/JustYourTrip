import Foundation
import SwiftData

// MARK: - 数据交换 DTO (用于离线 JSON 导入与导出)

struct TripBackupContainer: Codable {
    let version: Int
    let exportDate: Date
    let appName: String
    let trips: [TripPlanDTO]
}

struct TripPlanDTO: Codable {
    let title: String
    let destination: String
    let startDate: Date
    let endDate: Date
    let notes: String
    let vibeTags: [String]
    let days: [TripDayDTO]
    let checklistItems: [ChecklistItemDTO]
}

struct TripDayDTO: Codable {
    let dayIndex: Int
    let date: Date
    let summary: String
    let nodes: [RouteNodeDTO]
}

struct RouteNodeDTO: Codable {
    let title: String
    let latitude: Double
    let longitude: Double
    let sortOrder: Int
    let nodeType: String
    let isVisited: Bool
    let tips: String
    let suggestedDurationMinutes: Int
    let incomingTransit: String
    let incomingTransitGuide: String
}

struct ChecklistItemDTO: Codable {
    let name: String
    let category: String
    let isEssential: Bool
    let isChecked: Bool
    let note: String
}

// MARK: - 行程全量备份服务与模型测试服务

final class TripBackupService {
    static let shared = TripBackupService()
    
    private init() {}
    
    /// 将数据库中所有行程导出为 JSON 临时文件，返回文件路径供系统分享
    @MainActor
    func exportAllTrips(from context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<TripPlan>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let allTrips = try context.fetch(descriptor)
        
        let tripDTOs = allTrips.map { trip -> TripPlanDTO in
            let dayDTOs = trip.days.sorted(by: { $0.dayIndex < $1.dayIndex }).map { day -> TripDayDTO in
                let nodeDTOs = day.sortedNodes.map { node -> RouteNodeDTO in
                    RouteNodeDTO(
                        title: node.title,
                        latitude: node.latitude,
                        longitude: node.longitude,
                        sortOrder: node.sortOrder,
                        nodeType: node.nodeTypeRaw,
                        isVisited: node.isVisited,
                        tips: node.tips,
                        suggestedDurationMinutes: node.suggestedDurationMinutes,
                        incomingTransit: node.incomingTransitRaw,
                        incomingTransitGuide: node.incomingTransitGuide
                    )
                }
                return TripDayDTO(
                    dayIndex: day.dayIndex,
                    date: day.date,
                    summary: day.summary,
                    nodes: nodeDTOs
                )
            }
            
            let checklistDTOs = trip.checklistItems.map { item -> ChecklistItemDTO in
                ChecklistItemDTO(
                    name: item.name,
                    category: item.categoryRaw,
                    isEssential: item.isEssential,
                    isChecked: item.isChecked,
                    note: item.note
                )
            }
            
            return TripPlanDTO(
                title: trip.title,
                destination: trip.destination,
                startDate: trip.startDate,
                endDate: trip.endDate,
                notes: trip.notes,
                vibeTags: trip.vibeTags,
                days: dayDTOs,
                checklistItems: checklistDTOs
            )
        }
        
        let container = TripBackupContainer(
            version: 1,
            exportDate: Date(),
            appName: "JustYourTrip",
            trips: tripDTOs
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(container)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "JustYourTrip_Backup_\(timestamp).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: tempURL)
        
        return tempURL
    }
    
    /// 从外部 JSON 文件恢复导入行程数据
    @MainActor
    func importTrips(from fileURL: URL, into context: ModelContext) throws -> Int {
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let container = try decoder.decode(TripBackupContainer.self, from: data)
        var count = 0
        
        for tripDTO in container.trips {
            let trip = TripPlan(
                title: tripDTO.title,
                destination: tripDTO.destination,
                startDate: tripDTO.startDate,
                endDate: tripDTO.endDate,
                notes: tripDTO.notes,
                vibeTags: tripDTO.vibeTags
            )
            context.insert(trip)
            
            for dayDTO in tripDTO.days {
                let day = TripDay(dayIndex: dayDTO.dayIndex, date: dayDTO.date, summary: dayDTO.summary)
                day.trip = trip
                context.insert(day)
                
                for nodeDTO in dayDTO.nodes {
                    let node = RouteNode(
                        title: nodeDTO.title,
                        latitude: nodeDTO.latitude,
                        longitude: nodeDTO.longitude,
                        sortOrder: nodeDTO.sortOrder,
                        nodeType: NodeType(rawValue: nodeDTO.nodeType) ?? .attraction,
                        incomingTransit: TransitType(rawValue: nodeDTO.incomingTransit) ?? .walking,
                        incomingTransitGuide: nodeDTO.incomingTransitGuide,
                        tips: nodeDTO.tips,
                        durationMinutes: nodeDTO.suggestedDurationMinutes
                    )
                    node.isVisited = nodeDTO.isVisited
                    node.day = day
                    context.insert(node)
                }
            }
            
            for checkDTO in tripDTO.checklistItems {
                let item = ChecklistItem(
                    name: checkDTO.name,
                    category: ChecklistCategory(rawValue: checkDTO.category) ?? .documents,
                    isEssential: checkDTO.isEssential,
                    note: checkDTO.note
                )
                item.isChecked = checkDTO.isChecked
                item.trip = trip
                context.insert(item)
            }
            
            count += 1
        }
        
        try context.save()
        return count
    }
    
    /// 测试大模型接口连通性 (Ping)
    func testAPIConnectivity(baseURL: String, apiKey: String) async -> (success: Bool, latencyMs: Int, message: String) {
        let cleanBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard let url = URL(string: "\(cleanBaseURL)/models") else {
            return (false, 0, "接口地址格式不正确，请检查 URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, elapsed, "未能收到有效的 HTTP 响应")
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return (true, elapsed, "连接成功 (响应延迟 \(elapsed)ms)")
            case 401:
                return (false, elapsed, "鉴权失败 (HTTP 401)：API Key 无效或未授权")
            case 403:
                return (false, elapsed, "访问受限 (HTTP 403)：Key 权限不足或被冻结")
            case 404:
                return (false, elapsed, "地址未找到 (HTTP 404)：请检查 Base URL (通常以 /v1 结尾)")
            case 429:
                return (true, elapsed, "接口通畅但频控 (HTTP 429)：Key 额度耗尽或调用超限")
            default:
                return (false, elapsed, "HTTP 状态码: \(httpResponse.statusCode)")
            }
        } catch let error as URLError {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            switch error.code {
            case .timedOut:
                return (false, elapsed, "请求超时 (超过 8s)，请检查网络状况")
            case .cannotFindHost, .cannotConnectToHost:
                return (false, elapsed, "无法连接到该服务器主机，请检查域名是否正确")
            default:
                return (false, elapsed, "网络错误: \(error.localizedDescription)")
            }
        } catch {
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            return (false, elapsed, "错误: \(error.localizedDescription)")
        }
    }
}
