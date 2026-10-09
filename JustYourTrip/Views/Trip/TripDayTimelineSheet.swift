import SwiftUI
import CoreLocation

/// 底部联动抽屉：包含天数选择、竖向步进时间轴卡片与导航中继触发
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
                // 顶部：天数选择横向胶囊栏 (自然森林色系高光)
                daySwitcherBar
                
                Divider()
                    .opacity(0.5)
                
                // 当日概览统计横幅
                daySummaryBanner
                
                // 竖向步进时间轴卡片列表
                if sortedNodes.isEmpty {
                    emptyDayView
                } else {
                    nodesListView
                }
            }
            .background(AppTheme.canvasBackground)
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        onAddNode()
                    } label: {
                        Label("加节点", systemImage: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                }
            }
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
    
    // MARK: - 天数横向选择栏
    
    private var daySwitcherBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })) { day in
                    let isSelected = selectedDayIndex == day.dayIndex
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedDayIndex = day.dayIndex
                            selectedNodeId = day.sortedNodes.first?.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Day \(day.dayIndex)")
                                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .rounded))
                                
                                Text(day.date.formatted(.dateTime.month().day()))
                                    .font(.system(size: 10))
                                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                            }
                            
                            // 当日完成度小圆环 / 计数胶囊
                            if !day.nodes.isEmpty {
                                Text("\(day.visitedNodesCount)/\(day.nodes.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06))
                                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .shadow(color: isSelected ? AppTheme.sageMint.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - 当日概览横幅
    
    private var daySummaryBanner: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.sageMint)
                
                if let summary = currentDay?.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                } else {
                    Text("Day \(selectedDayIndex) · 今日计划共 \(sortedNodes.count) 站")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 进度比例
                if let day = currentDay, !day.nodes.isEmpty {
                    Text("\(Int(day.progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.sageMint)
                }
            }
            
            // 细长进度条
            if let day = currentDay, !day.nodes.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(AppTheme.mintGradient)
                            .frame(width: geo.size.width * CGFloat(day.progress), height: 3)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: day.progress)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.forestPrimary.opacity(0.04))
    }
    
    // MARK: - 节点列表
    
    private var nodesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                        NodeCardView(
                            node: node,
                            index: index + 1,
                            isFirst: index == 0,
                            isLast: index == sortedNodes.count - 1,
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
                    
                    // 底部添加下一站操作
                    Button {
                        HapticFeedback.light()
                        onAddNode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("添加今日下一站")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardBackground)
                        .foregroundStyle(AppTheme.sageMint)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.sageMint.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)
                    .padding(.leading, 32) // 与左侧轴线对齐
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
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
                    .fill(AppTheme.forestPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.sageMint)
            }
            Text("今日暂无行程节点")
                .font(.headline)
            Text("点击下方按钮添加今日的景点、车站或餐厅")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("添加今日第一站", action: onAddNode)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.forestPrimary)
                .controlSize(.regular)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
