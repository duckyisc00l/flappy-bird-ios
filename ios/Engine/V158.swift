import Foundation
import QuartzCore

// ===================== v158: the bird remembers, the fake crash, Night Shift, achievements =====================
// (the website's nb/t_zzzzzzv158.js, line by line)

// ---------- small helpers ----------
func lsNum(_ k: String) -> Int { Int(localStorage.getItem(k) ?? "0") ?? 0 }
func lsSetNum(_ k: String, _ v: Int) { localStorage.setItem(k, String(v)) }
func lsList(_ k: String) -> [String] {
    guard let s = localStorage.getItem(k), let a = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [Any] else { return [] }
    return a.compactMap { $0 as? String }
}
func lsSetList(_ k: String, _ a: [String]) { localStorage.setItem(k, jsonStr(a)) }
/// a real round of yours (not the bot, not a practice jump, not the afterlife)
func realRun() -> Bool { !runUsedBot && START_SCORE == 0 && afterlife == 0 && !devGod && !devSlow }
/// pixel letters in any colour, k = size of one pixel
func glyphText(_ text: String, _ x0: Double, _ top: Double, _ col: String, _ k: Double = 2) {
    ctx.fill(col); var x = x0
    for ch in text {
        guard ch != " ", let g = GLYPH[String(ch)] else { x += 4 * k; continue }
        for r in 0..<5 { let row = Array(g[r]); for c in 0..<row.count where row[c] == "#" { ctx.fillRect(x + Double(c) * k, top - Double(r + 1) * k, k, k) } }
        x += Double(g[0].count + 1) * k
    }
}
func glyphWidth(_ text: String, _ k: Double = 2) -> Double {
    var w = 0.0
    for ch in text { if ch != " ", let g = GLYPH[String(ch)] { w += Double(g[0].count + 1) * k } else { w += 4 * k } }
    return max(0, w - k)
}

