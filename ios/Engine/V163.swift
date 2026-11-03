import Foundation

// ===================== v163: the bird sleeps at night, a seasonal logo, the bird reacts to the weather =====================
// (the website's nb/t_zzzzzzzz163.js, line by line)

/// drawing in a sprite's own pixels (y down, like the picture), so extras sit exactly on it
func inSprite(_ x: Double, _ y: Double, _ s: Double, _ rot: Double, _ w: Double, _ h: Double, _ fn: () -> Void) {
    ctx.save(); ctx.translate(x, y); if rot != 0 { ctx.rotate(rot) }; ctx.scale(s, -s); ctx.translate(-w / 2, -h / 2)
    fn(); ctx.restore()
}
func px1(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ col: String) { ctx.fill(col); ctx.fillRect(x, y, w, h) }
func px1(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ col: String) { px1(Double(x), Double(y), Double(w), Double(h), col) }
/// what a picture looks like inside: its pixels (cached)
struct PixData { let w: Int, h: Int, d: [UInt8] }
private var PXDATA: [ObjectIdentifier: PixData] = [:], PXKEEP: [ObjectIdentifier: Img] = [:]
func pixData(_ im: Img) -> PixData {
    let k = ObjectIdentifier(im)
    if let hit = PXDATA[k] { return hit }
    let c = CGCanvas(im.width, im.height); c.drawImage(im, 0, 0)
    let out = PixData(w: im.width, h: im.height, d: c.getImageData())
    PXDATA[k] = out; PXKEEP[k] = im
    return out
}
/// the bird's eye: which big pixels are the eye, and the colours around it
struct BirdEye { let cells: [(Int, Int)], top: Int, bot: Int, left: Int, right: Int, L: String, O: String, ox: Int, oy: Int }
private var EYES: [ObjectIdentifier: BirdEye?] = [:]
func birdEye(_ im: Img) -> BirdEye? {
    let key = ObjectIdentifier(im)
    if let hit = EYES[key] { return hit }
    var out: BirdEye? = nil
    let P = pixData(im), w = P.w, h = P.h, ox = Int((Double(w - 34) / 2).rounded()), oy = Int((Double(h - 24) / 2).rounded())
    func px(_ x: Int, _ y: Int) -> [Int]? {
        let X = ox + x * 2, Y = oy + y * 2
        if X < 0 || Y < 0 || X >= w || Y >= h { return nil }
        let i = (Y * w + X) * 4
        return P.d[i + 3] > 10 ? [Int(P.d[i]), Int(P.d[i + 1]), Int(P.d[i + 2])] : nil
    }
    func hex(_ c: [Int]) -> String { "#" + c.map { String(format: "%02x", $0) }.joined() }
    if let white = px(11, 2), let pupil = px(12, 3), let lid = px(8, 2) ?? px(7, 2) {
        let line = px(7, 0)
        func near(_ a: [Int]?, _ b: [Int]) -> Bool { guard let a = a else { return false }; return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) < 40 }
        var cells: [(Int, Int)] = []
        for y in 0...6 { for x in 8...15 { let c = px(x, y); if near(c, white) || (near(c, pupil) && x >= 11 && y >= 2 && y <= 5) { cells.append((x, y)) } } }
        if cells.count >= 6 {
            let ys = cells.map { $0.1 }, xs = cells.map { $0.0 }
            out = BirdEye(cells: cells, top: ys.min()!, bot: ys.max()!, left: xs.min()!, right: xs.max()!, L: hex(lid), O: line.map(hex) ?? "#533846", ox: ox, oy: oy)
        }
    }
    EYES[key] = .some(out); PXKEEP[key] = im
    return out
}
/// draw on the bird, in its picture's pixels (cells are 2 x 2)
func onBird(_ fn: (Img, Int, Int, Int, Int) -> Void) {
    guard let im = birdFrame(), bird.added else { return }
    let w = im.width, h = im.height
    inSprite(bird.x, bird.y, bird.scale, bird.rot, Double(w), Double(h)) { fn(im, w, h, Int((Double(w - 34) / 2).rounded()), Int((Double(h - 24) / 2).rounded())) }
}
func birdExtrasOK() -> Bool { bird.added && afterlife == 0 && !haunted && !ending.on && !worldFlipped() && !glitchVisible() }

