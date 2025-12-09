
import SwiftUI
import UserNotifications
import Combine

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF)*17, (int & 0xF)*17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
  
    var toHex: String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

extension Color {
    static let background = Color(hex: "FFF8E1")
    static let accent = Color(hex: "F4B400")
    static let textGray = Color(hex: "6B6B6B")
    static let cardWhite = Color(hex: "FFFFFF")
    static let goodGreen = Color(hex: "66BB6A")
    static let warningOrange = Color(hex: "F28C38")
    static let criticalRed = Color(hex: "E53935")
}

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
}

struct CategoryCard: View {
    let category: Category
    let count: Int
  
    var body: some View {
        VStack(spacing: 12) {
            Text(category.icon)
                .font(.system(size: 48))
            Text(category.name)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.textGray)
            Text("\(count) items")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.textGray.opacity(0.8))
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(Color.cardWhite)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }
}

@main
struct FarmInventoryApp: App {
    @StateObject private var manager = InventoryManager()
  
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(manager)
                .preferredColorScheme(.light)
                .tint(.accent)
                .onAppear {
                    UIScrollView.appearance().backgroundColor = UIColor(Color.background)
                    UITableView.appearance().backgroundColor = UIColor(Color.background)
                    UITableViewCell.appearance().backgroundColor = UIColor.clear
                    UITableView.appearance().separatorStyle = .none
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationView { InventoryView() }
                .tabItem { Label("Inventory", systemImage: "tray.full") }
            NavigationView { AnalyticsView() }
                .tabItem { Label("Statistics", systemImage: "chart.pie.fill") }
            NavigationView { RemindersView() }
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
            NavigationView { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.accent)
        .background(Color.background.ignoresSafeArea())
    }
}

struct InventoryView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingAddItem = false
  
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(manager.categories) { cat in
                            NavigationLink(destination: CategoryItemsView(categoryName: cat.name)) {
                                CategoryCard(category: cat, count: manager.countForCategory(cat.name))
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(Color.background.ignoresSafeArea())
            .navigationTitle("Inventory")
          
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showingAddItem = true
                }
            } label: {
                Label("Add Item", systemImage: "plus")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 180, height: 60)
                    .background(Color.accent)
                    .cornerRadius(30)
                    .shadow(color: .accent.opacity(0.4), radius: 15, y: 8)
            }
            .padding(.trailing, 30)
            .padding(.bottom, 30)
            .sheet(isPresented: $showingAddItem) {
                AddEditItemView()
            }
        }
    }
}

struct CategoryItemsView: View {
    @EnvironmentObject var manager: InventoryManager
    let categoryName: String
    @State private var showingAddItem = false
  
    private var filteredItems: [Item] {
        manager.items.filter { $0.category == categoryName }
    }
  
    var body: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    HStack(spacing: 16) {
                        Text(item.status == .good ? "✅" : item.status == .needsRepair ? "⚠️" : "❌")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.system(.headline, design: .rounded))
                            Text("\(item.quantity) pcs • \(item.status.rawValue)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.textGray)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let item = filteredItems[index]
                    manager.items.removeAll { $0.id == item.id }
                }
                manager.saveItems()
            }
        }
        .listStyle(.plain)
        .navigationTitle(categoryName)
        .background(Color.background.ignoresSafeArea())
        .toolbar {
            Button("Add") { showingAddItem = true }
        }
        .sheet(isPresented: $showingAddItem) {
            AddEditItemView(preselectedCategory: categoryName)
        }
    }
}