// ======================================================= achievements
struct AchInfo { let id: String, name: String, desc: String; var secret = false }
let ACH: [AchInfo] = [
    AchInfo(id: "first", name: "First Flight", desc: "Pass your first pipe."),
    AchInfo(id: "s10", name: "Getting The Hang", desc: "Score 10 in one round."),
    AchInfo(id: "s25", name: "Bronze Wings", desc: "Score 25 in one round."),
    AchInfo(id: "s50", name: "Silver Wings", desc: "Score 50 in one round."),
    AchInfo(id: "s100", name: "Golden Wings", desc: "Score 100 in one round."),
    AchInfo(id: "s250", name: "Legend", desc: "Score 250 in one round."),
    AchInfo(id: "faceplant", name: "Faceplant", desc: "Crash before the first pipe."),
    AchInfo(id: "d50", name: "Battle Scarred", desc: "Crash 50 times. Your bird remembers."),
    AchInfo(id: "d100", name: "Reborn", desc: "Crash 100 times. A new bird rises."),
    AchInfo(id: "d500", name: "Unkillable", desc: "Crash 500 times."),
    AchInfo(id: "p500", name: "Pipe Dreams", desc: "Pass 500 pipes in total."),
    AchInfo(id: "p5000", name: "Plumber", desc: "Pass 5000 pipes in total."),
    AchInfo(id: "hard25", name: "Hard As Nails", desc: "Score 25 in Hard."),
    AchInfo(id: "flip10", name: "Head Rush", desc: "Score 10 in Upside Down."),
    AchInfo(id: "tiny10", name: "Needle Threader", desc: "Score 10 in Tiny Gap."),
    AchInfo(id: "turbo30", name: "Speed Demon", desc: "Score 30 in Turbo."),
    AchInfo(id: "dark10", name: "Lantern Bearer", desc: "Score 10 in Darkness."),
    AchInfo(id: "tourist", name: "Tourist", desc: "Play a round in every mode."),
    AchInfo(id: "daily", name: "Daily Flyer", desc: "Finish a Daily Challenge."),
    AchInfo(id: "streak7", name: "Week Streak", desc: "Keep a 7 day Daily streak."),
    AchInfo(id: "storm10", name: "Storm Chaser", desc: "Score 10 in a thunderstorm."),
    AchInfo(id: "night", name: "Night Shift", desc: "Play a round of Night Shift (12 to 3 AM)."),
    AchInfo(id: "night20", name: "Graveyard Shift", desc: "Score 20 in Night Shift."),
    AchInfo(id: "glitch", name: "Inside The Glitch", desc: "Find what hides behind the crash.", secret: true),
    AchInfo(id: "patched", name: "Patched", desc: "Make it out of the glitch.", secret: true),
    AchInfo(id: "theend", name: "The End", desc: "Reach the ending.", secret: true),
]
final class Banner { let top: String, name: String; var t = 0.0; init(_ a: String, _ b: String) { top = a; name = b } }
var ACHQ: [Banner] = []   // banners waiting to be shown
func achHas(_ id: String) -> Bool { lsList("fb_ach").contains(id) }
func achUnlock(_ id: String) {
    guard let a = ACH.first(where: { $0.id == id }) else { return }
    var got = lsList("fb_ach"); if got.contains(id) { return }
    got.append(id); lsSetList("fb_ach", got)
    ACHQ.append(Banner("ACHIEVEMENT", a.name.uppercased()))
    appHaptic("medium")
    if id == "d100" { rebornRegister(); ACHQ.append(Banner("NEW SECRET BIRD", "REBORN")) }
}
func achBanner(_ top: String, _ name: String) { ACHQ.append(Banner(top, name)) }
func achScoreCheck() {
    if !realRun() || haunted || score <= 0 { return }
    let s = score
    if s >= 1 { achUnlock("first") }
    for (n, id) in [(10, "s10"), (25, "s25"), (50, "s50"), (100, "s100"), (250, "s250")] where s >= n { achUnlock(id) }
    let m = gameMode
    if m == "hard" && s >= 25 { achUnlock("hard25") }
    if m == "flipped" && s >= 10 { achUnlock("flip10") }
    if m == "tiny" && s >= 10 { achUnlock("tiny10") }
    if m == "turbo" && s >= 30 { achUnlock("turbo30") }
    if m == "dark" && s >= 10 { achUnlock("dark10") }
    if m == "night" && s >= 20 { achUnlock("night20") }
    if WX.weather == "storm" && weatherOn() && s >= 10 { achUnlock("storm10") }
    let p = lsNum("fb_lifePipes") + 1; lsSetNum("fb_lifePipes", p)
    if p >= 500 { achUnlock("p500") }
    if p >= 5000 { achUnlock("p5000") }
}
/// every crash of yours (the bot's and the afterlife's don't count)
func achDeath() {
    if runUsedBot || afterlife >= 1 { return }
    let d = lsNum("fb_lifeDeaths") + 1; lsSetNum("fb_lifeDeaths", d); SCAR.at = 0
    lsSetNum("fb_lifeGames", lsNum("fb_lifeGames") + 1)
    if d >= 50 { achUnlock("d50") }
    if d >= 100 { achUnlock("d100") }
    if d >= 500 { achUnlock("d500") }
    if !realRun() { return }
    if score <= 0 && !haunted { achUnlock("faceplant") }
    var played = lsList("fb_modesPlayed")
    if !played.contains(gameMode) { played.append(gameMode); lsSetList("fb_modesPlayed", played) }
    if MODES.filter({ $0.id != "night" }).allSatisfy({ played.contains($0.id) }) { achUnlock("tourist") }
    if gameMode == "daily" { achUnlock("daily") }
    if gameMode == "night" { achUnlock("night") }
    DispatchQueue.main.async { if lsNum("fb_dailyStreak") >= 7 { achUnlock("streak7") } }   // (after the Daily has counted today)
}
/// handleScore's add-ons
func v158Score() {
    achScoreCheck(); glitchScore()
    if ending.on && !runUsedBot { achUnlock("theend") }
}
/// the banner on the ground
func drawAchBanner(_ dt: Double) {
    guard let b = ACHQ.first else { return }
    b.t += dt
    let T = 3.4, a = min(1, b.t / 0.2, (T - b.t) / 0.3)
    if b.t >= T { ACHQ.removeFirst(); return }
    let w = max(glyphWidth(b.top), glyphWidth(b.name)) + 24, h = 40.0, cx = width / 2, y0 = 118.0   // (on the ground, clear of the buttons)
    ctx.globalAlpha = max(0, a)
    ctx.fill("#533846"); ctx.fillRect(jsRound(cx - w / 2) - 2, y0 - 2, w + 4, h + 4)
    ctx.fill("#ded895"); ctx.fillRect(jsRound(cx - w / 2), y0, w, h)
    ctx.fill("#d0c874"); ctx.fillRect(jsRound(cx - w / 2), y0, w, 2)
    glyphText(b.top, jsRound(cx - glyphWidth(b.top) / 2), y0 + h - 6, "#fc7858")
    glyphText(b.name, jsRound(cx - glyphWidth(b.name) / 2), y0 + h - 22, "#533846")
    ctx.globalAlpha = 1
}

