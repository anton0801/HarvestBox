import Foundation
import Combine
import Network
import UserNotifications
import AppsFlyerLib
import FirebaseMessaging
import Firebase
import FirebaseMessaging

struct HarvestConfigEntity {
    let url: URL
}

enum HarvestPhaseEntity {
    case initPhase, runningPhase, legacyPhase, noConnectionPhase
}

struct AnalyticsEntity {
    let data: [String: Any]
}

struct DeepLinkEntity {
    let info: [String: Any]
}

protocol HarvestViewInterface: AnyObject {
    func setPhase(_ phase: HarvestPhaseEntity)
    func showPermDialog()
    func setConfigURL(_ url: URL?)
    func disapearPermissionsScreen()
}

protocol HarvestPresenterInterface {
    func attachView(_ view: HarvestViewInterface)
    func evaluateCurrentState()
    func onSkipPerm()
    func onGrantPerm()
}

protocol HarvestInteractorInterface {
    func getStoredConfig() -> HarvestConfigEntity?
    func storeConfig(_ entity: HarvestConfigEntity)
    func getAppStatus() -> String?
    func updateAppStatus(_ status: String)
    func isFirstRun() -> Bool
    func markRun()
    func shouldShowPerm() -> Bool
    func processPermSkip()
    func processPermGrant(granted: Bool)
    func fetchOrganicData(deepLink: DeepLinkEntity) async throws -> AnalyticsEntity
    func fetchServerConfig(analytics: AnalyticsEntity) async throws -> HarvestConfigEntity
    func evaluatePhase(analytics: AnalyticsEntity, firstRun: Bool, current: HarvestConfigEntity?, temp: String?) -> HarvestPhaseEntity
}

protocol HarvestRouterInterface {
    // For navigation if needed, but minimal here
}

final class HarvestInteractor: HarvestInteractorInterface {
    private let userDefaults: UserDefaults
    private let appsFlyer: AppsFlyerLib
    
    init(userDefaults: UserDefaults = .standard, appsFlyer: AppsFlyerLib = .shared()) {
        self.userDefaults = userDefaults
        self.appsFlyer = appsFlyer
    }
    
    func isFirstRun() -> Bool {
        !userDefaults.bool(forKey: "hasRunBefore")
    }
    
    func getStoredConfig() -> HarvestConfigEntity? {
        if let str = userDefaults.string(forKey: "harvest_config"),
           let url = URL(string: str) {
            return HarvestConfigEntity(url: url)
        }
        return nil
    }
    
    func storeConfig(_ entity: HarvestConfigEntity) {
        userDefaults.set(entity.url.absoluteString, forKey: "harvest_config")
        updateAppStatus("Active")
        markRun()
    }
    
    func updateAppStatus(_ status: String) {
        userDefaults.set(status, forKey: "harvest_status")
    }
    
    func markRun() {
        userDefaults.set(true, forKey: "hasRunBefore")
    }
    
    func getAppStatus() -> String? {
        userDefaults.string(forKey: "harvest_status")
    }
    
    func shouldShowPerm() -> Bool {
        guard !userDefaults.bool(forKey: "perm_granted"),
              !userDefaults.bool(forKey: "perm_denied") else {
            return false
        }
        if let last = userDefaults.object(forKey: "last_perm_time") as? Date,
           Date().timeIntervalSince(last) < 259200 {
            return false
        }
        return true
    }
    
    func processPermSkip() {
        userDefaults.set(Date(), forKey: "last_perm_time")
    }
    
    func processPermGrant(granted: Bool) {
        userDefaults.set(granted, forKey: "perm_granted")
        if !granted {
            userDefaults.set(true, forKey: "perm_denied")
        }
    }
    
