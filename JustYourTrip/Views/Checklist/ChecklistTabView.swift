import SwiftUI
import SwiftData

/// 行前准备（Checklist 打包助手 Tab - 仪式感进度环与手账折叠卡片）
struct ChecklistTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistItem.createdAt, order: .forward) private var allItems: [ChecklistItem]
    @Query(sort: \TripPlan.startDate, order: .reverse) private var trips: [TripPlan]
    
    @State private var selectedTripId: UUID?
    @State private var showAddItemSheet = false
    @State private var showApplyTemplateAlert = false
    @State private var showResetAlert = false
    @State private var collapsedCategories: Set<String> = []
    
    private var filteredItems: [ChecklistItem] {
        if let tripId = selectedTripId {
            return allItems.filter { $0.trip?.id == tripId }
        }
        return allItems
    }
    
    private var checkedCount: Int {
        filteredItems.filter(\.isChecked).count
    }
    
    private var totalCount: Int {
        filteredItems.count
    }
    
    private var essentialItems: [ChecklistItem] {
        filteredItems.filter(\.isEssential)
    }
    
    private var essentialCheckedCount: Int {
        essentialItems.filter(\.isChecked).count
    }
    
    private var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(checkedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 所属行程横向胶囊切换条
                tripPickerBar
                
                Divider()
                    .opacity(0.5)
                
                // 2. 顶部打包仪式感仪表盘卡片
                progressHeaderView
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                
                // 3. 分类清单手账内容列表
                if filteredItems.isEmpty {
                    emptyChecklistView
                } else {
                    categorizedItemsList
                }
            }
            .background(AppTheme.canvasBackground)
            .navigationTitle("行前打包助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            HapticFeedback.light()
                            showApplyTemplateAlert = true
                        } label: {
                            Label("应用 12 项经典清单模版", systemImage: "sparkles")
                        }
                        
                        if !filteredItems.isEmpty {
                            Button(role: .destructive) {
                                HapticFeedback.warning()
                                showResetAlert = true
                            } label: {
                                Label("重置当前清单勾选", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showAddItemSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.sageMint)
                    }
                }
            }
            .sheet(isPresented: $showAddItemSheet) {
                let currentTrip = trips.first(where: { $0.id == selectedTripId })
                AddChecklistItemSheet(trip: currentTrip)
            }
            .alert("应用常用出行模版", isPresented: $showApplyTemplateAlert) {
                Button("取消", role: .cancel) {}
                Button("确认导入") {
                    HapticFeedback.success()
                    applyPresetTemplate()
                }
            } message: {
                Text("将自动为你导入证件、数码、应急药品、洗漱等常用 12 项出行打包清单。")
            }
            .alert("重置勾选状态", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("确认重置", role: .destructive) {
                    HapticFeedback.medium()
                    withAnimation {
                        for item in filteredItems {
                            item.isChecked = false
                        }
                    }
                }
            } message: {
                Text("确定要将当前显示的所有物品重置为未打包状态吗？")
            }
        }
    }
    
    // MARK: - 行程切换栏
    
    private var tripPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部清单胶囊
                let isAllSelected = selectedTripId == nil
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTripId = nil
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("全部清单")
                            .font(.system(size: 13, weight: isAllSelected ? .bold : .medium, design: .rounded))
                        
                        if !allItems.isEmpty {
                            Text("\(allItems.filter(\.isChecked).count)/\(allItems.count)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(isAllSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06))
                                .foregroundStyle(isAllSelected ? Color.white : Color.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(isAllSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                    )
                    .foregroundStyle(isAllSelected ? .white : .primary)
                    .shadow(color: isAllSelected ? AppTheme.sageMint.opacity(0.3) : .clear, radius: 4)
                }
                .buttonStyle(.plain)
                
                // 各行程胶囊
                ForEach(trips) { trip in
                    let isSelected = selectedTripId == trip.id
                    let tripItems = allItems.filter { $0.trip?.id == trip.id }
                    
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTripId = trip.id
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(trip.title)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                                .lineLimit(1)
                            
                            if !tripItems.isEmpty {
                                Text("\(tripItems.filter(\.isChecked).count)/\(tripItems.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.06))
                                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                        )
                        .foregroundStyle(isSelected ? .white : .primary)
                        .shadow(color: isSelected ? AppTheme.sageMint.opacity(0.3) : .clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 顶部打包仪式感仪表盘卡片
    
    private var progressHeaderView: some View {
        HStack(spacing: 16) {
            // 双环形进度仪表盘
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                
                Circle()
                    .trim(from: 0, to: CGFloat(completionRate))
                    .stroke(
                        completionRate == 1.0 ? AppTheme.mintGradient : AppTheme.brandGradient,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: completionRate)
                
                VStack(spacing: 1) {
                    Text("\(Int(completionRate * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(completionRate == 1.0 ? AppTheme.sageMint : AppTheme.forestPrimary)
                }
            }
            .frame(width: 58, height: 58)
            
            // 文本信息与必备状态
            VStack(alignment: .leading, spacing: 5) {
                Text(completionRate == 1.0 ? "🎉 行李准备万全，随时启程！" : "行李打包收纳进度")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text("已备好 \(checkedCount) / \(totalCount) 件")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    if !essentialItems.isEmpty {
                        Text("• 必备 \(essentialCheckedCount)/\(essentialItems.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(essentialCheckedCount == essentialItems.count ? AppTheme.sageMint : AppTheme.sunsetCoral)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
    
    // MARK: - 手账分类卡片列表
    
    private var categorizedItemsList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(ChecklistCategory.allCases, id: \.self) { category in
                    let itemsInCategory = filteredItems.filter { $0.category == category }
                    if !itemsInCategory.isEmpty {
                        categoryCardView(category: category, items: itemsInCategory)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - 单个分类卡片 (支持折叠与展开)
    
    @ViewBuilder
    private func categoryCardView(category: ChecklistCategory, items: [ChecklistItem]) -> some View {
        let isCollapsed = collapsedCategories.contains(category.id)
        let catChecked = items.filter(\.isChecked).count
        let isAllChecked = catChecked == items.count && !items.isEmpty
            
            VStack(spacing: 0) {
                // 分类头部 Bar
                Button {
                    HapticFeedback.light()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if isCollapsed {
                            collapsedCategories.remove(category.id)
                        } else {
                            collapsedCategories.insert(category.id)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        // 分类图标徽标
                        Image(systemName: category.systemIcon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(categoryColor(for: category))
                            .frame(width: 26, height: 26)
                            .background(categoryColor(for: category).opacity(0.12))
                            .clipShape(Circle())
                        
                        Text(category.rawValue)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // 计数胶囊
                        Text("\(catChecked)/\(items.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(isAllChecked ? AppTheme.sageMint.opacity(0.15) : Color.primary.opacity(0.05))
                            .foregroundStyle(isAllChecked ? AppTheme.sageMint : .secondary)
                            .clipShape(Capsule())
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                // 展开时的物品项
                if !isCollapsed {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 {
                                Divider()
                                    .padding(.leading, 42)
                                    .opacity(0.4)
                            }
                            
                            ChecklistItemRow(item: item)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                        }
                    }
                    .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.5))
                }
            }
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isAllChecked ? AppTheme.sageMint.opacity(0.3) : Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - 空状态
    
    private var emptyChecklistView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.forestPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "bag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.sageMint)
            }
            Text("清单空空如也")
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text("出行前整理行李，避免遗落关键证件与常备药品")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                HapticFeedback.success()
                applyPresetTemplate()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("一键导入 12 项经典清单模版")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(AppTheme.brandGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: AppTheme.sageMint.opacity(0.35), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func categoryColor(for category: ChecklistCategory) -> Color {
        switch category {
        case .documents: return AppTheme.indigoPrimary
        case .digital: return AppTheme.skyTeal
        case .clothing: return AppTheme.warmAmber
        case .medical: return AppTheme.sageMint
        case .toiletries: return AppTheme.royalPurple
        case .custom: return Color.gray
        }
    }
    
    private func applyPresetTemplate() {
        let currentTrip = trips.first(where: { $0.id == selectedTripId })
        let template: [(String, ChecklistCategory, Bool)] = [
            ("身份证件 / 护照", .documents, true),
            ("交通行程单 / 乘车码", .documents, true),
            ("大容量移动电源 (支持快充)", .digital, true),
            ("手机多口充电线", .digital, true),
            ("降噪耳机", .digital, false),
            ("换洗衣物与贴身内衣", .clothing, true),
            ("轻便暴走运动鞋", .clothing, true),
            ("折叠晴雨伞", .clothing, false),
            ("感冒/胃肠/抗过敏日常药", .medical, true),
            ("创口贴与酒精棉片", .medical, false),
            ("牙刷/牙膏旅行分装瓶", .toiletries, false),
            ("便携抽纸与湿厕纸", .toiletries, true)
        ]
        
        for item in template {
            let checkItem = ChecklistItem(name: item.0, category: item.1, isEssential: item.2)
            checkItem.trip = currentTrip
            modelContext.insert(checkItem)
        }
    }
}

/// 清单单行卡片
struct ChecklistItemRow: View {
    @Bindable var item: ChecklistItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(spacing: 12) {
            // 触感打卡圆环
            Button {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    item.isChecked.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? AppTheme.sageMint : Color.secondary.opacity(0.35), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if item.isChecked {
                        Circle()
                            .fill(AppTheme.sageMint)
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // 内容文本
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .strikethrough(item.isChecked, color: .secondary.opacity(0.7))
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    
                    if item.isEssential {
                        Text("必备")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(AppTheme.sunsetCoral.opacity(0.12))
                            .foregroundStyle(AppTheme.sunsetCoral)
                            .clipShape(Capsule())
                    }
                }
                
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 快速删除按钮
            Button {
                HapticFeedback.light()
                modelContext.delete(item)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.success()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                item.isChecked.toggle()
            }
        }
    }
}
