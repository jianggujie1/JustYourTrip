import SwiftUI
import MapKit
import CoreLocation

/// 路线段渲染模型 (包含贝塞尔采样坐标、防重叠弧线参数、中点航向角与样式)
struct RouteMapSegment: Identifiable {
    let id: String
    let fromNode: RouteNode
    let toNode: RouteNode
    let dayIndex: Int
    let transitType: TransitType
    let color: Color
    let isCrossDay: Bool
    let strokeStyle: StrokeStyle
    let coordinates: [CLLocationCoordinate2D]
    let midCoordinate: CLLocationCoordinate2D
    let bearing: Double
    let distanceMeters: Double
}

/// 原始路段定义 (用于聚合与防重叠分配)
struct RawRouteSegment {
    let id: String
    let fromNode: RouteNode
    let toNode: RouteNode
    let dayIndex: Int
    let transitType: TransitType
    let color: Color
    let isCrossDay: Bool
    let strokeStyle: StrokeStyle
}

/// 两个地点的无序网格键 (用于识别往返或多日程重叠路段)
struct LocationPairKey: Hashable {
    let grid1: String
    let grid2: String

    init(coord1: CLLocationCoordinate2D, coord2: CLLocationCoordinate2D) {
        // 约 15~20 米分辨率网格 (0.0002度)
        let g1 = "\(Int(round(coord1.latitude * 5000))),\(Int(round(coord1.longitude * 5000)))"
        let g2 = "\(Int(round(coord2.latitude * 5000))),\(Int(round(coord2.longitude * 5000)))"
        if g1 <= g2 {
            self.grid1 = g1
            self.grid2 = g2
        } else {
            self.grid1 = g2
            self.grid2 = g1
        }
    }
}

/// 路线弧度与贝塞尔曲线几何计算器
struct RouteArcCalculator {
    /// 计算两点间的二次贝塞尔采样坐标集、中点坐标与切线航向角
    /// - Parameters:
    ///   - start: 起点经纬度
    ///   - end: 终点经纬度
    ///   - curvature: 弧度系数 (正数向行进方向右侧拱起，负数向左侧；0 为直线)
    ///   - sampleCount: 贝塞尔采样点数
    static func calculateArc(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        curvature: Double = 0.10,
        sampleCount: Int = 17
    ) -> (coordinates: [CLLocationCoordinate2D], midCoordinate: CLLocationCoordinate2D, bearing: Double, distanceMeters: Double) {
        let loc1 = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let loc2 = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let distanceMeters = loc1.distance(from: loc2)

        let deltaLat = end.latitude - start.latitude
        let deltaLon = end.longitude - start.longitude

        let avgLatRad = ((start.latitude + end.latitude) / 2.0) * .pi / 180.0
        let cosAvgLat = max(0.001, cos(avgLatRad))

        let dx = deltaLon * cosAvgLat
        let dy = deltaLat
        let length = sqrt(dx * dx + dy * dy)

        // 若两点重合或极近 (小于 5 米)，或无需弧度
        if length < 0.00005 || abs(curvature) < 0.001 {
            let mid = CLLocationCoordinate2D(
                latitude: (start.latitude + end.latitude) / 2.0,
                longitude: (start.longitude + end.longitude) / 2.0
            )
            let rawBearing = atan2(dx, dy) * 180.0 / .pi
            let bearing = rawBearing < 0 ? rawBearing + 360.0 : rawBearing
            return ([start, end], mid, bearing, distanceMeters)
        }

        // 行进方向单位向量与右手单位法向量
        let ux = dx / length
        let uy = dy / length

        // 顺时针旋转 90 度 (右法向量): (nx, ny) = (uy, -ux)
        let nx = uy
        let ny = -ux

        // 控制点偏移距离与经纬度增量
        let offsetDist = curvature * length
        let controlDx = nx * offsetDist
        let controlDy = ny * offsetDist

        let midLat = (start.latitude + end.latitude) / 2.0
        let midLon = (start.longitude + end.longitude) / 2.0

        let controlPoint = CLLocationCoordinate2D(
            latitude: midLat + controlDy,
            longitude: midLon + (controlDx / cosAvgLat)
        )

        // 采样二次贝塞尔曲线点集
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleCount - 1)
            let oneMinusT = 1.0 - t
            let b0 = oneMinusT * oneMinusT
            let b1 = 2.0 * oneMinusT * t
            let b2 = t * t

