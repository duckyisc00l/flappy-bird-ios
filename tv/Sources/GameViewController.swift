import SpriteKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = GameViewController()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

/// The TV screen: the game (SpriteKit) full screen, a row of big buttons on the title and Game Over screens.
/// Siri Remote: click (or tap the touch surface) to flap, Play/Pause or Menu pauses, Menu on the title leaves the app.
/// Game controllers work the same way (A = click, B / Menu = back).
final class GameViewController: UIViewController, GameSceneHUD {
    private let skView = SKView()
    private let scene = GameScene(size: CGSize(width: 1024, height: 768))
    private let bar = UIStackView()
    private let playButton = PixelButton("PLAY", color: Look.green)
    private let modeButton = PixelButton("MODE")
    private let birdButton = PixelButton("BIRD")
    private let boardButton = PixelButton("LEADERBOARD")
    private let soundButton = PixelButton("SOUND")
    private let partyButton = PixelButton("PARTY", color: UIColor(red: 0.61, green: 0.42, blue: 0.84, alpha: 1))
    private let pausedLabel = UILabel()
    private let hint = UILabel()
    private var paused = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        skView.frame = view.bounds; skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = false
        view.addSubview(skView)
        scene.scaleMode = .aspectFill
        scene.hud = self

        bar.axis = .horizontal; bar.spacing = 30; bar.alignment = .center
        bar.translatesAutoresizingMaskIntoConstraints = false
        for b in [playButton, partyButton, modeButton, birdButton, boardButton, soundButton] { bar.addArrangedSubview(b) }
        view.addSubview(bar)
        NSLayoutConstraint.activate([bar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     bar.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -70)])
        playButton.titleLabel?.font = Look.pixel(34)
        playButton.onSelect = { [weak self] in self?.play() }
        modeButton.onSelect = { [weak self] in self?.openModes() }
        birdButton.onSelect = { [weak self] in self?.openBirds() }
        partyButton.setTitleColor(.white, for: .normal)
        partyButton.onSelect = { [weak self] in self?.openParty() }
        boardButton.onSelect = { [weak self] in self?.present(LeaderboardController(), animated: true) }
        soundButton.onSelect = { [weak self] in Prefs.sound.toggle(); self?.updateLabels() }

        pausedLabel.text = "PAUSED\n\nCLICK TO KEEP GOING\nMENU TO QUIT"
        pausedLabel.numberOfLines = 0; pausedLabel.textAlignment = .center; pausedLabel.font = Look.pixel(40); pausedLabel.textColor = .white
        pausedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6); pausedLabel.isHidden = true
        pausedLabel.frame = view.bounds; pausedLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pausedLabel)

        hint.text = "CLICK OR TAP THE REMOTE TO FLAP"
        hint.font = Look.pixel(24); hint.textColor = .white; hint.textAlignment = .center
        hint.layer.shadowColor = UIColor.black.cgColor; hint.layer.shadowOpacity = 0.8; hint.layer.shadowRadius = 0; hint.layer.shadowOffset = CGSize(width: 3, height: 3)
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.alpha = 0
        view.addSubview(hint)
        NSLayoutConstraint.activate([hint.centerXAnchor.constraint(equalTo: view.centerXAnchor), hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -90)])

        // a tap on the Siri Remote's touch surface flaps too (faster than clicking)
        let tap = UITapGestureRecognizer(target: self, action: #selector(surfaceTap))
        tap.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        tap.allowedPressTypes = []
        view.addGestureRecognizer(tap)

        updateLabels()
        skView.presentScene(scene)
        checkForUpdate()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-shots") { Demo.run(self) }
        if args.contains("-partyshots") { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.openParty() } }
    }

    // MARK: HUD
    func phaseChanged(_ phase: GameScene.Phase) {
        let menu = phase == .title || phase == .over
        UIView.animate(withDuration: 0.2) {
            self.bar.alpha = menu ? 1 : 0
            self.hint.alpha = phase == .ready ? 1 : 0
        }
        bar.isUserInteractionEnabled = menu
        playButton.setTitle(phase == .over ? "PLAY AGAIN" : "PLAY", for: .normal)
        updateNote.isHidden = phase != .title
        updateLabels()
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [playButton] }

    private func updateLabels() {
        modeButton.setTitle("MODE\n" + Modes.info(Prefs.mode).title.uppercased(), for: .normal)
        let b = Prefs.bird
        birdButton.setTitle("BIRD\n" + (b == "random" ? "RANDOM" : (Birds.shared.info(b)?.name.uppercased() ?? "RANDOM")), for: .normal)
        soundButton.setTitle("SOUND\n" + (Prefs.sound ? "ON" : "OFF"), for: .normal)
    }

    // MARK: actions
    func play() { scene.getReadyScreen() }
    func openParty() {
        let args = ProcessInfo.processInfo.arguments
        let code = args.firstIndex(of: "-partycode").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        present(PartyController(code: code), animated: true)
    }
    func openModes() { let c = ModesController(); c.onDone = { [weak self] in self?.choicesChanged() }; present(c, animated: true) }
    func openBirds() { let c = BirdsController(); c.onDone = { [weak self] in self?.choicesChanged() }; present(c, animated: true) }
    private func choicesChanged() { scene.refreshChoices(); updateLabels() }

    @objc private func surfaceTap() { if !paused && (scene.phase == .ready || scene.phase == .playing) { scene.primaryAction() } }

    private func setPaused(_ p: Bool) {
        paused = p; skView.isPaused = p; scene.isPaused = p; pausedLabel.isHidden = !p
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard presentedViewController == nil, let type = presses.first?.type else { return super.pressesBegan(presses, with: event) }
        let inRound = scene.phase == .ready || scene.phase == .playing
        switch type {
        case .select, .upArrow:
            if paused { setPaused(false); return }
            if inRound { scene.primaryAction(); return }
        case .playPause:
            if scene.phase == .playing { setPaused(!paused); return }
            if scene.phase == .ready { scene.primaryAction(); return }
            if scene.phase == .title || scene.phase == .over { play(); return }
        case .menu:
            if paused { setPaused(false); scene.showTitle(); return }
            if scene.phase == .playing { setPaused(true); return }
            if scene.phase == .ready || scene.phase == .over || scene.phase == .dying { scene.showTitle(); return }
            // on the title screen Menu goes back to the Apple TV home screen (system default)
        default: break
        }
        super.pressesBegan(presses, with: event)
    }

    // MARK: a newer Apple TV version? (the website's version.json says which build is newest)
    private let updateNote = UILabel()
    private func checkForUpdate() {
        guard let url = URL(string: "https://duckyisc00l.github.io/flappy-bird/version.json?t=\(Int(Date().timeIntervalSince1970))") else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)) { [weak self] data, _, _ in
            guard let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let tv = obj["tv"] as? Int else { return }
            let mine = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
            guard tv > mine else { return }
            DispatchQueue.main.async { self?.showUpdateNote() }
        }.resume()
    }
    private func showUpdateNote() {
        updateNote.text = "  A NEW VERSION OF THE APPLE TV APP IS OUT. INSTALL THE NEW FILE TO GET IT.  "
        updateNote.font = Look.pixel(20); updateNote.textColor = Look.brown; updateNote.backgroundColor = Look.light
        updateNote.layer.cornerRadius = 14; updateNote.layer.borderWidth = 5; updateNote.layer.borderColor = Look.brown.cgColor; updateNote.clipsToBounds = true
        updateNote.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(updateNote)
        NSLayoutConstraint.activate([updateNote.centerXAnchor.constraint(equalTo: view.centerXAnchor), updateNote.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
                                     updateNote.heightAnchor.constraint(equalToConstant: 64)])
        phaseChanged(scene.phase)
    }

    // used by the demo
    var gameScene: GameScene { scene }
}

