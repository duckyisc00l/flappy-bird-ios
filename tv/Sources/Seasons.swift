import SpriteKit

/// Seasons from the web game: Halloween, Christmas, winter, spring, summer, fall, Valentine's and New Year.
/// "Auto" picks by date like the phone does. Same pixel art (exported from the game, 1 art pixel = 3 points),
/// same places: things on the ground, on the pipes, visitors in the sky, and snow / leaves / petals falling.
enum Seasons {
    static let all: [(id: String, title: String)] = [("auto", "Auto (by date)"), ("classic", "Classic"), ("halloween", "Halloween"), ("christmas", "Christmas"),
        ("winter", "Winter"), ("spring", "Spring"), ("summer", "Summer"), ("fall", "Fall"), ("valentine", "Valentine's"), ("newyear", "New Year")]
    static func byDate(_ d: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: d), m = c.month ?? 1, day = c.day ?? 1
        if (m == 12 && day == 31) || (m == 1 && day == 1) { return "newyear" }
        if m == 2 && day >= 7 && day <= 14 { return "valentine" }
        if m == 10 && day >= 15 { return "halloween" }
        if m == 12 { return "christmas" }
        if m <= 2 { return "winter" }
        if m <= 5 { return "spring" }
        if m <= 8 { return "summer" }
        return "fall"
    }
    static var current: String { Prefs.season == "auto" ? byDate() : Prefs.season }
    static func title(_ id: String) -> String { all.first { $0.id == id }?.title ?? "Auto" }

    private static var cache: [String: SKTexture] = [:]
    static func tex(_ name: String) -> SKTexture? {
        if let t = cache[name] { return t }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "season"),
              let im = UIImage(contentsOfFile: url.path) else { return nil }
        let t = SKTexture(image: im); t.filteringMode = .nearest
        cache[name] = t; return t
    }
}

/// What a scene tells the season layer every frame.
struct SeasonPipe { let x: CGFloat, top: CGFloat, bottom: CGFloat, k: Int }

final class SeasonLayer {
    let sky = SKNode(), onPipes = SKNode(), onGround = SKNode(), front = SKNode()
    private(set) var season = "classic"
    private var t: Double = 0, par: CGFloat = 0
    private var pools: [ObjectIdentifier: (nodes: [SKSpriteNode], used: Int)] = [:]
    private struct Mover { var x, y, t, life, ph, vx, vy: CGFloat; var s: CGFloat = 3; var c = false }
    private var witch: Mover?, sleigh: Mover?, plane: Mover?
    private var ghosts: [Mover] = [], flies: [Mover] = [], gulls: [Mover] = [], hearts: [Mover] = [], falling: [Mover] = []
    private var nextWitch: CGFloat = 6, nextGhost: CGFloat = 2, nextSleigh: CGFloat = 8, nextGull: CGFloat = 3, nextHeart: CGFloat = 1.5, nextPlane: CGFloat = 5
    private let banner = SKLabelNode(fontNamed: "KongtextRegular")
    private lazy var hill: SKTexture = makeHill()
    private lazy var moon: SKTexture = makeMoon()

    init() {
        sky.zPosition = -2.9; onPipes.zPosition = -1.9; onGround.zPosition = 0.5; front.zPosition = 4
        banner.fontSize = 12; banner.fontColor = UIColor(red: 0.33, green: 0.22, blue: 0.27, alpha: 1); banner.verticalAlignmentMode = .center; banner.horizontalAlignmentMode = .left
        banner.zPosition = 1; sky.addChild(banner)
    }
    func add(to parent: SKNode) { for n in [sky, onPipes, onGround, front] { parent.addChild(n) } }
    func set(_ s: String) {
        season = s
        witch = nil; sleigh = nil; plane = nil; ghosts = []; flies = []; gulls = []; hearts = []; falling = []
    }
    /// Halloween is always at night
    var wantsNight: Bool { season == "halloween" }

