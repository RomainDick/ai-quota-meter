import Foundation

struct QuotaWindow: Equatable {
    let usedPercent: Double
    let resetsAt: Date

    func isExpired(at now: Date) -> Bool {
        resetsAt <= now
    }

    func effectivePercent(at now: Date) -> Double {
        isExpired(at: now) ? 0 : usedPercent
    }
}

struct TokenTotals {
    var fiveHours = 0
    var today = 0
    var week = 0

    mutating func add(_ value: Int, at date: Date, bounds: TimeBounds) {
        guard date >= bounds.weekStart else { return }
        week += value
        if date >= bounds.dayStart { today += value }
        if date >= bounds.fiveHoursStart { fiveHours += value }
    }
}

struct TimeBounds {
    let weekStart: Date
    let dayStart: Date
    let fiveHoursStart: Date

    init(now: Date) {
        weekStart = now.addingTimeInterval(-Windows.week)
        dayStart = Calendar.current.startOfDay(for: now)
        fiveHoursStart = now.addingTimeInterval(-Windows.fiveHours)
    }
}

struct ProviderUsage: Identifiable {
    let id: String
    let name: String
    let shortName: String
    var fiveHour: QuotaWindow?
    var weekly: QuotaWindow?
    var tokens = TokenTotals()
    var quotaUpdatedAt: Date?
    var detail: String?

    func isActive(at now: Date) -> Bool {
        guard let fiveHour else { return false }
        return !fiveHour.isExpired(at: now)
    }

    func isStale(at now: Date) -> Bool {
        guard let quotaUpdatedAt else { return true }
        return now.timeIntervalSince(quotaUpdatedAt) > Windows.staleAfter
    }
}

enum Dates {
    static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        isoFractional.date(from: value) ?? iso.date(from: value)
    }
}

enum Windows {
    static let fiveHours: TimeInterval = 5 * 3600
    static let week: TimeInterval = 7 * 24 * 3600
    static let staleAfter: TimeInterval = 15 * 60
}

func enumerateRecentFiles(root: URL, since: Date, matching: (URL) -> Bool) -> [(url: URL, modified: Date)] {
    let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
        return []
    }
    var result: [(URL, Date)] = []
    for case let url as URL in enumerator {
        guard url.pathExtension == "jsonl", matching(url),
              let values = try? url.resourceValues(forKeys: Set(keys)),
              values.isRegularFile == true,
              let modified = values.contentModificationDate,
              modified >= since else { continue }
        result.append((url, modified))
    }
    return result
}

func jsonObjects(in url: URL, containing marker: String) -> [[String: Any]] {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return [] }
    let needle = Data(marker.utf8)
    return data.split(separator: 10, omittingEmptySubsequences: true).compactMap { line in
        guard line.range(of: needle) != nil else { return nil }
        return (try? JSONSerialization.jsonObject(with: line)) as? [String: Any]
    }
}

func quotaWindow(_ raw: Any?, percentKey: String) -> QuotaWindow? {
    guard let dict = raw as? [String: Any],
          let percent = (dict[percentKey] as? NSNumber)?.doubleValue,
          let reset = (dict["resets_at"] as? NSNumber)?.doubleValue else { return nil }
    return QuotaWindow(usedPercent: percent, resetsAt: Date(timeIntervalSince1970: reset))
}
