import SpriteKit

/// The 100 trails & effects from the web game, read from trails.json (exported from the game itself) and run here
/// with the same rules: P particles, R ribbons, O orbiting shapes, A glows / rings, H halos. All pixel style.
struct TrailLayer {
    let type: String
    let d: [String: Any]
    func n(_ k: String, _ def: Double = 0) -> Double { (d[k] as? NSNumber)?.doubleValue ?? def }
    /// a number or a [min, max] range (picked at random)
    func r(_ k: String, _ def: Double = 0) -> Double {
        if let a = d[k] as? [NSNumber], a.count == 2 { return a[0].doubleValue + Double.random(in: 0...1) * (a[1].doubleValue - a[0].doubleValue) }
        return n(k, def)
    }
    func cols(_ k: String = "cols") -> [String] { d[k] as? [String] ?? [] }
    var shape: String { d["shape"] as? String ?? "sq" }
}
struct TrailDef { let id: String, name: String, cat: String, layers: [TrailLayer] }

final class Trails {
    static let shared = Trails()
    private(set) var all: [TrailDef] = []
    private(set) var categories: [String] = []
    private var shapes: [String: [String]] = [:], pal: [String: String] = [:]
    private var texCache: [String: SKTexture] = [:]
    private var imgCache: [String: UIImage] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "trails", withExtension: "json", subdirectory: "birds"),
              let data = try? Data(contentsOf: url), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        shapes = obj["shapes"] as? [String: [String]] ?? [:]
        pal = obj["pal"] as? [String: String] ?? [:]
        for t in obj["trails"] as? [[String: Any]] ?? [] {
            let layers = (t["layers"] as? [[String: Any]] ?? []).map { TrailLayer(type: $0["type"] as? String ?? "p", d: $0) }
            let def = TrailDef(id: t["id"] as? String ?? "", name: t["name"] as? String ?? "", cat: t["cat"] as? String ?? "", layers: layers)
            all.append(def)
            if !categories.contains(def.cat) { categories.append(def.cat) }
        }
    }
    func def(_ id: String) -> TrailDef? { all.first { $0.id == id } }

    // MARK: colours: "#rrggbb" or "rgba(r,g,b,a)"
    static func color(_ s: String) -> UIColor {
        if s.hasPrefix("#"), s.count >= 7, let v = UInt32(s.dropFirst().prefix(6), radix: 16) {
            return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
        }
        if s.hasPrefix("rgba(") {
            let p = s.dropFirst(5).dropLast().split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            if p.count == 4 { return UIColor(red: p[0] / 255, green: p[1] / 255, blue: p[2] / 255, alpha: p[3]) }
        }
        return .white
    }

    // MARK: a pixel shape as a texture ('#' main colour, 'o' second colour, letters = fixed colours)
    func shapeImage(_ shape: String, _ c1: String, _ c2: String?) -> CGImage? {
        let rows = shapes[shape] ?? shapes["sq"] ?? ["#"]
        let w = rows.map { $0.count }.max() ?? 1, h = rows.count
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch != "." {
                let c = ch == "#" ? c1 : ch == "o" ? (c2 ?? c1) : (pal[String(ch)] ?? c1)
                ctx.setFillColor(Trails.color(c).cgColor)
                ctx.fill(CGRect(x: x, y: h - 1 - y, width: 1, height: 1))
            }
        }
        return ctx.makeImage()
    }
    func texture(_ shape: String, _ c1: String, _ c2: String? = nil) -> SKTexture {
        let key = shape + "|" + c1 + "|" + (c2 ?? "")
        if let t = texCache[key] { return t }
        let t = shapeImage(shape, c1, c2).map { SKTexture(cgImage: $0) } ?? SKTexture()
        t.filteringMode = .nearest
        texCache[key] = t
        return t
    }
    /// a round soft glow (or a ring) in one colour, for the A layers
    func glowTexture(_ col: String, ring: Bool) -> SKTexture {
        let key = "glow|" + col + (ring ? "|r" : "")
        if let t = texCache[key] { return t }
        let px = 128, cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let c = Trails.color(col), clear = c.withAlphaComponent(0)
        let colors = (ring ? [clear.cgColor, c.cgColor, clear.cgColor] : [c.cgColor, clear.cgColor]) as CFArray
        let g = CGGradient(colorsSpace: cs, colors: colors, locations: ring ? [0.55, 0.85, 1] : [0, 1])!
        let m = CGPoint(x: px / 2, y: px / 2)
        ctx.drawRadialGradient(g, startCenter: m, startRadius: 0, endCenter: m, endRadius: CGFloat(px) / 2, options: [])
        let t = SKTexture(cgImage: ctx.makeImage()!)
        texCache[key] = t
        return t
    }
    /// a small picture of a trail for menus: a few of its shapes / colours
    func icon(_ def: TrailDef) -> UIImage? {
        if let i = imgCache[def.id] { return i }
        let size = CGSize(width: 140, height: 100)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let im = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let g = ctx.cgContext; g.interpolationQuality = .none
            var x: CGFloat = 8
            for l in def.layers {
                switch l.type {
                case "r":
                    for (j, c) in (l.d["bands"] as? [String] ?? []).enumerated() { Trails.color(c).setFill(); g.fill(CGRect(x: 6, y: 30 + CGFloat(j) * 8, width: 128, height: 8)) }
                case "a":
                    Trails.color(l.d["col"] as? String ?? "#ffffff").withAlphaComponent(0.6).setFill(); g.fillEllipse(in: CGRect(x: 30, y: 10, width: 80, height: 80))
                case "h":
                    Trails.color(l.d["col"] as? String ?? "#ffe060").setStroke(); g.setLineWidth(6); g.strokeEllipse(in: CGRect(x: 40, y: 20, width: 60, height: 22))
                default:
                    for (i, c) in l.cols().prefix(3).enumerated() {
                        if let img = shapeImage(l.shape, c, l.cols("c2").first) {
                            let s: CGFloat = 6, w = CGFloat(img.width) * s, h = CGFloat(img.height) * s
                            let r = CGRect(x: x, y: 20 + CGFloat(i % 2) * 34, width: w, height: h)
                            g.saveGState(); g.translateBy(x: 0, y: size.height); g.scaleBy(x: 1, y: -1)
                            g.draw(img, in: CGRect(x: r.minX, y: size.height - r.maxY, width: w, height: h)); g.restoreGState()
                            x += w + 8; if x > 110 { x = 8 }
                        }
                    }
                }
            }
        }
        imgCache[def.id] = im
        return im
    }
}

