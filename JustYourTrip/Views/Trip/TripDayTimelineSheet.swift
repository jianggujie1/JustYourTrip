import SwiftUI
import CoreLocation
import UIKit
import SwiftData

/// 底部联动抽屉档位定义 (折叠态 / 半屏态 / 展开态)
enum DrawerDetent: CaseIterable, Equatable {
    case collapsed  // 底部紧凑态：最大化地图视野，露头 peek 首站
    case medium     // 半屏中档：地图与日程平衡浏览
    case expanded   // 全屏高档：沉浸式查阅全部节点

    func targetHeight(screenHeight: CGFloat, bottomSafeArea: CGFloat) -> CGFloat {
        let maxAllowed = max(320, screenHeight - 95)
        switch self {
        case .collapsed:
            // 抓手 + 标题操作栏 + 天数胶囊 + 当日概览 + 首站露头 + 底部安全区
            return min(210 + bottomSafeArea, maxAllowed * 0.45)
        case .medium:
            // 约屏幕高度 48%
            return min(max(360, screenHeight * 0.48), maxAllowed * 0.75)
        case .expanded:
            // 顶部留出约 95pt，保证顶部控制岛（返回、全览）常驻可见并可点
            return maxAllowed
        }
    }
}

// MARK: - 自定义顶部圆角 Shape
struct RoundedCornerShape: Shape {
    var radius: CGFloat = 26
    var corners: UIRectCorner = [.topLeft, .topRight]

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

/// 底部联动抽屉：包含天数选择、竖向步进时间轴卡片与导航中继触发
/// 原生内嵌于 TripDetailMapView 视图树内，随父视图一同转场与返回，彻底告别 modal sheet 异步残留问题
struct TripDayTimelineDrawer: View {
    @Bindable var trip: TripPlan
    @Binding var selectedDayIndex: Int
    @Binding var selectedNodeId: UUID?
    @Binding var drawerDetent: DrawerDetent
    var screenHeight: CGFloat
    var bottomSafeArea: CGFloat
    var onNodeSelected: (RouteNode) -> Void
    var onAddNode: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var navigatingNode: RouteNode?
    @State private var showNavigationDialog = false
    @State private var dragOffset: CGFloat = 0

    @State private var nodeToDelete: RouteNode?
    @State private var showDeleteConfirmation = false
    @State private var editingNode: RouteNode?
    
    @State private var showReorderSheet = false
    @State private var dayToDelete: TripDay?
    @State private var showDeleteDayAlert = false

    private var currentDay: TripDay? {
        trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }

    private var sortedNodes: [RouteNode] {
        currentDay?.sortedNodes ?? []
    }

    private var currentTargetHeight: CGFloat {
        drawerDetent.targetHeight(screenHeight: screenHeight, bottomSafeArea: bottomSafeArea)
    }

    private var displayedHeight: CGFloat {
        let h = currentTargetHeight - dragOffset
        let minH = DrawerDetent.collapsed.targetHeight(screenHeight: screenHeight, bottomSafeArea: bottomSafeArea)
        let maxH = DrawerDetent.expanded.targetHeight(screenHeight: screenHeight, bottomSafeArea: bottomSafeArea)
        if h < minH {
            return minH - (minH - h) * 0.25
        } else if h > maxH {
            return maxH + (h - maxH) * 0.25
        } else {
            return h
        }
    }

    // MARK: - 抽屉手势拖拽
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let projectedEndHeight = currentTargetHeight - (translation + velocity * 0.35)

                let detents: [DrawerDetent] = [.collapsed, .medium, .expanded]
                let closest = detents.min(by: {
                    abs($0.targetHeight(screenHeight: screenHeight, bottomSafeArea: bottomSafeArea) - projectedEndHeight) <
                    abs($1.targetHeight(screenHeight: screenHeight, bottomSafeArea: bottomSafeArea) - projectedEndHeight)
                }) ?? .medium

                HapticFeedback.selection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    drawerDetent = closest
                    dragOffset = 0
                }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 抽屉头部交互区 (抓手、标题、加节点、天数横滑栏、当日概览)
            headerSection

