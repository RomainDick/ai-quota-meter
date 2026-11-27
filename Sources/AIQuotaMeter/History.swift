import Foundation

struct HistorySample: Codable {
    let time: Double
    let percent: Double
    let reset: Double
}

struct HistoryPoint: Identifiable {
    let id = UUID()
    let provider: String
    let date: Date
    let percent: Double
}

final class HistoryStore {
    private static let retention: TimeInterval = 24 * 3600
    private static let resetTolerance: Double = 120
    private static let projectionLookback: TimeInterval = 3600
    private static let projectionMinSpan: TimeInterval = 600
    private static let duplicateInterval: Double = 300

    private let url = AppPaths.supportDir.appendingPathComponent("history.json")
    private var samples: [String: [HistorySample]]

    init() {
        samples = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([String: [HistorySample]].self, from: $0) } ?? [:]
    }

    func record(_ providers: [ProviderUsage], now: Date) {
        var changed = false
        for provider in providers {
            guard let window = provider.fiveHour, let updated = provider.quotaUpdatedAt else { continue }
            var list = samples[provider.id] ?? []
            let sample = HistorySample(time: updated.timeIntervalSince1970, percent: window.usedPercent, reset: window.resetsAt.timeIntervalSince1970)
            if let last = list.last {
                if last.time >= sample.time { continue }
                if last.percent == sample.percent, sameWindow(last, sample), sample.time - last.time < Self.duplicateInterval { continue }
            }
            list.append(sample)
            samples[provider.id] = list.filter { $0.time >= now.timeIntervalSince1970 - Self.retention }
            changed = true
        }
        if changed { save() }
    }

    func projection(for provider: ProviderUsage, now: Date) -> Date? {
        guard let window = provider.fiveHour, !window.isExpired(at: now), let list = samples[provider.id] else { return nil }
        let reset = window.resetsAt.timeIntervalSince1970
        let recent = list.filter {
            abs($0.reset - reset) < Self.resetTolerance && $0.time >= now.timeIntervalSince1970 - Self.projectionLookback
        }
        guard let first = recent.first, let last = recent.last,
              last.time - first.time >= Self.projectionMinSpan, last.percent > first.percent, last.percent < 100 else { return nil }
        let slope = (last.percent - first.percent) / (last.time - first.time)
        let eta = Date(timeIntervalSince1970: last.time + (100 - last.percent) / slope)
        return eta < window.resetsAt ? eta : nil
    }

    func points(for providers: [ProviderUsage], since start: Date, now: Date) -> [HistoryPoint] {
        var result: [HistoryPoint] = []
        for provider in providers {
            let list = (samples[provider.id] ?? []).filter { $0.time >= start.timeIntervalSince1970 }
            for (index, sample) in list.enumerated() {
                result.append(HistoryPoint(provider: provider.name, date: Date(timeIntervalSince1970: sample.time), percent: sample.percent))
                let nextTime = index + 1 < list.count ? list[index + 1].time : now.timeIntervalSince1970
                if sample.reset < nextTime {
                    result.append(HistoryPoint(provider: provider.name, date: Date(timeIntervalSince1970: sample.reset), percent: 0))
                    if index + 1 == list.count {
                        result.append(HistoryPoint(provider: provider.name, date: now, percent: 0))
                    }
                }
            }
        }
        return result
    }

    private func sameWindow(_ lhs: HistorySample, _ rhs: HistorySample) -> Bool {
        abs(lhs.reset - rhs.reset) < Self.resetTolerance
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