            let lat = b0 * start.latitude + b1 * controlPoint.latitude + b2 * end.latitude
            let lon = b0 * start.longitude + b1 * controlPoint.longitude + b2 * end.longitude
            coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }

        // 中点坐标 (t = 0.5)
        let midCoord = CLLocationCoordinate2D(
            latitude: 0.25 * start.latitude + 0.5 * controlPoint.latitude + 0.25 * end.latitude,
            longitude: 0.25 * start.longitude + 0.5 * controlPoint.longitude + 0.25 * end.longitude
        )

        // 航向角 (二次贝塞尔顶点切线严格平行于弦向量 dx, dy)
        let rawBearing = atan2(dx, dy) * 180.0 / .pi
        let bearing = rawBearing < 0 ? rawBearing + 360.0 : rawBearing

        return (coords, midCoord, bearing, distanceMeters)
    }

    /// 智能重叠分析与几何生成：针对往返路线与多日重叠路段自动分配互斥弧度
    static func buildNonOverlappingSegments(
        rawSegments: [RawRouteSegment],
        useCurvedRoutes: Bool
    ) -> [RouteMapSegment] {
        // 1. 按起止点空间无序键进行分组
        var grouped: [LocationPairKey: [RawRouteSegment]] = [:]
        for raw in rawSegments {
            let key = LocationPairKey(coord1: raw.fromNode.coordinate, coord2: raw.toNode.coordinate)
            grouped[key, default: []].append(raw)
        }

        var result: [RouteMapSegment] = []
        result.reserveCapacity(rawSegments.count)

        for (key, items) in grouped {
            if items.count == 1 {
                // 单一路段：若开启曲线则施加轻微自然微弧 (0.08)，关闭则为直线 (0.0)
                let raw = items[0]
                let curvature = useCurvedRoutes ? 0.08 : 0.0
                let arc = calculateArc(
                    start: raw.fromNode.coordinate,
                    end: raw.toNode.coordinate,
                    curvature: curvature
                )
                if arc.distanceMeters >= 5 {
                    result.append(
                        RouteMapSegment(
                            id: raw.id,
                            fromNode: raw.fromNode,
                            toNode: raw.toNode,
                            dayIndex: raw.dayIndex,
                            transitType: raw.transitType,
                            color: raw.color,
                            isCrossDay: raw.isCrossDay,
                            strokeStyle: raw.strokeStyle,
                            coordinates: arc.coordinates,
                            midCoordinate: arc.midCoordinate,
                            bearing: arc.bearing,
                            distanceMeters: arc.distanceMeters
                        )
                    )
                }
            } else {
                // 多条路段共存（原路折返或多日重合）
                let refGrid = key.grid1
                func isForward(_ s: RawRouteSegment) -> Bool {
                    let fromGrid = "\(Int(round(s.fromNode.latitude * 5000))),\(Int(round(s.fromNode.longitude * 5000)))"
                    return fromGrid == refGrid
                }

                let forward = items.filter { isForward($0) }
                let backward = items.filter { !isForward($0) }

                if !forward.isEmpty && !backward.isEmpty {
                    // 双向对开 (去程与回程)：双方均向行进方向右侧拱起，自然形成双环分离双轨
                    for (i, raw) in forward.enumerated() {
                        let curvature = useCurvedRoutes ? (0.14 + Double(i) * 0.12) : 0.0
                        let arc = calculateArc(
                            start: raw.fromNode.coordinate,
                            end: raw.toNode.coordinate,
                            curvature: curvature
                        )
                        if arc.distanceMeters >= 5 {
                            result.append(
                                RouteMapSegment(
                                    id: raw.id,
                                    fromNode: raw.fromNode,
                                    toNode: raw.toNode,
                                    dayIndex: raw.dayIndex,
                                    transitType: raw.transitType,
                                    color: raw.color,
                                    isCrossDay: raw.isCrossDay,
                                    strokeStyle: raw.strokeStyle,
                                    coordinates: arc.coordinates,
                                    midCoordinate: arc.midCoordinate,
                                    bearing: arc.bearing,
                                    distanceMeters: arc.distanceMeters
                                )
                            )
                        }
                    }

                    for (j, raw) in backward.enumerated() {
                        let curvature = useCurvedRoutes ? (0.14 + Double(j) * 0.12) : 0.0
                        let arc = calculateArc(
                            start: raw.fromNode.coordinate,
                            end: raw.toNode.coordinate,
                            curvature: curvature
                        )
                        if arc.distanceMeters >= 5 {
                            result.append(
                                RouteMapSegment(
                                    id: raw.id,
                                    fromNode: raw.fromNode,
                                    toNode: raw.toNode,
                                    dayIndex: raw.dayIndex,
                                    transitType: raw.transitType,
                                    color: raw.color,
                                    isCrossDay: raw.isCrossDay,
                                    strokeStyle: raw.strokeStyle,
                                    coordinates: arc.coordinates,
                                    midCoordinate: arc.midCoordinate,
                                    bearing: arc.bearing,
                                    distanceMeters: arc.distanceMeters
                                )
                            )
                        }
                    }
                } else {
                    // 同向多次路段 (如多日均从 A 去 B)：分配递增阶梯弧度，使线条平滑错开
                    for (k, raw) in items.enumerated() {
                        let curvature = useCurvedRoutes ? (0.08 + Double(k) * 0.14) : 0.0
                        let arc = calculateArc(
                            start: raw.fromNode.coordinate,
                            end: raw.toNode.coordinate,
                            curvature: curvature
                        )
                        if arc.distanceMeters >= 5 {
                            result.append(
                                RouteMapSegment(
                                    id: raw.id,
                                    fromNode: raw.fromNode,
                                    toNode: raw.toNode,
                                    dayIndex: raw.dayIndex,
                                    transitType: raw.transitType,
                                    color: raw.color,
                                    isCrossDay: raw.isCrossDay,
                                    strokeStyle: raw.strokeStyle,
                                    coordinates: arc.coordinates,
                                    midCoordinate: arc.midCoordinate,
                                    bearing: arc.bearing,
                                    distanceMeters: arc.distanceMeters
                                )
                            )
                        }
                    }
                }
            }
        }

        return result
    }
}