struct AddEditItemView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    var itemToEdit: Item? = nil
    var preselectedCategory: String? = nil
  
    @State private var name = ""
    @State private var category = ""
    @State private var quantity = 1
    @State private var status = ItemStatus.good
    @State private var lastUsed: Date? = nil
    @State private var note = ""
  
    private var lastUsedBinding: Binding<Date> {
        Binding(get: { lastUsed ?? Date() }, set: { lastUsed = $0 })
    }
  
    var body: some View {
        NavigationView {
            Form {
                Section("Name") { TextField("Enter name", text: $name) }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(manager.categories, id: \.id) { cat in
                            Text("\(cat.icon) \(cat.name)").tag(cat.name)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Quantity") {
                    Stepper("\(quantity) pcs", value: $quantity, in: 1...999)
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ItemStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Last used") {
                    DatePicker("Last used", selection: lastUsedBinding, displayedComponents: [.date])
                    Button("Clear date") { lastUsed = nil }
                        .foregroundColor(.red)
                }
                Section("Note") {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
            }
            .navigationTitle(itemToEdit == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newItem = Item(
                            id: itemToEdit?.id ?? UUID(),
                            name: name.isEmpty ? "New Item" : name,
                            category: category.isEmpty ? (preselectedCategory ?? manager.categories.first?.name ?? "Other") : category,
                            quantity: quantity,
                            status: status,
                            lastUsed: lastUsed,
                            note: note,
                            history: (itemToEdit?.history ?? []) + [HistoryEntry(text: itemToEdit == nil ? "Created" : "Updated")]
                        )
                      
                        if let itemToEdit = itemToEdit {
                            if let index = manager.items.firstIndex(where: { $0.id == itemToEdit.id }) {
                                manager.items[index] = newItem
                            }
                        } else {
                            manager.items.append(newItem)
                        }
                      
                        manager.saveItems()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let item = itemToEdit {
                    name = item.name
                    category = item.category
                    quantity = item.quantity
                    status = item.status
                    lastUsed = item.lastUsed
                    note = item.note
                } else if let pre = preselectedCategory {
                    category = pre
                }
            }
        }
    }
}

