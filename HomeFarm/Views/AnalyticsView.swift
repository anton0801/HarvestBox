import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var manager: InventoryManager
  
    private var goodCount: Int { manager.items.filter { $0.status == .good }.count }
    private var repairCount: Int { manager.items.filter { $0.status == .needsRepair }.count }
    private var outCount: Int { manager.items.filter { $0.status == .outOfStock }.count }
    private var totalCount: Int { manager.items.count }
    
    // For pie chart
    var statusData: [StatusData] {
        [
            StatusData(status: "Good", count: goodCount),
            StatusData(status: "Repair", count: repairCount),
            StatusData(status: "Out of Stock", count: outCount)
        ]
    }
    
    // For monthly chart
    var monthlyData: [MonthlyData] {
        manager.addedItemsPerMonth().map { MonthlyData(month: $0.month, count: $0.count) }
    }
  
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 30) {
                    // Overall Status
                    VStack(spacing: 16) {
                        Text("Overall Status")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        
                        if totalCount == 0 {
                            PlaceholderView(icon: "chart.pie", title: "No Items Yet", subtitle: "Add items to see status")
                        } else {
                            HStack(spacing: 40) {
                                StatusCircle(count: totalCount, color: .goodGreen, label: "Good", value: goodCount)
                                StatusCircle(count: totalCount, color: .warningOrange, label: "Repair", value: repairCount)
                                StatusCircle(count: totalCount, color: .criticalRed, label: "Out of stock", value: outCount)
                            }
                            
                            // Added Pie Chart
                            if #available(iOS 17.0, *) {
                                Chart(statusData) {
                                    SectorMark(
                                        angle: .value("Count", $0.count),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(by: .value("Status", $0.status))
                                }
                                .frame(height: 200)
                                .chartLegend(.hidden)
                            }
                        }
                        
                        if !manager.categories.isEmpty {
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
                    }
                    .padding()
                    .background(Color.cardWhite)
                    .cornerRadius(20)
                    .padding(.horizontal)
                  
                    // Total Items
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
                    
                    // Monthly Graph
                    VStack(spacing: 16) {
                        Text("Added Items Per Month")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        if monthlyData.isEmpty {
                            PlaceholderView(icon: "chart.bar", title: "No Data", subtitle: "Add items to see monthly trends")
                        } else if #available(iOS 16.0, *) {
                            Chart(monthlyData) {
                                BarMark(
                                    x: .value("Month", $0.month),
                                    y: .value("Count", $0.count)
                                )
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(Color.cardWhite)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Predictions
                    VStack(spacing: 16) {
                        Text("Predicted Out of Stock")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        if manager.predictedOutOfStock().isEmpty {
                            PlaceholderView(icon: "exclamationmark.triangle", title: "No Predictions", subtitle: "Update item statuses for predictions")
                        } else {
                            ForEach(manager.predictedOutOfStock()) { item in
                                Text(item.name)
                            }
                        }
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

// Placeholder View for empty states
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.textGray.opacity(0.5))
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.textGray)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.textGray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// For Charts
struct StatusData: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
}

struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String
    let count: Int
}

struct StatusCircle: View {
    let count: Int
    let color: Color
    let label: String
    let value: Int
    @State private var progress: Double = 0.0  // For animation
  
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if #available(iOS 15.0, *) {
                    ProgressView(value: progress, total: 1.0)  // Used ProgressView
                        .progressViewStyle(.circular)
                        .tint(color)
                        .scaleEffect(2.5)
                        .frame(width: 100, height: 100)
                } else {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 100, height: 100)
                }
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
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                progress = Double(value) / Double(count)
            }
        }
    }
}

struct HarvestPermView: View {
    let onAllow: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            ZStack {
                Image(isLandscape ? "harvest_box_bg_landscape" : "harvest_box_back")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                VStack(spacing: isLandscape ? 5 : 10) {
                    Spacer()
                    
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("BagelFatOne-Regular", size: 20))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("BagelFatOne-Regular", size: 15))
                        .foregroundColor(Color(hex: "#BABABA"))
                        .padding(.horizontal, 52)
                        .multilineTextAlignment(.center)
                    
                    Button(action: onAllow) {
                        Image("button_app_harvest")
                            .resizable()
                            .frame(height: 60)
                    }
                    .frame(width: 350)
                    .padding(.top, 12)
                    
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.custom("BagelFatOne-Regular", size: 15))
                            .foregroundColor(Color(hex: "#BABABA"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 320)
                    
                    Spacer()
                        .frame(height: isLandscape ? 30 : 50)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
        }
        .ignoresSafeArea()
    }
}


#Preview {
    AnalyticsView()
}
