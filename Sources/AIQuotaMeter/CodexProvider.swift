import Foundation

final class CodexProvider {
    private struct TokenEvent {
        let date: Date
        let tokens: Int
    }

    private struct QuotaEvent {
        let date: Date
        let fiveHour: QuotaWindow?
        let weekly: QuotaWindow?
    }

    private struct ParsedFile {
        let modified: Date
        let tokens: [TokenEvent]
        let quota: QuotaEvent?
    }

    private let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
    private var cache: [String: ParsedFile] = [:]

    func load(now: Date) -> ProviderUsage {
        var usage = ProviderUsage(id: "codex", name: "Codex", shortName: "X")
        let bounds = TimeBounds(now: now)
        let files = enumerateRecentFiles(root: root, since: bounds.weekStart) {
            $0.lastPathComponent.hasPrefix("rollout-")
        }
        var fresh: [String: ParsedFile] = [:]
        var latest: QuotaEvent?

        for file in files {
            let path = file.url.path
            let parsed = cache[path].flatMap { $0.modified == file.modified ? $0 : nil } ?? parse(file.url, modified: file.modified)
            fresh[path] = parsed
            parsed.tokens.forEach { usage.tokens.add($0.tokens, at: $0.date, bounds: bounds) }
            if let quota = parsed.quota, latest == nil || quota.date > latest!.date {
                latest = quota
            }
        }
        cache = fresh

        usage.fiveHour = latest?.fiveHour
        usage.weekly = latest?.weekly
        usage.quotaUpdatedAt = latest?.date
        if files.isEmpty { usage.detail = "Aucune session Codex sur 7 jours" }
        return usage
    }

    private func parse(_ url: URL, modified: Date) -> ParsedFile {
        var tokens: [TokenEvent] = []
        var quota: QuotaEvent?
        var previousTotal: Int?

        for object in jsonObjects(in: url, containing: "\"token_count\"") {
            guard let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let date = (object["timestamp"] as? String).flatMap(Dates.parse) else { continue }

            if let info = payload["info"] as? [String: Any],
               let total = (info["total_token_usage"] as? [String: Any])?["total_tokens"] as? Int,
               total != previousTotal,
               let last = info["last_token_usage"] as? [String: Any] {
                previousTotal = total
                tokens.append(TokenEvent(date: date, tokens: billedTokens(last)))
            }

            let limits = payload["rate_limits"] as? [String: Any]
            let fiveHour = quotaWindow(limits?["primary"], percentKey: "used_percent")
            let weekly = quotaWindow(limits?["secondary"], percentKey: "used_percent")
            if fiveHour != nil || weekly != nil {
                quota = QuotaEvent(date: date, fiveHour: fiveHour, weekly: weekly)
            }
        }
        return ParsedFile(modified: modified, tokens: tokens, quota: quota)
    }

    private func billedTokens(_ usage: [String: Any]) -> Int {
        let input = (usage["input_tokens"] as? NSNumber)?.intValue ?? 0
        let cached = (usage["cached_input_tokens"] as? NSNumber)?.intValue ?? 0
        let output = (usage["output_tokens"] as? NSNumber)?.intValue ?? 0
        return max(0, input - cached) + output
    }
}
