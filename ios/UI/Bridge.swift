import SpriteKit
import SwiftUI

/// The open menu (the website's PK): which page, where its back arrow goes, and a token that changes with every page.
final class PKState {
    var open = false, kind = "", fromSettings = false, tok = 0
    var from: [String: String] = [:]
    var makerId: String? = nil, exportId: String? = nil, friendsFromCard = false
}
let PK = PKState()
var PK_CARD: CardData? = nil

/// Tells SwiftUI when the game changed something the menus show.
struct Toast: Identifiable { let id: Int; let text: String }
final class UIBridge: ObservableObject {
    static let shared = UIBridge()
    @Published var tick = 0
    @Published var toasts: [Toast] = []
    @Published var invite: (uid: String, name: String, av: String?, bg: String?, room: String)? = nil
    @Published var update: (version: String, note: String)? = nil
    @Published var partyOpen = false
    private var nextId = 0
    func refresh() { DispatchQueue.main.async { self.tick &+= 1 } }
    func accountChanged() {
        // redraw an open account page (sign-in finished, signed out...)
        if PK.open {
            if !accSignedIn() && ["twofa", "email", "newpass", "pals", "avatar"].contains(PK.kind) { accGo("account", replace: true); return }
            if PK.kind == "account" && accSignedIn() { accGo("profile", ACCT.uid, replace: true); return }
        }
        refresh()
    }
    func toast(_ t: String) {
        nextId += 1; let id = nextId
        toasts.append(Toast(id: id, text: t))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { self.toasts.removeAll { $0.id == id } }
    }
    func showInvite(_ uid: String, _ name: String, _ av: String?, _ bg: String?, _ room: String) {
        invite = (uid, name, av, bg, room); playSound("point"); haptic()
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { if self.invite?.room == room { self.invite = nil } }
    }
    func showUpdate(_ v: String, _ note: String) { if update == nil { update = (v, note) } }
}

func openSheet(_ kind: String) {
    if PK.open { showPage(kind); return }
    PK.open = true; PK.fromSettings = kind == "settings"; PK.from = [:]
    showPage(kind)
}
func openPicker(_ kind: String) { openSheet(kind) }
func showPage(_ kind: String) {
    if PK.kind == "birds" { birdChanged() }
    if kind == "friends" { PK.friendsFromCard = PK.kind == "card" || (PK.kind == "friends" && PK.friendsFromCard) }
    PK.kind = kind; PK.tok += 1
    UIBridge.shared.refresh()
}
func closePicker() {
    if !PK.open { return }
    if PK.kind == "birds" { birdChanged() }
    let fromSettings = PK.fromSettings
    PK.open = false; PK.kind = ""; PK.tok += 1
    playSound("swoosh")
    if fromSettings { hideSettings() }
    UIBridge.shared.refresh()
}
/// where the back arrow of a page goes (nil = no back arrow)
func backTarget(_ kind: String) -> String? {
    let BACK = ["maker": "birds", "export": "maker", "import": "birds"]
    let ACC = ["account", "profile", "twofa", "email", "newpass", "pals", "avatar"]
    if ACC.contains(kind) || ["partycode", "notify", "tvapprove"].contains(kind) {
        if let f = PK.from[kind], f != kind { return f }
        return PK.fromSettings ? "settings" : nil
    }
    if kind == "friends" { return PK.friendsFromCard ? "card" : (PK.fromSettings ? "settings" : nil) }
    if let b = BACK[kind] { return b }
    if kind != "settings" && PK.fromSettings { return "settings" }
    return nil
}
let PAGE_TITLES = ["settings": "Settings", "birds": "Birds", "modes": "Modes", "weather": "Weather", "maker": "Bird Maker", "export": "Share", "import": "Import", "card": "Score Card",
                   "dev": "Developer", "replay": "Replay", "trails": "Trails", "friends": "Race a Friend", "leaders": "Leaderboard", "challenge": "Race!", "live": "Live Duel",
                   "account": "Account", "profile": "Profile", "twofa": "Two-Factor", "email": "Email", "newpass": "Password", "pals": "Friends", "avatar": "Picture",
                   "partycode": "TV Party", "notify": "Notifications", "tvapprove": "Apple TV"]

// MARK: - the game's SpriteKit scene: runs the web loop every frame and passes taps to it

final class WebScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = .zero
        if screen.root.parent == nil { addChild(screen.root) }
        screen.scaleHint = view.window?.screen.scale ?? UIScreen.main.scale
    }
    override func didChangeSize(_ oldSize: CGSize) {
        viewW = Double(size.width); viewH = Double(size.height)
        layout()
        screen.root.position = CGPoint(x: (viewW - boxW) / 2, y: (viewH - boxH) / 2)
    }
    override func update(_ currentTime: TimeInterval) { loop(currentTime) }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: view)
        pointerDown(Double(p.x) - (viewW - boxW) / 2, Double(p.y) - (viewH - boxH) / 2)
    }
}
struct GameSKView: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
        let v = SKView()
        v.ignoresSiblingOrder = true
        v.isMultipleTouchEnabled = false
        v.preferredFramesPerSecond = 120
        let s = WebScene(size: CGSize(width: 402, height: 874))
        s.scaleMode = .resizeFill
        v.presentScene(s)
        return v
    }
    func updateUIView(_ v: SKView, context: Context) {}
}
