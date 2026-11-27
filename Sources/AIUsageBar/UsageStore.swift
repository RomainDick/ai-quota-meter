import AppKit
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var providers: [ProviderUsage] = []
    @Published private(set) var label: MenuLabel = .idle
    @Published private(set) var hookStatus = HookManager.status()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var settings = AppSettings.load() {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            if settings.notifications && !oldValue.notifications { notifier.requestAuthorization() }
            updateLabel()
        }
    }

    private let claude = ClaudeProvider()
    private let codex = CodexProvider()
    private let history = HistoryStore()
    private let notifier = Notifier()
    private var timer: Timer?
    @Published private(set) var isRefreshing = false
    private var refreshStartedAt = Date()
    private static let minimumSpinnerDuration: TimeInterval = 0.6

    init() {
        if settings.notifications { notifier.requestAuthorization() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshStartedAt = Date()
        let claude = claude
        let codex = codex
        Task.detached(priority: .utility) {
            let now = Date()
            let loaded = [claude.load(now: now), codex.load(now: now)]
            await MainActor.run { self.apply(loaded, now: now) }
        }
    }

    func projection(for provider: ProviderUsage) -> Date? {
        history.projection(for: provider, now: Date())
    }

    func historyPoints(now: Date) -> [HistoryPoint] {
        history.points(for: providers, since: Calendar.current.startOfDay(for: now), now: now)
    }

    func toggleHook() {
        do {
            if hookStatus == .installed {
                try HookManager.uninstall()
                UserDefaults.standard.set(true, forKey: Onboarding.hookDeclinedKey)
            } else if let executable = Bundle.main.executablePath {
                try HookManager.install(executable: executable)
            }
        } catch {
            Onboarding.inform(title: "Modification du hook impossible", message: error.localizedDescription)
        }
        hookStatus = HookManager.status()
    }

    func uninstallApp() {
        let confirmed = Onboarding.ask(
            title: "Désinstaller AI Usage Bar ?",
            message: "Le hook Claude Code sera retiré (ta statusLine précédente est restaurée), l'historique et les réglages seront supprimés et l'app sera mise à la corbeille.",
            confirm: "Désinstaller",
            cancel: "Annuler"
        )
        guard confirmed else { return }
        if hookStatus != .absent { try? HookManager.uninstall() }
        try? SMAppService.mainApp.unregister()
        try? FileManager.default.removeItem(at: AppPaths.supportDir)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        AppLocation.moveToTrash()
        NSApp.terminate(nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func apply(_ loaded: [ProviderUsage], now: Date) {
        providers = loaded
        hookStatus = HookManager.status()
        let remaining = Self.minimumSpinnerDuration - Date().timeIntervalSince(refreshStartedAt)
        if remaining > 0 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                self.isRefreshing = false
            }
        } else {
            isRefreshing = false
        }
        history.record(loaded, now: now)
        if settings.notifications { notifier.evaluate(loaded, settings: settings, now: now) }
        updateLabel()
    }

    private func updateLabel() {
        let now = Date()
        let visible = providers.filter { $0.isActive(at: now) && !settings.hiddenProviders.contains($0.id) }
        guard !visible.isEmpty else {
            label = .idle
            return
        }
        switch settings.displayMode {
        case .text:
            label = .text(textTitle(visible, now: now))
        case .gauges:
            let items = visible.map { provider -> GaugeItem in
                let percent = provider.fiveHour?.effectivePercent(at: now) ?? 0
                return GaugeItem(letter: provider.shortName, percent: percent, color: settings.color(for: percent), stale: provider.isStale(at: now))
            }
            label = MenuBarImage.render(items).map(MenuLabel.image) ?? .text(textTitle(visible, now: now))
        }
    }

    private func textTitle(_ visible: [ProviderUsage], now: Date) -> String {
        visible.map { provider in
            "\(provider.shortName) \(Int((provider.fiveHour?.effectivePercent(at: now) ?? 0).rounded())) %"
        }.joined(separator: " · ")
    }
}
