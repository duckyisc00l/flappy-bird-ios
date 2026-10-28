import Foundation

/// "-shots": the build runs the app in the simulator and plays through the screens.
/// "DEMO snap NAME" tells the build to take a screenshot right then.
/// It also prints the Daily course so it can be checked against the website.
enum Demo {
    static func say(_ s: String) { print("DEMO \(s)"); fflush(stdout) }
    static func run() {
        var t = 0.0
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        var r = mulberry32(dailySeed()); var ys: [Int] = []
        for _ in 0..<12 { ys.append(Int(floor(r() * 192) + 192)) }
        say("dailycourse \(dailyKey()) \(ys)")
        r = mulberry32(12345); say("mulberry 12345 \((0..<4).map { _ in r() })")
        at(2) { say("snap title") }
        for p in ["settings", "birds", "modes", "weather", "trails", "maker", "account", "leaders", "friends", "partycode", "dev", "avatar", "import"] {
            at(0.8) { if p == "dev" { devMode = true }; openSheet(p) }
            at(1.0) { say("snap \(p)") }
            at(3.0) { closePicker() }
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
