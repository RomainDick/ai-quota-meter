import Foundation

enum CLI {
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let supportDir = home.appendingPathComponent("Library/Application Support/ai-usage-bar")
    private static let snapshotURL = supportDir.appendingPathComponent("claude-snapshot.json")
    private static let previousCommandURL = supportDir.appendingPathComponent("previous-statusline.txt")
    private static let settingsURL = home.appendingPathComponent(".claude/settings.json")
    private static let marker = "--statusline"

    static func runStatusLine() {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let object = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        writeSnapshot(from: object)

        var output = ""
        if let previous = try? String(contentsOf: previousCommandURL, encoding: .utf8),
           !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            output = runPrevious(command: previous, input: input)
        } else if let limits = object["rate_limits"] as? [String: Any],
                  let five = percent(limits["five_hour"]), let week = percent(limits["seven_day"]) {
            output = "5h \(five)% · 7j \(week)%"
        }
        print(output)
    }

    static func installHook() {
        guard let executable = Bundle.main.executablePath else { fail("Chemin de l'exécutable introuvable") }
        var settings = readSettings()
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)

        if let existing = settings["statusLine"] as? [String: Any],
           let command = existing["command"] as? String, !command.contains(marker) {
            try? command.write(to: previousCommandURL, atomically: true, encoding: .utf8)
            print("statusLine existante conservée et chaînée : \(command)")
        }
        backupSettings()
        settings["statusLine"] = ["type": "command", "command": "\"\(executable)\" \(marker)"]
        writeSettings(settings)
        print("Hook statusLine installé dans \(settingsURL.path)")
    }

    static func uninstallHook() {
        var settings = readSettings()
        backupSettings()
        if let previous = try? String(contentsOf: previousCommandURL, encoding: .utf8),
           !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings["statusLine"] = ["type": "command", "command": previous]
        } else if let current = (settings["statusLine"] as? [String: Any])?["command"] as? String,
                  current.contains(marker) {
            settings.removeValue(forKey: "statusLine")
        }
        try? FileManager.default.removeItem(at: previousCommandURL)
        writeSettings(settings)
        print("Hook statusLine retiré")
    }

    private static func percent(_ raw: Any?) -> Int? {
        guard let value = (raw as? [String: Any])?["used_percentage"] as? NSNumber else { return nil }
        return Int(value.doubleValue.rounded(.down))
    }

    private static func writeSnapshot(from object: [String: Any]) {
        let limits = object["rate_limits"] as? [String: Any]
        let model = object["model"] as? [String: Any]
        var snapshot: [String: Any] = ["updatedAt": Date().timeIntervalSince1970]
        if let id = object["session_id"] { snapshot["sessionId"] = id }
        if let name = model?["display_name"] ?? model?["id"] { snapshot["model"] = name }
        if let five = limits?["five_hour"] { snapshot["fiveHour"] = five }
        if let week = limits?["seven_day"] { snapshot["sevenDay"] = week }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot) else { return }
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        try? data.write(to: snapshotURL, options: .atomic)
    }

    private static func runPrevious(command: String, input: Data) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        guard (try? process.run()) != nil else { return "" }
        stdin.fileHandleForWriting.write(input)
        try? stdin.fileHandleForWriting.close()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
    }

    private static func readSettings() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL) else { return [:] }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            fail("\(settingsURL.path) n'est pas un JSON valide, rien n'a été modifié")
        }
        return object
    }

    private static func writeSettings(_ settings: [String: Any]) {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: options) else {
            fail("Sérialisation des réglages impossible")
        }
        try? FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: settingsURL, options: .atomic)
    }

    private static func backupSettings() {
        let backup = settingsURL.deletingLastPathComponent().appendingPathComponent("settings.json.ai-usage-bar.bak")
        guard FileManager.default.fileExists(atPath: settingsURL.path), !FileManager.default.fileExists(atPath: backup.path) else { return }
        try? FileManager.default.copyItem(at: settingsURL, to: backup)
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
