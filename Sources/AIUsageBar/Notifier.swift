import Foundation
import UserNotifications

final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private static let resetBucket: Double = 300
    private let defaults = UserDefaults.standard

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ providers: [ProviderUsage], settings: AppSettings, now: Date) {
        for provider in providers {
            guard let window = provider.fiveHour else { continue }
            let key = "notified.\(provider.id).\(Int(window.resetsAt.timeIntervalSince1970 / Self.resetBucket))"
            let notifiedLevel = defaults.integer(forKey: key)

            if window.isExpired(at: now) {
                let resetKey = key + ".reset"
                guard notifiedLevel >= 1, !defaults.bool(forKey: resetKey) else { continue }
                defaults.set(true, forKey: resetKey)
                post(id: resetKey,
                     title: "\(provider.name) : fenêtre 5 h réinitialisée",
                     body: "Le quota est de nouveau disponible.")
                continue
            }

            let level = settings.level(for: window.usedPercent)
            guard level > notifiedLevel else { continue }
            defaults.set(level, forKey: key)
            post(id: "\(key).\(level)",
                 title: "\(provider.name) : \(Int(window.usedPercent.rounded())) % de la fenêtre 5 h",
                 body: "Quota : \(Formatting.remaining(until: window.resetsAt, now: now)).")
        }
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
