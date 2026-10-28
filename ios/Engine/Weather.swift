import Foundation

// ===================== v95 add-ons: Windy mode, Darkness, weather + seasons =====================
var windAy = 0.0, windTarget = 0.0, windTimer = 0.0
let WIND_EASE = 1.3
func updateWind(_ dt: Double) {
    let on = modeOn("windy") && bird.dynamic && !isGameOver && moving.speed > 0
    if on {
        windTimer -= dt
        if windTimer <= 0 {
            windTimer = 1.8 + mrand() * 2
            windTarget = mrand() < 0.2 ? 0 : (mrand() < 0.5 ? -1 : 1) * (260 + mrand() * 300)
        }
    } else { windTarget = 0; windTimer = 0.8 }
    windAy += (windTarget - windAy) * min(1, dt * WIND_EASE)
    if !on && abs(windAy) < 1 { windAy = 0 }
}
func inRun() -> Bool { isWaitingToStart || bird.dynamic || isGameOver || isShowingGameOver }
func worldFlipped() -> Bool { modeOn("flipped") && inRun() }

func drawDarkness(_ flip: Bool) {
    if !(modeOn("dark") && inRun()) { return }
    let bx = bird.x, by = flip ? SH - bird.y : bird.y
    let r = 125 + 4 * sin(WX.t * 9) + 3 * sin(WX.t * 23)
    let v = viewBox()
    let g = ctx.createRadialGradient(bx, by, 0, bx, by, r)
    g.addColorStop(0, "rgba(4,4,12,0)"); g.addColorStop(0.45, "rgba(4,4,12,0.06)"); g.addColorStop(0.8, "rgba(4,4,12,0.62)"); g.addColorStop(1, "rgba(4,4,12,0.94)")
    ctx.fillStyle = .gradient(g); ctx.fillRect(v.L - 10, -10, v.R - v.L + 20, SH + 20)
    let w = ctx.createRadialGradient(bx, by, 0, bx, by, r * 0.7)
    w.addColorStop(0, "rgba(255,190,90,0.13)"); w.addColorStop(1, "rgba(255,190,90,0)")
    ctx.fillStyle = .gradient(w); ctx.fillRect(bx - r, by - r, r * 2, r * 2)
}

// ---------- Weather, seasons and time of day ----------
let WEATHERS: [(String, String, String)] = [("auto", "AUTO", "Auto"), ("clear", "CLEAR", "Clear"), ("rain", "RAIN", "Rain"), ("storm", "STORM", "Thunderstorm"), ("snow", "SNOW", "Snow"), ("fog", "FOG", "Fog"), ("windy", "WINDY", "Windy")]
let SEASONS: [(String, String, String)] = [("auto", "AUTO", "Auto (by date)"), ("classic", "CLASSIC", "Classic"), ("spring", "SPRING", "Spring"), ("summer", "SUMMER", "Summer"), ("fall", "FALL", "Fall"), ("winter", "WINTER", "Winter"),
                                           ("halloween", "SPOOKY", "Halloween"), ("christmas", "XMAS", "Christmas"), ("newyear", "NYE", "New Year"), ("valentine", "LOVE", "Valentine")]
