import SwiftUI

/// The game full screen, with the menu buttons on the title and Game Over screens (like the website).
struct RootView: View {
    @EnvironmentObject var g: GameModel
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GameView(scene: g.scene).ignoresSafeArea()
            if g.phase == .title || g.phase == .over { MenuButtons().transition(.opacity) }
            if g.phase == .playing && !g.paused {
                VStack { HStack { Spacer(); Button { g.setPaused(true) } label: { Image(systemName: "pause.fill").font(.system(size: 18, weight: .black)).foregroundColor(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(Px.brown.opacity(0.75))) }.padding(.trailing, 14).padding(.top, 8) }; Spacer() }
            }
            if g.paused { PausedView() }
            if let t = g.toast {
                VStack { Text(t).font(Px.text(11)).foregroundColor(.white).padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Px.brown.opacity(0.9))).padding(.top, 50); Spacer() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: g.phase)
        .animation(.easeOut(duration: 0.2), value: g.toast)
        .sheet(item: $g.sheet) { s in
            Group {
                switch s {
                case .modes: ModesView()
                case .birds: BirdsView()
                case .trails: TrailsView()
                case .seasons: SeasonsView()
                case .settings: SettingsView()
                case .leaderboard: LeaderboardView()
                case .account: AccountView()
                case .party: PartyView()
                }
            }.environmentObject(g)
        }
    }
}

/// Play, Daily, Party and the rest, under the bird
struct MenuButtons: View {
    @EnvironmentObject var g: GameModel
    var body: some View {
        let acc = Account.shared
        VStack(spacing: 10) {
            Spacer()
            Button { g.play() } label: { HStack(spacing: 10) { Image(systemName: "play.fill"); Text(g.phase == .over ? "PLAY AGAIN" : "PLAY") } }
                .buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 16))
            HStack(spacing: 10) {
                Button { g.playDaily() } label: { Label("DAILY", systemImage: "calendar") }.buttonStyle(PxButtonStyle(fill: Px.hex(0x26345e), fg: .white))
                Button { g.sheet = .leaderboard } label: { Label("BOARD", systemImage: "trophy.fill") }.buttonStyle(PxButtonStyle(fill: Px.hex(0xf5c542)))
            }
            HStack(spacing: 10) {
                Button { g.sheet = .modes } label: { VStack(spacing: 4) { Text("MODE"); Text(Modes.info(Prefs.mode).title.uppercased()).font(Px.text(8)).lineLimit(1) } }.buttonStyle(PxButtonStyle(size: 11))
                Button { g.sheet = .birds } label: { VStack(spacing: 4) { Text("BIRD"); Text(birdName.uppercased()).font(Px.text(8)).lineLimit(1) } }.buttonStyle(PxButtonStyle(size: 11))
            }
            HStack(spacing: 10) {
                Button { g.sheet = .account } label: { Label(acc.signedIn ? acc.username.uppercased() : "SIGN IN", systemImage: "person.fill").lineLimit(1) }.buttonStyle(PxButtonStyle(size: 10))
                Button { g.sheet = .party } label: { Label("TV PARTY", systemImage: "tv") }.buttonStyle(PxButtonStyle(fill: Px.hex(0x9b6bd6), fg: .white, size: 10))
                Button { g.sheet = .settings } label: { Image(systemName: "gearshape.fill") }.buttonStyle(PxButtonStyle(size: 14)).frame(width: 64)
            }
        }
        .padding(.horizontal, 22).padding(.bottom, 28)
        .id(g.accountTick)
    }
    private var birdName: String { Prefs.bird == "random" ? "Random" : (Birds.shared.info(Prefs.bird)?.name ?? "Random") }
}

struct PausedView: View {
    @EnvironmentObject var g: GameModel
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("PAUSED").font(Px.title(44)).foregroundColor(.white).shadow(color: Px.brown, radius: 0, x: 3, y: 3)
                Button("KEEP GOING") { g.setPaused(false) }.buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 14))
                Button("QUIT") { g.quitRound() }.buttonStyle(PxButtonStyle(size: 12))
            }.padding(.horizontal, 60)
        }
    }
}
