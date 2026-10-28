import CoreGraphics
import CoreText
import SpriteKit
import UIKit

// A Swift copy of the web page's 2D canvas, so the game's drawing code ports line for line.
// Two backends: CGCanvas draws into a picture (menus, score card, generated art), SKCanvas draws the game
// screen with SpriteKit (a pool of sprites rebuilt every frame, in the same order the web page draws).

// MARK: - colours

struct RGBA: Equatable { var r: Double, g: Double, b: Double, a: Double
    static let white = RGBA(r: 1, g: 1, b: 1, a: 1), black = RGBA(r: 0, g: 0, b: 0, a: 1), clear = RGBA(r: 0, g: 0, b: 0, a: 0)
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var ui: UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }
}
private var cssCache: [String: RGBA] = [:]
/// '#rgb', '#rrggbb', 'rgb(...)', 'rgba(...)', a few names
func css(_ s: String) -> RGBA {
    if let c = cssCache[s] { return c }
    var out = RGBA.black
    let t = s.trimmingCharacters(in: .whitespaces).lowercased()
    if t.hasPrefix("#") {
        let h = Array(t.dropFirst())
        func hx(_ c: [Character]) -> Double { Double(Int(String(c), radix: 16) ?? 0) / 255 }
        if h.count == 3 { out = RGBA(r: hx([h[0], h[0]]), g: hx([h[1], h[1]]), b: hx([h[2], h[2]]), a: 1) }
        else if h.count >= 6 { out = RGBA(r: hx([h[0], h[1]]), g: hx([h[2], h[3]]), b: hx([h[4], h[5]]), a: h.count == 8 ? hx([h[6], h[7]]) : 1) }
    } else if t.hasPrefix("rgb") {
        let nums = t.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" }).split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        if nums.count >= 3 { out = RGBA(r: nums[0] / 255, g: nums[1] / 255, b: nums[2] / 255, a: nums.count > 3 ? nums[3] : 1) }
    } else if t == "white" { out = .white } else if t == "transparent" { out = .clear }
    if cssCache.count > 4000 { cssCache.removeAll() }
    cssCache[s] = out
    return out
}

// MARK: - gradients and paints

final class Gradient {
    enum Kind { case linear(x0: Double, y0: Double, x1: Double, y1: Double), radial(x0: Double, y0: Double, r0: Double, x1: Double, y1: Double, r1: Double) }
    let kind: Kind
    var stops: [(Double, RGBA)] = []
    init(_ k: Kind) { kind = k }
    func addColorStop(_ at: Double, _ c: String) { stops.append((at, css(c))) }
    func addColorStop(_ at: Double, _ c: RGBA) { stops.append((at, c)) }
    var cgGradient: CGGradient {
        let cols = stops.map { $0.1.cg } as CFArray
        let locs = stops.map { CGFloat($0.0) }
        return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cols, locations: locs)!
    }
}
enum Paint: ExpressibleByStringLiteral {
    case color(RGBA), gradient(Gradient)
    init(stringLiteral s: String) { self = .color(css(s)) }
    static func s(_ s: String) -> Paint { .color(css(s)) }
}

// MARK: - pictures

/// A picture (the web page's Image / canvas). Lazily gives SpriteKit textures, nearest or smooth.
final class Img {
    let cg: CGImage
    var width: Int { cg.width }
    var height: Int { cg.height }
    init(_ cg: CGImage) { self.cg = cg }
    private var tn: SKTexture?, tl: SKTexture?
    private var subs: [String: SKTexture] = [:]
    func tex(_ smooth: Bool) -> SKTexture {
        if smooth { if let t = tl { return t }; let t = SKTexture(cgImage: cg); t.filteringMode = .linear; tl = t; return t }
        if let t = tn { return t }; let t = SKTexture(cgImage: cg); t.filteringMode = .nearest; tn = t; return t
    }
    /// part of the picture (sx, sy, sw, sh in pixels, y down)
    func sub(_ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ smooth: Bool) -> SKTexture {
        let key = "\(sx),\(sy),\(sw),\(sh),\(smooth)"
        if let t = subs[key] { return t }
        let W = Double(width), H = Double(height)
        let t = SKTexture(rect: CGRect(x: sx / W, y: 1 - (sy + sh) / H, width: sw / W, height: sh / H), in: tex(smooth))
        t.filteringMode = smooth ? .linear : .nearest
        if subs.count > 200 { subs.removeAll() }
        subs[key] = t
        return t
    }
    var ui: UIImage { UIImage(cgImage: cg) }
}

