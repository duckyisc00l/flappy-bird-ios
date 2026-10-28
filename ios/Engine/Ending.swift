import Foundation

// ===================== "The ending of Flappy Bird" (from the video) =====================
// Score 920-949: packed pipe walls. 936 and 974: the pipes topple like dominoes. 950-973: walls again. 975-998: normal
// pipes. From pipe 980 on the pipes are bloody. 999: a bird just like yours flies through the other way. 1012: more of
// them. 1014: a swarm fills the sky and kills you. The next game shows -1, the next pipe never seems to come, then the
// original bird appears with a Morse message and the screen goes black, then the game comes back haunted.

var START_SCORE = 0
let END = (wallStart: 920, collapse1: 936, wallResume: 937, collapse2: 974, plantsFrom: 976, last: 999)
final class Stranger { var x = 0.0, y = 0.0, vy = 0.0, rot = 0.0, lastFlap = -9.0, t = 0.0, skin = "yellow", speed = 150.0, kill = false, offset = 0.0, base = 0.0, steer = true }
final class EndingState {
    var on = false, next = 0.0, gapBottom = 430.0, dir = 1.0, collapsed: Set<Int> = [], frozen = false
    var strangers: [Stranger] = [], waves: Set<Int> = [], swarmed = false, swarm = false
    var fill: Double? = nil   // seconds since the swarm filled the screen
}
var ending = EndingState()
func resetEnding() { ending = EndingState() }

func passedCount() -> Int { haunted ? -score : score }
func pipeNumberNext() -> Int { var pending = 0; for p in pipeList where !p.scored && p.falling == nil && !p.gold { pending += 1 }; return passedCount() + pending + 1 }
func nextPipeK() -> Int { var pending = 0; for p in pipeList where !p.scored && p.falling == nil && !p.gold { pending += 1 }; return score + pending + 1 }
func endingWantsControl() -> Bool {
    if ending.on { return true }
    if !bird.dynamic || isGameOver { return false }
    if nextPipeK() >= END.wallStart {
        ending.on = true; ending.next = 0
        for at in [END.collapse1, END.collapse2] where score >= at { ending.collapsed.insert(at) }
        return true
    }
    return false
}
func pushPipe(_ y: Double, distance: Double? = nil) {
    let bw = birdWidthNow()
    let p = Pipe()
    p.k = pipeNumberNext(); p.gx = width + 30 * 2; p.traveled = 0; p.distance = distance ?? (width + 2 * 30 + 25); p.y = y
    p.sensorX = 30 + bw / 2 + 2; p.red = gameMode == "hard"
    pipeList.append(p)
}
func wallGap() -> Double {
    if crand() < 0.15 { ending.dir *= -1 }
    ending.gapBottom += ending.dir * (4 + crand() * 8)
    if ending.gapBottom > 540 { ending.gapBottom = 540; ending.dir = -1 }
    if ending.gapBottom < 320 { ending.gapBottom = 320; ending.dir = 1 }
    return (ending.gapBottom - 160).jr
}
func normalY() -> Double { let q = floor(height / 4); return floor(crand() * q) + q }
func endingUpdate(_ dt: Double) {
    if !ending.on || isGameOver || moving.speed == 0 { return }
    for at in [END.collapse1, END.collapse2] where score >= at && !ending.collapsed.contains(at) { ending.collapsed.insert(at); collapsePipes(); ending.next = max(ending.next, 1.3) }
    if ending.frozen { return }
    ending.next -= dt
    if ending.next > 0 { return }
    let k = nextPipeK()
    if k >= END.wallStart && k <= END.collapse2 { pushPipe(wallGap()); ending.next = k == END.collapse2 ? 1.0 : 0.3; return }
    // normal pipes (the biting plants from 976 were removed, but their dice are still rolled so the course stays the same)
    if k >= END.plantsFrom && k <= END.last { let r = crand(); if r < 0.45 || r < 0.7 { _ = crand() } }
    pushPipe(normalY())
    ending.next = 1.0
}
func collapsePipes() {
    let list = pipeList.filter { $0.falling == nil && !$0.gold }.sorted { $0.gx < $1.gx }
    for (i, p) in list.enumerated() { p.falling = (t: -Double(i) * 0.05, ang: 0, vel: 0.4) }
    playSound("hit")
}
func updateFalling(_ dt: Double) {
    for p in pipeList {
        guard var f = p.falling else { continue }
        f.t += dt
        if f.t >= 0 { f.vel += 5.5 * dt; f.ang += f.vel * dt }
        p.falling = f
    }
    pipeList = pipeList.filter { !($0.falling != nil && $0.falling!.ang > 1.75) }
}
func drawPipeRotated(_ im: Img?, _ R: R4, _ hingeY: Double, _ ang: Double) {
    ctx.save()
    ctx.translate(R.cx, hingeY)
    ctx.rotate(hingeY < 400 ? -ang : ang)
    spr(im, 0, R.cy - hingeY, 2, 2, 0)
    ctx.restore()
}

