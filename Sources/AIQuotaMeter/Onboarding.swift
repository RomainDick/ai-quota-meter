import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { Onboarding.run() }
    }
}

@MainActor
enum Onboarding {
    static let relocationDeclinedKey = "onboarding.relocationDeclined"
    static let hookDeclinedKey = "onboarding.hookDeclined"
    private static let defaults = UserDefaults.standard

    static func run() {
        guard AppLocation.isBundled else { return }
        if !AppLocation.isInApplications && !defaults.bool(forKey: relocationDeclinedKey) {
            if offerRelocation() { return }
        }
        AppLocation.removeLegacyCopies()
        guard AppLocation.canHostHook, let executable = Bundle.main.executablePath else { return }
        switch HookManager.status() {
        case .outdated:
            _ = try? HookManager.install(executable: executable)
        case .absent where FileManager.default.fileExists(atPath: AppPaths.claudeDir.path) && !defaults.bool(forKey: hookDeclinedKey):
            offerHook(executable: executable)
        default:
            break
        }
    }

    private static func offerRelocation() -> Bool {
        let accepted = ask(
            title: "Déplacer AI Quota Meter dans Applications ?",
            message: "L'app doit être rangée dans \(AppPaths.userApplications.path) pour fonctionner durablement : le hook Claude Code enregistre son emplacement. La copie actuelle sera mise à la corbeille.",
            confirm: "Déplacer",
            cancel: "Pas maintenant"
        )
        guard accepted else {
            defaults.set(true, forKey: relocationDeclinedKey)
            return false
        }
        do {
            AppLocation.relaunch(at: try AppLocation.moveToApplications())
            return true
        } catch {
            inform(title: "Déplacement impossible", message: error.localizedDescription)
            return false
        }
    }

    private static func offerHook(executable: String) {
        let accepted = ask(
            title: "Lire le quota de Claude Code ?",
            message: "Claude Code n'expose son quota qu'à sa ligne de statut. AI Quota Meter va remplacer la statusLine de ~/.claude/settings.json par la sienne : une sauvegarde est faite et ta statusLine actuelle, s'il y en a une, reste affichée. Tu pourras la retirer dans les réglages.",
            confirm: "Installer",
            cancel: "Plus tard"
        )
        guard accepted else {
            defaults.set(true, forKey: hookDeclinedKey)
            return
        }
        do {
            try HookManager.install(executable: executable)
            inform(title: "Hook installé", message: "Relance tes sessions Claude Code pour que le quota s'affiche.")
        } catch {
            inform(title: "Installation du hook impossible", message: error.localizedDescription)
        }
    }

    static func ask(title: String, message: String, confirm: String, cancel: String) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func inform(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
