import Foundation
import SwiftData

/// 清单分类
enum ChecklistCategory: String, Codable, CaseIterable, Identifiable {
    case documents = "证件票务"
    case digital   = "数码装备"
    case clothing  = "穿搭衣物"
    case medical   = "个人药品"
    case toiletries = "个护洗漱"
    case custom    = "其他定制"
    
    var id: String { rawValue }
    
    var systemIcon: String {
        switch self {
        case .documents: return "person.text.rectangle"
        case .digital: return "iphone.gen3"
        case .clothing: return "tshirt"
        case .medical: return "cross.case.fill"
        case .toiletries: return "comb.fill"
        case .custom: return "bag.fill"
        }
    }
}

/// 行前准备清单物品
@Model
final class ChecklistItem {
    var id: UUID = UUID()
    var name: String = ""
    var isChecked: Bool = false
    var categoryRaw: String = ChecklistCategory.documents.rawValue
    var isEssential: Bool = false // 是否特需/高优先级必备
    var note: String = ""
    var createdAt: Date = Date()
    
    var trip: TripPlan?

    var category: ChecklistCategory {
        get { ChecklistCategory(rawValue: categoryRaw) ?? .documents }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        category: ChecklistCategory = .documents,
        isEssential: Bool = false,
        note: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.isChecked = false
        self.categoryRaw = category.rawValue
        self.isEssential = isEssential
        self.note = note
        self.createdAt = Date()
    }
}