/// One running trail behind (and in front of) a bird. Add `back` under the bird and `front` over it.
final class TrailRunner {
    let back = SKNode(), front = SKNode()
    private(set) var def: TrailDef?
    private struct Part { let node: SKSpriteNode, glow: SKSpriteNode?; let l: TrailLayer; var x, y, vx, vy, life, max, s, r, vr, ph: Double }
    private var parts: [Part] = []
    private var ribs: [(x: Double, y: Double, t: Double)] = []
    private var acc: [Int: Double] = [:]
    private var t: Double = 0, ribT: Double = 0
    private var extras: [SKSpriteNode] = []   // glows, halos, orbiters, ribbon pieces (redrawn each frame)
    private var pool: [SKSpriteNode] = []
    private var used = 0

    func set(_ id: String?) {
        def = id.flatMap { Trails.shared.def($0) }
        parts.forEach { $0.node.removeFromParent(); $0.glow?.removeFromParent() }; parts = []; ribs = []; acc = [:]
    }

    private func spawn(_ l: TrailLayer, _ bx: Double, _ by: Double, burst: Bool) {
        guard parts.count < 320 else { return }
        let cols = l.cols(); guard !cols.isEmpty else { return }
        let c = cols.randomElement()!, c2 = l.cols("c2").randomElement()
        let life = l.r("life", 0.7)
        var p = Part(node: SKSpriteNode(texture: Trails.shared.texture(l.shape, c, c2)), glow: nil, l: l, x: bx + l.r("dx", -14), y: by + l.r("dy"),
                     vx: l.r("vx"), vy: l.r("vy"), life: life, max: life, s: l.r("s", 2), r: 0,
                     vr: l.n("spin") != 0 ? (Double.random(in: 0...1) - 0.5) * 2 * l.n("spin") : 0, ph: Double.random(in: 0..<6.3))
        if burst {
            let a = Double.random(in: 0..<(2 * .pi)), v = l.r("fsp", 100)
            p.x = bx + Double.random(in: -4...4); p.y = by + Double.random(in: -4...4); p.vx = cos(a) * v - 30; p.vy = sin(a) * v
        } else if l.n("around") > 0 {
            let a = Double.random(in: 0..<(2 * .pi)), ar = l.n("around")
            p.x = bx + cos(a) * ar; p.y = by + sin(a) * ar * 0.8
            if l.n("inward") > 0 { p.vx = -cos(a) * ar / life; p.vy = -sin(a) * ar * 0.8 / life }
        }
        if l.n("glow") > 0 { let g = SKSpriteNode(texture: p.node.texture); g.alpha = 0.3; p = Part(node: p.node, glow: g, l: p.l, x: p.x, y: p.y, vx: p.vx, vy: p.vy, life: p.life, max: p.max, s: p.s, r: p.r, vr: p.vr, ph: p.ph) }
        let layer = l.n("layer") > 0 ? front : back
        if let g = p.glow { layer.addChild(g) }
        layer.addChild(p.node)
        parts.append(p)
    }

