import SwiftUI
import SwiftData

/// 手动新建行程弹窗
struct AddTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var destination: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("行程基本信息") {
                    TextField("行程标题 (如：成都慢生活4日游)", text: $title)
                    TextField("目的地城市 (如：成都)", text: $destination)
                }
                
                Section("起止日期") {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                Section("行程备忘 / 主题") {
                    TextField("备注灵感、同行伙伴或旅行期望...", text: $notes, axis: .vertical)
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
            notes: notes
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
