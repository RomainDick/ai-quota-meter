import Foundation

enum Formatting {
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "H' h 'mm"
        return formatter
    }()

    static func tokens(_ value: Int) -> String {
        switch value {
        case 1_000_000...: return String(format: "%.1f M", Double(value) / 1_000_000)
        case 1_000...: return String(format: "%.0f k", Double(value) / 1_000)
        default: return "\(value)"
        }
    }

    static func time(_ date: Date) -> String {
        clock.string(from: date)
    }

    static func remaining(until date: Date, now: Date) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        guard seconds > 0 else { return "réinitialisé" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 { return "reset dans \(days) j \(hours) h" }
        if hours > 0 { return "reset dans \(hours) h \(String(format: "%02d", minutes))" }
        return "reset dans \(minutes) min"
    }

    static func age(of date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 90 { return "à l'instant" }
        if seconds < 3_600 { return "il y a \(seconds / 60) min" }
        if seconds < 86_400 { return "il y a \(seconds / 3_600) h" }
        return "il y a \(seconds / 86_400) j"
    }
}
