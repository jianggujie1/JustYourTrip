import SwiftUI

/// 历史足迹点选回顾卡片 (旅行明信片与手账手稿风)
struct FootprintCardView: View {
    let node: RouteNode
    var onClose: () -> Void
    var onNavigate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部明信片抬头：邮戳徽标与关闭按钮
            HStack(alignment: .top) {
                // 所属行程与城市微标
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let destination = node.day?.trip?.destination, !destination.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(destination)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(AppTheme.forestPrimary.opacity(0.12))
                            .foregroundStyle(AppTheme.forestPrimary)
                            .clipShape(Capsule())
                        }
                        
                        if let tripTitle = node.day?.trip?.title {
                            Text(tripTitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // 节点主标题
                    Text(node.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // 关闭按钮
                Button {
                    HapticFeedback.light()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 中部：分类徽章与打卡邮戳
            HStack(spacing: 10) {
                // 类型徽章
                HStack(spacing: 4) {
                    Image(systemName: node.nodeType.systemIcon)
                        .font(.system(size: 10))
                    Text(node.nodeType.title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(typeBadgeColor.opacity(0.12))
                .foregroundStyle(typeBadgeColor)
                .clipShape(Capsule())
                
                // 仿复古打卡时间邮戳
                if let visitedDate = node.visitedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.sageMint)
                        Text("打卡于 \(visitedDate.formatted(.dateTime.year().month().day().hour().minute()))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.sageMint.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                Spacer()
            }
            
            // 游记心得或避坑手账便签
            if !node.tips.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text("💭")
                            .font(.system(size: 11))
                        Text("探索随笔与攻略")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.warmAmber)
                    }
                    
                    Text(node.tips)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.orange.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.warmAmber.opacity(0.2), lineWidth: 0.8)
                )
            }
            
            // 底部操作栏：一键精准重游导航
            HStack {
                Spacer()
                Button {
                    HapticFeedback.light()
                    onNavigate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 12))
                        Text("重游导航")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.sageMint.opacity(0.35), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22)
        .padding(.horizontal, 16)
    }
    
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
}
