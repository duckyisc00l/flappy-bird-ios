import SwiftUI
import AVFoundation

// MARK: - Bird Maker

struct MakerPage: View {
    @State private var name = ""
    @State private var pal: [String: String] = BASE_PAL
    @State private var px: [String: String] = [:]
    @State private var part = "R"
    @State private var brush = "#ffd23c"
    @State private var tool = "paint"
    @State private var tab = "colors"
    @State private var clearSure = false
    @State private var delSure = false
    @State private var saveText = "Save"
    @State private var loaded = false
    private var old: CustomBird? { PK.makerId.flatMap { customBird($0) } }
    private func frames() -> [Img] { (0..<3).map { buildCustomFrame($0, pal: pal, px: px) } }
    var body: some View {
        let fr = frames()
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { c in let n = Int(c.date.timeIntervalSinceReferenceDate * 10); PixImage(img: fr[[0, 1, 2, 1][n % 4]], w: 50, h: 48, bg: K.sky, radius: 7, border: K.brown) }
                    TextField("", text: $name).font(K.kong(16)).foregroundColor(K.brown).autocorrectionDisabled()
                        .onChange(of: name) { v in if v.count > 16 { name = String(v.prefix(16)) } }
                        .overlay(alignment: .leading) { if name.isEmpty { Text("Name your bird").font(K.kong(9)).foregroundColor(K.placeholder).allowsHitTesting(false) } }
                        .padding(.vertical, 6).padding(.horizontal, 8).background(RoundedRectangle(cornerRadius: 8).fill(K.input)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
                }.padding(.bottom, 5)
                HStack(spacing: 5) { tabBtn("colors", "Colors"); tabBtn("draw", "Draw") }.padding(.bottom, 6)
                if tab == "colors" {
                    Hint(t: "Pick a part, then a colour")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                        ForEach(MK_PARTS, id: \.0) { k, label in
                            Button { part = k; haptic() } label: {
                                HStack(spacing: 5) { RoundedRectangle(cornerRadius: 4).fill(Color(css: pal[k] ?? "#000")).frame(width: 14, height: 14).overlay(RoundedRectangle(cornerRadius: 4).stroke(K.brown, lineWidth: 2)); KT(label, 6, lines: 1) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(4).tile(part == k)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.bottom, 5)
                    palette(pal[part]) { c in pal[part] = c }
                } else {
                    Hint(t: "Draw on your bird: hats, spots, stripes...")
                    editor(fr[1])
                    HStack(spacing: 5) {
                        toolBtn("paint", "Brush"); toolBtn("erase", "Eraser")
                        Button { if clearSure { px = [:]; clearSure = false } else { clearSure = true; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { clearSure = false } } } label: { toolLabel(clearSure ? "Sure?" : "Clear", false) }.buttonStyle(.plain)
                    }.padding(.bottom, 5)
                    palette(brush) { c in brush = c; tool = "paint" }
                }
                HStack(spacing: 5) {
                    MkBtn("Surprise me") {
                        func pick() -> String { MK_COLORS[6 + Int(floor(mrand() * Double(MK_COLORS.count - 6)))] }
                        pal["R"] = pick(); pal["L"] = MK_COLORS[Int(floor(mrand() * Double(MK_COLORS.count)))]; pal["D"] = pick(); pal["W"] = mrand() < 0.5 ? "#fafafa" : pick(); pal["G"] = pick(); pal["B"] = pick()
                        haptic(); playSound("swoosh")
                    }
                    if let o = old {
                        MkBtn("Share", .share) { playSound("swoosh"); PK.exportId = o.id; showPage("export") }
                        MkBtn(delSure ? "Sure?" : "Delete", .del) {
                            if !delSure { delSure = true; DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { delSure = false }; return }
                            customBirds.removeAll { $0.id == o.id }; saveCustomBirds(); unregisterCustom(o.id)
                            favBirds.removeAll { $0 == o.id }; saveFavs()
                            if birdPick == o.id { birdPick = "random"; saveStr("birdPick", "random") }
                            playSound("swoosh"); showPage("birds")
                        }
                    }
                    MkBtn(saveText, .save) {
                        let cb = CustomBird(id: old?.id ?? "custom_" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "My bird \(customBirds.count + 1)" : name.trimmingCharacters(in: .whitespaces), pal: pal, px: px)
                        if old != nil { customBirds = customBirds.map { $0.id == cb.id ? cb : $0 } } else { customBirds.insert(cb, at: 0) }
                        saveCustomBirds(); registerCustom(cb)
                        birdPick = cb.id; saveStr("birdPick", cb.id)
                        playSound("point"); haptic(); showPage("birds")
                    }
                }.padding(.top, 2)
            }
        }
        .onAppear {
            if loaded { return }; loaded = true
            if let o = old { name = o.name; for (k, v) in o.pal { pal[k] = v }; px = o.px }
            pal["S"] = nil
        }
    }
    private func tabBtn(_ id: String, _ label: String) -> some View {
        Button { tab = id; haptic() } label: { KT(label, 9, tab == id ? .white : K.brown).frame(maxWidth: .infinity).padding(.vertical, 7).background(RoundedRectangle(cornerRadius: 8).fill(tab == id ? K.orange : K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2)) }.buttonStyle(.plain)
    }
    private func toolLabel(_ t: String, _ on: Bool) -> some View { KT(t, 8, on ? .white : K.brown).frame(maxWidth: .infinity).padding(.vertical, 5).background(RoundedRectangle(cornerRadius: 8).fill(on ? K.brown : K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2)) }
    private func toolBtn(_ id: String, _ label: String) -> some View { Button { tool = id; haptic() } label: { toolLabel(label, tool == id) }.buttonStyle(.plain) }
    private func palette(_ cur: String?, _ pick: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 10), spacing: 3) {
            ForEach(MK_COLORS, id: \.self) { c in
                Button { pick(c); haptic() } label: {
                    RoundedRectangle(cornerRadius: 5).fill(Color(css: c)).aspectRatio(1, contentMode: .fit).overlay(RoundedRectangle(cornerRadius: 5).stroke(K.brown, lineWidth: 2))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(c == cur ? K.orange : .clear, lineWidth: 2).padding(-4)).overlay(RoundedRectangle(cornerRadius: 6).stroke(c == cur ? .white : .clear, lineWidth: 2).padding(-2))
                }.buttonStyle(.plain)
            }
            ColorPicker("", selection: Binding(get: { Color(css: cur ?? "#ffffff") }, set: { c in
                let u = UIColor(c); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; u.getRed(&r, green: &g, blue: &b, alpha: &a)
                pick(String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255)))
            }), supportsOpacity: false).labelsHidden().frame(maxWidth: .infinity)
        }.padding(.bottom, 6)
    }
    // 21 x 20 big pixels (the bird is 17 x 12 in the middle)
    private func editor(_ f: Img) -> some View {
        let GW = 21.0, GH = 20.0, W = 189.0, H = 180.0
        let c = CGCanvas(Int(GW * 12 * 2), Int(GH * 12 * 2))
        c.scale(2, 2); c.imageSmoothingEnabled = false
        for y in 0..<20 { for x in 0..<21 { c.fill((x + y) % 2 != 0 ? "#d6eef2" : "#c4e4ea"); c.fillRect(Double(x) * 12, Double(y) * 12, 12, 12) } }
        c.drawImage(f, 0, 0, GW * 2, GH * 2, 0, 0, GW * 12, GH * 12)
        c.strokeStyle = .s("rgba(83,56,70,0.12)"); c.lineWidth = 1; c.beginPath()
        for x in 1..<21 { c.moveTo(Double(x) * 12 + 0.5, 0); c.lineTo(Double(x) * 12 + 0.5, GH * 12) }
        for y in 1..<20 { c.moveTo(0, Double(y) * 12 + 0.5); c.lineTo(GW * 12, Double(y) * 12 + 0.5) }
        c.stroke()
        return PixImage(img: c.image(), w: W, h: H, radius: 6, border: K.brown)
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let gx = Int(floor(v.location.x / W * GW)), gy = Int(floor(v.location.y / H * GH))
                if gx < 0 || gy < 0 || gx >= 21 || gy >= 20 { return }
                let key = "\(gx - 2),\(gy - 4)"
                if tool == "erase" { px[key] = nil } else if px[key] != brush { px[key] = brush }
            })
            .padding(.bottom, 5)
    }
}

