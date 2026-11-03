import Foundation
import QuartzCore

// ===================== v161: bird moods, old version day =====================
// (the website's nb/t_zzzzzzz161.js, line by line)

/// a little pixel picture from rows of letters (one pixel per letter), like the website's pixCanvas
private var pixArtCache: [String: Img] = [:]
func pixArt(_ key: String, _ rows: [String], _ legend: [Character: String]) -> Img {
    if let hit = pixArtCache[key] { return hit }
    let w = rows.map { $0.count }.max() ?? 1, h = rows.count
    let c = CGCanvas(w, h); c.imageSmoothingEnabled = false
    for (j, row) in rows.enumerated() { for (i, ch) in row.enumerated() { if let col = legend[ch] { c.fill(col); c.fillRect(Double(i), Double(j), 1, 1) } } }
    let im = c.image(); pixArtCache[key] = im; return im
}

// ---------- old version day: on Flappy Bird's birthday (May 24) the game is plain, the way it started ----------
var OLD_FORCE = false   // (Developer page)
func oldDay() -> Bool { let c = Calendar.current.dateComponents([.month, .day], from: Date()); return OLD_FORCE || (c.month == 5 && c.day == 24) }

// ======================================================= bird moods
// happy after a new best, grumpy after crashing before the first pipe, sleepy if you haven't played for a day
func mood() -> String {
    let last = lsNum("fb_lastPlay")
    if last > 0 && Date().timeIntervalSince1970 * 1000 - Double(last) > 24 * 3600000 { return "sleepy" }
    if let s = localStorage.getItem("fb_mood"), let o = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [String: Any], let m = o["m"] as? String { return m }
    return ""
}
func moodSet() {
    if !realRun() || haunted { return }
    let m = score > bestScore() && score >= 5 ? "happy" : score <= 0 ? "grumpy" : ""
    localStorage.setItem("fb_mood", jsonStr(["m": m, "t": Date().timeIntervalSince1970 * 1000] as [String: Any]))
    lsSetNum("fb_lastPlay", Int(Date().timeIntervalSince1970 * 1000))
}
func drawMood() {
    if sleepingNow() { return }   // v163: sleep wins over moods
    if afterlife != 0 || haunted || ending.on || bird.dynamic || !bird.added { return }
    let m = mood(); if m.isEmpty { return }
    let t = sceneTime, by = worldFlipped() ? SH - bird.y : bird.y, x = bird.x, y = by + 30
    if m == "happy" {
        if let h = pix("heart") { spr(h, jsRound(x + 6), jsRound(y + 4 + sin(t * 3) * 3), 2, 2, 0) }
        if Int(floor(t * 3)) % 2 == 1 { ctx.fill("#fff6a0"); ctx.fillRect(jsRound(x - 16), jsRound(y + 8), 2, 2); ctx.fillRect(jsRound(x + 22), jsRound(y + 14), 2, 2) }
    } else if m == "grumpy" {
        let cloud = pixArt("moodCloud", ["...ggg...", ".gggggggg", "ggggggggg", ".ggggggg.", "....y....", "...y.....", "....y...."], ["g": "#5a5a6a", "y": "#ffd23c"])
        spr(cloud, jsRound(x + 2 + sin(t * 2) * 2), jsRound(y + 10), 3, 3, 0)
    } else if m == "sleepy" {
        for i in 0..<3 {
            let f = (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1), k = [1.0, 2, 2][i]
            ctx.globalAlpha = min(1, (1 - f) * 2)
            glyphText("Z", jsRound(x + 14 + f * 16 + Double(i) * 3), jsRound(y + f * 30 + 6), "#ffffff", k + f)
        }
        ctx.globalAlpha = 1
    }
}

// ======================================================= hooks
func v161Death() { moodSet() }
func drawV161Overlay() {
    drawMood()
}
private var oldTold = ""
/// old version day: say so once on the title
func oldDayBanner() {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; let day = f.string(from: Date())
    if oldDay() && oldTold != day && !bird.dynamic && flappyBird.added {
        oldTold = day
        achBanner("FLAPPY BIRD IS \(Calendar.current.component(.year, from: Date()) - 2013) TODAY", "THE CLASSIC LOOK ALL DAY")
    }
}
func v161Start() {
    if !ACH.contains(where: { $0.id == "oldday" }) {
        ACH.append(AchInfo(id: "oldday", name: "Happy Birthday", desc: "Play on Flappy Birds birthday (May 24).", secret: true))
    }
}
