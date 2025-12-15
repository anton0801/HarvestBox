import Foundation
import Combine
import SwiftUI

enum ItemStatus: String, CaseIterable, Codable {
    case good = "Good"
    case needsRepair = "Needs Repair"
    case outOfStock = "Out of Stock"
  
    var color: Color {
        switch self {
        case .good: return .goodGreen
        case .needsRepair: return .warningOrange
        case .outOfStock: return .criticalRed
        }
    }
}

struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var colorHex: String
    var color: Color { Color(hex: colorHex) }
}

struct Item: Identifiable, Codable {
    var id = UUID()
    var name: String = ""
    var category: String = "Other"
    var quantity: Int = 1
    var status: ItemStatus = .good
    var lastUsed: Date? = nil
    var note: String = ""
    var history: [HistoryEntry] = []
    var addedDate: Date = Date()
}

struct HistoryEntry: Codable {
    var date: Date = Date()
    var text: String
}

struct Reminder: Identifiable, Codable {
    var id = UUID()
    var title: String = ""
    var dueDate: Date = Date()
    var repeatInterval: RepeatInterval = .none
    var isDone: Bool = false
}

enum RepeatInterval: String, CaseIterable, Codable {
    case none = "One time"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

@MainActor
final class InventoryManager: ObservableObject {
    @Published var items: [Item] = []
    @Published var categories: [Category] = []
    @Published var reminders: [Reminder] = []
    
    private let calendar = Calendar.current
    
    var addedThisMonthCount: Int {
        let comps = calendar.dateComponents([.year, .month], from: Date())
        return items.filter {
            let ic = calendar.dateComponents([.year, .month], from: $0.addedDate)
            return ic.year == comps.year && ic.month == comps.month
        }.count
    }
    
    init() {
        loadAll()
        if categories.isEmpty {
            categories = defaultCategories
            saveCategories()
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private let defaultCategories = [
        Category(name: "Tools", icon: "🪣", colorHex: "808080"),
        Category(name: "Feeds", icon: "🌾", colorHex: "66BB6A"),
        Category(name: "Electricity", icon: "💡", colorHex: "F4B400"),
        Category(name: "Machinery", icon: "🚜", colorHex: "F28C38"),
        Category(name: "Consumables", icon: "🛒", colorHex: "3E7BB6"),
        Category(name: "Other", icon: "📦", colorHex: "6B6B6B")
    ]
    
    func saveItems() { try? UserDefaults.standard.set(JSONEncoder().encode(items), forKey: "FarmItems") }
    func saveCategories() { try? UserDefaults.standard.set(JSONEncoder().encode(categories), forKey: "FarmCategories") }
    func saveReminders() { try? UserDefaults.standard.set(JSONEncoder().encode(reminders), forKey: "FarmReminders") }
    
    func loadAll() {
        items = (try? JSONDecoder().decode([Item].self, from: UserDefaults.standard.data(forKey: "FarmItems") ?? Data())) ?? []
        categories = (try? JSONDecoder().decode([Category].self, from: UserDefaults.standard.data(forKey: "FarmCategories") ?? Data())) ?? []
        reminders = (try? JSONDecoder().decode([Reminder].self, from: UserDefaults.standard.data(forKey: "FarmReminders") ?? Data())) ?? []
    }
    
    func countForCategory(_ name: String) -> Int {
        items.filter { $0.category == name }.count
    }
    
    func predictedOutOfStock() -> [Item] {
        items.filter { item in
            if let lastHistory = item.history.last, lastHistory.text.contains("Out of Stock") {
                return true
            }
            return false
        }
    }
    
    func addedItemsPerMonth() -> [ (month: String, count: Int) ] {
        var monthlyCounts: [String: Int] = [:]
        for item in items {
            let comps = calendar.dateComponents([.year, .month], from: item.addedDate)
            let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
            monthlyCounts[key, default: 0] += 1
        }
        return monthlyCounts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    
}
