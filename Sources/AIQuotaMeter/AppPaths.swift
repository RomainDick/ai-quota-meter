import Foundation

enum AppPaths {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let supportDir = home.appendingPathComponent("Library/Application Support/ai-usage-bar")
    static let snapshotURL = supportDir.appendingPathComponent("claude-snapshot.json")
    static let previousCommandURL = supportDir.appendingPathComponent("previous-statusline.txt")
    static let claudeDir = home.appendingPathComponent(".claude")
    static let settingsURL = claudeDir.appendingPathComponent("settings.json")
    static let settingsBackupURL = claudeDir.appendingPathComponent("settings.json.ai-usage-bar.bak")
    static let userApplications = home.appendingPathComponent("Applications")
}
