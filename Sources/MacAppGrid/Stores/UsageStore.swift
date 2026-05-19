import SwiftUI
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    @Published private(set) var launchCounts: [String: Int] = [:]
    @Published private(set) var lastLaunch: [String: TimeInterval] = [:]

    private let countsKey = "MacAppGrid.launchCounts"
    private let lastKey = "MacAppGrid.lastLaunch"

    private init() {
        if let counts = UserDefaults.standard.dictionary(forKey: countsKey) as? [String: Int] {
            launchCounts = counts
        }
        if let last = UserDefaults.standard.dictionary(forKey: lastKey) as? [String: TimeInterval] {
            lastLaunch = last
        }
    }

    func recordLaunch(bundleID: String) {
        launchCounts[bundleID, default: 0] += 1
        lastLaunch[bundleID] = Date().timeIntervalSince1970
        UserDefaults.standard.set(launchCounts, forKey: countsKey)
        UserDefaults.standard.set(lastLaunch, forKey: lastKey)
    }

    func recentApps(from apps: [AppItem], limit: Int = 12) -> [AppItem] {
        let sorted = apps
            .filter { (lastLaunch[$0.bundleID] ?? 0) > 0 }
            .sorted { (lastLaunch[$0.bundleID] ?? 0) > (lastLaunch[$1.bundleID] ?? 0) }
        return Array(sorted.prefix(limit))
    }

    func frequentApps(from apps: [AppItem], limit: Int = 12) -> [AppItem] {
        let sorted = apps
            .filter { (launchCounts[$0.bundleID] ?? 0) > 0 }
            .sorted { (launchCounts[$0.bundleID] ?? 0) > (launchCounts[$1.bundleID] ?? 0) }
        return Array(sorted.prefix(limit))
    }
}