struct ExportPage: View {
    @State private var copied = false
    var body: some View {
        if let cb = PK.exportId.flatMap({ customBird($0) }) {
            let code = birdToCode(cb)
            VStack(spacing: 0) {
                HStack(spacing: 8) { BirdView(id: cb.id, w: 50, h: 48, bg: K.sky, radius: 7, border: K.brown); KT(cb.name, 9, K.orange, shadow: K.cream).frame(maxWidth: .infinity, alignment: .leading) }.padding(.bottom, 5)
                Hint(t: "Send this code to a friend. They tap Import a bird and paste it.")
                CodeBox(text: .constant(code), readOnly: true)
                HStack(spacing: 5) {
                    MkBtn(copied ? "Copied!" : "Copy code", .save) { UIPasteboard.general.string = code; copied = true; haptic(); playSound("point"); DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { copied = false } }
                    MkBtn("Share...") { share(["My Flappy bird: \(cb.name)\n" + code]) }
                }
            }
        } else { Note(t: "Save your bird first.") }
    }
}
struct ImportPage: View {
    @State private var text = ""
    @State private var msg = ""
    var body: some View {
        VStack(spacing: 0) {
            Hint(t: "Paste a bird code here (it starts with FLAPPYBIRD1:)")
            CodeBox(text: $text, ph: "FLAPPYBIRD1:...")
            Msg(t: msg)
            HStack(spacing: 5) {
                MkBtn("Paste") { if let s = UIPasteboard.general.string { text = s } else { msg = "Tap the box and paste instead" } }
                MkBtn("Import", .save) {
                    do {
                        let b = try birdFromCode(text)
                        let cb = CustomBird(id: "custom_" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), name: b.name, pal: b.pal, px: b.px)
                        customBirds.insert(cb, at: 0); saveCustomBirds(); registerCustom(cb); birdPick = cb.id; saveStr("birdPick", cb.id)
                        playSound("point"); haptic(); showPage("birds")
                    } catch { msg = (error as? CodeError)?.message ?? "The code is broken or cut off"; playSound("hit") }
                }
            }
        }
    }
}
func share(_ items: [Any]) {
    let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
    guard let root = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first?.rootViewController else { return }
    var top = root; while let p = top.presentedViewController { top = p }
    vc.popoverPresentationController?.sourceView = top.view
    top.present(vc, animated: true)
}

