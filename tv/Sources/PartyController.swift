import CoreImage
import SpriteKit
import UIKit

/// The couch party screen. The TV makes a room ("fb-party-CODE"); phones open the website with #party=CODE
/// (by scanning the QR code) and become controllers. The Siri Remote starts rounds; Menu leaves.
final class PartyController: UIViewController, PartySceneDelegate {
    static let site = "https://duckyisc00l.github.io/flappy-bird/"
    let code: String
    private let skView = SKView()
    private(set) lazy var scene = PartyScene(size: CGSize(width: 1024, height: 768))
    private var room: RealtimeRoom!
    private var tick: Timer?
    private var pendingSend = false
    private var online = false

    private let joinCard = UIView(), qr = UIImageView(), joinTitle = UILabel(), joinText = UILabel(), codeLabel = UILabel(), status = UILabel()
    private let list = UIStackView(), listCard = UIView(), listTitle = UILabel()
    private let hint = UILabel(), corner = UILabel()

    init(code: String? = nil) {
        let A = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        self.code = code ?? String((0..<5).map { _ in A.randomElement()! })
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        skView.frame = view.bounds; skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)
        scene.scaleMode = .aspectFill; scene.party = self
        skView.presentScene(scene)
        buildOverlay()
        room = RealtimeRoom(channel: "fb-party-" + code)
        room.onStatus = { [weak self] ok in self?.online = ok; self?.refresh() }
        room.onMessage = { [weak self] e, p in self?.message(e, p) }
        room.connect()
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            s.scene.dropQuiet(); s.send()
        }
        refresh()
        if ProcessInfo.processInfo.arguments.contains("-partyshots") { PartyDemo.run(self) }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        tick?.invalidate()
        room.broadcast("st", ["s": "closed"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [room] in room?.close() }
    }

    // MARK: phones talking to the TV
    private func message(_ e: String, _ p: [String: Any]) {
        guard let id = p["id"] as? String, id.count <= 40 else { return }
        switch e {
        case "p": scene.playerSeen(id: id, name: p["name"] as? String ?? "", bird: p["bird"] as? String ?? "random")
        case "f": scene.flap(id)
        case "bye": scene.playerLeft(id)
        default: break
        }
    }
    func partyChanged() {
        refresh()
        if !pendingSend { pendingSend = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.pendingSend = false; self?.send() } }
    }
    private func send() { room.broadcast("st", scene.stateForPhones()) }

    // MARK: the remote
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let t = presses.first?.type else { return super.pressesBegan(presses, with: event) }
        switch t {
        case .select, .playPause:
            if scene.phase == .lobby { scene.startCountdown() } else if scene.phase == .over { scene.backToLobby(); scene.startCountdown() }
            return
        case .menu:
            if scene.phase == .over { scene.backToLobby(); return }
            dismiss(animated: true); return
        default: super.pressesBegan(presses, with: event)
        }
    }

    // MARK: overlay
    private func card(_ v: UIView) {
        v.backgroundColor = Look.cream; v.layer.cornerRadius = 30; v.layer.borderWidth = 8; v.layer.borderColor = Look.brown.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v)
    }
    private func label(_ l: UILabel, _ f: UIFont, _ c: UIColor = Look.brown) { l.font = f; l.textColor = c; l.numberOfLines = 0; l.textAlignment = .center; l.translatesAutoresizingMaskIntoConstraints = false }

    private func buildOverlay() {
        card(joinCard); card(listCard)
        label(joinTitle, Look.title(60), Look.orange); joinTitle.text = "Party!"
        label(joinText, Look.pixel(17)); joinText.text = "SCAN WITH YOUR PHONE CAMERA\nOR GO TO\nDUCKYISC00L.GITHUB.IO/FLAPPY-BIRD\nAND TYPE THIS CODE IN SETTINGS"
        label(codeLabel, Look.pixel(64)); codeLabel.text = code
        label(status, Look.pixel(16))
        qr.image = makeQR(Self.site + "#party=" + code); qr.layer.magnificationFilter = .nearest; qr.translatesAutoresizingMaskIntoConstraints = false
        qr.backgroundColor = .white; qr.layer.cornerRadius = 14; qr.clipsToBounds = true
        for v in [joinTitle, qr, joinText, codeLabel, status] { joinCard.addSubview(v) }
        label(listTitle, Look.title(52), Look.orange)
        list.axis = .vertical; list.spacing = 14; list.translatesAutoresizingMaskIntoConstraints = false
        listCard.addSubview(listTitle); listCard.addSubview(list)
        label(hint, Look.pixel(26), .white)
        hint.layer.shadowColor = UIColor.black.cgColor; hint.layer.shadowOpacity = 0.9; hint.layer.shadowRadius = 0; hint.layer.shadowOffset = CGSize(width: 3, height: 3)
        label(corner, Look.pixel(22), .white); corner.backgroundColor = Look.brown.withAlphaComponent(0.85); corner.layer.cornerRadius = 14; corner.clipsToBounds = true
        for v in [hint, corner] { view.addSubview(v) }
        NSLayoutConstraint.activate([
            joinCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 90), joinCard.topAnchor.constraint(equalTo: view.topAnchor, constant: 70),
            joinCard.widthAnchor.constraint(equalToConstant: 520), joinCard.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -170),
            joinTitle.topAnchor.constraint(equalTo: joinCard.topAnchor, constant: 26), joinTitle.centerXAnchor.constraint(equalTo: joinCard.centerXAnchor),
            qr.topAnchor.constraint(equalTo: joinTitle.bottomAnchor, constant: 18), qr.centerXAnchor.constraint(equalTo: joinCard.centerXAnchor),
            qr.widthAnchor.constraint(equalToConstant: 300), qr.heightAnchor.constraint(equalToConstant: 300),
            joinText.topAnchor.constraint(equalTo: qr.bottomAnchor, constant: 22), joinText.leadingAnchor.constraint(equalTo: joinCard.leadingAnchor, constant: 20),
            joinText.trailingAnchor.constraint(equalTo: joinCard.trailingAnchor, constant: -20),
            codeLabel.topAnchor.constraint(equalTo: joinText.bottomAnchor, constant: 10), codeLabel.centerXAnchor.constraint(equalTo: joinCard.centerXAnchor),
            status.bottomAnchor.constraint(equalTo: joinCard.bottomAnchor, constant: -18), status.centerXAnchor.constraint(equalTo: joinCard.centerXAnchor),
            listCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -90), listCard.topAnchor.constraint(equalTo: view.topAnchor, constant: 70),
            listCard.widthAnchor.constraint(equalToConstant: 480),
            listTitle.topAnchor.constraint(equalTo: listCard.topAnchor, constant: 24), listTitle.centerXAnchor.constraint(equalTo: listCard.centerXAnchor),
            list.topAnchor.constraint(equalTo: listTitle.bottomAnchor, constant: 18), list.leadingAnchor.constraint(equalTo: listCard.leadingAnchor, constant: 26),
            list.trailingAnchor.constraint(equalTo: listCard.trailingAnchor, constant: -26), list.bottomAnchor.constraint(equalTo: listCard.bottomAnchor, constant: -26),
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor), hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -70),
            corner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60), corner.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            corner.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    private func refresh() {
        let ph = scene.phase, playing = ph == .count || ph == .play
        joinCard.isHidden = playing || ph == .over
        listCard.isHidden = false
        corner.isHidden = !playing
        corner.text = "   JOIN NEXT ROUND: \(code)   "
        status.text = online ? "\u{25CF} ROOM OPEN - \(Modes.info(Prefs.mode).title.uppercased()) MODE" : "CONNECTING..."
        status.textColor = online ? UIColor(red: 0.25, green: 0.55, blue: 0.15, alpha: 1) : Look.brown
        listTitle.text = ph == .over ? (scene.winners.count == 1 ? scene.winners[0] + " wins!" : "Tie!") : playing ? "Scores" : "Players \(scene.players.count)/8"
        listTitle.font = Look.title(ph == .over ? 44 : 52)
        list.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let rows = playing || ph == .over ? scene.players.sorted { $0.score != $1.score ? $0.score > $1.score : $0.diedAt > $1.diedAt } : scene.players
        if rows.isEmpty {
            let l = UILabel(); label(l, Look.pixel(20)); l.text = "WAITING FOR PHONES...\n\nEVERYONE SCANS THE CODE\nAND TAPS THEIR PHONE TO FLAP"; list.addArrangedSubview(l)
        }
        for (i, p) in rows.enumerated() {
            let row = UIStackView(); row.axis = .horizontal; row.spacing = 16; row.alignment = .center
            let pic = UIImageView(image: Birds.shared.image(p.birdId, scale: 2)); pic.layer.magnificationFilter = .nearest
            pic.backgroundColor = UIColor(red: 0.306, green: 0.753, blue: 0.792, alpha: 1); pic.layer.cornerRadius = 10; pic.clipsToBounds = true
            pic.widthAnchor.constraint(equalToConstant: 84).isActive = true; pic.heightAnchor.constraint(equalToConstant: 70).isActive = true
            let n = UILabel(); n.font = Look.pixel(24); n.textColor = Look.brown; n.text = (playing || ph == .over ? "\(i + 1). " : "") + p.name
            let s = UILabel(); s.font = Look.title(46); s.textColor = Look.brown; s.textAlignment = .right
            s.text = playing || ph == .over ? "\(p.score)" : ""
            if playing && p.inRound && !p.alive { n.textColor = Look.brown.withAlphaComponent(0.45); n.text = (n.text ?? "") + "  X" }
            if playing && !p.inRound { n.text = (n.text ?? "") + "  (NEXT ROUND)" }
            row.addArrangedSubview(pic); row.addArrangedSubview(n); row.addArrangedSubview(UIView()); row.addArrangedSubview(s)
            list.addArrangedSubview(row)
        }
        switch ph {
        case .lobby: hint.text = scene.players.isEmpty ? "MENU TO GO BACK" : "PRESS PLAY ON THE REMOTE TO START"
        case .count, .play: hint.text = ""
        case .over: hint.text = "PLAY = ANOTHER ROUND      MENU = LOBBY"
        }
    }

    private func makeQR(_ s: String) -> UIImage? {
        guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        f.setValue(Data(s.utf8), forKey: "inputMessage"); f.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        // a white border around it (phones read QR codes better with one)
        let pad: CGFloat = 36, size = CGSize(width: CGFloat(cg.width) + pad * 2, height: CGFloat(cg.height) + pad * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(x: pad, y: pad, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
    }
}

/// "-partyshots": pretend phones join and play, so the build's screenshots show the party.
enum PartyDemo {
    static func run(_ vc: PartyController) {
        let s = vc.scene
        var t = 2.0
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        let bots = [("bot1", "SAM", "robin"), ("bot2", "MIA", "crow"), ("bot3", "LEO", "kiwi")]
        for (id, n, b) in bots { at(1.5) { s.botIds.insert(id); s.playerSeen(id: id, name: n, bird: b); print("PARTY joined \(n)") } }
        // keep the pretend phones "connected"
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in for (id, n, b) in bots where s.botIds.contains(id) { s.playerSeen(id: id, name: n, bird: b) } }
        Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { _ in s.botsThink() }
        at(4) { s.startCountdown(); print("PARTY start") }
        at(16) { print("PARTY state \(s.phase.rawValue) " + s.players.map { "\($0.name)=\($0.score)\($0.alive ? "+" : "x")" }.joined(separator: " ")) }
        at(14) { print("PARTY end \(s.phase.rawValue) winners=\(s.winners)") }
    }
}