struct ItemDetailView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    @State var item: Item
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
  
    var body: some View {
        List {
            HStack { Text("Name"); Spacer(); Text(item.name).foregroundColor(.textGray) }
            HStack { Text("Category"); Spacer(); if let cat = manager.categories.first(where: { $0.name == item.category }) { Text("\(cat.icon) \(cat.name)") } }
            HStack { Text("Quantity"); Spacer(); Text("\(item.quantity) pcs") }
            HStack { Text("Status"); Spacer(); Text(item.status.rawValue).foregroundColor(item.status.color).bold() }
            if let date = item.lastUsed {
                HStack { Text("Last used"); Spacer(); Text(date, style: .date) }
            }
            if !item.note.isEmpty {
                Section("Note") { Text(item.note) }
            }
            Section("History") {
                if item.history.isEmpty {
                    Text("No history yet").foregroundColor(.secondary)
                } else {
                    ForEach(item.history, id: \.date) { entry in
                        Text("\(entry.date.formatted(date: .numeric, time: .shortened)) — \(entry.text)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(item.name)
        .background(Color.background.ignoresSafeArea())
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit") { showingEdit = true }
                Button("Delete", role: .destructive) { showingDeleteAlert = true }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditItemView(itemToEdit: item)
        }
        .alert("Delete item?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                manager.items.removeAll { $0.id == item.id }
                manager.saveItems()
                presentationMode.wrappedValue.dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct AnalyticsView: View {
    @EnvironmentObject var manager: InventoryManager
  
    private var goodCount: Int { manager.items.filter { $0.status == .good }.count }
    private var repairCount: Int { manager.items.filter { $0.status == .needsRepair }.count }
    private var outCount: Int { manager.items.filter { $0.status == .outOfStock }.count }
  
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        Text("Overall Status")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                      
                        HStack(spacing: 40) {
                            StatusCircle(count: manager.items.count, color: .goodGreen, label: "Good", value: goodCount)
                            StatusCircle(count: manager.items.count, color: .warningOrange, label: "Repair", value: repairCount)
                            StatusCircle(count: manager.items.count, color: .criticalRed, label: "Out of stock", value: outCount)
                        }
                      
                        ForEach(manager.categories) { cat in
                            if manager.countForCategory(cat.name) > 0 {
                                HStack {
                                    Text("\(cat.icon) \(cat.name)")
                                    Spacer()
                                    Text("\(manager.countForCategory(cat.name)) items")
                                        .bold()
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .padding()
                    .background(Color.cardWhite)
                    .cornerRadius(20)
                    .padding(.horizontal)
                  
                    VStack(spacing: 8) {
                        Text("Total items: \(manager.items.count)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                        Text("Added this month: \(manager.addedThisMonthCount)")
                            .font(.system(.body, design: .rounded))
                    }
                    .padding()
                    .background(Color.cardWhite)
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Statistics")
    }
}

struct StatusCircle: View {
    let count: Int
    let color: Color
    let label: String
    let value: Int
  
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 100, height: 100)
                VStack {
                    Text("\(value)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(label)
                        .font(.system(.caption, design: .rounded))
                }
            }
            if count > 0 {
                Text("\(Int(Double(value) / Double(count) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RemindersView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingAddReminder = false
  
    var body: some View {
        NavigationView {
            List {
                ForEach($manager.reminders) { $reminder in
                    HStack {
                        Image(systemName: reminder.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(reminder.isDone ? .goodGreen : .textGray)
                            .onTapGesture {
                                reminder.isDone.toggle()
                                manager.saveReminders()
                            }
                        VStack(alignment: .leading) {
                            Text(reminder.title)
                                .strikethrough(reminder.isDone)
                            if !reminder.isDone {
                                Text(reminder.dueDate, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { manager.reminders.remove(atOffsets: $0); manager.saveReminders() }
            }
            .listStyle(.plain)
            .navigationTitle("Reminders")
            .background(Color.background.ignoresSafeArea())
            .toolbar {
                Button(action: { showingAddReminder = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView()
            }
        }
    }
}

struct AddReminderView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var dueDate = Date().addingTimeInterval(86400)
    @State private var repeatInterval: RepeatInterval = .none
  
    var body: some View {
        NavigationView {
            Form {
                TextField("Reminder title", text: $title)
                DatePicker("Due date", selection: $dueDate)
                Picker("Repeat", selection: $repeatInterval) {
                    ForEach(RepeatInterval.allCases, id: \.self) { Text($0.rawValue) }
                }
            }
            .navigationTitle("New Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let reminder = Reminder(title: title, dueDate: dueDate, repeatInterval: repeatInterval)
                        manager.reminders.append(reminder)
                        manager.saveReminders()
                        scheduleNotification(for: reminder)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
  
    func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "Farm inventory reminder"
        content.sound = .default
      
        var dateComponents: DateComponents?
        let calendar = Calendar.current
      
        switch reminder.repeatInterval {
        case .none:
            dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        case .daily:
            dateComponents = calendar.dateComponents([.hour, .minute], from: reminder.dueDate)
        case .weekly:
            dateComponents = calendar.dateComponents([.weekday, .hour, .minute], from: reminder.dueDate)
        case .monthly:
            dateComponents = calendar.dateComponents([.day, .hour, .minute], from: reminder.dueDate)
        }
      
        if let components = dateComponents {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: reminder.repeatInterval != .none)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension View {
    @ViewBuilder func conditionalScrollContentBackground(_ visibility: Visibility) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(visibility)
        } else {
            self
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingHen = false
  
    var body: some View {
        NavigationView {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                List {
                    NavigationLink("Manage Categories") {
                        CategoriesManagementView()
                    }
                  
                    Button("Reset all data") {
                        manager.items = []
                        manager.reminders = []
                        manager.saveItems()
                        manager.saveReminders()
                    }
                  
                    HStack {
                        Text("App version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                  
                    HStack {
                        Text("Hen Approved! 🥚💛")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.accent)
                    }
                    .onLongPressGesture(minimumDuration: 2.0) {
                        withAnimation {
                            showingHen = true
                        }
                    }
                    .alert("Hen Approved! 🥚💛", isPresented: $showingHen) {
                        Button("OK") { }
                    }
                }
                .listStyle(.insetGrouped)
                .conditionalScrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
        }
    }
}

struct CategoriesManagementView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingAddCategory = false
  
    var body: some View {
        List {
            ForEach(manager.categories) { category in
                HStack {
                    Text(category.icon)
                    Text(category.name)
                    Spacer()
                    Circle()
                        .fill(category.color)
                        .frame(width: 30, height: 30)
                }
                .padding(.vertical, 4)
            }
            .onDelete { manager.categories.remove(atOffsets: $0); manager.saveCategories() }
        }
        .listStyle(.plain)
        .navigationTitle("Categories")
        .background(Color.background.ignoresSafeArea())
        .toolbar {
            Button("Add") { showingAddCategory = true }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
    }
}

struct AddCategoryView: View {
    @EnvironmentObject var manager: InventoryManager
    @Environment(\.presentationMode) var presentationMode
  
    @State private var name = ""
    @State private var icon = "📌"
    @State private var selectedColor = Color(hex: "6B6B6B")
  
    var body: some View {
        NavigationView {
            Form {
                TextField("Category name", text: $name)
                TextField("Icon (emoji)", text: $icon)
                    .frame(maxWidth: 80)
                ColorPicker("Color", selection: $selectedColor)
            }
            .navigationTitle("New Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let hex = selectedColor.toHex ?? "6B6B6B"
                        let newCat = Category(name: name, icon: icon, colorHex: hex)
                        manager.categories.append(newCat)
                        manager.saveCategories()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(name.isEmpty || icon.isEmpty)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(InventoryManager())
}