// MARK: - Score card

struct CardData { var score: Int, best: Int, fresh: Bool, medal: String?, bird: String, mode: String, season: String, weather: String, night: Bool, bot: Bool, when: Date }
func cardSnapshot() -> CardData {
    let s = result.lastI != nil ? result.score : score
    let fresh = s > 0 && result.lastI != nil && s > result.prevBest && START_SCORE == 0 && !runUsedBot
    return CardData(score: s, best: max(bestScore(), fresh ? s : 0), fresh: fresh, medal: result.medal, bird: birdColor, mode: ending.on ? "normal" : gameMode,
                    season: weatherOn() ? WX.season : "classic", weather: weatherOn() ? WX.weather : "clear", night: skyIsNight, bot: runUsedBot, when: Date())
}
private func txt(_ g: CGCanvas, _ t: String, _ x: Double, _ y: Double, _ px: Double, _ font: String, _ fill: String, _ stroke: String? = nil, _ sw: Double = 0, _ align: String = "center") {
    g.font = "\(px)px \(font), monospace"; g.textAlign = align; g.textBaseline = "alphabetic"
    if let s = stroke { g.lineJoin = "round"; g.lineWidth = sw; g.strokeStyle = .s(s); g.strokeText(t, x, y) }
    g.fill(fill); g.fillText(t, x, y)
}
private func pxBox(_ g: CGCanvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ face: String, _ border: String, _ hi: String?, _ sh: String?, _ P: Double = 6) {
    g.fill(border); g.fillRect(x + P, y, w - 2 * P, h); g.fillRect(x, y + P, w, h - 2 * P)
    g.fill(face); g.fillRect(x + 2 * P, y + P, w - 4 * P, h - 2 * P); g.fillRect(x + P, y + 2 * P, w - 2 * P, h - 4 * P)
    if let hi = hi { g.fill(hi); g.fillRect(x + 2 * P, y + P, w - 4 * P, P) }
    if let sh = sh { g.fill(sh); g.fillRect(x + 2 * P, y + h - 2 * P, w - 4 * P, P) }
}
private func bigNum(_ g: CGCanvas, _ t: String, _ x: Double, _ y: Double, _ px: Double) {
    g.textAlign = "center"; g.textBaseline = "alphabetic"
    if t.hasPrefix("-") {
        let rest = String(t.dropFirst()); g.font = "\(px)px \"04b19\", monospace"
        let w = g.measureText(rest).width, mw = px * 0.5, gap = px * 0.08, x0 = x - (w + mw + gap) / 2, k = jsRound(px * 0.06)
        let my = jsRound(y - px * 0.5), mh = jsRound(px * 0.24)
        g.fill("#000"); g.fillRect(jsRound(x0), my, jsRound(mw), mh)
        g.fill("#fff"); g.fillRect(jsRound(x0) + k, my + k, jsRound(mw) - 2 * k, mh - 2 * k)
        return bigNum(g, rest, x0 + mw + gap + w / 2, y, px)
    }
    g.font = "\(px)px \"inside_font\", monospace"; g.fill("#fff"); g.lineJoin = "round"; g.lineWidth = px * 0.06; g.strokeStyle = "#fff"; g.strokeText(t, x, y); g.fillText(t, x, y)
    g.font = "\(px)px \"04b19\", monospace"; g.fill("#000"); g.fillText(t, x, y)
}
private func panelLabel(_ g: CGCanvas, _ t: String, _ x: Double, _ y: Double, _ px: Double) { g.font = "\(px)px \"kongtext\", monospace"; g.textAlign = "center"; g.fill("#efeaa9"); g.fillText(t, x, y + px * 0.12); g.fill("#fc7858"); g.fillText(t, x, y) }
private func drawScaryName(_ g: CGCanvas, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
    let G: [Character: [String]] = ["Y": ["¥", "Ɏ", "Ψ", "Ү"], "O": ["Ø", "Θ", "Ө", "∅"], "U": ["Ʉ", "µ", "Ц", "ᴜ"], "A": ["∆", "Λ", "Д", "Å"], "R": ["Я", "Ɽ", "ʀ", "℟"], "E": ["Ξ", "∑", "Є", "€"], "M": ["ʍ", "М", "Ɱ", "Ϻ"]]
    let t = "† " + String("YOU ARE ME".map { $0 == " " ? " " : Character(G[$0]![Int(floor(mrand() * 4))]) }) + " †"
    let o = CGCanvas(Int(w), Int(h))
    var fs = 64.0; o.font = "bold \(fs)px \"Courier New\", Courier, monospace"
    while o.measureText(t).width > w - 10 && fs > 22 { fs -= 2; o.font = "bold \(fs)px \"Courier New\", Courier, monospace" }
    o.textAlign = "center"; o.textBaseline = "middle"
    o.fill("rgba(0,255,255,0.35)"); o.fillText(t, w / 2 - 4, h / 2 + 1)
    o.fill("#000"); o.fillText(t, w / 2 + 3, h / 2 + 3)
    o.fill("#ff2a1e"); o.fillText(t, w / 2, h / 2)
    let oi = o.image()
    var yy = 0.0
    while yy < h { let sh = 3 + floor(mrand() * 10), dx = mrand() < 0.35 ? jsRound((mrand() - 0.5) * 26) : 0; g.drawImage(oi, 0, yy, w, sh, x + dx, y + yy, w, sh); yy += sh }
    for _ in 0..<14 { g.fill(mrand() < 0.5 ? "#ff2a1e" : "#000"); g.fillRect(x + mrand() * w, y + 12 + mrand() * (h - 24), 6, 6) }
}
func makeScoreCard(_ d: CardData) -> Img {
    let N = 1080.0, GROUND = 930.0
    let g = CGCanvas(1080, 1080); g.imageSmoothingEnabled = false
    let sky = d.night ? img("night_sky") : img("day_sky")
    g.fill(d.night ? "#008793" : "#4ec0ca"); g.fillRect(0, 0, N, N)
    if let s = sky { var x = -60.0; while x < N { g.drawImage(s, x, GROUND - 402 * 3, 288 * 3, 512 * 3); x += 288 * 3 - 3 } }
    let keep = (WX.season, WX.weather, WX.tintKey, WX.tint)
    WX.season = d.season; WX.weather = d.weather; WX.tintKey = ""
    if let tint = tintFor() { g.imageSmoothingEnabled = true; g.drawImage(tint, 0, 0, N, GROUND); g.imageSmoothingEnabled = false }
    (WX.season, WX.weather, WX.tintKey, WX.tint) = keep
    if let l = img("land") { var x = -20.0; while x < N { g.drawImage(l, x, GROUND, 336 * 3, 112 * 3); x += 336 * 3 - 3 } }
    if let lg = img("flappy_logo") { let s = 3.5; g.drawImage(lg, jsRound((N - 178 * s) / 2), 46, 178 * s, 48 * s) }
    let X = 108.0, Y = 246.0, W = N - 2 * X, H = 600.0
    g.fill("rgba(0,0,0,0.22)"); g.fillRect(X + 18, Y + 18, W, H)
    pxBox(g, X, Y, W, H, "#ded895", "#533846", "#efeaa9", "#c4bd7a", 6)
    let nb = (x: X + 42, y: Y + 42, w: W - 84, h: 96.0)
    let scary = d.bird == "haunted"
    if scary { pxBox(g, nb.x, nb.y, nb.w, nb.h, "#1a0306", "#000000", "#3a070d", "#0a0103", 6) } else { pxBox(g, nb.x, nb.y, nb.w, nb.h, "#fc7858", "#533846", "#ffa587", "#d85c40", 6) }
    if scary { drawScaryName(g, nb.x + 150, nb.y, nb.w - 170, nb.h) }
    else {
        let name = String(skinName(d.bird).prefix(18))
        var fs = 50.0; g.font = "\(fs)px \"04b19\", monospace"
        while g.measureText(name).width > nb.w - 230 && fs > 26 { fs -= 2; g.font = "\(fs)px \"04b19\", monospace" }
        txt(g, name, nb.x + 150 + (nb.w - 150) / 2, nb.y + nb.h / 2 + fs * 0.36, fs, "\"04b19\"", "#fff", "#533846", 10)
    }
    ensureSkin(d.bird)
    if let bim = img(d.bird + "_2") ?? img("yellow_2") {
        let w = Double(bim.width), h = Double(bim.height), s = 4.0
        g.save(); g.translate(nb.x + 92, nb.y + nb.h / 2 - 6); g.rotate(-0.22); g.drawImage(bim, -w * s / 2, -h * s / 2, w * s, h * s); g.restore()
    }
    let sb = (x: X + 42, y: Y + 168, w: W - 84, h: 262.0)
    pxBox(g, sb.x, sb.y, sb.w, sb.h, "#d4cd8b", "#c4bd7a", nil, nil, 6)
    g.fill("#bdb675"); g.fillRect(sb.x + 12, sb.y + 6, sb.w - 24, 6)
    let c1 = sb.x + sb.w * 0.27, c2 = sb.x + sb.w * 0.73
    bigNum(g, String(d.score), c1, sb.y + 166, 116)
    bigNum(g, String(d.best), c2, sb.y + 166, 116)
    panelLabel(g, "SCORE", c1, sb.y + 228, 30)
    panelLabel(g, "BEST", c2, sb.y + 228, 30)
    g.fill("#c4bd7a"); g.fillRect(sb.x + sb.w / 2 - 3, sb.y + 36, 6, sb.h - 72)
    if d.fresh, let nb2 = img("new_badge") { g.drawImage(nb2, jsRound(c2 + 70), sb.y + 34, 32 * 4, 14 * 4) }
    let my = Y + 520
    panelLabel(g, "MEDAL", c1, my + 14, 30)
    if let m = d.medal, let mi = img(m) { g.drawImage(mi, jsRound(c2 - 66), my - 66, 132, 132) }
    else { g.fill("#c4bd7a"); g.beginPath(); g.arc(c2, my - 2, 58, 0, 7); g.fill(); g.fill("#d4cd8b"); g.beginPath(); g.arc(c2, my + 2, 52, 0, 7); g.fill() }
    var pills: [(String, String, String)] = [(modeInfo(d.mode).title.uppercased(), "#fc7858", "#d85c40")]
    if d.season != "classic", let s = SEASONS.first(where: { $0.0 == d.season }) { pills.append((s.2.uppercased(), "#b07cff", "#8a5ad8")) }
    if d.weather != "clear", let w = WEATHERS.first(where: { $0.0 == d.weather }) { pills.append((w.2.uppercased(), "#3cb0ff", "#2a88cc")) }
    if d.bot { pills.append(("AUTOPLAY", "#7a7a7a", "#5a5a5a")) }
    g.font = "22px \"kongtext\", monospace"
    let pw = pills.map { g.measureText($0.0).width + 44 }, gap = 14.0, total = pw.reduce(0, +) + gap * Double(pills.count - 1)
    var px = (N - total) / 2; let py = Y + H + 34
    for (i, p) in pills.enumerated() { pxBox(g, px, py, pw[i], 54, p.1, "#533846", nil, p.2, 6); txt(g, p.0, px + pw[i] / 2, py + 36, 22, "\"kongtext\"", "#fff"); px += pw[i] + gap }
    txt(g, "FLAPPY BIRD", N / 2, 1040, 40, "\"04b19\"", "#fff", "#533846", 10)
    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
    txt(g, "@iluvsmltwin - " + f.string(from: d.when).uppercased(), N / 2, 1068, 17, "\"kongtext\"", "#fff", "#533846", 6)
    return g.image()
}
struct CardPage: View {
    @State private var card: Img? = nil
    @State private var reply: String? = nil
    var body: some View {
        let d = PK_CARD ?? cardSnapshot()
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ZStack { if let c = card { Image(uiImage: c.ui).resizable().interpolation(.high).aspectRatio(1, contentMode: .fit) } else { K.sky } }
                    .frame(maxWidth: 280).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 3))
                    .contextMenu { if let c = card { Button("Save to Photos") { UIImageWriteToSavedPhotosAlbum(c.ui, nil, nil, nil) }; Button("Copy") { UIPasteboard.general.image = c.ui } } }
                    .padding(.bottom, 6)
                Hint(t: card == nil ? "Making your card..." : "Press and hold the picture to save it or send it")
                if let c = card {
                    HStack(spacing: 5) {
                        MkBtn("Share", .save) { share([c.ui, "I scored \(d.score) in Flappy Bird!"]) }
                        MkBtn("Save picture") { UIImageWriteToSavedPhotosAlbum(c.ui, nil, nil, nil); toast("Saved to Photos") }
                    }
                }
                // v134: send your reply after a duel round
                if let lr = lastRun, let rd = lr.raced, let f = friendList.first(where: { $0.id == rd }), f.duel != nil, !lr.bot, (f.round ?? 1) < 9 {
                    let won = lr.score > f.score
                    CardBtn(title: reply ?? "Send your reply to \(f.name)", sub: (won ? "You won round " : "Round ") + "\((f.round ?? 1) + 1) - your \(lr.score) vs their \(f.score)", green: true) {
                        if onlineName().isEmpty { accGo("account"); return }
                        if reply == "Reply sent - share it", let u = replyURL { share([(won ? "I beat you, " : "Your turn, ") + "\(f.name)! \(lr.score) vs \(f.score). Tap to race me back:\n" + u]); return }
                        reply = "Sending..."
                        Task { @MainActor in
                            do {
                                var extra: [String: Any] = ["duel": f.duel!, "round": (f.round ?? 1) + 1, "reply_to": f.gid as Any? ?? NSNull()]
                                extra["to_user"] = f.uid != nil && palsIsFriend(f.uid!) ? f.uid! : NSNull()
                                let id = try await uploadRun(lr.enc, lr.mode, extra)
                                if let u = f.uid, palsIsFriend(u) { rtSend(u, ["t": "race"]) }
                                reply = "Reply sent - share it"; replyURL = SITE + "#r=" + id
                                share([(won ? "I beat you, " : "Your turn, ") + "\(f.name)! \(lr.score) vs \(f.score). Tap to race me back:\n" + replyURL!])
                            } catch { reply = accErr(error) }
                        }
                    }
                }
                let f = friendList.first { $0.id == raceId }
                CardBtn(title: "Race a Friend", sub: f != nil ? "Racing \(f!.name)" : "Send your ghost or race theirs") { playSound("swoosh"); haptic(); showPage("friends") }
            }.padding(2)
        }
        .onAppear { DispatchQueue.main.async { card = makeScoreCard(d) } }
    }
    @State private var replyURL: String? = nil
}
struct CardBtn: View { let title: String; let sub: String; var green = false; let act: () -> Void
    var body: some View {
        Button(action: act) {
            VStack(spacing: 3) { KT(title, 9, .white, upper: false, align: .center).shadow(color: green ? Color(hex: 0x3a7a2a) : Color(hex: 0x4a3a90), radius: 0, x: 0, y: 2); KT(sub, 6, .white, align: .center).opacity(0.9) }
                .frame(maxWidth: .infinity).padding(.vertical, 7).padding(.horizontal, 8)
                .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 9).fill(green ? Color(hex: 0x78d850) : Color(hex: 0x8a7ae0)); (green ? Color(hex: 0x4aa83a) : Color(hex: 0x6a5ac0)).frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 9)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(K.brown, lineWidth: 2))
        }.buttonStyle(PressStyle()).padding(.top, 6)
    }
}

