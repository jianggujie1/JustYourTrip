import Foundation
import SwiftData

/// 行程总体计划
@Model
final class TripPlan {
    var id: UUID = UUID()
    var title: String = ""
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var coverImageData: Data?
    var notes: String = ""
    var createdAt: Date = Date()
    
    // 关系：每日安排 (一对多，级联删除)
    @Relationship(deleteRule: .cascade, inverse: \TripDay.trip)
    var days: [TripDay] = []
    
    // 关系：行程专属行前清单
    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.trip)
    var checklistItems: [ChecklistItem] = []

    init(
        title: String,
        destination: String,
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(86400 * 2),
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = Date()
    }
    
    /// 统计节点总数
    var totalNodesCount: Int {
        days.reduce(0) { $0 + $1.nodes.count }
    }
    
    /// 统计已打卡节点数
    var visitedNodesCount: Int {
        days.reduce(0) { $0 + $1.nodes.filter(\.isVisited).count }
    }
    
    /// 行程完成度 (0.0 - 1.0)
    var progress: Double {
        guard totalNodesCount > 0 else { return 0 }
        return Double(visitedNodesCount) / Double(totalNodesCount)
    }
}
