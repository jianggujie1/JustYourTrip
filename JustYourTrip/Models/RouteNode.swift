import Foundation
import SwiftData
import CoreLocation

/// 地点节点类型
enum NodeType: String, Codable, CaseIterable, Identifiable {
    case attraction = "attraction"   // 景点
    case restaurant = "restaurant"   // 美食餐饮
    case hotel      = "hotel"        // 住宿酒店
    case transitBus = "transitBus"   // 公交站
    case transitSub = "transitSub"   // 地铁站/出入口
    case parkingLot = "parkingLot"   // 停车场
    case other      = "other"        // 其他自定义
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .attraction: return "景点"
        case .restaurant: return "餐饮"
        case .hotel: return "住宿"
        case .transitBus: return "公交站"
        case .transitSub: return "地铁出入口"
        case .parkingLot: return "停车场"
        case .other: return "其他"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .attraction: return "star.fill"
        case .restaurant: return "fork.knife"
        case .hotel: return "bed.double.fill"
        case .transitBus: return "bus.fill"
        case .transitSub: return "tram.fill"
        case .parkingLot: return "car.circle.fill"
        case .other: return "mappin.and.ellipse"
        }
    }
    
    /// 是否属于纯中转节点（用于足迹大地图智能过滤）
    var isTransitOnly: Bool {
        switch self {
        case .transitBus, .transitSub, .parkingLot:
            return true
        default:
            return false
        }
    }
}

/// 交通连接方式
enum TransitType: String, Codable, CaseIterable, Identifiable {
    case walking = "walking"         // 步行 (虚线)
    case driving = "driving"         // 驾车 (实线)
    case transit = "transit"         // 公共交通/地铁 (粗线/彩色)
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .walking: return "步行"
        case .driving: return "驾车/打车"
        case .transit: return "地铁/公交"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .walking: return "figure.walk"
        case .driving: return "car.fill"
        case .transit: return "tram.fill"
        }
    }
}

/// 行程路线上的节点
@Model
final class RouteNode {
    var id: UUID = UUID()
    var title: String = ""
    var rawAddress: String = ""
    var nodeTypeRaw: String = NodeType.attraction.rawValue
    
    // 经纬度
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    
    // 打卡流转状态机
    var isVisited: Bool = false
    var visitedAt: Date?
    var sortOrder: Int = 0 // 当日次序
    
    // 攻略指南
    var tips: String = ""              // 避坑与注意事项
    var suggestedDurationMinutes: Int = 60
    var userNotes: String = ""         // 用户实际打卡随笔
    
    // 抵达本节点的上一段交通方式与指示说明
    var incomingTransitRaw: String = TransitType.walking.rawValue
    var incomingTransitGuide: String = "" // 例如：“从人民广场乘2号线往浦东机场方向，坐3站至陆家嘴站C口出”
    
    var day: TripDay?

    var coordinate: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var nodeType: NodeType {
        get { NodeType(rawValue: nodeTypeRaw) ?? .attraction }
        set { nodeTypeRaw = newValue.rawValue }
    }
    
    var incomingTransit: TransitType {
        get { TransitType(rawValue: incomingTransitRaw) ?? .walking }
        set { incomingTransitRaw = newValue.rawValue }
    }

    init(
        title: String,
        latitude: Double,
        longitude: Double,
        sortOrder: Int,
        nodeType: NodeType = .attraction,
        incomingTransit: TransitType = .walking,
        incomingTransitGuide: String = "",
        tips: String = "",
        durationMinutes: Int = 60
    ) {
        self.id = UUID()
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
        self.nodeTypeRaw = nodeType.rawValue
        self.incomingTransitRaw = incomingTransit.rawValue
        self.incomingTransitGuide = incomingTransitGuide
        self.tips = tips
        self.suggestedDurationMinutes = durationMinutes
    }
}