// MARK: - fonts ("400 50px \"04b19\", monospace")

struct FontSpec { let ct: CTFont; let size: Double }
private var fontCache: [String: FontSpec] = [:]
func cssFont(_ s: String) -> FontSpec {
    if let f = fontCache[s] { return f }
    var size = 10.0
    if let r = s.range(of: #"([0-9.]+)px"#, options: .regularExpression) { size = Double(s[r].dropLast(2)) ?? 10 }
    let low = s.lowercased()
    let bold = low.contains("bold") || low.contains("700")
    var name = "KongtextRegular"
    if low.contains("04b19") { name = "04b19" }
    else if low.contains("inside") { name = "inside" }
    else if low.contains("kongtext") { name = "KongtextRegular" }
    else if low.contains("courier") { name = bold ? "Courier-Bold" : "Courier" }
    else if low.contains("system-ui") || low.contains("sans-serif") { name = bold ? ".SFUI-Bold" : ".SFUI-Regular" }
    else if low.contains("monospace") { name = bold ? "Menlo-Bold" : "Menlo-Regular" }
    let ct: CTFont
    if name.hasPrefix(".SFUI") { ct = UIFont.systemFont(ofSize: CGFloat(size), weight: bold ? .bold : .regular) as CTFont }
    else { ct = CTFontCreateWithName(name as CFString, CGFloat(size), nil) }
    let f = FontSpec(ct: ct, size: size)
    fontCache[s] = f
    return f
}
struct TextMetrics { let width: Double; let actualBoundingBoxLeft: Double; let actualBoundingBoxRight: Double; let ascent: Double; let descent: Double }
private func ctLine(_ text: String, _ f: FontSpec) -> CTLine {
    let a = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): f.ct])
    return CTLineCreateWithAttributedString(a)
}
func measure(_ text: String, _ f: FontSpec) -> TextMetrics {
    let line = ctLine(text, f)
    var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
    let w = CTLineGetTypographicBounds(line, &asc, &desc, &lead)
    let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    return TextMetrics(width: w, actualBoundingBoxLeft: ink.isNull ? 0 : -Double(ink.minX), actualBoundingBoxRight: ink.isNull ? 0 : Double(ink.maxX), ascent: Double(asc), descent: Double(desc))
}

// MARK: - the shared canvas state (transform, styles, path)

class Canvas2D {
    struct State {
        var m = CGAffineTransform.identity
        var fill: Paint = .color(.black), stroke: Paint = .color(.black)
        var alpha = 1.0, lineWidth = 1.0, font = "10px sans-serif", align = "start", baseline = "alphabetic"
        var smooth = true, lineCap = "butt", lineJoin = "miter"
    }
    var st = State()
    private var stack: [State] = []
    var fillStyle: Paint { get { st.fill } set { st.fill = newValue } }
    var strokeStyle: Paint { get { st.stroke } set { st.stroke = newValue } }
    var globalAlpha: Double { get { st.alpha } set { st.alpha = max(0, min(1, newValue)) } }
    var lineWidth: Double { get { st.lineWidth } set { st.lineWidth = newValue } }
    var font: String { get { st.font } set { st.font = newValue } }
    var textAlign: String { get { st.align } set { st.align = newValue } }
    var textBaseline: String { get { st.baseline } set { st.baseline = newValue } }
    var imageSmoothingEnabled: Bool { get { st.smooth } set { st.smooth = newValue } }
    var lineCap: String { get { st.lineCap } set { st.lineCap = newValue } }
    var lineJoin: String { get { st.lineJoin } set { st.lineJoin = newValue } }
    var miterLimit = 10.0
    func fill(_ s: String) { st.fill = .color(css(s)) }

