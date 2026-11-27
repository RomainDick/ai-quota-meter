import Foundation

final class ClaudeProvider {
    private struct MessageUsage {
        let key: String
        let date: Date
        let tokens: Int
    }

    private struct ParsedFile {
        let modified: Date
        let messages: [MessageUsage]
    }

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var projectsRoot: URL { home.appendingPathComponent(".claude/projects") }
    private var cache: [String: ParsedFile] = [:]

    func load(now: Date) -> ProviderUsage {
        var usage = ProviderUsage(id: "claude", name: "Claude", shortName: "C")
        readSnapshot(into: &usage)
        usage.tokens = scanTokens(now: now)
        return usage
    }

    private func readSnapshot(into usage: inout ProviderUsage) {
        guard let data = try? Data(contentsOf: AppPaths.snapshotURL),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            usage.detail = "Aucune donnée de quota : lance une session Claude Code"
            return
        }
        usage.fiveHour = quotaWindow(object["fiveHour"], percentKey: "used_percentage")
        usage.weekly = quotaWindow(object["sevenDay"], percentKey: "used_percentage")
        if let updated = (object["updatedAt"] as? NSNumber)?.doubleValue {
            usage.quotaUpdatedAt = Date(timeIntervalSince1970: updated)
        }
        if usage.fiveHour == nil && usage.weekly == nil {
            usage.detail = "Quota indisponible pour ce type de compte"
        }
    }

    private func scanTokens(now: Date) -> TokenTotals {
        let bounds = TimeBounds(now: now)
        let files = enumerateRecentFiles(root: projectsRoot, since: bounds.weekStart) { _ in true }
        var fresh: [String: ParsedFile] = [:]
        var byMessage: [String: MessageUsage] = [:]

        for file in files {
            let path = file.url.path
            let parsed = cache[path].flatMap { $0.modified == file.modified ? $0 : nil } ?? parse(file.url, modified: file.modified)
            fresh[path] = parsed
            parsed.messages.forEach { byMessage[$0.key] = $0 }
        }
        cache = fresh

        var totals = TokenTotals()
        byMessage.values.forEach { totals.add($0.tokens, at: $0.date, bounds: bounds) }
        return totals
    }

    private func parse(_ url: URL, modified: Date) -> ParsedFile {
        let messages = jsonObjects(in: url, containing: "\"usage\"").compactMap { object -> MessageUsage? in
            guard let message = object["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let date = (object["timestamp"] as? String).flatMap(Dates.parse) else { return nil }
            let tokens = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
                .reduce(0) { $0 + ((usage[$1] as? NSNumber)?.intValue ?? 0) }
            let key = (message["id"] as? String) ?? (object["uuid"] as? String) ?? UUID().uuidString
            return MessageUsage(key: key, date: date, tokens: tokens)
        }
        return ParsedFile(modified: modified, messages: messages)
    }
}
