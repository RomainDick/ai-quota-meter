import Charts
import SwiftUI

struct UsagePopover: View {
    @ObservedObject var store: UsageStore
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(store: store) { showingSettings = false }
            } else {
                content
            }
        }
        .padding(14)
        .frame(width: 330)
        .onAppear { store.refresh() }
    }

    private var content: some View {
        let now = Date()
        let points = store.historyPoints(now: now)
        return VStack(alignment: .leading, spacing: 14) {
            ForEach(store.providers) { provider in
                ProviderSection(provider: provider, settings: store.settings, projection: store.projection(for: provider), now: now)
                Divider()
            }
            if points.count >= 2 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fenêtre 5 h aujourd'hui").font(.subheadline)
                    HistoryChart(points: points, settings: store.settings, start: Calendar.current.startOfDay(for: now), end: now)
                }
                Divider()
            }
            HStack {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .help("Réglages")
                Button("Actualiser") { store.refresh() }
                Spacer()
                Button("Quitter") { NSApplication.shared.terminate(nil) }
            }
        }
    }
}

struct ProviderSection: View {
    let provider: ProviderUsage
    let settings: AppSettings
    let projection: Date?
    let now: Date

    var body: some View {
        let active = provider.isActive(at: now)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(provider.name).font(.headline)
                if !active {
                    Text("inactif")
                        .font(.caption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let updated = provider.quotaUpdatedAt {
                    if active && provider.isStale(at: now) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(.orange)
                            .help("Donnée de plus de 15 min : le pourcentage peut avoir augmenté depuis")
                    }
                    Text(Formatting.age(of: updated, now: now)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let window = provider.fiveHour {
                if active {
                    QuotaRow(title: "Fenêtre 5 h", window: window, settings: settings, now: now)
                    if let projection {
                        Label("Quota atteint vers \(Formatting.time(projection)) au rythme actuel", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Fenêtre 5 h expirée : quota disponible").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let window = provider.weekly {
                QuotaRow(title: "Semaine", window: window, settings: settings, now: now)
            }
            if let detail = provider.detail, provider.fiveHour == nil {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                TokenStat(label: "5 h", value: provider.tokens.fiveHours)
                TokenStat(label: "Aujourd'hui", value: provider.tokens.today)
                TokenStat(label: "7 jours", value: provider.tokens.week)
            }
        }
        .opacity(active ? 1 : 0.7)
    }
}

struct QuotaRow: View {
    let title: String
    let window: QuotaWindow
    let settings: AppSettings
    let now: Date

    var body: some View {
        let percent = window.effectivePercent(at: now)
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Int(percent.rounded())) %").font(.subheadline.monospacedDigit())
            }
            ProgressView(value: min(percent, 100), total: 100).tint(settings.color(for: percent))
            Text(Formatting.remaining(until: window.resetsAt, now: now))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TokenStat: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(Formatting.tokens(value)).font(.callout.monospacedDigit())
        }
    }
}

struct HistoryChart: View {
    let points: [HistoryPoint]
    let settings: AppSettings
    let start: Date
    let end: Date

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Heure", point.date), y: .value("Utilisation", point.percent))
                    .foregroundStyle(by: .value("Outil", point.provider))
                    .interpolationMethod(.stepEnd)
            }
            RuleMark(y: .value("Seuil orange", settings.warn))
                .foregroundStyle(Color.orange.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            RuleMark(y: .value("Seuil rouge", settings.critical))
                .foregroundStyle(Color.red.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: start...end)
        .chartYAxis { AxisMarks(values: [0, 50, 100]) }
        .frame(height: 90)
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Réglages").font(.headline)
            Picker("Affichage", selection: $store.settings.displayMode) {
                Text("Jauges").tag(DisplayMode.gauges)
                Text("Texte").tag(DisplayMode.text)
            }
            .pickerStyle(.segmented)
            Stepper(value: $store.settings.warnThreshold, in: 30...95, step: 5) {
                Text("Seuil orange : \(Int(store.settings.warn)) %")
            }
            Stepper(value: $store.settings.criticalThreshold, in: 35...100, step: 5) {
                Text("Seuil rouge : \(Int(store.settings.critical)) %")
            }
            Toggle("Notifications aux seuils et au reset", isOn: $store.settings.notifications)
            Toggle("Lancer au démarrage", isOn: Binding(
                get: { store.launchAtLogin },
                set: { store.setLaunchAtLogin($0) }
            ))
            Divider()
            Text("Afficher dans la barre de menus").font(.subheadline)
            ForEach(store.providers) { provider in
                Toggle(provider.name, isOn: Binding(
                    get: { !store.settings.hiddenProviders.contains(provider.id) },
                    set: { show in
                        if show {
                            store.settings.hiddenProviders.remove(provider.id)
                        } else {
                            store.settings.hiddenProviders.insert(provider.id)
                        }
                    }
                ))
            }
            Text("Un outil sans fenêtre 5 h en cours est masqué automatiquement.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Terminé", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .toggleStyle(.checkbox)
    }
}