// ======================================================= the bird remembers (scars) + the Reborn bird
var scarsOn = true
final class ScarState { var at = 0.0, stage = 0; var cache: [ObjectIdentifier: [Int: Img]] = [:]; var keep: [ObjectIdentifier: Img] = [:] }
let SCAR = ScarState()
/// in the bird's own big pixels (17 x 12, 2 px each); nil = that pixel is knocked out
let SCARS: [[(Int, Int, String?)]] = [
    [(5, 2, "#a01818"), (6, 3, "#a01818"), (7, 4, "#a01818"), (7, 2, "#d03a3a"), (4, 3, "#d03a3a")],                                   // 10: claw marks
    [(6, 0, "#f0e0c0"), (7, 0, "#f0e0c0"), (8, 0, "#f0e0c0"), (6, 1, "#f0e0c0"), (7, 1, "#c8a880"), (8, 1, "#f0e0c0")],                // 25: a bandage
    [(16, 7, nil), (15, 7, "#3a2a30"), (15, 9, nil), (14, 9, "#3a2a30"), (6, 8, "#6a5a6a"), (4, 9, "#5a4a5a"), (5, 9, "#5a4a5a")],      // 50: chipped beak, bruise
    [(10, 2, "#16121a"), (11, 2, "#16121a"), (9, 3, "#16121a"), (10, 3, "#3a3440"), (11, 3, "#16121a"), (12, 3, "#16121a"),
     (9, 4, "#16121a"), (10, 4, "#16121a"), (11, 4, "#16121a"), (12, 4, "#16121a"), (10, 5, "#16121a"), (11, 5, "#16121a")],          // 75: an eye patch
]
let SCAR_AT = [10, 25, 50, 75]
func scarStage() -> Int {
    let now = CACurrentMediaTime()
    if now - SCAR.at > 2 { SCAR.at = now; let d = lsNum("fb_lifeDeaths"); SCAR.stage = SCAR_AT.filter { d >= $0 }.count }
    return SCAR.stage
}
func scarred(_ im: Img, _ stage: Int) -> Img {
    let key = ObjectIdentifier(im)
    if let hit = SCAR.cache[key]?[stage] { return hit }
    let w = im.width, h = im.height
    let c = CGCanvas(w, h); c.imageSmoothingEnabled = false; c.drawImage(im, 0, 0)
    let d = c.getImageData(), ox = Int((Double(w - 34) / 2).rounded()), oy = Int((Double(h - 24) / 2).rounded())
    for s in 0..<stage { for (x, y, col) in SCARS[s] {
        let px = ox + x * 2, py = oy + y * 2
        if px < 0 || py < 0 || px + 1 >= w || py + 1 >= h || d[(py * w + px) * 4 + 3] < 10 { continue }   // only on the bird itself
        if let col = col { c.fill(col); c.fillRect(Double(px), Double(py), 2, 2) } else { c.clearRect(Double(px), Double(py), 2, 2) }
    } }
    let out = c.image()
    SCAR.cache[key, default: [:]][stage] = out; SCAR.keep[key] = im   // (keep the original alive so its id isn't reused)
    return out
}
/// birdFrame's add-on
func scarFrame(_ im: Img?) -> Img? {
    guard let im = im, scarsOn, afterlife == 0, !haunted, !["reborn", "super", "haunted"].contains(birdColor) else { return im }
    let st = scarStage()
    return st > 0 ? scarred(im, st) : im
}
// Reborn: a bird made of light and embers. It never scars.
let REBORN_PAL = ["R": "#fff1d0", "L": "#ffffff", "D": "#ffd27a", "W": "#ffb347", "G": "#ff7a2a", "B": "#ff4a1e", "E": "#ffffff", "P": "#e8281e", "O": "#6a2a14"]
let REBORN_PX = ["8,-3": "#ffe14a", "7,-2": "#ff8a1e", "8,-2": "#ffe14a", "9,-2": "#ff8a1e", "7,-1": "#ff8a1e", "8,-1": "#ff4a1e", "9,-1": "#ff8a1e", "10,-1": "#ffe14a",
                 "-1,3": "#ff8a1e", "-2,4": "#ffe14a", "-1,4": "#ff4a1e", "-1,5": "#ff8a1e", "-2,6": "#ffe14a"]