// MARK: - Developer

struct DevPage: View {
    @State private var num = ""
    @State private var sure: String? = nil
    @State private var done: String? = nil
    @State private var tick = 0
    var body: some View {
        _ = tick
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Sec(t: "Jump to"); Hint(t: "Starts a game there (practice: best scores are not saved)")
                Flow(spacing: 4) {
                    ForEach([("Start (0)", 0), ("100", 100), ("500", 500), ("900", 900), ("920 Walls", 920), ("975 Plants", 975), ("985 Blood", 985), ("996 Ending", 996), ("1011 Birds", 1011), ("1013 Swarm", 1013), ("-1 Run", -1)], id: \.0) { l, n in Opt(t: l, on: false) { haptic(); playSound("swoosh"); devJump(n) } }
                }.padding(.bottom, 8)
                HStack(spacing: 6) { Field(ph: "Any score", text: $num, numeric: true).padding(.bottom, -6); MkBtn("Go", .save) { if let n = Int(num), n >= 0 { devJump(n) } }.frame(width: 70) }.padding(.bottom, 10)
                Sec(t: "Cheats"); Hint(t: "Only for this visit")
                Flow(spacing: 4) {
                    Opt(t: "God mode", on: devGod) { devGod.toggle(); tick += 1 }
                    Opt(t: "Slow motion", on: devSlow) { devSlow.toggle(); tick += 1 }
                    Opt(t: "Hitboxes", on: devBoxes) { devBoxes.toggle(); tick += 1 }
                    Opt(t: "Speed meter", on: SHOW_FPS) { SHOW_FPS.toggle(); tick += 1 }
                    Opt(t: "Autoplay", on: autoplay) { autoplay.toggle(); saveBool("autoplay", autoplay); botTimer = 0; tick += 1 }
                }.padding(.bottom, 8)
                Sec(t: "Ending")
                Flow(spacing: 4) { Opt(t: "Haunted mode", on: haunted) { devHaunt(!haunted); tick += 1 } }.padding(.bottom, 8)
                Sec(t: "Reset"); Hint(t: "Tap twice to confirm")
                Flow(spacing: 4) {
                    resetOpt("Best scores") { removeKeys { $0.hasPrefix("fb_bestScore") }; resultBestLabel = String(bestScore()) }
                    resetOpt("Ghost runs") { removeKeys { $0.hasPrefix("fb_ghost") }; ghostCache = [:] }
                    resetOpt("Favorites") { favBirds = []; saveFavs(); if birdPick == "favs" { birdPick = "random"; saveStr("birdPick", "random") } }
                    resetOpt("My birds") {
                        for cb in customBirds { unregisterCustom(cb.id) }
                        favBirds = favBirds.filter { !$0.hasPrefix("custom_") }; saveFavs(); customBirds = []; saveCustomBirds()
                        if birdPick.hasPrefix("custom_") { birdPick = "random"; saveStr("birdPick", "random") }
                    }
                    resetOpt("Settings") {
                        setGameMode("normal"); weatherPick = "auto"; seasonPick = "auto"; birdPick = "random"
                        for (k, v) in [("weather", "auto"), ("season", "auto"), ("birdPick", "random")] { saveStr(k, v) }
                        playSounds = true; saveBool("playSounds", true); autoplay = false; saveBool("autoplay", false); ghostOn = false; saveBool("ghostOn", false)
                        rollWeather(); hauntedMusicSync()
                    }
                    resetOpt("Everything") { removeKeys { $0.hasPrefix("fb_") }; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { reloadEverything() } }
                }.padding(.bottom, 8)
                MkBtn("Turn off developer mode", .del) { devMode = false; devGod = false; devSlow = false; devBoxes = false; saveBool("devMode", false); playSound("swoosh"); showPage("settings") }
            }
        }
    }
    private func resetOpt(_ label: String, _ fn: @escaping () -> Void) -> some View {
        Opt(t: done == label ? "Done!" : sure == label ? "Sure?" : label, on: false, warn: sure == label) {
            haptic(); playSound("swoosh")
            if sure != label { sure = label; DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { if sure == label { sure = nil } }; return }
            fn(); sure = nil; done = label; playSound("point"); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if done == label { done = nil } }
        }
    }
}
func removeKeys(_ test: (String) -> Bool) { var ks: [String] = []; for i in 0..<localStorage.length { if let k = localStorage.key(i), test(k) { ks.append(k) } }; ks.forEach { localStorage.removeItem($0) } }
func devJump(_ n: Int) {
    closePicker()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
        afterlife = 0
        if n == -1 { afterlife = 1; START_SCORE = 0 } else { START_SCORE = max(0, min(1013, n)) }
        hitButton = false
        handlePlayTap()
    }
}
func devHaunt(_ on: Bool) {
    haunted = on; saveBool("haunted", on)
    if !on { DEATHS = []; localStorage.removeItem("fb_deaths") }
    hauntedMusicSync(); birdChanged(); updateSky()
}

