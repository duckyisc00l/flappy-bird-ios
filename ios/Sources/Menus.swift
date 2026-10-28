import SwiftUI

// MARK: - Modes (+ the Daily Challenge)
struct ModesView: View {
    @EnvironmentObject var g: GameModel
    var body: some View {
        Panel(title: "Modes", onClose: { g.sheet = nil }) {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Every mode keeps its own best score.").font(Px.text(8)).foregroundColor(Px.brown).frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(Modes.all, id: \.id) { m in
                        Button { Prefs.mode = m.id; g.choicesChanged(); g.sheet = nil } label: {
                            Card(on: m.id == Prefs.mode) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack { Text(m.title.uppercased()).font(Px.text(13)); Spacer(); if Prefs.best(m.id) > 0 { Text("BEST \(Prefs.best(m.id))").font(Px.text(9)).foregroundColor(Px.orange) } }
                                    Text((m.id == "daily" ? "The same pipes for everyone today. New pipes in \(Daily.hoursLeft)h." : m.desc).uppercased()).font(Px.text(8)).lineSpacing(3)
                                }.foregroundColor(Px.brown)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
        }
    }
}

// MARK: - Birds (2,265, by category, with search)
struct BirdsView: View {
    @EnvironmentObject var g: GameModel
    @State private var cat = "All"
    @State private var q = ""
    private var shown: [BirdInfo] {
        let base = cat == "All" ? Birds.shared.all : Birds.shared.birds(in: cat)
        let s = q.trimmingCharacters(in: .whitespaces).lowercased()
        return s.isEmpty ? base : base.filter { $0.name.lowercased().contains(s) }
    }
    var body: some View {
        Panel(title: "Birds", onClose: { g.sheet = nil }) {
            VStack(spacing: 10) {
                TextField("Search \(Birds.shared.all.count) birds", text: $q).font(Px.text(11)).padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Px.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Px.line, lineWidth: 2))
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["All"] + Birds.shared.categories, id: \.self) { c in
                            Button { cat = c } label: { Text(c.uppercased()).font(Px.text(8)).padding(.vertical, 8).padding(.horizontal, 10)
                                .background(Capsule().fill(c == cat ? Px.orange : Px.light)).foregroundColor(c == cat ? .white : Px.brown).overlay(Capsule().stroke(Px.brown, lineWidth: 2)) }
                        }
                    }.padding(.vertical, 2)
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 12) {
                        if cat == "All" && q.isEmpty { tile("random", "Random") }
                        ForEach(shown, id: \.id) { b in tile(b.id, b.name) }
                    }.padding(.bottom, 30)
                }
            }.padding(.horizontal, 16)
        }
    }
    private func tile(_ id: String, _ name: String) -> some View {
        Button { Prefs.bird = id; g.choicesChanged(); g.sheet = nil } label: {
            VStack(spacing: 4) {
                ZStack {
                    BirdPic(id: id, size: 68, bg: id == "random" ? Px.hex(0x9b6bd6) : Px.sky)
                    if id == "random" { Image(systemName: "shuffle").font(.system(size: 22, weight: .black)).foregroundColor(.white) }
                }.overlay(RoundedRectangle(cornerRadius: 12).stroke(Prefs.bird == id ? Px.orange : Px.brown, lineWidth: Prefs.bird == id ? 4 : 2))
                Text(name.uppercased()).font(Px.text(7)).foregroundColor(Px.brown).lineLimit(2).multilineTextAlignment(.center).frame(height: 20)
            }
        }.buttonStyle(.plain)
    }
}

