import Foundation
import UIKit

// The game, ported line by line from the website (v148). Same names, same numbers, same order of things,
// so the pipes, the Daily Challenge, ghosts and replays line up exactly with the website.
// Everything is in SpriteKit scene points, y-up (1024 x 768), exactly like the web page.

func mrand() -> Double { Double.random(in: 0..<1) }
@inline(__always) func clampD(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }

// ---------- Scene size & camera (GameScene.sks = 1024x768, scaleMode = .aspectFill) ----------
let SW = 1024.0, SH = 768.0
let width = SW, height = SH
var DPR = 1.0, camS = 1.0, camX = 0.0, camY = 0.0, boxW = 402.0, boxH = 874.0
var viewW = 402.0, viewH = 874.0
func layout() {
    let vw = viewW, vh = viewH
    // Real app is portrait-only. On a wide screen (iPad), a phone-shaped (402x874) box, like the website.
    let phoneAspect = 402.0 / 874.0
    if vw / vh > phoneAspect * 1.15 { boxH = vh; boxW = (vh * phoneAspect).rounded() } else { boxW = vw; boxH = vh }
    camS = max(boxW / SW, boxH / SH)
    camX = (boxW - SW * camS) / 2
    camY = (boxH - SH * camS) / 2
}

// ---------- Assets ----------
func img(_ k: String) -> Img? { Assets.img(k) }
func ok(_ im: Img?) -> Bool { im != nil }

// ---------- Audio ----------
func hauntedMusicSync() { Audio.shared.setMusic(haunted && playSounds && appActive) }
var appActive = true
func rawPlay(_ name: String) { Audio.shared.play(name) }
func playSound(_ name: String) { if !playSounds { return }; rawPlay(name) }
func armyRush() { if !playSounds { return }; Audio.shared.army() }
func armyBuzzSync() {}   // (v111: the quiet scattered flaps at -1 are off)
// haptics: the app's Taptic Engine (Settings > Haptics)
var haptics = true
var hapScoreNext = false
let APP_HAPTICS = true
private let hapLight = UIImpactFeedbackGenerator(style: .light), hapMedium = UIImpactFeedbackGenerator(style: .medium), hapHeavy = UIImpactFeedbackGenerator(style: .heavy), hapNote = UINotificationFeedbackGenerator()
func appHaptic(_ kind: String) {
    if !haptics { return }
    switch kind { case "flap": hapLight.impactOccurred(intensity: 0.7); case "light": hapLight.impactOccurred(); case "medium": hapMedium.impactOccurred(); case "heavy": hapHeavy.impactOccurred(); case "error": hapNote.notificationOccurred(.error); default: hapLight.impactOccurred() }
}
func hapticPulse() { appHaptic(hapScoreNext ? "medium" : "light"); hapScoreNext = false }
func haptic() { if !haptics { return }; hapticPulse() }
func hapticError() { if !haptics { return }; appHaptic("error"); DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { appHaptic("heavy") } }

// ---------- Settings (UserDefaults) ----------
func loadBool(_ key: String, _ def: Bool) -> Bool {
    if let v = localStorage.getItem("fb_" + key) { return v == "1" }
    localStorage.setItem("fb_" + key, def ? "1" : "0"); return def
}
func saveBool(_ key: String, _ v: Bool) { localStorage.setItem("fb_" + key, v ? "1" : "0") }
func loadStr(_ key: String, _ def: String) -> String { localStorage.getItem("fb_" + key) ?? def }
func saveStr(_ key: String, _ v: String) { localStorage.setItem("fb_" + key, v) }
func bestKey() -> String { "fb_bestScore" + modeSuffix(gameMode) }
func bestScore() -> Int { Int(localStorage.getItem(bestKey()) ?? "0") ?? 0 }
func setBestScore(_ v: Int) { localStorage.setItem(bestKey(), String(v)) }

var playSounds = true
var newBirds = true
var adaptiveBackground = false
var autoplay = false
struct ModeInfo { let id: String, name: String, title: String; let descText: () -> String; var desc: String { descText() } }
var MODES: [ModeInfo] = [
    ModeInfo(id: "normal", name: "NORMAL", title: "Normal", descText: { "The classic game." }),
    ModeInfo(id: "daily", name: "DAILY", title: "Daily Challenge", descText: {
        let s = dailyStreak()
        return "The same pipes for everyone today. New pipes in \(dailyHoursLeft())h." + (s > 0 ? " Streak: \(s)" + (s == 1 ? " day" : " days") + "." : "")
    }),
    ModeInfo(id: "hard", name: "HARD", title: "Hard", descText: { "Smaller gaps and faster pipes. The pipes turn red." }),
    ModeInfo(id: "wavy", name: "WAVY", title: "Wavy", descText: { "The pipes slide up and down while you fly." }),
    ModeInfo(id: "flipped", name: "FLIPPED", title: "Upside Down", descText: { "The whole world is upside down: you fall up, and every tap pushes you down." }),
    ModeInfo(id: "tiny", name: "TINY", title: "Tiny Gap", descText: { "The gaps are barely bigger than you are." }),
    ModeInfo(id: "turbo", name: "TURBO", title: "Turbo", descText: { "Starts normal and gets faster with every point." }),
    ModeInfo(id: "windy", name: "WINDY", title: "Windy", descText: { "Gusts of wind push you up and down. Watch the wind lines." }),
    ModeInfo(id: "dark", name: "DARK", title: "Darkness", descText: { "Pitch black. You only see what your lantern lights up." }),
]
var gameMode = "normal"
func modeSuffix(_ m: String) -> String { m == "normal" ? "" : m == "hard" ? "Hard" : "_" + m }
func modeInfo(_ m: String? = nil) -> ModeInfo { MODES.first { $0.id == (m ?? gameMode) } ?? MODES[0] }
var ghostOn = false
let HARD = (gap: 110.0, speed: 1.25, every: 1.0)