var rebornOn = false
func rebornUnlocked() -> Bool { lsNum("fb_lifeDeaths") >= 100 || achHas("d100") }
func rebornRegister() { rebornOn = true }
private var rebornBuilt = false
func ensureReborn() {
    if rebornBuilt { return }
    for n in 1...3 { Assets.put("reborn_\(n)", buildCustomFrame(n - 1, pal: REBORN_PAL, px: REBORN_PX)) }
    rebornBuilt = true
}

// ======================================================= the fake crash (and the level hidden inside it)
// About one round in 30 (from 8 points on, never in the Daily) the game "crashes": it freezes, tears apart,
// shows an error... and drops you into the glitch: a broken green world. Pass 10 pipes in there to get out.
struct GlitchBar { var y, h, x, w: Double; var c: String; var a: Double }
final class GlitchState { var phase = "", t = 0.0, armAt = 0, passed = 0, bars: [GlitchBar] = [], barT = -1, force = false }
let GL = GlitchState()
func glitchVisible() -> Bool { GL.phase == "inside" || (GL.phase == "crash" && GL.t > 1.65) || (GL.phase == "exit" && Int(floor(GL.t * 14)) % 2 == 0) }
func glitchArm() {
    GL.phase = ""; GL.t = 0; GL.passed = 0
    GL.armAt = gameMode != "daily" && afterlife == 0 && !haunted && START_SCORE == 0 && Double.random(in: 0..<1) < 1.0 / 30 ? 8 + Int.random(in: 0..<18) : 0
    if GL.force { GL.force = false; GL.armAt = 3 }   // (Developer page)
}
func glitchCrash() {
    if !GL.phase.isEmpty || afterlife != 0 || haunted || ending.on { return }
    GL.phase = "crash"; GL.t = 0; GL.barT = -1; GL.armAt = 0
    shakeT = 1.0; playSound("hit"); appHaptic("error")
}
func glitchEnter() {
    GL.phase = "inside"; GL.t = 0; GL.passed = 0
    pipeList = []                                   // the old world is gone
    if bird.y < 420 { bird.y = 420 }                // (a fair start: in the middle of the sky, with a flap)
    bird.vy = C.flapImpulse / BIRD_MASS; bird.rot = C.flapRotation; lastFlapTime = sceneTime
    botPath = nil
    flashScreen("#2bff6a", 0.02, 0.8, 0.4)
    if !runUsedBot { achUnlock("glitch") }
}
func glitchScore() {
    if GL.armAt > 0 && score >= GL.armAt && GL.phase.isEmpty && !isShowingGameOver { glitchCrash() }
    else if GL.phase == "inside" && !isShowingGameOver { GL.passed += 1; if GL.passed >= 10 { GL.phase = "exit"; GL.t = 0; flashScreen("#fff", 0.02, 0.6, 0.3) } }
}
/// the top of update(): while it "crashes" everything stops (only the glitch moves). true = skip the rest
func glitchFrozen(_ dt: Double) -> Bool {
    if GL.phase != "crash" { return false }
    GL.t += dt
    if GL.t >= 1.8 { glitchEnter() }
    return true
}
/// the end of update()
func v158Tick(_ dt: Double) {
    if GL.phase == "exit" { GL.t += dt; if GL.t >= 1.2 { GL.phase = ""; if !isShowingGameOver && !runUsedBot { achUnlock("patched") } } }
    else if GL.phase == "inside" { GL.t += dt }
    if !GL.phase.isEmpty && !bird.dynamic && !isGameOver && !isShowingGameOver { GL.phase = "" }   // (back on the title)
    nightTick(dt)
}
/// applyPipes' add-on: the glitch pipes, the Night Shift pipes
func v158Pipes(_ weatherWasOn: Bool) {
    var set: String? = nil
    if glitchVisible() { set = "glitch" } else if nightOn() && weatherWasOn { set = "night" }
    if let s = set, Assets.img("pipe_\(s)_up") != nil { pipeSkin = s }
}
private func glitchBars() -> [GlitchBar] {   // new tears every 70 ms
    let k = Int(floor(GL.t / 0.07))
    if k == GL.barT { return GL.bars }
    GL.barT = k; GL.bars = []
    let cols = ["#ff2ad8", "#22e8ff", "#2bff6a", "#000000", "#ffffff"], n = 7 + Int.random(in: 0..<7)
    for _ in 0..<n { GL.bars.append(GlitchBar(y: mrand() * SH, h: 2 + mrand() * 16, x: (mrand() - 0.5) * 60, w: 0.3 + mrand() * 0.9, c: cols[Int.random(in: 0..<cols.count)], a: 0.35 + mrand() * 0.5)) }
    for _ in 0..<14 { GL.bars.append(GlitchBar(y: mrand() * SH, h: 6 + mrand() * 8, x: mrand(), w: -1, c: cols[Int.random(in: 0..<3)], a: 0.9)) }
    return GL.bars
}
func drawGlitchSky() {
    let v = viewBox(), L = v.L - 10, W = v.R - v.L + 20
    ctx.fill("#020805"); ctx.fillRect(L, -10, W, SH + 20)
    ctx.fill("#0b3a1c")
    let off = ((groundX * 0.5).truncatingRemainder(dividingBy: 48) + 48).truncatingRemainder(dividingBy: 48)
    var x = floor(L / 48) * 48 + off
    while x < v.R + 10 { ctx.fillRect(x, 224, 2, SH); x += 48 }
    var y = 224.0
    while y < SH { ctx.fillRect(L, y, W, 2); y += 48 }
    let k = floor(sceneTime * 10)
    ctx.fill("rgba(31,216,96,0.7)")
    for i in 0..<40 {
        let h = sin(Double(i + 1) * 12.9898 + k * 78.233) * 43758.5453, r = h - floor(h), h2 = sin(Double(i + 1) * 4.1 + k * 9.7) * 2745.13, r2 = h2 - floor(h2)
        ctx.fillRect(jsRound(L + r * W), jsRound(240 + r2 * (SH - 260)), 2, 2)
    }
}
func drawGlitchGround() {
    let v = viewBox(), L = v.L - 10, W = v.R - v.L + 20
    ctx.fill("rgba(2,12,6,0.86)"); ctx.fillRect(L, -10, W, 234)
    ctx.fill("#2bff6a"); ctx.fillRect(L, 220, W, 4)
    ctx.fill("#1fd860")
    let off = (groundX.truncatingRemainder(dividingBy: 24) + 24).truncatingRemainder(dividingBy: 24)
    var x = floor(L / 24) * 24 + off
    while x < v.R + 10 { ctx.fillRect(x, 200, 12, 2); x += 24 }
}
func drawGlitchOverlay() {
    let v = viewBox(), L = v.L - 10, W = v.R - v.L + 20
    if GL.phase == "crash" {
        for b in glitchBars() {
            ctx.globalAlpha = b.a; ctx.fill(b.c)
            if b.w < 0 { ctx.fillRect(jsRound(L + b.x * W), jsRound(b.y), jsRound(b.h), jsRound(b.h)) }
            else { ctx.fillRect(jsRound(L + b.x), jsRound(b.y), jsRound(W * b.w), jsRound(b.h)) }
        }
        ctx.globalAlpha = 1
        if GL.t > 0.55 {   // the error box
            let l1 = "FATAL ERROR", l2 = "FLAPPY BIRD STOPPED", l3 = "0X0BADB1RD"
            let bw = max(glyphWidth(l1, 4), glyphWidth(l2, 2)) + 28, cx = width / 2, top = SH / 2 + 60
            ctx.fill("#000"); ctx.fillRect(jsRound(cx - bw / 2), top - 96, bw, 96)
            ctx.fill("#ff2ad8"); ctx.fillRect(jsRound(cx - bw / 2), top - 4, bw, 4); ctx.fillRect(jsRound(cx - bw / 2), top - 96, bw, 4)
            glyphText(l1, jsRound(cx - glyphWidth(l1, 4) / 2), top - 14, "#ffffff", 4)
            glyphText(l2, jsRound(cx - glyphWidth(l2, 2) / 2), top - 52, "#22e8ff", 2)
            if Int(floor(GL.t * 6)) % 2 == 1 { glyphText(l3, jsRound(cx - glyphWidth(l3, 2) / 2), top - 72, "#2bff6a", 2) }
        }
        if GL.t > 1.45 { ctx.globalAlpha = min(1, (GL.t - 1.45) / 0.3); ctx.fill("#000"); ctx.fillRect(L, -10, W, SH + 20); ctx.globalAlpha = 1 }
        return
    }
    if !glitchVisible() || !bird.added { return }
    // the bird glitches too
    let k = Int(floor(sceneTime * 8))
    if k % 5 == 0 || k % 7 == 0 {
        let by = worldFlipped() ? SH - bird.y : bird.y
        ctx.globalAlpha = 0.6
        ctx.fill("#ff2ad8"); ctx.fillRect(jsRound(bird.x - 30), jsRound(by + 4 - Double(k % 3) * 6), 40, 3)
        ctx.fill("#22e8ff"); ctx.fillRect(jsRound(bird.x - 14), jsRound(by - 10 + Double(k % 4) * 3), 44, 2)
        ctx.globalAlpha = 1
    }
    ctx.fill("rgba(0,0,0,0.18)")
    var y = 0.0
    while y < SH { ctx.fillRect(L, y, W, 2); y += 6 }   // scanlines
}

