import Foundation

// ===================== Ghost of your best run + replayable course =====================
// Each run records the bird every 1/30 s. The best run of each mode is kept with its course: the pipes on screen at
// the start, the spawner's timing and the seed for every later pipe. Same format as the website (JSON + base64 arrays).
var courseRng: () -> Double = { mrand() }
func crand() -> Double { courseRng() }
func mulberry32(_ seed: UInt32) -> () -> Double {
    var a = seed
    return {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (1 | a)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296
    }
}
func seedU32(_ d: Double) -> UInt32 { UInt32(truncatingIfNeeded: Int64(d.rounded(.towardZero))) }
let GHOST_HZ = 30.0, GHOST_MAX = 30 * 60 * 40
/// a recorded run (what the ghost player uses)
final class GhostRun {
    var score = 0, seed = 0.0, phase = 0.0, pipes: [[String: Any]] = [], skin = "yellow"
    var y: [Int16] = [], x: [Int16] = [], r: [Int8] = []
    var friend: String? = nil
    var raw: [String: Any] = [:]
}
final class GhostRec {
    var seed = 0.0, hard = "normal", phase = 0.0, pipes: [[String: Any]] = [], skin = "yellow"
    var y: [Int16] = [], x: [Int16] = [], r: [Int8] = [], next = 0, prev: (t: Double, x: Double, y: Double, r: Double)? = nil, done = false
}
var ghostRec: GhostRec? = nil
var ghostPlay: (g: GhostRun, fade: Double)? = nil
var ghostCache: [String: GhostRun?] = [:]
func ghostKey(_ mode: String) -> String { "fb_ghost" + modeSuffix(mode) }
func b64(_ d: Data) -> String { d.base64EncodedString() }
func encArrays(_ y: [Int16], _ x: [Int16], _ r: [Int8]) -> (String, String, String) {
    func d16(_ a: [Int16]) -> Data { a.withUnsafeBufferPointer { Data(buffer: $0) } }
    return (b64(d16(y)), b64(d16(x)), b64(r.withUnsafeBufferPointer { Data(buffer: $0) }))
}
func decArrays(_ ys: String, _ xs: String, _ rs: String) -> ([Int16], [Int16], [Int8])? {
    guard let yd = Data(base64Encoded: ys), let xd = Data(base64Encoded: xs), let rd = Data(base64Encoded: rs) else { return nil }
    let y: [Int16] = yd.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    let x: [Int16] = xd.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    let r: [Int8] = rd.withUnsafeBytes { Array($0.bindMemory(to: Int8.self)) }
    return (y, x, r)
}
func jsonObj(_ s: String?) -> [String: Any]? { guard let s = s, let d = s.data(using: .utf8) else { return nil }; return try? JSONSerialization.jsonObject(with: d) as? [String: Any] }
func jsonStr(_ o: Any) -> String { (try? JSONSerialization.data(withJSONObject: o)).flatMap { String(data: $0, encoding: .utf8) } ?? "null" }
func num(_ v: Any?) -> Double? { if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.doubleValue }; if let s = v as? String { return Double(s) }; return nil }
/// the stored form (base64 arrays) -> what the ghost player uses
func fgDecode(_ enc: [String: Any]?) -> GhostRun? {
    guard let e = enc, let ys = e["y"] as? String, let xs = e["x"] as? String, let rs = e["r"] as? String, let (y, x, r) = decArrays(ys, xs, rs) else { return nil }
    guard !y.isEmpty, x.count == y.count, r.count == y.count, let pipes = e["pipes"] as? [[String: Any]], let seed = num(e["seed"]) else { return nil }
    let g = GhostRun()
    g.score = Int(num(e["score"]) ?? 0); g.seed = seed; g.phase = num(e["phase"]) ?? 0; g.pipes = pipes
    g.skin = e["skin"] as? String ?? "yellow"; if !skinExists(g.skin) { g.skin = "yellow" }
    g.y = y; g.x = x; g.r = r; g.raw = e
    return g
}
func loadGhost(_ mode: String) -> GhostRun? {
    let key = ghostKey(mode)
    if let c = ghostCache[key] { return c }
    var g: GhostRun? = nil
    if let o = jsonObj(localStorage.getItem(key)), num(o["v"]) == 1 { g = fgDecode(o) }
    ghostCache[key] = g
    return g
}
func ghostScore(_ mode: String) -> Int { loadGhost(mode)?.score ?? 0 }
func encRun(_ R: GhostRec, _ sc: Int) -> [String: Any] {
    let (ys, xs, rs) = encArrays(R.y, R.x, R.r)
    return ["v": 1, "score": sc, "seed": R.seed, "phase": R.phase, "pipes": R.pipes, "skin": R.skin, "n": R.y.count, "y": ys, "x": xs, "r": rs]
}
@discardableResult func saveGhost(_ rec: GhostRec, _ sc: Int) -> Bool {
    let enc = encRun(rec, sc)
    localStorage.setItem(ghostKey(rec.hard), jsonStr(enc))
    ghostCache[ghostKey(rec.hard)] = fgDecode(enc)
    return true
}
func spawnerAction() -> Action? { scene.action("pipeSpawner") }
func spawnerRemaining() -> Double {
    guard let a = spawnerAction() else { return 0 }
    return a.i == 1 ? max(0, a.steps[1].dur - a.t) : 0
}
func setSpawnerRemaining(_ rem: Double) {
    guard let a = spawnerAction() else { return }
    a.i = 1; a.started = true; a.t = max(0, a.steps[1].dur - rem)
}
func ghostStart() {
    let daily = gameMode == "daily" && START_SCORE == 0 && WATCH == nil
    if daily { dailyFresh(); pipeList = pipeList.filter { $0.gold || $0.falling != nil }; setSpawnerRemaining(0.25) }
    ghostStartBase()
    if daily, let R = ghostRec, ghostPlay == nil {   // (with your own daily ghost on, its course is today's already)
        let s = dailySeed()
        courseRng = mulberry32(s); R.seed = Double(s); R.pipes = []; R.phase = spawnerRemaining()
    }
}
private func ghostStartBase() {
    ghostRec = nil; ghostPlay = nil; courseRng = { mrand() }
    if liveCourse() { return }
    if START_SCORE > 0 || afterlife >= 2 { return }
    let g = friendRaceGhost() ?? (ghostOn ? loadGhost(gameMode) : nil)
    var seed: Double
    if let g = g {
        pipeList = g.pipes.map { Pipe.from($0) }.filter { !($0.gx + 30 < bird.x - BIRD_RADIUS) }
        setSpawnerRemaining(g.phase)
        seed = g.seed
        ghostPlay = (g, 1)
    } else { seed = Double(UInt32.random(in: 0...UInt32.max)) }
    courseRng = mulberry32(seedU32(seed))
    let R = GhostRec()
    R.seed = seed; R.hard = gameMode; R.phase = spawnerRemaining()
    R.pipes = pipeList.filter { !$0.gold && $0.falling == nil }.map { $0.json() }
    R.skin = birdColor
    ghostRec = R
}
func ghostSample(_ t: Double) {
    // v147: watching a replay: the bird follows the recorded path; the game's own collisions still end it
    if let W = WATCH, !W.done, bird.dynamic, !isShowingGameOver {
        let g = W.g, n = g.y.count, fi = t * GHOST_HZ
        if fi < Double(n - 1) {
            let i0 = max(0, Int(floor(fi))), f = fi - Double(i0), i1 = i0 + 1
            let ny = (Double(g.y[i0]) + Double(Int(g.y[i1]) - Int(g.y[i0])) * f) / 4
            bird.vy = Double(Int(g.y[i1]) - Int(g.y[i0])) / 4 * GHOST_HZ
            bird.y = ny; bird.x = (Double(g.x[i0]) + Double(Int(g.x[i1]) - Int(g.x[i0])) * f) / 4
            bird.rot = (Double(g.r[i0]) + Double(Int(g.r[i1]) - Int(g.r[i0])) * f) / 60
            if i0 >= max(1, W.lastI + 1) {
                for k in max(1, W.lastI + 1)...i0 {
                    let d1 = Int(g.y[k]) - Int(g.y[k - 1]), d0 = k > 1 ? Int(g.y[k - 1]) - Int(g.y[k - 2]) : -1
                    if d1 > 0 && d0 <= 0 && k > 2 { lastFlapTime = sceneTime; if playSounds { rawPlay("wing") }; trailFlap() }
                }
            }
            W.lastI = max(W.lastI, i0)
        }
    }
    guard let R = ghostRec, !R.done, bird.dynamic else { return }
    let cur = (t: t, x: bird.x, y: bird.y, r: bird.rot)
    let p = R.prev ?? cur
    while Double(R.next) / GHOST_HZ <= t + 1e-9 {
        let tt = Double(R.next) / GHOST_HZ, f = cur.t > p.t ? min(1, max(0, (tt - p.t) / (cur.t - p.t))) : 1
        R.y.append(Int16(clamping: Int(jsRound((p.y + (cur.y - p.y) * f) * 4))))
        R.x.append(Int16(clamping: Int(jsRound((p.x + (cur.x - p.x) * f) * 4))))
        R.r.append(Int8(max(-127, min(127, Int(jsRound((p.r + (cur.r - p.r) * f) * 60))))))
        R.next += 1
        if R.y.count >= GHOST_MAX { R.done = true; break }
    }
    R.prev = cur
}
/// the bird hit the ground: keep the run if it beat this mode's ghost (plus everything the add-ons do then)
func ghostRunEnded() {
    let daily = gameMode == "daily" && !runUsedBot && START_SCORE == 0
    let racedM = raceInfo != nil ? raceId : nil, sM = score, botM = runUsedBot || START_SCORE > 0 || autoplay, modeM = gameMode
    let R = ghostRec, raced = raceInfo != nil ? raceId : nil
    // the website's own ghost save
    if let R = R {
        R.done = true; ghostRec = nil
        if !(runUsedBot || START_SCORE > 0 || score <= 0 || R.y.isEmpty) { if score > ghostScore(R.hard) { saveGhost(R, score) } }
    }
    // v134: the round you just played (for duel replies)
    if let R = R, !R.y.isEmpty, score > 0 { lastRun = LastRun(enc: encRun(R, score), score: score, mode: R.hard, raced: raced, bot: runUsedBot || START_SCORE > 0) } else { lastRun = nil }
    // v138: racing a friend's run goes in the duel history
    if let rd = racedM, !botM, accSignedIn(), let f = friendList.first(where: { $0.id == rd }), let uid = f.uid, let gid = f.gid, uid != ACCT.uid {
        recordMatch("race", gid, uid, sM, f.score, f.m.isEmpty ? modeM : f.m)
    }
    // v147: the Daily streak
    if daily {
        let today = dailyDate(Date()), last = loadStr("dailyLast", "")
        if last != today {
            let st = last == dailyDate(Date(timeIntervalSinceNow: -86400)) ? (Int(loadStr("dailyStreak", "0")) ?? 0) + 1 : 1
            saveStr("dailyStreak", String(st)); saveStr("dailyLast", today)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast("Daily streak: \(st)" + (st == 1 ? " day" : " days") + " \u{1F525}") }
        }
    }
    if let W = WATCH { W.done = true }
}
func drawGhost() {
    if let W = WATCH, !W.done { return }
    if let P = ghostPlay, bird.dynamic {
        let g = P.g, t = sceneTime - gameStartTime, fi = t * GHOST_HZ, n = g.y.count
        var i0 = Int(floor(fi)), f = fi - Double(i0)
        if i0 >= n - 1 { i0 = n - 1; f = 0 }
        let endFade = max(0, min(1, 1 - (fi - Double(n - 1)) / (GHOST_HZ * 0.5)))
        if isShowingGameOver { ghostPlay!.fade = max(0, P.fade - 0.06) }
        let a = 0.42 * endFade * ghostPlay!.fade
        if a > 0.01 {
            let i1 = min(n - 1, i0 + 1)
            let y = (Double(g.y[i0]) + Double(Int(g.y[i1]) - Int(g.y[i0])) * f) / 4, x = (Double(g.x[i0]) + Double(Int(g.x[i1]) - Int(g.x[i0])) * f) / 4
            let r = (Double(g.r[i0]) + Double(Int(g.r[i1]) - Int(g.r[i0])) * f) / 60
            let seq = [1, 2, 3, 2], frame = seq[Int(floor(t / C.animationFrameDuration)) % 4]
            ensureSkin(g.skin)
            ctx.globalAlpha = a
            spr(img(g.skin + "_\(frame)") ?? img("yellow_\(frame)"), x, y, C.birdScale, C.birdScale, r)
            ctx.globalAlpha = 1
        }
        // v132: their name over a friend's ghost
        if let fr = g.friend {
            let a2 = endFade * ghostPlay!.fade
            if a2 > 0.02 {
                let i1 = min(n - 1, i0 + 1)
                let y = (Double(g.y[i0]) + Double(Int(g.y[i1]) - Int(g.y[i0])) * f) / 4, x = (Double(g.x[i0]) + Double(Int(g.x[i1]) - Int(g.x[i0])) * f) / 4
                let label = fgLabel(fr)
                fgText(label, jsRound(x - panelTextWidth(label) / 2), jsRound(y + 36), 0.9 * a2)
            }
        }
    }
    // v134: the other player in a live duel
    if let L = liveRoom, let o = L.oppState, let opp = L.opp {
        let age = Date().timeIntervalSince(o.at) * 1000
        if (bird.dynamic || isGameOver) && o.round == L.round && age <= 4000 {
            ensureSkin(opp.bird)
            let seq = [1, 2, 3, 2], frame = seq[Int(floor(sceneTime / C.animationFrameDuration)) % 4]
            ctx.globalAlpha = o.dead ? 0.25 : 0.55; spr(img(opp.bird + "_\(frame)") ?? img("yellow_\(frame)"), bird.x, o.y, C.birdScale, C.birdScale, o.r); ctx.globalAlpha = 1
            let label = fgLabel(opp.name) + " \(o.score)"
            fgText(label, jsRound(bird.x - panelTextWidth(label) / 2), jsRound(o.y + 36), o.dead ? 0.5 : 0.9)
        }
    }
}

