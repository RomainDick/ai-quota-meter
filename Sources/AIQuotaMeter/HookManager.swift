import Foundation

enum HookStatus {
    case installed
    case outdated
    case absent
    case unavailable
}

enum HookError: LocalizedError {
    case invalidSettings
    case serialization
    case write(String)

    var errorDescription: String? {
        switch self {
        case .invalidSettings: return "\(AppPaths.settingsURL.path) n'est pas un JSON valide, rien n'a été modifié"
        case .serialization: return "Sérialisation des réglages Claude Code impossible"
        case .write(let reason): return "Écriture de \(AppPaths.settingsURL.path) impossible : \(reason)"
        }
    }
}

enum HookManager {
    static let marker = "--statusline"

    static func expectedCommand(executable: String) -> String {
        "\"\(executable)\" \(marker)"
    }

    static func status() -> HookStatus {
        guard AppLocation.canHostHook, let executable = Bundle.main.executablePath else { return .unavailable }
        guard let command = try? currentCommand(), command.contains(marker) else { return .absent }
        return command == expectedCommand(executable: executable) ? .installed : .outdated
    }

    @discardableResult
    static func install(executable: String) throws -> String? {
        var settings = try readSettings()
        try? FileManager.default.createDirectory(at: AppPaths.supportDir, withIntermediateDirectories: true)

        var preserved: String?
        if let command = (settings["statusLine"] as? [String: Any])?["command"] as? String, !command.contains(marker) {
            try? command.write(to: AppPaths.previousCommandURL, atomically: true, encoding: .utf8)
            preserved = command
        }
        backupSettings()
        settings["statusLine"] = ["type": "command", "command": expectedCommand(executable: executable)]
        try writeSettings(settings)
        return preserved
    }

    static func uninstall() throws {
        var settings = try readSettings()
        backupSettings()
        if let previous = previousCommand() {
            settings["statusLine"] = ["type": "command", "command": previous]
        } else if let current = (settings["statusLine"] as? [String: Any])?["command"] as? String, current.contains(marker) {
            settings.removeValue(forKey: "statusLine")
        }
        try? FileManager.default.removeItem(at: AppPaths.previousCommandURL)
        try writeSettings(settings)
    }

    static func previousCommand() -> String? {
        guard let previous = try? String(contentsOf: AppPaths.previousCommandURL, encoding: .utf8),
              !previous.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return previous
    }

    private static func currentCommand() throws -> String? {
        (try readSettings()["statusLine"] as? [String: Any])?["command"] as? String
    }

    private static func readSettings() throws -> [String: Any] {
        guard let data = try? Data(contentsOf: AppPaths.settingsURL) else { return [:] }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw HookError.invalidSettings
        }
        return object
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: options) else {
            throw HookError.serialization
        }
        do {
            try FileManager.default.createDirectory(at: AppPaths.claudeDir, withIntermediateDirectories: true)
            try data.write(to: AppPaths.settingsURL, options: .atomic)
        } catch {
            throw HookError.write(error.localizedDescription)
        }
    }

    private static func backupSettings() {
        let manager = FileManager.default
        guard manager.fileExists(atPath: AppPaths.settingsURL.path),
              !manager.fileExists(atPath: AppPaths.settingsBackupURL.path) else { return }
        try? manager.copyItem(at: AppPaths.settingsURL, to: AppPaths.settingsBackupURL)
    }
}