    func save() { stack.append(st) }
    func restore() { if let s = stack.popLast() { st = s } }
    func resetStack() { stack.removeAll(); st = State() }
    func translate(_ x: Double, _ y: Double) { st.m = st.m.translatedBy(x: CGFloat(x), y: CGFloat(y)) }
    func scale(_ x: Double, _ y: Double) { st.m = st.m.scaledBy(x: CGFloat(x), y: CGFloat(y)) }
    func rotate(_ a: Double) { st.m = st.m.rotated(by: CGFloat(a)) }
    func setTransform(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) { st.m = CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(e), ty: CGFloat(f)) }
    func transform(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) { st.m = CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(e), ty: CGFloat(f)).concatenating(st.m) }

    // path
    enum Seg { case move(CGPoint), line(CGPoint), rect(CGRect), arc(CGPoint, CGFloat, CGFloat, CGFloat, Bool) }
    var path: [Seg] = []
    func beginPath() { path = [] }
    func moveTo(_ x: Double, _ y: Double) { path.append(.move(CGPoint(x: x, y: y))) }
    func lineTo(_ x: Double, _ y: Double) { path.append(.line(CGPoint(x: x, y: y))) }
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { path.append(.rect(CGRect(x: x, y: y, width: w, height: h))) }
    func arc(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, _ ccw: Bool = false) { path.append(.arc(CGPoint(x: x, y: y), CGFloat(r), CGFloat(a0), CGFloat(a1), ccw)) }
    func closePath() {}

    func measureText(_ t: String) -> TextMetrics { measure(t, cssFont(st.font)) }
    func createRadialGradient(_ x0: Double, _ y0: Double, _ r0: Double, _ x1: Double, _ y1: Double, _ r1: Double) -> Gradient { Gradient(.radial(x0: x0, y0: y0, r0: r0, x1: x1, y1: y1, r1: r1)) }
    func createLinearGradient(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Gradient { Gradient(.linear(x0: x0, y0: y0, x1: x1, y1: y1)) }

    // primitives (backends)
    func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {}
    func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {}
    func strokeRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) { beginPath(); moveTo(x, y); lineTo(x + w, y); lineTo(x + w, y + h); lineTo(x, y + h); lineTo(x, y); stroke() }
    func drawImage(_ im: Img?, _ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) {}
    func drawImage(_ im: Img?, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) { guard let im = im else { return }; drawImage(im, 0, 0, Double(im.width), Double(im.height), dx, dy, dw, dh) }
    func drawImage(_ im: Img?, _ dx: Double, _ dy: Double) { guard let im = im else { return }; drawImage(im, dx, dy, Double(im.width), Double(im.height)) }
    func fill() {}
    func stroke() {}
    func clip() {}
    func fillText(_ t: String, _ x: Double, _ y: Double) {}
    func strokeText(_ t: String, _ x: Double, _ y: Double) {}

    /// where the text's baseline-left sits for the current align / baseline
    func textOrigin(_ t: String, _ x: Double, _ y: Double) -> (Double, Double, TextMetrics, FontSpec) {
        let f = cssFont(st.font), m = measure(t, f)
        var ox = x, oy = y
        switch st.align { case "center": ox -= m.width / 2; case "right", "end": ox -= m.width; default: break }
        let asc = Double(CTFontGetAscent(f.ct)), desc = Double(CTFontGetDescent(f.ct))
        switch st.baseline { case "middle": oy += (asc - desc) / 2; case "top", "hanging": oy += asc; case "bottom", "ideographic": oy -= desc; default: break }
        return (ox, oy, m, f)
    }
}

// MARK: - CoreGraphics backend (a picture)

