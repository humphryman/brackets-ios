//
//  AppUpdateChecker.swift
//  Brackets
//

import Foundation

enum AppUpdateChecker {
    static let appStoreId = "1168249255"

    static var appStoreURL: URL? {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreId)")
    }

    private static let lastCheckedKey = "com.brackets.lastUpdateCheckAt"
    private static let dismissedVersionKey = "com.brackets.lastDismissedVersion"
    private static let dismissedAtKey = "com.brackets.lastDismissedAt"

    private static let twentyFourHours: TimeInterval = 24 * 3600

    static var installedVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Returns the App Store version when it is newer than the installed version
    /// AND the user has not dismissed that same version in the last 24h. Otherwise nil.
    static func checkForUpdate() async -> String? {
        let defaults = UserDefaults.standard

        // Throttle: at most one network lookup per 24h
        if let lastCheck = defaults.object(forKey: lastCheckedKey) as? Date,
           Date().timeIntervalSince(lastCheck) < twentyFourHours {
            return nil
        }

        guard let installed = installedVersion,
              let storeVersion = await fetchStoreVersion() else {
            return nil
        }

        defaults.set(Date(), forKey: lastCheckedKey)

        guard isNewer(store: storeVersion, than: installed) else { return nil }

        if let dismissedVersion = defaults.string(forKey: dismissedVersionKey),
           dismissedVersion == storeVersion,
           let dismissedAt = defaults.object(forKey: dismissedAtKey) as? Date,
           Date().timeIntervalSince(dismissedAt) < twentyFourHours {
            return nil
        }

        return storeVersion
    }

    static func recordDismiss(version: String) {
        let defaults = UserDefaults.standard
        defaults.set(version, forKey: dismissedVersionKey)
        defaults.set(Date(), forKey: dismissedAtKey)
    }

    private static func fetchStoreVersion() async -> String? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appStoreId)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let version = results.first?["version"] as? String else {
                return nil
            }
            return version
        } catch {
            return nil
        }
    }

    /// Compares dot-separated numeric versions. Non-numeric components are ignored.
    static func isNewer(store: String, than installed: String) -> Bool {
        let s = parseVersion(store)
        let i = parseVersion(installed)
        let count = max(s.count, i.count)
        for idx in 0..<count {
            let a = idx < s.count ? s[idx] : 0
            let b = idx < i.count ? i[idx] : 0
            if a > b { return true }
            if a < b { return false }
        }
        return false
    }

    private static func parseVersion(_ s: String) -> [Int] {
        s.split(separator: ".").compactMap { Int($0) }
    }
}