func loadSettings() {
    playSounds = loadBool("playSounds", true)
    _ = loadBool("newBirds", true)
    _ = loadBool("adaptiveBackground", false)
    autoplay = loadBool("autoplay", false)
    gameMode = loadStr("gameMode", loadBool("hardMode", false) ? "hard" : "normal")
    if !MODES.contains(where: { $0.id == gameMode }) { gameMode = "normal" }
    ghostOn = {
        if let v = localStorage.getItem("fb_ghostOn") { return v == "1" }
        let old = localStorage.getItem("fb_ghost")
        if old == "0" { localStorage.removeItem("fb_ghost"); saveBool("ghostOn", false); return false }
        if old == "1" { localStorage.removeItem("fb_ghost") }
        return false
    }()
    // Reloading puts the game back to normal: the haunted state after the ending and the dead birds are not kept.
    localStorage.removeItem("fb_haunted"); localStorage.removeItem("fb_deaths")
    haunted = false; DEATHS = []
    adaptiveBackground = false; newBirds = true   // (switches removed in v101 / v102)
    haptics = loadBool("appHaptics", true)
    weatherPick = loadStr("weather", "auto"); seasonPick = loadStr("season", "auto")
    birdPick = loadStr("birdPick", "random")
    favBirds = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_favBirds") ?? "[]").utf8)) as? [String]) ?? []
    trailPick = loadStr("trail", "none"); trailDefNow = trailDef(trailPick)
    devMode = loadBool("devMode", false)
    resultBestLabel = String(bestScore())
}

// ---------- Constants (GameScene.Constants) ----------
enum C {
    static let superScore = 1000.0, gravity = -12.0, verticalPipeGap = 130.0, pipeScale = 2.0, birdScale = 1.5
    static let idleFloatDistance = 35.0, idleFloatDuration = 1.0, flapImpulse = 22.0, flapRotation = 0.45, flapRotationHold = 0.60
    static let minimumBirdYOffset = 20.0, groundMoveSpeed = 0.005, skyMoveSpeed = 0.1, pipeMoveSpeed = 0.005
    static let animationFrameDuration = 0.1, toggleAnimationDuration = 0.12, gameOverDelay = 0.8, resultDelay = 0.2
}
let PTM = 150.0
let GRAVITY = C.gravity * PTM
let BIRD_RADIUS = (24 * C.birdScale) / 2
let BIRD_MASS = Double.pi * BIRD_RADIUS * BIRD_RADIUS / (PTM * PTM)
let LINEAR_DAMPING = 0.1

// ---------- Minimal SKNode/SKAction runtime ----------
struct Step {
    var call: (() -> Void)? = nil
    var scaleTo: Double? = nil, moveTo: (Double, Double)? = nil, moveBy: (Double, Double)? = nil, fadeTo: Double? = nil
    var d: Double = 0
    var dyn: (() -> Double)? = nil
    var dur: Double { dyn?() ?? d }
    static func wait(_ d: Double) -> Step { Step(d: d) }
    static func call(_ f: @escaping () -> Void) -> Step { Step(call: f) }
    static func scale(_ s: Double, _ d: Double) -> Step { Step(scaleTo: s, d: d) }
}
final class Action {
    var steps: [Step], i = 0, t = 0.0, started = false, rep: Bool, done: (() -> Void)?
    var fromScale = 0.0, fromX = 0.0, fromY = 0.0, fromAlpha = 0.0
    init(_ s: [Step], _ r: Bool, _ d: (() -> Void)?) { steps = s; rep = r; done = d }
}
final class GNode {
    var x = 0.0, y = 0.0, scale = 1.0, rot = 0.0, speed = 1.0, added = false, alpha = 1.0
    var actions: [(key: String, a: Action)] = []
    // the bird's extras
    var vy = 0.0, dynamic = false, animT = 0.0, collideLandOnly = false
    var color = "#000"
    init(x: Double = 0, y: Double = 0, scale: Double = 1, added: Bool = false, alpha: Double = 1) { self.x = x; self.y = y; self.scale = scale; self.added = added; self.alpha = alpha }
    func action(_ k: String) -> Action? { actions.first { $0.key == k }?.a }
}
var actionId = 0
func run(_ node: GNode, _ steps: [Step], _ key: String? = nil, rep: Bool = false, done: (() -> Void)? = nil) {
    let k = key ?? ("a" + String(actionId)); if key == nil { actionId += 1 }
    let a = Action(steps, rep, done)
    if let i = node.actions.firstIndex(where: { $0.key == k }) { node.actions[i].a = a } else { node.actions.append((k, a)) }
}
func removeAction(_ node: GNode, _ key: String) { node.actions.removeAll { $0.key == key } }
func removeAllActions(_ node: GNode) { node.actions = [] }
func stepActions(_ node: GNode, _ dt: Double) {
    let ndt = dt * node.speed
    for key in node.actions.map({ $0.key }) {
        guard let a = node.action(key) else { continue }
        var remaining = ndt, guardN = 0
        while node.action(key) === a && guardN < 200 {
            guardN += 1
            if a.i >= a.steps.count {
                if a.rep { a.i = 0; a.started = false; continue }
                removeAction(node, key)
                a.done?()
                break
            }
            let s = a.steps[a.i]
            if !a.started { a.started = true; a.t = 0; a.fromScale = node.scale; a.fromX = node.x; a.fromY = node.y; a.fromAlpha = node.alpha }
            if let c = s.call { a.i += 1; a.started = false; c(); continue }
            let d = s.dur
            let use = max(0, min(remaining, d - a.t))
            a.t += use; remaining -= use
            let p = d > 0 ? min(1, a.t / d) : 1
            if let st = s.scaleTo { node.scale = a.fromScale + (st - a.fromScale) * p }
            if let m = s.moveTo { node.x = a.fromX + (m.0 - a.fromX) * p; node.y = a.fromY + (m.1 - a.fromY) * p }
            if let m = s.moveBy { node.x = a.fromX + m.0 * p; node.y = a.fromY + m.1 * p }
            if let f = s.fadeTo { node.alpha = a.fromAlpha + (f - a.fromAlpha) * p }
            if a.t >= d - 1e-9 { a.i += 1; a.started = false; continue }
            break
        }
    }
}
func scaleTwice(_ node: GNode, _ s1: Double, _ d1: Double, _ s2: Double, _ d2: Double) { run(node, [.scale(s1, d1), .scale(s2, d2)], "scaleTwice") }

