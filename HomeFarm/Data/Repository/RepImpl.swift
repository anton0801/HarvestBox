import Foundation
import AppsFlyerLib
import Firebase
import FirebaseMessaging

class HarvestRepositoryImpl: HarvestRepository {
    private let defaults: UserDefaults
    private let tracker: AppsFlyerLib
    
    init(defaults: UserDefaults = .standard, tracker: AppsFlyerLib = .shared()) {
        self.defaults = defaults
        self.tracker = tracker
    }
    
    var isInitialRun: Bool {
        !defaults.bool(forKey: "hasRunPreviously")
    }
    
    func retrieveStoredPath() -> URL? {
        if let stored = defaults.string(forKey: "stored_path"),
           let url = URL(string: stored) {
            return url
        }
        return nil
    }
    
    func storePath(_ url: String) {
        defaults.set(url, forKey: "stored_path")
    }
    
    func updateAppState(_ state: String) {
        defaults.set(state, forKey: "app_state")
    }
    
    func markAsRun() {
        defaults.set(true, forKey: "hasRunPreviously")
    }
    
    func retrieveAppState() -> String? {
        defaults.string(forKey: "app_state")
    }
    
    func updateLastPermRequest(_ date: Date) {
        defaults.set(date, forKey: "last_perm_request")
    }
    
    func updatePermsAccepted(_ accepted: Bool) {
        defaults.set(accepted, forKey: "perms_accepted")
    }
    
    func updatePermsDenied(_ denied: Bool) {
        defaults.set(denied, forKey: "perms_denied")
    }
    
    func retrievePermsAccepted() -> Bool {
        defaults.bool(forKey: "perms_accepted")
    }
    
    func retrievePermsDenied() -> Bool {
        defaults.bool(forKey: "perms_denied")
    }
    
    func retrieveLastPermRequest() -> Date? {
        defaults.object(forKey: "last_perm_request") as? Date
    }
    
    func retrievePushToken() -> String? {
        defaults.string(forKey: "push_token") ?? Messaging.messaging().fcmToken
    }
    
    func retrieveLanguageCode() -> String {
        Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
    }
    
    func retrieveAppIdentifier() -> String {
        "com.helpharvestb.HarvestBox"
    }
    
    func retrieveFirebaseID() -> String? {
        FirebaseApp.app()?.options.gcmSenderID
    }
    
    func retrieveAppStoreID() -> String {
        "id\(AppConstants.appsFlyerAppID)"
    }
    
    func retrieveTrackingID() -> String {
        tracker.getAppsFlyerUID()
    }
    
    func retrieveOrganicData(linkData: [String: Any]) async throws -> [String: Any] {
        let builder = HarvestTrackerBuilder()
            .assignAppID(AppConstants.appsFlyerAppID)
            .assignDevKey(AppConstants.appsFlyerDevKey)
            .assignUID(retrieveTrackingID())
            .generate()
        
        guard let url = builder else {
            throw NSError(domain: "TrackingError", code: 0)
        }
        
        let (data, resp) = try await URLSession.shared.data(from: url)
        
        guard let httpResp = resp as? HTTPURLResponse,
              httpResp.statusCode == 200,
              let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "TrackingError", code: 1)
        }
        
        var merged = jsonData
        for (k, v) in linkData where merged[k] == nil {
            merged[k] = v
        }
        
        return merged
    }
    
    func retrieveServerPath(data: [String: Any]) async throws -> URL {
        guard let endpoint = URL(string: "https://harrvestbox.com/config.php") else {
            throw NSError(domain: "PathError", code: 0)
        }
        
        var requestData = data
        requestData["os"] = "iOS"
        requestData["af_id"] = retrieveTrackingID()
        requestData["bundle_id"] = retrieveAppIdentifier()
        requestData["firebase_project_id"] = retrieveFirebaseID()
        requestData["store_id"] = retrieveAppStoreID()
        requestData["push_token"] = retrievePushToken()
        requestData["locale"] = retrieveLanguageCode()
        
        guard let body = try? JSONSerialization.data(withJSONObject: requestData) else {
            throw NSError(domain: "PathError", code: 1)
        }
        
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        
        let (responseData, _) = try await URLSession.shared.data(for: req)
        
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let success = json["ok"] as? Bool, success,
              let pathStr = json["url"] as? String,
              let pathURL = URL(string: pathStr) else {
            throw NSError(domain: "PathError", code: 2)
        }
        
        return pathURL
    }
}


struct StartInitialSequenceUseCase {
    func perform() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
    }
}

struct ActivateLegacyUseCase {
    let repo: HarvestRepository
    
    func perform() {
        repo.updateAppState("Inactive")
        repo.markAsRun()
    }
}

struct RetrieveCachedPathUseCase {
    let repo: HarvestRepository
    
    func perform() -> URL? {
        repo.retrieveStoredPath()
    }
}

struct CacheSuccessfulPathUseCase {
    let repo: HarvestRepository
    
    func perform(path: String) {
        repo.storePath(path)
        repo.updateAppState("HarvestView")
        repo.markAsRun()
    }
}
