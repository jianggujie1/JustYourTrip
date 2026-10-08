import UIKit
import CoreLocation

/// 支持唤起的地图应用枚举
enum MapAppType: String, CaseIterable, Identifiable {
    case apple = "Apple 地图"
    case amap = "高德地图"
    case baidu = "百度地图"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .amap: return "location.north.circle.fill"
        case .baidu: return "map.fill"
        }
    }
    
    var urlSchemeBase: String {
        switch self {
        case .apple: return "maps://"
        case .amap: return "iosamap://"
        case .baidu: return "baidumap://"
        }
    }
    
    @MainActor
    var isInstalled: Bool {
        guard self != .apple else { return true }
        guard let url = URL(string: urlSchemeBase) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

/// 混合导航中继器：根据用户安装情况唤起外部专业地图 App
@MainActor
final class NavigationRelayService {
    static let shared = NavigationRelayService()
    
    private init() {}
    
    /// 获取当前系统可用的外部导航 App 列表
    var availableApps: [MapAppType] {
        MapAppType.allCases.filter { $0 == .apple || $0.isInstalled }
    }
    
    /// 唤起指定外部导航软件
    func launchNavigation(
        to coordinate: CLLocationCoordinate2D,
        destinationName: String,
        mode: TransitType = .walking,
        app: MapAppType
    ) {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let safeName = destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var targetURLString = ""
        
        switch app {
        case .apple:
            let transportMode: String = {
                switch mode {
                case .driving: return "d"
                case .transit: return "r"
                case .walking: return "w"
                }
            }()
            targetURLString = "maps://?daddr=\(lat),\(lon)&dirflg=\(transportMode)&q=\(safeName)"
            
        case .amap:
            let devMode: Int = {
                switch mode {
                case .driving: return 0
                case .transit: return 1
                case .walking: return 2
                }
            }()
            // 高德地图 URL Scheme (dev=0 代表坐标已经是 GCJ-02 火星坐标)
            targetURLString = "iosamap://path?sourceApplication=YourTrip&dlat=\(lat)&dlon=\(lon)&dname=\(safeName)&dev=0&t=\(devMode)"
            
        case .baidu:
            let baiduMode: String = {
                switch mode {
                case .driving: return "driving"
                case .transit: return "transit"
                case .walking: return "walking"
                }
            }()
            // 百度地图通过 coord_type=gcj02 告知传入为 GCJ-02 坐标，百度自动转换
            targetURLString = "baidumap://map/direction?destination=latlng:\(lat),\(lon)|name:\(safeName)&mode=\(baiduMode)&coord_type=gcj02"
        }
        
        guard let url = URL(string: targetURLString) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
