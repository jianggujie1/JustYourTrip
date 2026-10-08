import SwiftUI
import CoreLocation

/// 底部联动抽屉：包含天数选择、竖向时间轴卡片与导航中继触发
struct TripDayTimelineSheet: View {
    @Bindable var trip: TripPlan
    @Binding var selectedDayIndex: Int
    @Binding var selectedNodeId: UUID?
    var onNodeSelected: (RouteNode) -> Void
    var onAddNode: () -> Void
    
    @State private var navigatingNode: RouteNode?
    @State private var showNavigationDialog = false
    
    private var currentDay: TripDay? {
        trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }
    
    private var sortedNodes: [RouteNode] {
        currentDay?.sortedNodes ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部：天数选择横向滚动栏 (胶囊手账风)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })) { day in
                            let isSelected = selectedDayIndex == day.dayIndex
                            Button {
                                HapticFeedback.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedDayIndex = day.dayIndex
                                    selectedNodeId = day.sortedNodes.first?.id
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("第 \(day.dayIndex) 天")
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    Text(day.date.formatted(.dateTime.month().day()))
                                        .font(.system(size: 10))
                                        .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                                )
                                .foregroundStyle(isSelected ? .white : .primary)
                                .shadow(color: isSelected ? AppTheme.indigoPrimary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
                
                Divider()
                    .opacity(0.6)
                
                // 当日概览描述横幅
                if let summary = currentDay?.summary, !summary.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.indigoPrimary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(AppTheme.indigoPrimary.opacity(0.04))
                }
                
                // 竖向时间轴卡片列表
                if sortedNodes.isEmpty {
                    emptyDayView
                } else {
                    nodesListView
                }
            }
            .background(AppTheme.canvasBackground)
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "请选择导航应用",
                isPresented: $showNavigationDialog,
                titleVisibility: .visible
            ) {
                if let target = navigatingNode {
                    let relay = NavigationRelayService.shared
                    ForEach(relay.availableApps) { app in
                        Button(app.rawValue) {
                            HapticFeedback.light()
                            relay.launchNavigation(
                                to: target.coordinate,
                                destinationName: target.title,
                                mode: target.incomingTransit,
                                app: app
                            )
                        }
                    }
                    Button("取消", role: .cancel) {}
                }
            } message: {
                if let target = navigatingNode {
                    Text("精准导航至：\(target.title)")
                }
            }
        }
    }
    
    // MARK: - 节点列表
    
    private var nodesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(sortedNodes) { node in
                        NodeCardView(
                            node: node,
                            isSelected: selectedNodeId == node.id,
                            onSelect: {
                                selectedNodeId = node.id
                                onNodeSelected(node)
                            },
                            onNavigate: {
                                navigatingNode = node
                                showNavigationDialog = true
                            }
                        )
                        .id(node.id)
                    }
                    
                    // 底部添加节点按钮
                    Button {
                        HapticFeedback.light()
                        onAddNode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("添加新节点")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.indigoPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.indigoPrimary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(.top, 4)
                }
                .padding(18)
            }
            .onChange(of: selectedNodeId) { _, newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - 空状态
    
    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.indigoPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.indigoPrimary)
            }
            Text("今日暂无行程节点")
                .font(.headline)
            Text("点击下方按钮添加今日的景点、车站或餐厅")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("添加今日第一站", action: onAddNode)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.indigoPrimary)
                .controlSize(.regular)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
