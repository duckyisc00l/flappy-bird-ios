import SwiftUI

// MARK: - little pictures made from the game's own sprites (the website's drawModeIcon / weatherIcon)

func drawModeIcon(_ id: String) -> Img {
    let S = 84.0, GROUND = 68.0
    let g = CGCanvas(84, 84); g.imageSmoothingEnabled = false
    let sky = id == "dark" ? img("night_sky") : img("day_sky")
    g.fill(id == "dark" ? "#008793" : "#4ec0ca"); g.fillRect(0, 0, S, GROUND)
    if let s = sky { g.drawImage(s, 60, 402 - 20, S, 20, 0, GROUND - 20, S, 20) }
    let up = id == "hard" ? img("red_up") : img("pipe_up"), down = id == "hard" ? img("red_down") : img("pipe_down")
    func pair(_ x: Double, _ gapTop: Double, _ gap: Double) {
        if let d = down { g.drawImage(d, 0, 512 - gapTop, 30, gapTop, x, 0, 30, gapTop) }
        let lo = gapTop + gap
        if let u = up { g.drawImage(u, 0, 0, 30, GROUND - lo, x, lo, 30, GROUND - lo) }
    }
    let gap = id == "tiny" ? 28.0 : id == "hard" ? 32 : 38
    if id == "wavy" { pair(44, 10, 38); pair(78, 26, 38) }
    else if id == "hard" { pair(42, 22, gap); pair(76, 12, gap) }
    else { pair(48, id == "tiny" ? 24 : 16, gap) }
    if let l = img("land") { g.drawImage(l, 0, 0, S, S - GROUND, 0, GROUND, S, S - GROUND) }
    let bx = 6.0, by = id == "tiny" ? 26.0 : 22
    if id == "turbo" { g.fill("rgba(255,255,255,0.9)"); for (x, y, w) in [(0.0, by + 6, 6.0), (0, by + 12, 8), (0, by + 18, 5)] { g.fillRect(x, y, w, 2) } }
    if id == "windy" {
        g.fill("rgba(255,255,255,0.95)")
        for (x, y, w) in [(4.0, 8.0, 22.0), (8, 54, 18), (52, 60, 18)] { g.fillRect(x, y, w, 2); g.fillRect(x + w, y - 2, 2, 2); g.fillRect(x + w + 2, y - 4, 2, 2); g.fillRect(x + w, y - 6, 2, 2) }
    }
    if let b = img("yellow_2") {
        g.save(); g.translate(bx + 17, by + 12)
        if id == "flipped" { g.scale(1, -1) }
        if id == "turbo" { g.rotate(-0.25) }
        g.drawImage(b, -17, -12); g.restore()
    }
    if id == "wavy" { g.fill("#fff"); let ax = 70.0, ay = 4.0; g.fillRect(ax, ay, 2, 12); g.fillRect(ax - 2, ay + 2, 6, 2); g.fillRect(ax - 4, ay + 4, 10, 2); g.fillRect(ax - 2, ay + 8, 6, 2); g.fillRect(ax - 4, ay + 6, 10, 2) }
    if id == "dark" {
        let r = g.createRadialGradient(bx + 17, by + 12, 5, bx + 17, by + 12, 34)
        r.addColorStop(0, "rgba(4,4,12,0)"); r.addColorStop(0.6, "rgba(4,4,12,0.55)"); r.addColorStop(1, "rgba(4,4,12,0.95)")
        g.fillStyle = .gradient(r); g.fillRect(0, 0, S, S)
    }
    if id == "flipped" {
        let c2 = g.image(); let f = CGCanvas(84, 84); f.imageSmoothingEnabled = false
        f.translate(0, S); f.scale(1, -1); f.drawImage(c2, 0, 0); return f.image()
    }
    return g.image()
}
func weatherIcon() -> Img {
    let g = CGCanvas(24, 24); g.imageSmoothingEnabled = false
    func put(_ im: Img?, _ sc: Double) { if let im = im { g.drawImage(im, jsRound((24 - Double(im.width) * sc) / 2), jsRound((24 - Double(im.height) * sc) / 2), Double(im.width) * sc, Double(im.height) * sc) } }
    let w: String? = weatherPick != "auto" ? weatherPick : nil, s = seasonPick == "auto" ? seasonByDate(Date()) : seasonPick
    func P(_ x: Double, _ y: Double, _ ww: Double, _ hh: Double, _ c: String) { g.fill(c); g.fillRect(x, y, ww, hh) }
    func cloud(_ c: String) { P(5, 7, 14, 6, c); P(7, 5, 6, 2, c); P(12, 4, 5, 3, c) }
    if w == "rain" || w == "storm" { cloud(w == "storm" ? "#4a5068" : "#8a94a8"); for i in 0..<4 { P(6 + Double(i) * 4, 15 + Double(i % 2) * 2, 1, 3, "#7ab8ff") }; if w == "storm" { P(12, 13, 2, 3, "#ffe14a"); P(10, 16, 3, 2, "#ffe14a"); P(10, 18, 2, 3, "#ffe14a") } }
    else if w == "snow" { cloud("#c9ccd6"); for (x, y) in [(6.0, 16.0), (11, 19), (16, 15), (14, 21), (8, 21)] { P(x, y, 2, 2, "#ffffff") } }
    else if w == "fog" { for i in 0..<4 { P(3 + Double(i % 2) * 3, 6 + Double(i) * 4, 16, 2, "#dfe3e8") } }
    else if w == "windy" { P(3, 7, 12, 2, "#ffffff"); P(15, 5, 2, 2, "#ffffff"); P(5, 12, 15, 2, "#ffffff"); P(6, 17, 10, 2, "#ffffff"); P(16, 19, 2, 2, "#ffffff") }
    else if w == "clear" || s == "classic" || s == "summer" { put(wxArt("sun"), 1) }
    else if s == "halloween" { put(pix("pumpkin"), 2) }
    else if s == "christmas" { put(pix("tree1"), 1.5) }
    else if s == "spring" { put(pix("flowerP"), 4) }
    else if s == "fall" { put(pix("leafpile"), 2) }
    else if s == "valentine" { put(pix("heart"), 3) }
    else if s == "winter" { for (x, y) in [(11.0, 3.0), (11, 19), (4, 11), (18, 11)] { P(x, y, 2, 2, "#ffffff") }; P(11, 5, 2, 14, "#e6f4ff"); P(5, 11, 14, 2, "#e6f4ff") }
    else { for (x, y, c) in [(11.0, 4.0, "#ff3b3b"), (5, 10, "#ffd23b"), (17, 10, "#3bb0ff"), (8, 17, "#3bff6b"), (15, 17, "#ff6bf0"), (11, 11, "#ffffff")] { P(x, y, 3, 3, c) } }
    return g.image()
}
func modeBest(_ id: String) -> Int { Int(localStorage.getItem("fb_bestScore" + modeSuffix(id)) ?? "0") ?? 0 }

