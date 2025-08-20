import Foundation
import UIKit

struct AppVersionInfo {
    let currentVersion: String
    let latestVersion: String
    let updateAvailable: Bool
    let appStoreURL: String
}

final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()
    
    @Published var updateInfo: AppVersionInfo?
    @Published var showUpdateAlert = false
    
    private let userDefaults = UserDefaults.standard
    private let lastUpdateCheckKey = "lastUpdateCheckDate"
    
    private init() {}
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    func checkForUpdatesIfNeeded() {
        guard shouldCheckForUpdates() else { return }
        
        Task {
            await checkForUpdates()
        }
    }
    
    private func shouldCheckForUpdates() -> Bool {
        guard let lastCheckDate = userDefaults.object(forKey: lastUpdateCheckKey) as? Date else {
            return true // First time checking
        }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Check if it's a different day
        return !calendar.isDate(lastCheckDate, inSameDayAs: today)
    }
    
    private func saveLastCheckDate() {
        userDefaults.set(Date(), forKey: lastUpdateCheckKey)
    }
    
    @MainActor
    func checkForUpdates() async {
        saveLastCheckDate()
        
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleID)"
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(AppStoreResponse.self, from: data)
            
            guard let appInfo = response.results.first else { return }
            
            let latestVersion = appInfo.version
            let updateAvailable = isUpdateAvailable(current: currentVersion, latest: latestVersion)
            
            let info = AppVersionInfo(
                currentVersion: currentVersion,
                latestVersion: latestVersion,
                updateAvailable: updateAvailable,
                appStoreURL: appInfo.trackViewUrl
            )
            
            self.updateInfo = info
            
            if updateAvailable {
                self.showUpdateAlert = true
            }
            
        } catch {
            print("Failed to check for updates: \(error)")
        }
    }
    
    private func isUpdateAvailable(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxLength {
            let currentVersion = i < currentComponents.count ? currentComponents[i] : 0
            let latestVersion = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestVersion > currentVersion {
                return true
            } else if latestVersion < currentVersion {
                return false
            }
        }
        
        return false
    }
    
    func openAppStore() {
        guard let info = updateInfo,
              let url = URL(string: info.appStoreURL) else { return }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - App Store Response Models
private struct AppStoreResponse: Codable {
    let results: [AppStoreResult]
}

private struct AppStoreResult: Codable {
    let version: String
    let trackViewUrl: String
}
