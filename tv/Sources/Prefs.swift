import Foundation

struct GameMode {
    let id: String, title: String, desc: String
}

enum Modes {
    static let all: [GameMode] = [
        GameMode(id: "normal", title: "Normal", desc: "The classic game."),
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
    static func best(_ mode: String) -> Int { d.integer(forKey: "best_" + mode) }
    static func setBest(_ mode: String, _ v: Int) { if v > best(mode) { d.set(v, forKey: "best_" + mode) } }
}