// ---------- Scene nodes ----------
let scene = GNode(added: true)
let moving = GNode(added: true)
let pipesNode = GNode(added: true)
let bird = GNode(x: width / 2, y: height / 2 + 75, scale: C.birdScale)
let flappyBird = GNode(x: width / 2, y: height / 2 + 200, scale: 1.5)
let getReady = GNode(x: width / 2, y: height / 2 + 130, scale: 1.2)
let tapTap = GNode(x: width / 2, y: height / 2, scale: 1.5)
let scoreLabel = GNode(x: width / 2, y: 3 * height / 4)
let gameOverNode = GNode(x: width / 2, y: height / 2 + 210, scale: 1.5)
let resultNode = GNode(x: width / 2, y: height / 2 + 75)
let settingsNode = GNode(x: width / 2, y: height / 2 + 15, scale: 1.2)
let playButton = GNode(x: width / 2, y: height / 2 - 115, scale: 1.2)
let settingsButton = GNode(x: width / 2 + 45, y: height / 2 - 25, scale: 1.2)
let githubButton = GNode(x: width / 2 - 45, y: height / 2 - 25, scale: 1.2)
let shareButton = GNode(scale: 1.2)
let replayButton = GNode(scale: 1.2)
let leadersButton = GNode(scale: 1.2)
let newBadge = GNode(x: 35, y: -6, scale: 0, added: true)
let sparkle = GNode(scale: 0, added: true)
var flashes: [GNode] = []

var groundX = 0.0, skyX = 0.0, skyIsNight = false
final class Pipe {
    var k = 0, gx = 0.0, traveled = 0.0, distance = 0.0, y = 0.0, sensorX = 0.0
    var scored = false, touching = false, gap: Double? = nil, red = false, gold = false
    var y0: Double? = nil, amp: Double? = nil, ph: Double? = nil, wk: Double? = nil
    var falling: (t: Double, ang: Double, vel: Double)? = nil
    var pb: PipeBlood? = nil, bt: Double? = nil, mass: [Death]? = nil
    var gapV: Double { gap ?? C.verticalPipeGap }
    /// GHOST_PIPE_KEYS: the course as stored in ghosts (JSON, like the website)
    func json() -> [String: Any] {
        var o: [String: Any] = ["gx": gx, "traveled": traveled, "distance": distance, "y": y, "sensorX": sensorX, "red": red]
        if let g = gap { o["gap"] = g }
        if let v = y0 { o["y0"] = v }; if let v = amp { o["amp"] = v }; if let v = ph { o["ph"] = v }; if let v = wk { o["wk"] = v }
        return o
    }
    static func from(_ o: [String: Any]) -> Pipe {
        let p = Pipe()
        func num(_ k: String) -> Double? { if let n = o[k] as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.doubleValue }; return nil }
        p.gx = num("gx") ?? 0; p.traveled = num("traveled") ?? 0; p.distance = num("distance") ?? (width + 85); p.y = num("y") ?? 0; p.sensorX = num("sensorX") ?? 0
        p.gap = num("gap"); p.y0 = num("y0"); p.amp = num("amp"); p.ph = num("ph"); p.wk = num("wk")
        if let r = o["red"] as? Bool { p.red = r } else if let n = num("red") { p.red = n != 0 }
        if let k = num("k") { p.k = Int(k) }
        return p
    }
}
var pipeList: [Pipe] = []
var score = 0
var birdColor = "yellow"
var gameStartTime = 0.0, lastFlapTime = 0.0, sceneTime = 0.0
var isWaitingToStart = false, isGameOver = false, hasHitGround = false, isShowingGameOver = false
var hitButton = false
struct ResultState { var score = 0, prevBest = 0, shownAt = 0.0, medal: String? = nil, lastI: Int? = nil, currentText: String? = nil }
var result = ResultState()

