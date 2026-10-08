import SwiftUI
import SwiftData

/// 手动新建行程弹窗 (集成 Trip Vibe 情绪风格标签选择)
struct AddTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var notes: String = ""
    @State private var selectedVibes: Set<String> = ["🏙️ 城市漫步", "📸 地标巡礼"]
    
    private let availableVibes = [
        "🏙️ 城市漫步", "🌿 慢调漫游", "📸 地标巡礼",
        "🍜 美食寻味", "⛺ 户外探秘", "🚇 地铁漫游",
        "☕ 咖啡探店", "🏛️ 历史文博", "🚗 自由自驾"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("行程基本信息") {
                    TextField("行程标题 (如：成都慢生活4日游)", text: $title)
                    TextField("目的地城市 (如：成都)", text: $destination)
                }
                
                Section("旅行风格与情绪 (Trip Vibe)") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableVibes, id: \.self) { vibe in
                                let isSelected = selectedVibes.contains(vibe)
                                Button {
                                    HapticFeedback.selection()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        if isSelected {
                                            selectedVibes.remove(vibe)
                                        } else {
                                            selectedVibes.insert(vibe)
                                        }
                                    }
                                } label: {
                                    Text(vibe)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                                        )
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .shadow(color: isSelected ? AppTheme.forestPrimary.opacity(0.3) : .clear, radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("起止日期") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section("行程备忘 / 主题灵感") {
                    TextField("备注同行伙伴、核心期待或行前灵感...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("新建行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        HapticFeedback.success()
                        createTrip()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func createTrip() {
        let trip = TripPlan(
            title: title,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            vibeTags: Array(selectedVibes)
        )
        modelContext.insert(trip)
        
        // 自动根据起止日期生成 TripDay
        let calendar = Calendar.current
        var current = startDate
        var dayIndex = 1
        
        while current <= endDate {
            let day = TripDay(dayIndex: dayIndex, date: current, summary: "第 \(dayIndex) 天日程")
            day.trip = trip
            modelContext.insert(day)
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
            dayIndex += 1
        }
        
        dismiss()
    }
}
