import SwiftUI

struct ContentView: View {
    @StateObject private var manager = InventoryManager()
    @State private var showTutorial = false
    
    var body: some View {
        ZStack {
            MainTabView()
                .environmentObject(manager)
                .preferredColorScheme(.light)
                .tint(.accent)
                .onAppear {
                    UIScrollView.appearance().backgroundColor = UIColor(Color.background)
                    UITableView.appearance().backgroundColor = UIColor(Color.background)
                    UITableViewCell.appearance().backgroundColor = UIColor.clear
                    UITableView.appearance().separatorStyle = .none
                    
                    if manager.items.isEmpty {
                        showTutorial = true
                    }
                }
                .sheet(isPresented: $showTutorial) {
                    TutorialView {
                        showTutorial = false
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
