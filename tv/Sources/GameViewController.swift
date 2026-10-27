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

/// The TV screen: the game (SpriteKit) full screen. On the title and Game Over screens a row of big picture cards
/// (like Apple TV's own Home screen and Apple Arcade games): Play, Party, Mode, Bird, Leaderboard, Account, Settings.
/// Siri Remote: click to flap, Play/Pause pauses, Menu goes back (on the title it leaves the app).
/// Get Ready screen: swipe left / right to change mode, up / down to change bird.
/// Game controllers work the same way (A = click, B / Menu = back) and rumble when you crash.
final class GameViewController: UIViewController, GameSceneHUD, UICollectionViewDataSource, UICollectionViewDelegate {
    private let skView = SKView()
    private let scene = GameScene(size: CGSize(width: 1024, height: 768))
    private var shelf: UICollectionView!
    private let shade = UIView(), shadeLayer = CAGradientLayer()
    private let pausedView = UIVisualEffectView(effect: UIBlurEffect(style: .dark)), pausedLabel = UILabel()
    private let hint = UILabel(), toast = UILabel()
    private var paused = false
    private var focusPlay = true

    private enum Card: Int, CaseIterable { case play, party, mode, bird, board, account, settings }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        skView.frame = view.bounds; skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = false
        view.addSubview(skView)
        scene.scaleMode = .aspectFill
        scene.hud = self

