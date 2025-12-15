
import SwiftUI
import WebKit
import Combine

struct InventoryView: View {
    @EnvironmentObject var manager: InventoryManager
    @State private var showingAddItem = false
    @State private var searchText = ""  // For search
    
    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return manager.categories
        } else {
            return manager.categories.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {  // Adaptive for iPad
                        ForEach(filteredCategories) { cat in
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
            .searchable(text: $searchText, prompt: "Search categories")  // Added searchable
            
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

enum SortOption: String, CaseIterable {
    case name = "Name"
    case status = "Status"
    case date = "Date Added"
}

struct CategoryItemsView: View {
    @EnvironmentObject var manager: InventoryManager
    let categoryName: String
    @State private var showingAddItem = false
    @State private var sortOption: SortOption = .name  // For sorting
  
    private var filteredItems: [Item] {
        var items = manager.items.filter { $0.category == categoryName }
        switch sortOption {
        case .name:
            items.sort { $0.name < $1.name }
        case .status:
            items.sort { $0.status.rawValue < $1.status.rawValue }
        case .date:
            items.sort { $0.addedDate > $1.addedDate }
        }
        return items
    }
  
    var body: some View {
        VStack {
            Picker("Sort by", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            ScrollView {  // Replaced List with ScrollView for custom cards
                VStack(spacing: 12) {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 16) {
                                    Text(item.status == .good ? "✅" : item.status == .needsRepair ? "⚠️" : "❌")
                                        .font(.title2)
                                    Text(item.name)
                                        .font(.system(.headline, design: .rounded))
                                    Spacer()
                                    Text("\(item.quantity) pcs")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(.textGray)
                                }
                                Text(item.status.rawValue)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundColor(.textGray)
                            }
                            .padding()
                            .background(Color.cardWhite)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
            }
        }
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



struct HarvestProgressView: View {
    @State private var animate = false
    
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray4))
                Capsule().fill(.purple)
                    .frame(width: g.size.width * 0.3)
                    .offset(x: animate ? g.size.width : -g.size.width * 0.4)
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: animate)
            }
        }
        .frame(height: 10)
        .cornerRadius(6.5)
        .onAppear { animate = true }
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
        ScrollView {  // Replaced List with ScrollView
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text("Name"); Spacer(); Text(item.name).foregroundColor(.textGray) }
                HStack { Text("Category"); Spacer(); if let cat = manager.categories.first(where: { $0.name == item.category }) { Text("\(cat.icon) \(cat.name)") } }
                HStack { Text("Quantity"); Spacer(); Text("\(item.quantity) pcs") }
                HStack { Text("Status"); Spacer(); Text(item.status.rawValue).foregroundColor(item.status.color).bold() }
                if let date = item.lastUsed {
                    HStack { Text("Last used"); Spacer(); Text(date, style: .date) }
                }
                if !item.note.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Note")
                        Text(item.note)
                    }
                }
                VStack(alignment: .leading) {
                    Text("History")
                    if item.history.isEmpty {
                        Text("No history yet").foregroundColor(.secondary)
                    } else {
                        ForEach(item.history, id: \.date) { entry in
                            Text("\(entry.date.formatted(date: .numeric, time: .shortened)) — \(entry.text)")
                        }
                    }
                }
            }
            .padding()
            .background(Color.cardWhite)
            .cornerRadius(20)  // Added background
            .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
            .padding()
        }
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
#Preview {
    InventoryView()
}

struct HarvestMainView: View {
    
    @State private var activeHarvestLink = ""
    
    var body: some View {
        ZStack {
            if let harvestLink = URL(string: activeHarvestLink) {
                HarvestHostView(harvestLink: harvestLink)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: initHarvestLink)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            if let tempHarvest = UserDefaults.standard.string(forKey: "temp_url"), !tempHarvest.isEmpty {
                activeHarvestLink = tempHarvest
                UserDefaults.standard.removeObject(forKey: "temp_url")
            }
        }
    }
    
    private func initHarvestLink() {
        let tempHarvest = UserDefaults.standard.string(forKey: "temp_url")
        let storedHarvest = UserDefaults.standard.string(forKey: "harvest_config") ?? ""
        activeHarvestLink = tempHarvest ?? storedHarvest
        
        if tempHarvest != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
}

struct HarvestHostView: UIViewRepresentable {
    let harvestLink: URL
    
    @StateObject private var harvestSupervisor = HarvestSupervisor()
    
    func makeCoordinator() -> HarvestNavigationManager {
        HarvestNavigationManager(supervisor: harvestSupervisor)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        harvestSupervisor.setupPrimaryView()
        harvestSupervisor.primaryHarvestView.uiDelegate = context.coordinator
        harvestSupervisor.primaryHarvestView.navigationDelegate = context.coordinator
        
        harvestSupervisor.loadStoredHarvest()
        harvestSupervisor.primaryHarvestView.load(URLRequest(url: harvestLink))
        
        return harvestSupervisor.primaryHarvestView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

class HarvestSupervisor: ObservableObject {
    @Published var primaryHarvestView: WKWebView!
    
    private var subs = Set<AnyCancellable>()
    
    func setupPrimaryView() {
        let config = createHarvestConfig()
        primaryHarvestView = WKWebView(frame: .zero, configuration: config)
        applyHarvestSettings(to: primaryHarvestView)
    }
    
    private func createHarvestConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let prefs = WKPreferences()
        prefs.javaScriptEnabled = true
        prefs.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = prefs
        
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs
        
        return config
    }
    
    private func applyHarvestSettings(to webView: WKWebView) {
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
    }
    
    @Published var additionalHarvestViews: [WKWebView] = []
    
    func loadStoredHarvest() {
        guard let storedHarvest = UserDefaults.standard.object(forKey: "preserved_grains") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        
        let harvestStore = primaryHarvestView.configuration.websiteDataStore.httpCookieStore
        let harvestItems = storedHarvest.values.flatMap { $0.values }.compactMap {
            HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any])
        }
        