// Blood on the pipes: every pipe from number 980 on is bloody, more so the closer you get to 999.
let PB_COL = ["#6a040e", "#940a14", "#bc121c", "#d81e26", "#f2383e"]
func pbShade(_ c: Int, _ onCap: Bool) -> Int {
    let k = Double(onCap ? c + 2 : c)
    let L = k <= 1 ? 0.3 : k <= 8 ? 0.55 + 0.45 * (k - 1) / 7 : k <= 19 ? 1 - (k - 8) / 11 * 0.72 : 0.26
    return max(0, min(4, Int(floor(L * 4.6))))
}
final class PipeBlood {
    var low: [(c: Int, row: Int, kind: String)] = [], up: [(c: Int, row: Int, kind: String)] = []
    var lowSet: [String: String] = [:], upSet: [String: String] = [:]
    var drips: [(c: Int, w: Int, max: Int, speed: Double)] = []
    var hang: [(c: Int, len: Int, period: Double, phase: Double)] = []
    var imgL: (cv: Img, lo: Int, hi: Int)? = nil, imgU: (cv: Img, lo: Int, hi: Int)? = nil
}
func pipeBloodCells(_ p: Pipe) -> PipeBlood {
    if let b = p.pb { return b }
    var s = Double((p.k * 7919 + 12345) % 2147483647); if s == 0 { s = 1 }
    func r() -> Double { s = (s * 16807).truncatingRemainder(dividingBy: 2147483647); return s / 2147483647 }
    let sev = max(0.35, min(1, Double(p.k - 978) / 20))
    let B = PipeBlood()
    func add(_ lower: Bool, _ c: Int, _ row: Int, _ kind: String) {
        guard c >= 1 && c <= 28 else { return }
        let key = "\(c),\(row)"
        if lower { if B.lowSet[key] == nil { B.low.append((c, row, kind)) } else { if let i = B.low.firstIndex(where: { $0.c == c && $0.row == row }) { B.low[i].kind = kind } }; B.lowSet[key] = kind }
        else { if B.upSet[key] == nil { B.up.append((c, row, kind)) } else { if let i = B.up.firstIndex(where: { $0.c == c && $0.row == row }) { B.up[i].kind = kind } }; B.upSet[key] = kind }
    }
    let a = 2 + Int(floor(r() * 7)), b = min(27, a + 11 + Int(floor(r() * 9 * sev)))
    if a + 2 <= b - 2 { for c in (a + 2)...(b - 2) { add(true, c, -1, "pool"); if c > a + 4 && c < b - 4 && r() < 0.75 { add(true, c, -2, "pool") } } }
    var d = 4 + Int(floor(r() * 3))
    for c in a...b {
        d = max(3, min(9, d + Int(((r() - 0.5) * 2).jr)))
        var depth = (c == a || c == b) ? max(1, d - 3) : d
        if c > a && c < b && r() < 0.28 { depth = 11 }
        for row in 0...depth { add(true, c, row, "cap") }
    }
    let nDrips = 2 + Int((sev * 4).jr)
    for _ in 0..<nDrips {
        let c = max(2, min(27, a + 1 + Int(floor(r() * Double(b - a - 1)))))
        B.drips.append((c, r() < 0.4 ? 2 : 1, 10 + Int(floor(r() * 50 * sev)), 0.5 + r() * 0.9))
    }
    if r() < 0.45 + sev * 0.5 {
        let sc = max(2, min(22, a + Int(floor(r() * Double(max(1, b - a - 5)))))), w = 4 + Int(floor(r() * 3)), len = 30 + Int(floor(r() * 60 * sev))
        var jag = 0
        for row in 12..<(12 + len) {
            let f = Double(row - 12) / Double(len); jag = max(-1, min(1, jag + Int(((r() - 0.5) * 1.2).jr)))
            for c in (sc + jag)..<(sc + w + jag) {
                let edge = c == sc + jag || c == sc + w + jag - 1
                let keep = f < 0.65 ? (edge ? r() < 0.75 : true) : r() < 1 - (f - 0.65) / 0.35 * (edge ? 1 : 0.8)
                if keep { add(true, c, row, "smear") }
            }
        }
    }
    let nSpat = Int((14 + 24 * sev).jr)
    for _ in 0..<nSpat {
        let c = max(2, min(27, a - 4 + Int(floor(r() * Double(b - a + 9))))), row = Int(floor(pow(r(), 1.6) * 26))
        if B.lowSet["\(c),\(row)"] == nil { add(true, c, row, "spat") }
    }
    let c0 = 5 + Int(floor(r() * 18)), r0 = 3 + Int(floor(r() * 6)), rad = 3 + sev * 4
    let cr = Int(ceil(rad))
    for dc in -cr...cr { for dr in -cr...cr {
        let t = hypot(Double(dc) / rad, Double(dr) / (rad * 0.85)) / (0.7 + 0.45 * r())
        if t <= 1 { add(false, c0 + dc, r0 + dr, "splat") } else if t < 1.7 && r() < 0.16 { add(false, c0 + dc, r0 + dr, "spat") }
    } }
    let nSp = 6 + Int(floor(r() * 4))
    for i in 0..<nSp {
        let ang = (Double(i) / Double(nSp)) * Double.pi * 2 + r() * 0.5, L = rad * (1.1 + r() * 1.1)
        var k = rad * 0.6
        while k < L { add(false, Int((Double(c0) + cos(ang) * k * 1.15).jr), Int((Double(r0) + sin(ang) * k * 0.9).jr), "splat"); k += 0.7 }
        add(false, Int((Double(c0) + cos(ang) * (L + 1.2) * 1.15).jr), Int((Double(r0) + sin(ang) * (L + 1.2) * 0.9).jr), "spat")
    }
    let nSt = 1 + Int((sev * 3).jr)
    for _ in 0..<nSt {
        let c = max(2, min(27, c0 - 6 + Int(floor(r() * 13)))), top = 14 + Int(floor(r() * 40 * sev))
        for row in 1...top { if row > top - 2 || r() < 0.93 { add(false, c, row, "streak") } }
        add(false, c + 1, top, "streak"); add(false, c, top + 1, "streak")
    }
    let nH = 1 + Int((sev * 3).jr)
    for _ in 0..<nH {
        let c = max(2, min(27, c0 - 5 + Int(floor(r() * 11))))
        B.hang.append((c, 1 + Int(floor(r() * 4)), 1.3 + r() * 1.8, r() * 3))
    }
    p.pb = B
    return B
}
func drawPipeBlood(_ p: Pipe) {
    let B = pipeBloodCells(p)
    let gapBottom = p.y + 160, gapTop = gapBottom + p.gapV, x0 = p.gx - 30
    if p.bt == nil { p.bt = sceneTime }
    let t = sceneTime - p.bt!
    func cellL(_ c: Int, _ row: Int, _ col: String) { ctx.fill(col); ctx.fillRect(x0 + 2 * Double(c), gapBottom - 2 * Double(row + 1), 2, 2) }
    func cellU(_ c: Int, _ row: Int, _ col: String) { ctx.fill(col); ctx.fillRect(x0 + 2 * Double(c), gapTop + 2 * Double(row), 2, 2) }
    if B.imgL == nil {
        func mk(_ list: [(c: Int, row: Int, kind: String)], _ set: [String: String], _ lower: Bool) -> (cv: Img, lo: Int, hi: Int) {
            var lo = 0, hi = 0
            for e in list { lo = min(lo, e.row); hi = max(hi, e.row) }
            let cv = CGCanvas(30, hi - lo + 1)
            for e in list {
                let c = e.c, row = e.row, kind = set["\(c),\(row)"] ?? e.kind
                let down = lower ? row + 1 : row - 1, upr = lower ? row - 1 : row + 1
                var sh = pbShade(c, row <= 11) - (kind == "smear" ? 1 : 0) - (kind == "spat" ? 1 : 0)
                let thick = kind == "pool" || kind == "cap" || kind == "streak"
                if thick && set["\(c),\(down)"] == nil { sh -= 1 }
                if thick && set["\(c),\(upr)"] == nil { sh += 1 }
                if kind == "splat" && ((c * 7 + row * 13) % 5 == 0) { sh -= 1 }
                cv.fill((kind == "pool" && row == -2 && c % 5 == 2) ? "#ff8a8a" : PB_COL[max(0, min(4, sh))])
                cv.fillRect(Double(c), Double(lower ? row - lo : hi - row), 1, 1)
            }
            return (cv.image(), lo, hi)
        }
        B.imgL = mk(B.low, B.lowSet, true); B.imgU = mk(B.up, B.upSet, false)
    }
    ctx.save(); ctx.imageSmoothingEnabled = false
    ctx.translate(x0, gapBottom - 2 * Double(B.imgL!.lo)); ctx.scale(2, -2); ctx.drawImage(B.imgL!.cv, 0, 0)
    ctx.restore()
    ctx.save(); ctx.imageSmoothingEnabled = false
    ctx.translate(x0, gapTop + 2 * Double(B.imgU!.hi + 1)); ctx.scale(2, -2); ctx.drawImage(B.imgU!.cv, 0, 0)
    ctx.restore()
    for dr in B.drips {
        let len = Int(floor(min(1, t * dr.speed / 2.5) * Double(dr.max)))
        for row in 11...(11 + len) { for k in 0..<dr.w { cellL(dr.c + k, row, PB_COL[max(0, pbShade(dr.c + k, false) - 1)]) } }
        let tip = 12 + len
        for k in -1...dr.w { cellL(dr.c + k, tip, PB_COL[max(0, pbShade(dr.c + k, false) - (k < 0 || k == dr.w ? 2 : 0))]) }
        for k in 0..<dr.w { cellL(dr.c + k, tip + 1, PB_COL[max(0, pbShade(dr.c + k, false) - 1)]) }
        cellL(dr.c, tip, "#ff6b6b")
    }
    let g = 900.0, fall = gapTop - gapBottom
    for hd in B.hang {
        for row in 1...hd.len { cellU(hd.c, -row, PB_COL[max(0, pbShade(hd.c, true) - 1)]) }
        let ph = (t + hd.phase).truncatingRemainder(dividingBy: hd.period), T = (2 * fall / g).squareRoot()
        let y = gapTop - 2 * Double(hd.len) - 0.5 * g * ph * ph
        if ph < T && y > gapBottom + 2 { ctx.fill("#c41622"); ctx.fillRect(x0 + 2 * Double(hd.c), y - 4, 2, 4); ctx.fill("#ff6b6b"); ctx.fillRect(x0 + 2 * Double(hd.c), y - 2, 2, 2) }
        else if ph >= T && ph < T + 0.14 {
            ctx.fill("#c41622")
            let sp = Double(Int(floor((ph - T) / 0.05)))
            for (dx, dy) in [(-2 - sp * 2, 2 + sp), (2 + sp * 2, 2 + sp), (0, 4 + sp * 2)] { ctx.fillRect(x0 + 2 * Double(hd.c) + dx, gapBottom + dy, 2, 2) }
        }
    }
}
func renderEndingPipes() {
    for p in pipeList {
        let R = pipeRects(p)
        let up = p.red ? img("red_up") : img("pipe_up"), down = p.red ? img("red_down") : img("pipe_down")
        let dead: [Death]? = score <= -1 && p.k != 0 && p.falling == nil ? massDeaths(p) : (haunted && p.k != 0 && p.falling == nil ? DEATHS.filter { $0.k == p.k } : nil)
        if let f = p.falling, f.ang > 0 {
            drawPipeRotated(up, R.up, 224, f.ang)
            drawPipeRotated(down, R.down, 768, f.ang)
        } else {
            spr(up, R.up.cx, R.up.cy, 2, 2, 0)
            spr(down, R.down.cx, R.down.cy, 2, 2, 0)
        }
        if !haunted && p.k >= 980 && !p.gold && p.falling == nil { drawPipeBlood(p) }
        if let d = dead, !d.isEmpty { drawDeaths(p, d) }
    }
}

