import SwiftUI

/// 地图上的节点自定义图钉标记 (空间毛玻璃与发光徽章)
struct NodeMarkerView: View {
    let node: RouteNode
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 选中时的环境光环晕
                if isSelected {
                    Circle()
                        .fill(markerColor.opacity(0.25))
                        .frame(width: 52, height: 52)
                        .blur(radius: 4)
                }
                
                // 图钉主圆盘
                Circle()
                    .fill(markerColor)
                    .frame(width: isSelected ? 42 : 32, height: isSelected ? 42 : 32)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 2.5 : 2)
                    )
                    .shadow(color: markerColor.opacity(isSelected ? 0.45 : 0.25), radius: isSelected ? 8 : 4, x: 0, y: 3)
                
                Image(systemName: node.nodeType.systemIcon)
                    .font(.system(size: isSelected ? 17 : 13, weight: .bold))
                    .foregroundStyle(.white)
                
                // 打卡成功翡翠绿微角标
                if node.isVisited {
                    Circle()
                        .fill(AppTheme.mintGreen)
                        .frame(width: 15, height: 15)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .offset(x: isSelected ? 15 : 12, y: isSelected ? -15 : -12)
                }
            }
            
            // 节点名称毛玻璃标签
            HStack(spacing: 3) {
                if isSelected {
                    Circle()
                        .fill(markerColor)
                        .frame(width: 5, height: 5)
                }
                
                Text(node.title)
                    .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? markerColor.opacity(0.4) : Color.white.opacity(0.3), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
    }
    
    private var markerColor: Color {
        if node.isVisited {
            return Color.gray.opacity(0.75)
        }
        switch node.nodeType {
        case .attraction:
            return AppTheme.sunsetCoral
        case .restaurant:
            return AppTheme.sunsetGold
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
