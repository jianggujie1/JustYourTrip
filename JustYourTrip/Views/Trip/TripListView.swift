import SwiftUI
import SwiftData

/// 行程列表首页 (画册杂志风 & 空间质感)
struct TripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TripPlan.startDate, order: .reverse) private var trips: [TripPlan]
    
    @State private var showAddTripSheet = false
    @State private var showAIImportSheet = false
    @State private var showSettingsSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景暖色画板
                AppTheme.canvasBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 顶部杂志感 Hero 欢迎栏
                        headerHeroSection
                        
                        if trips.isEmpty {
                            emptyStateView
                        } else {
                            // 行程卡片流
                            LazyVStack(spacing: 18) {
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
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
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
                            .foregroundStyle(AppTheme.indigoPrimary)
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
    
    // MARK: - 顶部欢迎 Hero 区域
    
    private var headerHeroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // 快捷 AI 导入发光按钮
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.brandGradient)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.indigoPrimary.opacity(0.35), radius: 6, x: 0, y: 3)
                }
            }
            
            Text("专属旅程 · 即刻启程")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 空状态视图
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.indigoPrimary.opacity(0.08))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(AppTheme.indigoPrimary.opacity(0.12))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppTheme.brandGradient)
            }
            .padding(.top, 30)
            
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
                .tint(AppTheme.indigoPrimary)
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
            .padding(.top, 10)
        }
        .padding(24)
        .elevatedCard(cornerRadius: 24)
        .padding(.top, 10)
    }
}

// MARK: - 行程封面手账画册卡片
struct TripCardView: View {
    let trip: TripPlan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 卡片上部：目的地地名大字与天数 Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
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
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 天数胶囊
                Text("\(trip.days.count) 天行程")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(AppTheme.indigoPrimary)
                    .clipShape(Capsule())
            }
            
            // 行程备注备忘
            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.vertical, 2)
            }
            
            Divider()
                .opacity(0.6)
            
            // 底部流体进度条与打卡统计
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(trip.progress == 1.0 ? AppTheme.mintGreen : AppTheme.indigoPrimary)
                    
                    Text("打卡进度 \(trip.visitedNodesCount) / \(trip.totalNodesCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 进度百分比数字
                Text("\(Int(trip.progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(trip.progress == 1.0 ? AppTheme.mintGreen : AppTheme.indigoPrimary)
                
                // 平滑圆角进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(
                                trip.progress == 1.0
                                ? LinearGradient(colors: [AppTheme.mintGreen, Color(hex: "34D399")], startPoint: .leading, endPoint: .trailing)
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

// MARK: - 按压弹性微动效 ButtonStyle
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