    // MARK: drawing helpers (sprites are reused every frame)
    private func put(_ layer: SKNode, _ name: String, _ x: CGFloat, _ y: CGFloat, sx: CGFloat = 3, sy: CGFloat = 3, rot: CGFloat = 0, alpha: CGFloat = 1) {
        guard let tex = Seasons.tex(name) else { return }
        let n = node(layer); n.texture = tex; n.size = tex.size(); n.xScale = sx; n.yScale = sy
        n.position = CGPoint(x: x.rounded(), y: y.rounded()); n.zRotation = rot; n.alpha = alpha
    }
    private func rect(_ layer: SKNode, _ c: UIColor, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        let n = node(layer); n.texture = nil; n.color = c; n.colorBlendFactor = 1; n.size = CGSize(width: w, height: h)
        n.xScale = 1; n.yScale = 1; n.position = CGPoint(x: x + w / 2, y: y + h / 2); n.zRotation = 0; n.alpha = 1
    }
    private func node(_ layer: SKNode) -> SKSpriteNode {
        let k = ObjectIdentifier(layer)
        var p = pools[k] ?? ([], 0)
        let n: SKSpriteNode
        if p.used < p.nodes.count { n = p.nodes[p.used] } else { n = SKSpriteNode(); layer.addChild(n); p.nodes.append(n) }
        p.used += 1; pools[k] = p
        n.isHidden = false; n.colorBlendFactor = 0
        return n
    }
    private func beginFrame() { for k in pools.keys { pools[k]!.used = 0 } }
    private func endFrame() { for (_, p) in pools { for i in p.used..<p.nodes.count { p.nodes[i].isHidden = true } } }