// MARK: - Trails (100)
struct TrailsView: View {
    @EnvironmentObject var g: GameModel
    @State private var cat = "All"
    var body: some View {
        Panel(title: "Trails", onClose: { g.sheet = nil }) {
            VStack(spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["All"] + Trails.shared.categories, id: \.self) { c in
                            Button { cat = c } label: { Text(c.uppercased()).font(Px.text(8)).padding(.vertical, 8).padding(.horizontal, 10)
                                .background(Capsule().fill(c == cat ? Px.orange : Px.light)).foregroundColor(c == cat ? .white : Px.brown).overlay(Capsule().stroke(Px.brown, lineWidth: 2)) }
                        }
                    }
                }
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                        if cat == "All" { tile("none", "None", nil) }
                        ForEach(Trails.shared.all.filter { cat == "All" || $0.cat == cat }, id: \.id) { t in tile(t.id, t.name, Trails.shared.icon(t)) }
                    }.padding(.bottom, 30)
                }
            }.padding(.horizontal, 16)
        }
    }
    private func tile(_ id: String, _ name: String, _ icon: UIImage?) -> some View {
        Button { Prefs.trail = id; g.choicesChanged(); g.sheet = nil } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Px.hex(0x26345e))
                    if let icon = icon { Image(uiImage: icon).interpolation(.none).resizable().aspectRatio(contentMode: .fit).padding(6) }
                    else { Image(systemName: "nosign").font(.system(size: 26, weight: .bold)).foregroundColor(.white) }
                }.frame(height: 64).overlay(RoundedRectangle(cornerRadius: 12).stroke(Prefs.trail == id ? Px.orange : Px.brown, lineWidth: Prefs.trail == id ? 4 : 2))
                Text(name.uppercased()).font(Px.text(7)).foregroundColor(Px.brown).lineLimit(2).multilineTextAlignment(.center).frame(height: 20)
            }
        }.buttonStyle(.plain)
    }
}

// MARK: - Seasons
struct SeasonsView: View {
    @EnvironmentObject var g: GameModel
    var body: some View {
        Panel(title: "Seasons", onClose: { g.sheet = .settings }) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Seasons.all, id: \.id) { s in
                        Button { Prefs.season = s.id; g.choicesChanged(); g.sheet = .settings } label: {
                            Card(on: s.id == Prefs.season) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(s.title.uppercased()).font(Px.text(12))
                                    if s.id == "auto" { Text("RIGHT NOW: \(Seasons.title(Seasons.byDate()).uppercased())").font(Px.text(8)) }
                                }.foregroundColor(Px.brown)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(16)
            }
        }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var g: GameModel
    @State private var sound = Prefs.sound
    @State private var haptics = Prefs.haptics
    var body: some View {
        Panel(title: "Settings", onClose: { g.sheet = nil }) {
            ScrollView {
                VStack(spacing: 10) {
                    row("Account", Account.shared.signedIn ? "Signed in as \(Account.shared.username)" : "Sign in to get on the leaderboard") { g.sheet = .account }
                    row("Join a TV party", "Use your phone as a controller for Flappy Bird on Apple TV") { g.sheet = .party }
                    row("Trail", Trails.shared.def(Prefs.trail)?.name ?? "None") { g.sheet = .trails }
                    row("Season", Seasons.title(Prefs.season)) { g.sheet = .seasons }
                    toggle("Sound", "Flaps, points and crashes", $sound) { Prefs.sound = $0 }
                    toggle("Haptics", "A light tap when you flap, a thud when you crash", $haptics) { Prefs.haptics = $0 }
                    Text("FLAPPY BIRD \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))  \u{00B7}  ALL SWIFT")
                        .font(Px.text(7)).foregroundColor(Px.brown.opacity(0.6)).padding(.top, 10)
                }.padding(16)
            }
        }
    }
    private func row(_ t: String, _ s: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) { Card { HStack { VStack(alignment: .leading, spacing: 5) { Text(t.uppercased()).font(Px.text(12)); Text(s.uppercased()).font(Px.text(8)).lineSpacing(3) }; Spacer(); Text("\u{203A}").font(Px.text(18)) }.foregroundColor(Px.brown) } }.buttonStyle(.plain)
    }
    private func toggle(_ t: String, _ s: String, _ v: Binding<Bool>, _ save: @escaping (Bool) -> Void) -> some View {
        Card { Toggle(isOn: Binding(get: { v.wrappedValue }, set: { v.wrappedValue = $0; save($0) })) {
            VStack(alignment: .leading, spacing: 5) { Text(t.uppercased()).font(Px.text(12)); Text(s.uppercased()).font(Px.text(8)).lineSpacing(3) }.foregroundColor(Px.brown)
        }.tint(Px.green) }
    }
}
