import SwiftUI

struct AIUsageBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(store: store)
        } label: {
            MenuBarLabel(label: store.label)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let label: MenuLabel

    var body: some View {
        switch label {
        case .image(let image):
            Image(nsImage: image)
        case .text(let title):
            Text(title)
        case .idle:
            Image(systemName: "gauge.with.dots.needle.0percent")
        }
    }
}
