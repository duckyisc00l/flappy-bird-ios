import Foundation

/// What the Home Screen widget shows. The app writes it (widget.json + bird.png) into the shared App Group folder.
struct WidgetData: Codable {
    var best = 0                  // Normal mode best
    var streak = 0                // Daily streak, as of streakLast
    var streakLast = ""           // the day (UTC, yyyy-MM-dd) of the last Daily played
    var dailyDay = ""             // the day the Daily score below is for
    var dailyScore: Int? = nil    // your best in that day's Daily
    var birdName = "Flappy Bird"
    var weather: String? = nil    // "74F, light rain"
    var place: String? = nil
    var season = "classic"
    var updated = 0.0
}

enum WidgetShare {
    static let defaultGroup = "group.com.jordanvalladares.flappybird"
    /// SideStore / AltStore give the App Group a new name when they sign the app (they add your team ID)
    /// and list the real names under ALTAppGroups in the Info.plist. The widget lives inside the app, so it
    /// checks the app's Info.plist too.
    static var group: String {
        if let g = (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String])?.first { return g }
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        if appURL.pathExtension == "app", let d = NSDictionary(contentsOf: appURL.appendingPathComponent("Info.plist")),
           let g = (d["ALTAppGroups"] as? [String])?.first { return g }
        return defaultGroup
    }
    static var folder: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) }
    static var dataURL: URL? { folder?.appendingPathComponent("widget.json") }
    static var birdURL: URL? { folder?.appendingPathComponent("bird.png") }

    static func load() -> WidgetData? {
        guard let u = dataURL, let d = try? Data(contentsOf: u) else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: d)
    }

    // the Daily resets at midnight UTC (same as the website)
    static let utc: DateFormatter = { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC"); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
    static func day(_ d: Date = Date()) -> String { utc.string(from: d) }
    static func nextDaily(after d: Date = Date()) -> Date {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        return c.startOfDay(for: d).addingTimeInterval(86400)
    }
}