// ===================== After 999: the other birds, -1 and the message =====================
func makeStranger(_ y: Double, dx: Double = 0, skin: String? = nil, speed: Double? = nil, kill: Bool = false, offset: Double = 0, steer: Bool = true) -> Stranger {
    let s = Stranger()
    s.x = (boxW - camX) / camS + 40 + dx; s.y = y; s.t = mrand(); s.skin = skin ?? birdColor
    s.speed = speed ?? 150; s.kill = kill; s.offset = offset; s.base = y; s.steer = steer
    return s
}
func strangerWave(_ s: Int) {
    if ending.waves.contains(s) { return }
    if s == END.last { ending.waves.insert(s); ending.strangers.append(makeStranger(470)) }
    else if s == 1012 {
        ending.waves.insert(s)
        for (off, dx) in [(-40.0, 0.0), (25, 70), (-10, 150), (40, 230), (-30, 320)] { ending.strangers.append(makeStranger(470 + off, dx: dx, speed: 150 + mrand() * 40, offset: off)) }
    } else if s == 1014 {
        ending.waves.insert(s); ending.swarm = true
        for col in 0..<6 { for row in 0..<13 {
            let y = 236 + Double(row) * 46 + Double(col % 2) * 23
            ending.strangers.append(makeStranger(y, dx: Double(col) * 48 + mrand() * 10, skin: "yellow", speed: 330, kill: true, steer: false))
        } }
        playSound("swoosh")
    }
}
func updateStrangers(_ dt: Double) {
    let list = ending.strangers; if list.isEmpty { return }
    let flapV = C.flapImpulse / BIRD_MASS
    for s in list {
        s.t += dt
        s.x -= ((afterlife >= 3 ? 0 : 200 * (moving.speed > 0 ? 1 : 0)) + s.speed) * dt
        var target = s.base
        if s.steer {
            var next: Pipe? = nil
            for p in pipeList where p.falling == nil && p.gx < s.x + 40 && p.gx > s.x - 260 && (next == nil || p.gx > next!.gx) { next = p }
            if let n = next { target = n.y + 160 + n.gapV / 2 + s.offset * 0.25 }
        }
        s.vy += GRAVITY * dt; s.vy /= 1 + dt * LINEAR_DAMPING; s.y += s.vy * dt
        if s.y < target && s.vy < 60 && s.t - s.lastFlap > 0.2 { s.vy = flapV * (s.kill ? 0.8 : 1); s.lastFlap = s.t }
        if s.y < 236 { s.y = 236; s.vy = flapV; s.lastFlap = s.t }
        let since = s.t - s.lastFlap
        s.rot = since < C.flapRotationHold ? C.flapRotation : max(-1.2, min(0.6, s.vy * 0.002))
    }
    ending.strangers = list.filter { $0.x > -camX / camS - 80 }
}
var shakeT = 99.0
func drawArmyFill() {
    guard let ft = ending.fill else { return }
    let left = -camX / camS - 60, right = (boxW - camX) / camS + 60, reveal = right - ft * 3200
    let seq = [1, 2, 3, 2]; var n = 0
    for layer in 0..<3 {
        var row = 0, y = -12.0 + Double(layer) * 15
        while y < SH + 56 {
            var x = left + Double((row + layer) % 2) * 26 + Double(layer) * 17
            while x < right {
                if x >= reveal {
                    let t = ft + Double(n) * 0.137; n += 1
                    let fr = seq[Int(floor(t / C.animationFrameDuration)) % 4]
                    spr(img("yellow_\(fr)"), x, y + sin(t * 9 + Double(n)) * 3, -C.birdScale, C.birdScale, sin(t * 5 + Double(n)) * 0.25)
                }
                x += 52
            }
            row += 1; y += 38
        }
    }
}
func drawStrangers() {
    for s in ending.strangers {
        ensureSkin(s.skin)
        let seq = [1, 2, 3, 2], f = seq[Int(floor(s.t / C.animationFrameDuration)) % 4]
        let im = img(s.skin + "_\(f)") ?? img("yellow_\(f)")
        spr(im, s.x, s.y, -C.birdScale, C.birdScale, -s.rot)
    }
}