// ======================================================= Night Shift (12 to 3 AM, your time)
var NIGHT_FORCE = false   // (Developer page: open it now)
func nightOpen() -> Bool { NIGHT_FORCE || Calendar.current.component(.hour, from: Date()) < 3 }
func nightOn() -> Bool { modeOn("night") && afterlife == 0 && !haunted }
struct NightEye { var x, y, t, life: Double }
final class NightState { var eyes: [NightEye] = [], nextEye = 1.0, flick = 0.0, nextFlick = 7.0, check = 0.0, told = "" }
let NS = NightState()
func nightTick(_ dt: Double) {
    NS.check -= dt
    if NS.check <= 0 {
        NS.check = 1
        let title = !bird.dynamic && !isGameOver && !isShowingGameOver && !isWaitingToStart
        if gameMode == "night" && !nightOpen() && !inRun() { setGameMode("normal"); achBanner("NIGHT SHIFT", "IS OVER") }
        let f = DateFormatter(); f.dateFormat = "EEE MMM dd yyyy"; f.locale = Locale(identifier: "en_US_POSIX")
        let night = f.string(from: Date().addingTimeInterval(-3 * 3600))   // (one "night" runs 12 AM to 3 AM)
        if nightOpen() && title && NS.told != night && lsList("fb_nightTold").first != night {
            NS.told = night; lsSetList("fb_nightTold", [night])
            if gameMode != "night" { achBanner("NIGHT SHIFT IS OPEN", "PICK IT IN MODES") }
        }
    }
    if !nightOn() { NS.eyes = []; return }
    let v = viewBox(), scroll = moving.speed > 0 ? 200 * speedMul() : 0
    NS.nextEye -= dt
    if NS.nextEye <= 0 && NS.eyes.count < 4 { NS.nextEye = 1.2 + mrand() * 2; NS.eyes.append(NightEye(x: v.L + 30 + mrand() * (v.R - v.L - 60), y: 250 + mrand() * 120, t: 0, life: 2.5 + mrand() * 2)) }
    for i in NS.eyes.indices { NS.eyes[i].t += dt; NS.eyes[i].x -= scroll * 0.25 * dt }
    NS.eyes = NS.eyes.filter { $0.t < $0.life && $0.x > v.L - 20 }
    NS.nextFlick -= dt
    if NS.nextFlick <= 0 { NS.nextFlick = 6 + mrand() * 6; NS.flick = 0.45 }
    if NS.flick > 0 { NS.flick -= dt }
}
/// drawDarkness' add-on
func drawNightShift(_ flip: Bool) {
    if !nightOn() || glitchVisible() { return }
    let v = viewBox(), bx = bird.x, by = flip ? SH - bird.y : bird.y
    let out = NS.flick > 0 && Int(floor(NS.flick * 16)) % 3 != 0 ? 0.97 : 0.8   // the lights go out now and then
    let r = 175 + 5 * sin(WX.t * 7)
    drawVignette(bx, by, r, (8, 2, 10), [(0, 0), (0.5, 0.22), (1, out)], v.L - 10, -10, v.R - v.L + 20, SH + 20)
    ctx.fill("rgba(70,0,14,0.14)"); ctx.fillRect(v.L - 10, -10, v.R - v.L + 20, SH + 20)
    for e in NS.eyes {   // eyes in the dark (they blink)
        let a = min(1, e.t / 0.4, (e.life - e.t) / 0.4), blink = e.t.truncatingRemainder(dividingBy: 1.7) > 1.5
        if blink { continue }
        ctx.globalAlpha = a * 0.25; ctx.fill("#ff2020"); ctx.fillRect(jsRound(e.x) - 4, jsRound(e.y) - 3, 19, 9)
        ctx.globalAlpha = a; ctx.fill("#ff3030"); ctx.fillRect(jsRound(e.x), jsRound(e.y), 3, 3); ctx.fillRect(jsRound(e.x) + 8, jsRound(e.y), 3, 3)
        ctx.globalAlpha = 1
    }
}
/// a round shadow with a clear middle, drawn as a picture (the same as a radial gradient filling the rect;
/// the game screen's own radial gradients came out as a clear square here)
private var vigCache: [String: Img] = [:]
func vignetteImg(_ rgb: (Int, Int, Int), _ stops: [(Double, Double)]) -> Img {
    let key = "\(rgb)" + stops.map { String(format: "%.2f:%.2f", $0.0, $0.1) }.joined(separator: ",")
    if let hit = vigCache[key] { return hit }
    let N = 64
    var px = [UInt8](repeating: 0, count: N * N * 4)
    func alpha(_ d: Double) -> Double {
        if d <= stops[0].0 { return stops[0].1 }
        for i in 1..<stops.count where d <= stops[i].0 { let (a0, b0) = stops[i - 1], (a1, b1) = stops[i]; return b0 + (b1 - b0) * (d - a0) / max(1e-9, a1 - a0) }
        return stops[stops.count - 1].1
    }
    for y in 0..<N { for x in 0..<N {
        let d = hypot(Double(x) + 0.5 - Double(N) / 2, Double(y) + 0.5 - Double(N) / 2) / (Double(N) / 2), i = (y * N + x) * 4
        px[i] = UInt8(rgb.0); px[i + 1] = UInt8(rgb.1); px[i + 2] = UInt8(rgb.2); px[i + 3] = UInt8(max(0, min(255, (alpha(d) * 255).rounded())))
    } }
    let c = CGCanvas(N, N); c.putImageData(px)
    let im = c.image()
    if vigCache.count > 40 { vigCache.removeAll() }
    vigCache[key] = im
    return im
}
func drawVignette(_ cx: Double, _ cy: Double, _ r: Double, _ rgb: (Int, Int, Int), _ stops: [(Double, Double)], _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
    let im = vignetteImg(rgb, stops)
    ctx.save(); ctx.imageSmoothingEnabled = true; ctx.drawImage(im, cx - r, cy - r, 2 * r, 2 * r); ctx.restore()
    let last = stops[stops.count - 1].1
    if last <= 0.001 { return }
    ctx.fill("rgba(\(rgb.0),\(rgb.1),\(rgb.2),\(last))")
    let L = x, R = x + w, B = y, T = y + h, sl = cx - r, sr = cx + r, sb = cy - r, st = cy + r
    if sb > B { ctx.fillRect(L, B, w, sb - B) }                                   // below the circle's square
    if T > st { ctx.fillRect(L, st, w, T - st) }                                  // above
    let lo = max(B, sb), hi = min(T, st)
    if hi > lo { if sl > L { ctx.fillRect(L, lo, sl - L, hi - lo) }; if R > sr { ctx.fillRect(sr, lo, R - sr, hi - lo) } }   // left and right
}