final class CGCanvas: Canvas2D {
    let w: Int, h: Int
    let ctx: CGContext
    init(_ w: Int, _ h: Int) {
        self.w = max(1, w); self.h = max(1, h)
        ctx = CGContext(data: nil, width: self.w, height: self.h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        super.init()
        st.smooth = true
    }
    var width: Int { w }
    var height: Int { h }
    /// the picture as it is now
    func image() -> Img { Img(ctx.makeImage()!) }
    private func begin() {
        ctx.saveGState()
        ctx.concatenate(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(h)))   // y down, like the canvas
        ctx.concatenate(st.m)
        ctx.setAlpha(CGFloat(st.alpha))
        ctx.interpolationQuality = st.smooth ? .high : .none
        ctx.setShouldAntialias(true)
    }
    private func end() { ctx.restoreGState() }
    private func fillPaint(_ r: CGRect?) {
        switch st.fill {
        case .color(let c): ctx.setFillColor(c.cg); if let r = r { ctx.fill(r) } else { ctx.fillPath() }
        case .gradient(let g):
            ctx.saveGState()
            if let r = r { ctx.clip(to: r) } else { ctx.clip() }
            switch g.kind {
            case let .linear(x0, y0, x1, y1): ctx.drawLinearGradient(g.cgGradient, start: CGPoint(x: x0, y: y0), end: CGPoint(x: x1, y: y1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            case let .radial(x0, y0, r0, x1, y1, r1): ctx.drawRadialGradient(g.cgGradient, startCenter: CGPoint(x: x0, y: y0), startRadius: CGFloat(r0), endCenter: CGPoint(x: x1, y: y1), endRadius: CGFloat(r1), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            ctx.restoreGState()
        }
    }
    override func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        begin(); ctx.setShouldAntialias(false); fillPaint(CGRect(x: x, y: y, width: w, height: h)); end()
    }
    override func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        begin(); ctx.clear(CGRect(x: x, y: y, width: w, height: h)); end()
    }
    override func drawImage(_ im: Img?, _ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) {
        guard let im = im, sw > 0, sh > 0 else { return }
        var src = im.cg
        if !(sx == 0 && sy == 0 && Int(sw) == im.width && Int(sh) == im.height) {
            // (parts outside the picture are left out, like the canvas)
            let r = CGRect(x: sx, y: sy, width: sw, height: sh).intersection(CGRect(x: 0, y: 0, width: im.width, height: im.height))
            guard !r.isNull, r.width > 0, r.height > 0, let c = im.cg.cropping(to: r.integral) else { return }
            let kx = dw / sw, ky = dh / sh
            src = c
            let ndx = dx + (Double(r.minX) - sx) * kx, ndy = dy + (Double(r.minY) - sy) * ky
            draw(src, ndx, ndy, Double(r.width) * kx, Double(r.height) * ky)
            return
        }
        draw(src, dx, dy, dw, dh)
    }
    private func draw(_ c: CGImage, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) {
        begin()
        ctx.translateBy(x: CGFloat(dx), y: CGFloat(dy + dh)); ctx.scaleBy(x: 1, y: -1)   // images are y up in CG
        ctx.draw(c, in: CGRect(x: 0, y: 0, width: dw, height: dh))
        end()
    }
    private func buildPath() {
        ctx.beginPath()
        for s in path {
            switch s {
            case .move(let p): ctx.move(to: p)
            case .line(let p): ctx.addLine(to: p)
            case .rect(let r): ctx.addRect(r)
            case let .arc(c, r, a0, a1, ccw): ctx.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: ccw)
            }
        }
    }
    override func fill() { begin(); buildPath(); fillPaint(nil); end() }
    override func stroke() {
        begin(); buildPath()
        if case .color(let c) = st.stroke { ctx.setStrokeColor(c.cg) }
        ctx.setLineWidth(CGFloat(st.lineWidth))
        ctx.setLineCap(st.lineCap == "square" ? .square : st.lineCap == "round" ? .round : .butt)
        ctx.setLineJoin(st.lineJoin == "round" ? .round : st.lineJoin == "bevel" ? .bevel : .miter)
        ctx.strokePath(); end()
    }
    private var clipDepth = 0
    override func clip() {}   // (not needed by the pictures the game makes)
    private func text(_ t: String, _ x: Double, _ y: Double, fill: Bool) {
        let (ox, oy, _, f) = textOrigin(t, x, y)
        begin()
        let line: CTLine
        if fill {
            guard case .color(let c) = st.fill else { end(); return }
            let a = NSAttributedString(string: t, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): f.ct, NSAttributedString.Key(kCTForegroundColorAttributeName as String): c.cg])
            line = CTLineCreateWithAttributedString(a)
        } else {
            guard case .color(let c) = st.stroke else { end(); return }
            ctx.setStrokeColor(c.cg); ctx.setLineWidth(CGFloat(st.lineWidth)); ctx.setTextDrawingMode(.stroke)
            ctx.setLineJoin(st.lineJoin == "round" ? .round : .miter)
            let a = NSAttributedString(string: t, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): f.ct, NSAttributedString.Key(kCTStrokeColorAttributeName as String): c.cg,
                                                                NSAttributedString.Key(kCTStrokeWidthAttributeName as String): NSNumber(value: st.lineWidth / f.size * 100), NSAttributedString.Key(kCTForegroundColorAttributeName as String): UIColor.clear.cgColor])
            line = CTLineCreateWithAttributedString(a)
        }
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: ox, y: oy)
        CTLineDraw(line, ctx)
        end()
    }
    override func fillText(_ t: String, _ x: Double, _ y: Double) { text(t, x, y, fill: true) }
    override func strokeText(_ t: String, _ x: Double, _ y: Double) { text(t, x, y, fill: false) }

    /// pixels, RGBA (not premultiplied), like getImageData
    func getImageData() -> [UInt8] {
        let img = ctx.makeImage()!
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let c2 = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c2.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: out.count, by: 4) where out[i + 3] > 0 && out[i + 3] < 255 {
            let a = Double(out[i + 3]) / 255
            for k in 0..<3 { out[i + k] = UInt8(min(255, (Double(out[i + k]) / a).rounded())) }
        }
        return out
    }
    func putImageData(_ px: [UInt8]) {
        var d = px
        for i in stride(from: 0, to: d.count, by: 4) { let a = Double(d[i + 3]) / 255; for k in 0..<3 { d[i + k] = UInt8((Double(d[i + k]) * a).rounded()) } }
        let c2 = CGContext(data: &d, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let img = c2.makeImage()!
        ctx.saveGState(); ctx.setBlendMode(.copy); ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h)); ctx.restoreGState()
    }
}

