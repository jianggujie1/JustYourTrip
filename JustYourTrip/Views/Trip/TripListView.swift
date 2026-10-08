import SwiftUI
import SwiftData

/// 行程列表首页 (Uix Foysal 概念画册风、多层堆叠卡片与自然森林色系)
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripPlan.startDate, order: .reverse) private var trips: [TripPlan]
    
    @State private var showAddTripSheet = false
    @State private var showAIImportSheet = false
    @State private var showSettingsSheet = false
    
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
                            // 堆叠层级感行程卡片流
                            LazyVStack(spacing: 28) {
                                ForEach(trips) { trip in
                                    NavigationLink(destination: TripDetailMapView(trip: trip)) {
                                        TripCardView(trip: trip)
                                    }
                                    .buttonStyle(BouncyButtonStyle())
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
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
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

// MARK: - 行程封面手账画册卡片 (带多重层叠感 & Trip Vibe 情绪胶囊)
struct TripCardView: View {
    let trip: TripPlan
    
    var body: some View {
        ZStack(alignment: .top) {
            // 背景层叠 2 (最外层/最窄，呈现厚度)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.sageMint.opacity(0.12))
                .frame(height: 50)
                .padding(.horizontal, 24)
                .offset(y: -12)
            
            // 背景层叠 1 (中层，稍宽)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.forestPrimary.opacity(0.18))
                .frame(height: 50)
                .padding(.horizontal, 12)
                .offset(y: -6)
            
            // 主前景卡片
            VStack(alignment: .leading, spacing: 14) {
                // 卡片上部：目的地地名大字与天数 Badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.sunsetCoral)
                            
                            Text(trip.destination)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(AppTheme.sunsetCoral)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text("\(trip.startDate.formatted(.dateTime.month().day())) - \(trip.endDate.formatted(.dateTime.month().day()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(trip.title)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 天数胶囊
                    Text("\(trip.days.count) 天行程")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.forestPrimary.opacity(0.12))
                        .foregroundStyle(AppTheme.forestPrimary)
                        .clipShape(Capsule())
                }
                
                // Trip Vibe 情绪标签流
                if !trip.vibeTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(trip.vibeTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.sageMint.opacity(0.12))
                                    .foregroundStyle(AppTheme.forestPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                
                // 行程备忘摘要
                if !trip.notes.isEmpty {
                    Text(trip.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.vertical, 1)
                }
                
                Divider()
                    .opacity(0.6)
                
                // 底部流体进度条与打卡统计
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.caption)
                            .foregroundStyle(trip.progress == 1.0 ? AppTheme.luminousMint : AppTheme.forestPrimary)
                        
                        Text("打卡进度 \(trip.visitedNodesCount) / \(trip.totalNodesCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // 进度百分比数字
                    Text("\(Int(trip.progress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(trip.progress == 1.0 ? AppTheme.sageMint : AppTheme.forestPrimary)
                    
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
                    .frame(width: 64, height: 6)
                }
            }
            .padding(20)
            .elevatedCard(cornerRadius: 24)
        }
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
