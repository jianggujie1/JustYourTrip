import SwiftUI

/// 行程时间轴中的单个节点卡片 (杂志手账风与多模态流向胶囊)
struct NodeCardView: View {
    @Bindable var node: RouteNode
    let isSelected: Bool
    var onSelect: () -> Void
    var onNavigate: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 上方多模态交通指引胶囊 (如果存在上一段换乘指示)
            if !node.incomingTransitGuide.isEmpty {
                transitGuidanceCapsule
            }
            
            // 节点主信息卡片
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // 打卡流转触感按钮
                    Button {
                        HapticFeedback.success()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            node.isVisited.toggle()
                            node.visitedAt = node.isVisited ? Date() : nil
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(node.isVisited ? AppTheme.mintGreen : Color.secondary.opacity(0.35), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            
                            if node.isVisited {
                                Circle()
                                    .fill(AppTheme.mintGreen)
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                    
                    // 核心内容排版
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(node.title)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .strikethrough(node.isVisited, color: .secondary)
                                .foregroundStyle(node.isVisited ? .secondary : .primary)
                            
                            Spacer()
                            
                            // 停留耗时胶囊
                            if node.suggestedDurationMinutes > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("\(node.suggestedDurationMinutes)m")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.05))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                            }
                        }
                        
                        // 节点类型标签
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
                            
                            if node.isVisited, let visitedAt = node.visitedAt {
                                Text("• 已打卡 \(visitedAt.formatted(.dateTime.hour().minute()))")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.mintGreen)
                            }
                        }
                        
                        // 避坑与攻略 Tips 便签
                        if !node.tips.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Text("💡")
                                    .font(.caption2)
                                Text(node.tips)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .padding(.top, 2)
                        }
                    }
                }
                
                // 卡片底栏：一键精准导航中继
                HStack {
                    Spacer()
                    Button {
                        HapticFeedback.light()
                        onNavigate()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.system(size: 11))
                            Text("精准导航")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.indigoPrimary.opacity(0.1))
                        .foregroundStyle(AppTheme.indigoPrimary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AppTheme.indigoPrimary.opacity(0.04) : AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppTheme.indigoPrimary.opacity(0.4) : Color.primary.opacity(0.04), lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {
                HapticFeedback.selection()
                onSelect()
            }
        }
    }
    
    // MARK: - 多模态交通流动微胶囊
    private var transitGuidanceCapsule: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(transitColor)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: node.incomingTransit.systemIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                )
            
            Text(node.incomingTransitGuide)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(transitColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(transitColor.opacity(0.15), lineWidth: 0.8)
        )
    }
    
    private var typeBadgeColor: Color {
        switch node.nodeType {
        case .attraction: return AppTheme.sunsetCoral
        case .restaurant: return AppTheme.sunsetGold
        case .hotel: return AppTheme.royalPurple
        case .transitBus: return AppTheme.skyTeal
        case .transitSub: return AppTheme.indigoPrimary
        case .parkingLot: return Color.brown
        case .other: return Color.gray
        }
    }
    
    private var transitColor: Color {
        switch node.incomingTransit {
        case .walking: return AppTheme.indigoPrimary
        case .driving: return AppTheme.sunsetCoral
        case .transit: return AppTheme.royalPurple
        }
    }
}