// ======================================================= the bird sleeps at night (3 to 6 AM, on the title screen)
var SLEEP_FORCE = false   // (Developer page)
func sleepyHour() -> Bool { let h = Calendar.current.component(.hour, from: Date()); return SLEEP_FORCE || (h >= 3 && h < 6) }
func onTitle() -> Bool { flappyBird.added && playButton.added && !bird.dynamic && !isWaitingToStart && !isGameOver && !isShowingGameOver }
func sleepingNow() -> Bool { sleepyHour() && onTitle() && birdExtrasOK() }
func drawSleep() {
    if !sleepingNow() { return }
    let t = sceneTime, m = t.truncatingRemainder(dividingBy: 6), doze = m > 3.6 && m < 5.4   // every few seconds it nods off completely, then jerks awake
    onBird { im, _, _, _, _ in
        guard let e = birdEye(im) else { return }
        let shut = doze ? e.bot : Int(jsRound(Double(e.top + e.bot) / 2))   // half closed, or all the way
        for (x, y) in e.cells where y <= shut { px1(e.ox + x * 2, e.oy + y * 2, 2, 2, e.L) }
        px1(e.ox + e.left * 2, e.oy + shut * 2 + 1, (e.right - e.left + 1) * 2, 1, e.O)   // the eyelid's edge
    }
    // Zzz
    let x = bird.x, y = bird.y + 30
    for i in 0..<3 {
        let f = (t * 0.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1), k = [1.0, 2, 2][i]
        ctx.globalAlpha = min(1, (1 - f) * 2)
        glyphText("Z", jsRound(x + 14 + f * 16 + Double(i) * 3), jsRound(y + f * 30 + 6), "#ffffff", k + f)
    }
    ctx.globalAlpha = 1
}