// MARK: - SpriteKit backend (the game screen)

final class SKCanvas: Canvas2D {
    let root = SKNode()
    var boxH = 874.0
    var scaleHint: CGFloat = 3   // screen pixels per point (for text sharpness)
    private var pool: [SKSpriteNode] = []
    private var used = 0
    private var z: CGFloat = 0
    private lazy var white: SKTexture = {
        let c = CGCanvas(1, 1); c.fill("#fff"); c.fillRect(0, 0, 1, 1); let t = SKTexture(cgImage: c.image().cg); t.filteringMode = .nearest; return t
    }()

    func begin() { used = 0; z = 0; resetStack() }
    func end() {
        if used < pool.count { for i in used..<pool.count where !pool[i].isHidden { pool[i].isHidden = true } }
    }
    private func node() -> SKSpriteNode {
        if used == pool.count {
            let n = SKSpriteNode(texture: nil, color: .white, size: CGSize(width: 1, height: 1))
            n.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            root.addChild(n); pool.append(n)
        }
        let n = pool[used]; used += 1
        if n.isHidden { n.isHidden = false }
        z += 1; n.zPosition = z
        return n
    }
    /// one textured / coloured quad: the local rect (x, y, w, h, y down) under transform m
    private func quad(_ m: CGAffineTransform, _ x: Double, _ y: Double, _ w: Double, _ h: Double, tex: SKTexture?, color: RGBA, alpha: Double, tint: Bool) {
        let a = alpha
        if a <= 0.001 || w == 0 || h == 0 { return }
        // linear part in SK space (y up both for the canvas and the texture): K = F * M * diag(w, h) * F
        let la = Double(m.a), lb = Double(m.b), lc = Double(m.c), ld = Double(m.d)
        let k11 = la * w, k21 = -lb * w, k12 = -lc * h, k22 = ld * h
        let sx = (k11 * k11 + k21 * k21).squareRoot()
        if sx < 1e-9 { return }
        let rot = atan2(k21, k11), sy = (k11 * k22 - k12 * k21) / sx
        let cx = x + w / 2, cy = y + h / 2
        let px = Double(m.a) * cx + Double(m.c) * cy + Double(m.tx), py = Double(m.b) * cx + Double(m.d) * cy + Double(m.ty)
        let n = node()
        if n.texture !== tex { n.texture = tex }
        if tex == nil || tint {
            let c = color.ui
            if n.color != c { n.color = c }
            n.colorBlendFactor = 1
        } else if n.colorBlendFactor != 0 { n.colorBlendFactor = 0 }
        n.alpha = CGFloat(a)
        n.position = CGPoint(x: px, y: boxH - py)
        n.zRotation = CGFloat(rot)
        n.xScale = CGFloat(sx); n.yScale = CGFloat(sy)
    }
    override func fillRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        switch st.fill {
        case .color(let c): quad(st.m, x, y, w, h, tex: nil, color: RGBA(r: c.r, g: c.g, b: c.b, a: 1), alpha: c.a * st.alpha, tint: false)
        case .gradient(let g): gradientRect(g, x, y, w, h)
        }
    }
    override func clearRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {}
    override func drawImage(_ im: Img?, _ sx: Double, _ sy: Double, _ sw: Double, _ sh: Double, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double) {
        guard let im = im else { return }
        let full = sx == 0 && sy == 0 && Int(sw) == im.width && Int(sh) == im.height
        let t = full ? im.tex(st.smooth) : im.sub(sx, sy, sw, sh, st.smooth)
        quad(st.m, dx, dy, dw, dh, tex: t, color: .white, alpha: st.alpha, tint: false)
    }
    /// a picture coloured in (white parts take the colour)
    func drawTinted(_ t: SKTexture, _ dx: Double, _ dy: Double, _ dw: Double, _ dh: Double, _ c: RGBA, _ alpha: Double) {
        quad(st.m, dx, dy, dw, dh, tex: t, color: RGBA(r: c.r, g: c.g, b: c.b, a: 1), alpha: alpha, tint: true)
    }
    override func fill() {
        for s in path { if case .rect(let r) = s { fillRect(Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)) } }
        // arcs filled on the game screen: a disc
        for s in path { if case let .arc(c, r, _, _, _) = s { if case .color(let col) = st.fill { drawTinted(SKCanvas.disc, Double(c.x - r), Double(c.y - r), Double(2 * r), Double(2 * r), col, col.a * st.alpha) } } }
    }
    private static let disc: SKTexture = {
        let c = CGCanvas(64, 64); c.fill("#fff"); c.beginPath(); c.arc(32, 32, 32, 0, 7); c.fill(); let t = SKTexture(cgImage: c.image().cg); t.filteringMode = .linear; return t
    }()
    override func stroke() {
        guard case .color(let c) = st.stroke else { return }
        let lw = st.lineWidth
        var subs: [[CGPoint]] = []
        for s in path {
            switch s {
            case .move(let p): subs.append([p])
            case .line(let p): if subs.isEmpty { subs.append([p]) } else { subs[subs.count - 1].append(p) }
            case .rect(let r): subs.append([CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.minY)])
            case let .arc(cc, r, a0, a1, _):
                var pts: [CGPoint] = []; let n = 40
                let span = min(Double(a1 - a0), 2 * .pi)
                for i in 0...n { let a = Double(a0) + span * Double(i) / Double(n); pts.append(CGPoint(x: Double(cc.x) + cos(a) * Double(r), y: Double(cc.y) + sin(a) * Double(r))) }
                subs.append(pts)
            }
        }
        let cap = st.lineCap == "square" ? lw / 2 : 0
        for pts in subs where pts.count > 1 {
            for i in 0..<(pts.count - 1) {
                let p0 = pts[i], p1 = pts[i + 1]
                let dx = Double(p1.x - p0.x), dy = Double(p1.y - p0.y), L = (dx * dx + dy * dy).squareRoot()
                if L < 1e-9 { continue }
                let e0 = i > 0 ? lw / 2 : cap, e1 = i < pts.count - 2 ? lw / 2 : cap
                var m = st.m.translatedBy(x: p0.x, y: p0.y)
                m = m.rotated(by: CGFloat(atan2(dy, dx)))
                quad(m, -e0, -lw / 2, L + e0 + e1, lw, tex: nil, color: RGBA(r: c.r, g: c.g, b: c.b, a: 1), alpha: c.a * st.alpha, tint: false)
            }
        }
    }
    override func clip() {}   // (the game's only clip hides what is behind the ground or above the screen anyway)

    // text: drawn once into a picture with CoreText, then placed like an image
    private struct TextKey: Hashable { let t: String, font: String, col: String, stroke: Double, scale: Int, join: String }
    private var textCache: [TextKey: (Img, Double, Double)] = [:]   // picture, its left and top relative to the baseline origin (points)
    private func textImage(_ t: String, fill: Bool) -> (Img, Double, Double, Double)? {
        let paint = fill ? st.fill : st.stroke
        guard case .color(let c) = paint else { return nil }
        let k = Double(scaleHint) * max(0.25, Double((st.m.a * st.m.a + st.m.b * st.m.b).squareRoot()))
        let ks = Int((k * 4).rounded())
        let key = TextKey(t: t, font: st.font, col: "\(c.r),\(c.g),\(c.b)", stroke: fill ? 0 : st.lineWidth, scale: ks, join: st.lineJoin)
        if let hit = textCache[key] { return (hit.0, hit.1, hit.2, Double(ks) / 4) }
        let f = cssFont(st.font), m = measure(t, f)
        let pad = (fill ? 0 : st.lineWidth) + 2
        let asc = Double(CTFontGetAscent(f.ct)), desc = Double(CTFontGetDescent(f.ct))
        let left = min(0, -m.actualBoundingBoxLeft) - pad, right = max(m.width, m.actualBoundingBoxRight) + pad
        let top = -asc - pad, bottom = desc + pad
        let sc = Double(ks) / 4
        let cv = CGCanvas(Int(((right - left) * sc).rounded(.up)), Int(((bottom - top) * sc).rounded(.up)))
        cv.scale(sc, sc); cv.translate(-left, -top)
        cv.font = st.font; cv.textAlign = "left"; cv.textBaseline = "alphabetic"; cv.lineJoin = st.lineJoin
        if fill { cv.fillStyle = .color(RGBA(r: c.r, g: c.g, b: c.b, a: 1)); cv.fillText(t, 0, 0) }
        else { cv.strokeStyle = .color(RGBA(r: c.r, g: c.g, b: c.b, a: 1)); cv.lineWidth = st.lineWidth; cv.strokeText(t, 0, 0) }
        let im = cv.image()
        if textCache.count > 300 { textCache.removeAll() }
        textCache[key] = (im, left, top)
        return (im, left, top, sc)
    }
    private func text(_ t: String, _ x: Double, _ y: Double, fill: Bool) {
        guard !t.isEmpty, let (im, left, top, sc) = textImage(t, fill: fill) else { return }
        let (ox, oy, _, _) = textOrigin(t, x, y)
        let paint = fill ? st.fill : st.stroke
        var a = st.alpha; if case .color(let c) = paint { a *= c.a }
        quad(st.m, ox + left, oy + top, Double(im.width) / sc, Double(im.height) / sc, tex: im.tex(true), color: .white, alpha: a, tint: false)
    }
    override func fillText(_ t: String, _ x: Double, _ y: Double) { text(t, x, y, fill: true) }
    override func strokeText(_ t: String, _ x: Double, _ y: Double) { text(t, x, y, fill: false) }

    // gradients: a cached picture of the gradient's shape, coloured and stretched over the rect
    private var gradCache: [String: SKTexture] = [:]
    private func gradientRect(_ g: Gradient, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        guard let first = g.stops.first else { return }
        let rgb = first.1, maxA = g.stops.map { $0.1.a }.max() ?? 0
        let sameRGB = g.stops.allSatisfy { abs($0.1.r - rgb.r) + abs($0.1.g - rgb.g) + abs($0.1.b - rgb.b) < 0.01 }
        if maxA <= 0.001 { return }
        let prof = g.stops.map { String(format: "%.3f:%.2f", $0.0, $0.1.a / maxA) }.joined(separator: ",")
        switch g.kind {
        case let .radial(x0, y0, r0, _, _, r1):
            guard r1 > 0 else { return }
            let ratio = r0 / r1
            let key = "r" + String(format: "%.3f", ratio) + prof + (sameRGB ? "" : g.stops.map { "\($0.1.r),\($0.1.g),\($0.1.b)" }.joined())
            let tex = gradCache[key] ?? {
                let N = 128, c = CGCanvas(N, N)
                let gg = c.createRadialGradient(Double(N) / 2, Double(N) / 2, ratio * Double(N) / 2, Double(N) / 2, Double(N) / 2, Double(N) / 2)
                for s in g.stops { gg.addColorStop(s.0, sameRGB ? RGBA(r: 1, g: 1, b: 1, a: s.1.a / maxA) : RGBA(r: s.1.r, g: s.1.g, b: s.1.b, a: s.1.a / maxA)) }
                c.fillStyle = .gradient(gg); c.fillRect(0, 0, Double(N), Double(N))
                let t = SKTexture(cgImage: c.image().cg); t.filteringMode = .linear
                if gradCache.count > 120 { gradCache.removeAll() }
                gradCache[key] = t; return t
            }()
            let col = sameRGB ? rgb : .white
            // the square that holds the circle, cut to the rect
            let sq = CGRect(x: x0 - r1, y: y0 - r1, width: 2 * r1, height: 2 * r1), rr = CGRect(x: x, y: y, width: w, height: h)
            let inter = sq.intersection(rr)
            if !inter.isNull && inter.width > 0 && inter.height > 0 {
                let t = inter == sq ? tex : SKTexture(rect: CGRect(x: (inter.minX - sq.minX) / sq.width, y: 1 - (inter.maxY - sq.minY) / sq.height, width: inter.width / sq.width, height: inter.height / sq.height), in: tex)
                quad(st.m, Double(inter.minX), Double(inter.minY), Double(inter.width), Double(inter.height), tex: t, color: col, alpha: maxA * st.alpha, tint: true)
            }
            // outside the circle: the last colour
            if let last = g.stops.last, last.1.a > 0.001 {
                let lc = last.1
                for part in [CGRect(x: rr.minX, y: rr.minY, width: rr.width, height: max(0, sq.minY - rr.minY)), CGRect(x: rr.minX, y: sq.maxY, width: rr.width, height: max(0, rr.maxY - sq.maxY)),
                             CGRect(x: rr.minX, y: max(rr.minY, sq.minY), width: max(0, sq.minX - rr.minX), height: max(0, min(rr.maxY, sq.maxY) - max(rr.minY, sq.minY))),
                             CGRect(x: sq.maxX, y: max(rr.minY, sq.minY), width: max(0, rr.maxX - sq.maxX), height: max(0, min(rr.maxY, sq.maxY) - max(rr.minY, sq.minY)))] where part.width > 0 && part.height > 0 {
                    quad(st.m, Double(part.minX), Double(part.minY), Double(part.width), Double(part.height), tex: nil, color: RGBA(r: lc.r, g: lc.g, b: lc.b, a: 1), alpha: lc.a * st.alpha, tint: false)
                }
            }
        case let .linear(x0, y0, x1, y1):
            // the game's linear gradients run straight down or across the rect
            let vertical = abs(x1 - x0) < abs(y1 - y0)
            let a0 = vertical ? y0 : x0, a1 = vertical ? y1 : x1
            let s0 = vertical ? y : x, len = vertical ? h : w
            guard len > 0 else { return }
            let key = "l\(vertical)" + String(format: "%.2f,%.2f", (a0 - s0) / len, (a1 - s0) / len) + prof + (sameRGB ? "" : g.stops.map { "\($0.1.r),\($0.1.g),\($0.1.b)" }.joined())
            let tex = gradCache[key] ?? {
                let N = 64, c = CGCanvas(vertical ? 2 : N, vertical ? N : 2)
                let gg = vertical ? c.createLinearGradient(0, (a0 - s0) / len * Double(N), 0, (a1 - s0) / len * Double(N)) : c.createLinearGradient((a0 - s0) / len * Double(N), 0, (a1 - s0) / len * Double(N), 0)
                for s in g.stops { gg.addColorStop(s.0, sameRGB ? RGBA(r: 1, g: 1, b: 1, a: s.1.a / maxA) : RGBA(r: s.1.r, g: s.1.g, b: s.1.b, a: s.1.a / maxA)) }
                c.fillStyle = .gradient(gg); c.fillRect(0, 0, Double(c.w), Double(c.h))
                let t = SKTexture(cgImage: c.image().cg); t.filteringMode = .linear
                gradCache[key] = t; return t
            }()
            quad(st.m, x, y, w, h, tex: tex, color: sameRGB ? rgb : .white, alpha: maxA * st.alpha, tint: true)
        }
    }
}