// ---------- Bird textures / animation ----------
func updateBirdTextures() {
    let r = mrand()
    var color: String
    // the app's six colours + the extra skins share 97% equally; 'kup' keeps its rare 3%
    let pool = ["yellow", "red", "blue", "green", "peach", "purple"] + extraSkinIds()
    if r < 0.97 { color = pool[min(pool.count - 1, Int(floor(r / 0.97 * Double(pool.count))))] } else { color = "kup" }
    if let pk = pickedSkin() { color = pk }   // the bird you picked in Settings
    if haunted { color = "haunted" }
    ensureSkin(color)
    birdColor = color
    applyBirdAnimation()
}
func applyBirdAnimation() { bird.animT = 0 }
func birdFrame() -> Img? {
    let seq = [1, 2, 3, 2]
    let idx = Int(floor(bird.animT / C.animationFrameDuration)) % 4
    return img(birdColor + "_" + String(seq[idx]))
}
func idleAnimation() -> [Step] { [Step(moveBy: (0, C.idleFloatDistance), d: C.idleFloatDuration), Step(moveBy: (0, -C.idleFloatDistance), d: C.idleFloatDuration)] }
func startIdleAnimation() { removeAction(bird, "idle"); run(bird, idleAnimation(), "idle", rep: true) }
func stopIdleAnimation() { removeAction(bird, "idle") }

// ---------- Sky ----------
func updateSky() {
    var night = mrand() < 0.5
    WX.tod = night ? "night" : "day"
    if adaptiveBackground { WX.tod = clockTod(); night = WX.tod == "night" }
    skyIsNight = night
    rollWeather()
    skyX = 0
}

// ---------- Pipes ----------
func modeOn(_ id: String) -> Bool { gameMode == id && !ending.on }
func hardOn() -> Bool { modeOn("hard") }
func turboMul() -> Double { 1 + Double(min(max(score, 0), 50)) * 0.016 }
func speedMul() -> Double { hardOn() ? HARD.speed : modeOn("turbo") ? turboMul() : 1 }
func modeGap() -> Double { hardOn() ? HARD.gap : modeOn("tiny") ? 106 : modeOn("wavy") ? 140 : C.verticalPipeGap }
func spawnEvery() -> Double { hardOn() ? HARD.every : modeOn("turbo") ? 1 / turboMul().squareRoot() : 1 }
func birdWidthNow() -> Double { bird.scale * (34 * abs(cos(bird.rot)) + 24 * abs(sin(bird.rot))) }
func spawnPipe() {
    if endingWantsControl() { return }
    if afterlife >= 1 && afterlife != 1 { return }
    let quarterHeight = floor(height / 4)
    var y = floor(crand() * quarterHeight) + quarterHeight
    let bw = birdWidthNow()
    let kNum = pipeNumberNext()
    var wave: (Double, Double, Double, Double)? = nil
    if modeOn("wavy") {
        let w = (y, 40 + crand() * 30, crand() * Double.pi * 2, (Double.pi * 2) / (200 * (1.3 + crand() * 0.8)))
        wave = w; y = w.0 + w.1 * sin(w.2)
    }
    let p = Pipe()
    p.k = kNum; p.gx = width + 30 * 2; p.traveled = 0; p.distance = width + 2 * 30 + 25; p.y = y
    p.sensorX = 30 + bw / 2 + 2; p.gap = modeGap(); p.red = gameMode == "hard"
    if let w = wave { p.y0 = w.0; p.amp = w.1; p.ph = w.2; p.wk = w.3 }
    pipeList.append(p)
}
struct R4 { var cx: Double, cy: Double, w: Double, h: Double }
func pipeRects(_ p: Pipe) -> (up: R4, down: R4, sensor: R4) {
    let gy = -352.0
    return (R4(cx: p.gx, cy: gy + p.y, w: 60, h: 1024), R4(cx: p.gx, cy: gy + p.y + 512 * 2 + p.gapV, w: 60, h: 1024), R4(cx: p.gx + p.sensorX, cy: gy + height / 2 + 400, w: 4, h: height))
}
func circleRect(_ cx: Double, _ cy: Double, _ r: Double, _ R: R4) -> Bool {
    let nx = max(R.cx - R.w / 2, min(cx, R.cx + R.w / 2)), ny = max(R.cy - R.h / 2, min(cy, R.cy + R.h / 2))
    let dx = cx - nx, dy = cy - ny
    return dx * dx + dy * dy < r * r
}

// ---------- Scene setup (didMove) ----------
func didMove() {
    flappyBird.added = true; bird.added = true; githubButton.added = true; settingsButton.added = true; playButton.added = true
    score = 0
    moving.speed = 1; bird.speed = 1
    pipesNode.scale = 0
    updateSky()
    updateBirdTextures()
    startPipeSpawner()
    startIdleAnimation()
}
func startPipeSpawner() { run(scene, [.call(spawnPipe), Step(dyn: { spawnEvery() })], "pipeSpawner", rep: true) }

