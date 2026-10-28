import AVFoundation
import SpriteKit
import SwiftUI

/// Flappy Bird for iPhone, all Swift: the game is SpriteKit (the same code as the Apple TV app),
/// the menus are SwiftUI in the website's look (cream panels, pixel font).
@main
struct FlappyBirdApp: App {
    @StateObject private var game = GameModel()
    init() {
        // game sounds mix with music and follow the silent switch, like the original app
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(game)
                .statusBarHidden(true)
        }
    }
}

/// The screens over the game (one at a time, like the website's panels)
enum Sheet: String, Identifiable {
    case modes, birds, trails, seasons, settings, leaderboard, account, party
    var id: String { rawValue }
}

/// Everything the menus need to know about the game
final class GameModel: ObservableObject, GameSceneHUD {
    let scene = GameScene(size: CGSize(width: 1024, height: 768))
    @Published var phase: GameScene.Phase = .title
    @Published var sheet: Sheet?
    @Published var paused = false
    @Published var toast: String?
    @Published var accountTick = 0   // bumps when you sign in / out
    private let light = UIImpactFeedbackGenerator(style: .light), heavy = UINotificationFeedbackGenerator()

    init() {
        scene.scaleMode = .aspectFill
        scene.hud = self
        scene.onEvent = { [weak self] e in self?.event(e) }
        NotificationCenter.default.addObserver(forName: .accountChanged, object: nil, queue: .main) { [weak self] _ in self?.accountTick += 1 }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let s = self, s.scene.phase == .playing else { return }
            s.setPaused(true)
        }
        if ProcessInfo.processInfo.arguments.contains("-shots") { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Demo.run(self) } }
    }
    func phaseChanged(_ phase: GameScene.Phase) { DispatchQueue.main.async { self.phase = phase } }
    private func event(_ e: String) {
        guard Prefs.haptics else { return }
        switch e {
        case "flap": light.impactOccurred(intensity: 0.7)
        case "crash": heavy.notificationOccurred(.error)
        default: break
        }
    }
    func play() { sheet = nil; scene.getReadyScreen() }
    func playDaily() { Prefs.mode = "daily"; choicesChanged(); play() }
    func choicesChanged() { scene.refreshChoices(); objectWillChange.send() }
    func setPaused(_ p: Bool) { paused = p; scene.isPaused = p; scene.view?.isPaused = p }
    func quitRound() { setPaused(false); scene.showTitle() }
    func show(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in if self?.toast == text { self?.toast = nil } }
    }
}

extension Prefs {
    /// light taps on the iPhone's Taptic Engine when you flap / crash
    static var haptics: Bool {
        get { UserDefaults.standard.object(forKey: "haptics") == nil ? true : UserDefaults.standard.bool(forKey: "haptics") }
        set { UserDefaults.standard.set(newValue, forKey: "haptics") }
    }
}

/// "-shots": the build runs the app in the iPhone simulator and takes screenshots while this plays through the screens.
enum Demo {
    static func run(_ g: GameModel) {
        var t: Double = 2
        func at(_ d: Double, _ f: @escaping () -> Void) { t += d; DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }
        at(0) { print("DEMO title") }
        for s in [Sheet.modes, .birds, .trails, .settings, .leaderboard, .account, .party] {
            at(3) { g.sheet = s; print("DEMO sheet \(s.rawValue)") }
            at(4) { g.sheet = nil }
        }
        at(2) { g.scene.autopilot = true; g.play(); print("DEMO ready") }
        at(2) { g.scene.primaryAction(); print("DEMO play") }
        at(10) { print("DEMO score \(g.scene.score)"); g.scene.autopilot = false }
        at(5) { print("DEMO over") }
        at(4) { g.scene.autopilot = true; g.playDaily(); print("DEMO daily") }
        at(2) { g.scene.primaryAction() }
        at(6) { g.scene.autopilot = false }
        at(5) { Prefs.mode = "normal"; g.scene.showTitle(); print("DEMO end") }
    }
}