            // 竖向步进时间轴卡片列表
            if sortedNodes.isEmpty {
                emptyDayView
                    .frame(maxHeight: .infinity)
            } else {
                nodesListView
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(height: displayedHeight)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                AppTheme.canvasBackground
                    .opacity(0.88)
            }
        )
        .clipShape(
            RoundedCornerShape(radius: 26, corners: [.topLeft, .topRight])
        )
        .overlay(
            RoundedCornerShape(radius: 26, corners: [.topLeft, .topRight])
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: -6)
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
        .confirmationDialog(
            "删除地点",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            presenting: nodeToDelete
        ) { node in
            Button("删除「\(node.title)」", role: .destructive) {
                deleteNode(node)
            }
            Button("取消", role: .cancel) {
                nodeToDelete = nil
            }
        } message: { node in
            Text("确定从 Day \(selectedDayIndex) 中删除「\(node.title)」吗？该操作无法撤销。")
        }
        .sheet(item: $editingNode) { node in
            EditNodeSheet(
                node: node,
                destination: trip.destination,
                allDays: trip.days,
                onDelete: {
                    deleteNode(node)
                }
            )
        }
        .sheet(isPresented: $showReorderSheet) {
            if let day = currentDay {
                ReorderNodesSheet(day: day)
            }
        }
        .confirmationDialog(
            "删除天数日程",
            isPresented: $showDeleteDayAlert,
            titleVisibility: .visible,
            presenting: dayToDelete
        ) { day in
            Button("删除 Day \(day.dayIndex) 及所属地点", role: .destructive) {
                deleteDay(day)
            }
            Button("取消", role: .cancel) {
                dayToDelete = nil
            }
        } message: { day in
            Text("确定从行程中移除 Day \(day.dayIndex) 吗？该天包含的 \(day.nodes.count) 个地点将被一并删除。")
        }
    }

    // MARK: - 抽屉头部交互区
    private var headerSection: some View {
        VStack(spacing: 0) {
            // 1. 顶部小抓手
            Capsule()
                .fill(Color.primary.opacity(0.20))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        switch drawerDetent {
                        case .collapsed:
                            drawerDetent = .medium
                        case .medium:
                            drawerDetent = .expanded
                        case .expanded:
                            drawerDetent = .collapsed
                        }
                    }
                }

            // 2. 行程标题与快捷操作栏
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !trip.destination.isEmpty {
                        Text(trip.destination)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 抽屉展开/收起辅助切换按键
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        drawerDetent = (drawerDetent == .collapsed) ? .medium : .collapsed
                    }
                } label: {
                    Image(systemName: drawerDetent == .collapsed ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // 调序操作按钮 (多于1站时允许快捷调序)
                if sortedNodes.count > 1 {
                    Button {
                        HapticFeedback.light()
                        showReorderSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .bold))
                            Text("调序")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(Color.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // 加节点操作按钮
                Button {
                    HapticFeedback.light()
                    onAddNode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("加节点")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.sageMint.opacity(0.15))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            // 3. 天数横向选择胶囊栏
            daySwitcherBar

            Divider()
                .opacity(0.4)

            // 4. 当日概览统计横幅
            daySummaryBanner
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
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

                            // 当日完成度小徽标
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
                    .contextMenu {
                        if trip.days.count > 1 {
                            Button(role: .destructive) {
                                dayToDelete = day
                                showDeleteDayAlert = true
                            } label: {
                                Label("删除 Day \(day.dayIndex)", systemImage: "trash")
                            }
                        }
                    }
                }

                // 快捷增加天数胶囊
                Button {
                    HapticFeedback.light()
                    addNewDay()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("加一天")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.forestPrimary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    if drawerDetent == .collapsed {
                                        drawerDetent = .medium
                                    }
                                }
                                onNodeSelected(node)
                            },
                            onNavigate: {
                                navigatingNode = node
                                showNavigationDialog = true
                            },
                            onEdit: {
                                editingNode = node
                            },
                            onDelete: {
                                nodeToDelete = node
                                showDeleteConfirmation = true
                            },
                            onMoveUp: {
                                moveNodeUp(node)
                            },
                            onMoveDown: {
                                moveNodeDown(node)
                            },
                            otherDays: trip.days.filter { $0.id != currentDay?.id },
                            onMoveToDay: { targetDay in
                                moveNodeToDay(node, targetDay: targetDay)
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
                .padding(.bottom, bottomSafeArea + 24)
            }
            .onChange(of: selectedNodeId) { _, newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
        // 当折叠态露头时，允许上滑手势直接拉出抽屉
        .simultaneousGesture(
            drawerDetent == .collapsed ? dragGesture : nil
        )
    }

    // MARK: - 删除节点业务逻辑
    private func deleteNode(_ node: RouteNode) {
        guard let day = currentDay else { return }
        HapticFeedback.warning()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let remaining = day.sortedNodes.filter { $0.id != node.id }
            if selectedNodeId == node.id {
                selectedNodeId = remaining.first?.id
            }
            if let idx = day.nodes.firstIndex(where: { $0.id == node.id }) {
                day.nodes.remove(at: idx)
            }
            modelContext.delete(node)
            for (idx, n) in remaining.enumerated() {
                n.sortOrder = idx
            }
            try? modelContext.save()
        }
        nodeToDelete = nil
    }

    // MARK: - 节点排序与移动逻辑
    
    private func moveNodeUp(_ node: RouteNode) {
        guard let day = currentDay else { return }
        let nodes = day.sortedNodes
        guard let idx = nodes.firstIndex(where: { $0.id == node.id }), idx > 0 else { return }
        HapticFeedback.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            let prev = nodes[idx - 1]
            let tempOrder = prev.sortOrder
            prev.sortOrder = node.sortOrder
            node.sortOrder = tempOrder
            try? modelContext.save()
        }
    }
    
    private func moveNodeDown(_ node: RouteNode) {
        guard let day = currentDay else { return }
        let nodes = day.sortedNodes
        guard let idx = nodes.firstIndex(where: { $0.id == node.id }), idx < nodes.count - 1 else { return }
        HapticFeedback.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            let next = nodes[idx + 1]
            let tempOrder = next.sortOrder
            next.sortOrder = node.sortOrder
            node.sortOrder = tempOrder
            try? modelContext.save()
        }
    }
    
    private func moveNodeToDay(_ node: RouteNode, targetDay: TripDay) {
        guard let currentDay = currentDay, currentDay.id != targetDay.id else { return }
        HapticFeedback.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selectedNodeId == node.id {
                selectedNodeId = currentDay.sortedNodes.filter({ $0.id != node.id }).first?.id
            }
            currentDay.nodes.removeAll(where: { $0.id == node.id })
            node.day = targetDay
            node.sortOrder = targetDay.nodes.count
            targetDay.nodes.append(node)
            
            for (idx, n) in currentDay.sortedNodes.enumerated() { n.sortOrder = idx }
            for (idx, n) in targetDay.sortedNodes.enumerated() { n.sortOrder = idx }
            try? modelContext.save()
        }
    }

    // MARK: - 天数增删逻辑
    
    private func addNewDay() {
        let nextIndex = (trip.days.map(\.dayIndex).max() ?? 0) + 1
        let baseDate = trip.days.map(\.date).max() ?? trip.startDate
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: baseDate) ?? Date()
        let newDay = TripDay(dayIndex: nextIndex, date: nextDate, summary: "")
        newDay.trip = trip
        modelContext.insert(newDay)
        trip.days.append(newDay)
        try? modelContext.save()
        HapticFeedback.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedDayIndex = nextIndex
            selectedNodeId = nil
        }
    }
    
    private func deleteDay(_ day: TripDay) {
        guard trip.days.count > 1 else { return }
        HapticFeedback.warning()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let idx = trip.days.firstIndex(where: { $0.id == day.id }) {
                trip.days.remove(at: idx)
            }
            modelContext.delete(day)
            let sorted = trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })
            for (idx, d) in sorted.enumerated() {
                d.dayIndex = idx + 1
            }
            try? modelContext.save()
            if selectedDayIndex == day.dayIndex {
                selectedDayIndex = trip.days.map(\.dayIndex).min() ?? 1
                selectedNodeId = currentDay?.sortedNodes.first?.id
            }
        }
        dayToDelete = nil
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
        .frame(maxWidth: .infinity)
        .padding(.bottom, bottomSafeArea + 16)
    }
}

/// 兼容别名
typealias TripDayTimelineSheet = TripDayTimelineDrawer