/// 路线中间的流向箭头微标视图
struct RouteDirectionBadge: View {
    let segment: RouteMapSegment
    let isHighlighted: Bool
    let isDimmed: Bool
    let isOverviewMode: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.up")
                .font(.system(size: isHighlighted ? 10 : 8.5, weight: .black))
                .foregroundStyle(isHighlighted ? Color.white : segment.color)
                .rotationEffect(.degrees(segment.bearing))

            if isOverviewMode && !segment.isCrossDay {
                Text("D\(segment.dayIndex)")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isHighlighted ? Color.white : segment.color)
            }
        }
        .padding(.horizontal, isOverviewMode ? 6 : 5)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(isHighlighted ? segment.color : Color(UIColor.systemBackground).opacity(0.92))
        )
        .overlay(
            Capsule()
                .stroke(isHighlighted ? Color.white : segment.color.opacity(0.55), lineWidth: isHighlighted ? 1.5 : 1.0)
        )
        .shadow(
            color: isHighlighted ? segment.color.opacity(0.4) : Color.black.opacity(0.08),
            radius: isHighlighted ? 4 : 1.5,
            x: 0,
            y: 1
        )
        .opacity(isDimmed ? 0.25 : 1.0)
        .scaleEffect(isHighlighted ? 1.12 : 1.0)
        .compositingGroup()
    }
}
