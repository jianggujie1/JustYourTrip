import SwiftUI

/// 历史足迹点选回顾卡片 (空间毛玻璃与回忆手账微弹窗)
struct FootprintCardView: View {
    let node: RouteNode
    var onClose: () -> Void
    var onNavigate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: node.nodeType.systemIcon)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.sunsetCoral)
                        
                        Text(node.nodeType.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.sunsetCoral)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppTheme.sunsetCoral.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    Text(node.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
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
            
            // 打卡时间与所属行程胶囊
            HStack(spacing: 12) {
                if let visitedDate = node.visitedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                        Text(visitedDate.formatted(.dateTime.year().month().day().hour().minute()))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                if let tripTitle = node.day?.trip?.title {
                    HStack(spacing: 4) {
                        Image(systemName: "airplane")
                            .font(.caption2)
                        Text(tripTitle)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(AppTheme.indigoPrimary)
                }
            }
            
            // 游记随笔或避坑心得
            if !node.tips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💭 探索心得与贴士")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(node.tips)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                            .font(.system(size: 11))
                        Text("导航去这里")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.indigoPrimary.opacity(0.3), radius: 6, x: 0, y: 2)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, 16)
    }
}
