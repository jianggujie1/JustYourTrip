import SwiftUI

/// 地图上的节点自定义图钉标记 (空间毛玻璃与发光徽章、序号标、微动效)
struct NodeMarkerView: View {
    let node: RouteNode
    var index: Int? = nil
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // 选中时的环境双层光环
                if isSelected {
                    Circle()
                        .fill(markerColor.opacity(0.25))
                        .frame(width: 56, height: 56)
                        .blur(radius: 5)
                    
                    Circle()
                        .stroke(markerColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 50, height: 50)
                }
                
                // 图钉主圆盘 (带微渐变)
                Circle()
                    .fill(markerGradient)
                    .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 2.5 : 2)
                    )
                    .shadow(color: markerColor.opacity(isSelected ? 0.45 : 0.25), radius: isSelected ? 8 : 4, x: 0, y: 3)
                
                // 内部类型图标
                Image(systemName: node.nodeType.systemIcon)
                    .font(.system(size: isSelected ? 16 : 13, weight: .bold))
                    .foregroundStyle(.white)
                
                // 左上角数字序号角标
                if let index = index {
                    Text("\(index)")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? markerColor : Color.white)
                        .frame(width: 16, height: 16)
                        .background(isSelected ? Color.white : AppTheme.forestDeep)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        )
                        .offset(x: isSelected ? -14 : -12, y: isSelected ? -14 : -12)
                }
                
                // 打卡成功右下角微角标
                if node.isVisited {
                    Circle()
                        .fill(AppTheme.sageMint)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                        .offset(x: isSelected ? 14 : 12, y: isSelected ? 14 : 12)
                }
            }
            
            // 节点名称毛玻璃标签
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
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? markerColor.opacity(0.6) : Color.white.opacity(0.35), lineWidth: isSelected ? 1.2 : 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
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