// MARK: - Settings (one card: Mode / Bird / Weather tiles + rows)

struct SettingsPage: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var verTaps = 0
    @State private var verAt = Date.distantPast
    @State private var verText = ""
    @State private var show: String? = nil
    var body: some View {
        _ = ui.tick
        let pickName = birdPick == "random" ? "Random" : birdPick == "favs" ? "Favorites" : skinExists(birdPick) ? skinName(birdPick) : "Random"
        let wName = weatherPick == "auto" && seasonPick == "auto" ? "Auto" : (weatherPick != "auto" ? WEATHERS.first { $0.0 == weatherPick }!.2 : SEASONS.first { $0.0 == seasonPick }!.2)
        return VStack(spacing: 0) {
            HStack(spacing: 5) {
                tile("modes", "Mode", modeInfo().title) { PixImage(img: drawModeIcon(gameMode), w: 44, h: 44) }
                tile("birds", "Bird", pickName) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { c in
                        let n = Int(c.date.timeIntervalSinceReferenceDate * 10)
                        PixImage(img: skinCanvas(tileBird(n), [1, 2, 3, 2][n % 4]), w: 36, h: 30)
                    }
                }
                tile("weather", "Weather", wName) { PixImage(img: weatherIcon(), w: 36, h: 36) }
            }.padding(.bottom, 7)
            FitScroll {
                VStack(spacing: 0) {
                    row("Account", trailing: AnyView(Arrow())) { playSound("swoosh"); haptic(); accGo(accSignedIn() ? "profile" : "account", accSignedIn() ? ACCT.uid : nil) }
                    row("Join a TV party", trailing: AnyView(Arrow())) { playSound("swoosh"); accGo("partycode") }
                    row("Notifications", trailing: AnyView(Arrow())) { playSound("swoosh"); accGo("notify") }
                    row("Trail", trailing: AnyView(HStack(spacing: 10) { KT(trailDef(trailPick)?.name ?? "None", 6).opacity(0.75).lineLimit(1).frame(maxWidth: 90, alignment: .trailing); Arrow() })) { playSound("swoosh"); haptic(); showPage("trails") }
                    row("Haptics", trailing: AnyView(Sw(on: haptics))) { haptics.toggle(); saveBool("appHaptics", haptics); if haptics { appHaptic("medium") }; playSound("swoosh"); ui.refresh() }
                    row("Sound", trailing: AnyView(Sw(on: playSounds))) { handleSoundToggle(); ui.refresh() }
                    row("Autoplay", trailing: AnyView(Sw(on: autoplay))) { handleAutoplayToggle(); ui.refresh() }
                    row("Ghost", trailing: AnyView(Sw(on: ghostOn)), last: !devMode) { handleGhostToggle(); ui.refresh() }
                    if devMode { row("Developer", color: K.blue, trailing: AnyView(Arrow()), last: true) { playSound("swoosh"); haptic(); showPage("dev") } }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: 8).fill(K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
            Button {
                if devMode { return }
                if Date().timeIntervalSince(verAt) > 1.5 { verTaps = 0 }
                verAt = Date(); verTaps += 1
                let left = 5 - verTaps
                if left > 0 { if verTaps >= 2 { verText = "\(left)" + (left == 1 ? " more tap" : " more taps") + " to developer mode" }; playSound("point"); return }
                devMode = true; saveBool("devMode", true); playSound("swoosh"); haptic(); showPage("settings")
            } label: { KT(verText.isEmpty ? "Version \(APP_VERSION)" + (devMode ? " - developer" : "") : verText, 6).opacity(0.65).padding(3) }
                .buttonStyle(.plain).padding(.top, 4)
        }
    }
    private func tileBird(_ n: Int) -> String {
        if skinExists(birdPick) { return birdPick }
        let pool = birdPick == "favs" && !favBirds.isEmpty ? favBirds : allSkins()
        if show == nil || n % 10 == 0 { DispatchQueue.main.async { show = pool[Int(floor(mrand() * Double(pool.count)))] } }
        return show ?? "yellow"
    }
    private func tile<I: View>(_ kind: String, _ label: String, _ value: String, @ViewBuilder icon: () -> I) -> some View {
        Button { playSound("swoosh"); haptic(); showPage(kind) } label: {
            VStack(spacing: 3) {
                ZStack { K.sky; icon() }.frame(width: 44, height: 40).clipShape(RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(K.brown, lineWidth: 2))
                KT(label, 8, K.orange, shadow: Color(hex: 0xfff6c8))
                KT(value, 6, lines: 1).truncationMode(.tail).padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity).padding(.top, 5).padding(.bottom, 5).padding(.horizontal, 2)
            .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 8).fill(K.light); K.line2.frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 8)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
        }.buttonStyle(PressStyle(scale: 0.97))
    }
    private func row(_ name: String, color: Color = K.orange, trailing: AnyView, last: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 0) {
                HStack(spacing: 10) { KT(name, 8, color, shadow: K.cream).frame(maxWidth: .infinity, alignment: .leading); trailing }
                    .padding(.vertical, 7).padding(.horizontal, 9).frame(minHeight: 33)
                if !last { K.line2.frame(height: 1) }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Birds

struct BirdsPage: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var q = ""
    @State private var cat = "All"
    @State private var pick = birdPick
    @State private var favTick = 0
    var body: some View {
        let ids = allSkins()
        var counts: [String: Int] = [:]; for id in ids { counts[skinCat(id), default: 0] += 1 }
        let chips: [(String, Int?)] = [("All", ids.count), ("My Birds", counts["My Birds"] ?? 0), ("Favorites", nil)] + CAT_ORDER.filter { (counts[$0] ?? 0) > 0 && $0 != "My Birds" }.map { ($0, counts[$0]) }
        let s = q.trimmingCharacters(in: .whitespaces).lowercased()
        var list = ids.filter { cat == "All" || (cat == "Favorites" ? favBirds.contains($0) : skinCat($0) == cat) }
        if !s.isEmpty { list = list.filter { skinName($0).lowercased().contains(s) || $0.contains(s) || skinCat($0).lowercased().contains(s) } }
        var cells: [String] = []
        if s.isEmpty && (cat == "All" || cat == "My Birds") { cells += ["new", "import"] }
        if s.isEmpty && (cat == "All" || cat == "Favorites") { cells.append("random"); if !favBirds.isEmpty { cells.append("favs") } }
        cells += list
        let countText = !list.isEmpty ? "\(list.count.formatted())" + (list.count == 1 ? " bird" : " birds") : (cat == "Favorites" && s.isEmpty ? "No favorites yet: pick a bird and tap the star" : cat == "My Birds" && s.isEmpty ? "Tap + to make your own bird" : "No birds found")
        return VStack(spacing: 0) {
            preview
            Field(ph: "Search \(ids.count.formatted()) birds", text: $q)
            HStack(spacing: 6) {
                KT("Show", 7).opacity(0.75)
                Menu {
                    ForEach(chips, id: \.0) { c in Button(c.1 == nil ? c.0 : "\(c.0) (\(c.1!.formatted()))") { cat = c.0; haptic() } }
                } label: {
                    HStack { KT(chipLabel(chips), 11, .white, lines: 1).frame(maxWidth: .infinity, alignment: .leading); Image(systemName: "chevron.down").font(.system(size: 9, weight: .black)).foregroundColor(.white) }
                        .padding(.vertical, 6).padding(.leading, 10).padding(.trailing, 9).background(Capsule().fill(K.orange)).overlay(Capsule().stroke(K.brown, lineWidth: 2))
                }
            }.padding(.bottom, 6)
            KT(countText, 6).opacity(0.7).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 2).padding(.bottom, 4)
            ScrollViewReader { sr in
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 4)], spacing: 4) {
                        ForEach(cells, id: \.self) { id in cell(id).id(id) }
                    }.padding(2)
                }
                .onAppear { if skinExists(birdPick) { DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { sr.scrollTo(birdPick, anchor: .center) } } }
            }
        }
    }
    private func chipLabel(_ chips: [(String, Int?)]) -> String { let c = chips.first { $0.0 == cat } ?? ("All", nil); return c.1 == nil ? c.0 : "\(c.0) (\(c.1!.formatted()))" }
    private var preview: some View {
        let id = pick, real = skinExists(id) && id != "random" && id != "favs"
        return HStack(spacing: 8) {
            ZStack {
                if real { BirdView(id: id, w: 54, h: 45) }
                else { TimelineView(.periodic(from: .now, by: 0.1)) { c in let n = Int(c.date.timeIntervalSinceReferenceDate * 10); let pool = id == "favs" && !favBirds.isEmpty ? favBirds : allSkins(); PixImage(img: skinCanvas(pool[(n / 6 * 7919) % pool.count], [1, 2, 3, 2][n % 4]), w: 54, h: 45) } }
            }.frame(width: 54, height: 45).background(K.sky).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(K.brown, lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                KT(real ? skinName(id) : (id == "favs" ? "Random favorite" : "Random bird"), 9, K.orange, shadow: K.cream, lines: 1)
                KT(real ? skinCat(id) : (id == "favs" ? "\(favBirds.count) favorites" : "A new bird every game"), 6).opacity(0.8)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if real && id.hasPrefix("custom_") {
                Button { playSound("swoosh"); PK.makerId = id; showPage("maker") } label: { Text("\u{270E}").font(.system(size: 16)).foregroundColor(K.brown).frame(width: 32, height: 32).background(Circle().fill(K.light)).overlay(Circle().stroke(K.brown, lineWidth: 2)) }.buttonStyle(.plain)
            }
            if real {
                let on = favBirds.contains(id)
                Button {
                    if let i = favBirds.firstIndex(of: id) { favBirds.remove(at: i) } else { favBirds.append(id) }
                    saveFavs(); haptic(); playSound("point"); favTick += 1
                } label: { Text("\u{2605}").font(.system(size: 16)).foregroundColor(on ? .white : K.line).shadow(color: on ? Color(hex: 0xc88a10) : .clear, radius: 0, x: 0, y: 2).frame(width: 32, height: 32).background(Circle().fill(on ? Color(hex: 0xffd23c) : K.cream)).overlay(Circle().stroke(K.brown, lineWidth: 2)) }
                    .buttonStyle(PressStyle(scale: 1.2, dy: 0)).id(favTick)
            }
        }
        .padding(.vertical, 5).padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
        .padding(.bottom, 6)
    }
    @ViewBuilder private func cell(_ id: String) -> some View {
        let sel = id == pick
        Button {
            if id == "new" { playSound("swoosh"); PK.makerId = nil; showPage("maker"); return }
            if id == "import" { playSound("swoosh"); showPage("import"); return }
            birdPick = id; saveStr("birdPick", id); haptic(); playSound("swoosh"); pick = id
        } label: {
            VStack(spacing: 0) {
                Group {
                    if id == "new" || id == "import" || id == "random" || id == "favs" {
                        let sym = ["new": "+", "import": "\u{21E9}", "random": "?", "favs": "\u{2605}"][id]!
                        if id == "import" { Text(sym).font(.system(size: 26, weight: .bold)).foregroundColor(K.blue) }
                        else { OutlinedTitle(t: sym, size: 26, color: id == "new" ? K.green : .white, drop: 4) }
                    } else { BirdView(id: id, w: 54, h: 45) }
                }.frame(width: 54, height: 45)
                KT(["new": "Make a bird", "import": "Import a bird", "random": "Random", "favs": "Random favorite"][id] ?? skinName(id), 5, align: .center, lines: 2, spacing: 1)
                    .frame(height: 14, alignment: .top).padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity).padding(.top, 3).padding(.bottom, 2).padding(.horizontal, 1)
            .tile(sel)
        }.buttonStyle(PressStyle(scale: 0.95, dy: 0))
    }
}

