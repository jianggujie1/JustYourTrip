import SwiftUI
import SwiftData

/// 新增行李准备物品弹窗
struct AddChecklistItemSheet: View {
    let trip: TripPlan?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name: String = ""
    @State private var category: ChecklistCategory = .documents
    @State private var isEssential: Bool = false
    @State private var note: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("物品名称") {
                    TextField("例如：身份证、充电宝、晕车贴", text: $name)
                }
                
                Section("归属分类") {
                    Picker("分类", selection: $category) {
                        ForEach(ChecklistCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.systemIcon).tag(cat)
                        }
                    }
                }
                
                Section("重要程度") {
                    Toggle("特需 / 关键必备物品", isOn: $isEssential)
                }
                
                Section("备注说明") {
                    TextField("例如：提前充满电、放随身小包", text: $note)
                }
            }
            .navigationTitle("添加准备物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let item = ChecklistItem(
                            name: name,
                            category: category,
                            isEssential: isEssential,
                            note: note
                        )
                        item.trip = trip
                        modelContext.insert(item)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