// ---------- Input ----------
func nodeHit(_ node: GNode, _ texW: Double, _ texH: Double, _ px: Double, _ py: Double) -> Bool {
    if !node.added { return false }
    let s = node.scale
    if s == 0 { return false }
    return abs(px - node.x) <= texW * s / 2 && abs(py - node.y) <= texH * s / 2
}
func namedAt(_ px: Double, _ py: Double) -> String? {
    if settingsNode.added { return nil }   // (the old panel is never drawn: the settings sheet covers the screen)
    if nodeHit(playButton, 104, 58, px, py) { return "play" }
    if nodeHit(shareButton, 62, 36, px, py) { return "share" }
    if nodeHit(replayButton, 62, 36, px, py) { return "replay" }
    if nodeHit(leadersButton, 62, 36, px, py) { return "leaders" }
    if nodeHit(settingsButton, 62, 36, px, py) { return "settings" }
    if nodeHit(githubButton, 62, 36, px, py) { return "github" }
    return nil
}
func touchesBegan(_ px: Double, _ py: Double) {
    if afterlife >= 3 { return }
    if stopButtonVisible() {
        let r = stopButtonRect()
        if abs(px - r.cx) <= r.w / 2 + 6 && abs(py - r.cy) <= r.h / 2 + 6 { handleStopTap(); return }
    }
    switch namedAt(px, py) {
    case "play": handlePlayTap()
    case "settings": handleSettingsTap()
    case "share": handleShareTap()
    case "replay": handleReplayTap()
    case "leaders": handleLeadersTap()
    case "github": handleGitHubTap()
    default:
        if autoplay && bird.dynamic && !isGameOver { break }
        handleGameTap()
    }
}
func handleGameTap() {
    if liveRoom != nil && liveRoom!.opp != nil && isWaitingToStart { return }   // in a live duel the countdown starts the round
    if isWaitingToStart { startGame(); return }
    flapBird()
}
func startGame() {
    if !isWaitingToStart { return }
    isWaitingToStart = false
    gameStartTime = sceneTime
    stopIdleAnimation()
    removeStartUI()
    pipesNode.scale = 1
    pipeList = pipeList.filter { $0.gold || $0.falling != nil || $0.gx - 30 >= bird.x + BIRD_RADIUS + 160 }
    if afterlife == 1 { startAfterlife() }
    ghostStart()
    for (i, p) in pipeList.filter({ !$0.gold && $0.falling == nil }).sorted(by: { $0.gx < $1.gx }).enumerated() { p.k = passedCount() + 1 + i }
    bird.dynamic = true
    flapBird()
    // v147: watching someone's run
    if let W = WATCH, !W.done {
        runUsedBot = true
        if skinExists(W.g.skin) { ensureSkin(W.g.skin); birdColor = W.g.skin; applyBirdAnimation() }
    }
}
func removeStartUI() {
    run(tapTap, [.scale(0, 0.1), .call({ tapTap.added = false }), .scale(1.5, 0)], "remove")
    run(getReady, [.scale(0, 0.1), .call({ getReady.added = false }), .scale(1.2, 0)], "remove")
}

// ---------- Play button ----------
func handlePlayTap() {
    if !hitButton {
        hitButton = true
        playSound("swoosh")
        playButton.scale = 1.15
        run(scene, [.wait(0.1), .call({ haptic() }), .call({ playButton.scale = 1.2 }), .call({ flashScreen("#000", 0.25, 1, 0.25) }), .wait(0.25)], "playTap", done: prepareNewGame)
    }
    if let L = liveRoom, L.opp != nil, L.go == nil, !bird.dynamic { liveReady() }
}
func prepareNewGame() {
    if let W = WATCH, W.done { watchEnd() }
    if isGameOver { resetScene(); updateBirdTextures() } else { prepareInitialGame(); updateBirdTextures() }
    settingsButton.added = false; githubButton.added = false; shareButton.added = false; replayButton.added = false; leadersButton.added = false; playButton.added = false
    isWaitingToStart = true
    isGameOver = false
    hitButton = false
    if START_SCORE > 0 { score = START_SCORE }
    runUsedBot = false; botHandsOff = false
}
func prepareInitialGame() {
    removeAction(bird, "idle")
    tapTap.added = true; getReady.added = true; scoreLabel.added = true
    bird.x = width / 2.5; bird.y = height / 2
    flappyBird.added = false
    startIdleAnimation()
}

// ---------- Settings ----------
func handleSettingsTap() {
    if hitButton { return }
    hitButton = true
    playSound("swoosh")
    settingsButton.scale = 1.15
    run(scene, [.wait(0.1), .call({ haptic() }), .call({ settingsButton.scale = 1.2 }), .wait(0.1)], "settingsTap", done: showSettings)
}
func showSettings() {
    scaleTwice(settingsButton, 1, 0.1, 0, 0.1)
    scaleTwice(playButton, 1, 0.1, 0, 0.1)
    if isGameOver {
        scaleTwice(resultNode, 1, 0.1, 0, 0.1)
        for b in [shareButton, replayButton, leadersButton] where b.added { scaleTwice(b, 1, 0.1, 0, 0.1) }
    } else { scaleTwice(bird, 1, 0.1, 0, 0.1); scaleTwice(githubButton, 1, 0.1, 0, 0.1) }
    settingsNode.scale = 0; settingsNode.added = true
    openSheet("settings")
    run(scene, [.wait(0.2), .call({ hitButton = false })], "unlock")
}
func hideSettings() {
    scaleTwice(settingsNode, 1, 0.1, 0, 0.1)
    settingsNode.added = false
    scaleTwice(settingsButton, 1, 0.1, 1.25, 0.1)
    scaleTwice(playButton, 1, 0.1, 1.2, 0.1)
    if isGameOver {
        scaleTwice(resultNode, 1, 0.1, 1.2, 0.1)
        for b in [shareButton, replayButton, leadersButton] where b.added { scaleTwice(b, 1, 0.1, 1.2, 0.1) }
    } else { scaleTwice(bird, 1, 0.1, 1.5, 0.1); scaleTwice(githubButton, 1, 0.1, 1.2, 0.1) }
}
func handleSoundToggle() {
    haptic()
    if !playSounds { playSound("swoosh") }
    playSounds = !playSounds; saveBool("playSounds", playSounds); hauntedMusicSync()
}
func handleAutoplayToggle() {
    playSound("swoosh"); haptic()
    autoplay = !autoplay; saveBool("autoplay", autoplay)
    botTimer = 0
}
func setGameMode(_ id: String) {
    gameMode = id; saveStr("gameMode", id); saveBool("hardMode", id == "hard")
    resultBestLabel = String(bestScore())
}
func handleGhostToggle() {
    playSound("swoosh"); haptic()
    ghostOn = !ghostOn; saveBool("ghostOn", ghostOn)
}
func updateSettingsUI() {}

