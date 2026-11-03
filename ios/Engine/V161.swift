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
/// the mood shows on the bird's own face (its eye), whatever bird it is
func drawMood() {
    if sleepingNow() { return }   // v163: sleep wins over moods
    if afterlife != 0 || haunted || ending.on || bird.dynamic || !bird.added || worldFlipped() || glitchVisible() { return }
    let m = mood(); if m.isEmpty { return }
    onBird { im, _, _, _, _ in
        guard let e = birdEye(im) else { return }
        func X(_ x: Int) -> Int { e.ox + x * 2 }
        func Y(_ y: Int) -> Int { e.oy + y * 2 }
        let mid = Int(jsRound(Double(e.top + e.bot) / 2))
        if m == "happy" {          // eyes closed in a smile ^ and a little blush
            for (x, y) in e.cells { px1(X(x), Y(y), 2, 2, e.L) }
            let c = Int(jsRound(Double(e.left + e.right) / 2))
            for (dx, dy) in [(-2, 1), (-1, 0), (0, -1), (1, -1), (2, 0), (3, 1)] { px1(X(c + dx - 1), Y(mid + dy), 2, 2, e.O) }
            px1(X(e.left - 1), Y(e.bot + 1), 2, 2, "#ff8aa8"); px1(X(e.left), Y(e.bot + 1), 2, 2, "#ff8aa8")
        } else if m == "grumpy" {  // a heavy brow comes down over the eye, lower on the beak side
            func brow(_ x: Int) -> Int { e.top + Int(floor(Double(x - e.left) * 0.6)) }
            for (x, y) in e.cells where y <= brow(x) { px1(X(x), Y(y), 2, 2, e.L) }
            for x in (e.left - 1)...e.right { px1(X(x), Y(brow(max(x, e.left))) + 1, 2, 2, e.O) }
        } else if m == "sleepy" {  // droopy half-closed eyelids
            for (x, y) in e.cells where y <= mid { px1(X(x), Y(y), 2, 2, e.L) }
            px1(X(e.left), Y(mid) + 1, (e.right - e.left + 1) * 2, 1, e.O)
        }
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