var weatherPick = "auto", seasonPick = "auto"
let WX_ODDS: [String: [(String, Double)]] = [
    "classic": [("clear", 0.55), ("rain", 0.15), ("storm", 0.07), ("fog", 0.1), ("windy", 0.13)],
    "spring": [("clear", 0.5), ("rain", 0.25), ("storm", 0.07), ("fog", 0.08), ("windy", 0.1)],
    "summer": [("clear", 0.65), ("storm", 0.15), ("rain", 0.08), ("windy", 0.12)],
    "fall": [("clear", 0.4), ("rain", 0.2), ("windy", 0.25), ("fog", 0.15)],
    "winter": [("clear", 0.35), ("snow", 0.45), ("fog", 0.12), ("windy", 0.08)],
    "halloween": [("clear", 0.3), ("fog", 0.35), ("storm", 0.2), ("windy", 0.15)],
    "christmas": [("snow", 0.7), ("clear", 0.3)],
    "newyear": [("clear", 0.6), ("snow", 0.4)],
    "valentine": [("clear", 0.7), ("snow", 0.15), ("rain", 0.15)],
]
final class WPart { var k = "", x = 0.0, y = 0.0, vx = 0.0, vy = 0.0, ph = 0.0, par = 0.3, wf = 1.0, s = 2.0, c = "#fff", spin = 0.0, len = 0.0 }
struct Bolt { var pts: [(Double, Double)], br: [(Double, Double)], t: Double }
struct Bat { var x, y, vx, ph, t: Double }
struct Firework { var x, y, t: Double, c: String, c2: String, n: Int, sp: Double }
final class WXState {
    var season = "classic", weather = "clear", tod = "day", parts: [WPart] = [], splash: [(x: Double, t: Double)] = [], t = 0.0, seeded = false
    var bolt: Bolt? = nil, flash = 0.0, nextBolt = 3.0, bats: [Bat] = [], nextBat = 2.0, shoot: (x: Double, y: Double, t: Double)? = nil, nextShoot = 5.0
    var fw: [Firework] = [], nextFw = 1.0, cloudX = 0.0, fogX = 0.0, tint: Img? = nil, tintKey = ""
}
let WX = WXState()
func seasonByDate(_ d: Date) -> String {
    let c = Calendar.current, m = c.component(.month, from: d), day = c.component(.day, from: d)
    if (m == 12 && day == 31) || (m == 1 && day == 1) { return "newyear" }
    if m == 2 && day >= 7 && day <= 14 { return "valentine" }
    if m == 10 && day >= 15 { return "halloween" }
    if m == 12 { return "christmas" }
    if m <= 2 { return "winter" }
    if m <= 5 { return "spring" }
    if m <= 8 { return "summer" }
    return "fall"
}
func clockTod() -> String {
    let c = Calendar.current, d = Date(), h = Double(c.component(.hour, from: d)) + Double(c.component(.minute, from: d)) / 60
    if h >= 5.5 && h < 7.5 { return "dawn" }
    if h >= 7.5 && h < 18 { return "day" }
    if h >= 18 && h < 20 { return "dusk" }
    return "night"
}
func rollWeather() {
    WX.season = seasonPick == "auto" ? seasonByDate(Date()) : seasonPick
    if weatherPick != "auto" { WX.weather = weatherPick }
    else {
        let odds = WX_ODDS[WX.season] ?? WX_ODDS["classic"]!
        var r = mrand(), w = "clear"
        for (k, p) in odds { if r < p { w = k; break }; r -= p }
        WX.weather = w
    }
    if WX.season == "halloween" && !adaptiveBackground { skyIsNight = true; WX.tod = "night" }
    WX.parts = []; WX.splash = []; WX.seeded = false; WX.bolt = nil; WX.flash = 0; WX.bats = []; WX.fw = []; WX.shoot = nil
}
func weatherOn() -> Bool { !ending.on && afterlife == 0 && !haunted && creepyLvl <= 0.001 && score > -1 }
func viewBox() -> (L: Double, R: Double) { (-camX / camS, (boxW - camX) / camS) }
func rnd(_ a: Double, _ b: Double) -> Double { a + mrand() * (b - a) }
func wantParts() -> [(String, Int)] {
    let w = WX.weather, s = WX.season
    var want: [(String, Int)] = []
    func set(_ k: String, _ n: Int) { if let i = want.firstIndex(where: { $0.0 == k }) { want[i].1 = n } else { want.append((k, n)) } }
    if w == "rain" { set("rain", 110) }
    if w == "storm" { set("rain", 190) }
    if w == "snow" { set("snow", 120) } else if (s == "christmas" || s == "winter") && w != "rain" && w != "storm" { set("snow", 35) }
    if s == "fall" { set("leaf", w == "windy" ? 34 : 18) }
    if s == "halloween" { set("leaf", 10) }
    if s == "spring" { set("petal", w == "windy" ? 34 : 20) }
    if s == "summer" && skyIsNight && w != "rain" && w != "storm" { set("fly", 16) }
    if s == "valentine" { set("heart", 12) }
    if s == "newyear" { set("confetti", 36) }
    if w == "windy" { set("streak", 18) }
    if modeOn("windy") && bird.dynamic { set("streak", max(want.first { $0.0 == "streak" }?.1 ?? 0, 16)) }
    return want
}
let LEAF_COL = ["#e8742a", "#c8401e", "#f0b030", "#a85a20"]
let PETAL_COL = ["#ffc2d8", "#ffd6e6", "#ff9ec4"]
let HEART_COL = ["#ff5c8a", "#ff8fb0", "#e8323c"]
let CONF_COL = ["#ff3b3b", "#3bff6b", "#ffd23b", "#3bb0ff", "#ff6bf0", "#ffffff"]
func newPart(_ k: String, _ v: (L: Double, R: Double), _ anywhere: Bool) -> WPart {
    let p = WPart(); p.k = k; p.x = rnd(v.L - 60, v.R + 120); p.y = anywhere ? rnd(230, SH) : SH + rnd(10, 90); p.ph = mrand() * 6.3
    if k == "rain" { let storm = WX.weather == "storm"; p.vx = storm ? -220 : -130; p.vy = -rnd(900, 1150); p.par = 0.25; p.y = anywhere ? rnd(0, SH) : SH + rnd(10, 160) }
    else if k == "snow" { p.vx = -20; p.vy = -rnd(45, 110); p.s = [2.0, 2, 3, 3, 4][Int(floor(mrand() * 5))]; p.wf = 0.8 }
    else if k == "leaf" { p.vx = -30; p.vy = -rnd(40, 85); p.c = LEAF_COL[Int(floor(mrand() * 4))]; p.spin = rnd(2, 4.5); p.par = 0.35; p.wf = 1.2 }
    else if k == "petal" { p.vx = -25; p.vy = -rnd(30, 60); p.c = PETAL_COL[Int(floor(mrand() * 3))]; p.spin = rnd(2, 4); p.wf = 1.2 }
    else if k == "fly" { p.x = rnd(v.L, v.R); p.y = rnd(260, 700); p.vx = rnd(-20, 20); p.vy = rnd(-15, 15); p.par = 0.05; p.wf = 0 }
    else if k == "heart" { p.y = anywhere ? rnd(230, SH) : rnd(200, 240); p.vy = rnd(25, 50); p.c = HEART_COL[Int(floor(mrand() * 3))]; p.par = 0.2; p.wf = 0.5 }
    else if k == "confetti" { p.vx = rnd(-40, 40); p.vy = -rnd(60, 120); p.c = CONF_COL[Int(floor(mrand() * Double(CONF_COL.count)))]; p.spin = rnd(4, 9); p.par = 0.25 }
    else if k == "streak" { p.x = anywhere ? rnd(v.L, v.R + 200) : v.R + rnd(10, 240); p.y = rnd(240, SH - 20); p.vx = -rnd(700, 1000); p.len = rnd(40, 90); p.par = 0; p.wf = 0 }
    return p
}
func updateWeather(_ dt: Double) {
    updateWeatherBase(dt)
    updateSeasons(dt)
}
private func updateWeatherBase(_ dt: Double) {
    WX.t += dt
    if WX.flash > 0 { WX.flash = max(0, WX.flash - dt * 3) }
    if !weatherOn() { if !WX.parts.isEmpty { WX.parts = [] }; WX.bats = []; WX.fw = []; WX.bolt = nil; return }
    let v = viewBox()
    let scroll = moving.speed > 0 && !ending.frozen ? 200 * speedMul() : 0
    let windX = WX.weather == "windy" ? -260.0 : 0
    let flip = worldFlipped()
    let want = wantParts()
    let wantK = Dictionary(uniqueKeysWithValues: want)
    WX.parts = WX.parts.filter { wantK[$0.k] != nil }
    var have: [String: Int] = [:]
    for p in WX.parts { have[p.k, default: 0] += 1 }
    for (k, n) in want { var i = have[k] ?? 0; while i < n { WX.parts.append(newPart(k, v, !WX.seeded)); i += 1 } }
    WX.seeded = true
    for p in WX.parts {
        var sway = 0.0
        if p.k == "snow" { sway = sin(WX.t * 1.3 + p.ph) * 18 }
        else if p.k == "leaf" || p.k == "petal" { sway = sin(WX.t * 1.7 + p.ph) * 30 }
        else if p.k == "heart" { sway = sin(WX.t * 2 + p.ph) * 14 }
        else if p.k == "fly" { p.vx += rnd(-40, 40) * dt; p.vy += rnd(-40, 40) * dt; p.vx = max(-30, min(30, p.vx)); p.vy = max(-25, min(25, p.vy)) }
        if p.k == "streak" { p.vy = modeOn("windy") ? windAy * 0.18 : sin(WX.t + p.ph) * 20 }
        p.x += (p.vx + sway + windX * p.wf - scroll * p.par) * dt
        p.y += p.vy * dt
        var gone = p.y > SH + 200 || p.x < v.L - 140 || p.x > v.R + 400
        if p.k == "fly" { gone = p.y < 240 || p.y > SH - 40 || p.x < v.L - 20 || p.x > v.R + 20 }
        else if p.k == "heart" { gone = gone || p.y > SH + 20 }
        else if p.k == "rain" && p.y < 226 { gone = true; if !flip && WX.splash.count < 60 { WX.splash.append((p.x, 0)) } }
        else if p.y < 214 { gone = true }
        if gone { let q = newPart(p.k, v, p.k == "fly"); p.x = q.x; p.y = q.y; p.vx = q.vx; p.vy = q.vy; p.ph = q.ph; p.par = q.par; p.wf = q.wf; p.s = q.s; p.c = q.c; p.spin = q.spin; p.len = q.len }
    }
    for i in WX.splash.indices { WX.splash[i].t += dt; WX.splash[i].x -= scroll * dt }
    WX.splash = WX.splash.filter { $0.t < 0.22 }
    WX.cloudX -= (14 + scroll * 0.08) * dt
    WX.fogX -= (22 + scroll * 0.15) * dt
    if WX.weather == "storm" {
        WX.nextBolt -= dt
        if WX.nextBolt <= 0 {
            WX.nextBolt = 3.5 + mrand() * 5
            var pts: [(Double, Double)] = []; var x = rnd(v.L + 40, v.R - 40), y = SH + 10; let end = rnd(360, 520)
            while y > end { pts.append((x, y)); y -= rnd(28, 50); x += rnd(-26, 26) }
            pts.append((x, end))
            let bi = 1 + Int(floor(mrand() * Double(max(1, pts.count - 2))))
            var br = [pts[bi]]
            var bx = pts[bi].0, by = pts[bi].1
            for _ in 0..<3 { bx += rnd(10, 30) * (mrand() < 0.5 ? -1 : 1); by -= rnd(20, 35); br.append((bx, by)) }
            WX.bolt = Bolt(pts: pts, br: br, t: 0)
        }
    }
    if WX.bolt != nil {
        WX.bolt!.t += dt; let bt = WX.bolt!.t
        WX.flash = bt < 0.06 ? 1 : bt < 0.1 ? 0.25 : bt < 0.16 ? 0.8 : max(WX.flash, 0)
        if bt > 0.32 { WX.bolt = nil }
    }
    if WX.season == "halloween" {
        WX.nextBat -= dt
        if WX.nextBat <= 0 {
            WX.nextBat = 3 + mrand() * 4
            let n = 1 + Int(floor(mrand() * 3)), y0 = rnd(450, 690)
            for i in 0..<n { WX.bats.append(Bat(x: v.R + 20 + Double(i) * rnd(18, 40), y: y0 + rnd(-30, 30), vx: -rnd(90, 150), ph: mrand() * 6, t: mrand())) }
        }
        for i in WX.bats.indices { WX.bats[i].t += dt; WX.bats[i].x += (WX.bats[i].vx - scroll * 0.15) * dt }
        WX.bats = WX.bats.filter { $0.x > v.L - 40 }
    } else { WX.bats = [] }
    if skyIsNight && !["rain", "storm", "snow"].contains(WX.weather) {
        WX.nextShoot -= dt
        if WX.nextShoot <= 0 && WX.shoot == nil { WX.nextShoot = 5 + mrand() * 7; WX.shoot = (rnd(v.L + 120, v.R + 40), rnd(580, 740), 0) }
    }
    if WX.shoot != nil { WX.shoot!.t += dt; WX.shoot!.x -= 460 * dt; WX.shoot!.y -= 170 * dt; if WX.shoot!.t > 0.9 { WX.shoot = nil } }
    if WX.season == "newyear" {
        WX.nextFw -= dt
        if WX.nextFw <= 0 {
            WX.nextFw = 0.7 + mrand() * 0.9
            WX.fw.append(Firework(x: rnd(v.L + 50, v.R - 50), y: rnd(470, 700), t: 0, c: CONF_COL[Int(floor(mrand() * 5))], c2: CONF_COL[Int(floor(mrand() * 5))], n: 18 + Int(floor(mrand() * 8)), sp: rnd(70, 110)))
        }
        for i in WX.fw.indices { WX.fw[i].t += dt; WX.fw[i].x -= scroll * 0.1 * dt }
        WX.fw = WX.fw.filter { $0.t < 1.5 }
    } else { WX.fw = [] }
}
// the pixel pictures (exported from the website)
func pix(_ name: String) -> Img? { img("pix_" + name) }
func sart(_ name: String) -> Img? { img("sart_" + name) }
func wxArt(_ name: String) -> Img? { img("wx_" + name) }
func tintFor() -> Img? {
    var layers: [(String, String)] = []
    if adaptiveBackground && WX.tod == "dawn" { layers.append(("rgba(255,150,190,0.28)", "rgba(255,205,150,0.38)")) }
    if adaptiveBackground && WX.tod == "dusk" { layers.append(("rgba(80,50,140,0.42)", "rgba(255,120,60,0.45)")) }
    let s = WX.season
    if s == "halloween" { layers.append(("rgba(70,20,90,0.35)", "rgba(255,110,20,0.28)")) }
    else if s == "fall" { layers.append(("rgba(255,140,40,0.10)", "rgba(255,140,40,0.16)")) }
    else if s == "winter" || s == "christmas" { layers.append(("rgba(205,225,255,0.18)", "rgba(225,240,255,0.24)")) }
    else if s == "spring" { layers.append(("rgba(255,190,225,0.06)", "rgba(255,190,225,0.12)")) }
    else if s == "summer" && !skyIsNight { layers.append(("rgba(255,245,200,0)", "rgba(255,220,120,0.16)")) }
    else if s == "valentine" { layers.append(("rgba(255,160,200,0.10)", "rgba(255,160,200,0.18)")) }
    else if s == "newyear" { layers.append(("rgba(40,20,80,0.25)", "rgba(40,20,80,0.05)")) }
    let w = WX.weather
    if w == "rain" { layers.append(("rgba(70,80,100,0.32)", "rgba(70,80,100,0.22)")) }
    else if w == "storm" { layers.append(("rgba(25,28,45,0.58)", "rgba(45,50,70,0.40)")) }
    else if w == "snow" { layers.append(("rgba(190,195,210,0.28)", "rgba(210,215,225,0.20)")) }
    else if w == "fog" { layers.append(("rgba(205,210,215,0.20)", "rgba(205,210,215,0.40)")) }
    let key = layers.map { $0.0 + $0.1 }.joined(separator: "|")
    if key == WX.tintKey { return WX.tint }
    WX.tintKey = key
    if layers.isEmpty { WX.tint = nil; return nil }
    let c = CGCanvas(4, 128)
    for (top, bot) in layers { let gr = c.createLinearGradient(0, 0, 0, 128); gr.addColorStop(0, top); gr.addColorStop(1, bot); c.fillStyle = .gradient(gr); c.fillRect(0, 0, 4, 128) }
    WX.tint = c.image()
    return WX.tint
}
func drawImgUp(_ im: Img?, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ smooth: Bool, _ alpha: Double? = nil) {
    guard let im = im else { return }
    ctx.save(); ctx.imageSmoothingEnabled = smooth; if let a = alpha { ctx.globalAlpha = a }
    ctx.translate(x, y + h); ctx.scale(1, -1); ctx.drawImage(im, 0, 0, w, h)
    ctx.restore()
}
func drawWeatherSky() {
    drawWeatherSkyBase()
    if weatherOn() { seasonSky() }
}
private func drawWeatherSkyBase() {
    if !weatherOn() { return }
    let v = viewBox(), L = v.L - 10, R = v.R + 10, w = WX.weather, s = WX.season
    let sx = v.R - 95, sy = worldFlipped() ? SH - 440 : 650
    if !skyIsNight && (w == "clear" || w == "windy") && ["summer", "spring", "fall", "valentine"].contains(s) && WX.tod != "dusk" {
        drawImgUp(wxArt("glowSun"), sx - 90, sy - 90, 180, 180, true)
        ctx.fill("#ffe680")
        for i in 0..<8 {
            let a = Double(i) * Double.pi / 4 + WX.t * 0.25, len = (i % 2 != 0 ? 8.0 : 12) + 3 * sin(WX.t * 3 + Double(i))
            var k = 0.0
            while k < len { ctx.fillRect(jsRound((sx + cos(a) * (36 + k)) / 3) * 3 - 1.5, jsRound((sy + sin(a) * (36 + k)) / 3) * 3 - 1.5, 3, 3); k += 3 }
        }
        spr(wxArt("sun"), sx, sy, 3, 3, 0)
    } else if skyIsNight && w != "rain" && w != "storm" {
        if s == "halloween" { drawImgUp(wxArt("glowOrange"), sx - 120, sy - 120, 240, 240, true); spr(wxArt("pumpkinMoon"), sx, sy, 3, 3, 0) }
        else { drawImgUp(wxArt("glowMoon"), sx - 70, sy - 70, 140, 140, true); spr(wxArt("moon"), sx, sy, 3, 3, 0) }
    }
    if let st = WX.shoot {
        let a = st.t < 0.15 ? st.t / 0.15 : max(0, 1 - (st.t - 0.15) / 0.75)
        for i in 0..<12 { ctx.globalAlpha = a * (1 - Double(i) / 12); ctx.fill("#ffffff"); ctx.fillRect(st.x + Double(i) * 7, st.y + Double(i) * 2.6, 3, 3) }
        ctx.globalAlpha = 1
    }
    for f in WX.fw {
        let a = max(0, 1 - f.t / 1.5), rr = f.sp * (1 - exp(-2.4 * f.t)) / 1.1, drop = 26 * f.t * f.t
        ctx.globalAlpha = a
        for i in 0..<f.n {
            let ang = Double(i) / Double(f.n) * Double.pi * 2
            ctx.fill(i % 2 != 0 ? f.c : f.c2)
            ctx.fillRect(jsRound(f.x + cos(ang) * rr), jsRound(f.y + sin(ang) * rr - drop), 3, 3)
            ctx.fillRect(jsRound(f.x + cos(ang) * rr * 0.6), jsRound(f.y + sin(ang) * rr * 0.6 - drop), 2, 2)
        }
        if f.t < 0.12 { ctx.fill("#fff"); ctx.fillRect(f.x - 3, f.y - 3, 6, 6) }
        ctx.globalAlpha = 1
    }
    if let tint = tintFor() { drawImgUp(tint, L, 0, R - L, SH, true) }
    let cn: String? = w == "storm" ? "cloudStorm" : w == "rain" ? "cloudRain" : w == "snow" ? "cloudSnow" : nil
    if let cn = cn {
        let cv = wxArt(cn), tw = 192.0 * 3, th = 26.0 * 3
        var x0 = jsMod(WX.cloudX, tw); if x0 > 0 { x0 -= tw }
        var x = L + x0
        while x < R { drawImgUp(cv, x, SH - th + 6, tw, th, false); x += tw - 1 }
    }
    if WX.flash > 0 { ctx.fillStyle = .color(RGBA(r: 235 / 255, g: 240 / 255, b: 1, a: 0.42 * WX.flash)); ctx.fillRect(L, 0, R - L, SH) }
    if let b = WX.bolt {
        let a = b.t < 0.2 ? 1 : max(0, 1 - (b.t - 0.2) / 0.12)
        ctx.save(); ctx.lineJoin = "miter"; ctx.lineCap = "square"
        for (lw, col) in [(8.0, RGBA(r: 170 / 255, g: 190 / 255, b: 1, a: 0.35 * a)), (3, RGBA(r: 1, g: 1, b: 1, a: a))] {
            ctx.strokeStyle = .color(col); ctx.lineWidth = lw; ctx.beginPath()
            for (i, p) in b.pts.enumerated() { if i > 0 { ctx.lineTo(p.0, p.1) } else { ctx.moveTo(p.0, p.1) } }
            for (i, p) in b.br.enumerated() { if i > 0 { ctx.lineTo(p.0, p.1) } else { ctx.moveTo(p.0, p.1) } }
            ctx.stroke()
        }
        ctx.restore()
    }
    for b in WX.bats {
        let up = Int(floor(b.t * 8)) % 2 == 0
        spr(pix(up ? "batUp" : "batDown"), jsRound(b.x), jsRound(b.y + sin(b.t * 3 + b.ph) * 10), 3, 3, 0)
    }
    if w == "fog" { drawFogBand(0.5, 250, 0.55) }
}
func drawFogBand(_ speed: Double, _ y: Double, _ alpha: Double) {
    let v = viewBox(), cv = wxArt("fog"), tw = 256.0 * 4, th = 64.0 * 4
    var x0 = jsMod(WX.fogX * speed, tw); if x0 > 0 { x0 -= tw }
    var x = v.L - 10 + x0
    while x < v.R + 10 { drawImgUp(cv, x, y - th / 2, tw, th, true, alpha); x += tw - 2 }
}
func hash2(_ a: Int, _ b: Int) -> Double {
    // (the same arithmetic as JavaScript: the big product is a rounded double, then |0)
    func toInt32(_ d: Double) -> Int32 { Int32(truncatingIfNeeded: Int64(d.truncatingRemainder(dividingBy: 4294967296))) }
    var h = toInt32(Double(a) * 374761393 + Double(b) * 668265263)
    h = toInt32(Double(h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 13)) * 1274126177)
    return Double(UInt32(bitPattern: h ^ Int32(bitPattern: UInt32(bitPattern: h) >> 16))) / 4294967296
}
func drawSeasonPipes() {
    drawSeasonPipesBase()
    if weatherOn() { seasonPipes() }
}
private func drawSeasonPipesBase() {
    if !weatherOn() { return }
    let s = WX.season, snowy = s == "winter" || s == "christmas" || WX.weather == "snow"
    if !snowy && !["halloween", "spring", "fall"].contains(s) { return }
    for p in pipeList where p.falling == nil && !p.gold {
        let R = pipeRects(p), x = R.up.cx, top = R.up.cy + 512, bot = R.down.cy - 512, k = p.k != 0 ? p.k : 1
        if snowy {
            ctx.fill("#f4f8ff")
            for i in 0..<33 { let h = 2 + Int(floor(hash2(k, i) * 2.2)) + (i > 3 && i < 29 ? 1 : 0); ctx.fillRect(x - 33 + Double(i) * 2, top, 2, Double(h) * 2) }
            ctx.fill("#cfe0f0"); ctx.fillRect(x - 33, top, 66, 2)
            for j in 0..<5 {
                let ix = x - 26 + Double(j) * 12 + floor(hash2(k, j + 40) * 4) * 2, len = 3 + Int(floor(hash2(k, j + 80) * 5))
                for r in 0..<len { ctx.fill(r == len - 1 ? "#ffffff" : "#d8eeff"); ctx.fillRect(ix, bot - 2 - Double(r) * 2, Double(r) < Double(len) / 2 ? 4 : 2, 2) }
            }
            if s == "christmas" {
                let Cc = ["#ff3b3b", "#3bff6b", "#ffd23b", "#3bb0ff"]
                for i in 0..<7 {
                    let on = (Int(floor(WX.t * 2.5)) + i + k) % 3 != 0
                    ctx.fill(on ? Cc[(i + k) % 4] : "#555"); ctx.fillRect(x - 27 + Double(i) * 9, top - 10, 4, 4)
                    if on { ctx.globalAlpha = 0.35; ctx.fillRect(x - 29 + Double(i) * 9, top - 12, 8, 8); ctx.globalAlpha = 1 }
                }
            }
        } else if s == "halloween" {
            spr(pix("web"), x - 22, bot - 9, 2, 2, 0)
            if k % 3 == 0 {
                let sy = bot - 34 - 12 * sin(WX.t * 1.8 + Double(k))
                ctx.fill("rgba(230,230,240,0.8)"); ctx.fillRect(x + 12, sy, 1, bot - sy)
                spr(pix("spider"), x + 12.5, sy - 4, 2, 2, 0)
            }
        } else if s == "spring" {
            spr(pix(k % 2 != 0 ? "flowerP" : "flowerW"), x - 18, top + 7.5, 3, 3, 0)
            spr(pix(k % 2 != 0 ? "flowerY" : "flowerV"), x + 16, top + 7.5, 3, 3, 0)
        } else if s == "fall" {
            spr(pix("leafRest"), x - 14 + Double(k % 3) * 6, top + 3, 3, 3, 0)
            if k % 2 != 0 { spr(pix("leafRest"), x + 16, top + 3, 3, 3, 0) }
        }
    }
}
func drawSeasonGround() {
    drawSeasonGroundBase()
    if weatherOn() { seasonGround() }
}
private func drawSeasonGroundBase() {
    if !weatherOn() { return }
    let s = WX.season, snowy = s == "winter" || s == "christmas" || WX.weather == "snow"
    let landW = 336.0 * 2, n = 2 + Int(floor(width / landW))
    for i in 0..<n {
        let cx = groundX + Double(i) * (landW - 1), left = cx - 336
        func at(_ name: String, _ off: Double, _ sc: Double) { if let im = pix(name) { spr(im, left + off, 224 + Double(im.height) * sc / 2 - 2, sc, sc, 0) } }
        if s == "halloween" { at("pumpkin", 70, 3); at("tomb", 185, 3); at("pumpkin", 300, 3); at("pumpkin", 505, 3); at("tomb", 610, 3) }
        else if s == "spring" { let F = ["flowerP", "flowerY", "flowerW", "flowerV"]; for (j, o) in [20.0, 55, 110, 160, 205, 260, 330, 380, 430, 470, 540, 590, 640].enumerated() { at(F[j % 4], o, 3) } }
        else if s == "fall" { for o in [60.0, 250, 420, 600] { at("leafpile", o, 3) } }
        else if s == "summer" { at("sunflower", 90, 3); at("sunflower", 380, 3); at("sunflower", 560, 3) }
        if snowy { spr(wxArt("snowStrip"), cx, 226, 2, 2, 0) }
        if s == "christmas" { let f = Int(floor(WX.t * 2)) % 2; at(f != 0 ? "tree1" : "tree2", 140, 3); at(f != 0 ? "tree2" : "tree1", 470, 3) }
    }
}
func drawWeatherFront(_ flip: Bool) {
    if !weatherOn() || (WX.parts.isEmpty && WX.splash.isEmpty && WX.weather != "fog") { return }
    let rain = WX.parts.filter { $0.k == "rain" }
    if !rain.isEmpty {
        ctx.strokeStyle = .s(WX.weather == "storm" ? "rgba(200,215,240,0.6)" : "rgba(200,220,255,0.5)"); ctx.lineWidth = 2
        ctx.beginPath()
        for p in rain { ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + p.vx * 0.014, p.y + p.vy * 0.014) }
        ctx.stroke()
    }
    ctx.fill("rgba(210,225,255,0.7)")
    for s in WX.splash { let d = 2 + s.t * 40; ctx.fillRect(s.x - d, 226 + s.t * 18, 2, 2); ctx.fillRect(s.x + d, 226 + s.t * 18, 2, 2) }
    for p in WX.parts {
        if p.k == "snow" { ctx.fill("#ffffff"); ctx.fillRect(jsRound(p.x), jsRound(p.y), p.s, p.s) }
        else if p.k == "leaf" || p.k == "petal" || p.k == "confetti" {
            let w = max(1, abs(cos(WX.t * p.spin + p.ph)) * (p.k == "leaf" ? 9 : p.k == "petal" ? 6 : 5))
            ctx.fill(p.c); ctx.fillRect(jsRound(p.x - w / 2), jsRound(p.y), w, p.k == "leaf" ? 5 : 3)
            if p.k == "leaf" { ctx.fill("rgba(0,0,0,0.18)"); ctx.fillRect(jsRound(p.x - w / 2), jsRound(p.y) + 2, w, 1) }
        } else if p.k == "fly" {
            let a = 0.45 + 0.55 * max(0, sin(WX.t * 2.2 + p.ph))
            drawImgUp(wxArt("glowFly"), p.x - 12, p.y - 12, 24, 24, true, a)
            ctx.fillStyle = .color(RGBA(r: 240 / 255, g: 1, b: 150 / 255, a: a)); ctx.fillRect(jsRound(p.x) - 1, jsRound(p.y) - 1, 3, 3)
        } else if p.k == "heart" { ctx.globalAlpha = max(0, min(1, (SH - p.y) / 120)) * 0.85; spr(pix("heart"), jsRound(p.x), jsRound(p.y), 2, 2, 0); ctx.globalAlpha = 1 }
    }
    let streaks = WX.parts.filter { $0.k == "streak" }
    if !streaks.isEmpty {
        ctx.strokeStyle = .s("rgba(255,255,255,0.38)"); ctx.lineWidth = 2; ctx.beginPath()
        for p in streaks { let k = p.len / max(1, -p.vx); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * k, p.y - p.vy * k) }
        ctx.stroke()
    }
    if WX.weather == "fog" { drawFogBand(1, 330, 0.75); drawFogBand(1.6, 470, 0.5) }
}

