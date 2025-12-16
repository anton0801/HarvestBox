import Foundation
import Combine
import Network
import UserNotifications
import AppsFlyerLib
import FirebaseMessaging
import Firebase

struct AssessCurrentModeUseCase {
    let repo: HarvestRepository
    
    func perform(trackingData: [String: Any], initial: Bool, currentURL: URL?, interimURL: String?) -> HarvestPhase {
        if trackingData.isEmpty {
            return .legacy
        }
        
        if repo.retrieveAppState() == "Inactive" {
            return .legacy
        }
        
        if initial && (trackingData["af_status"] as? String == "Organic") {
            return .setup
        }
        
        if let interim = interimURL, let url = URL(string: interim), currentURL == nil {
            return .operational
        }
        
        return .setup
    }
}

struct CheckPermPromptUseCase {
    let repo: HarvestRepository
    
    func perform() -> Bool {
        guard !repo.retrievePermsAccepted(),
              !repo.retrievePermsDenied() else {
            return false
        }
        
        if let previous = repo.retrieveLastPermRequest(),
           Date().timeIntervalSince(previous) < 259200 {
            return false
        }
        return true
    }
}

struct ProcessSkipPermUseCase {
    let repo: HarvestRepository
    
    func perform() {
        repo.updateLastPermRequest(Date())
    }
}

struct ProcessGrantPermUseCase {
    let repo: HarvestRepository
    
    func perform(accepted: Bool) {
        repo.updatePermsAccepted(accepted)
        if !accepted {
            repo.updatePermsDenied(true)
        }
    }
}

struct RetrieveOrganicTrackingUseCase {
    let repo: HarvestRepository
    
    func perform(linkData: [String: Any]) async throws -> [String: Any] {
        try await repo.retrieveOrganicData(linkData: linkData)
    }
}

struct RetrievePathConfigUseCase {
    let repo: HarvestRepository
    
    func perform(trackingData: [String: Any]) async throws -> URL {
        try await repo.retrieveServerPath(data: trackingData)
    }
}

enum HarvestPhase { case setup, operational, legacy, disconnected }

struct HarvestTrackerBuilder {
    private var appID = ""
    private var devKey = ""
    private var uid = ""
    private let endpoint = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    
    func assignAppID(_ id: String) -> Self { duplicate(appID: id) }
    func assignDevKey(_ key: String) -> Self { duplicate(devKey: key) }
    func assignUID(_ id: String) -> Self { duplicate(uid: id) }
    
    func generate() -> URL? {
        guard !appID.isEmpty, !devKey.isEmpty, !uid.isEmpty else { return nil }
        var parts = URLComponents(string: endpoint + "id" + appID)!
        parts.queryItems = [
            URLQueryItem(name: "devkey", value: devKey),
            URLQueryItem(name: "device_id", value: uid)
        ]
        return parts.url
    }
    
    private func duplicate(appID: String = "", devKey: String = "", uid: String = "") -> Self {
        var instance = self
        if !appID.isEmpty { instance.appID = appID }
        if !devKey.isEmpty { instance.devKey = devKey }
        if !uid.isEmpty { instance.uid = uid }
        return instance
    }
}