// MARK: - Modes

struct ModesPage: View {
    @State private var sel = gameMode
    var body: some View {
        VStack(spacing: 0) {
            Note(t: "Every mode keeps its own best score and ghost. From 920 on, the ending always plays the normal way.")
            FitScroll {
                VStack(spacing: 5) {
                    ForEach(MODES, id: \.id) { m in
                        Button {
                            setGameMode(m.id); haptic(); sel = m.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { if !PK.open { return }; if PK.fromSettings { playSound("swoosh"); showPage("settings") } else { closePicker() } }
                        } label: {
                            HStack(spacing: 8) {
                                PixImage(img: drawModeIcon(m.id), w: 40, h: 40, bg: K.sky, radius: 6, border: K.brown, smooth: true)
                                VStack(alignment: .leading, spacing: 0) {
                                    OutlinedTitle(t: m.title, size: 14, outline: 2, drop: 3)
                                    KT(m.desc, 6, spacing: 3).padding(.top, 3).padding(.bottom, 2)
                                    let b = modeBest(m.id); KT(b > 0 ? "Best \(b)" : "Not played yet", 6, K.orange)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 5).padding(.horizontal, 7)
                            .tile(m.id == sel, radius: 8)
                        }.buttonStyle(PressStyle(scale: 0.98, dy: 0))
                    }
                }.padding(2)
            }
        }
    }
}

// MARK: - Weather

struct WeatherPage: View {
    @State private var tick = 0
    var body: some View {
        _ = tick
        let sToday = seasonByDate(Date())
        func sName(_ id: String) -> String { SEASONS.first { $0.0 == id }!.2 }
        let status = "Today is " + sName(sToday) + ". Now showing: " + sName(WX.season) + ", " + (WEATHERS.first { $0.0 == WX.weather }?.2.lowercased() ?? "") + "."
        return FitScroll {
            VStack(alignment: .leading, spacing: 0) {
                Sec(t: "Weather")
                Flow(spacing: 4) { ForEach(WEATHERS, id: \.0) { w in Opt(t: w.2, on: weatherPick == w.0) { weatherPick = w.0; saveStr("weather", w.0); haptic(); playSound("swoosh"); rollWeather(); tick += 1 } } }.padding(.bottom, 8)
                Sec(t: "Season")
                Flow(spacing: 4) { ForEach(SEASONS, id: \.0) { w in Opt(t: w.2, on: seasonPick == w.0) { seasonPick = w.0; saveStr("season", w.0); haptic(); playSound("swoosh"); rollWeather(); tick += 1 } } }.padding(.bottom, 8)
                Note(t: status)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Trails

final class TrailTiles: ObservableObject {
    var states: [String: TrailState] = [:]
    var cv: [String: CGCanvas] = [:]
    func frame(_ id: String) -> Img {
        let st = states[id] ?? { let s = TrailState(); states[id] = s; return s }()
        let c = cv[id] ?? { let c = CGCanvas(108, 90); cv[id] = c; return c }()
        drawTrailIcon(c, id, st, 1.0 / 12)
        return c.image()
    }
}
struct TrailsPage: View {
    @StateObject private var tiles = TrailTiles()
    @State private var sel = trailPick
    var body: some View {
        VStack(spacing: 0) {
            Note(t: "100 trails and effects. They follow you while you fly; some burst when you flap or score.")
            FitScroll {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 4)], spacing: 4) {
                    tile("none", "None")
                    ForEach(Array(cats.enumerated()), id: \.offset) { _, c in
                        Section(header: KT(c, 8, K.orange, shadow: K.cream).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6).padding(.horizontal, 2).padding(.bottom, 1)) {
                            ForEach(TRAILS.filter { $0.cat == c }, id: \.id) { t in tile(t.id, t.name) }
                        }
                    }
                }.padding(2)
            }
        }
    }
    private var cats: [String] { var out: [String] = []; for t in TRAILS where !out.contains(t.cat) { out.append(t.cat) }; return out }
    private func tile(_ id: String, _ name: String) -> some View {
        Button { setTrail(id); playSound("swoosh"); haptic(); sel = id } label: {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 1.0 / 12)) { _ in PixImage(img: tiles.frame(id), w: 66, h: 55, radius: 4) }
                KT(name, 5, align: .center, lines: 2, spacing: 1).frame(height: 14, alignment: .top)
            }.frame(maxWidth: .infinity).padding(.top, 3).padding(.bottom, 2).tile(sel == id)
        }.buttonStyle(PressStyle(scale: 0.95, dy: 0))
    }
}
