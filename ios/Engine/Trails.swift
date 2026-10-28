import Foundation

// ===================== v129: Trails & effects (100) =====================
// P particles, R a ribbon that follows the bird, O shapes orbiting it, A a glow, H a halo. Definitions come from the website.
var trailScroll = 0.0
var trailPick = "none"
let TSHAPE: [String: [String]] = (Assets.data["TSHAPE"] as? [String: [String]]) ?? [:]
let TPAL: [String: String] = (Assets.data["TPAL"] as? [String: String]) ?? [:]
struct TLayer {
    var type = "p", shape = "sq", cols: [String] = [], c2: [String]? = nil
    var rate = 26.0, s = (2.0, 2.0), life = (0.5, 0.9), vx = (-30.0, 0.0), vy = (-15.0, 15.0), g = 0.0, drag = 0.0, spin = 0.0, fade = 1.0, shrink = 0.0, wob = 0.0
    var dx = (-14.0, -14.0), dy = (-5.0, 5.0), flap = 0, fsp = (60.0, 150.0), score = 0, layer = 0, glow = 0.0, twinkle = 0.0, around = 0.0, inward = 0.0, grow = 0.0
    var bands: [String] = [], w = 2.0, len = 26, wave = 0.0, wsp = 8.0, dash = 0.0
    var n = 3, r = 26.0, ry = 0.55, sp = 3.0, so = 2.0, bob = 0.0
    var col = "", pulse = 0.12, ring = 0.0, hw = 18.0, hh = 5.0, hy = 20.0
}
struct TrailDef { let id: String, name: String, cat: String, layers: [TLayer] }
private func rng(_ v: Any?, _ d: (Double, Double)) -> (Double, Double) {
    if let a = v as? [Any], a.count >= 2 { return (num(a[0]) ?? d.0, num(a[1]) ?? d.1) }
    if let n = num(v) { return (n, n) }
    return d
}
let TRAILS: [TrailDef] = {
    guard let list = Assets.data["TRAILS"] as? [[String: Any]] else { return [] }
    return list.map { t in
        let layers = (t["layers"] as? [[String: Any]] ?? []).map { o -> TLayer in
            var l = TLayer()
            l.type = o["type"] as? String ?? "p"
            let D = { (k: String, d: Double) -> Double in num(o[k]) ?? d }
            switch l.type {
            case "p":
                l.shape = o["shape"] as? String ?? "sq"; l.cols = o["cols"] as? [String] ?? ["#fff"]; l.c2 = o["c2"] as? [String]
                l.rate = D("rate", 26); l.s = rng(o["s"], (2, 2)); l.life = rng(o["life"], (0.5, 0.9)); l.vx = rng(o["vx"], (-30, 0)); l.vy = rng(o["vy"], (-15, 15))
                l.g = D("g", 0); l.drag = D("drag", 0); l.spin = D("spin", 0); l.fade = D("fade", 1); l.shrink = D("shrink", 0); l.wob = D("wob", 0)
                l.dx = rng(o["dx"], (-14, -14)); l.dy = rng(o["dy"], (-5, 5)); l.flap = Int(D("flap", 0)); l.fsp = rng(o["fsp"], (60, 150)); l.score = Int(D("score", 0))
                l.layer = Int(D("layer", 0)); l.glow = D("glow", 0); l.twinkle = D("twinkle", 0); l.around = D("around", 0); l.inward = D("inward", 0); l.grow = D("grow", 0)
            case "r":
                l.bands = o["bands"] as? [String] ?? []; l.w = D("w", 2); l.len = Int(D("len", 26)); l.wave = D("wave", 0); l.wsp = D("wsp", 8); l.fade = D("fade", 1); l.glow = D("glow", 0); l.dash = D("dash", 0)
            case "o":
                l.shape = o["shape"] as? String ?? "sq"; l.cols = o["cols"] as? [String] ?? ["#fff"]; l.n = Int(D("n", 3)); l.r = D("r", 26); l.ry = D("ry", 0.55); l.sp = D("sp", 3); l.so = D("s", 2); l.bob = D("bob", 0)
            case "a":
                l.col = o["col"] as? String ?? "#fff"; l.r = D("r", 30); l.pulse = D("pulse", 0.12); l.ring = D("ring", 0)
            default:
                l.col = o["col"] as? String ?? "#fff"; l.hw = D("w", 18); l.hh = D("h", 5); l.hy = D("y", 20)
            }
            return l
        }
        return TrailDef(id: t["id"] as? String ?? "", name: t["name"] as? String ?? "", cat: t["cat"] as? String ?? "", layers: layers)
    }
}()
private var tCache: [String: Img] = [:]
func tImg(_ shape: String, _ c1: String, _ c2: String? = nil) -> Img {
    let key = shape + "|" + c1 + "|" + (c2 ?? "")
    if let im = tCache[key] { return im }
    let rows = TSHAPE[shape] ?? TSHAPE["sq"] ?? ["#"]
    let cv = CGCanvas(rows.map { $0.count }.max() ?? 1, rows.count)
    for (y, r) in rows.enumerated() { for (x, ch) in r.enumerated() where ch != "." {
        cv.fill(ch == "#" ? c1 : ch == "o" ? (c2 ?? c1) : (TPAL[String(ch)] ?? c1)); cv.fillRect(Double(x), Double(y), 1, 1)
    } }
    let im = cv.image(); tCache[key] = im; return im
}
func trr(_ v: (Double, Double)) -> Double { v.0 + mrand() * (v.1 - v.0) }
func tpick<T>(_ a: [T]) -> T { a[Int(floor(mrand() * Double(a.count)))] }
final class TPart { var l: TLayer, img: Img, x, y, vx, vy, life, max, s, r, vr, ph: Double
    init(_ l: TLayer, _ img: Img, _ x: Double, _ y: Double, _ vx: Double, _ vy: Double, _ life: Double, _ s: Double, _ vr: Double) {
        self.l = l; self.img = img; self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.life = life; self.max = life; self.s = s; self.r = 0; self.vr = vr; self.ph = mrand() * 6.3 } }
