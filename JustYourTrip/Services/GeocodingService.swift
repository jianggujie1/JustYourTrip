import Foundation
import CoreLocation

/// 地理编码服务：地名反查坐标与周边校准
final class GeocodingService {
    static let shared = GeocodingService()
    private let geocoder = CLGeocoder()
    
    private init() {}
    
    /// 根据地点名称与可选城市反查经纬度坐标
    func geocode(locationName: String, city: String? = nil) async throws -> CLLocationCoordinate2D {
        let cleanName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchString: String
        if let city = city, !city.isEmpty, !cleanName.contains(city) {
            searchString = "\(city) \(cleanName)"
        } else {
            searchString = cleanName
        }
        
        let placemarks = try await geocoder.geocodeAddressString(searchString)
        guard let location = placemarks.first?.location else {
            throw CLError(.geocodeFoundNoResult)
        }
        
        return location.coordinate
    }
    
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
}