// ---------- TikTok (button + link) ----------
func handleGitHubTap() {
    if hitButton { return }
    hitButton = true
    playSound("swoosh")
    githubButton.scale = 1.15
    run(scene, [.wait(0.1), .call({ haptic() }), .call({ githubButton.scale = 1.2 }), .wait(0.9)], "githubTap", done: {
        if let u = URL(string: "https://www.tiktok.com/@iluvsmltwin") { UIApplication.shared.open(u) }
        hitButton = false
    })
}

// ---------- Flap / rotation ----------
func flapBird() {
    if let W = WATCH, !W.done, bird.dynamic, sceneTime > gameStartTime + 0.01 { return }   // no taps while watching
    if !(moving.speed > 0) { return }
    if !bird.dynamic { return }
    if !(bird.y < height + C.minimumBirdYOffset) { return }
    lastFlapTime = sceneTime
    bird.rot = C.flapRotation
    bird.vy = 0
    bird.vy += C.flapImpulse / BIRD_MASS
    if playSounds { rawPlay("wing") }
    trailFlap(); appHaptic("flap")
}
func updateBirdRotation(_ dt: Double) {
    if !bird.dynamic { return }
    let timeSinceFlap = sceneTime - lastFlapTime
    if timeSinceFlap < C.flapRotationHold { bird.rot = C.flapRotation; return }
    let velocityY = bird.vy
    let targetRotation = min(max(velocityY * (velocityY < 0.4 ? 0.003 : 0.001), -1.57), 0.6)
    let k = 1 - pow(1 - 0.15, dt * 60)
    bird.rot += (targetRotation - bird.rot) * k
    bird.speed = targetRotation < -0.7 ? 2 : 1
}

// ---------- Score ----------
func handleScore() {
    if afterlife >= 2 { return }
    if haunted { score -= 1; haptic(); playSound("point"); scaleTwice(scoreLabel, 1.5, 0.1, 1, 0.1); return }
    score += 1
    trailScore()
    strangerWave(score)
    haptic()
    playSound("point")
    scaleTwice(scoreLabel, 1.5, 0.1, 1, 0.1)
}

// ---------- Game over ----------
func gameOver() {
    if isShowingGameOver { return }
    isShowingGameOver = true
    recordDeath()
    if ending.swarmed || afterlife == 2 { afterlife = 1 }
    isGameOver = true
    hapticError()
    flashScreen("#fff", 0.1, 0.9, 0.25)
    bird.collideLandOnly = true
    applyBirdAnimation()
    playSound("hit")
    run(scene, [.wait(0.2), .call({ playSound("die") })])
    gameOverNode.scale = 0; gameOverNode.added = true
    run(scene, [.wait(0.1), .call({ scoreLabel.added = false }), .call({ scaleTwice(gameOverNode, 1, 0.1, 1.25, 0.1) })])
    moving.speed = 0
    bird.vy = 0
    bird.vy += 20 / BIRD_MASS
    // add-ons (in the website's order): the live duel hears about it, then your stats count the game
    liveDied(score)
    if accCounting() { ACC_ST.g += 1; ACC_ST.p += max(0, score); accSaveStats(); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { accFlushStats() } }
}
func handleGroundCollision() {
    if hasHitGround { return }
    hasHitGround = true
    ghostRunEnded()
    bird.speed = 0.5
    if !isShowingGameOver { gameOver() }
    bird.vy = 0
    run(scene, [.wait(C.gameOverDelay), .call({ bird.speed = 0 }), .wait(C.resultDelay), .call({ playSound("swoosh"); addResultsAndButtons() })])
}
func addResultsAndButtons() {
    resultNode.scale = 0
    setResultScore(score)
    resultNode.added = true
    scaleTwice(resultNode, 1, 0.1, 1.25, 0.1)
    settingsButton.x = width / 2; settingsButton.y = height / 2 - 25
    settingsButton.scale = 0; settingsButton.added = true
    scaleTwice(settingsButton, 1, 0.1, 1.2, 0.1)
    if afterlife == 0 && replayHas() { replayButton.x = width / 2; replayButton.y = height / 2 - 25; replayButton.scale = 0; replayButton.added = true; scaleTwice(replayButton, 1, 0.1, 1.2, 0.1) }
    if afterlife == 0 { shareButton.x = width / 2 - 80; shareButton.y = height / 2 - 25; shareButton.scale = 0; shareButton.added = true; scaleTwice(shareButton, 1, 0.1, 1.2, 0.1) }
    if afterlife == 0 {
        leadersButton.y = height / 2 - 25; leadersButton.scale = 0; leadersButton.added = true; scaleTwice(leadersButton, 1, 0.1, 1.2, 0.1)
        let row = [shareButton, replayButton.added ? replayButton : nil, leadersButton, settingsButton].compactMap { $0 }
        for (i, b) in row.enumerated() { b.x = width / 2 + (Double(i) - Double(row.count - 1) / 2) * 77 }
    }
    playButton.scale = 0; playButton.added = true
    scaleTwice(playButton, 1, 0.1, 1.2, 0.1)
}
var resultBestLabel = "0"
func setResultScore(_ s: Int) {
    let previousHighScore = bestScore()
    if s > previousHighScore && START_SCORE == 0 && !runUsedBot { setBestScore(s) }
    result = ResultState(score: s, prevBest: previousHighScore, shownAt: sceneTime, medal: nil, lastI: -1, currentText: nil)
    newBadge.scale = 0; removeAllActions(newBadge)
    let b = Double(previousHighScore), sd = Double(s)
    result.medal = s <= 0 ? nil : (sd < b / 2 ? "copper_medal" : (sd < b ? "silver_medal" : (sd < b * 2 ? "gold_medal" : "platinum_medal")))
    sparkle.scale = 0; removeAllActions(sparkle)
    if s > 0 {
        run(sparkle, [.call({ sparkle.x = -88 + mrand() * 48; sparkle.y = -26 + mrand() * 41 }), .scale(0.7, 0.3), .wait(0.5), .scale(0, 0.3)], "sparkle", rep: true)
    }
    lbRecord(s)
}
func updateResultCount() {
    guard var lastI = result.lastI else { return }
    let s = result.score
    let t = sceneTime - result.shownAt
    if s < 0 { result.lastI = s; result.currentText = String(s); return }
    let i = s == 0 ? 0 : min(s, Int(floor(t / (1.5 / Double(s)))))
    if lastI + 1 <= i {
        for k in (lastI + 1)...i {
            if k > result.prevBest && START_SCORE == 0 && !runUsedBot {
                resultBestLabel = String(k)
                if k == s { run(newBadge, [.scale(0.7, 0.05), .scale(1.0, 0.05)], "pop") }
            }
        }
    }
    lastI = i
    result.lastI = lastI
    result.currentText = String(i)
}