// The -1 run (the game after the swarm): no score, one pipe that takes forever, then the message.
var afterlife = 0
struct AL { var t = 0.0, speed = 1.0, pipe = false, vt = 0.0, beeps = false, bt = 0.0 }
var al = AL()
func startAfterlife() { afterlife = 2; score = -1; al = AL(); pipeList = []; ending.strangers = [] }
func updateAfterlife(_ dt: Double) {
    if afterlife == 2 {
        if isGameOver { return }
        al.t += dt
        if !al.pipe && al.t > 2.2 { al.pipe = true; pushPipe(normalY(), distance: 99999) }
        if al.t > 2.2 { al.speed = max(0.06, 1 - (al.t - 2.2) * 0.22) }
        if al.t > 15 { afterlife = 3; al.vt = 0; bird.dynamic = false; scoreLabel.added = false }
    } else if afterlife == 3 {
        al.vt += dt
        if !al.beeps && al.vt > 0.6 { al.beeps = true; playMorse() }
        if al.vt >= 5.6 { afterlife = 4; al.bt = 0; stopMorse() }
    } else if afterlife == 4 {
        al.bt += dt
        if al.bt >= 3 { returnToNormal() }
    }
}
// "YOU ARE ME AND I AM YOU"
let MORSE_WORDS: [[String]] = [["-.--", "---", "..-"], [".-", ".-.", "."], ["--", "."], [".-", "-.", "-.."], [".."], [".-", "--"], ["-.--", "---", "..-"]]
func morseTimeline() -> [(Bool, Int)] {
    var out: [(Bool, Int)] = []
    for (wi, w) in MORSE_WORDS.enumerated() {
        if wi > 0 { out.append((false, 7)) }
        for (li, l) in w.enumerated() {
            if li > 0 { out.append((false, 3)) }
            for (ci, c) in l.enumerated() { if ci > 0 { out.append((false, 1)) }; out.append((true, c == "-" ? 3 : 1)) }
        }
    }
    return out
}
func playMorse() {
    if !playSounds { return }
    let tl = morseTimeline(), total = tl.reduce(0) { $0 + $1.1 }
    Audio.shared.playMorse(tl, unit: 4.6 / Double(total))
}
func stopMorse() { Audio.shared.stopMorse() }
func drawVision() {
    let v = al.vt, a = min(1, v / 0.6)
    ctx.globalAlpha = 0.35 * a; ctx.fill("#000"); ctx.fillRect(-camX / camS - 10, -10, boxW / camS + 20, SH + 20); ctx.globalAlpha = 1
    let p = pipeList.first { $0.falling == nil }
    let visL = -camX / camS, visR = (boxW - camX) / camS
    let px = p != nil ? max(visL + 40, min(visR - 40, p!.gx)) : (visL + visR) / 2
    let top = p != nil ? p!.y + 160 : 360
    let bx = px, by = top + 46 + sin(v * Double.pi * 2 / 1.0) * 6
    let seq = [1, 2, 3, 2], f = seq[Int(floor(v / C.animationFrameDuration)) % 4]
    ctx.globalAlpha = a
    spr(img("yellow_\(f)"), bx, by, -C.birdScale, C.birdScale, 0)
    ctx.globalAlpha = 1
    if v < 0.6 { return }
    let tl = morseTimeline(), total = Double(tl.reduce(0) { $0 + $1.1 })
    let shown = max(0, (v - 0.65) / 4.6) * total
    let lines = [Array(MORSE_WORDS[0..<2]), Array(MORSE_WORDS[2..<5]), Array(MORSE_WORDS[5...])]
    let strs = lines.map { ws in ws.map { $0.joined(separator: " ") }.joined(separator: "   ") }
    func unitsOf(_ s: String) -> Double { s.reduce(0.0) { $0 + ($1 == " " ? 2 : ($1 == "-" ? 3 : 1) + 1) } }
    let u = 3.0, rowH = 12.0, pad = 8.0
    let bw = (strs.map(unitsOf).max() ?? 0) * u + pad * 2, bh = Double(strs.count) * rowH + pad * 2 - 4
    let visTop = SH + camY / camS
    let x0 = max(visL + 8, min(visR - 8 - bw, bx - bw / 2)), y0 = min(top + 46 + 36, visTop - bh - 10)
    ctx.fill("#533846"); ctx.fillRect(x0 - 2, y0 - 2, bw + 4, bh + 4)
    ctx.fill("#ffffff"); ctx.fillRect(x0, y0, bw, bh)
    let tx = max(x0 + 8, min(x0 + bw - 16, bx - 4))
    ctx.fill("#533846"); ctx.fillRect(tx - 2, y0 - 10, 12, 10)
    ctx.fill("#ffffff"); ctx.fillRect(tx, y0 - 6, 8, 8); ctx.fillRect(tx + 2, y0 - 8, 4, 4)
    var done = 0.0
    for (li, str) in strs.enumerated() {
        var x = x0 + (bw - unitsOf(str) * u) / 2
        let y = y0 + bh - pad - Double(li) * rowH - 2
        for c in str {
            if c == " " { x += u * 2; continue }
            let w = c == "-" ? 3.0 : 1.0
            done += w
            if done <= shown + 0.5 { ctx.fill("#1e1e1e"); ctx.fillRect(x, y - u, w * u, u + 1) }
            x += (w + 1) * u
        }
    }
}