// ---------- Autoplay bot ----------
var botHandsOff = false, botTimer = 0.0, runUsedBot = false, botLastFlap = -1.0, botAcc = 0.0, botTier = 0
func BOT_FLAP_VY() -> Double { C.flapImpulse / BIRD_MASS }
let BOT_N = 120, BOT_STEP = 1.0 / 60, BOT_MIN_GAP = 5
var BOT_NODE_BUDGET = 40000, BOT_TOTAL_BUDGET = 60000, BOT_FOLLOW = true, botNodesUsed = 0
struct BotPipe { var gx: Double, lo: Double, hi: Double, amp: Double, y0: Double, ph: Double, wk: Double, tr: Double, d: Double, y: Double }
struct BotWorld {
    let pipes: [BotPipe], bx: Double, V: Double, R: Double, w0: Double, wt: Double, lag: Double
    func alive(_ k: Int, _ y: Double) -> Bool {
        if y < 224 + R + 4 { return false }
        let t = Double(k) * BOT_STEP - lag
        for q in pipes where abs(bx - (q.gx - V * t)) < 30 + R + 2 {
            if q.amp != 0 { let lo = q.lo + q.amp * sin((q.tr + V * t) * q.wk + q.ph) - (q.y - q.y0); if y < lo || y > lo + q.d { return false } }
            else if y < q.lo || y > q.hi { return false }
        }
        return true
    }
    func adv(_ k: Int, _ y0: Double, _ vy0: Double) -> (Bool, Double, Double) {
        let G = GRAVITY + (w0 != 0 || wt != 0 ? wt + (w0 - wt) * exp(-WIND_EASE * Double(k) * BOT_STEP) : 0)
        var y = y0, vy = vy0
        for _ in 0..<2 { vy += G / 120; vy /= 1 + 0.1 / 120; y += vy / 120 }
        return (alive(k + 1, y), y, vy)
    }
}
func botWorld(_ extra: Double) -> BotWorld {
    let R = BIRD_RADIUS, M = 9 + extra, bx = bird.x, V = 200 * speedMul()
    var pipes: [BotPipe] = []
    var lastReal = Int.max
    if ending.on { lastReal = !ending.collapsed.contains(END.collapse1) ? END.collapse1 : (!ending.collapsed.contains(END.collapse2) ? END.collapse2 : Int.max) }
    let order = pipeList.filter { !$0.gold && $0.falling == nil && !$0.scored }.sorted { $0.gx < $1.gx }
    for p in pipeList {
        if p.gold || p.falling != nil { continue }
        if !p.scored, let idx = order.firstIndex(where: { $0 === p }), lastReal != Int.max, idx + score + 1 > lastReal { continue }
        let bottom = p.y + 160
        pipes.append(BotPipe(gx: p.gx, lo: bottom + R + M, hi: bottom + p.gapV - R - M, amp: p.amp ?? 0, y0: p.y0 ?? 0, ph: p.ph ?? 0, wk: p.wk ?? 0, tr: p.traveled, d: p.gapV - 2 * (R + M), y: p.y))
    }
    return BotWorld(pipes: pipes, bx: bx, V: V, R: R, w0: windAy, wt: windTarget, lag: botLag)
}
final class BotPath { var flaps: Set<Int>, n: Int, extra: Double, t0 = 0.0; init(_ f: Set<Int>, _ n: Int, _ e: Double) { flaps = f; self.n = n; extra = e } }
func botPlan(_ y0: Double, _ vy0: Double, _ since0: Int, _ flapNow: Bool, _ extra: Double = 0) -> BotPath? {
    let W = botWorld(extra)
    var seen: [Int: Bool] = [:]; var nodes = 0, blown = false
    func dfs(_ k: Int, _ y: Double, _ vy: Double, _ since: Int) -> Bool {
        if k >= BOT_N { return true }
        let key = ((k * 1024 + max(0, min(1023, Int(jsRound(y / 2))))) * 1024 + max(0, min(1023, Int(jsRound(vy / 8 + 512))))) * 8 + min(since, BOT_MIN_GAP)
        if let hit = seen[key] { return hit }
        botNodesUsed += 1
        nodes += 1; if nodes > BOT_NODE_BUDGET { blown = true; return false }
        var okv = false
        var r = W.adv(k, y, vy)
        if r.0 && dfs(k + 1, r.1, r.2, since + 1) { okv = true }
        else if since >= BOT_MIN_GAP { r = W.adv(k, y, BOT_FLAP_VY()); if r.0 && dfs(k + 1, r.1, r.2, 1) { okv = true } }
        if !blown { seen[key] = okv }
        return okv
    }
    let r = W.adv(0, y0, flapNow ? BOT_FLAP_VY() : vy0)
    var since = flapNow ? 1 : since0 + 1
    if !(r.0 && dfs(1, r.1, r.2, since)) { return nil }
    var flaps = Set<Int>(); if flapNow { flaps.insert(0) }
    var y = r.1, vy = r.2
    for k in 1..<BOT_N {
        let a = W.adv(k, y, vy)
        if a.0 && dfs(k + 1, a.1, a.2, since + 1) { y = a.1; vy = a.2; since += 1 }
        else { let f = W.adv(k, y, BOT_FLAP_VY()); flaps.insert(k); y = f.1; vy = f.2; since = 1 }
    }
    return BotPath(flaps, BOT_N, extra)
}
func botPathOK(_ path: BotPath, _ j: Int) -> Bool {
    let W = botWorld(path.extra)
    var y = bird.y, vy = bird.vy
    if j < path.n { for k in j..<path.n {
        let r = W.adv(k - j, y, path.flaps.contains(k) ? BOT_FLAP_VY() : vy)
        if !r.0 { return false }
        y = r.1; vy = r.2
    } }
    return true
}
var botPath: BotPath? = nil, botStartCheck = 0.0, BOT_KEEP = 75
func autoBot(_ dt: Double) {
    if !autoplay || settingsNode.added || PK.open { botTimer = 0; botPath = nil; return }
    if !isWaitingToStart && !isGameOver && !bird.dynamic && flappyBird.added && playButton.added && !hitButton {
        botTimer += dt
        if botTimer > 1.5 { botTimer = 0; handlePlayTap() }
        return
    }
    if isWaitingToStart && tapTap.added && !hitButton {
        botTimer += dt; botStartCheck -= dt; botPath = nil
        if botTimer > 0.9 && botStartCheck <= 0 {
            botStartCheck = 0.05
            botLag = 0
            if !pipeList.contains(where: { abs($0.gx - bird.x) < 30 + BIRD_RADIUS + 12 }) && (botPlan(bird.y, 0, 99, true) != nil || botTimer > 8) {
                botTimer = 0; runUsedBot = true; botLastFlap = sceneTime; botNext = BOT_STEP; botPath = nil; startGame()
            }
        }
        return
    }
    if isGameOver {
        botPath = nil
        if playButton.added && playButton.scale > 0 && !hitButton {
            botTimer += dt
            if botTimer > 3.5 { botTimer = 0; handlePlayTap() }
        } else { botTimer = 0 }
        return
    }
    botTimer = 0
    if botHandsOff { botPath = nil }
}
var botNext = BOT_STEP, botLag = 0.0
func botFlying() -> Bool { autoplay && !settingsNode.added && !botHandsOff && bird.dynamic && !isGameOver && moving.speed > 0 && !isWaitingToStart }
func botDecide(_ now: Double, _ lag: Double) {
    botLag = lag
    let since = min(99, Int(jsRound((now - botLastFlap) / BOT_STEP)))
    let canFlap = since >= BOT_MIN_GAP
    var flap = false
    if !pipeList.contains(where: { !$0.gold && $0.falling == nil && $0.gx + 30 > bird.x - 30 }) {
        flap = bird.y < 360 && bird.vy < 100 && canFlap; botTier = 0; botPath = nil
    } else {
        var used = false
        if let bp = botPath, BOT_FOLLOW {
            let j = Int(jsRound((now - bp.t0) / BOT_STEP))
            let roomy = bp.extra >= 10 || j % 8 != 0
            if bp.n - j >= BOT_KEEP && roomy && botPathOK(bp, j) { flap = bp.flaps.contains(j) && canFlap; used = true }
        }
        if !used {
            botPath = nil
            let tiers: [(Bool, Double, Int)] = [(false, 10, 1), (true, 0, 2), (false, 0, 3), (true, -6, 4), (false, -6, 5), (true, -8, 7), (false, -8, 8)]
            botNodesUsed = 0
            for (fl, ex, tier) in tiers {
                if fl && !canFlap { continue }
                if botNodesUsed > BOT_TOTAL_BUDGET { break }
                if let res = botPlan(bird.y, bird.vy, since, fl, ex) { botPath = res; res.t0 = now; flap = fl; botTier = tier; used = true; break }
            }
        }
        if !used {
            var nx: Pipe? = nil
            for p in pipeList where !p.gold && p.falling == nil && p.gx + 30 > bird.x - 30 && (nx == nil || p.gx < nx!.gx) { nx = p }
            flap = canFlap && bird.vy < 0 && bird.y < (nx != nil ? nx!.y + 160 + 65 : 380); botTier = 6
        }
    }
    if flap { botLastFlap = now; runUsedBot = true; flapBird() }
}