/// the mode picker's picture for Night Shift
func nightModeIcon(_ base: Img) -> Img {
    let g = CGCanvas(84, 84); g.imageSmoothingEnabled = false; g.drawImage(base, 0, 0)
    g.fill("rgba(70,0,14,0.35)"); g.fillRect(0, 0, 84, 84)
    g.fill("#f0e6c8")   // a crescent moon
    for (x, y, w) in [(63.0, 6.0, 4.0), (61, 8, 3), (60, 10, 3), (60, 12, 3), (60, 14, 3), (61, 16, 3), (63, 18, 4)] { g.fillRect(x, y, w, 2) }
    g.fill("#ff3030"); g.fillRect(20, 52, 3, 3); g.fillRect(28, 52, 3, 3); g.fillRect(58, 40, 2, 2); g.fillRect(64, 40, 2, 2)
    return g.image()
}

// ======================================================= drawing hook (after the STOP button)
private var v158LastT = 0.0
func drawV158Overlay() {
    let now = CACurrentMediaTime(), dt = v158LastT > 0 ? min(0.1, now - v158LastT) : 0; v158LastT = now
    drawGlitchOverlay(); drawAchBanner(dt)
}

// ======================================================= startup
func v158Start() {
    scarsOn = loadBool("scars", true)
    if !MODES.contains(where: { $0.id == "night" }) {
        MODES.append(ModeInfo(id: "night", name: "NIGHT SHIFT", title: "Night Shift", descText: { "Only open from 12 to 3 AM. Darker and faster, with things watching, and its own leaderboard." }))
    }
    if !LB_MODES.contains("night") { LB_MODES.append("night") }
    if rebornUnlocked() { rebornRegister() }
}
