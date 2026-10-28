import SwiftUI

@main
struct FlappyBirdApp: App {
    init() {
        _ = Audio.shared
        startEngine()
        startOnline()
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in appActive = false; hauntedMusicSync() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in appActive = true; hauntedMusicSync() }
        if ProcessInfo.processInfo.arguments.contains("-shots") { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { Demo.run() } }
    }
    var body: some Scene {
        WindowGroup {
            RootView().statusBarHidden(true).persistentSystemOverlays(.hidden)
                .onOpenURL { openLink($0.absoluteString.replacingOccurrences(of: "flappybird://", with: "#")) }
        }
    }
}

struct RootView: View {
    @ObservedObject var ui = UIBridge.shared
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                GameSKView()
                if let w = watchBarText {
                    VStack { KT(w, 9, .white, upper: false).padding(.vertical, 10).padding(.horizontal, 16).background(RoundedRectangle(cornerRadius: 12).fill(K.brown.opacity(0.88))).padding(.top, 14 + geo.safeAreaInsets.top); Spacer() }
                        .allowsHitTesting(false)
                }
                if PK.open { MenuLayer(size: geo.size, safe: geo.safeAreaInsets) }
                if ui.partyOpen { PartyController().transition(.opacity) }
                if let inv = ui.invite { InviteBanner(inv: inv, top: geo.safeAreaInsets.top) }
                if let u = ui.update { UpdateBanner(v: u.version, note: u.note, bottom: geo.safeAreaInsets.bottom) }
                ForEach(ui.toasts) { t in
                    KT(t.text, 9, .white, align: .center).padding(.vertical, 10).padding(.horizontal, 14).background(RoundedRectangle(cornerRadius: 9).fill(K.brown))
                        .frame(maxWidth: geo.size.width * 0.8).position(x: geo.size.width / 2, y: geo.size.height * 0.18 + 20).allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.3), value: ui.toasts.map { $0.id })
        }
        .ignoresSafeArea()
        .id(ui.tick >= 0 ? 0 : 1)
    }
}

/// the dark backdrop + the card in the middle (tap outside to close)
struct MenuLayer: View {
    let size: CGSize, safe: EdgeInsets
    @ObservedObject var ui = UIBridge.shared
    @State var shown = false
    var body: some View {
        let kind = PK.kind
        ZStack {
            Color.black.opacity(shown ? (kind == "weather" ? 0.2 : 0.42) : 0).onTapGesture { closePicker() }
            page(kind)
                .id(PK.tok)
                .frame(width: min(size.width * (kind == "settings" ? 0.78 : 0.8), kind == "settings" ? 300 : 310))
                .frame(maxHeight: maxH(kind))
                .scaleEffect(shown ? 1 : 0.92).offset(y: shown ? 0 : 24).opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { shown = true } }
    }
    func maxH(_ k: String) -> CGFloat {
        let H = size.height - safe.top - safe.bottom
        switch k {
        case "birds", "trails": return min(H * 0.68, 560)
        case "modes": return min(H * 0.72, 600)
        case "weather": return H * 0.8
        case "leaders", "challenge", "live": return min(H * 0.74, 620)
        case "friends": return min(H * 0.78, 640)
        case "account", "profile", "twofa", "email", "newpass", "notify", "partycode", "tvapprove": return min(H * 0.8, 660)
        case "pals", "avatar": return min(H * 0.84, 700)
        case "maker": return H * 0.92
        case "dev": return H * 0.86
        case "replay": return H * 0.9
        default: return H - 40
        }
    }
    @ViewBuilder func page(_ k: String) -> some View {
        let back = backTarget(k)
        let backAct: (() -> Void)? = back == nil ? nil : { playSound("swoosh"); PK.from[k] = nil; showPage(back!) }
        PanelCard(title: PAGE_TITLES[k] ?? "", back: backAct, close: closePicker) {
            switch k {
            case "settings": SettingsPage()
            case "birds": BirdsPage()
            case "modes": ModesPage()
            case "weather": WeatherPage()
            case "trails": TrailsPage()
            case "maker": MakerPage()
            case "export": ExportPage()
            case "import": ImportPage()
            case "card": CardPage()
            case "dev": DevPage()
            case "replay": ReplayPage()
            case "friends": FriendsPage()
            case "leaders": LeadersPage()
            case "challenge": ChallengePage()
            case "live": LivePage()
            case "account": AccountPage()
            case "profile": ProfilePage()
            case "twofa": TwoFaPage()
            case "email": EmailPage()
            case "newpass": NewPassPage()
            case "pals": PalsPage()
            case "avatar": AvatarPage()
            case "partycode": PartyCodePage()
            case "notify": NotifyPage()
            case "tvapprove": TVApprovePage()
            default: EmptyView()
            }
        }
    }
}
/// pages that scroll inside the card (.fg-page)
struct Scroll<C: View>: View {
    @ViewBuilder var content: C
    var body: some View { ScrollView(showsIndicators: false) { VStack(spacing: 0) { content }.padding(2) } }
}

struct InviteBanner: View {
    let inv: (uid: String, name: String, av: String?, bg: String?, room: String); let top: CGFloat
    var body: some View {
        VStack {
            HStack(spacing: 7) {
                Avatar(av: inv.av, bg: inv.bg, w: 40, h: 34)
                VStack(alignment: .leading, spacing: 2) { KT(inv.name, 11); KT("wants to duel you live!", 7) }.frame(maxWidth: .infinity, alignment: .leading)
                MkBtn("Join", .save, full: false) { UIBridge.shared.invite = nil; playSound("swoosh"); joinLive(inv.room); if PK.open { showPage("live") } else { openSheet("live") } }.fixedSize()
                MkBtn("Not now", full: false) { UIBridge.shared.invite = nil; rtSend(inv.uid, ["t": "no", "room": inv.room]) }.fixedSize()
            }
            .padding(7).background(RoundedRectangle(cornerRadius: 12).fill(K.cream)).overlay(RoundedRectangle(cornerRadius: 12).stroke(K.brown, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 6)
            .frame(maxWidth: 380).padding(.horizontal, 16).padding(.top, top + 10)
            Spacer()
        }
    }
}
struct UpdateBanner: View {
    let v: String, note: String, bottom: CGFloat
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 2) { KT("New version \(v) is out!", 9, K.orange); KT(note, 6, spacing: 3) }.frame(maxWidth: .infinity, alignment: .leading)
                MkBtn("OK", .save, full: false) { UIBridge.shared.update = nil }.fixedSize()
            }
            .padding(9).background(RoundedRectangle(cornerRadius: 12).fill(K.cream)).overlay(RoundedRectangle(cornerRadius: 12).stroke(K.brown, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 6)
            .frame(maxWidth: 420).padding(.horizontal, 12).padding(.bottom, bottom + 14)
        }
    }
}
