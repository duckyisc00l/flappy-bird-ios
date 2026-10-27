import Foundation
import CoreGraphics

struct GameMode {
    let id: String, title: String, desc: String
}

enum Modes {
    static let all: [GameMode] = [
        GameMode(id: "normal", title: "Normal", desc: "The classic game."),
        GameMode(id: "daily", title: "Daily Challenge", desc: "The same pipes for everyone today. New pipes every day."),
        GameMode(id: "hard", title: "Hard", desc: "Smaller gaps and faster pipes. The pipes turn red."),
        GameMode(id: "wavy", title: "Wavy", desc: "The pipes slide up and down while you fly."),
        GameMode(id: "flipped", title: "Upside Down", desc: "The whole world is upside down: you fall up, and every click pushes you down."),
        GameMode(id: "tiny", title: "Tiny Gap", desc: "The gaps are barely bigger than you are."),
        GameMode(id: "turbo", title: "Turbo", desc: "Starts normal and gets faster with every point."),
        GameMode(id: "windy", title: "Windy", desc: "Gusts of wind push you up and down. Watch the wind lines."),
        GameMode(id: "dark", title: "Darkness", desc: "Pitch black. You only see what your lantern lights up."),
    ]
    static func info(_ id: String) -> GameMode { all.first { $0.id == id } ?? all[0] }
}

/// Settings and best scores, kept on the Apple TV.
enum Prefs {
    private static let d = UserDefaults.standard

    static var mode: String {
        get { let m = d.string(forKey: "mode") ?? "normal"; return Modes.all.contains { $0.id == m } ? m : "normal" }
        set { d.set(newValue, forKey: "mode") }
    }
    /// a bird id, or "random"
    static var bird: String {
        get { d.string(forKey: "bird") ?? "random" }
        set { d.set(newValue, forKey: "bird") }
    }
    static var sound: Bool {
        get { d.object(forKey: "sound") == nil ? true : d.bool(forKey: "sound") }
        set { d.set(newValue, forKey: "sound") }
    }
    /// a trail id, or "none"
    static var trail: String {
        get { d.string(forKey: "trail") ?? "none" }
        set { d.set(newValue, forKey: "trail") }
    }
    /// "auto" (by date) or a season id
    static var season: String {
        get { d.string(forKey: "season") ?? "auto" }
        set { d.set(newValue, forKey: "season") }
    }
    static func best(_ mode: String) -> Int { d.integer(forKey: "best_" + Daily.scoreMode(mode)) }   // (today's Daily best is its own)
    static func setBest(_ mode: String, _ v: Int) { if v > best(mode) { d.set(v, forKey: "best_" + Daily.scoreMode(mode)) } }
}

/// Daily Challenge: one course a day for everyone, from a seed made of the date (UTC, like the website),
/// with its own leaderboard "daily-YYYYMMDD".
enum Daily {
    static var key: String { "daily-" + dateString.replacingOccurrences(of: "-", with: "") }
    static var dateString: String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC"); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
    static func scoreMode(_ mode: String) -> String { mode == "daily" ? key : mode }
    static var seed: UInt32 { var h: UInt32 = 2166136261; for c in key.utf8 { h ^= UInt32(c); h = h &* 16777619 }; return h }
    static var hoursLeft: Int {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let next = c.startOfDay(for: Date()).addingTimeInterval(86400)
        return max(1, Int(ceil(next.timeIntervalSinceNow / 3600)))
    }
}
/// a small seeded random number generator (mulberry32, like the website's)
struct Mulberry32: RandomNumberGenerator {
    private var a: UInt32
    init(seed: UInt32) { a = seed }
    mutating func next() -> UInt64 { UInt64(next32()) << 32 | UInt64(next32()) }
    mutating func next32() -> UInt32 {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return t ^ (t >> 14)
    }
    mutating func unit() -> CGFloat { CGFloat(next32()) / 4294967296 }
}
