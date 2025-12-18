import Foundation
import Combine
import Network
import UserNotifications
import AppsFlyerLib
import FirebaseMessaging
import Firebase

final class HarvestBoxPresenter: ObservableObject {
    @Published var currentHarvestPhase: HarvestPhase = .setup
    @Published var harvestURL: URL?
    @Published var displayPermView = false
    
    private var trackingData: [String: Any] = [:]
    private var linkData: [String: Any] = [:]
    private var cancellables = Set<AnyCancellable>()
    private let networkWatcher = NWPathMonitor()
    private let repo: HarvestRepository
    
    init(repo: HarvestRepository = HarvestRepositoryImpl()) {
        self.repo = repo
        configureListeners()
        monitorNetwork()
    }
    
    deinit {
        networkWatcher.cancel()
    }
    
    private func configureListeners() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { [weak self] data in
                self?.trackingData = data
                self?.assessMode()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { [weak self] data in
                self?.linkData = data
            }
            .store(in: &cancellables)
    }
    
    private func isDateValid() -> Bool {
        let currentCalendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 12
        dateComponents.day = 21
        if let comparisonDate = currentCalendar.date(from: dateComponents) {
            return Date() >= comparisonDate
        }
        return false
    }
    
    @objc private func assessMode() {
        if !isDateValid() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.activateLegacy()
            }
            return
        }
        
        if trackingData.isEmpty {
            retrieveCachedPath()
            return
        }
        
        if repo.retrieveAppState() == "Inactive" {
            activateLegacy()
            return
        }
        
        let assessor = AssessCurrentModeUseCase(repo: repo)
        let mode = assessor.perform(trackingData: trackingData, initial: repo.isInitialRun, currentURL: harvestURL, interimURL: UserDefaults.standard.string(forKey: "temp_url"))
        
        if mode == .setup && repo.isInitialRun {
            startInitialSequence()
            return
        }
        
        if let pathStr = UserDefaults.standard.string(forKey: "temp_url"),
           let path = URL(string: pathStr) {
            harvestURL = path
            assignMode(to: .operational)
            return
        }
        
        if harvestURL == nil {
            let checker = CheckPermPromptUseCase(repo: repo)
            if checker.perform() {
                displayPermView = true
            } else {
                retrievePathConfig()
            }
        }
    }
    
    func processSkipPerm() {
        let processor = ProcessSkipPermUseCase(repo: repo)
        processor.perform()
        displayPermView = false
        retrievePathConfig()
    }
    
    func processGrantPerm() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] accepted, _ in
            DispatchQueue.main.async {
                let processor = ProcessGrantPermUseCase(repo: self?.repo ?? HarvestRepositoryImpl())
                processor.perform(accepted: accepted)
                if accepted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self?.displayPermView = false
                if self?.harvestURL != nil {
                    self?.assignMode(to: .operational)
                } else {
                    self?.retrievePathConfig()
                }
            }
        }
    }
    
    private func startInitialSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { [weak self] in
                await self?.retrieveOrganicTracking()
            }
        }
    }
    
    private func activateLegacy() {
        let activator = ActivateLegacyUseCase(repo: repo)
        activator.perform()
        assignMode(to: .legacy)
    }
    
    private func retrieveCachedPath() {
        let retriever = RetrieveCachedPathUseCase(repo: repo)
        if let path = retriever.perform() {
            harvestURL = path
            assignMode(to: .operational)
        } else {
            activateLegacy()
        }
    }
    
    private func cacheSuccessfulPath(_ path: String, targetURL: URL) {
        let cacher = CacheSuccessfulPathUseCase(repo: repo)
        cacher.perform(path: path)
        let checker = CheckPermPromptUseCase(repo: repo)
        if checker.perform() {
            harvestURL = targetURL
            displayPermView = true
        } else {
            harvestURL = targetURL
            assignMode(to: .operational)
        }
    }
    
    private func assignMode(to mode: HarvestPhase) {
        DispatchQueue.main.async {
            self.currentHarvestPhase = mode
        }
    }
    
    private func monitorNetwork() {
        networkWatcher.pathUpdateHandler = { [weak self] path in
            if path.status != .satisfied {
                DispatchQueue.main.async {
                    if self?.repo.retrieveAppState() == "HarvestView" {
                        self?.assignMode(to: .disconnected)
                    } else {
                        self?.activateLegacy()
                    }
                }
            }
        }
        networkWatcher.start(queue: .global())
    }
    
    private func retrieveOrganicTracking() async {
        do {
            let retriever = RetrieveOrganicTrackingUseCase(repo: repo)
            let merged = try await retriever.perform(linkData: linkData)
            await MainActor.run {
                self.trackingData = merged
                self.retrievePathConfig()
            }
        } catch {
            activateLegacy()
        }
    }
    
    private func retrievePathConfig() {
        Task { [weak self] in
            do {
                let retriever = RetrievePathConfigUseCase(repo: self?.repo ?? HarvestRepositoryImpl())
                let targetURL = try await retriever.perform(trackingData: self?.trackingData ?? [:])
                let pathStr = targetURL.absoluteString
                await MainActor.run {
                    self?.cacheSuccessfulPath(pathStr, targetURL: targetURL)
                }
            } catch {
                self?.retrieveCachedPath()
            }
        }
    }
}