        harvestItems.forEach { harvestStore.setCookie($0) }
    }
    
    func revertHarvest(to url: URL? = nil) {
        if !additionalHarvestViews.isEmpty {
            if let lastAdditional = additionalHarvestViews.last {
                lastAdditional.removeFromSuperview()
                additionalHarvestViews.removeLast()
            }
            
            if let targetURL = url {
                primaryHarvestView.load(URLRequest(url: targetURL))
            }
        } else if primaryHarvestView.canGoBack {
            primaryHarvestView.goBack()
        }
    }
    
    func refreshHarvest() {
        primaryHarvestView.reload()
    }
}

class HarvestNavigationManager: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private var redirectCount = 0
    
    init(supervisor: HarvestSupervisor) {
        self.harvestSupervisor = supervisor
        super.init()
    }
    
    private var harvestSupervisor: HarvestSupervisor
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil else { return nil }
        
        let newHarvestView = WKWebView(frame: .zero, configuration: configuration)
        setupNewHarvestView(newHarvestView)
        attachHarvestConstraints(newHarvestView)
        
        harvestSupervisor.additionalHarvestViews.append(newHarvestView)
        
        let edgeSwipeRecognizer = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(processEdgeSwipe))
        edgeSwipeRecognizer.edges = .left
        newHarvestView.addGestureRecognizer(edgeSwipeRecognizer)
        
        func isValidRequest(_ request: URLRequest) -> Bool {
            guard let urlString = request.url?.absoluteString,
                  !urlString.isEmpty,
                  urlString != "about:blank" else { return false }
            return true
        }
        
        if isValidRequest(action.request) {
            newHarvestView.load(action.request)
        }
        
        return newHarvestView
    }
    
    private var lastKnownURL: URL?
    
    private let maxRedirectsPerMinute = 70
    
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    private func setupNewHarvestView(_ webView: WKWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self
        harvestSupervisor.primaryHarvestView.addSubview(webView)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let enhancementScript = """
        (function() {
            const vp = document.createElement('meta');
            vp.name = 'viewport';
            vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(vp);
            
            const rules = document.createElement('style');
            rules.textContent = 'body { touch-action: pan-x pan-y; } input, textarea { font-size: 16px !important; }';
            document.head.appendChild(rules);
            
            document.addEventListener('gesturestart', e => e.preventDefault());
            document.addEventListener('gesturechange', e => e.preventDefault());
        })();
        """
        
        webView.evaluateJavaScript(enhancementScript) { _, error in
            if let error = error { print("Enhancement script failed: \(error)") }
        }
    }
    
    @objc private func processEdgeSwipe(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        guard recognizer.state == .ended,
              let swipedView = recognizer.view as? WKWebView else { return }
        
        if swipedView.canGoBack {
            swipedView.goBack()
        } else if harvestSupervisor.additionalHarvestViews.last === swipedView {
            harvestSupervisor.revertHarvest(to: nil)
        }
    }
    
    private func storeHarvest(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var harvestDict: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            
            for cookie in cookies {
                var domainDict = harvestDict[cookie.domain] ?? [:]
                if let properties = cookie.properties {
                    domainDict[cookie.name] = properties
                }
                harvestDict[cookie.domain] = domainDict
            }
            
            UserDefaults.standard.set(harvestDict, forKey: "preserved_grains")
        }
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects,
           let safeURL = lastKnownURL {
            webView.load(URLRequest(url: safeURL))
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        
        if redirectCount > maxRedirectsPerMinute {
            webView.stopLoading()
            if let safeURL = lastKnownURL {
                webView.load(URLRequest(url: safeURL))
            }
            return
        }
        
        lastKnownURL = webView.url
        storeHarvest(from: webView)
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        lastKnownURL = url
        
        let schemeLower = (url.scheme ?? "").lowercased()
        let urlStringLower = url.absoluteString.lowercased()
        
        let internalSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let internalPrefixes = ["srcdoc", "about:blank", "about:srcdoc"]
        
        let isInternal = internalSchemes.contains(schemeLower) ||
        internalPrefixes.contains { urlStringLower.hasPrefix($0) } ||
        urlStringLower == "about:blank"
        
        if isInternal {
            decisionHandler(.allow)
            return
        }
        
        UIApplication.shared.open(url, options: [:]) { _ in }
        
        decisionHandler(.cancel)
    }
    
    private func attachHarvestConstraints(_ webView: WKWebView) {
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: harvestSupervisor.primaryHarvestView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: harvestSupervisor.primaryHarvestView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: harvestSupervisor.primaryHarvestView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: harvestSupervisor.primaryHarvestView.bottomAnchor)
        ])
    }
}
