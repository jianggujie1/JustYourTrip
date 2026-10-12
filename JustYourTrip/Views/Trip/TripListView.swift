import SwiftUI
import SwiftData

/// 行程列表首页 (Uix Foysal 概念画册风、多层堆叠卡片与自然森林色系)
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripPlan.startDate, order: .reverse) private var trips: [TripPlan]
    
    @State private var showAddTripSheet = false
    @State private var showAIImportSheet = false
    @State private var showSettingsSheet = false
    @Namespace private var tripTransitionNamespace
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景暖色画布
                AppTheme.canvasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 顶部杂志感 Hero 欢迎与探索栏
                        headerHeroSection
                        
                        if trips.isEmpty {
                            emptyStateView
                        } else {
                            // 优雅自适应行程卡片流 (去除假叠层，间距 18)
                            LazyVStack(spacing: 18) {
                                ForEach(trips) { trip in
                                    NavigationLink(value: trip.id) {
                                        TripCardView(trip: trip)
                                    }
                                    .buttonStyle(BouncyButtonStyle())
                                    .tripZoomTransitionSource(id: trip.id, in: tripTransitionNamespace)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            HapticFeedback.warning()
                                            modelContext.delete(trip)
                                        } label: {
                                            Label("删除行程", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
                }
            }
            .navigationDestination(for: UUID.self) { tripId in
                if let trip = trips.first(where: { $0.id == tripId }) {
                    TripDetailMapView(trip: trip)
                        .tripZoomDestination(id: tripId, in: tripTransitionNamespace)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticFeedback.light()
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            HapticFeedback.medium()
                            showAIImportSheet = true
                        } label: {
                            Label("AI 攻略导入", systemImage: "sparkles")
                        }
                        
                        Button {
                            HapticFeedback.light()
                            showAddTripSheet = true
                        } label: {
                            Label("手动新建行程", systemImage: "plus")
                        }
                        
                        Divider()
                        
                        Button {
                            HapticFeedback.success()
                            _ = MockData.createSampleTrip(in: modelContext)
                        } label: {
                            Label("加载演示样例行程", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppTheme.sageMint)
                    }
                }
            }
            .sheet(isPresented: $showAddTripSheet) {
                AddTripSheet()
            }
            .sheet(isPresented: $showAIImportSheet) {
                AIImportSheet()
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
        }
    }
    
    // MARK: - 顶部欢迎 Hero 区域 (参考 Uix Foysal "Where Will You Go Next?")
    
    private var headerHeroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.sageMint)
                        .frame(width: 7, height: 7)
                    
                    Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 快捷 AI 导入发光微胶囊
                Button {
                    HapticFeedback.medium()
                    showAIImportSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("AI 快速导入")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(AppTheme.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.forestPrimary.opacity(0.35), radius: 6, x: 0, y: 3)
                }
            }
            
            Text("Where Will You\nGo Next?")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineSpacing(2)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.sageMint.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(AppTheme.forestPrimary.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.brandGradient)
            }
            .padding(.top, 28)
            
            VStack(spacing: 8) {
                Text("记录独属于你的每一次漫游")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("本地优先存储 · 零服务器运维 · 跨设备静默互联\n支持小红书/社媒游记一键端侧解析提取")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 12) {
                Button {
                    HapticFeedback.medium()
                    showAIImportSheet = true
                } label: {
                    Label("AI 智能提取新行程", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.forestPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Button {
                    HapticFeedback.success()
                    _ = MockData.createSampleTrip(in: modelContext)
                } label: {
                    Label("立即加载演示路线体验", systemImage: "play.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(24)
        .elevatedCard(cornerRadius: 24)
        .padding(.top, 10)
    }
}

// MARK: - 行程封面画册卡片 (现代旅行杂志风 · 去除歧义叠层 · 路线亮点速览)
struct TripCardView: View {
    let trip: TripPlan
    
    // 聚合该行程按顺序排列的所有打卡点
    private var allSortedNodes: [RouteNode] {
        trip.days.sorted(by: { $0.dayIndex < $1.dayIndex }).flatMap { $0.sortedNodes }
    }
    
    // 路线精选前 3 个代表性打卡点
    private var highlightNodes: [RouteNode] {
        Array(allSortedNodes.prefix(3))
    }
    
    // 剩余未在预览中展示的节点数量
    private var extraNodesCount: Int {
        max(0, allSortedNodes.count - highlightNodes.count)
    }
    
    // 出行状态智能识别 (已完成 / 旅途中 / X天后出发 / 往昔回忆)
    private var departureStatus: (title: String, icon: String, color: Color, bg: Color) {
        if trip.progress >= 1.0 && trip.totalNodesCount > 0 {
            return ("已全部打卡", "checkmark.seal.fill", AppTheme.sageMint, AppTheme.sageMint.opacity(0.14))
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        
        if today >= start && today <= end {
            return ("旅途中", "figure.walk", AppTheme.sunsetCoral, AppTheme.sunsetCoral.opacity(0.14))
        } else if start > today {
            let days = calendar.dateComponents([.day], from: today, to: start).day ?? 0
            if days == 0 {
                return ("今日启程", "airplane.departure", AppTheme.warmAmber, AppTheme.warmAmber.opacity(0.14))
            } else {
                return ("\(days)天后启程", "clock.badge.checkmark", AppTheme.forestPrimary, AppTheme.forestPrimary.opacity(0.10))
            }
        } else {
            return ("漫游回忆", "bookmark.fill", .secondary, Color.primary.opacity(0.06))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 卡片顶部氛围抬头：目的地与出行状态
            HStack(alignment: .center) {
                // 目的地小徽标
                HStack(spacing: 5) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.sunsetCoral)
                    
                    Text(trip.destination.isEmpty ? "未设定目的地" : trip.destination)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.tertiaryBackground)
                .clipShape(Capsule())
                
                Spacer()
                
                // 智能出行状态微标
                let status = departureStatus
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(status.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(status.bg)
                .foregroundStyle(status.color)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            // 2. 行程主标题与日期信息
            VStack(alignment: .leading, spacing: 6) {
                Text(trip.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text("\(trip.startDate.formatted(.dateTime.month().day())) - \(trip.endDate.formatted(.dateTime.month().day()))")
                    }
                    
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text("\(trip.days.count) 天 · \(trip.totalNodesCount) 个打卡点")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            
            // 3. Trip Vibe 情绪风格标签 (若存在)
            if !trip.vibeTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(trip.vibeTags, id: \.self) { tag in
                            HStack(spacing: 3) {
                                Text("#")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.sageMint)
                                Text(tag)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.forestPrimary.opacity(0.08))
                            .foregroundStyle(AppTheme.forestPrimary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 12)
            }
            
            // 4. 路线亮点预览 (Mini Itinerary Stepper) 或 备忘提示
            if !highlightNodes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Array(highlightNodes.enumerated()), id: \.element.id) { index, node in
                            HStack(spacing: 4) {
                                Image(systemName: node.nodeType.systemIcon)
                                    .font(.system(size: 9))
                                    .foregroundStyle(node.isVisited ? AppTheme.sageMint : .secondary)
                                
                                Text(node.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundStyle(node.isVisited ? .secondary : .primary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            
                            if index < highlightNodes.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        
                        if extraNodesCount > 0 {
                            Text("+\(extraNodesCount)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            } else if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
            
            Divider()
                .opacity(0.4)
                .padding(.horizontal, 18)
            
            // 5. 底部打卡进度与进入路书入口
            HStack(spacing: 12) {
                // 打卡统计与百分比
                HStack(spacing: 6) {
                    Image(systemName: trip.progress == 1.0 ? "checkmark.circle.fill" : "flag.checkered")
                        .font(.system(size: 12))
                        .foregroundStyle(trip.progress == 1.0 ? AppTheme.sageMint : AppTheme.forestPrimary)
                    
                    Text("打卡 \(trip.visitedNodesCount)/\(trip.totalNodesCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(trip.progress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(trip.progress == 1.0 ? AppTheme.sageMint : AppTheme.forestPrimary)
                }
                
                // 平滑圆角进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                trip.progress == 1.0
                                ? AppTheme.emeraldGlowGradient
                                : AppTheme.brandGradient
                            )
                            .frame(width: geo.size.width * CGFloat(trip.progress), height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: trip.progress)
                    }
                }
                .frame(height: 6)
                
                // 查看路书指引
                HStack(spacing: 3) {
                    Text("路书")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(AppTheme.forestPrimary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.cardGlassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .shadow(color: AppTheme.forestPrimary.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

// MARK: - 按压弹性微动效 ButtonStyle
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