    func flap(_ bx: CGFloat, _ by: CGFloat) { burst("flap", Double(bx), Double(by)) }
    func point(_ bx: CGFloat, _ by: CGFloat) { burst("score", Double(bx), Double(by)) }
    private func burst(_ k: String, _ bx: Double, _ by: Double) {
        guard let d = def else { return }
        for l in d.layers where l.type == "p" { for _ in 0..<Int(l.n(k)) { spawn(l, bx, by, burst: true) } }
    }

    /// every frame: bird position, how far the world moved, and whether new bits should appear
    func step(_ dt: Double, bird: CGPoint, scroll: CGFloat, spawning: Bool) {
        t += dt
        let bx = Double(bird.x), by = Double(bird.y), sc = Double(scroll)
        if let d = def, spawning {
            for (i, l) in d.layers.enumerated() where l.type == "p" && l.n("rate") > 0 {
                acc[i, default: 0] += dt * l.n("rate")
                while acc[i, default: 0] >= 1 { acc[i, default: 0] -= 1; spawn(l, bx, by, burst: false) }
            }
        }
        for i in parts.indices {
            let l = parts[i].l
            parts[i].life -= dt
            if l.n("drag") > 0 { parts[i].vx *= 1 - l.n("drag") * dt; parts[i].vy *= 1 - l.n("drag") * dt }
            parts[i].vy += l.n("g") * dt
            parts[i].x += parts[i].vx * dt - sc + (l.n("wob") > 0 ? sin(t * 5 + parts[i].ph) * l.n("wob") * dt : 0)
            parts[i].y += parts[i].vy * dt
            parts[i].r += parts[i].vr * dt
        }
        parts.removeAll { p in if p.life <= 0 { p.node.removeFromParent(); p.glow?.removeFromParent(); return true }; return false }
        // ribbons
        if let d = def, d.layers.contains(where: { $0.type == "r" }) {
            for i in ribs.indices { ribs[i].x -= sc }
            ribT += dt
            if spawning { while ribT >= 1.0 / 60 { ribT -= 1.0 / 60; ribs.append((bx - 8, by, t)) } } else { ribT = 0; if !ribs.isEmpty { ribs.removeFirst() } }
            let maxLen = Int(d.layers.filter { $0.type == "r" }.map { $0.n("len", 26) }.max() ?? 26)
            while ribs.count > maxLen { ribs.removeFirst() }
        } else { ribs = [] }
        draw(bx, by)
    }

    private func piece(_ layer: SKNode) -> SKSpriteNode {
        let n: SKSpriteNode
        if used < pool.count { n = pool[used] } else { n = SKSpriteNode(); pool.append(n) }
        used += 1
        if n.parent !== layer { n.removeFromParent(); layer.addChild(n) }
        n.isHidden = false; n.alpha = 1; n.zRotation = 0; n.colorBlendFactor = 0; n.texture = nil; n.xScale = 1; n.yScale = 1
        return n
    }

