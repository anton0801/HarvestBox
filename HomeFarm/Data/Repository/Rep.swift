import Foundation

protocol HarvestRepository {
    var isInitialRun: Bool { get }
    func retrieveStoredPath() -> URL?
    func storePath(_ url: String)
    func updateAppState(_ state: String)
    func markAsRun()
    func retrieveAppState() -> String?
    func updateLastPermRequest(_ date: Date)
    func updatePermsAccepted(_ accepted: Bool)
    func updatePermsDenied(_ denied: Bool)
    func retrievePermsAccepted() -> Bool
    func retrievePermsDenied() -> Bool
    func retrieveLastPermRequest() -> Date?
    func retrievePushToken() -> String?
    func retrieveLanguageCode() -> String
    func retrieveAppIdentifier() -> String
    func retrieveFirebaseID() -> String?
    func retrieveAppStoreID() -> String
    func retrieveTrackingID() -> String
    func retrieveOrganicData(linkData: [String: Any]) async throws -> [String: Any]
    func retrieveServerPath(data: [String: Any]) async throws -> URL
}