// ===================== v115: replay theater =====================
func updateExtras(_ dt: Double) {
    recordReplay(dt)
    liveTick()
    updateTrailGame(dt)
}
struct RPFrame { var bx, by, br: Double, bf: Int, gx, sx: Double, s: Int, p: [(Double, Double, Double, Bool, Bool)] }
struct RPMeta { var skin: String, night: Bool, season: String, weather: String, mode: String }
final class Replay { var frames: [RPFrame] = [], acc = 0.0, meta: RPMeta? = nil, after = 0.0, keepMenu = false, playing = false }
let RP = Replay()
let RP_HZ = 30.0, RP_MAX = 30 * 8
func recordReplay(_ dt: Double) {
    if afterlife != 0 { return }
    if !bird.dynamic && !isShowingGameOver { if isWaitingToStart && !RP.frames.isEmpty && !RP.keepMenu { RP.frames = [] }; return }
    if hasHitGround && RP.after > 1.0 { return }
    if hasHitGround { RP.after += dt } else { RP.after = 0 }
    RP.acc += dt
    if RP.acc < 1 / RP_HZ { return }
    RP.acc = 0
    RP.frames.append(RPFrame(bx: bird.x, by: bird.y, br: bird.rot, bf: [1, 2, 3, 2][Int(floor(bird.animT / C.animationFrameDuration)) % 4], gx: groundX, sx: skyX, s: score,
                             p: pipeList.filter { $0.falling == nil }.map { ($0.gx, $0.y, $0.gapV, $0.red, $0.gold) }))
    if RP.frames.count > RP_MAX { RP.frames.removeFirst() }
    RP.meta = RPMeta(skin: birdColor, night: skyIsNight, season: weatherOn() ? WX.season : "classic", weather: weatherOn() ? WX.weather : "clear", mode: gameMode)
}
func replayHas() -> Bool { Double(RP.frames.count) > RP_HZ }
func handleLeadersTap() {
    if hitButton { return }
    hitButton = true; playSound("swoosh"); leadersButton.scale = 1.15
    run(scene, [.wait(0.1), .call({ haptic(); leadersButton.scale = 1.2 }), .wait(0.1)], "leadersTap", done: { hitButton = false; lbMode = gameMode; openSheet("leaders") })
}
func handleReplayTap() {
    if hitButton || !replayHas() { return }
    hitButton = true; playSound("swoosh"); replayButton.scale = 1.15
    run(scene, [.wait(0.1), .call({ haptic(); replayButton.scale = 1.2 }), .wait(0.1)], "replayTap", done: { hitButton = false; openSheet("replay") })
}
func handleShareTap() {
    if hitButton { return }
    hitButton = true
    playSound("swoosh")
    shareButton.scale = 1.15
    let snap = cardSnapshot()
    run(scene, [.wait(0.1), .call({ haptic(); shareButton.scale = 1.2 }), .wait(0.1)], "shareTap", done: { hitButton = false; PK_CARD = snap; openSheet("card") })
}