// ---------- ...but it isn't normal: every one of your deaths stays where it happened ----------
var haunted = false
struct Death: Codable { var k: Int, dx: Int, skin: String, pipe: String?, hy: Int, side: Int, seed: Int }
var DEATHS: [Death] = []
func recordDeath() {
    if runUsedBot || afterlife >= 2 || !bird.dynamic { return }
    var ref: Pipe? = nil
    for p in pipeList where p.k != 0 && p.falling == nil && !p.gold && (ref == nil || abs(p.gx - bird.x) < abs(ref!.gx - bird.x)) { ref = p }
    guard let r = ref else { return }
    let hitPipe = !contactGround && abs(bird.x - r.gx) < 30 + BIRD_RADIUS + 4
    let gapBottom = r.y + 160, gapTop = gapBottom + r.gapV
    DEATHS.append(Death(k: r.k, dx: Int((bird.x - r.gx).jr), skin: birdColor,
                        pipe: hitPipe ? (bird.y > (gapBottom + gapTop) / 2 ? "top" : "bottom") : nil,
                        hy: Int((bird.y - gapBottom).jr), side: bird.x < r.gx - 20 ? -1 : 0, seed: Int(floor(mrand() * 1e6))))
    if DEATHS.count > 150 { DEATHS = Array(DEATHS.suffix(150)) }
    if let d = try? JSONEncoder().encode(DEATHS), let s = String(data: d, encoding: .utf8) { localStorage.setItem("fb_deaths", s) }
}
private var deadImgs: [String: Img] = [:]
func deadImg(_ skin: String) -> Img? {
    if let d = deadImgs[skin] { return d }
    ensureSkin(skin)
    guard let src = img(skin + "_2") ?? img("yellow_2") else { return nil }
    let c = CGCanvas(src.width, src.height); c.imageSmoothingEnabled = false; c.drawImage(src, 0, 0)
    let ox = Double(c.w - 34) / 2, oy = Double(c.h - 24) / 2
    c.fill("#ffffff"); c.fillRect(ox + 20, oy + 2, 8, 9)
    c.fill("#533846")
    for (x, y) in [(20.0, 3.0), (26, 3), (22, 5), (24, 5), (23, 6), (22, 7), (24, 7), (20, 9), (26, 9)] { c.fillRect(ox + x, oy + y, 2, 2) }
    c.fill("#a00010"); for (x, y) in [(6.0, 14.0), (8, 16), (12, 12), (4, 10)] { c.fillRect(ox + x, oy + y, 2, 2) }
    let im = c.image(); deadImgs[skin] = im; return im
}
func blood(_ x: Double, _ y: Double, _ n: Double, _ seed: Int, _ spread: Double, _ drip: Int) {
    var s = Double(seed == 0 ? 1 : seed)
    func r() -> Double { s = (s * 16807).truncatingRemainder(dividingBy: 2147483647); return s / 2147483647 }
    func cell(_ px: Double, _ py: Double, _ c: String) { ctx.fill(c); ctx.fillRect((px / 3).jr * 3, (py / 3).jr * 3, 3, 3) }
    let DARK = "#4a0007", EDGE = "#750009", MID = "#a00010", RED = "#c8101e", BRIGHT = "#e3202b", SHINE = "#ff7a7a"
    let flat = drip == 0 && spread >= 25
    let sq = flat ? 0.42 : 0.72, R = spread * (flat ? 1.05 : 0.85)
    let step = 3.0, cx = (x / 3).jr * 3, cy = (y / 3).jr * 3
    var dy = -R * sq - 3
    while dy <= R * sq + 3 {
        var dx = -R - 3
        while dx <= R + 3 {
            let wob = 0.82 + 0.3 * r()
            let t = hypot(dx / R, dy / (R * sq)) / wob
            if t <= 1 { cell(cx + dx, cy + dy, t > 0.8 ? (r() < 0.55 ? DARK : EDGE) : t > 0.5 ? (r() < 0.6 ? MID : EDGE) : t > 0.25 ? (r() < 0.65 ? RED : MID) : (r() < 0.5 ? BRIGHT : RED)) }
            dx += step
        }
        dy += step
    }
    if n >= 20 { cell(cx - R * 0.3, cy + R * sq * 0.3, SHINE); cell(cx - R * 0.3 + 3, cy + R * sq * 0.3, "#ff4d4d") }
    let m = Int(ceil(n * 0.22))
    for _ in 0..<m {
        let a = r() * Double.pi * 2, d = R * (1 + r() * 0.9), px = cx + cos(a) * d, py = cy + sin(a) * d * (flat ? 0.5 : 0.85)
        cell(px, py, r() < 0.5 ? MID : RED)
        if r() < 0.35 { cell(px + cos(a) * 3, py + sin(a) * 3, EDGE) }
    }
    for _ in 0..<drip {
        let px = ((x + (r() - 0.5) * R * 1.3) / 3).jr * 3, len = 9 + floor(r() * 10) * 3, top = cy - 3
        var k = 0.0
        while k <= len {
            let taper = k > len - 6
            cell(px, top - k, taper ? MID : RED)
            if !taper && k < 9 { cell(px - 3, top - k, EDGE); cell(px + 3, top - k, MID) }
            else if !taper && Int(k) % 12 == 0 { cell(px - 3, top - k, EDGE) }
            k += 3
        }
        cell(px - 3, top - len - 3, EDGE); cell(px, top - len - 3, RED); cell(px + 3, top - len - 3, EDGE)
        cell(px, top - len - 6, MID)
        cell(px - 3, top - len + (len > 15 ? 0 : 3), SHINE)
    }
}
func massDeaths(_ p: Pipe) -> [Death] {
    if let m = p.mass { return m }
    var s = Double((p.k * 48271 + 7) % 2147483647); if s == 0 { s = 1 }
    func r() -> Double { s = (s * 16807).truncatingRemainder(dividingBy: 2147483647); return s / 2147483647 }
    let skins = ["yellow", "red", "blue", birdColor], gap = p.gapV
    var out: [Death] = []
    for i in 0..<5 {
        let top = i % 2 == 1, hitPipe = i != 4
        let dx = Int(((r() - 0.5) * 60).jr)
        let hy = top ? Int((gap + r() * 14).jr) : -Int((r() * 14).jr)
        let side = r() < 0.3 ? -1 : 0
        let seed = Int(floor(r() * 1e6)) + 1
        out.append(Death(k: p.k, dx: dx, skin: skins[i % 4], pipe: hitPipe ? (top ? "top" : "bottom") : nil, hy: hy, side: side, seed: seed))
    }
    p.mass = out
    return out
}
struct Grave { var off: Double, skin: String, flat: Bool, rot: Double, seed: Int }
var GRAVES: [Grave]? = nil
func drawMassGraves() {
    if GRAVES == nil {
        var s = 24681357.0
        func r() -> Double { s = (s * 16807).truncatingRemainder(dividingBy: 2147483647); return s / 2147483647 }
        var g: [Grave] = []
        for j in 0..<13 { let off = 12 + Double(j) * 51 + r() * 22; let fl = r() < 0.35; let rot = (r() - 0.5) * 0.6; g.append(Grave(off: off, skin: ["yellow", "red", "blue", "green"][j % 4], flat: fl, rot: rot, seed: Int(floor(r() * 1e6)) + 1)) }
        GRAVES = g
    }
    let landW = 336.0 * 2, skinNow = birdColor
    for i in 0..<(2 + Int(floor(width / landW))) {
        let base = groundX + Double(i) * (landW - 1)
        for g in GRAVES! {
            let x = base + g.off
            if x < -40 || x > width + 40 { continue }
            blood(x, 225, 16, g.seed, 15, 0)
            let sk = g.skin == "green" ? skinNow : g.skin
            if g.flat { spr(deadImg(sk), x, 224 + 9 * C.birdScale, C.birdScale, C.birdScale, (g.seed % 2 != 0 ? 1 : -1) * (1.2 + g.rot)) }
            else { spr(deadImg(sk), x, 224 + 17 * C.birdScale, C.birdScale, C.birdScale, -Double.pi / 2 + g.rot) }
        }
    }
}
func drawDeaths(_ p: Pipe, _ list: [Death]) {
    let gapBottom = p.y + 160
    for (i, d) in list.enumerated() {
        let x = p.gx + Double(d.dx) + (i > 0 ? Double((d.seed % 17) - 8) + Double(i) * 3 : 0)
        if let pp = d.pipe {
            let hx = d.side < 0 ? p.gx - 28 : x, hy = gapBottom + Double(d.hy) + (pp == "top" ? 12 : -12)
            blood(hx, hy, 34, d.seed, 16, pp == "top" ? 4 : 2)
            blood(hx + 6, hy - 10, 10, d.seed + 3, 8, 1)
        }
        blood(x, 225, 46, d.seed + 7, 30, 0)
        spr(deadImg(d.skin), x, 224 + 17 * C.birdScale, C.birdScale, C.birdScale, -Double.pi / 2 + Double((d.seed % 7) - 3) * 0.04)
        blood(x - 4, 236, 8, d.seed + 11, 8, 0)
    }
}
func returnToNormal() {
    afterlife = 0; haunted = true; saveBool("haunted", true); hauntedMusicSync()
    stopMorse()
    removeAllActions(bird); removeAction(scene, "playTap")
    pipeList = []; resetEnding(); score = 0
    isGameOver = false; isShowingGameOver = false; hasHitGround = false; isWaitingToStart = false; hitButton = false
    tapTap.added = false; getReady.added = false; scoreLabel.added = false; resultNode.added = false; gameOverNode.added = false
    bird.x = width / 2; bird.y = height / 2 + 75; bird.rot = 0; bird.vy = 0; bird.dynamic = false; bird.collideLandOnly = false
    bird.speed = 1; moving.speed = 1; pipesNode.scale = 0; bird.added = true
    flappyBird.added = true; githubButton.added = true; settingsButton.added = true; playButton.added = true
    settingsButton.x = width / 2 + 45; settingsButton.y = height / 2 - 25
    for n in [githubButton, settingsButton, playButton] { n.scale = 1.2 }
    flappyBird.scale = 1.5
    updateSky(); updateBirdTextures(); startIdleAnimation()
    loadingAlpha = 1; loadingHold = 1.6
}