// ---------- Reset ----------
func resetScene() {
    pipeList = []
    courseRng = { mrand() }
    resetEnding()
    resultNode.added = false
    gameOverNode.added = false
    updateSky()
    tapTap.added = true; getReady.added = true; scoreLabel.added = true
    scoreLabel.scale = 1
    score = 0
    moving.speed = 1; bird.speed = 1
    pipesNode.scale = 0
    bird.rot = 0
    bird.x = width / 2.5; bird.y = height / 2
    removeAllActions(bird)
    applyBirdAnimation()
    bird.dynamic = false; bird.vy = 0; bird.collideLandOnly = false
    hasHitGround = false; isGameOver = false; isShowingGameOver = false; isWaitingToStart = true
    lastFlapTime = 0
    startIdleAnimation()
}

// ---------- Flash ----------
func flashScreen(_ color: String, _ fadeIn: Double, _ peak: Double, _ fadeOut: Double) {
    let f = GNode(added: true, alpha: 0); f.color = color
    run(f, [Step(fadeTo: peak, d: fadeIn), Step(fadeTo: 0, d: fadeOut), .call({ f.added = false })], "flash")
    flashes.append(f)
}

// ---------- Simulation step ----------
let LINEAR_SLOP = 0.005 * PTM
let POLY_SKIN = 2 * LINEAR_SLOP
let VELOCITY_THRESHOLD = 1 * PTM
let RESTITUTION = 0.2
let CONTACT_R = BIRD_RADIUS + POLY_SKIN
func resolveAgainst(_ R: R4) -> Bool {
    let nx0 = max(R.cx - R.w / 2, min(bird.x, R.cx + R.w / 2)), ny0 = max(R.cy - R.h / 2, min(bird.y, R.cy + R.h / 2))
    var dx = bird.x - nx0, dy = bird.y - ny0
    var dist = (dx * dx + dy * dy).squareRoot()
    if dist >= CONTACT_R { return false }
    if dist < 1e-6 {
        let l = bird.x - (R.cx - R.w / 2), r = (R.cx + R.w / 2) - bird.x, b = bird.y - (R.cy - R.h / 2), t = (R.cy + R.h / 2) - bird.y
        let m = min(l, r, b, t)
        if m == t { dx = 0; dy = 1 } else if m == b { dx = 0; dy = -1 } else if m == l { dx = -1; dy = 0 } else { dx = 1; dy = 0 }
        dist = 0
    } else { dx /= dist; dy /= dist }
    let target = CONTACT_R - LINEAR_SLOP
    let vn = bird.vy * dy
    if abs(dy) > abs(dx) {
        if dist < target { bird.x += dx * (target - dist); bird.y += dy * (target - dist) }
    } else {
        let pen = target - dist; if pen > 0 { bird.x += dx * pen * 0.2; bird.y += dy * pen * 0.2 }
    }
    if vn < 0 {
        let bounce = -vn > VELOCITY_THRESHOLD ? -RESTITUTION * vn : 0
        bird.vy += (-vn + bounce) * dy
    }
    return true
}
func physicsStep(_ h: Double) {
    if !bird.dynamic { return }
    bird.vy += (GRAVITY + windAy) * h
    bird.vy *= 1 / (1 + h * LINEAR_DAMPING)
    bird.y += bird.vy * h
    if !bird.collideLandOnly && pipesNode.scale > 0 && !devGod {
        for p in pipeList {
            if p.falling != nil { continue }
            let R = pipeRects(p); if resolveAgainst(R.up) || resolveAgainst(R.down) { contactPipe = true }
        }
    }
    if resolveAgainst(R4(cx: 0, cy: 112, w: width, h: 224)) { contactGround = true }
}
var contactPipe = false
var contactGround = false

