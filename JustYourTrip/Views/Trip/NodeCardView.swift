import SwiftUI

/// 行程竖向时间轴节点行卡片 (左侧贯穿步进轴线 + 右侧富媒体攻略卡片与便签纸)
struct NodeCardView: View {
    @Bindable var node: RouteNode
    var index: Int = 1
    var isFirst: Bool = false
    var isLast: Bool = false
    let isSelected: Bool
    var onSelect: () -> Void
    var onNavigate: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 节点间换乘指引 (当存在上一段交通指引且非首节点时渲染)
            if !isFirst && !node.incomingTransitGuide.isEmpty {
                transitConnectorSection
            }
            
            // 节点主体行 (左侧轴点 + 右侧信息卡片)
            HStack(alignment: .top, spacing: 14) {
                // 左侧时光轴步进柱 (Stepper Column)
                VStack(spacing: 0) {
                    // 节点轴心圆
                    stepperNodeDot
                    
                    // 向下延伸的连接线 (非末尾节点时显示)
                    if !isLast {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [stepperDotColor.opacity(0.6), Color.primary.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2.5)
                            .frame(minHeight: 40)
                            .padding(.top, 4)
                    }
                }
                .frame(width: 32)
                
                // 右侧富媒体攻略卡片
                mainCardContent
            }
        }
    }
    
    // MARK: - 左侧轴心圆 (Stepper Dot)
    
    private var stepperNodeDot: some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(AppTheme.sageMint.opacity(0.4), lineWidth: 4)
                    .frame(width: 34, height: 34)
            }
            
            Circle()
                .fill(stepperDotBackground)
                .frame(width: 26, height: 26)
                .overlay(
                    Circle()
                        .stroke(stepperDotBorder, lineWidth: 1.5)
                )
                .shadow(color: stepperDotColor.opacity(isSelected ? 0.35 : 0.15), radius: 4, x: 0, y: 2)
            
            if node.isVisited {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
            } else {
                Text("\(index)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
            }
        }
        .frame(width: 32, height: 32)
    }
    
    private var stepperDotBackground: AnyShapeStyle {
        if node.isVisited {
            return AnyShapeStyle(AppTheme.sageMint)
        } else if isSelected {
            return AnyShapeStyle(AppTheme.forestPrimary)
        } else {
            return AnyShapeStyle(AppTheme.cardBackground)
        }
    }
    
    private var stepperDotBorder: Color {
        if node.isVisited {
            return .clear
        } else if isSelected {
            return AppTheme.sageMint
        } else {
            return Color.primary.opacity(0.2)
        }
    }
    
    private var stepperDotColor: Color {
        if node.isVisited {
            return AppTheme.sageMint
        } else if isSelected {
            return AppTheme.forestPrimary
        } else {
            return Color.secondary
        }
    }
    
    // MARK: - 右侧主卡片
    
    private var mainCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题与停留时长行
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(node.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .strikethrough(node.isVisited, color: .secondary.opacity(0.7))
                            .foregroundStyle(node.isVisited ? .secondary : .primary)
                        
                        if node.isVisited {
                            Text("已打卡")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.sageMint.opacity(0.15))
                                .foregroundStyle(AppTheme.sageMint)
                                .clipShape(Capsule())
                        }
                    }
                    
                    // 节点分类微标
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: node.nodeType.systemIcon)
                                .font(.system(size: 10))
                            Text(node.nodeType.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(typeBadgeColor.opacity(0.12))
                        .foregroundStyle(typeBadgeColor)
                        .clipShape(Capsule())
                        
                        if let visitedAt = node.visitedAt, node.isVisited {
                            Text("• \(visitedAt.formatted(.dateTime.hour().minute()))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 停留建议时长胶囊
                if node.suggestedDurationMinutes > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(node.suggestedDurationMinutes)m")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.05))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
                }
            }
            
            // 避坑便签卡片 (仿手账贴纸风格)
            if !node.tips.isEmpty {
                tipsStickyNoteView
            }
            
            Divider()
                .opacity(0.4)
                .padding(.vertical, 1)
            
            // 操作栏：打卡开关与一键导航
            HStack {
                // 打卡切换按钮
                Button {
                    HapticFeedback.success()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        node.isVisited.toggle()
                        node.visitedAt = node.isVisited ? Date() : nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: node.isVisited ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(node.isVisited ? AppTheme.sageMint : .secondary)
                        
                        Text(node.isVisited ? "取消打卡" : "标记打卡")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(node.isVisited ? AppTheme.sageMint : .secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 精准导航中继按钮
                Button {
                    HapticFeedback.light()
                    onNavigate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 11))
                        Text("导航前往")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background(AppTheme.indigoPrimary.opacity(0.1))
                    .foregroundStyle(AppTheme.indigoPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? AppTheme.cardBackground : AppTheme.cardBackground.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? AppTheme.sageMint.opacity(0.65) : Color.primary.opacity(0.05),
                    lineWidth: isSelected ? 1.6 : 1
                )
        )
        .shadow(
            color: isSelected ? AppTheme.sageMint.opacity(0.12) : Color.black.opacity(0.04),
            radius: isSelected ? 10 : 5,
            x: 0,
            y: 2
        )
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.selection()
            onSelect()
        }
    }
    
    // MARK: - 避坑便签小组件 (Travel Tip Post-it)
    
    private var tipsStickyNoteView: some View {
        HStack(alignment: .top, spacing: 8) {
            // 便签左侧黄铜/暖金竖指示条
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppTheme.warmAmber)
                .frame(width: 3)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("💡")
                        .font(.system(size: 11))
                    Text("避坑指南与贴士")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.warmAmber)
                }
                
                Text(node.tips)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2.5)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.warmAmber.opacity(0.2), lineWidth: 0.8)
        )
    }
    
    // MARK: - 换乘连接段 (Transit Connector)
    
    private var transitConnectorSection: some View {
        HStack(alignment: .center, spacing: 14) {
            // 左侧虚线段
            VStack {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 2, height: 28)
            }
            .frame(width: 32)
            
            // 右侧换乘提示胶囊
            HStack(spacing: 7) {
                Circle()
                    .fill(transitColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: node.incomingTransit.systemIcon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
                
                Text(node.incomingTransitGuide)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(transitColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(transitColor.opacity(0.15), lineWidth: 0.8)
            )
        }
        .padding(.bottom, 6)
    }
    
    // MARK: - 辅助计算色值
    
    private var typeBadgeColor: Color {
        switch node.nodeType {
        case .attraction: return AppTheme.sunsetCoral
        case .restaurant: return AppTheme.warmAmber
        case .hotel: return AppTheme.royalPurple
        case .transitBus: return AppTheme.skyTeal
        case .transitSub: return AppTheme.indigoPrimary
        case .parkingLot: return Color.brown
        case .other: return Color.gray
        }
    }
    
    private var transitColor: Color {
        switch node.incomingTransit {
        case .walking: return AppTheme.skyTeal
        case .driving: return AppTheme.sunsetCoral
        case .transit: return AppTheme.indigoPrimary
        }
    }
}