        // a dark fade at the bottom so the cards stand out over the game
        shadeLayer.colors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.65).cgColor]
        shade.layer.addSublayer(shadeLayer); shade.isUserInteractionEnabled = false
        shade.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(shade)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 300, height: 290); layout.minimumLineSpacing = 50
        layout.sectionInset = UIEdgeInsets(top: 20, left: 90, bottom: 0, right: 90)
        shelf = UICollectionView(frame: .zero, collectionViewLayout: layout)
        shelf.backgroundColor = .clear; shelf.clipsToBounds = false; shelf.showsHorizontalScrollIndicator = false
        shelf.dataSource = self; shelf.delegate = self; shelf.remembersLastFocusedIndexPath = true
        shelf.register(CardCell.self, forCellWithReuseIdentifier: "c")
        shelf.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shelf)
        NSLayoutConstraint.activate([
            shelf.leadingAnchor.constraint(equalTo: view.leadingAnchor), shelf.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shelf.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30), shelf.heightAnchor.constraint(equalToConstant: 330),
            shade.leadingAnchor.constraint(equalTo: view.leadingAnchor), shade.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shade.bottomAnchor.constraint(equalTo: view.bottomAnchor), shade.heightAnchor.constraint(equalToConstant: 470),
        ])

        NotificationCenter.default.addObserver(forName: .accountChanged, object: nil, queue: .main) { [weak self] _ in self?.updateLabels() }
        // leaving the app (TV button, screen saver) in the middle of a round pauses it
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let s = self, s.scene.phase == .playing, !s.paused else { return }
            s.setPaused(true)
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let s = self, s.paused else { return }
            s.skView.isPaused = true; s.scene.isPaused = true   // (tvOS un-pauses the view by itself; stay paused until you click)
        }

        pausedView.frame = view.bounds; pausedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]; pausedView.isHidden = true
        let pt = NSMutableAttributedString(string: "Paused\n", attributes: [.font: Look.font(76, .bold), .foregroundColor: UIColor.white])
        pt.append(NSAttributedString(string: "\nClick to keep going.   Menu to quit.", attributes: [.font: Look.font(34), .foregroundColor: Look.dim]))
        pausedLabel.attributedText = pt; pausedLabel.numberOfLines = 0; pausedLabel.textAlignment = .center
        pausedLabel.frame = pausedView.bounds; pausedLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pausedView.contentView.addSubview(pausedLabel)
        view.addSubview(pausedView)

        for l in [hint, toast] {
            l.textColor = .white; l.textAlignment = .center; l.alpha = 0
            l.layer.shadowColor = UIColor.black.cgColor; l.layer.shadowOpacity = 0.7; l.layer.shadowRadius = 6; l.layer.shadowOffset = CGSize(width: 0, height: 3)
            l.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(l)
        }
        hint.font = Look.font(30, .semibold); hint.numberOfLines = 0
        hint.text = "Press the remote to flap\nSwipe \u{2190} \u{2192} to change mode     Swipe \u{2191} \u{2193} to change bird"
        toast.font = Look.font(48, .bold)
        NSLayoutConstraint.activate([hint.centerXAnchor.constraint(equalTo: view.centerXAnchor), hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
                                     toast.centerXAnchor.constraint(equalTo: view.centerXAnchor), toast.topAnchor.constraint(equalTo: view.topAnchor, constant: 70)])

        // swipes on the Get Ready screen
        for (d, f) in [(UISwipeGestureRecognizer.Direction.left, -1), (.right, 1), (.up, -2), (.down, 2)] as [(UISwipeGestureRecognizer.Direction, Int)] {
            let g = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:))); g.direction = d; g.name = "\(f)"; view.addGestureRecognizer(g)
        }

        skView.presentScene(scene)
        checkForUpdate()
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-shots") { Demo.run(self) }
        if args.contains("-partyshots") { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.openParty() } }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); shadeLayer.frame = shade.bounds }

    // MARK: HUD
    func phaseChanged(_ phase: GameScene.Phase) {
        let menu = phase == .title || phase == .over
        UIView.animate(withDuration: 0.25) {
            self.shelf.alpha = menu ? 1 : 0; self.shade.alpha = menu ? 1 : 0
            self.hint.alpha = phase == .ready ? 1 : 0
        }
        shelf.isUserInteractionEnabled = menu
        updateNote.isHidden = phase != .title
        if menu { focusPlay = true; updateLabels(); shelf.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: false) }
        setNeedsFocusUpdate(); updateFocusIfNeeded()
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [shelf] }
    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? { focusPlay ? IndexPath(item: 0, section: 0) : nil }
    func collectionView(_ c: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) { focusPlay = false }

    private func updateLabels() { shelf?.reloadData() }

    // MARK: the cards
    func collectionView(_ c: UICollectionView, numberOfItemsInSection s: Int) -> Int { Card.allCases.count }
    func collectionView(_ c: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = c.dequeueReusableCell(withReuseIdentifier: "c", for: ip) as! CardCell
        let card = Card(rawValue: ip.item)!
        let (title, image) = art(card)
        cell.label.text = title; cell.pic.image = image
        return cell
    }
    func collectionView(_ c: UICollectionView, didSelectItemAt ip: IndexPath) {
        switch Card(rawValue: ip.item)! {
        case .play: play()
        case .party: openParty()
        case .mode: openModes()
        case .bird: openBirds()
        case .board: present(LeaderboardController(), animated: true)
        case .account: present(SignInController(), animated: true)
        case .settings: let s = SettingsController(); s.onDone = { [weak self] in self?.choicesChanged() }; present(s, animated: true)
        }
    }
    private func art(_ card: Card) -> (String, UIImage) {
        let size = CGSize(width: 300, height: 210)
        let mode = Prefs.mode, bird = Prefs.bird, acc = Account.shared
        let birdName = bird == "random" ? "Random" : (Birds.shared.info(bird)?.name ?? "Random")
        switch card {
        case .play:
            return (scene.phase == .over ? "Play Again" : "Play", Cards.render(size) { g, r in
                Cards.scenery(g, r)
                Cards.bird(bird == "random" ? "yellow" : bird, height: 80, at: CGPoint(x: r.width * 0.36, y: r.height * 0.46))
                UIColor.white.withAlphaComponent(0.92).setFill(); g.fillEllipse(in: CGRect(x: r.width * 0.62, y: r.height * 0.24, width: 84, height: 84))
                Cards.symbol("play.fill", 38, at: CGPoint(x: r.width * 0.62 + 46, y: r.height * 0.24 + 42), color: Look.rgb(0x4ec0ca))
            })
        case .party:
            return ("Party", Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0x9b6bd6), Look.rgb(0x5b3a9a))
                for (i, b) in ["robin", "blue", "yellow", "red"].enumerated() { Cards.bird(b, height: 40, at: CGPoint(x: r.width * (0.2 + 0.2 * CGFloat(i)), y: r.height * (i % 2 == 0 ? 0.36 : 0.5))) }
                Cards.symbol("iphone", 34, at: CGPoint(x: r.width * 0.5, y: r.height * 0.8), color: UIColor.white.withAlphaComponent(0.85))
            })
        case .mode:
            let sym = ["normal": "flag.fill", "hard": "flame.fill", "wavy": "water.waves", "flipped": "arrow.up.arrow.down", "tiny": "arrow.down.right.and.arrow.up.left",
                       "turbo": "hare.fill", "windy": "wind", "dark": "moon.stars.fill"][mode] ?? "flag.fill"
            return ("Mode: " + Modes.info(mode).title, Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0xfc9a58), Look.rgb(0xe0563a))
                Cards.symbol(sym, 74, at: CGPoint(x: r.midX, y: r.midY))
            })
        case .bird:
            return ("Bird: " + birdName, Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0x4ec0ca), Look.rgb(0x2f8f9a))
                if bird == "random" { Cards.symbol("shuffle", 70, at: CGPoint(x: r.midX, y: r.midY)) }
                else { Cards.bird(bird, height: 120, at: CGPoint(x: r.midX, y: r.midY)) }
            })
        case .board:
            return ("Leaderboard", Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0xf5c542), Look.rgb(0xd4921a))
                Cards.symbol("trophy.fill", 76, at: CGPoint(x: r.midX, y: r.midY))
            })
        case .account:
            return (acc.signedIn ? acc.username : (acc.session?.needCode == true ? "Finish Signing In" : "Sign In"), Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0x7fcf5a), Look.rgb(0x3f9a3a))
                if acc.signedIn { Cards.bird(bird == "random" ? "yellow" : bird, height: 100, at: CGPoint(x: r.midX, y: r.midY)) }
                else { Cards.symbol("person.crop.circle.fill", 80, at: CGPoint(x: r.midX, y: r.midY)) }
            })
        case .settings:
            return ("Settings", Cards.render(size) { g, r in
                Cards.gradient(g, r, Look.rgb(0x6b7280), Look.rgb(0x3a3f4a))
                Cards.symbol("gearshape.fill", 76, at: CGPoint(x: r.midX, y: r.midY))
            })
        }
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

    /// Get Ready: swipe left / right = mode, up / down = bird
    @objc private func swiped(_ g: UISwipeGestureRecognizer) {
        guard presentedViewController == nil, scene.phase == .ready, let f = Int(g.name ?? "") else { return }
        if abs(f) == 1 {
            let all = Modes.all, i = all.firstIndex { $0.id == Prefs.mode } ?? 0
            Prefs.mode = all[(i + f + all.count) % all.count].id
            show(toast: "Mode: " + Modes.info(Prefs.mode).title)
        } else {
            let cur = Prefs.bird
            let list = Birds.shared.birds(in: Birds.shared.info(cur)?.category ?? (Birds.shared.categories.first ?? "Classic"))
            guard !list.isEmpty else { return }
            let i = list.firstIndex { $0.id == cur } ?? -1
            Prefs.bird = list[(i + f / 2 + list.count) % list.count].id
            show(toast: "Bird: " + (Birds.shared.info(Prefs.bird)?.name ?? ""))
        }
        scene.refreshChoices(); scene.sound(scene.swoosh)
    }
    private func show(toast text: String) {
        toast.text = text; toast.layer.removeAllAnimations()
        toast.alpha = 1
        UIView.animate(withDuration: 0.4, delay: 1.2, options: [.beginFromCurrentState]) { self.toast.alpha = 0 }
    }

    private func setPaused(_ p: Bool) {
        paused = p; skView.isPaused = p; scene.isPaused = p; pausedView.isHidden = !p
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
        updateNote.text = "     A new version of the Apple TV app is out. Install the new file to get it.     "
        updateNote.font = Look.font(28, .medium); updateNote.textColor = .white; updateNote.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        updateNote.layer.cornerRadius = 32; updateNote.clipsToBounds = true
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
        at(2) { vc.present(SignInController(), animated: true); print("DEMO signin") }
        at(6) { vc.dismiss(animated: true) }
        at(2) { let c = SettingsController(); vc.present(c, animated: true); print("DEMO settings") }
        at(3) { vc.presentedViewController?.present(TrailsController(), animated: true); print("DEMO trails") }
        at(4) { vc.presentedViewController?.dismiss(animated: false); vc.dismiss(animated: true) }
        let looks = [("halloween", "rainbow"), ("christmas", "sparkles"), ("spring", "hearts"), ("fall", "fireribbon"), ("summer", "bubbles"), ("winter", "halo")]
        for (i, m) in ["normal", "flipped", "dark", "windy", "wavy", "hard"].enumerated() {
            at(2) { Prefs.season = looks[i].0; Prefs.trail = looks[i].1; Prefs.mode = m; s.refreshChoices(); s.autopilot = true; vc.play(); print("DEMO ready \(m) \(looks[i].0) \(looks[i].1)") }
            at(2) { s.primaryAction(); print("DEMO play \(m)") }
            at(i == 0 ? 12 : 8) { print("DEMO score \(m) \(s.score)"); s.autopilot = false }
            at(5) { print("DEMO over \(m) \(s.score)") }
        }
        at(3) { Prefs.season = "auto"; Prefs.trail = "none"; s.showTitle(); Prefs.mode = "normal"; print("DEMO end") }
    }
}
