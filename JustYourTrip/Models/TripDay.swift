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
}
