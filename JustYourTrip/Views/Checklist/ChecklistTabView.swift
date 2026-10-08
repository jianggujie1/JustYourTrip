import SwiftUI
import SwiftData

/// 行前准备（Checklist 打包助手 Tab - 仪式感进度环与分类手账）
struct ChecklistTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChecklistItem.createdAt, order: .forward) private var allItems: [ChecklistItem]
    @Query(sort: \TripPlan.startDate, order: .reverse) private var trips: [TripPlan]
    
    @State private var selectedTripId: UUID?
    @State private var showAddItemSheet = false
    @State private var showApplyTemplateAlert = false
    
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
    
    private var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(checkedCount) / Double(totalCount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 所属行程选择器横向滚动条 (胶囊切换带触感)
                if !trips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            let isAllSelected = selectedTripId == nil
                            Button {
                                HapticFeedback.selection()
                                selectedTripId = nil
                            } label: {
                                Text("全部清单")
                                    .font(.system(size: 13, weight: isAllSelected ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(isAllSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                                    )
                                    .foregroundStyle(isAllSelected ? .white : .primary)
                                    .shadow(color: isAllSelected ? AppTheme.indigoPrimary.opacity(0.3) : .clear, radius: 4)
                            }
                            
                            ForEach(trips) { trip in
                                let isSelected = selectedTripId == trip.id
                                Button {
                                    HapticFeedback.selection()
                                    selectedTripId = trip.id
                                } label: {
                                    Text(trip.title)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .shadow(color: isSelected ? AppTheme.indigoPrimary.opacity(0.3) : .clear, radius: 4)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                    Divider()
                        .opacity(0.6)
                }
                
                // 顶部打包进度展示卡片
                progressHeaderView
                
                // 分类清单内容列表
                if filteredItems.isEmpty {
                    emptyChecklistView
                } else {
                    List {
                        ForEach(ChecklistCategory.allCases) { category in
                            let itemsInCategory = filteredItems.filter { $0.category == category }
                            if !itemsInCategory.isEmpty {
                                Section {
                                    ForEach(itemsInCategory) { item in
                                        ChecklistItemRow(item: item)
                                    }
                                    .onDelete { offsets in
                                        deleteItems(items: itemsInCategory, offsets: offsets)
                                    }
                                } header: {
                                    HStack(spacing: 6) {
                                        Image(systemName: category.systemIcon)
                                            .foregroundStyle(categoryColor(for: category))
                                        Text(category.rawValue)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        let catChecked = itemsInCategory.filter(\.isChecked).count
                                        Text("\(catChecked)/\(itemsInCategory.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(AppTheme.canvasBackground)
            .navigationTitle("行前打包助手")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            HapticFeedback.light()
                            showApplyTemplateAlert = true
                        } label: {
                            Label("应用常用出行模版", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticFeedback.light()
                        showAddItemSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
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
        }
    }
    
    // MARK: - 进度条头部
    
    private var progressHeaderView: some View {
        HStack(spacing: 16) {
            // 发光环形进度仪表盘
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
                
                Text("\(Int(completionRate * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(completionRate == 1.0 ? AppTheme.mintGreen : AppTheme.indigoPrimary)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(completionRate == 1.0 ? "🎉 行李准备万全，祝旅途愉快！" : "打包整理进度")
                    .font(.system(size: 16, weight: .bold))
                
                Text("已确认 \(checkedCount) / \(totalCount) 件物品")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(18)
        .background(AppTheme.cardBackground)
    }
    
    // MARK: - 空状态
    
    private var emptyChecklistView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.indigoPrimary.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: "bag.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.indigoPrimary)
            }
            Text("清单空空如也")
                .font(.headline)
            Text("出行前整理行李，避免遗落关键物品与药品")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                HapticFeedback.success()
                applyPresetTemplate()
            } label: {
                Label("一键导入 12 项经典清单模版", systemImage: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.indigoPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func categoryColor(for category: ChecklistCategory) -> Color {
        switch category {
        case .documents: return AppTheme.indigoPrimary
        case .digital: return AppTheme.skyTeal
        case .clothing: return AppTheme.sunsetGold
        case .medical: return AppTheme.mintGreen
        case .toiletries: return AppTheme.royalPurple
        case .custom: return Color.gray
        }
    }
    
    private func deleteItems(items: [ChecklistItem], offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            modelContext.delete(item)
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
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    item.isChecked.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? AppTheme.mintGreen : Color.secondary.opacity(0.35), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if item.isChecked {
                        Circle()
                            .fill(AppTheme.mintGreen)
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundStyle(item.isChecked ? .secondary : .primary)
                    
                    if item.isEssential {
                        Text("必备")
                            .font(.system(size: 10, weight: .bold))
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