/// "-shots": the build runs the app in the Apple TV simulator and takes screenshots while this plays through the screens.
enum Demo {
    static func run(_ vc: GameViewController) {
        var t: Double = 3
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        let s = vc.gameScene
        Prefs.bird = Birds.shared.all.first { $0.id == "robin" }?.id ?? (Birds.shared.all.dropFirst(40).first?.id ?? "yellow")
        at(0) { print("DEMO title") }
        at(4) { vc.openBirds(); print("DEMO birds") }
        at(5) { vc.dismiss(animated: true) }
        at(2) { vc.openModes(); print("DEMO modes") }
        at(5) { vc.dismiss(animated: true) }
        at(2) { vc.present(LeaderboardController(), animated: true); print("DEMO leaderboard") }
        at(7) { vc.dismiss(animated: true) }
        for (i, m) in ["normal", "flipped", "dark", "windy", "wavy", "hard"].enumerated() {
            at(2) { Prefs.mode = m; s.refreshChoices(); s.autopilot = true; vc.play(); print("DEMO ready \(m)") }
            at(2) { s.primaryAction(); print("DEMO play \(m)") }
            at(i == 0 ? 12 : 8) { print("DEMO score \(m) \(s.score)"); s.autopilot = false }
            at(5) { print("DEMO over \(m) \(s.score)") }
        }
        at(3) { s.showTitle(); Prefs.mode = "normal"; print("DEMO end") }
    }
}
