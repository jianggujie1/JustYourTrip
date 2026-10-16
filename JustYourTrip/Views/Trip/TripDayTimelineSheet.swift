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
    var onTogglePanel: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @State private var navigatingNode: RouteNode?
    @State private var showNavigationDialog = false
    @State private var dragOffset: CGFloat = 0

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    @State private var nodeToDelete: RouteNode?
    @State private var showDeleteConfirmation = false
    @State private var editingNode: RouteNode?
    
    @State private var showReorderSheet = false
    @State private var dayToDelete: TripDay?
    @State private var showDeleteDayAlert = false
    @State private var showEditOutfitSheet = false

    private var isOverviewMode: Bool {
        selectedDayIndex == 0
    }

    private var sortedDays: [TripDay] {
        trip.days.sorted(by: { $0.dayIndex < $1.dayIndex })
    }

    private var currentDay: TripDay? {
        if isOverviewMode {
            return sortedDays.first
        }
        return trip.days.first(where: { $0.dayIndex == selectedDayIndex })
    }

    private var sortedNodes: [RouteNode] {
        if isOverviewMode {
            return sortedDays.flatMap(\.sortedNodes)
        }
        return currentDay?.sortedNodes ?? []
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
                guard !isRegularWidth else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                guard !isRegularWidth else { return }
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
            } else if isOverviewMode {
                overviewNodesListView
                    .frame(maxHeight: .infinity)
            } else {
                nodesListView
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: isRegularWidth ? 410 : nil)
        .frame(maxWidth: isRegularWidth ? nil : .infinity)
        .frame(height: isRegularWidth ? nil : displayedHeight)
        .frame(maxHeight: isRegularWidth ? .infinity : nil)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                AppTheme.canvasBackground
                    .opacity(0.88)
            }
        )
        .clipShape(
            RoundedCornerShape(
                radius: isRegularWidth ? 24 : 26,
                corners: isRegularWidth ? .allCorners : [.topLeft, .topRight]
            )
        )
        .overlay(
            RoundedCornerShape(
                radius: isRegularWidth ? 24 : 26,
                corners: isRegularWidth ? .allCorners : [.topLeft, .topRight]
            )
            .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(isRegularWidth ? 0.16 : 0.12),
            radius: isRegularWidth ? 20 : 18,
            x: isRegularWidth ? 4 : 0,
            y: isRegularWidth ? 4 : -6
        )
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
            let dayText = (node.day?.dayIndex).map { "Day \($0)" } ?? "行程"
            Text("确定从 \(dayText) 中删除「\(node.title)」吗？该操作无法撤销。")
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
        .sheet(isPresented: $showEditOutfitSheet) {
            EditOutfitAdviceSheet(trip: trip, day: isOverviewMode ? nil : currentDay)
        }
    }

    // MARK: - 抽屉头部交互区
    private var headerSection: some View {
        VStack(spacing: 0) {
            // 1. 顶部小抓手 (iPhone 上显示拖拽手势胶囊；iPad 上显示呼吸边距)
            if !isRegularWidth {
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
            } else {
                Spacer()
                    .frame(height: 14)
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

                // 抽屉展开/收起辅助切换按键 (iPhone 抽屉；iPad 侧面板收起)
                if !isRegularWidth {
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
                } else if let onToggle = onTogglePanel {
                    Button {
                        HapticFeedback.light()
                        onToggle()
                    } label: {
                        Image(systemName: "sidebar.leading")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.forestPrimary)
                            .frame(width: 28, height: 28)
                            .background(AppTheme.forestPrimary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .ipadHoverEffect()
                }

                // 调序操作按钮 (单日模式且多于1站时允许快捷调序)
                if !isOverviewMode && sortedNodes.count > 1 {
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

                // 穿衣指南/穿搭建议按键
                Button {
                    HapticFeedback.light()
                    showEditOutfitSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("穿搭")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.sageMint.opacity(0.12))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

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
                // 1. 全景总览入口胶囊 (selectedDayIndex == 0)
                let isOverviewSelected = selectedDayIndex == 0
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        selectedDayIndex = 0
                        selectedNodeId = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 11, weight: .bold))

                        Text("全景总览")
                            .font(.system(size: 13, weight: isOverviewSelected ? .bold : .semibold, design: .rounded))

                        Text("\(trip.days.count)天")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(isOverviewSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isOverviewSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                    )
                    .foregroundStyle(isOverviewSelected ? .white : .primary)
                    .shadow(color: isOverviewSelected ? AppTheme.sageMint.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)

                // 2. 每日胶囊
                ForEach(sortedDays) { day in
                    let isSelected = selectedDayIndex == day.dayIndex
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedDayIndex = day.dayIndex
                            selectedNodeId = day.sortedNodes.first?.id
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isSelected ? Color.white : AppTheme.dayColor(for: day.dayIndex))
                                .frame(width: 6, height: 6)

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

                // 3. 快捷增加天数胶囊
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

    // MARK: - 当日/全景概览横幅
    private var daySummaryBanner: some View {
        VStack(spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                if isOverviewMode {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.sageMint)

                    Text("全景总览 · 全程共 \(trip.days.count) 天 \(trip.totalNodesCount) 站")
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Spacer()

                    if trip.totalNodesCount > 0 {
                        Text("\(trip.visitedNodesCount)/\(trip.totalNodesCount) 已打卡 (\(Int(trip.progress * 100))%)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                } else {
                    Image(systemName: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.dayColor(for: selectedDayIndex))

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
                        Text("\(day.visitedNodesCount)/\(day.nodes.count) (\(Int(day.progress * 100))%)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                }
            }

            // 细长进度条
            let progressValue = isOverviewMode ? trip.progress : (currentDay?.progress ?? 0)
            let hasNodes = isOverviewMode ? (trip.totalNodesCount > 0) : ((currentDay?.nodes.count ?? 0) > 0)
            if hasNodes {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 3)

                        Capsule()
                            .fill(AppTheme.mintGradient)
                            .frame(width: geo.size.width * CGFloat(progressValue), height: 3)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressValue)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AppTheme.forestPrimary.opacity(0.04))
    }

    // MARK: - 单日专注节点列表
    private var nodesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // 当日穿衣搭配指南卡片
                    OutfitAdviceCardView(trip: trip, day: currentDay) {
                        showEditOutfitSheet = true
                    }
                    .padding(.bottom, 2)

                    // 前日承接提示 (当非第一天时展示)
                    if selectedDayIndex > 1, let prevDay = trip.days.first(where: { $0.dayIndex == selectedDayIndex - 1 }) {
                        previousDayTransitionHint(prevDay: prevDay)
                    }

                    ForEach(Array(sortedNodes.enumerated()), id: \.element.id) { index, node in
                        NodeCardView(
                            node: node,
                            index: index + 1,
                            dayColor: AppTheme.dayColor(for: selectedDayIndex),
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

                    // 次日启程预告 (当非最后一天时展示)
                    if let nextDay = trip.days.first(where: { $0.dayIndex == selectedDayIndex + 1 }) {
                        nextDayTransitionHint(nextDay: nextDay)
                    }
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

    // MARK: - 全景总览多日连续时间轴
    private var overviewNodesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 全程穿衣搭配指南卡片
                    OutfitAdviceCardView(trip: trip, day: nil) {
                        showEditOutfitSheet = true
                    }
                    .padding(.bottom, 2)

                    ForEach(Array(sortedDays.enumerated()), id: \.element.id) { dayIndex, day in
                        // 1. 各天头部卡片 (含 "只看这天" 快捷按键)
                        dayOverviewHeader(day: day)

                        // 2. 当日节点列表
                        if day.nodes.isEmpty {
                            dayOverviewEmptyRow(day: day)
                        } else {
                            ForEach(Array(day.sortedNodes.enumerated()), id: \.element.id) { nodeIdx, node in
                                NodeCardView(
                                    node: node,
                                    index: nodeIdx + 1,
                                    indexText: "D\(day.dayIndex)-\(nodeIdx + 1)",
                                    dayColor: AppTheme.dayColor(for: day.dayIndex),
                                    isFirst: nodeIdx == 0,
                                    isLast: nodeIdx == day.sortedNodes.count - 1,
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
                                    otherDays: trip.days.filter { $0.id != day.id },
                                    onMoveToDay: { targetDay in
                                        moveNodeToDay(node, targetDay: targetDay)
                                    }
                                )
                                .id(node.id)
                            }
                        }

                        // 3. 跨日衔接桥梁卡片 (当存在次日时展示，彻底消除割裂感)
                        if dayIndex < sortedDays.count - 1 {
                            let nextDay = sortedDays[dayIndex + 1]
                            crossDayTransitionCard(from: day, to: nextDay)
                        }
                    }
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
        .simultaneousGesture(
            drawerDetent == .collapsed ? dragGesture : nil
        )
    }

    // MARK: - 全景总览单天头部卡片
    private func dayOverviewHeader(day: TripDay) -> some View {
        let dayColor = AppTheme.dayColor(for: day.dayIndex)
        return HStack(spacing: 8) {
            Circle()
                .fill(dayColor)
                .frame(width: 10, height: 10)

            Text("Day \(day.dayIndex)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(day.date.formatted(.dateTime.month().day().weekday()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            if !day.summary.isEmpty {
                Text("• \(day.summary)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // "只看这天" 快捷切换
            Button {
                HapticFeedback.selection()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    selectedDayIndex = day.dayIndex
                    selectedNodeId = day.sortedNodes.first?.id
                }
            } label: {
                HStack(spacing: 3) {
                    Text("只看这天")
                        .font(.system(size: 11, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(dayColor.opacity(0.12))
                .foregroundStyle(dayColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
    }

    // MARK: - 全景总览单天空列表占位
    private func dayOverviewEmptyRow(day: TripDay) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Day \(day.dayIndex) 暂无安排地点")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                HapticFeedback.light()
                selectedDayIndex = day.dayIndex
                onAddNode()
            } label: {
                Text("+ 加地点")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.forestPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 跨日交接卡片 (连接 Day K 与 Day K+1)
    private func crossDayTransitionCard(from currentDay: TripDay, to nextDay: TripDay) -> some View {
        let fromLastNode = currentDay.sortedNodes.last
        let toFirstNode = nextDay.sortedNodes.first
        let currentColor = AppTheme.dayColor(for: currentDay.dayIndex)
        let nextColor = AppTheme.dayColor(for: nextDay.dayIndex)

        return HStack(spacing: 12) {
            // 左侧跨日连接线
            VStack(spacing: 3) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [currentColor, nextColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.2, height: 32)
                Circle()
                    .fill(nextColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 32)

            // 跨日交接卡片内容
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.royalPurple)

                    Text("夜间休整 · 跨日衔接")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("Day \(currentDay.dayIndex) ➔ Day \(nextDay.dayIndex)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                }

                if let fromNode = fromLastNode, let toNode = toFirstNode {
                    HStack(spacing: 4) {
                        Text(fromNode.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.royalPurple)

                        Text(toNode.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("完成当日安排，准备迎接次日旅程")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [currentColor.opacity(0.35), nextColor.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
                    )
            )
        }
        .padding(.vertical, 2)
    }

    // MARK: - 单日模式前日承接提示
    private func previousDayTransitionHint(prevDay: TripDay) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.warmAmber)

            Text("承接 Day \(prevDay.dayIndex) 旅程")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if let prevLast = prevDay.sortedNodes.last {
                Text("• 上站：\(prevLast.title)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                HapticFeedback.light()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedDayIndex = prevDay.dayIndex
                    selectedNodeId = prevDay.sortedNodes.last?.id
                }
            } label: {
                Text("查看前日")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.forestPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
        .padding(.bottom, 4)
    }

    // MARK: - 单日模式次日启程预告
    private func nextDayTransitionHint(nextDay: TripDay) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedDayIndex = nextDay.dayIndex
                selectedNodeId = nextDay.sortedNodes.first?.id
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.royalPurple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("结束 Day \(selectedDayIndex) · 次日启程预告")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.primary)

                    if let nextFirst = nextDay.sortedNodes.first {
                        Text("次日首站：\(nextFirst.title)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("前往 Day \(nextDay.dayIndex) 规划行程")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("前往 Day \(nextDay.dayIndex)")
                        .font(.system(size: 11, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AppTheme.forestPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.royalPurple.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.leading, 32)
    }

    // MARK: - 节点归属与操作支持
    private func nodeBelongingDay(_ node: RouteNode) -> TripDay? {
        node.day ?? trip.days.first(where: { $0.nodes.contains(where: { $0.id == node.id }) }) ?? currentDay
    }

    // MARK: - 删除节点业务逻辑
    private func deleteNode(_ node: RouteNode) {
        guard let day = nodeBelongingDay(node) else { return }
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
        guard let day = nodeBelongingDay(node) else { return }
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
        guard let day = nodeBelongingDay(node) else { return }
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
        guard let day = nodeBelongingDay(node), day.id != targetDay.id else { return }
        HapticFeedback.success()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if selectedNodeId == node.id {
                selectedNodeId = day.sortedNodes.filter({ $0.id != node.id }).first?.id
            }
            day.nodes.removeAll(where: { $0.id == node.id })
            node.day = targetDay
            node.sortOrder = targetDay.nodes.count
            targetDay.nodes.append(node)
            
            for (idx, n) in day.sortedNodes.enumerated() { n.sortOrder = idx }
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
            OutfitAdviceCardView(trip: trip, day: isOverviewMode ? nil : currentDay) {
                showEditOutfitSheet = true
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.forestPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.sageMint)
            }
            Text(isOverviewMode ? "行程暂无任何地点" : "今日暂无行程节点")
                .font(.headline)
            Text(isOverviewMode ? "点击下方按钮开启你的行程规划" : "点击下方按钮添加今日的景点、车站或餐厅")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(isOverviewMode ? "添加首个地点" : "添加今日第一站", action: onAddNode)
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