// MARK: - Replay theater

func drawReplayFrame(_ g: CGCanvas, _ W: Double, _ H: Double, _ F: RPFrame, _ cam: (x: Double, y: Double, z: Double, tilt: Double), _ tAll: Double, _ k: Double) {
    let M = RP.meta, z = cam.z
    g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.imageSmoothingEnabled = false
    g.fill(M?.night == true ? "#008793" : "#4ec0ca"); g.fillRect(0, 0, W, H)
    g.setTransform(z, 0, 0, z, W / 2 - cam.x * z, H / 2 - (SH - cam.y) * z)
    if cam.tilt != 0 { g.translate(cam.x, SH - cam.y); g.rotate(cam.tilt); g.translate(-cam.x, -(SH - cam.y)) }
    let sky = M?.night == true ? img("night_sky") : img("day_sky"), skyW = 288 * 1.5, skyH = 512 * 1.5, skyCY = skyH / 3.5 + 224
    if let s = sky { for i in -1..<4 { g.drawImage(s, F.sx + Double(i) * (skyW - 1) - skyW / 2, SH - (skyCY + skyH / 2), skyW, skyH) } }
    for (gx, y, gap, red, _) in F.p {
        let up = red ? img("red_up") : img("pipe_up"), down = red ? img("red_down") : img("pipe_down")
        let upTop = -352 + y + 512, downCY = -352 + y + 1024 + gap
        g.drawImage(up, gx - 30, SH - upTop, 60, 1024)
        g.drawImage(down, gx - 30, SH - (downCY + 512), 60, 1024)
    }
    if let bim = img((M?.skin ?? "yellow") + "_\(F.bf)") ?? img("yellow_2") {
        g.save(); g.translate(F.bx, SH - F.by); g.rotate(-F.br); let w = Double(bim.width) * 1.5, h = Double(bim.height) * 1.5; g.drawImage(bim, -w / 2, -h / 2, w, h); g.restore()
    }
    if let l = img("land") { for i in -1..<4 { g.drawImage(l, F.gx + Double(i) * (672 - 1) - 336, SH - 224, 672, 224) } }
    g.restore()
    g.fill("#000"); g.fillRect(0, 0, W, H * 0.07); g.fillRect(0, H * 0.93, W, H * 0.07)
    g.font = "\(jsRound(W * 0.045))px \"04b19\", monospace"; g.textBaseline = "middle"
    if Int(floor(tAll * 2)) % 2 == 0 { g.fill("#ff3b3b"); g.beginPath(); g.arc(W * 0.05, H * 0.035, W * 0.012, 0, 7); g.fill() }
    g.textAlign = "left"; g.fill("#fff"); g.fillText("REPLAY", W * 0.08, H * 0.037)
    g.textAlign = "right"; g.fillText((k < 1 ? "\(k)x" : "") + "  \(F.s)", W * 0.96, H * 0.037)
}
func replayCam(_ frames: [RPFrame], _ i: Int, _ angle: String, _ f: Double) -> (x: Double, y: Double, z: Double, tilt: Double) {
    let F = frames[i]
    if angle == "wide" { return (F.bx + 160, 384, 0.62, 0) }
    if angle == "close" { return (F.bx + 40, max(260, min(620, F.by)), 1.7, 0) }
    let p = min(1, f), zz = 0.75 + p * p * 1.35
    return (F.bx + 120 * (1 - p), 384 + (max(260, min(620, F.by)) - 384) * p, zz, p > 0.75 ? (p - 0.75) * 0.35 : 0)
}
final class ReplayModel: ObservableObject {
    let frames = RP.frames
    @Published var pos = 0.0, playing = true, k = 0.5, angle = "cinematic"
    var t = 0.0, last = Date()
    let cv = CGCanvas(540, 540)
    func frameAt(_ pos: Double) -> RPFrame {
        let i = max(0, min(frames.count - 1, Int(floor(pos)))), j = min(frames.count - 1, i + 1), f = pos - Double(i), A = frames[i], B = frames[j]
        func L(_ a: Double, _ b: Double) -> Double { a + (b - a) * f }
        var o = A
        o.bx = L(A.bx, B.bx); o.by = L(A.by, B.by); o.br = L(A.br, B.br)
        o.gx = abs(B.gx - A.gx) < 200 ? L(A.gx, B.gx) : A.gx; o.sx = abs(B.sx - A.sx) < 200 ? L(A.sx, B.sx) : A.sx
        o.p = A.p.map { pa in let pb = B.p.first { abs($0.1 - pa.1) < 0.01 && abs($0.0 - pa.0) < 40 } ?? pa; return (L(pa.0, pb.0), pa.1, pa.2, pa.3, pa.4) }
        return o
    }
    func tick() -> Img {
        let dt = min(0.1, Date().timeIntervalSince(last)); last = Date(); t += dt
        if playing { pos += dt * RP_HZ * k; if pos >= Double(frames.count - 1) { pos = Double(frames.count - 1); playing = false } }
        let i = Int(floor(pos)), F = frameAt(pos)
        drawReplayFrame(cv, 540, 540, F, replayCam(frames, i, angle, pos / Double(frames.count - 1)), t, k)
        return cv.image()
    }
}
struct ReplayPage: View {
    @StateObject private var m = ReplayModel()
    @State private var saving = ""
    var body: some View {
        if m.frames.count < 2 { Note(t: "Play a round first.") } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    TimelineView(.animation) { _ in Image(uiImage: m.tick().ui).resizable().interpolation(.none).aspectRatio(1, contentMode: .fit) }
                        .frame(maxWidth: 280).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 3)).padding(.bottom, 6)
                    Slider(value: Binding(get: { m.pos }, set: { m.pos = $0; m.playing = false }), in: 0...Double(m.frames.count - 1)).tint(K.orange).padding(.bottom, 6)
                    HStack(spacing: 5) {
                        MkBtn(m.playing ? "Pause" : "Play", .save) { m.playing.toggle(); if m.playing && m.pos >= Double(m.frames.count - 1) { m.pos = 0 }; haptic() }
                        MkBtn("Restart") { m.pos = 0; m.playing = true; haptic() }
                        MkBtn("\(m.k == 1 ? "1" : m.k == 0.5 ? "0.5" : "0.25")x") { m.k = m.k == 0.5 ? 0.25 : m.k == 0.25 ? 1 : 0.5; haptic() }
                    }.padding(.bottom, 6)
                    Sec(t: "Camera")
                    Flow(spacing: 4) { ForEach([("cinematic", "Cinematic"), ("close", "Close-up"), ("wide", "Wide")], id: \.0) { id, n in Opt(t: n, on: m.angle == id) { m.angle = id; haptic(); playSound("swoosh") } } }.padding(.bottom, 8)
                    MkBtn(saving.isEmpty ? "Save clip" : saving, .share) { saveClip() }
                }
            }
        }
    }
    /// records the replay as a video (like the website's MediaRecorder), then offers to share it
    private func saveClip() {
        if !saving.isEmpty { return }
        saving = "Recording..."
        let frames = m.frames, k = m.k, angle = m.angle
        DispatchQueue.global(qos: .userInitiated).async {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("flappy-bird-replay.mp4")
            try? FileManager.default.removeItem(at: url)
            guard let w = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
            let inp = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 540, AVVideoHeightKey: 540])
            let ad = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: inp, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 540, kCVPixelBufferHeightKey as String: 540])
            w.add(inp); w.startWriting(); w.startSession(atSourceTime: .zero)
            let model = ReplayModel(); let total = Int(Double(frames.count) / RP_HZ / k * 30)
            for n in 0..<max(1, total) {
                let pos = min(Double(frames.count - 1), Double(n) / 30 * RP_HZ * k)
                let F = model.frameAt(pos)
                DispatchQueue.main.sync { drawReplayFrame(model.cv, 540, 540, F, replayCam(frames, Int(floor(pos)), angle, pos / Double(frames.count - 1)), Double(n) / 30, k) }
                let im = model.cv.image().cg
                while !inp.isReadyForMoreMediaData { usleep(2000) }
                var pb: CVPixelBuffer?
                CVPixelBufferCreate(nil, 540, 540, kCVPixelFormatType_32ARGB, nil, &pb)
                guard let b = pb else { continue }
                CVPixelBufferLockBaseAddress(b, [])
                let c = CGContext(data: CVPixelBufferGetBaseAddress(b), width: 540, height: 540, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(b), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                c?.draw(im, in: CGRect(x: 0, y: 0, width: 540, height: 540))
                CVPixelBufferUnlockBaseAddress(b, [])
                ad.append(b, withPresentationTime: CMTime(value: CMTimeValue(n), timescale: 30))
            }
            inp.markAsFinished()
            w.finishWriting { DispatchQueue.main.async { saving = "Share clip"; share([url]); DispatchQueue.main.asyncAfter(deadline: .now() + 1) { saving = "" } } }
        }
    }
}
