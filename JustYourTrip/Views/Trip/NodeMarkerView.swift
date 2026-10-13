import SwiftUI

/// 地图上的节点自定义图钉标记 (空间徽章、序号标、自适应紧凑模式与高性能图层栅格化)
struct NodeMarkerView: View {
    let node: RouteNode
    var index: Int? = nil
    var indexText: String? = nil
    var dayColor: Color? = nil
    let isSelected: Bool
    var showTitle: Bool = true
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // 选中时的环境双层光环
                if isSelected {
                    Circle()
                        .fill(markerColor.opacity(0.25))
                        .frame(width: 54, height: 54)
                        .blur(radius: 4)
                    
                    Circle()
                        .stroke(markerColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                }
                
                // 图钉主圆盘 (带微渐变)
                Circle()
                    .fill(markerGradient)
                    .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 2.5 : 2)
                    )
                    .shadow(color: isSelected ? markerColor.opacity(0.4) : Color.black.opacity(0.12), radius: isSelected ? 6 : 2, x: 0, y: isSelected ? 2 : 1)
                
                // 内部类型图标
                Image(systemName: node.nodeType.systemIcon)
                    .font(.system(size: isSelected ? 15 : 12, weight: .bold))
                    .foregroundStyle(.white)
                
                // 左上角数字序号/天数标识角标
                let badgeText = indexText ?? index.map { "\($0)" }
                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: badge.count > 2 ? 8 : 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? (dayColor ?? markerColor) : Color.white)
                        .frame(minWidth: 16)
                        .frame(height: 16)
                        .padding(.horizontal, badge.count > 2 ? 3 : 0)
                        .background(isSelected ? Color.white : (dayColor ?? AppTheme.forestDeep))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        )
                        .offset(x: isSelected ? -13 : -11, y: isSelected ? -13 : -11)
                }
                
                // 打卡成功右下角微角标
                if node.isVisited {
                    Circle()
                        .fill(AppTheme.sageMint)
                        .frame(width: 15, height: 15)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 7.5, weight: .black))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.2)
                        )
                        .offset(x: isSelected ? 13 : 11, y: isSelected ? 13 : 11)
                }
            }
            
            // 节点名称标签 (采用硬件加速单层混合，杜绝全景多节点 GPU 离屏模糊拖慢)
            if showTitle {
                HStack(spacing: 4) {
                    if isSelected {
                        Circle()
                            .fill(markerColor)
                            .frame(width: 5, height: 5)
                    }
                    
                    Text(node.title)
                        .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(isSelected ? 0.96 : 0.90))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? markerColor.opacity(0.6) : Color.white.opacity(0.35), lineWidth: isSelected ? 1.2 : 0.8)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 3 : 1.5, x: 0, y: 1)
            }
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .compositingGroup()
    }
    
    private var markerGradient: LinearGradient {
        LinearGradient(
            colors: [markerColor, markerColor.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var markerColor: Color {
        if node.isVisited {
            return AppTheme.sageMint
        }
        if let dayColor = dayColor {
            return dayColor
        }
        switch node.nodeType {
        case .attraction:
            return AppTheme.sunsetCoral
        case .restaurant:
            return AppTheme.warmAmber
        case .hotel:
            return AppTheme.royalPurple
        case .transitBus:
            return AppTheme.skyTeal
        case .transitSub:
            return AppTheme.indigoPrimary
        case .parkingLot:
            return Color.brown
        case .other:
            return Color.cyan
        }
    }
}

