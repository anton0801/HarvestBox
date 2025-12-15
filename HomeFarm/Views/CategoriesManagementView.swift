import SwiftUI


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