func update(_ dt: Double) {
    sceneTime += dt
    updateCreepy(dt)
    if !hasHitGround { updateBirdRotation(dt) }
    stepActions(scene, dt)
    stepActions(bird, dt)
    for n in [flappyBird, getReady, tapTap, scoreLabel, gameOverNode, resultNode, settingsNode, playButton, settingsButton, githubButton, shareButton, replayButton, leadersButton, newBadge, sparkle] { stepActions(n, dt) }
    for f in flashes { stepActions(f, dt) }
    flashes = flashes.filter { $0.added }
    bird.animT += dt * bird.speed

    if afterlife >= 2 { updateAfterlife(dt) }
    updateStrangers(dt)
    if ending.fill != nil { ending.fill! += dt }
    if shakeT < 5 { shakeT += dt }
    armyBuzzSync()
    let md = (ending.frozen || afterlife >= 3 ? 0 : dt) * moving.speed * speedMul() * (afterlife == 2 ? al.speed : 1)
    trailScroll = md > 0 ? md / C.pipeMoveSpeed : 0
    if md > 0 {
        let groundWidth = 336.0 * 2
        groundX -= md / C.groundMoveSpeed; while groundX <= -groundWidth { groundX += groundWidth }
        let skyWidth = 288.0 * 1.5
        skyX -= md / C.skyMoveSpeed; while skyX <= -skyWidth { skyX += skyWidth }
        for p in pipeList { let step = md / C.pipeMoveSpeed; p.gx -= step; p.traveled += step }
        pipeList = pipeList.filter { $0.traveled < $0.distance }
    }
    for p in pipeList where p.amp != nil && p.amp != 0 && p.falling == nil { p.y = p.y0! + p.amp! * sin(p.traveled * p.wk! + p.ph!) }
    updateWind(dt)
    updateWeather(dt)
    updateExtras(dt)

    updateFalling(dt * (moving.speed > 0 ? 1 : 0))
    endingUpdate(dt)

    contactGround = false; contactPipe = false
    var rem = dt; let H = 1.0 / 120
    while rem > 1e-9 {
        var h = min(H, rem)
        let botFly = botFlying()
        if botFly { h = min(h, max(1e-6, botNext)) }
        physicsStep(h); rem -= h
        if ghostRec != nil || WATCH != nil { ghostSample(sceneTime - rem - gameStartTime) }
        if botFly { botNext -= h; if botNext <= 1e-7 { botNext += BOT_STEP; if botNext < 1e-7 { botNext = BOT_STEP }; botDecide(sceneTime - rem, rem) } }
    }
    autoBot(dt)

    if bird.dynamic && !hasHitGround {
        for p in pipeList {
            let R = pipeRects(p)
            let inSensor = p.falling == nil && !p.gold && pipesNode.scale > 0 && circleRect(bird.x, bird.y, CONTACT_R, R.sensor)
            if inSensor && !p.scored {
                p.scored = true
                if (!isShowingGameOver && bird.speed == 1) || bird.speed == 2 { handleScore() }
            }
        }
        if !isShowingGameOver && ending.strangers.contains(where: { $0.kill && hypot($0.x - bird.x, $0.y - bird.y) < BIRD_RADIUS * 2 - 4 }) {
            contactPipe = true; ending.swarmed = true
            if ending.fill == nil { ending.fill = 0; armyRush(); shakeT = 0 }
        }
        if contactPipe && !isShowingGameOver && !devGod { gameOver() }
        if contactGround { if devGod && !isShowingGameOver { bird.vy = C.flapImpulse / BIRD_MASS } else { handleGroundCollision() } }
    }
    if resultNode.added { updateResultCount() }
}

// ---------- STOP button (shown while Autoplay is on) ----------
func stopButtonVisible() -> Bool { autoplay && !settingsNode.added && loadingAlpha == 0 }
func stopButtonRect() -> R4 {
    let left = -camX / camS, top = SH + camY / camS
    let w = 64.0, h = 28.0
    return R4(cx: left + 14 + w / 2, cy: top - (44 + safeTop) / camS - h / 2, w: w, h: h)
}
var safeTop = 0.0   // (the web page's 44 pt already sits under the status bar; the app adds the notch on top)
func handleStopTap() {
    autoplay = false; saveBool("autoplay", false); botPath = nil; botTimer = 0
    updateSettingsUI(); playSound("swoosh"); haptic()
}
let APP_VERSION = "5.3"

// ---------- Loop ----------
let CROSS_DISSOLVE = 0.35
var loadingAlpha = 1.0, dissolving = false, loadingHold = 0.0
var lastTs: Double? = nil
var devSlow = false, devGod = false, devBoxes = false, devMode = false
var SHOW_FPS = false
func loop(_ ts: Double) {
    if lastTs == nil { lastTs = ts }
    var dt = ts - lastTs!; lastTs = ts
    dt = min(max(dt, 0), 1.0 / 20)
    if dissolving {
        let n = max(1, Int(ceil(dt * 60 - 1e-6)))
        for _ in 0..<n { update(dt / Double(n) * (devSlow ? 0.5 : 1)) }
        if loadingHold > 0 { loadingHold -= dt } else { loadingAlpha = max(0, loadingAlpha - dt / CROSS_DISSOLVE) }
    }
    render()
    renderLoading()
}
func toScene(_ clientX: Double, _ clientY: Double) -> (Double, Double) {
    let x = (clientX - camX) / camS
    let y = SH - (clientY - camY) / camS
    return (x, y)
}
func pointerDown(_ cx: Double, _ cy: Double) {
    if loadingAlpha > 0 { return }
    let (x, y) = toScene(cx, cy)
    touchesBegan(x, y)
}
/// start the game (the website's Promise.all(...).finally)
func startEngine() {
    loadSettings()
    prepareSkins()
    didMove()
    dissolving = true
    dailyFresh()
}