// ======================================================= the logo dresses up for the season
private var LOGO_TOP: [ObjectIdentifier: [Int]] = [:]
func logoTops(_ im: Img) -> [Int] {   // for every column of the logo: its top pixel (-1 = empty)
    let k = ObjectIdentifier(im)
    if let hit = LOGO_TOP[k] { return hit }
    let P = pixData(im); var out: [Int] = []
    for x in 0..<P.w { var top = -1; for y in 0..<P.h where P.d[(y * P.w + x) * 4 + 3] > 40 { top = y; break }; out.append(top) }
    LOGO_TOP[k] = out
    return out
}
func hash1(_ n: Double) -> Double { let s = sin(n * 127.1 + 311.7) * 43758.5453; return s - floor(s) }
func drawLogoSeason() {
    if !flappyBird.added || flappyBird.scale <= 0 || !weatherOn() { return }
    let s = WX.season; if s.isEmpty || s == "classic" { return }
    guard let im = img("flappy_logo") else { return }
    let tops1 = logoTops(im)
    // the logo is drawn in 2 x 2 "big pixels": decorate in the same big pixels
    let w = im.width / 2, h = im.height / 2, t = sceneTime
    var tops: [Int] = []
    for x in 0..<w { let a = tops1[2 * x], b = tops1[2 * x + 1], m = a < 0 ? b : b < 0 ? a : min(a, b); tops.append(m < 0 ? -1 : m / 2) }
    inSprite(flappyBird.x, flappyBird.y, flappyBird.scale * 2, 0, Double(w), Double(h)) {
        if s == "winter" || s == "christmas" {   // snow on top of every letter
            for (x, y) in tops.enumerated() where y >= 0 { let lump = hash1(Double(x)) > 0.6 ? 1 : 0; px1(x, y - lump, 1, lump + 1, "#ffffff") }
            if s == "christmas" { var x = 4; while x < w - 4 { if tops[x] >= 0 { px1(x, tops[x] - 2, 1, 1, ["#e8281e", "#2fbf3f", "#ffd23c"][(x / 7) % 3]) }; x += 7 } }
        } else if s == "spring" {   // little flowers growing on the letters
            var x = 3
            while x < w - 3 {
                let y = tops[x]
                if y >= 0 { let c = ["#ff7ab8", "#ffffff", "#c890ff"][(x / 9) % 3]; px1(x, y - 3, 1, 3, "#3a9a3a"); px1(x - 1, y - 5, 3, 1, c); px1(x, y - 6, 1, 3, c); px1(x, y - 5, 1, 1, "#ffd23c") }
                x += 9
            }
        } else if s == "summer" {   // a sun coming up behind the corner
            let cx = w - 2, cy = -1, r = 4.0
            for y in -6...6 { for x in -6...6 { let d = hypot(Double(x), Double(y)); if d <= r { px1(cx + x, cy + y, 1, 1, d > r - 1.2 ? "#ffb020" : "#ffe14a") } } }
            for i in 0..<8 { let a = Double(i) * .pi / 4 + t * 0.3; px1(Int(jsRound(Double(cx) + cos(a) * 6)), Int(jsRound(Double(cy) + sin(a) * 6)), 1, 1, "#ffe680") }
        } else if s == "fall" || s == "thanksgiving" {   // leaves on top, one drifting down
            var x = 2
            while x < w - 2 { let y = tops[x]; if y >= 0 { px1(x, y - 1, 2, 1, ["#e8742a", "#c8401e", "#f0b030"][(x / 5) % 3]) }; x += 5 }
            let f = (t * 0.15).truncatingRemainder(dividingBy: 1), lx = jsRound(Double(w) * 0.3 + sin(t * 2) * 6 + f * 20), ly = jsRound(-6 + f * Double(h + 10))
            px1(lx, ly, 1, 1, "#e8742a")
        } else if s == "halloween" {   // cobwebs in the corners, a spider on a thread
            func web(_ cx: Int, _ cy: Int, _ dx: Int) {
                for i in 0..<8 { px1(cx + dx * i, cy - 1, 1, 1, "#e8e8f0"); px1(cx, cy - 1 + i, 1, 1, "#e8e8f0"); px1(cx + dx * Int(jsRound(Double(i) * 0.8)), cy - 1 + Int(jsRound(Double(i) * 0.8)), 1, 1, "#e8e8f0") }
                for r in [3, 6] { for i in 0...r { px1(cx + dx * i, cy - 1 + r - i, 1, 1, "#cfcfdc") } }
            }
            web(0, 0, 1); web(w - 1, 0, -1)
            let sx = Int(jsRound(Double(w) * 0.3)), drop = 3 + Int(jsRound((sin(t * 1.3) + 1) * 3))   // a spider on a thread under the "a"
            px1(sx, h - 3, 1, drop + 3, "#e8e8f0")
            px1(sx - 1, h + drop, 3, 2, "#1e1028"); px1(sx - 2, h + drop - 1, 1, 1, "#1e1028"); px1(sx + 2, h + drop - 1, 1, 1, "#1e1028"); px1(sx - 2, h + drop + 2, 1, 1, "#1e1028"); px1(sx + 2, h + drop + 2, 1, 1, "#1e1028")
            px1(sx - 1, h + drop, 1, 1, "#ff3030"); px1(sx + 1, h + drop, 1, 1, "#ff3030")
        } else if s == "valentine" {   // hearts on top
            var x = 5
            while x < w - 5 {
                let y = tops[x]
                if y >= 0 { let b = Int(jsRound(sin(t * 3 + Double(x)))); px1(x - 1, y - 5 + b, 2, 1, "#e8285a"); px1(x + 2, y - 5 + b, 2, 1, "#e8285a"); px1(x - 1, y - 4 + b, 5, 1, "#e8285a"); px1(x, y - 3 + b, 3, 1, "#e8285a"); px1(x + 1, y - 2 + b, 1, 1, "#e8285a") }
                x += 11
            }
        } else if s == "newyear" {   // a party hat on the F, confetti falling
            let fx = tops.firstIndex(where: { $0 >= 0 }) ?? 0, fy = tops[fx]
            for i in 0..<6 { px1(fx + 3 - i / 2, fy - 6 + i, 1 + 2 * (i / 2), 1, i % 2 == 1 ? "#ffd23c" : "#3c4bff") }   // a little cone
            px1(fx + 2, fy - 8, 3, 2, "#ff4fa3")
            for i in 0..<12 { let f = (t * 0.25 + hash1(Double(i))).truncatingRemainder(dividingBy: 1); px1(jsRound(hash1(Double(i + 9)) * Double(w)), jsRound(-5 + f * Double(h + 8)), 1, 1, ["#ff4fa3", "#ffd23c", "#3cb0ff", "#7be36b"][i % 4]) }
        }
    }
}

