import Foundation
import QuartzCore

// ===================== v161: the scared pipe, last words, the pipe graveyard, bird moods, old version day =====================
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

// ======================================================= the scared pipe
// Very rarely (about 1 pipe in 35, from 3 points on, never in the Daily) a pipe flinches when you get close
// and pulls its two halves apart to let you through.
func scareOK(_ p: Pipe) -> Bool { gameMode != "daily" && WATCH == nil && afterlife == 0 && !haunted && !ending.on && !glitchVisible() && !p.gold && p.falling == nil && (p.amp ?? 0) == 0 && !p.red && score >= 3 }
var SCARE_FORCE = false
func scareTick(_ dt: Double) {
    for p in pipeList {
        if !p.scareRolled && p.gx - bird.x < 230 && p.gx > bird.x {
            p.scareRolled = true
            if bird.dynamic && !isGameOver && scareOK(p) && (SCARE_FORCE || Double.random(in: 0..<1) < 1.0 / 35) { SCARE_FORCE = false; p.scare = PipeScare() }
        }
        guard let s = p.scare else { continue }
        s.t += dt
        let want = s.t < 0.18 ? 0 : 74 * min(1, (s.t - 0.18) / 0.32)   // a flinch, then it slides apart
        let step = want - s.d; s.d = want
        if step != 0 { p.y -= step / 2; p.gap = p.gapV + step }
        if !s.got && p.scored { s.got = true; if !runUsedBot { achUnlock("scared") } }
    }
}
final class PipeScare { var t = 0.0, d = 0.0, got = false }
func drawScared() {
    for p in pipeList {
        guard let s = p.scare, s.t <= 1.1 else { continue }
        let shake = s.t < 0.18 ? (Int(floor(s.t * 60)) % 2 == 1 ? 2.0 : -2) : 0
        let top = p.y + 160 + p.gapV / 2 + 6, x = p.gx + shake   // "!!" in the middle of the gap
        ctx.globalAlpha = min(1, (1.1 - s.t) / 0.3)
        ctx.fill("#ffffff"); ctx.fillRect(jsRound(x - 7), jsRound(top - 14), 4, 10); ctx.fillRect(jsRound(x - 7), jsRound(top - 20), 4, 4)
        ctx.fillRect(jsRound(x + 3), jsRound(top - 14), 4, 10); ctx.fillRect(jsRound(x + 3), jsRound(top - 20), 4, 4)
        ctx.globalAlpha = 1
    }
}

// ======================================================= last words
let LAST_WORDS = ["WORTH IT", "TELL MY EGGS", "NOT AGAIN", "I REGRET NOTHING", "THAT PIPE MOVED", "MY WINGS", "WHY", "ONE MORE TRY",
                  "BAD IDEA", "I SAW A LIGHT", "OUCH", "RUDE", "I MEANT THAT", "SKILL ISSUE", "TOTALLY FINE", "AVENGE ME", "SO CLOSE", "NEXT TIME PIPE", "I BLINKED", "LAG"]
final class LastWordsState { var text = "", t = 9.0 }
let LW = LastWordsState()
func lastWords() {
    if afterlife != 0 || ending.on { return }
    var pool = LAST_WORDS
    if score <= 0 { pool = ["WAIT WHAT", "TOO SOON", "I WAS NOT READY", "OOPS"] }
    else if score > bestScore() && score >= 5 { pool = ["NEW RECORD THO", "WORTH IT", "REMEMBER ME"] }
    LW.text = pool[Int.random(in: 0..<pool.count)]; LW.t = -0.35
}
func drawLastWords(_ dt: Double) {
    if LW.text.isEmpty { return }
    LW.t += dt
    if !isShowingGameOver || LW.t > 2.6 { LW.text = ""; return }
    if LW.t < 0 { return }
    let a = min(1, LW.t / 0.15, (2.6 - LW.t) / 0.3), w = glyphWidth(LW.text) + 14, h = 18.0
    let by = worldFlipped() ? SH - bird.y : bird.y, cx = max(viewBox().L + w / 2 + 6, bird.x + 10), y0 = by + 30
    ctx.globalAlpha = max(0, a)
    ctx.fill("#533846"); ctx.fillRect(jsRound(cx - w / 2) - 2, jsRound(y0) - 2, w + 4, h + 4)
    ctx.fill("#ffffff"); ctx.fillRect(jsRound(cx - w / 2), jsRound(y0), w, h)
    ctx.fill("#533846"); ctx.fillRect(jsRound(bird.x - 2), jsRound(y0) - 6, 4, 4)   // the bubble's tail
    glyphText(LW.text, jsRound(cx - glyphWidth(LW.text) / 2), jsRound(y0) + 14, "#533846")
    ctx.globalAlpha = 1
}

// ======================================================= the pipe graveyard
var graveOn = true
func graves() -> [Int] { lsList("fb_pipeGraves").compactMap { Int($0) }.filter { $0 >= 0 } }
func drawGraveyard() {
    if !graveOn || !weatherOn() || haunted { return }
    let g = graves(); if g.isEmpty { return }
    let stone = pixArt("stone", ["..sss..", ".sSSSs.", "sSSSSSs", "sSSSSSs", "sSSSSSs", "sSSSSSs", "sSSSSSs", "sSSSSSs", "mmmmmmm"], ["s": "#6a6a78", "S": "#a0a0ae", "m": "#7a5a3a"])
    let landW = 336 * 2.0, n = 2 + Int(floor(width / landW)), shown = Array(g.suffix(12).reversed())
    for i in 0..<n {
        let left = groundX + Double(i) * (landW - 1) - 336
        for (j, sc) in shown.enumerated() {
            let x = jsRound(left + 30 + Double(j) * 56), base = 46.0
            spr(stone, x, base + 13.5, 3, 3, 0)
            let t = String(sc); glyphText(t, jsRound(x - glyphWidth(t, 1) / 2), base + 20, "#3a3a46", 1)
        }
    }
}
func graveAdd() {
    if !contactPipe || !realRun() || haunted || afterlife != 0 || ending.on || glitchVisible() { return }
    var g = lsList("fb_pipeGraves"); g.append(String(max(0, score))); lsSetList("fb_pipeGraves", Array(g.suffix(40)))
}

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
func v161Tick(_ dt: Double) { scareTick(dt) }
func v161Death() { graveAdd(); lastWords(); moodSet() }
private var v161LastT = 0.0
func drawV161Overlay() {
    let now = CACurrentMediaTime(), dt = v161LastT > 0 ? min(0.1, now - v161LastT) : 0; v161LastT = now
    drawScared(); drawMood(); drawLastWords(dt)
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
    graveOn = loadBool("graveyard", true)
    if !ACH.contains(where: { $0.id == "scared" }) {
        ACH.append(AchInfo(id: "scared", name: "Scaredy Pipe", desc: "A pipe got out of your way.", secret: true))
        ACH.append(AchInfo(id: "oldday", name: "Happy Birthday", desc: "Play on Flappy Birds birthday (May 24).", secret: true))
    }
}