    func fetchOrganicData(deepLink: DeepLinkEntity) async throws -> AnalyticsEntity {
        let builder = HarvestURLBuilder()
            .withAppID(HarvestConstants.appsFlyerAppID)
            .withDevKey(HarvestConstants.appsFlyerDevKey)
            .withUID(appsFlyer.getAppsFlyerUID())
            .construct()
        guard let url = builder else {
            throw NSError(domain: "FetchError", code: 100)
        }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FetchError", code: 101)
        }
        var result = json
        for (k, v) in deepLink.info where result[k] == nil {
            result[k] = v
        }
        return AnalyticsEntity(data: result)
    }
    
    func fetchServerConfig(analytics: AnalyticsEntity) async throws -> HarvestConfigEntity {
        guard let url = URL(string: "https://harrvestbox.com/config.php") else {
            throw NSError(domain: "ConfigFetchError", code: 200)
        }
        var params = analytics.data
        params["platform"] = "iOS"
        params["tracker_id"] = appsFlyer.getAppsFlyerUID()
        params["app_bundle"] = "com.helpharvestb.HarvestBox"
        params["firebase_id"] = FirebaseApp.app()?.options.gcmSenderID
        params["store_identifier"] = "id\(HarvestConstants.appsFlyerAppID)"
        params["token_push"] = userDefaults.string(forKey: "harvest_token") ?? Messaging.messaging().fcmToken
        params["lang"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        guard let body = try? JSONSerialization.data(withJSONObject: params) else {
            throw NSError(domain: "ConfigFetchError", code: 201)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ok = json["ok"] as? Bool, ok,
              let urlStr = json["url"] as? String,
              let configURL = URL(string: urlStr) else {
            throw NSError(domain: "ConfigFetchError", code: 202)
        }
        return HarvestConfigEntity(url: configURL)
    }
    
    func evaluatePhase(analytics: AnalyticsEntity, firstRun: Bool, current: HarvestConfigEntity?, temp: String?) -> HarvestPhaseEntity {
        if analytics.data.isEmpty {
            return .legacyPhase
        }
        if getAppStatus() == "Inactive" {
            return .legacyPhase
        }
        if firstRun && (analytics.data["af_status"] as? String == "Organic") {
            return .initPhase
        }
        if let t = temp, let _ = URL(string: t), current == nil {
            return .runningPhase
        }
        return .initPhase
    }
}

final class HarvestPresenter: HarvestPresenterInterface {
    weak var view: HarvestViewInterface?
    private let interactor: HarvestInteractorInterface
    private let router: HarvestRouterInterface? // Optional if no routing
    private var currentConfig: HarvestConfigEntity?
    private var analytics: AnalyticsEntity = AnalyticsEntity(data: [:])
    private var deepLink: DeepLinkEntity = DeepLinkEntity(info: [:])
    private var subs = Set<AnyCancellable>()
    private let netMonitor = NWPathMonitor()
    
    init(interactor: HarvestInteractorInterface, router: HarvestRouterInterface? = nil) {
        self.interactor = interactor
        self.router = router
        setupNotifications()
        setupNetMonitor()
    }
    
    func attachView(_ view: HarvestViewInterface) {
        self.view = view
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { [weak self] data in
                self?.analytics = AnalyticsEntity(data: data)
                self?.evaluateCurrentState()
            }
            .store(in: &subs)
        
        NotificationCenter.default.publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { [weak self] data in
                self?.deepLink = DeepLinkEntity(info: data)
            }
            .store(in: &subs)
    }
    
    func evaluateCurrentState() {
        if analytics.data.isEmpty {
            loadConfigFromStorage()
            return
        }
        if interactor.getAppStatus() == "Inactive" {
            enableLegacyMode()
            return
        }
        let phase = interactor.evaluatePhase(analytics: analytics, firstRun: interactor.isFirstRun(), current: currentConfig, temp: UserDefaults.standard.string(forKey: "temp_url"))
        if phase == .initPhase && interactor.isFirstRun() {
            startInitSequence()
            return
        }
        if let tempStr = UserDefaults.standard.string(forKey: "temp_url"),
           let tempURL = URL(string: tempStr) {
            currentConfig = HarvestConfigEntity(url: tempURL)
            view?.setConfigURL(tempURL)
            updatePhase(.runningPhase)
            return
        }
        if currentConfig == nil {
            if interactor.shouldShowPerm() {
                view?.showPermDialog()
            } else {
                loadServerConfig()
            }
        }
    }
    
    func onSkipPerm() {
        view?.disapearPermissionsScreen()
        interactor.processPermSkip()
        loadServerConfig()
    }
    
    func onGrantPerm() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.interactor.processPermGrant(granted: granted)
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self?.view?.disapearPermissionsScreen()
                if self?.currentConfig != nil {
                    self?.updatePhase(.runningPhase)
                } else {
                    self?.loadServerConfig()
                }
            }
        }
    }
    
    private func startInitSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { [weak self] in
                await self?.loadOrganicData()
            }
        }
    }
    
    private func enableLegacyMode() {
        interactor.updateAppStatus("Inactive")
        interactor.markRun()
        updatePhase(.legacyPhase)
    }
    
    private func loadConfigFromStorage() {
        if let config = interactor.getStoredConfig() {
            currentConfig = config
            view?.setConfigURL(config.url)
            updatePhase(.runningPhase)
        } else {
            enableLegacyMode()
        }
    }
    
    private func cacheConfig(_ str: String, entity: HarvestConfigEntity) {
        interactor.storeConfig(entity)
        if interactor.shouldShowPerm() {
            currentConfig = entity
            view?.setConfigURL(entity.url)
            view?.showPermDialog()
        } else {
            currentConfig = entity
            updatePhase(.runningPhase)
        }
    }
    
    private func updatePhase(_ phase: HarvestPhaseEntity) {
        DispatchQueue.main.async {
            self.view?.setPhase(phase)
        }
    }
    
    private func setupNetMonitor() {
        netMonitor.pathUpdateHandler = { [weak self] path in
            if path.status != .satisfied {
                DispatchQueue.main.async {
                    if self?.interactor.getAppStatus() == "Active" {
                        self?.updatePhase(.noConnectionPhase)
                    } else {
                        self?.enableLegacyMode()
                    }
                }
            }
        }
        netMonitor.start(queue: .global())
    }
    
    private func loadOrganicData() async {
        do {
            let data = try await interactor.fetchOrganicData(deepLink: deepLink)
            await MainActor.run {
                self.analytics = data
                self.loadServerConfig()
            }
        } catch {
            enableLegacyMode()
        }
    }
    
    private func loadServerConfig() {
        Task { [weak self] in
            do {
                let entity = try await self?.interactor.fetchServerConfig(analytics: self?.analytics ?? AnalyticsEntity(data: [:]))
                if let entity = entity {
                    let str = entity.url.absoluteString
                    await MainActor.run {
                        self?.cacheConfig(str, entity: entity)
                    }
                }
            } catch {
                self?.loadConfigFromStorage()
            }
        }
    }
}

struct HarvestURLBuilder {
    private var appID = ""
    private var devKey = ""
    private var uid = ""
    private let endpoint = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    
    func withAppID(_ id: String) -> Self {
        var copy = self
        copy.appID = id
        return copy
    }
    
    func withDevKey(_ key: String) -> Self {
        var copy = self
        copy.devKey = key
        return copy
    }
    
    func withUID(_ id: String) -> Self {
        var copy = self
        copy.uid = id
        return copy
    }
    
    func construct() -> URL? {
        guard !appID.isEmpty, !devKey.isEmpty, !uid.isEmpty else { return nil }
        var comps = URLComponents(string: endpoint + "id" + appID)!
        comps.queryItems = [
            URLQueryItem(name: "devkey", value: devKey),
            URLQueryItem(name: "device_id", value: uid)
        ]
        return comps.url
    }
}

// Router (minimal)
final class HarvestRouter: HarvestRouterInterface {
    // Implement if needed
}
