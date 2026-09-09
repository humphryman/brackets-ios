import Foundation

/// Produces the "FALTAN N DÍAS" style pill text for an upcoming final, or nil
/// when no countdown should show.
enum FinalCountdown {
    static func label(until date: Date?, isLiveOrFinished: Bool, now: Date, calendar: Calendar) -> String? {
        guard !isLiveOrFinished, let date else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        guard let days = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget).day else { return nil }
        if days < 0 { return nil }
        if days == 0 { return "HOY" }
        if days == 1 { return "MAÑANA" }
        return "FALTAN \(days) DÍAS"
    }

    /// Convenience for views: uses the app timezone and the current date.
    static func label(until date: Date?, isLiveOrFinished: Bool) -> String? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = AppConfig.DateTime.apiTimeZone
        return label(until: date, isLiveOrFinished: isLiveOrFinished, now: Date(), calendar: cal)
    }
}
