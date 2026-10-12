import Foundation
import CoreLocation
import MapKit

/// 空间坐标解析与纠偏结果
struct ResolvedCoordinateResult {
    let coordinate: CLLocationCoordinate2D
    let isVerified: Bool
    let formattedAddress: String
    let sourceMethod: String // "MKLocalSearch", "CLGeocoder", "AIPrior", "FallbackVicinity"
}

/// 工业级地理编码与空间拓扑校准服务
/// 融合城市基准锚点、高精度 MapKit POI 检索、AI 先验坐标校验、防离群纠偏与防重叠微分散算法
final class GeocodingService {
    static let shared = GeocodingService()
    private let geocoder = CLGeocoder()
    
    // MARK: - 全球主流旅游城市基准锚点库 (保障 0ms 闪电基准，杜绝跨省飞线)
    private static let cityAnchorDatabase: [String: CLLocationCoordinate2D] = [
        // 国内直辖市与主要城市
        "上海": CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737),
        "北京": CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074),
        "成都": CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668),
        "广州": CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644),
        "深圳": CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579),
        "杭州": CLLocationCoordinate2D(latitude: 30.2741, longitude: 120.1551),
        "南京": CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969),
        "武汉": CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055),
        "重庆": CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516),
        "西安": CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398),
        "长沙": CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388),
        "青岛": CLLocationCoordinate2D(latitude: 36.0671, longitude: 120.3826),
        "厦门": CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894),
        "苏州": CLLocationCoordinate2D(latitude: 31.2990, longitude: 120.5853),
        "三亚": CLLocationCoordinate2D(latitude: 18.2528, longitude: 109.5119),
        "海口": CLLocationCoordinate2D(latitude: 20.0440, longitude: 110.3492),
        "黄山": CLLocationCoordinate2D(latitude: 29.7147, longitude: 118.3375),
        "桂林": CLLocationCoordinate2D(latitude: 25.2736, longitude: 110.2902),
        "丽江": CLLocationCoordinate2D(latitude: 26.8721, longitude: 100.2299),
        "大理": CLLocationCoordinate2D(latitude: 25.6065, longitude: 100.2676),
        "昆明": CLLocationCoordinate2D(latitude: 24.8801, longitude: 102.8329),
        "拉萨": CLLocationCoordinate2D(latitude: 29.6525, longitude: 91.1721),
        "乌鲁木齐": CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168),
        "哈尔滨": CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5350),
        "九寨沟": CLLocationCoordinate2D(latitude: 33.2600, longitude: 103.9186),
        "张家界": CLLocationCoordinate2D(latitude: 29.1170, longitude: 110.4792),
        "西宁": CLLocationCoordinate2D(latitude: 36.6232, longitude: 101.7789),
        "银川": CLLocationCoordinate2D(latitude: 38.4872, longitude: 106.2309),
        "呼伦贝尔": CLLocationCoordinate2D(latitude: 49.2116, longitude: 119.7658),
        "香港": CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        "澳门": CLLocationCoordinate2D(latitude: 22.1987, longitude: 113.5439),
        "台北": CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654),
        
        // 海外热门旅游地
        "东京": CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        "大阪": CLLocationCoordinate2D(latitude: 34.6937, longitude: 135.5023),
        "京都": CLLocationCoordinate2D(latitude: 35.0116, longitude: 135.7681),
        "曼谷": CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018),
        "清迈": CLLocationCoordinate2D(latitude: 18.7883, longitude: 98.9853),
        "新加坡": CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
        "巴黎": CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        "伦敦": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        "纽约": CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
        "旧金山": CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        "首尔": CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        "悉尼": CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)
    ]
    
    private init() {}
    
    // MARK: - 1. 目的地城市基准锚点解析
    
    /// 解析目的地的城市中心坐标（优先本地库，兜底网络解析）
    func resolveCityAnchor(destination: String) async -> CLLocationCoordinate2D {
        let cleanCity = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 尝试匹配本地城市表（包含模糊包含判断）
        for (cityName, coord) in Self.cityAnchorDatabase {
            if cleanCity.contains(cityName) || cityName.contains(cleanCity) {
                return coord
            }
        }
        
        // 2. 本地未命中时通过 MKLocalSearch 解析城市中心
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(cleanCity) 市中心"
        let search = MKLocalSearch(request: request)
        if let response = try? await search.start(), let firstItem = response.mapItems.first {
            return firstItem.placemark.coordinate
        }
        
        // 3. 降级 CLGeocoder
        if let placemarks = try? await geocoder.geocodeAddressString(cleanCity),
           let loc = placemarks.first?.location {
            return loc.coordinate
        }
        
        // 4. 极端兜底（全国几何中心附近 / 默认上海）
        return CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
    }
    
    // MARK: - 2. 地理检索地名文本清洗器 (清除口语、动作与换乘修饰)
    
    static func cleanPOIKeyword(title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除前置时间与换乘动词
        let leadingPatterns = [
            #"^(?:早上|中午|下午|傍晚|晚上|夜间)\s*(?:[0-9一二两三四五六七八九十]+点半?|[0-9]+:[0-9]+)?\s*"#,
            #"^(?:步行至|打车前往|乘车前往|坐车前往|打车到|步行到|乘地铁[0-9]+号线(?:坐[0-9]+站)?至|乘公交至|乘公交车至|乘坐|坐地铁至|坐轮渡过江至|轮渡过黄浦江至)\s*"#,
            #"^(?:前往|打卡|游览|逛|参观|漫步|漫游|体验|入住|到达|随后)\s*"#
        ]
        for p in leadingPatterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
            }
        }
        
        // 移除括号内说明及符号
        let bracketPatterns = [
            #"[（(][^）)]*[）)]"#,
            #"[【\[][^】\]]*[】\]]"#
        ]
        for p in bracketPatterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
            }
        }
        
        // 移除后置游玩动作与修饰
        let trailingPatterns = [
            #"(?:打卡|吃Brunch|吃午饭|吃晚饭|喝咖啡|吃特色小吃|看展|拍照极佳|拍照打卡|慢走|停留[0-9]+(?:小时|分钟)?|脚下三件套)$"#,
            #"(?:出)$"#, // 如 "C口出" -> "C口"
            #"[，,。].*$"#
        ]
        for p in trailingPatterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text), withTemplate: "")
            }
        }
        
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? title : cleaned
    }
    
    // MARK: - 3. 多层级混合地理编码与纠偏管道
    
    /// 解析单个节点的经纬度坐标，并执行城市范围约束与离群校验
    func resolveNodeCoordinate(
        title: String,
        searchKeyword: String?,
        estimatedAddress: String?,
        city: String,
        cityAnchor: CLLocationCoordinate2D,
        aiLat: Double?,
        aiLon: Double?,
        fallbackCoord: CLLocationCoordinate2D?,
        nodeIndex: Int
    ) async -> ResolvedCoordinateResult {
        let cityAnchorLocation = CLLocation(latitude: cityAnchor.latitude, longitude: cityAnchor.longitude)
        let maxAllowedRadiusMeters: CLLocationDistance = 120_000 // 允许离城市中心最大 120 公里（覆盖市郊景区如迪士尼、青浦、都江堰、长城等）
        
        // 准备检索关键词候选列
        let cleanTitle = Self.cleanPOIKeyword(title: title)
        var queryCandidates: [String] = []
        if let kw = searchKeyword, !kw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryCandidates.append(kw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if !queryCandidates.contains(cleanTitle) {
            queryCandidates.append(cleanTitle)
        }
        if let addr = estimatedAddress, !addr.isEmpty {
            let combined = "\(cleanTitle) \(addr)"
            if !queryCandidates.contains(combined) {
                queryCandidates.append(combined)
            }
        }
        
        // -------------------------------------------------------------
        // Tier 1: 苹果地图原生 POI 检索 (MKLocalSearch + 城市 Region 约束)
        // -------------------------------------------------------------
        let region = MKCoordinateRegion(center: cityAnchor, latitudinalMeters: 80_000, longitudinalMeters: 80_000)
        for candidate in queryCandidates {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = candidate
            request.region = region
            let localSearch = MKLocalSearch(request: request)
            
            if let response = try? await localSearch.start(), let firstItem = response.mapItems.first {
                let coord = firstItem.placemark.coordinate
                let itemLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let distance = itemLocation.distance(from: cityAnchorLocation)
                
                // 确保结果在城市合理半径范围内，杜绝跨省同名漂移
                if distance <= maxAllowedRadiusMeters {
                    let addr = firstItem.placemark.title ?? firstItem.name ?? ""
                    return ResolvedCoordinateResult(
                        coordinate: coord,
                        isVerified: true,
                        formattedAddress: addr,
                        sourceMethod: "MKLocalSearch"
                    )
                }
            }
        }
        
        // -------------------------------------------------------------
        // Tier 2: CLGeocoder 地址反查 (配合城市前缀与距离校验)
        // -------------------------------------------------------------
        for candidate in queryCandidates {
            let searchString = candidate.contains(city) ? candidate : "\(city) \(candidate)"
            if let placemarks = try? await geocoder.geocodeAddressString(searchString),
               let location = placemarks.first?.location {
                let coord = location.coordinate
                let distance = location.distance(from: cityAnchorLocation)
                
                if distance <= maxAllowedRadiusMeters {
                    let mark = placemarks.first!
                    let addr = [mark.administrativeArea, mark.locality, mark.subLocality, mark.thoroughfare, mark.name]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    return ResolvedCoordinateResult(
                        coordinate: coord,
                        isVerified: true,
                        formattedAddress: addr,
                        sourceMethod: "CLGeocoder"
                    )
                }
            }
        }
        
        // -------------------------------------------------------------
        // Tier 3: AI 大模型先验估算坐标 (仅在符合城市半径时采纳)
        // -------------------------------------------------------------
        if let lat = aiLat, let lon = aiLon, abs(lat) > 0.1 && abs(lon) > 0.1 {
            let aiLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = aiLocation.distance(from: cityAnchorLocation)
            if distance <= 80_000 {
                return ResolvedCoordinateResult(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    isVerified: true,
                    formattedAddress: "AI 先验位置",
                    sourceMethod: "AIPrior"
                )
            }
        }
        
        // -------------------------------------------------------------
        // Tier 4: 本地微分散兜底 (基于前序站点或城市锚点，杜绝几个点堆叠重合)
        // -------------------------------------------------------------
        let anchor = fallbackCoord ?? cityAnchor
        // 计算微分散量 (~300 - 600 米半径)，避免多点完全重合在同一像素
        let angle = Double(nodeIndex) * 1.05
        let radiusDeg = 0.003 + (Double(nodeIndex % 4) * 0.0015)
        let dispersedLat = anchor.latitude + sin(angle) * radiusDeg
        let dispersedLon = anchor.longitude + cos(angle) * radiusDeg
        
        return ResolvedCoordinateResult(
            coordinate: CLLocationCoordinate2D(latitude: dispersedLat, longitude: dispersedLon),
            isVerified: false,
            formattedAddress: "\(city) (待人工校准)",
            sourceMethod: "FallbackVicinity"
        )
    }
    
    // MARK: - 4. 整路线拓扑校验与防重合/离群纠偏 (Post-processing)
    
    /// 对整趟行程的所有草稿节点进行全局拓扑健康度检查：
    /// 1. 消除同日/相近节点的坐标重合现象；
    /// 2. 强制拉回偏离城市中心的离群点。
    func disambiguateAndSanitize(days: inout [DraftDay], cityAnchor: CLLocationCoordinate2D) {
        let cityAnchorLoc = CLLocation(latitude: cityAnchor.latitude, longitude: cityAnchor.longitude)
        let maxRadius: CLLocationDistance = 120_000
        
        for day in days {
            // 1. 离群点拉回检测
            for node in day.nodes {
                let nodeLoc = CLLocation(latitude: node.latitude, longitude: node.longitude)
                if nodeLoc.distance(from: cityAnchorLoc) > maxRadius {
                    // 严重偏离（如几千公里外的外省），拉回至城市中心附近微分散位置
                    node.latitude = cityAnchor.latitude + Double.random(in: -0.015...0.015)
                    node.longitude = cityAnchor.longitude + Double.random(in: -0.015...0.015)
                }
            }
            
            // 2. 节点重合检测与微位移消重 (若两节点距离 < 20 米且标题不同，则施加微分散)
            for i in 0..<day.nodes.count {
                for j in (i + 1)..<day.nodes.count {
                    let nodeA = day.nodes[i]
                    let nodeB = day.nodes[j]
                    
                    let locA = CLLocation(latitude: nodeA.latitude, longitude: nodeA.longitude)
                    let locB = CLLocation(latitude: nodeB.latitude, longitude: nodeB.longitude)
                    
                    if locA.distance(from: locB) < 20.0 && nodeA.title != nodeB.title {
                        // 微调 nodeB 坐标 (~180 米偏移)
                        let offsetDeg = 0.0016
                        nodeB.latitude += offsetDeg * cos(Double(j))
                        nodeB.longitude += offsetDeg * sin(Double(j))
                    }
                }
            }
        }
    }
    
    // MARK: - 5. 人机交互搜索建议 (供 EditDraftNodeSheet 实时搜索重置)
    
    /// 在指定城市区域内实时搜索 POI 候选
    func searchPOISuggestions(query: String, cityAnchor: CLLocationCoordinate2D) async -> [MKMapItem] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleanQuery
        request.region = MKCoordinateRegion(center: cityAnchor, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems
        } catch {
            return []
        }
    }
    
    // MARK: - 6. 逆地理编码
    
    /// 逆地理编码：根据经纬度反查地址描述
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = placemarks.first else { return nil }
            return [mark.administrativeArea, mark.locality, mark.subLocality, mark.thoroughfare, mark.name]
                .compactMap { $0 }
                .joined(separator: " ")
        } catch {
            return nil
        }
    }
    
    // MARK: - 7. 兼容传统地理编码调用 (供 AddNodeSheet 等调用)
    
    /// 根据地点名称与可选城市反查经纬度坐标
    func geocode(locationName: String, city: String? = nil) async throws -> CLLocationCoordinate2D {
        let destinationCity = city ?? "上海"
        let cityAnchor = await resolveCityAnchor(destination: destinationCity)
        let resolved = await resolveNodeCoordinate(
            title: locationName,
            searchKeyword: nil,
            estimatedAddress: nil,
            city: destinationCity,
            cityAnchor: cityAnchor,
            aiLat: nil,
            aiLon: nil,
            fallbackCoord: nil,
            nodeIndex: 0
        )
        if resolved.isVerified {
            return resolved.coordinate
        }
        throw CLError(.geocodeFoundNoResult)
    }
}
