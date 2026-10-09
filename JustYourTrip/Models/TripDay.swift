import Foundation
import SwiftData

/// 某一日程
@Model
final class TripDay {
    var id: UUID = UUID()
    var dayIndex: Int = 1 // 第几天 (Day 1, Day 2...)
    var date: Date = Date()
    var summary: String = ""
    
    var trip: TripPlan?
    
    // 关系：节点顺序列表
    @Relationship(deleteRule: .cascade, inverse: \RouteNode.day)
    var nodes: [RouteNode] = []
    
    init(dayIndex: Int, date: Date, summary: String = "") {
        self.id = UUID()
        self.dayIndex = dayIndex
        self.date = date
        self.summary = summary
    }
    
    /// 按顺序排列的节点列表
    var sortedNodes: [RouteNode] {
        nodes.sorted(by: { $0.sortOrder < $1.sortOrder })
    }
    
    /// 已打卡节点数
    var visitedNodesCount: Int {
        nodes.filter(\.isVisited).count
    }
    
    /// 当日打卡完成比例 (0.0 - 1.0)
    var progress: Double {
        guard !nodes.isEmpty else { return 0 }
        return Double(visitedNodesCount) / Double(nodes.count)
    }
}