// ======================================================= the bird reacts to the weather
// clear and sunny: sunglasses. Rain or a storm: a little umbrella. Snow: snow on its head, and it shivers.
let UMBRELLA = ["......OOOO......", "....OOrrwwOO....", "..OOrrrwwwrrOO..", ".OrrrrwwwwrrrrO.", "OOOOOOOOOOOOOOOO", ".......O........", ".......O........", ".......O........", ".......O........"]
var WX_FORCE = ""   // (Developer page)
func wxReaction() -> String {
    if !birdExtrasOK() || gameMode == "night" || sleepingNow() { return "" }
    let w = !WX_FORCE.isEmpty ? WX_FORCE : (weatherOn() ? WX.weather : "")
    if w == "clear" && !skyIsNight { return "sun" }
    if w == "rain" || w == "storm" { return "rain" }
    if w == "snow" { return "snow" }
    return ""
}
func drawWeatherReaction() {
    let r = wxReaction(); if r.isEmpty { return }
    onBird { im, w, h, ox, oy in
        if r == "sun" {   // sunglasses over the eye
            guard let e = birdEye(im) else { return }
            for (x, y) in e.cells { px1(ox + x * 2, oy + y * 2, 2, 2, "#16141c") }
            px1(ox + e.left * 2 - 2, oy + e.top * 2 + 1, 2, 1, "#16141c")                          // the arm
            px1(ox + (e.left + 1) * 2, oy + e.top * 2 + 1, 1, 1, "#ffffff"); px1(ox + (e.left + 1) * 2 + 1, oy + e.top * 2 + 2, 1, 1, "#9aa0b0")   // a glint
        } else if r == "rain" {   // an umbrella held over its head
            let cx = ox + 16, top = oy + 1 - UMBRELLA.count * 2   // (in the bird's big pixels; the handle reaches its head)
            for (j, row) in UMBRELLA.enumerated() { for (i, ch) in row.enumerated() where ch != "." { px1(cx - 16 + i * 2, top + j * 2, 2, 2, ch == "O" ? "#533846" : ch == "r" ? "#e8281e" : "#ffffff") } }
        } else if r == "snow" {   // snow piled on its head
            let P = pixData(im)
            var x = ox + 10
            while x < ox + 28 && x < w {
                var top = -1
                for y in 0..<h where P.d[(y * P.w + x) * 4 + 3] > 40 { top = y; break }
                if top >= 0 { let lump = hash1(Double(x)) > 0.5 ? 2 : 1; px1(x, top - lump, 1, lump, "#ffffff") }
                x += 1
            }
        }
    }
    if r == "snow" && Int(floor(sceneTime * 12)) % 2 == 1 {   // shivering
        let by = bird.y; ctx.fill("rgba(200,230,255,0.9)")
        ctx.fillRect(jsRound(bird.x - 34), jsRound(by + 2), 6, 2); ctx.fillRect(jsRound(bird.x - 32), jsRound(by - 6), 4, 2)
        ctx.fillRect(jsRound(bird.x + 28), jsRound(by + 4), 6, 2); ctx.fillRect(jsRound(bird.x + 30), jsRound(by - 4), 4, 2)
    }
}

// ======================================================= hook (before the STOP button)
func drawV163Overlay() { drawLogoSeason(); drawWeatherReaction(); drawSleep() }