    private func draw(_ bx: Double, _ by: Double) {
        used = 0
        for p in parts {
            let l = p.l, k = p.life / p.max
            var a = l.n("fade", 1) > 0 ? min(1, k * 2) : 1
            if l.n("twinkle") > 0 { a *= 0.55 + 0.45 * sin(t * 18 + p.ph) }
            var s = p.s
            if l.n("shrink") > 0 { s *= 0.35 + 0.65 * k }
            if l.n("grow") > 0 { s *= 1 + (1 - k) * 0.8 }
            p.node.position = CGPoint(x: p.x.rounded(), y: p.y.rounded()); p.node.zRotation = CGFloat(p.r)
            p.node.setScale(CGFloat(s * 2)); p.node.alpha = CGFloat(max(0, a))
            if let g = p.glow { g.position = p.node.position; g.setScale(CGFloat(s * 3.4)); g.alpha = CGFloat(a * 0.3) }
        }
        guard let d = def else { hideRest(); return }
        for l in d.layers {
            switch l.type {
            case "a":
                let r = l.n("r", 30) * (1 + sin(t * 5) * l.n("pulse", 0.12))
                let n = piece(back); n.texture = Trails.shared.glowTexture(l.d["col"] as? String ?? "#ffffff", ring: l.n("ring") > 0)
                n.size = CGSize(width: r * 2, height: r * 2); n.position = CGPoint(x: bx, y: by)
            case "h":
                let y0 = by + l.n("y", 20) + sin(t * 3) * 1.5, w = l.n("w", 18), h = l.n("h", 5)
                var i = -w / 2
                while i < w / 2 {
                    let e = ((max(0, 1 - pow(2 * i / w, 2))).squareRoot() * h / 2 / 2).rounded() * 2
                    for yy in [y0 + e, y0 - e] {
                        let n = piece(front); n.texture = nil; n.color = Trails.color(l.d["col"] as? String ?? "#ffe060"); n.colorBlendFactor = 1
                        n.size = CGSize(width: 2, height: 2); n.position = CGPoint(x: bx + 2 + i + 1, y: yy + 1)
                    }
                    i += 2
                }
            case "o":
                let cnt = Int(l.n("n", 3)), cols = l.cols()
                for i in 0..<cnt where !cols.isEmpty {
                    let a = t * l.n("sp", 3) + Double(i) * .pi * 2 / Double(cnt), frontSide = sin(a) < 0
                    let n = piece(frontSide ? front : back)
                    let tex = Trails.shared.texture(l.shape, cols[i % cols.count]); n.texture = tex; n.size = tex.size()
                    n.setScale(CGFloat(l.n("s", 2)))
                    n.position = CGPoint(x: (bx + cos(a) * l.n("r", 26)).rounded(), y: (by + sin(a) * l.n("r", 26) * l.n("ry", 0.55) + (l.n("bob") > 0 ? sin(t * 7 + Double(i)) * l.n("bob") : 0)).rounded())
                }
            case "r" where ribs.count > 1:
                let len = Int(l.n("len", 26)), pts = Array(ribs.suffix(len)), cnt = pts.count
                let bands = l.d["bands"] as? [String] ?? [], bw = l.n("w", 2)
                for i in 0..<(cnt - 1) {
                    let q = pts[i], q2 = pts[i + 1], f = Double(i + 1) / Double(cnt)
                    if l.n("dash") > 0 && Int(floor(q.t * 60 / 3)) % 2 == 1 { continue }
                    let alpha = l.n("fade", 1) > 0 ? min(1, f * 1.4) : 1
                    let wv = l.n("wave") > 0 ? sin(q.t * l.n("wsp", 8) - Double(i) * 0.35) * l.n("wave") * (1 - f * 0.5) : 0
                    let wv2 = l.n("wave") > 0 ? sin(q2.t * l.n("wsp", 8) - Double(i + 1) * 0.35) * l.n("wave") * (1 - Double(i + 2) / Double(cnt) * 0.5) : 0
                    let x0 = floor(q.x / 2) * 2, w0 = max(2, ceil((q2.x - q.x) / 2) * 2 + 1)
                    for (j, c) in bands.enumerated() {
                        let off = (Double(bands.count) / 2 - Double(j) - 1) * bw
                        let ya = ((q.y + wv + off) / 2).rounded() * 2, yb = ((q2.y + wv2 + off) / 2).rounded() * 2
                        let lo = min(ya, yb), hi = max(ya, yb)
                        let n = piece(back); n.color = Trails.color(c); n.colorBlendFactor = 1; n.alpha = CGFloat(alpha)
                        n.size = CGSize(width: w0, height: hi - lo + bw); n.position = CGPoint(x: x0 + w0 / 2, y: lo + (hi - lo + bw) / 2)
                    }
                }
            default: break
            }
        }
        hideRest()
    }
    private func hideRest() { for i in used..<pool.count { pool[i].isHidden = true } }
}
