import Foundation
import UIKit

/// "-shots": the build runs the app in the simulator and plays through the screens.
/// "DEMO snap NAME" tells the build to take a screenshot right then.
/// It also prints the Daily course so it can be checked against the website.
enum Demo {
    static var shotN = 0
    /// the app takes its own screenshot (the simulator's screenshots arrive seconds late)
    static func snap(_ name: String) {
        guard let win = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else { say("nowindow"); return }
        let img = UIGraphicsImageRenderer(bounds: win.bounds).image { _ in _ = win.drawHierarchy(in: win.bounds, afterScreenUpdates: false) }
        shotN += 1
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? img.pngData()?.write(to: dir.appendingPathComponent(String(format: "%02d_", shotN) + name + ".png"))
    }
    static func say(_ s: String) {
        if s.hasPrefix("snap ") { snap(String(s.dropFirst(5))) }
        print("DEMO \(s)"); fflush(stdout)
        // the build reads this file (the console reaches it seconds late)
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("demo.txt")
        let line = Data(("DEMO " + s + "\n").utf8)
        if let h = try? FileHandle(forWritingTo: u) { h.seekToEndOfFile(); h.write(line); try? h.close() } else { try? line.write(to: u) }
    }
    static func run() {
        var t = 0.0
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        try? FileManager.default.removeItem(at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("demo.txt"))
        var r = mulberry32(dailySeed()); var ys: [Int] = []
        for _ in 0..<12 { ys.append(Int(floor(r() * 192) + 192)) }
        say("dailycourse \(dailyKey()) \(ys)")
        r = mulberry32(12345); say("mulberry 12345 \((0..<4).map { _ in r() })")
        at(2) { say("snap title") }
        at(4) {}
        for p in ["settings", "birds", "modes", "weather", "trails", "maker", "account", "leaders", "friends", "partycode", "dev", "avatar", "import"] {
            at(1.0) { if p == "dev" { devMode = true }; openSheet(p) }
            at(1.5) { say("snap \(p)") }
            at(4.0) { closePicker() }
        }
        at(1) { autoplay = true; handlePlayTap(); say("snap ready") }
        at(1.5) { say("snap play1") }
        at(3) { say("snap play2") }
        at(4) { say("snap play3") }
        at(1) { autoplay = false; say("score \(score)") }
        at(3) { say("over \(isGameOver)"); say("snap over") }
        at(1.5) { say("snap over2") }
        at(1) { openSheet("card") }
        at(1.5) { say("snap card") }
        at(3) { closePicker(); saveBool("autoplay", false); setGameMode("daily"); handlePlayTap() }
        at(1.5) { say("snap daily") }
        at(0.5) { touchesBegan(0, 0) }
        at(0.6) { say("snap dailyplay") }
        at(3) { say("snap dailyover") }
        at(1) { say("end") }
    }
}
