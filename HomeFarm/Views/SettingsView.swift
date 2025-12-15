import SwiftUI
import StoreKit


struct SettingsView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingHen = false
    
    @Environment(\.requestReview) var rateUs
  
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
                    
                    Button("Privacy policy") {
                        UIApplication.shared.open(URL(string: "https://harrvestbox.com/privacy-policy.html")!)
                    }
                    
                    Button("Rate US") {
                        rateUs()
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



#Preview {
    SettingsView()
}