final class TrailState { var parts: [TPart] = [], ribs: [(x: Double, y: Double, t: Double)] = [], t = 0.0, acc: [Int: Double] = [:], ribT = 0.0 }
func trailDef(_ id: String) -> TrailDef? { TRAILS.first { $0.id == id } }
func tSpawn(_ st: TrailState, _ l: TLayer, _ bx: Double, _ by: Double, burst: Bool = false) {
    if st.parts.count > 320 { return }
    let c = tpick(l.cols), c2 = l.c2 != nil ? tpick(l.c2!) : nil
    let life = trr(l.life)
    let p = TPart(l, tImg(l.shape, c, c2), bx + trr(l.dx), by + trr(l.dy), trr(l.vx), trr(l.vy), life, trr(l.s), l.spin != 0 ? (mrand() - 0.5) * 2 * l.spin : 0)
    if burst { let a = mrand() * Double.pi * 2, v = trr(l.fsp); p.x = bx + trr((-4, 4)); p.y = by + trr((-4, 4)); p.vx = cos(a) * v - 30; p.vy = sin(a) * v }
    else if l.around != 0 { let a = mrand() * Double.pi * 2; p.x = bx + cos(a) * l.around; p.y = by + sin(a) * l.around * 0.8; if l.inward != 0 { p.vx = -cos(a) * l.around / life; p.vy = -sin(a) * l.around * 0.8 / life } }
    st.parts.append(p)
}
func tStep(_ st: TrailState, _ def: TrailDef?, _ dt: Double, _ bx: Double, _ by: Double, _ scroll: Double, _ spawning: Bool) {
    st.t += dt
    if let def = def, spawning {
        for (i, l) in def.layers.enumerated() where l.type == "p" && l.rate > 0 {
            st.acc[i, default: 0] += dt * l.rate
            while st.acc[i]! >= 1 { st.acc[i]! -= 1; tSpawn(st, l, bx, by) }
        }
    }
    for p in st.parts {
        let l = p.l; p.life -= dt
        if l.drag != 0 { p.vx *= 1 - l.drag * dt; p.vy *= 1 - l.drag * dt }
        p.vy += l.g * dt
        p.x += p.vx * dt - scroll + (l.wob != 0 ? sin(st.t * 5 + p.ph) * l.wob * dt : 0)
        p.y += p.vy * dt
        p.r += p.vr * dt
    }
    st.parts = st.parts.filter { $0.life > 0 }
    if let def = def, def.layers.contains(where: { $0.type == "r" }) {
        for i in st.ribs.indices { st.ribs[i].x -= scroll }
        st.ribT += dt
        if spawning { while st.ribT >= 1.0 / 60 { st.ribT -= 1.0 / 60; st.ribs.append((bx - 8, by, st.t)) } }
        else { st.ribT = 0; if !st.ribs.isEmpty { st.ribs.removeFirst() } }
        let maxLen = def.layers.filter { $0.type == "r" }.map { $0.len }.max() ?? 0
        while st.ribs.count > maxLen { st.ribs.removeFirst() }
    } else { st.ribs = [] }
}
func tBurst(_ st: TrailState, _ def: TrailDef?, _ kind: String, _ bx: Double, _ by: Double) {
    guard let def = def else { return }
    for l in def.layers where l.type == "p" { let n = kind == "flap" ? l.flap : l.score; for _ in 0..<max(0, n) { tSpawn(st, l, bx, by, burst: true) } }
}
func tClear(_ c: String) -> RGBA { var r = css(c); r.a = 0; return r }
func tDrawImg(_ g: Canvas2D, _ im: Img, _ x: Double, _ y: Double, _ s: Double, _ r: Double) {
    g.save(); g.translate(x, y); if r != 0 { g.rotate(r) }; g.scale(s, -s); g.drawImage(im, -Double(im.width) / 2, -Double(im.height) / 2); g.restore()
}
func tDraw(_ g: Canvas2D, _ st: TrailState, _ def: TrailDef?, _ layer: Int, _ bx: Double, _ by: Double) {
    guard let def = def else { return }
    g.imageSmoothingEnabled = false
    for l in def.layers {
        if l.type == "a" && layer == 0 {
            let r = l.r * (1 + sin(st.t * 5) * l.pulse)
            if l.ring != 0 {
                let grd = g.createRadialGradient(bx, by, r * 0.55, bx, by, r)
                grd.addColorStop(0, tClear(l.col)); grd.addColorStop(0.75, l.col); grd.addColorStop(1, tClear(l.col))
                g.fillStyle = .gradient(grd); g.fillRect(bx - r, by - r, r * 2, r * 2)
            } else {
                let grd = g.createRadialGradient(bx, by, 0, bx, by, r)
                grd.addColorStop(0, l.col); grd.addColorStop(1, tClear(l.col))
                g.fillStyle = .gradient(grd); g.fillRect(bx - r, by - r, r * 2, r * 2)
            }
        }
        if l.type == "h" && layer == 1 {
            let y0 = by + l.hy + sin(st.t * 3) * 1.5; g.fill(l.col); let hx = bx + 2
            var i = -l.hw / 2
            while i < l.hw / 2 { let e = jsRound((max(0, 1 - pow(2 * i / l.hw, 2))).squareRoot() * l.hh / 2 / 2) * 2; g.fillRect(hx + i, y0 + e, 2, 2); g.fillRect(hx + i, y0 - e, 2, 2); i += 2 }
        }
        if l.type == "o" {
            for i in 0..<l.n {
                let a = st.t * l.sp + Double(i) * Double.pi * 2 / Double(l.n), front = sin(a) < 0
                if (front ? 1 : 0) != layer { continue }
                let im = tImg(l.shape, l.cols[i % l.cols.count])
                tDrawImg(g, im, jsRound(bx + cos(a) * l.r), jsRound(by + sin(a) * l.r * l.ry + (l.bob != 0 ? sin(st.t * 7 + Double(i)) * l.bob : 0)), l.so, 0)
            }
        }
        if l.type == "r" && layer == 0 && st.ribs.count > 1 {
            let pts = Array(st.ribs.suffix(l.len)), n = pts.count
            for i in 0..<(n - 1) {
                let q = pts[i], q2 = pts[i + 1], f = Double(i + 1) / Double(n)
                if l.dash != 0 && Int(floor((q.t * 60) / 3)) % 2 != 0 { continue }
                g.globalAlpha = l.fade != 0 ? min(1, f * 1.4) : 1
                let wv = l.wave != 0 ? sin(q.t * l.wsp - Double(i) * 0.35) * l.wave * (1 - f * 0.5) : 0
                let wv2 = l.wave != 0 ? sin(q2.t * l.wsp - Double(i + 1) * 0.35) * l.wave * (1 - Double(i + 2) / Double(n) * 0.5) : 0
                let x0 = floor(q.x / 2) * 2, w0 = max(2, ceil((q2.x - q.x) / 2) * 2 + 1)
                for (j, c) in l.bands.enumerated() {
                    let off = (Double(l.bands.count) / 2 - Double(j) - 1) * l.w
                    let ya = jsRound((q.y + wv + off) / 2) * 2, yb = jsRound((q2.y + wv2 + off) / 2) * 2
                    let lo = min(ya, yb), hi = max(ya, yb)
                    g.fill(c); g.fillRect(x0, lo, w0, hi - lo + l.w)
                }
            }
            g.globalAlpha = 1
        }
    }
    for p in st.parts where p.l.layer == layer {
        let l = p.l, k = p.life / p.max
        var a = l.fade != 0 ? min(1, k * 2) : 1
        if l.twinkle != 0 { a *= 0.55 + 0.45 * sin(st.t * 18 + p.ph) }
        var s = p.s
        if l.shrink != 0 { s *= 0.35 + 0.65 * k }
        if l.grow != 0 { s *= 1 + (1 - k) * 0.8 }
        if a <= 0.02 { continue }
        g.globalAlpha = a
        if l.glow != 0 { g.globalAlpha = a * 0.3; tDrawImg(g, p.img, jsRound(p.x), jsRound(p.y), s * 3.4, p.r); g.globalAlpha = a }
        tDrawImg(g, p.img, jsRound(p.x), jsRound(p.y), s * 2, p.r)
    }
    g.globalAlpha = 1
}
let TRS = TrailState()
var trailDefNow: TrailDef? = nil
func trailLive() -> Bool { trailDefNow != nil && bird.added && weatherOn() && !RP.playing }
func updateTrailGame(_ dt: Double) {
    if trailDefNow == nil { TRS.parts = []; TRS.ribs = []; return }
    let spawning = trailLive() && moving.speed > 0 && !isGameOver && !isShowingGameOver
    tStep(TRS, trailDefNow, dt, bird.x, bird.y, trailScroll, spawning)
}
func drawTrail(_ layer: Int) {
    if trailDefNow == nil || !trailLive() { return }
    ctx.save()
    tDraw(ctx, TRS, trailDefNow, layer, bird.x, bird.y)
    ctx.restore()
}
func trailFlap() {
    if trailDefNow != nil && trailLive() { tBurst(TRS, trailDefNow, "flap", bird.x, bird.y) }
    if accCounting() && bird.dynamic { ACC_ST.f += 1 }
}
func trailScore() { hapScoreNext = true; if trailDefNow != nil && trailLive() { tBurst(TRS, trailDefNow, "score", bird.x, bird.y) } }
func setTrail(_ id: String) { trailPick = id; saveStr("trail", id); trailDefNow = trailDef(id); TRS.parts = []; TRS.ribs = [] }
/// a little scene for the Trails page: the bird bobbing with its trail
func drawTrailIcon(_ cv: CGCanvas, _ id: String, _ st: TrailState, _ dt: Double) {
    let def = trailDef(id)
    cv.setTransform(1, 0, 0, 1, 0, 0); cv.clearRect(0, 0, Double(cv.w), Double(cv.h))
    cv.fill("#4ec0ca"); cv.fillRect(0, 0, Double(cv.w), Double(cv.h))
    let k = Double(cv.h) / 100
    cv.setTransform(k, 0, 0, -k, 0, Double(cv.h)); cv.imageSmoothingEnabled = false
    let bx = Double(cv.w) / k * 0.64, by = 50 + sin(st.t * 3.2) * 8
    if let d = def {
        tStep(st, d, dt, bx, by, 170 * dt, true)
        if mrand() < dt * 0.9 { tBurst(st, d, "flap", bx, by) }
        tDraw(cv, st, d, 0, bx, by)
    } else { st.t += dt }
    if let im = birdFrame() { cv.save(); cv.translate(bx, by); cv.rotate(sin(st.t * 3.2 + 1.6) * 0.25); cv.scale(1.5, -1.5); cv.drawImage(im, -Double(im.width) / 2, -Double(im.height) / 2); cv.restore() }
    if def != nil { tDraw(cv, st, def, 1, bx, by) }
}
