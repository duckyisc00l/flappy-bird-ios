import SwiftUI

/// Your phone as a controller for the Apple TV couch party (the TV shows a code; type it here).
/// Same room and messages as the website: "p" {id, name, bird} every 2 s, "f" {id} for every tap, "bye" when you leave;
/// the TV sends "st" {s: lobby|count|play|over|closed, c, pl: [...], win: [...]}.
final class PartyClient: ObservableObject {
    @Published var code: String?
    @Published var online = false
    @Published var state: [String: Any] = [:]
    @Published var lastTV = Date.distantPast
    private var room: RealtimeRoom?
    private var hello: Timer?
    let id: String = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
    var name: String { Account.shared.signedIn ? Account.shared.username : (UserDefaults.standard.string(forKey: "partyNick") ?? "PLAYER") }
    var bird: String { Prefs.bird == "random" ? "yellow" : Prefs.bird }

    func join(_ raw: String) -> Bool {
        let c = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard (4...12).contains(c.count) else { return false }
        leave()
        code = c
        let r = RealtimeRoom(channel: "fb-party-" + c)
        r.onStatus = { [weak self] ok in self?.online = ok; if ok { self?.sayHello() } }
        r.onMessage = { [weak self] e, p in
            guard e == "st" else { return }
            self?.state = p; self?.lastTV = Date()
        }
        room = r; r.connect()
        hello = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.sayHello() }
        return true
    }
    func sayHello() { room?.broadcast("p", ["id": id, "name": String(name.prefix(14)), "bird": bird]) }
    func flap() { room?.broadcast("f", ["id": id]) }
    func leave() {
        hello?.invalidate(); hello = nil
        room?.broadcast("bye", ["id": id])
        let r = room; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { r?.close() }
        room = nil; code = nil; online = false; state = [:]
    }
    /// what to show: "lobby", "count", "play", "over", "closed" (TV quiet for 6 s = gone)
    var phase: String { Date().timeIntervalSince(lastTV) > 6 && !state.isEmpty ? "lost" : (state["s"] as? String ?? "waiting") }
    var me: [String: Any]? { (state["pl"] as? [[String: Any]])?.first { ($0["id"] as? String) == id } }
}

struct PartyView: View {
    @EnvironmentObject var g: GameModel
    @StateObject private var party = PartyClient()
    @State private var entry = ""
    @State private var nick = UserDefaults.standard.string(forKey: "partyNick") ?? ""
    @State private var tick = 0
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        Group {
            if party.code == nil {
                Panel(title: "TV Party", onClose: { g.sheet = nil }) {
                    VStack(spacing: 12) {
                        Text("ON THE APPLE TV, OPEN PARTY. TYPE THE CODE IT SHOWS, THEN YOUR PHONE IS THE CONTROLLER: TAP TO FLAP.").font(Px.text(8)).foregroundColor(Px.brown).lineSpacing(3)
                        TextField("CODE", text: $entry).font(Px.text(26)).multilineTextAlignment(.center).textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .padding(12).background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 1, green: 0.98, blue: 0.88))).overlay(RoundedRectangle(cornerRadius: 8).stroke(Px.brown, lineWidth: 2))
                        if !Account.shared.signedIn {
                            TextField("Your name on the TV", text: $nick).font(Px.text(12)).autocorrectionDisabled()
                                .padding(12).background(RoundedRectangle(cornerRadius: 8).fill(Px.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Px.line, lineWidth: 2))
                        }
                        Button("JOIN") {
                            if !nick.isEmpty { UserDefaults.standard.set(String(nick.prefix(14)), forKey: "partyNick") }
                            if !party.join(entry) { g.show("That code doesn't look right") }
                        }.buttonStyle(PxButtonStyle(fill: Px.hex(0x9b6bd6), fg: .white, size: 14))
                        Spacer()
                    }.padding(16)
                }
            } else { controller }
        }
        .onReceive(clock) { _ in tick += 1 }
        .onDisappear { party.leave() }
    }
    private var controller: some View {
        _ = tick   // (re-check the TV every second)
        let ph = party.phase, me = party.me
        let alive = (me?["alive"] as? Int) == 1, inRound = (me?["in"] as? Int) == 1, score = me?["score"] as? Int ?? 0
        let bg: Color = ph == "play" && inRound ? (alive ? Px.hex(0x3fb24a) : Px.hex(0x555060)) : Px.hex(0x26345e)
        let big: String = {
            switch ph {
            case "play": return inRound ? (alive ? "TAP TO FLAP" : "OUT! \u{2715}") : "NEXT ROUND"
            case "count": return "\(party.state["c"] as? Int ?? 3)"
            case "over": let w = party.state["win"] as? [String] ?? []; return w.isEmpty ? "ROUND OVER" : (w.count == 1 ? "\(w[0].uppercased()) WINS!" : "TIE!")
            case "closed": return "THE TV CLOSED THE PARTY"
            case "lost": return "CAN'T SEE THE TV"
            case "lobby": return "YOU'RE IN!"
            default: return party.online ? "LOOKING FOR THE TV..." : "CONNECTING..."
            }
        }()
        let small: String = {
            switch ph {
            case "lobby": return "WAIT FOR THE TV TO START (PLAY ON THE REMOTE)"
            case "play": return inRound ? "SCORE \(score)" : "YOU JOIN THE NEXT ROUND"
            case "over": return "SCORE \(score)  \u{00B7}  ANOTHER ROUND SOON"
            default: return "CODE \(party.code ?? "")"
            }
        }()
        return ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack { BirdPic(id: party.bird, size: 44, bg: nil); Text(party.name.uppercased()).font(Px.text(12)).foregroundColor(.white); Spacer()
                    Button("LEAVE") { party.leave() }.font(Px.text(10)).foregroundColor(.white).padding(10).background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.3))) }
                Spacer()
                Text(big).font(Px.title(ph == "count" ? 120 : 44)).foregroundColor(.white).multilineTextAlignment(.center).shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: 3)
                Text(small).font(Px.text(10)).foregroundColor(.white.opacity(0.85)).multilineTextAlignment(.center)
                Spacer()
            }.padding(20).allowsHitTesting(true)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in
            if v.translation == .zero { party.flap(); if Prefs.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
        })
    }
}