    // MARK: every frame
    func update(_ dt: Double, scroll: CGFloat, groundX: CGFloat, pipes: [SeasonPipe], visL: CGFloat = 0, visR: CGFloat = 1024, groundTop: CGFloat = 224) {
        t += dt
        let f = CGFloat(dt), s = season
        par -= scroll
        beginFrame()
        banner.isHidden = true
        guard s != "classic" else { endFrame(); return }
        let rnd = { (a: CGFloat, b: CGFloat) -> CGFloat in a + CGFloat.random(in: 0...1) * (b - a) }
        let speed = f > 0 ? scroll / f : 0
        // ---- sky visitors ----
        if s == "halloween" {
            put(sky, "glowOrange", 830, 640, sx: 3, sy: 3, alpha: 0.35)
            let mt = moon; let m = node(sky); m.texture = mt; m.size = mt.size(); m.setScale(3); m.position = CGPoint(x: 830, y: 640); m.alpha = 1
            let span: CGFloat = 1400
            var x0 = (visL + 260 + par * 0.25).truncatingRemainder(dividingBy: span); if x0 < 0 { x0 += span }; x0 += visL - 200
            var x = x0
            while x < visR + 200 {
                let h = node(sky); h.texture = hill; h.size = hill.size(); h.setScale(1); h.position = CGPoint(x: x, y: groundTop + hill.size().height / 2); h.alpha = 1; h.zRotation = 0
                let lit = sin(t * 7.3 + sin(t * 2.1) * 3) > -0.6
                put(sky, lit ? "house" : "houseDim", x, groundTop + 62 + 27 - 3)
                if lit { put(sky, "glowOrange", x, groundTop + 85, sx: 1.9, sy: 1.4, alpha: 0.35) }
                put(sky, "deadTree", x - 120, groundTop + 26 + 19)
                put(sky, "deadTree", x + 140, groundTop + 18 + 19, sx: -3)
                x += span
            }
            nextWitch -= f
            if witch == nil && nextWitch <= 0 { nextWitch = 14 + rnd(0, 10); witch = Mover(x: visR + 60, y: 630 + rnd(0, 30), t: 0, life: 0, ph: 0, vx: 0, vy: 0) }
            if var w = witch { w.t += f; w.x -= (70 + speed * 0.08) * f; w.y += sin(w.t * 0.8) * 10 * f; witch = w.x < visL - 80 ? nil : w
                put(sky, "witch", w.x, w.y + sin(w.t * 3) * 8, sx: -3, rot: sin(w.t * 3) * 0.06) }
            nextGhost -= f
            if nextGhost <= 0 && ghosts.count < 3 { nextGhost = 3 + rnd(0, 4); ghosts.append(Mover(x: rnd(visL + 60, visR + 60), y: rnd(380, 700), t: 0, life: 6 + rnd(0, 4), ph: rnd(0, 6), vx: rnd(-40, -10), vy: 0, s: rnd(2, 3.5))) }
            for i in ghosts.indices { ghosts[i].t += f; ghosts[i].x += (ghosts[i].vx - speed * 0.06) * f }
            ghosts.removeAll { $0.t >= $0.life }
            for g in ghosts { put(sky, "ghostW", g.x, g.y + sin(g.t * 2 + g.ph) * 10, sx: g.s, sy: g.s, rot: sin(g.t * 1.5 + g.ph) * 0.12, alpha: min(1, g.t / 1.2, (g.life - g.t) / 1.2) * 0.75) }
        }
        if s == "christmas" {
            nextSleigh -= f
            if sleigh == nil && nextSleigh <= 0 { nextSleigh = 16 + rnd(0, 10); sleigh = Mover(x: visR + 100, y: 660 + rnd(0, 40), t: 0, life: 0, ph: 0, vx: 0, vy: 0) }
            if var sl = sleigh { sl.t += f; sl.x -= (80 + speed * 0.08) * f; sleigh = sl.x < visL - 160 ? nil : sl; put(sky, "sleigh", sl.x, sl.y + sin(sl.t * 2) * 6, sx: -3) }
        }
        if s == "spring" {
            while flies.count < 5 { flies.append(Mover(x: rnd(visL, visR + 200), y: rnd(260, 520), t: 0, life: 0, ph: rnd(0, 6), vx: rnd(-30, 20), vy: 0, c: Bool.random())) }
            for i in flies.indices { flies[i].t += f; flies[i].vy = max(-30, min(30, flies[i].vy + rnd(-60, 60) * f)); flies[i].x += (flies[i].vx - speed * 0.6) * f; flies[i].y = max(250, min(560, flies[i].y + flies[i].vy * f)) }
            flies.removeAll { $0.x < visL - 30 }
            for b in flies { let up = Int(b.t * 9 + b.ph) % 2 == 1; put(sky, b.c ? (up ? "flyB1" : "flyB2") : (up ? "fly1" : "fly2"), b.x, b.y) }
        }
        if s == "summer" {
            nextGull -= f
            if nextGull <= 0 { nextGull = 4 + rnd(0, 5); let n = 1 + Int.random(in: 0..<3), y0 = rnd(520, 700); for i in 0..<n { gulls.append(Mover(x: visR + 30 + CGFloat(i) * 26, y: y0 + CGFloat(i) * 12, t: 0, life: 0, ph: rnd(0, 6), vx: 0, vy: 0)) } }
            for i in gulls.indices { gulls[i].t += f; gulls[i].x -= (35 + speed * 0.08) * f }
            gulls.removeAll { $0.x < visL - 30 }
            for g in gulls { put(sky, Int(g.t * 4 + g.ph) % 2 == 1 ? "gull1" : "gull2", g.x, g.y + sin(g.t + g.ph) * 6) }
        }
        if s == "valentine" {
            nextHeart -= f
            if nextHeart <= 0 && hearts.count < 6 { nextHeart = 2 + rnd(0, 3); hearts.append(Mover(x: rnd(visL + 30, visR + 100), y: 240, t: 0, life: 0, ph: rnd(0, 6), vx: 0, vy: 0)) }
            for i in hearts.indices { hearts[i].t += f; hearts[i].y += 28 * f; hearts[i].x -= speed * 0.2 * f }
            hearts.removeAll { $0.y > 808 }
            for h in hearts { put(sky, "heartBal", h.x + sin(h.t * 1.3 + h.ph) * 10, h.y, rot: sin(h.t * 1.3 + h.ph) * 0.1) }
        }
        if s == "newyear" {
            nextPlane -= f
            if plane == nil && nextPlane <= 0 { nextPlane = 18 + rnd(0, 8); plane = Mover(x: visR + 40, y: 640, t: 0, life: 0, ph: 0, vx: 0, vy: 0) }
            if var p = plane {
                p.t += f; p.x -= 70 * f; plane = p.x < visL - 520 ? nil : p
                let yr = Calendar.current.component(.month, from: Date()) == 12 ? Calendar.current.component(.year, from: Date()) + 1 : Calendar.current.component(.year, from: Date())
                banner.text = "HAPPY NEW YEAR \(yr)"; banner.isHidden = false
                let by = p.y + sin(p.t * 2) * 4, bx = p.x + 40, tw = banner.frame.width + 24
                rect(sky, UIColor(red: 0.81, green: 0.78, blue: 0.85, alpha: 1), p.x + 18, by + 2, 24, 2)
                rect(sky, UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1), bx, by - 10, tw, 24)
                rect(sky, UIColor(red: 0.91, green: 0.16, blue: 0.12, alpha: 1), bx, by - 12, tw, 3); rect(sky, UIColor(red: 0.91, green: 0.16, blue: 0.12, alpha: 1), bx, by + 13, tw, 3)
                banner.position = CGPoint(x: bx + 12, y: by + 2)
                put(sky, "plane", p.x, by, sx: -3)
            }
        }
        // ---- on the pipes ----
        let snowy = s == "winter" || s == "christmas"
        for p in pipes {
            let x = p.x, top = p.top, bot = p.bottom, k = p.k
            if snowy {
                rect(onPipes, UIColor(red: 0.96, green: 0.97, blue: 1, alpha: 1), x - 33, top, 66, 6)
                for j in 0..<5 { let ix = x - 26 + CGFloat(j) * 12, len = CGFloat(3 + (k * 7 + j * 3) % 5); rect(onPipes, UIColor(red: 0.85, green: 0.93, blue: 1, alpha: 1), ix, bot - 2 - len * 2, 3, len * 2) }
            }
            switch s {
            case "halloween":
                put(onPipes, "web", x - 22, bot - 9, sx: 2, sy: 2)
                if k % 2 == 0 { let fl = 0.6 + 0.4 * sin(t * 9 + Double(k) * 2) * sin(t * 5.3 + Double(k)); put(onPipes, "glowOrange", x, top + 15, sx: 0.95, sy: 0.8, alpha: CGFloat(0.35 + 0.35 * fl)); put(onPipes, "jack", x + (k % 4 == 0 ? -12 : 12), top + 13.5) }
                else { put(onPipes, "candyCorn", x + 16, top + 6) }
                if k % 3 == 1 { put(onPipes, "hangBat", x - 14, bot - 9, rot: sin(t * 1.6 + Double(k)) * 0.12) }
                if k % 3 == 0 { let sy = bot - 34 - 12 * sin(t * 1.8 + Double(k)); rect(onPipes, UIColor(white: 0.92, alpha: 0.8), x + 12, sy, 1, bot - sy); put(onPipes, "spider", x + 12.5, sy - 4, sx: 2, sy: 2) }
            case "christmas":
                if k % 2 == 1 { put(onPipes, "wreath", x, top - 40) }
                let C: [UIColor] = [UIColor(red: 1, green: 0.23, blue: 0.23, alpha: 1), UIColor(red: 1, green: 0.82, blue: 0.23, alpha: 1), UIColor(red: 0.23, green: 0.69, blue: 1, alpha: 1)]
                for j in 0..<3 { let ox = x - 22 + CGFloat(j) * 22, len = CGFloat(10 + ((k * 7 + j * 5) % 4) * 6); rect(onPipes, UIColor(white: 0.8, alpha: 1), ox, bot - len, 2, len); rect(onPipes, C[(j + k) % 3], ox - 4, bot - len - 9, 10, 10) }
                for i in 0..<7 { let on = (Int(t * 2.5) + i + k) % 3 != 0; rect(onPipes, on ? C[(i + k) % 3] : UIColor(white: 0.33, alpha: 1), x - 27 + CGFloat(i) * 9, top + 6, 4, 4) }
            case "winter": if k % 3 == 0 { put(onPipes, "snowman", x + 10, top + 21, sx: 2, sy: 2) }
            case "spring": put(onPipes, k % 2 == 1 ? "flowerP" : "flowerW", x - 18, top + 7.5); put(onPipes, k % 2 == 1 ? "flowerY" : "flowerV", x + 16, top + 7.5)
            case "summer": if k % 3 == 1 { put(onPipes, "beachball", x + 14, top + 7.5) }
            case "fall":
                put(onPipes, "leafRest", x - 14 + CGFloat(k % 3) * 6, top + 3)
                if k % 2 == 0 { put(onPipes, "crow", x - 10, top + 7.5, sx: k % 4 == 0 ? 3 : -3) }
                if k % 3 == 1 { put(onPipes, "gourd", x + 16, top + 7.5) }
            case "valentine": for j in 0..<5 { let hx = x - 26 + CGFloat(j) * 13, hy = bot - 10 - (sin(Double(j) / 4 * .pi) * 6).rounded(); rect(onPipes, UIColor(white: 0.9, alpha: 1), hx, hy + 6, 13, 1); put(onPipes, "miniHeart", hx + 1, hy) }
            case "newyear": if k % 2 == 1 { put(onPipes, "partyHat", x - 8, top + 10.5) }
            default: break
            }
        }
        // ---- on the ground (each pair of land tiles, like the phone) ----
        let landW: CGFloat = 672
        for i in 0..<4 {
            let left = groundX + CGFloat(i) * (landW - 1) - 336
            func at(_ n: String, _ off: CGFloat, _ sc: CGFloat = 3, flip: Bool = false) { if let tx = Seasons.tex(n) { put(onGround, n, left + off, groundTop + tx.size().height * sc / 2 - 2, sx: flip ? -sc : sc, sy: sc) } }
            switch s {
            case "halloween":
                at("pumpkin", 70); at("tomb", 185); at("pumpkin", 300); at("pumpkin", 505); at("tomb", 610)
                at("fence", 120); at("fence", 545); at("hand", 255); at("candyCorn", 345); at("candyCorn", 470)
                for o: CGFloat in [70, 300, 505] { put(onGround, "glowOrange", left + o, groundTop + 14, sx: 0.8, sy: 0.7, alpha: CGFloat(0.45 + 0.25 * sin(t * 7 + Double(o)))) }
                rect(onGround, UIColor(red: 0.47, green: 0.24, blue: 0.59, alpha: 0.16), left, groundTop, landW, 22)
            case "christmas":
                at("present1", 175); at("present2", 200); at("present3", 500); at("present1", 520); at("snowman", 330); at("cane", 60); at("cane", 610, flip: true)
                let fr = Int(t * 2) % 2; at(fr == 1 ? "tree1" : "tree2", 140); at(fr == 1 ? "tree2" : "tree1", 470)
                let C: [UIColor] = [UIColor(red: 1, green: 0.23, blue: 0.23, alpha: 1), UIColor(red: 0.23, green: 1, blue: 0.42, alpha: 1), UIColor(red: 1, green: 0.82, blue: 0.23, alpha: 1), UIColor(red: 0.23, green: 0.69, blue: 1, alpha: 1)]
                for j in 0..<24 { let on = (Int(t * 3) + j) % 4 != 0; rect(onGround, on ? C[j % 4] : UIColor(white: 0.3, alpha: 1), left + CGFloat(j) * 28, groundTop + 4 + CGFloat(j % 2) * 3, 4, 4) }
            case "winter": at("pine", 90); at("pine", 130); at("snowman", 300); at("pine", 470); at("pine", 620)
            case "spring":
                let F = ["flowerP", "flowerY", "flowerW", "flowerV"]
                for (j, o) in [20, 55, 110, 160, 205, 260, 330, 380, 430, 470, 540, 590, 640].enumerated() { at(F[j % 4], CGFloat(o)) }
                at("blossom", 300); at("tulipR", 230); at("tulipY", 400); at("tulipR", 575)
                let hop = abs(sin(t * 3 + Double(i))); if let b = Seasons.tex(hop > 0.5 ? "bunny2" : "bunny1") { put(onGround, hop > 0.5 ? "bunny2" : "bunny1", left + 500 + CGFloat(sin(t * 0.5 + Double(i))) * 40, groundTop + 10 + CGFloat(hop) * 12); _ = b }
            case "summer": at("sunflower", 90); at("sunflower", 380); at("sunflower", 560); at("umbrella", 230); at("sandcastle", 470); at("beachball", 310)
            case "fall": for o: CGFloat in [60, 250, 420, 600] { at("leafpile", o) }; at("scarecrow", 330); at("hay", 150); at("hay", 180); at("gourd", 520); at("gourd", 545)
            case "valentine": at("roses", 120); at("roses", 360); at("roses", 590)
            case "newyear": at("balloonNY", 140); at("balloonNY", 420); at("balloonNY", 640)
            default: break
            }
            if snowy { put(onGround, "snowStrip", left + 336, groundTop + 2, sx: 2, sy: 2) }
        }
        // ---- falling: snow, leaves, petals, confetti ----
        let want: Int = snowy ? 90 : s == "fall" ? 22 : s == "spring" ? 18 : s == "newyear" ? 40 : s == "valentine" ? 12 : 0
        while falling.count < want { falling.append(Mover(x: rnd(visL - 40, visR + 80), y: rnd(320, 820), t: 0, life: 0, ph: rnd(0, 6), vx: rnd(-20, 10), vy: snowy ? rnd(-70, -35) : rnd(-50, -25), s: snowy ? rnd(2, 5) : 3, c: Bool.random())) }
        if falling.count > want { falling.removeLast(falling.count - want) }
        let colors: [UIColor] = s == "fall" ? [UIColor(red: 0.85, green: 0.35, blue: 0.1, alpha: 1), UIColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1), UIColor(red: 0.7, green: 0.2, blue: 0.1, alpha: 1)]
            : s == "spring" ? [UIColor(red: 1, green: 0.76, blue: 0.85, alpha: 1), UIColor(red: 1, green: 0.9, blue: 0.95, alpha: 1)]
            : s == "newyear" ? [UIColor(red: 1, green: 0.23, blue: 0.23, alpha: 1), UIColor(red: 1, green: 0.82, blue: 0.23, alpha: 1), UIColor(red: 0.23, green: 0.69, blue: 1, alpha: 1), UIColor(red: 1, green: 0.42, blue: 0.94, alpha: 1)]
            : s == "valentine" ? [UIColor(red: 1, green: 0.36, blue: 0.54, alpha: 1)] : [UIColor(red: 0.96, green: 0.97, blue: 1, alpha: 1)]
        for i in falling.indices {
            falling[i].t += f
            falling[i].x += (falling[i].vx + sin(falling[i].t * 2 + falling[i].ph) * 18 - speed * 0.3) * f
            falling[i].y += falling[i].vy * f
            if falling[i].y < groundTop - 10 || falling[i].x < visL - 60 { falling[i].y = rnd(780, 840); falling[i].x = rnd(visL, visR + 120) }
            let p = falling[i]
            let n = node(front); n.texture = nil; n.color = colors[Int(p.ph * 10) % colors.count]; n.colorBlendFactor = 1
            n.size = CGSize(width: p.s, height: p.s); n.xScale = 1; n.yScale = 1; n.alpha = snowy ? 0.9 : 1
            n.position = CGPoint(x: p.x.rounded(), y: p.y.rounded()); n.zRotation = s == "fall" || s == "newyear" ? CGFloat(p.t * 3 + p.ph) : 0
        }
        endFrame()
    }

    // MARK: art made here
    private func makeHill() -> SKTexture {
        let w = 384, h = 70, cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(UIColor(red: 0.11, green: 0.063, blue: 0.157, alpha: 1).cgColor)
        var i = -190
        while i <= 190 { let c = cos(Double(i) / 190 * .pi / 2), hh = ((4 + 62 * c * c) / 3).rounded() * 3; ctx.fill(CGRect(x: i + 190, y: 0, width: 3, height: Int(hh))); i += 3 }
        let t = SKTexture(cgImage: ctx.makeImage()!); t.filteringMode = .nearest; return t
    }
    private func makeMoon() -> SKTexture {
        let r = 14, cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: r * 2, height: r * 2, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for y in 0..<(r * 2) { for x in 0..<(r * 2) {
            let dx = Double(x - r) + 0.5, dy = Double(y - r) + 0.5
            guard dx * dx + dy * dy <= Double(r * r) else { continue }
            let crater = (dx - 4) * (dx - 4) + (dy - 3) * (dy - 3) < 9 || (dx + 5) * (dx + 5) + (dy + 4) * (dy + 4) < 6 || (dx + 2) * (dx + 2) + (dy - 7) * (dy - 7) < 4
            ctx.setFillColor((crater ? UIColor(red: 0.78, green: 0.42, blue: 0.2, alpha: 1) : UIColor(red: 0.91, green: 0.55, blue: 0.29, alpha: 1)).cgColor)
            ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        } }
        let t = SKTexture(cgImage: ctx.makeImage()!); t.filteringMode = .nearest; return t
    }
}
