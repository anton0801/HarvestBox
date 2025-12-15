import SwiftUI
import Combine
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

class HarvestFarmAppDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var harvestTrackingDeeplinksData: [AnyHashable: Any] = [:]
    private var harvestConversion: [AnyHashable: Any] = [:]
    
    private let trackingSentKey = "trackingDataSent"
    
    private var dataCombineTimer: Timer?
    
    func application(_ app: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
        
        if let notificationInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            paraseForAdditionalDataInTheHarvestPush(notificationInfo)
        }
        
        setUpAppsflyer()
        startAppsflyer()
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    private func startAppsflyer() {
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activateTrackMonitoring),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func activateTrackMonitoring() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                }
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        paraseForAdditionalDataInTheHarvestPush(response.notification.request.content.userInfo)
        completionHandler()
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        paraseForAdditionalDataInTheHarvestPush(userInfo)
        completionHandler(.newData)
    }
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        harvestConversion = data
        initiateCombineTimer()
        if !harvestTrackingDeeplinksData.isEmpty {
            sendAllData()
        }
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let linkObject = result.deepLink else { return }
        guard !UserDefaults.standard.bool(forKey: trackingSentKey) else { return }
        harvestTrackingDeeplinksData = linkObject.clickEvent
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": harvestTrackingDeeplinksData])
        dataCombineTimer?.invalidate()
        if !harvestConversion.isEmpty {
            sendAllData()
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let activeToken = token else { return }
            UserDefaults.standard.set(activeToken, forKey: "fcm_token")
            UserDefaults.standard.set(activeToken, forKey: "push_token")
        }
    }
    
    
    private func initiateCombineTimer() {
        dataCombineTimer?.invalidate()
        dataCombineTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.sendAllData()
        }
    }
    
    func onConversionDataFail(_ error: Error) {
        sendInfo(data: [:])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let infoPayload = notification.request.content.userInfo
        paraseForAdditionalDataInTheHarvestPush(infoPayload)
        completionHandler([.banner, .sound])
    }
    
}

extension HarvestFarmAppDelegate {
    
    
    private func sendAllData() {
        var combinedData = harvestConversion
        for (k, v) in harvestTrackingDeeplinksData {
            if combinedData[k] == nil {
                combinedData[k] = v
            }
        }
        sendInfo(data: combinedData)
        UserDefaults.standard.set(true, forKey: trackingSentKey)
    }
    
}

extension HarvestFarmAppDelegate {
    
    
    func sendInfo(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
}

extension HarvestFarmAppDelegate {
    
    
    func setUpAppsflyer() {
        AppsFlyerLib.shared().appleAppID = HarvestConstants.appsFlyerAppID
        AppsFlyerLib.shared().appsFlyerDevKey = HarvestConstants.appsFlyerDevKey
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
    }
    
}


extension HarvestFarmAppDelegate {
    
    func paraseForAdditionalDataInTheHarvestPush(_ info: [AnyHashable: Any]) {
        var harvestL: String?
        if let link = info["url"] as? String {
            harvestL = link
        } else if let subInfo = info["data"] as? [String: Any],
                  let subLink = subInfo["url"] as? String {
            harvestL = subLink
        }
        if let harvestData = harvestL {
            UserDefaults.standard.set(harvestData, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTempURL"),
                    object: nil,
                    userInfo: ["temp_url": harvestData]
                )
            }
        }
    }
    
}
