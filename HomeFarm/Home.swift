
import SwiftUI
import UserNotifications
import Charts
import Combine

struct HarvestConstants {
    static let appsFlyerAppID = "6756317171"
    static let appsFlyerDevKey = "QZzkkBwYe7GhXuFd8Ks5qP"
}

struct AppConstants {
    static let appsFlyerAppID = "6756317171"
    static let appsFlyerDevKey = "QZzkkBwYe7GhXuFd8Ks5qP"
}

struct CategoryCard: View {
    let category: Category
    let count: Int
    @State private var isTapped = false
  
    var body: some View {
        VStack(spacing: 12) {
            Text(category.icon)
                .font(.system(size: 60))
            Text(category.name)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.textGray)
            Text("\(count) items")
                .font(.system(.body, design: .rounded))
                .foregroundColor(.textGray.opacity(0.8))
        }
        .frame(height: 160)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(gradient: Gradient(colors: [category.color.opacity(0.1), .clear]), startPoint: .top, endPoint: .bottom)  // Gradient background
        )
        .background(Color.cardWhite)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
        .scaleEffect(isTapped ? 1.05 : 1.0)  // Scale effect
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTapped)
        .onTapGesture {
            isTapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTapped = false
            }
        }
        .hoverEffect(.lift)  // Hover effect for iPad/macOS
    }
}

@main
struct FarmInventoryApp: App {
  
    @UIApplicationDelegateAdaptor(HarvestFarmAppDelegate.self) var harvestFarmAppDelegate
    
    var body: some Scene {
        WindowGroup {
            HarvestBoxSplashView()
        }
    }
}

struct TutorialView: View {
    let onDismiss: () -> Void
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            // Page 1: Welcome
            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.accent)
                Text("Welcome to Harvest Box!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.accent)
                Text("Your ultimate farm inventory manager.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .tag(0)
            .padding()
            
            // Page 2: Inventory
            VStack(spacing: 20) {
                Image(systemName: "tray.full.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.goodGreen)
                Text("Manage Your Inventory")
                    .font(.title.bold())
                Text("Add, edit, and track items in categories like tools and feeds.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .tag(1)
            .padding()
            
            // Page 3: Reminders
            VStack(spacing: 20) {
                Image(systemName: "bell.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.warningOrange)
                Text("Set Reminders")
                    .font(.title.bold())
                Text("Never forget maintenance or restocking with customizable reminders.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .tag(2)
            .padding()
            
            // Page 4: Statistics
            VStack(spacing: 20) {
                Image(systemName: "chart.pie.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.criticalRed)
                Text("View Statistics")
                    .font(.title.bold())
                Text("Get insights on your inventory status and trends.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .tag(3)
            .padding()
            
            // Page 5: Get Started
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.goodGreen)
                Text("Ready to Start?")
                    .font(.title.bold())
                Button("Get Started") {
                    onDismiss()
                }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding()
                .background(Color.accent)
                .cornerRadius(10)
            }
            .tag(4)
            .padding()
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page)
        .background(Color.background)
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


#Preview {
    MainTabView()
        .environmentObject(InventoryManager())
}