// ---------- The ending turns the world creepy (from 990 through the -1 run and the message) ----------
var creepyLvl = 0.0, creepyFlick = 0.0, creepyNextFlick = 7.0
func creepyTarget() -> Double {
    if afterlife >= 1 { return 1 }
    if ending.swarmed || ending.fill != nil { return 1 }
    if ending.on && score >= 990 { return min(1, Double(score - 989) / 10) }
    return 0
}
func updateCreepy(_ dt: Double) {
    let tg = creepyTarget()
    creepyLvl += (tg - creepyLvl) * min(1, dt * (tg > creepyLvl ? 0.8 : 2.5))
    if creepyLvl < 0.002 { creepyLvl = 0 }
    if creepyLvl > 0.3 {
        creepyNextFlick -= dt
        if creepyNextFlick <= 0 { creepyFlick = 0.22; creepyNextFlick = 5 + mrand() * 9 }
    }
    if creepyFlick > 0 { creepyFlick -= dt }
}
func visRect() -> (l: Double, r: Double, b: Double, t: Double) { (-camX / camS, (boxW - camX) / camS, SH - (boxH - camY) / camS, SH + camY / camS) }
func drawCreepySky(_ skyX: Double, _ skyW: Double, _ skyH: Double) {
    if creepyLvl <= 0 { return }
    guard let bs = img("blood_sky") else { return }
    ctx.globalAlpha = creepyLvl
    for i in 0..<(2 + Int(floor(width / skyW))) { spr(bs, skyX + Double(i) * (skyW - 1), skyH / 3.5 + 112 * 2, 1.5, 1.5, 0) }
    let V = visRect(), mx = V.r - 92, my = min(V.t - 110, 690), R = 34.0, pulse = 0.85 + 0.15 * sin(sceneTime * 1.3)
    let glow = ctx.createRadialGradient(mx, my, R * 0.6, mx, my, R * 3.2)
    glow.addColorStop(0, RGBA(r: 1, g: 40 / 255, b: 30 / 255, a: 0.45 * creepyLvl * pulse)); glow.addColorStop(1, RGBA(r: 1, g: 40 / 255, b: 30 / 255, a: 0))
    ctx.globalAlpha = 1; ctx.fillStyle = .gradient(glow); ctx.fillRect(mx - R * 3.3, my - R * 3.3, R * 6.6, R * 6.6)
    ctx.globalAlpha = creepyLvl
    var y = -R
    while y < R {
        var x = -R
        while x < R {
            let d = hypot(x + 1.5, y + 1.5)
            if d <= R {
                let spot = (hypot(x - 10, y - 8) < 9) || (hypot(x + 12, y + 4) < 6) || (hypot(x + 2, y - 18) < 5)
                ctx.fill(d > R - 3 ? "#8c0c10" : spot ? "#a8141a" : (x + y < -10 ? "#e8343a" : "#cc2026"))
                ctx.fillRect(mx + x, my + y, 3, 3)
            }
            x += 3
        }
        y += 3
    }
    ctx.globalAlpha = 1
}
func drawCreepyFog() {
    if creepyLvl <= 0 { return }
    let V = visRect()
    let gr = ctx.createLinearGradient(0, 224, 0, 400)
    gr.addColorStop(0, RGBA(r: 70 / 255, g: 0, b: 12 / 255, a: 0.55 * creepyLvl)); gr.addColorStop(1, RGBA(r: 70 / 255, g: 0, b: 12 / 255, a: 0))
    ctx.fillStyle = .gradient(gr); ctx.fillRect(V.l - 10, 224, V.r - V.l + 20, 176)
    for i in 0..<9 {
        let di = Double(i)
        let w = 140 + Double((i * 37) % 90), x = V.l + (di * 173 + sceneTime * (12 + di * 3)).truncatingRemainder(dividingBy: V.r - V.l + 300) - 150, y = 236 + Double((i * 29) % 70)
        let g2 = ctx.createRadialGradient(x, y, 0, x, y, w / 2)
        g2.addColorStop(0, RGBA(r: 90 / 255, g: 10 / 255, b: 20 / 255, a: 0.22 * creepyLvl)); g2.addColorStop(1, RGBA(r: 90 / 255, g: 10 / 255, b: 20 / 255, a: 0))
        ctx.fillStyle = .gradient(g2); ctx.fillRect(x - w / 2, y - w / 2, w, w)
    }
}
func jsMod(_ a: Double, _ b: Double) -> Double { a.truncatingRemainder(dividingBy: b) }
func drawCreepyOverlay() {
    if creepyLvl <= 0 { return }
    let V = visRect(), W = V.r - V.l, H = V.t - V.b
    ctx.fillStyle = .color(RGBA(r: 30 / 255, g: 0, b: 5 / 255, a: 0.45 * creepyLvl)); ctx.fillRect(V.l - 10, V.b - 10, W + 20, 224 - V.b + 10)
    for i in 0..<46 {
        let di = Double(i)
        let sp = 18 + Double((i * 7) % 23)
        let x = V.l + jsMod(jsMod(di * 97.3 + sceneTime * (6 + Double(i % 5) * 3) + sin(sceneTime * 0.7 + di) * 12, W) + W, W)
        let y = V.t - jsMod(di * 151.7 + sceneTime * sp, H + 20)
        ctx.fillStyle = i % 4 == 0 ? .color(RGBA(r: 200 / 255, g: 40 / 255, b: 40 / 255, a: 0.55 * creepyLvl)) : .color(RGBA(r: 170 / 255, g: 160 / 255, b: 160 / 255, a: 0.5 * creepyLvl))
        ctx.fillRect(x.jr, y.jr, i % 3 == 0 ? 3 : 2, 2)
    }
    let cx = (V.l + V.r) / 2, cy = (V.b + V.t) / 2, rr = hypot(W, H) / 2
    let vg = ctx.createRadialGradient(cx, cy, rr * 0.35, cx, cy, rr)
    vg.addColorStop(0, RGBA(r: 0, g: 0, b: 0, a: 0)); vg.addColorStop(1, RGBA(r: 0, g: 0, b: 0, a: 0.72 * creepyLvl))
    ctx.fillStyle = .gradient(vg); ctx.fillRect(V.l - 10, V.b - 10, W + 20, H + 20)
    if creepyFlick > 0 { ctx.fillStyle = .color(RGBA(r: 150 / 255, g: 0, b: 12 / 255, a: 0.22 * creepyLvl * (creepyFlick / 0.22))); ctx.fillRect(V.l - 10, V.b - 10, W + 20, H + 20) }
}
