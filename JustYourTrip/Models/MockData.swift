import Foundation
import SwiftData

/// 初始内置演示数据，方便快速预览与首发体验
struct MockData {
    @MainActor
    static func createSampleTrip(in context: ModelContext) -> TripPlan {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today) ?? today
        
        let trip = TripPlan(
            title: "上海·魔都城市建筑与漫步漫游",
            destination: "上海",
            startDate: today,
            endDate: dayAfter,
            notes: "包含经典陆家嘴天际线、外滩历史建筑群、法租界梧桐区漫步与特色轮渡换乘体验。"
        )
        context.insert(trip)
        
        // Day 1
        let day1 = TripDay(dayIndex: 1, date: today, summary: "从人民广场到陆家嘴核心地标群，体验过江交通")
        day1.trip = trip
        context.insert(day1)
        
        let d1n1 = RouteNode(
            title: "人民广场地铁站",
            latitude: 31.2335,
            longitude: 121.4740,
            sortOrder: 0,
            nodeType: .transitSub,
            incomingTransit: .transit,
            incomingTransitGuide: "地铁1/2/8号线交汇枢纽，从19号口出站即达南京路步行街起点",
            tips: "早高峰人流量大，注意随身行李",
            durationMinutes: 15
        )
        d1n1.isVisited = true
        d1n1.visitedAt = today
        d1n1.day = day1
        context.insert(d1n1)
        
        let d1n2 = RouteNode(
            title: "南京路步行街东拓段",
            latitude: 31.2378,
            longitude: 121.4856,
            sortOrder: 1,
            nodeType: .attraction,
            incomingTransit: .walking,
            incomingTransitGuide: "沿南京东路步行街向东直行约10分钟，沿途欣赏近代历史风貌",
            tips: "推荐傍晚华灯初上时游览，夜景极美",
            durationMinutes: 45
        )
        d1n2.isVisited = true
        d1n2.visitedAt = today.addingTimeInterval(1800)
        d1n2.day = day1
        context.insert(d1n2)
        
        let d1n3 = RouteNode(
            title: "金陵东路渡口 (东金线轮渡)",
            latitude: 31.2351,
            longitude: 121.4925,
            sortOrder: 2,
            nodeType: .transitBus,
            incomingTransit: .walking,
            incomingTransitGuide: "步行至金陵东路尽头渡口，刷乘车码2元乘坐东金线过江至东昌路渡口",
            tips: "观赏两岸江景的极佳性价比方式，二层甲板视野开阔",
            durationMinutes: 30
        )
        d1n3.day = day1
        context.insert(d1n3)
        
        let d1n4 = RouteNode(
            title: "陆家嘴中心绿地与三件套",
            latitude: 31.2397,
            longitude: 121.5015,
            sortOrder: 3,
            nodeType: .attraction,
            incomingTransit: .walking,
            incomingTransitGuide: "从东昌路渡口沿世纪大道漫步约12分钟，直达环形世纪天桥",
            tips: "广角镜头拍摄上海中心大厦与环球金融中心最佳机位",
            durationMinutes: 90
        )
        d1n4.day = day1
        context.insert(d1n4)
        
        // Day 2
        let day2 = TripDay(dayIndex: 2, date: tomorrow, summary: "武康路与安福路梧桐区Citywalk，探访历史洋房")
        day2.trip = trip
        context.insert(day2)
        
        let d2n1 = RouteNode(
            title: "交通大学地铁站 7号口",
            latitude: 31.2012,
            longitude: 121.4332,
            sortOrder: 0,
            nodeType: .transitSub,
            incomingTransit: .transit,
            incomingTransitGuide: "乘地铁10/11号线至交通大学站，7号口出即达淮海中路武康路交叉口",
            tips: "建议上午9:30前到达，避开拍照人潮",
            durationMinutes: 10
        )
        d2n1.day = day2
        context.insert(d2n1)
        
        let d2n2 = RouteNode(
            title: "武康大楼",
            latitude: 31.2038,
            longitude: 121.4365,
            sortOrder: 1,
            nodeType: .attraction,
            incomingTransit: .walking,
            incomingTransitGuide: "出站沿淮海中路步行150米即见著名诺曼底公寓（武康大楼）",
            tips: "对面天桥与大坑道斑马线角是经典构图点，过马路务必注意交通安全",
            durationMinutes: 40
        )
        d2n2.day = day2
        context.insert(d2n2)
        
        let d2n3 = RouteNode(
            title: "RAC BAR (安福路店)",
            latitude: 31.2134,
            longitude: 121.4428,
            sortOrder: 2,
            nodeType: .restaurant,
            incomingTransit: .walking,
            incomingTransitGuide: "沿武康路北行转入安福路，步行约800米",
            tips: "法式烘焙与可丽饼特色，周末排队较长，可先领号",
            durationMinutes: 60
        )
        d2n3.day = day2
        context.insert(d2n3)
        
        // 行前清单预设
        let defaultChecklists: [(String, ChecklistCategory, Bool)] = [
            ("身份证 / 护照", .documents, true),
            ("交通乘车码 / 实体卡", .documents, true),
            ("移动电源 (10000mAh+)", .digital, true),
            ("微单相机与备用电池", .digital, false),
            ("降噪耳机", .digital, false),
            ("舒适暴走运动鞋", .clothing, true),
            ("晴雨两用伞", .clothing, true),
            ("晕车/胃肠日常应急药", .medical, true),
            ("便携洗漱旅行装", .toiletries, false)
        ]
        
        for item in defaultChecklists {
            let checklistItem = ChecklistItem(name: item.0, category: item.1, isEssential: item.2)
            checklistItem.trip = trip
            context.insert(checklistItem)
        }
        
        return trip
    }
}