// ===================== v147: Daily Challenge =====================
private let utcFmt: DateFormatter = { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC"); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f }()
func dailyDate(_ d: Date = Date()) -> String { utcFmt.string(from: d) }
func dailyKey(_ d: Date = Date()) -> String { "daily-" + dailyDate(d).replacingOccurrences(of: "-", with: "") }
func dailySeed() -> UInt32 { var h: UInt32 = 2166136261; for c in dailyKey().utf8 { h ^= UInt32(c); h = h &* 16777619 }; return h }
func dailyHoursLeft() -> Int {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
    let next = c.startOfDay(for: Date()).addingTimeInterval(86400)
    return max(1, Int(ceil(next.timeIntervalSinceNow / 3600)))
}
func dailyStreak() -> Int {
    let st = Int(loadStr("dailyStreak", "0")) ?? 0, last = loadStr("dailyLast", "")
    return last == dailyDate() || last == dailyDate(Date(timeIntervalSinceNow: -86400)) ? st : 0
}
func dailyFresh() {
    let k = dailyKey()
    if loadStr("dailyOf", "") == k { return }
    localStorage.removeItem("fb_bestScore_daily"); localStorage.removeItem("fb_ghost_daily")
    ghostCache[ghostKey("daily")] = nil
    saveStr("dailyOf", k)
}

// ===================== v147: watch the best runs =====================
final class Watch { let g: GhostRun, name: String, mode: String, prevMode: String; var done = false, lastI = 0
    init(_ g: GhostRun, _ n: String, _ m: String, _ p: String) { self.g = g; name = n; mode = m; prevMode = p } }
var WATCH: Watch? = nil
var watchBarText: String? = nil
func watchBest(_ uid: String, _ mode: String, _ name: String) {
    if !accSignedIn() { toast("Sign in to watch replays"); accGo("account"); return }
    if bird.dynamic && !isGameOver { toast("Finish your round first"); return }
    let key = mode == "daily" ? dailyKey() : mode
    sb("ghosts?select=data,score,name&user_id=eq.\(uid)&mode=eq.\(key)&order=score.desc&limit=1") { res in
        switch res {
        case .failure(let e): toast(e.message)
        case .success(let v):
            let rows = v as? [[String: Any]] ?? []
            guard let row = rows.first, let g = fgDecode(row["data"] as? [String: Any]) else { toast("No replay saved for that run yet"); return }
            let W = Watch(g, name.isEmpty ? (row["name"] as? String ?? "Player") : name, mode, gameMode)
            WATCH = W
            if gameMode != mode { setGameMode(mode) }
            closePicker()
            playSound("swoosh")
            watchBarText = "\u{25B6}  Watching \(W.name)'s best: \(g.score)"
            UIBridge.shared.refresh()
            func go() { if isWaitingToStart { startGame(); return }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { go() } }
            if isWaitingToStart { startGame() } else { handlePlayTap(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { go() } }
        }
    }
}
func watchEnd() {
    guard let W = WATCH else { return }
    let m = W.prevMode; WATCH = nil
    watchBarText = nil; UIBridge.shared.refresh()
    if gameMode != m { setGameMode(m) }
}
func friendRaceGhost() -> GhostRun? {
    if let W = WATCH, !W.done { raceInfo = nil; return W.g }
    raceInfo = nil
    guard let f = friendList.first(where: { $0.id == raceId }), f.m == gameMode else { return nil }
    var g = fgCache[f.id]
    if g == nil { g = fgDecode(f.g); if g == nil { return nil }; g!.friend = f.name; fgCache[f.id] = g }
    raceInfo = (f.name, g!.score)
    return g
}
func jsRound(_ x: Double) -> Double { floor(x + 0.5) }
extension Double { /// Math.round, the JavaScript way (halves go up)
    var jr: Double { (self + 0.5).rounded(.down) } }
