import SwiftUI

enum DisplayMode: String, Codable, CaseIterable {
    case gauges
    case text
}

struct AppSettings: Codable, Equatable {
    private static let key = "settings.v1"
    private static let minimumGap = 5.0

    var displayMode: DisplayMode = .gauges
    var warnThreshold = 70.0
    var criticalThreshold = 90.0
    var notifications = true
    var hiddenProviders: Set<String> = []

    var warn: Double { warnThreshold }
    var critical: Double { max(criticalThreshold, warnThreshold + Self.minimumGap) }

    func color(for percent: Double) -> Color {
        switch percent {
        case critical...: return .red
        case warn...: return .orange
        default: return .green
        }
    }

    func level(for percent: Double) -> Int {
        switch percent {
        case critical...: return 2
        case warn...: return 1
        default: return 0
        }
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
