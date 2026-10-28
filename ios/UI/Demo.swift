import Foundation

/// "-shots": the build runs the app in the simulator and takes screenshots while this plays through the screens.
/// It also prints the Daily course so it can be checked against the website.
enum Demo {
    static func run() {
        var t = 0.0
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        // the Daily course (first 12 pipes' heights from today's seed), compared with the website in CI
        var r = mulberry32(dailySeed()); var ys: [Int] = []
        for _ in 0..<12 { ys.append(Int(floor(r() * 192) + 192)) }
        print("DEMO dailycourse \(dailyKey()) \(ys)")
        r = mulberry32(12345); print("DEMO mulberry 12345 \((0..<4).map { _ in r() })")
        at(1) { print("DEMO title") }
        for p in ["settings", "birds", "modes", "weather", "trails", "maker", "account", "leaders", "partycode", "dev", "avatar"] {
            at(3) { if p == "dev" { devMode = true }; openSheet(p); print("DEMO page \(p)") }
            at(3) { closePicker() }
        }
        at(2) { autoplay = true; handlePlayTap(); print("DEMO play") }
        at(14) { print("DEMO score \(score)") }
        at(6) { print("DEMO over \(isGameOver)") }
        at(2) { openSheet("card"); print("DEMO page card") }
        at(4) { closePicker(); autoplay = false; saveBool("autoplay", false); setGameMode("daily"); handlePlayTap(); print("DEMO daily") }
        at(3) { touchesBegan(0, 0); print("DEMO daily start") }
        at(4) { print("DEMO end") }
    }
}
