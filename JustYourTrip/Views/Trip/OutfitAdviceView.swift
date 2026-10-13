import SwiftUI
import SwiftData

/// 精致手账旅行风的穿衣指南与穿搭卡片 (OutfitAdviceCardView)
struct OutfitAdviceCardView: View {
    @Bindable var trip: TripPlan
    var day: TripDay? // 若为 nil 则处于全景总览模式
    var onEdit: () -> Void

    @State private var isExpanded: Bool = false

    private var isOverview: Bool {
        day == nil
    }

    /// 当前显示的穿衣建议正文
    private var displayedAdvice: String {
        if let day = day, !day.outfitAdvice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return day.outfitAdvice
        }
        return trip.outfitAdvice
    }

    /// 标记是否为当日专属建议
    private var isDaySpecific: Bool {
        guard let day = day else { return false }
        return !day.outfitAdvice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var themeColor: Color {
        if let day = day {
            return AppTheme.dayColor(for: day.dayIndex)
        }
        return AppTheme.sageMint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 头部标题与编辑按键
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(themeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isOverview ? "全程穿衣指南 · 穿搭推荐" : "Day \(day?.dayIndex ?? 1) 穿衣推荐")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        if isDaySpecific {
                            Text("当日专属")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(themeColor.opacity(0.12))
                                .foregroundStyle(themeColor)
                                .clipShape(Capsule())
                        } else if !displayedAdvice.isEmpty {
                            Text("推荐指南")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.primary.opacity(0.06))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // 自定义编辑按键
                Button {
                    HapticFeedback.light()
                    onEdit()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                        Text(displayedAdvice.isEmpty ? "添加" : "编辑")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.forestPrimary.opacity(0.08))
                    .foregroundStyle(AppTheme.forestPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // 穿衣指南正文内容
            if displayedAdvice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    HapticFeedback.light()
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text(isOverview ? "点击添加全程穿衣指南与温差、鞋履建议..." : "点击为今日添加专属穿搭或使用全程穿衣指南...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } else {
                Text(displayedAdvice)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }

                if displayedAdvice.count > 50 {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Text(isExpanded ? "收起" : "展开全部")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(themeColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(themeColor.opacity(0.18), lineWidth: 1)
        )
    }
}

/// 穿衣推荐独立编辑弹窗 (EditOutfitAdviceSheet)
struct EditOutfitAdviceSheet: View {
    @Bindable var trip: TripPlan
    var day: TripDay? // 若传入 day 则允许切换编辑当日或全程
    @Environment(\.dismiss) private var dismiss

    enum EditScope: Int {
        case trip = 0
        case day = 1
    }

    @State private var editScope: EditScope = .trip
    @State private var textInput: String = ""

    private let quickTags = [
        "🧥 早晚温差备外套",
        "👟 轻便平底暴走鞋",
        "📸 浅色系拍照出片",
        "🌬️ 江边防风保暖",
        "☀️ 防晒透气速干",
        "☔ 备晴雨两用伞",
        "👗 氛围感法式复古",
        "🥾 徒步防滑运动鞋",
        "🧣 昼夜温差洋葱穿法"
    ]

    init(trip: TripPlan, day: TripDay? = nil) {
        self.trip = trip
        self.day = day
        if let day = day, !day.outfitAdvice.isEmpty {
            _editScope = State(initialValue: .day)
            _textInput = State(initialValue: day.outfitAdvice)
        } else {
            _editScope = State(initialValue: day != nil ? .day : .trip)
            _textInput = State(initialValue: day?.outfitAdvice.isEmpty == false ? (day?.outfitAdvice ?? "") : trip.outfitAdvice)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let day = day {
                    Section {
                        Picker("编辑范围", selection: $editScope) {
                            Text("Day \(day.dayIndex) 当日穿搭").tag(EditScope.day)
                            Text("整趟行程总体穿衣指南").tag(EditScope.trip)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: editScope) { _, newScope in
                            switch newScope {
                            case .day:
                                textInput = day.outfitAdvice.isEmpty ? trip.outfitAdvice : day.outfitAdvice
                            case .trip:
                                textInput = trip.outfitAdvice
                            }
                        }
                    } header: {
                        Text("穿搭作用范围")
                    } footer: {
                        Text(editScope == .day ? "此建议将优先展示在 Day \(day.dayIndex) 日程卡片上。" : "此建议将作为整趟行程的总览指导，各天未单独设置时将自动沿用。")
                    }
                }

                Section {
                    TextEditor(text: $textInput)
                        .frame(minHeight: 110)

                    if !textInput.isEmpty {
                        HStack {
                            Spacer()
                            Button("清空内容") {
                                textInput = ""
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Text("穿衣搭配建议与气候贴士")
                        Spacer()
                        Text("\(textInput.count) 字")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("快速添加常用建议与标签") {
                    FlowLayout(spacing: 8) {
                        ForEach(quickTags, id: \.self) { tag in
                            Button {
                                HapticFeedback.light()
                                appendTag(tag)
                            } label: {
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundStyle(Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !trip.destination.isEmpty {
                    Section {
                        Button {
                            HapticFeedback.light()
                            applyIntelligentPreset()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(AppTheme.warmAmber)
                                Text("一键生成「\(trip.destination)」智能穿衣模版")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.forestPrimary)
                            }
                        }
                    } footer: {
                        Text("根据目的地与多日徒步场景自动推荐分层穿衣与舒适鞋履搭配。")
                    }
                }
            }
            .navigationTitle("编辑穿衣推荐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        HapticFeedback.success()
                        saveAdvice()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.forestPrimary)
                }
            }
        }
    }

    private func appendTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespaces)
        if textInput.isEmpty {
            textInput = cleanTag
        } else if textInput.contains(cleanTag) {
            return
        } else {
            textInput += "；" + cleanTag
        }
    }

    private func applyIntelligentPreset() {
        let city = trip.destination.isEmpty ? "目的地" : trip.destination
        textInput = "\(city)出行穿搭建议：早晚温差较大，推荐洋葱式分层穿法（长袖打底配轻薄风衣/针织开衫）；全天探索步行多，请务必穿轻便舒适的平底健步鞋；拍照推荐浅色系或大地色系，出片效果好；随身备晴雨两用伞与防晒用品。"
    }

    private func saveAdvice() {
        let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let day = day, editScope == .day {
            day.outfitAdvice = trimmed
        } else {
            trip.outfitAdvice = trimmed
        }
    }
}

/// 简单的 FlowLayout 辅助视图，用于流式标签排列
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        height = currentY + lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