// ===================== v132: richer seasons =====================
final class WX2State {
    var par = 0.0, witch: (x: Double, y: Double, t: Double)? = nil, nextWitch = 6.0
    var ghosts: [(x: Double, y: Double, t: Double, life: Double, ph: Double, s: Double, vx: Double)] = [], nextGhost = 2.0
    var sleigh: (x: Double, y: Double, t: Double)? = nil, nextSleigh = 8.0
    var flies: [(x: Double, y: Double, t: Double, ph: Double, c: Bool, vx: Double, vy: Double)] = []
    var gulls: [(x: Double, y: Double, t: Double, ph: Double)] = [], nextGull = 3.0
    var hearts: [(x: Double, y: Double, t: Double, ph: Double)] = [], nextHeart = 1.5
    var plane: (x: Double, y: Double, t: Double)? = nil, nextPlane = 5.0
}
let WX2 = WX2State()
func seasonSky() {
    let s = WX.season, v = viewBox(), t = WX.t
    if s == "halloween" {
        let span = 1400.0
        var x = jsMod(jsMod(v.L + 260 + WX2.par * 0.25, span) + span, span) + v.L - 200
        while x < v.R + 200 {
            ctx.fill("#1c1028")
            var i = -190.0
            while i <= 190 { let c = cos(i / 190 * Double.pi / 2), hh = jsRound((4 + 62 * c * c) / 3) * 3; ctx.fillRect(x + i, 224, 3, hh); i += 3 }
            let lit = sin(t * 7.3 + sin(t * 2.1) * 3) > -0.6
            spr(sart(lit ? "house" : "houseDim"), x, 224 + 62 + 27 - 3, 3, 3, 0)
            if lit { drawImgUp(wxArt("glowOrange"), x - 60, 224 + 40, 120, 90, true, 0.35) }
            spr(sart("deadTree"), x - 120, 224 + jsRound((4 + 62 * pow(cos(120.0 / 190 * Double.pi / 2), 2)) / 3) * 3 + 19, 3, 3, 0)
            spr(sart("deadTree"), x + 140, 224 + jsRound((4 + 62 * pow(cos(140.0 / 190 * Double.pi / 2), 2)) / 3) * 3 + 19, -3, 3, 0)
            x += span
        }
        for g in WX2.ghosts {
            ctx.globalAlpha = min(1, g.t / 1.2, (g.life - g.t) / 1.2) * 0.75
            spr(sart("ghostW"), jsRound(g.x), jsRound(g.y + sin(g.t * 2 + g.ph) * 10), g.s, g.s, sin(g.t * 1.5 + g.ph) * 0.12)
            ctx.globalAlpha = 1
        }
        if let w = WX2.witch { spr(sart("witch"), jsRound(w.x), jsRound(w.y + sin(w.t * 3) * 8), -3, 3, sin(w.t * 3) * 0.06) }
    }
    if (s == "winter" || s == "christmas") && skyIsNight && WX.weather == "clear" {
        let L = v.L, R = v.R
        for band in 0..<3 {
            let col = [(90.0, 255.0, 170.0), (120, 200, 255), (190, 120, 255)][band]
            var x = floor(L / 6) * 6
            while x < R {
                let y = 600 + Double(band) * 26 + sin(x * 0.006 + t * 0.5 + Double(band)) * 26 + sin(x * 0.017 - t * 0.8) * 10
                let a = 0.12 + 0.1 * sin(x * 0.01 + t + Double(band) * 2)
                ctx.fillStyle = .color(RGBA(r: col.0 / 255, g: col.1 / 255, b: col.2 / 255, a: max(0, (a * 1000).rounded() / 1000))); ctx.fillRect(x, y, 6, 40 + Double(band) * 10)
                x += 6
            }
        }
    }
    if s == "christmas", let sl = WX2.sleigh { spr(sart("sleigh"), jsRound(sl.x), jsRound(sl.y + sin(sl.t * 2) * 6), -3, 3, 0) }
    if s == "spring" { for f in WX2.flies { let up = Int(floor(f.t * 9 + f.ph)) % 2; spr(sart(f.c ? (up != 0 ? "flyB1" : "flyB2") : (up != 0 ? "fly1" : "fly2")), jsRound(f.x), jsRound(f.y), 3, 3, 0) } }
    if s == "summer" { for g in WX2.gulls { let up = Int(floor(g.t * 4 + g.ph)) % 2; spr(sart(up != 0 ? "gull1" : "gull2"), jsRound(g.x), jsRound(g.y + sin(g.t + g.ph) * 6), 3, 3, 0) } }
    if s == "valentine" { for h in WX2.hearts { spr(sart("heartBal"), jsRound(h.x + sin(h.t * 1.3 + h.ph) * 10), jsRound(h.y), 3, 3, sin(h.t * 1.3 + h.ph) * 0.1) } }
    if s == "newyear", let p = WX2.plane {
        let c = Calendar.current, yr = c.component(.month, from: Date()) == 12 ? c.component(.year, from: Date()) + 1 : c.component(.year, from: Date())
        let text = "HAPPY NEW YEAR \(yr)", tw = panelTextWidth(text) + 24, bx = p.x + 40, by = p.y + sin(p.t * 2) * 4
        ctx.fill("#cfc8d8"); ctx.fillRect(p.x + 18, by + 2, 24, 2)
        ctx.fill("#fff6e0"); ctx.fillRect(bx, by - 10, tw, 24)
        ctx.fill("#e8281e"); ctx.fillRect(bx, by - 12, tw, 3); ctx.fillRect(bx, by + 13, tw, 3)
        drawPanelText(text, jsRound(bx + 12), jsRound(by - 6))
        spr(sart("plane"), jsRound(p.x), jsRound(p.y + sin(p.t * 2) * 4), -3, 3, 0)
    }
}
func updateSeasons(_ dt: Double) {
    if !weatherOn() { WX2.witch = nil; WX2.ghosts = []; WX2.sleigh = nil; WX2.plane = nil; return }
    let s = WX.season, v = viewBox(), scroll = moving.speed > 0 && !ending.frozen ? 200 * speedMul() : 0
    WX2.par -= scroll * dt
    if s == "halloween" {
        WX2.nextWitch -= dt
        if WX2.witch == nil && WX2.nextWitch <= 0 { WX2.nextWitch = 14 + mrand() * 10; WX2.witch = (v.R + 60, 630 + mrand() * 30, 0) }
        if var w = WX2.witch { w.t += dt; w.x -= (70 + scroll * 0.08) * dt; w.y += sin(w.t * 0.8) * 10 * dt; WX2.witch = w.x < v.L - 80 ? nil : w }
        WX2.nextGhost -= dt
        if WX2.nextGhost <= 0 && WX2.ghosts.count < 3 { WX2.nextGhost = 3 + mrand() * 4; WX2.ghosts.append((rnd(v.L + 60, v.R + 60), rnd(380, 700), 0, 6 + mrand() * 4, mrand() * 6, mrand() < 0.5 ? 2 : 3, -rnd(15, 40))) }
        for i in WX2.ghosts.indices { WX2.ghosts[i].t += dt; WX2.ghosts[i].x += (WX2.ghosts[i].vx - scroll * 0.06) * dt }
        WX2.ghosts = WX2.ghosts.filter { $0.t < $0.life }
    } else { WX2.witch = nil; WX2.ghosts = [] }
    if s == "christmas" {
        WX2.nextSleigh -= dt
        if WX2.sleigh == nil && WX2.nextSleigh <= 0 { WX2.nextSleigh = 16 + mrand() * 10; WX2.sleigh = (v.R + 100, 660 + mrand() * 40, 0) }
        if var sl = WX2.sleigh { sl.t += dt; sl.x -= (80 + scroll * 0.08) * dt; WX2.sleigh = sl.x < v.L - 160 ? nil : sl }
    } else { WX2.sleigh = nil }
    if s == "spring" {
        while WX2.flies.count < 5 { WX2.flies.append((rnd(v.L, v.R + 200), rnd(260, 520), 0, mrand() * 6, mrand() < 0.4, rnd(-30, 20), 0)) }
        for i in WX2.flies.indices {
            WX2.flies[i].t += dt; WX2.flies[i].vy += rnd(-60, 60) * dt; WX2.flies[i].vy = max(-30, min(30, WX2.flies[i].vy))
            WX2.flies[i].x += (WX2.flies[i].vx - scroll * 0.6) * dt; WX2.flies[i].y = max(250, min(560, WX2.flies[i].y + WX2.flies[i].vy * dt))
        }
        WX2.flies = WX2.flies.filter { $0.x > v.L - 30 }
    } else { WX2.flies = [] }
    if s == "summer" {
        WX2.nextGull -= dt
        if WX2.nextGull <= 0 { WX2.nextGull = 4 + mrand() * 5; let n = 1 + Int(floor(mrand() * 3)), y0 = rnd(520, 700); for i in 0..<n { WX2.gulls.append((v.R + 30 + Double(i) * 26, y0 + Double(i) * 12, 0, mrand() * 6)) } }
        for i in WX2.gulls.indices { WX2.gulls[i].t += dt; WX2.gulls[i].x -= (35 + scroll * 0.08) * dt }
        WX2.gulls = WX2.gulls.filter { $0.x > v.L - 30 }
    } else { WX2.gulls = [] }
    if s == "valentine" {
        WX2.nextHeart -= dt
        if WX2.nextHeart <= 0 && WX2.hearts.count < 6 { WX2.nextHeart = 2 + mrand() * 3; WX2.hearts.append((rnd(v.L + 30, v.R + 100), 240, 0, mrand() * 6)) }
        for i in WX2.hearts.indices { WX2.hearts[i].t += dt; WX2.hearts[i].y += 28 * dt; WX2.hearts[i].x -= scroll * 0.2 * dt }
        WX2.hearts = WX2.hearts.filter { $0.y < SH + 40 }
    } else { WX2.hearts = [] }
    if s == "newyear" {
        WX2.nextPlane -= dt
        if WX2.plane == nil && WX2.nextPlane <= 0 { WX2.nextPlane = 18 + mrand() * 8; WX2.plane = (v.R + 40, 640, 0) }
        if var p = WX2.plane { p.t += dt; p.x -= 70 * dt; WX2.plane = p.x < v.L - 520 ? nil : p }
    } else { WX2.plane = nil }
}
func seasonPipes() {
    let s = WX.season
    for p in pipeList where p.falling == nil && !p.gold {
        let R = pipeRects(p), x = R.up.cx, top = R.up.cy + 512, bot = R.down.cy - 512, k = p.k != 0 ? p.k : 1
        if s == "halloween" {
            if k % 2 == 0 {
                let fl = 0.6 + 0.4 * sin(WX.t * 9 + Double(k) * 2) * sin(WX.t * 5.3 + Double(k))
                drawImgUp(wxArt("glowOrange"), x - 30, top - 10, 60, 50, true, 0.35 + 0.35 * fl)
                spr(sart("jack"), x + (k % 4 == 0 ? -12 : 12), top + 13.5, 3, 3, 0)
            } else { spr(sart("candyCorn"), x + 16, top + 6, 3, 3, 0) }
            if k % 3 == 1 { let sw = sin(WX.t * 1.6 + Double(k)) * 0.12; spr(sart("hangBat"), x - 14, bot - 9, 3, 3, sw) }
            if k % 5 == 2 { spr(sart("hangBat"), x + 18, bot - 9, 3, 3, -sin(WX.t * 1.4 + Double(k)) * 0.12) }
        } else if s == "christmas" {
            if k % 2 != 0 { spr(sart("wreath"), x, top - 40, 3, 3, 0) }
            for j in 0..<3 {
                let ox = x - 22 + Double(j) * 22, len = 10 + Double((k * 7 + j * 5) % 4) * 6
                ctx.fill("#c8c8d0"); ctx.fillRect(ox, bot - len, 2, len)
                ctx.fill(["#ff3b3b", "#ffd23b", "#3bb0ff"][(j + k) % 3]); ctx.fillRect(ox - 4, bot - len - 9, 10, 10)
                ctx.fill("#ffffff"); ctx.fillRect(ox - 2, bot - len - 3, 2, 2)
            }
        } else if s == "winter" {
            if k % 3 == 0 { spr(sart("snowman"), x + 10, top + 21, 2, 2, 0) }
        } else if s == "spring" {
            if k % 2 == 0 { ctx.fill("#3f9a30"); for i in 0..<6 { ctx.fillRect(x - 33 + Double((i * 11 + k * 3) % 64), bot - 4 - Double(i % 3) * 6, 3, 6 + Double(i % 3) * 6) } }
        } else if s == "summer" {
            if k % 3 == 1 { spr(sart("beachball"), x + 14, top + 7.5, 3, 3, 0) }
        } else if s == "fall" {
            if k % 2 == 0 { spr(sart("crow"), x - 10, top + 7.5, k % 4 != 0 ? 3 : -3, 3, 0) }
            if k % 3 == 1 { spr(sart("gourd"), x + 16, top + 7.5, 3, 3, 0) }
        } else if s == "valentine" {
            for j in 0..<5 { let hx = x - 26 + Double(j) * 13, hy = bot - 10 - jsRound(sin(Double(j) / 4 * Double.pi) * 6); ctx.fill("#e8e0e8"); ctx.fillRect(hx, hy + 6, 13, 1); spr(sart("miniHeart"), hx + 1, hy, 3, 3, 0) }
        } else if s == "newyear" {
            if k % 2 != 0 { spr(sart("partyHat"), x - 8, top + 10.5, 3, 3, 0) }
            let Cc = ["#ff3b3b", "#ffd23b", "#3bb0ff", "#ff6bf0", "#3bff6b"]
            for j in 0..<4 { ctx.fill(Cc[(j + k) % 5]); for r in 0..<7 { ctx.fillRect(x - 24 + Double(j) * 16 + Double(r % 2) * 3, bot - 4 - Double(r) * 4, 3, 4) } }
        }
    }
}
func seasonGround() {
    let s = WX.season, landW = 336.0 * 2, n = 2 + Int(floor(width / landW))
    for i in 0..<n {
        let cx = groundX + Double(i) * (landW - 1), left = cx - 336
        func at(_ name: String, _ off: Double, _ sc: Double, _ flip: Bool = false) { if let im = sart(name) { spr(im, left + off, 224 + Double(im.height) * sc / 2 - 2, flip ? -sc : sc, sc, 0) } }
        if s == "halloween" {
            at("fence", 120, 3); at("fence", 545, 3)
            at("hand", 255, 3); at("candyCorn", 345, 3); at("candyCorn", 470, 3)
            let ph = jsMod(WX.t * 0.35 + Double(i) * 0.5, 1), rise = ph < 0.15 ? ph / 0.15 : ph < 0.45 ? 1 : ph < 0.6 ? 1 - (ph - 0.45) / 0.15 : 0
            if rise > 0 { ctx.globalAlpha = 0.85; spr(sart("ghostW"), left + 185 + 4, 224 + 6 + rise * 30, 2, 2, sin(WX.t * 3) * 0.1); ctx.globalAlpha = 1; spr(pix("tomb"), left + 185, 224 + 9 * 3 / 2 - 2, 3, 3, 0) }
            if skyIsNight { for o in [70.0, 300, 505] { drawImgUp(wxArt("glowOrange"), left + o - 26, 216, 52, 44, true, 0.45 + 0.25 * sin(WX.t * 7 + o)) } }
            ctx.fill("rgba(120,60,150,0.16)"); ctx.fillRect(left, 224, landW, 22)
            ctx.fill("rgba(255,140,60,0.08)"); ctx.fillRect(left, 224, landW, 8)
        } else if s == "christmas" {
            at("present1", 175, 3); at("present2", 200, 3); at("present3", 500, 3); at("present1", 520, 3)
            at("snowman", 330, 3); at("cane", 60, 3); at("cane", 610, 3, true)
            let Cc = ["#ff3b3b", "#3bff6b", "#ffd23b", "#3bb0ff"]
            for j in 0..<24 { let on = (Int(floor(WX.t * 3)) + j) % 4 != 0; ctx.fill(on ? Cc[j % 4] : "#4a4a52"); ctx.fillRect(left + Double(j) * 28, 228 + Double(j % 2) * 3, 4, 4) }
        } else if s == "winter" {
            at("pine", 90, 3); at("pine", 130, 3); at("snowman", 300, 3); at("pine", 470, 3); at("pine", 620, 3)
        } else if s == "spring" {
            at("blossom", 300, 3); at("tulipR", 230, 3); at("tulipY", 400, 3); at("tulipR", 575, 3)
            let hop = abs(sin(WX.t * 3 + Double(i)))
            if let b = sart(hop > 0.5 ? "bunny2" : "bunny1") { spr(b, left + 500 + sin(WX.t * 0.5 + Double(i)) * 40, 224 + 10 + hop * 12, 3, 3, 0) }
        } else if s == "summer" {
            at("umbrella", 230, 3); at("sandcastle", 470, 3); at("beachball", 310, 3)
        } else if s == "fall" {
            at("scarecrow", 330, 3); at("hay", 150, 3); at("hay", 180, 3); at("gourd", 520, 3); at("gourd", 545, 3)
        } else if s == "valentine" {
            at("roses", 120, 3); at("roses", 360, 3); at("roses", 590, 3)
        } else if s == "newyear" {
            at("balloonNY", 140, 3); at("balloonNY", 420, 3); at("balloonNY", 640, 3)
        }
    }
}
