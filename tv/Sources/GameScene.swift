import SpriteKit

/// The game. Same rules and numbers as the web / iPhone version (which came from Brandon Plank's SpriteKit app):
/// a 1024 x 768 scene, gravity -1800 pt/s², a flap sets the speed to 486 pt/s, pipes move 200 pt/s, one pair a second.
protocol GameSceneHUD: AnyObject {
    func phaseChanged(_ phase: GameScene.Phase)
}

final class GameScene: SKScene {
    enum Phase { case title, ready, playing, dying, over }

    weak var hud: GameSceneHUD?
    private(set) var phase: Phase = .title { didSet { if oldValue != phase { hud?.phaseChanged(phase) } } }
    /// the bot flies (used for the screenshots the build takes)
    var autopilot = false

    // MARK: numbers (from the original app)
    private let W: CGFloat = 1024, H: CGFloat = 768
    private let PTM: CGFloat = 150
    private lazy var gravity: CGFloat = -12 * PTM
    private let birdScale: CGFloat = 1.5
    private lazy var birdRadius: CGFloat = 24 * birdScale / 2
    private lazy var birdMass: CGFloat = .pi * birdRadius * birdRadius / (PTM * PTM)
    private let flapImpulse: CGFloat = 22
    private let flapRotation: CGFloat = 0.45, flapRotationHold: TimeInterval = 0.60
    private let damping: CGFloat = 0.1
    private let moveSpeed: CGFloat = 200          // 1 / 0.005
    private let groundTop: CGFloat = 224
    private let pipeW: CGFloat = 60, pipeH: CGFloat = 1024, groupY: CGFloat = -352

    // MARK: state
    private(set) var mode = Prefs.mode
    private(set) var score = 0 { didSet { scoreLabel.text = "\(score)"; scoreInside.text = "\(score)" } }
    private var time: TimeInterval = 0, lastUpdate: TimeInterval = 0, lastFlap: TimeInterval = -9
    private var birdY: CGFloat = 0, birdX: CGFloat = 0, vy: CGFloat = 0, rot: CGFloat = 0
    private var dynamic = false, landOnly = false, hasHitGround = false, showingGameOver = false
    private var birdAnimT: TimeInterval = 0, birdSpeed: CGFloat = 1, movingSpeed: CGFloat = 1
    private var idleT: TimeInterval = 0, idleBaseY: CGFloat = 0
    private var groundX: CGFloat = 0, skyX: CGFloat = 0
    private var spawnTimer: TimeInterval = 0
    private var windAy: CGFloat = 0, windTarget: CGFloat = 0, windTimer: TimeInterval = 0, streakTimer: TimeInterval = 0
    private var birdId = "yellow"
    private var frames: [SKTexture] = []

    private struct Pipe {
        let node: SKNode, up: SKSpriteNode, down: SKSpriteNode
        var gx: CGFloat, traveled: CGFloat = 0, y: CGFloat, gap: CGFloat
        var scored = false
        var wave: (y0: CGFloat, amp: CGFloat, ph: CGFloat, wk: CGFloat)?
    }
    private var pipes: [Pipe] = []

    // MARK: nodes
    private let atlas = SKTextureAtlas(named: "textures")
    private let world = SKNode()
    private let pipeLayer = SKNode()
    private let bird = SKSpriteNode()
    private var skyNodes: [SKSpriteNode] = [], groundNodes: [SKSpriteNode] = []
    private var streaks: [(node: SKShapeNode, vy: CGFloat)] = []
    private lazy var logo = sprite("flappybird", 1.5, CGPoint(x: W / 2, y: H / 2 + 200))
    private lazy var getReady = sprite("get-ready", 1.2, CGPoint(x: W / 2, y: H / 2 + 130))
    private lazy var tapTap = sprite("taptap", 1.5, CGPoint(x: W / 2, y: H / 2))
    private lazy var gameOverNode = sprite("gameover", 1.5, CGPoint(x: W / 2, y: H / 2 + 210))
    private lazy var board = ScoreBoard(atlas: atlas)
    private let modeTag = SKLabelNode(fontNamed: "KongtextRegular")
    private let scoreLabel = SKLabelNode(fontNamed: "04b19"), scoreInside = SKLabelNode(fontNamed: "inside")
    private lazy var darkness = makeDarkness()
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 1024, height: 768))

    // sounds
    private let sWing = SKAction.playSoundFileNamed("sfx_wing.caf", waitForCompletion: false)
    private let sPoint = SKAction.playSoundFileNamed("sfx_point.wav", waitForCompletion: false)
    private let sHit = SKAction.playSoundFileNamed("sfx_hit.caf", waitForCompletion: false)
    private let sDie = SKAction.playSoundFileNamed("sfx_die.caf", waitForCompletion: false)
    private let sSwoosh = SKAction.playSoundFileNamed("sfx_swooshing.caf", waitForCompletion: false)
    func sound(_ a: SKAction) { if Prefs.sound { run(a) } }

    override init(size: CGSize) { super.init(size: size) }
    convenience override init() { self.init(size: CGSize(width: 1024, height: 768)) }
    required init?(coder: NSCoder) { fatalError() }

    private func tex(_ name: String) -> SKTexture { let t = atlas.textureNamed(name); t.filteringMode = .nearest; return t }
    private func sprite(_ name: String, _ scale: CGFloat, _ p: CGPoint) -> SKSpriteNode {
        let s = SKSpriteNode(texture: tex(name)); s.setScale(scale); s.position = p; return s
    }

    // MARK: setup
    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.31, green: 0.75, blue: 0.79, alpha: 1)
        addChild(world)
        world.addChild(pipeLayer); pipeLayer.zPosition = -2
        bird.zPosition = -1; world.addChild(bird)
        let land = tex("land")
        for i in 0..<4 {
            let g = SKSpriteNode(texture: land); g.setScale(2); g.zPosition = 0
            g.position = CGPoint(x: CGFloat(i) * (g.size.width - 1), y: g.size.height / 2)
            world.addChild(g); groundNodes.append(g)
        }
        for n in [logo, getReady, tapTap, gameOverNode] { n.zPosition = 5; addChild(n) }
        board.position = CGPoint(x: W / 2, y: H / 2 + 75); board.zPosition = 6; addChild(board)
        for (l, c, z, dx) in [(scoreLabel, UIColor.black, CGFloat(11), CGFloat(0)), (scoreInside, UIColor.white, CGFloat(10), CGFloat(-1.5))] {
            l.fontSize = 50; l.fontColor = c; l.zPosition = z; l.position = CGPoint(x: W / 2 + dx, y: 3 * H / 4); addChild(l)
        }
        modeTag.fontSize = 12; modeTag.fontColor = .white; modeTag.zPosition = 5; modeTag.position = CGPoint(x: W / 2, y: H / 2 + 72); addChild(modeTag)
        darkness.zPosition = 20; world.addChild(darkness)
        flash.anchorPoint = .zero; flash.zPosition = 50; flash.alpha = 0; addChild(flash)
        showTitle()
    }

    private func makeSky() {
        skyNodes.forEach { $0.removeFromParent() }; skyNodes = []
        let t = tex(Bool.random() ? "night-sky" : "day-sky")
        for i in 0..<4 {
            let s = SKSpriteNode(texture: t); s.setScale(1.5); s.zPosition = -3
            s.position = CGPoint(x: CGFloat(i) * (s.size.width - 1), y: s.size.height / 3.5 + groundTop)
            world.addChild(s); skyNodes.append(s)
        }
        skyX = 0
    }

    private func pickBird() {
        birdId = Prefs.bird == "random" || Birds.shared.info(Prefs.bird) == nil ? Birds.shared.randomId() : Prefs.bird
        frames = Birds.shared.frames(birdId)
        if let f = frames.first { bird.texture = f; bird.size = CGSize(width: f.size().width * birdScale, height: f.size().height * birdScale) }
    }
    /// called when you pick another bird / mode in the menus
    func refreshChoices() {
        mode = Prefs.mode
        if !dynamic { pickBird() }
        updateModeTag()
    }

    // MARK: screens
    func showTitle() {
        clearRun()
        makeSky(); pickBird()
        logo.isHidden = false; getReady.isHidden = true; tapTap.isHidden = true; gameOverNode.isHidden = true; board.isHidden = true
        scoreLabel.isHidden = true; scoreInside.isHidden = true
        birdX = W / 2; idleBaseY = H / 2 + 75; birdY = idleBaseY; idleT = 0
        phase = .title
        updateModeTag()
    }

    /// Get Ready: the bird waits, the next click starts the round
    func getReadyScreen() {
        clearRun()
        if phase == .over { makeSky() }
        mode = Prefs.mode
        pickBird()
        logo.isHidden = true; getReady.isHidden = false; tapTap.isHidden = false; gameOverNode.isHidden = true; board.isHidden = true
        score = 0; scoreLabel.isHidden = false; scoreInside.isHidden = false; scoreLabel.setScale(1); scoreInside.setScale(1)
        birdX = W / 2.5; idleBaseY = H / 2; birdY = idleBaseY; idleT = 0
        phase = .ready
        updateModeTag()
        sound(sSwoosh)
    }

    private func clearRun() {
        pipes.forEach { $0.node.removeFromParent() }; pipes = []
        streaks.forEach { $0.node.removeFromParent() }; streaks = []
        dynamic = false; landOnly = false; hasHitGround = false; showingGameOver = false
        vy = 0; rot = 0; birdSpeed = 1; movingSpeed = 1; windAy = 0; windTarget = 0
        world.yScale = 1; world.position = .zero
        bird.removeAllActions(); flash.alpha = 0
    }

    private func updateModeTag() {
        modeTag.text = mode == "normal" ? "" : Modes.info(mode).title.uppercased() + " MODE"
        modeTag.isHidden = phase != .ready
    }

    private func startRound() {
        phase = .playing
        getReady.run(.fadeOut(withDuration: 0.2)); tapTap.run(.fadeOut(withDuration: 0.2))
        getReady.run(.sequence([.wait(forDuration: 0.2), .run { [weak self] in self?.getReady.isHidden = true; self?.getReady.alpha = 1 }]))
        tapTap.run(.sequence([.wait(forDuration: 0.2), .run { [weak self] in self?.tapTap.isHidden = true; self?.tapTap.alpha = 1 }]))
        modeTag.isHidden = true
        dynamic = true; vy = 0
        spawnTimer = 0.25
        if mode == "flipped" { world.yScale = -1; world.position = CGPoint(x: 0, y: H) }
        flap()
    }

    // MARK: input
    /// a click on the remote, a tap on its touch surface, or the A button on a controller
    func primaryAction() {
        switch phase {
        case .ready: startRound()
        case .playing: if !autopilot { flap() }
        default: break
        }
    }

    private func flap() {
        guard dynamic, movingSpeed > 0, !showingGameOver, birdY < H + 20 else { return }
        lastFlap = time
        rot = flapRotation
        vy = flapImpulse / birdMass
        sound(sWing)
    }

    // MARK: modes
    private var turboMul: CGFloat { 1 + CGFloat(min(max(score, 0), 50)) * 0.016 }
    private var speedMul: CGFloat { mode == "hard" ? 1.25 : mode == "turbo" ? turboMul : 1 }
    private var modeGap: CGFloat { mode == "hard" ? 110 : mode == "tiny" ? 106 : mode == "wavy" ? 140 : 130 }
    private var spawnEvery: TimeInterval { mode == "hard" ? 1 : mode == "turbo" ? 1 / Double(turboMul.squareRoot()) : 1 }

    private func spawnPipe() {
        let q = Int(H / 4)
        var y = CGFloat(Int.random(in: q...(q * 2)))
        var wave: (CGFloat, CGFloat, CGFloat, CGFloat)? = nil
        if mode == "wavy" {
            let w = (y, 40 + CGFloat.random(in: 0..<30), CGFloat.random(in: 0..<(2 * .pi)), (2 * .pi) / (200 * (1.3 + CGFloat.random(in: 0..<0.8))))
            wave = w; y = w.0 + w.1 * sin(w.2)
        }
        let node = SKNode()   // (the layer itself sits between the sky and the bird)
        let up = SKSpriteNode(texture: tex("PipeUp")), down = SKSpriteNode(texture: tex("PipeDown"))
        for p in [up, down] {
            p.setScale(2)
            if mode == "hard" { p.color = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1); p.colorBlendFactor = 0.55 }
            node.addChild(p)
        }
        pipeLayer.addChild(node)
        var pipe = Pipe(node: node, up: up, down: down, gx: W + pipeW, y: y, gap: modeGap)
        if let w = wave { pipe.wave = (w.0, w.1, w.2, w.3) }
        place(pipe)
        pipes.append(pipe)
    }

    private func place(_ p: Pipe) {
        p.node.position = CGPoint(x: p.gx, y: groupY)
        p.up.position = CGPoint(x: 0, y: p.y)
        p.down.position = CGPoint(x: 0, y: p.y + pipeH + p.gap)
    }

    // MARK: the loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60 : min(1.0 / 20, currentTime - lastUpdate)
        lastUpdate = currentTime
        step(dt)
    }

    private func step(_ dt: TimeInterval) {
        time += dt
        let fdt = CGFloat(dt)
        // flapping wings
        birdAnimT += dt * Double(birdSpeed)
        if !frames.isEmpty { bird.texture = frames[[0, 1, 2, 1][Int(birdAnimT / 0.1) % 4]] }
        // idle float (title and Get Ready)
        if !dynamic && (phase == .title || phase == .ready) {
            idleT += dt
            let k = idleT.truncatingRemainder(dividingBy: 2)
            birdY = idleBaseY + 35 * CGFloat(k < 1 ? k : 2 - k)
        }
        // the world scrolls
        let md = fdt * movingSpeed * speedMul
        if md > 0 {
            groundX -= md * moveSpeed; if groundX <= -672 { groundX += 672 }
            skyX -= md * 10; if skyX <= -432 { skyX += 432 }
            for i in pipes.indices {
                pipes[i].gx -= md * moveSpeed; pipes[i].traveled += md * moveSpeed
                if let w = pipes[i].wave { pipes[i].y = w.y0 + w.amp * sin(w.ph + w.wk * pipes[i].traveled) }
                place(pipes[i])
            }
            pipes.removeAll { p in if p.traveled > W + 2 * pipeW + 25 + 60 { p.node.removeFromParent(); return true }; return false }
        }
        for (i, g) in groundNodes.enumerated() { g.position.x = groundX + CGFloat(i) * (g.size.width - 1) }
        for (i, s) in skyNodes.enumerated() { s.position.x = skyX + CGFloat(i) * (s.size.width - 1) }
        // new pipes
        if phase == .playing && movingSpeed > 0 && !showingGameOver {
            spawnTimer -= dt
            if spawnTimer <= 0 { spawnPipe(); spawnTimer += spawnEvery }
        }
        updateWind(dt)
        if autopilot { bot() }
        // physics in small steps
        var contactPipe = false, contactGround = false
        var rem = dt
        while rem > 1e-9 {
            let h = CGFloat(min(1.0 / 120, rem)); rem -= Double(h)
            guard dynamic else { break }
            vy += (gravity + windAy) * h
            vy *= 1 / (1 + h * damping)
            birdY += vy * h
            if !landOnly {
                for p in pipes {
                    let upR = CGRect(x: p.gx - pipeW / 2, y: groupY + p.y - pipeH / 2, width: pipeW, height: pipeH)
                    let dnR = CGRect(x: p.gx - pipeW / 2, y: groupY + p.y + pipeH + p.gap - pipeH / 2, width: pipeW, height: pipeH)
                    if hits(upR) || hits(dnR) { contactPipe = true }
                }
            }
            if birdY - birdRadius < groundTop { birdY = groundTop + birdRadius; if vy < 0 { vy = 0 }; contactGround = true }
        }
        // scoring: just past each pipe
        if dynamic && !hasHitGround && !showingGameOver {
            let bw = birdScale * 34
            for i in pipes.indices where !pipes[i].scored {
                let sx = pipes[i].gx + 30 + bw / 2 + 2
                if birdX + birdRadius > sx - 2 { pipes[i].scored = true; addPoint() }
            }
        }
        if dynamic && !hasHitGround {
            if contactPipe && !showingGameOver { gameOver() }
            if contactGround { groundHit() }
        }
        // the bird turns with its speed
        if dynamic && !hasHitGround {
            if time - lastFlap < flapRotationHold { rot = flapRotation } else {
                let target = min(max(vy * (vy < 0.4 ? 0.003 : 0.001), -1.57), 0.6)
                rot += (target - rot) * CGFloat(1 - pow(1 - 0.15, dt * 60))
                birdSpeed = target < -0.7 ? 2 : 1
            }
        }
        bird.position = CGPoint(x: birdX, y: birdY); bird.zRotation = rot
        // Darkness: the lantern follows the bird
        darkness.isHidden = !(mode == "dark" && (phase == .ready || phase == .playing || phase == .dying))   // the score card stays readable
        if !darkness.isHidden {
            darkness.position = bird.position
            let flick = 1 + 0.03 * sin(time * 9) + 0.025 * sin(time * 23)
            darkness.setScale(flick)
        }
    }

    private func hits(_ r: CGRect) -> Bool {
        let nx = max(r.minX, min(birdX, r.maxX)), ny = max(r.minY, min(birdY, r.maxY))
        let dx = birdX - nx, dy = birdY - ny
        return dx * dx + dy * dy < (birdRadius + 1.5) * (birdRadius + 1.5)
    }

    private func addPoint() {
        score += 1
        sound(sPoint)
        for l in [scoreLabel, scoreInside] { l.run(.sequence([.scale(to: 1.5, duration: 0.1), .scale(to: 1, duration: 0.1)])) }
    }

    // MARK: game over (same order and timing as the original)
    private func gameOver() {
        guard !showingGameOver else { return }
        showingGameOver = true
        phase = .dying
        flash.size = size; flash.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.1), .fadeAlpha(to: 0, duration: 0.25)]))
        landOnly = true
        sound(sHit)
        run(.sequence([.wait(forDuration: 0.2), .run { [weak self] in if let s = self { s.sound(s.sDie) } }]))
        gameOverNode.isHidden = false; gameOverNode.setScale(0)
        run(.sequence([.wait(forDuration: 0.1), .run { [weak self] in
            guard let s = self else { return }
            s.scoreLabel.isHidden = true; s.scoreInside.isHidden = true
            s.gameOverNode.run(.sequence([.scale(to: 1.25 * 1.5, duration: 0.1), .scale(to: 1.5, duration: 0.1)]))
        }]))
        movingSpeed = 0
        vy = 20 / birdMass
    }

    private func groundHit() {
        guard !hasHitGround else { return }
        hasHitGround = true
        birdSpeed = 0.5
        if !showingGameOver { gameOver() }
        vy = 0
        run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in self?.birdSpeed = 0 }, .wait(forDuration: 0.2), .run { [weak self] in self?.showResults() }]))
    }

    private func showResults() {
        sound(sSwoosh)
        let prev = Prefs.best(mode)
        Prefs.setBest(mode, score)
        board.show(score: score, previousBest: prev)
        board.isHidden = false; board.setScale(0)
        board.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1, duration: 0.1)]))
        phase = .over
    }

    // MARK: Windy mode
    private func updateWind(_ dt: TimeInterval) {
        let on = mode == "windy" && dynamic && !showingGameOver && movingSpeed > 0
        if on {
            windTimer -= dt
            if windTimer <= 0 {
                windTimer = 1.8 + Double.random(in: 0..<2)
                windTarget = Double.random(in: 0..<1) < 0.2 ? 0 : (Bool.random() ? -1 : 1) * (260 + CGFloat.random(in: 0..<300))
            }
        } else { windTarget = 0; windTimer = 0.8 }
        windAy += (windTarget - windAy) * CGFloat(min(1, dt * 1.3))
        // wind lines
        if mode == "windy" && phase == .playing && !showingGameOver {
            streakTimer -= dt
            if streakTimer <= 0 {
                streakTimer = 0.12
                let path = CGMutablePath(); path.move(to: .zero); path.addLine(to: CGPoint(x: CGFloat.random(in: 40...90), y: 0))
                let n = SKShapeNode(path: path); n.strokeColor = UIColor(white: 1, alpha: 0.55); n.lineWidth = 2; n.zPosition = 4
                n.position = CGPoint(x: W + 20, y: CGFloat.random(in: groundTop + 20...H))
                world.addChild(n); streaks.append((n, windAy * 0.18))
            }
        }
        for i in streaks.indices {
            streaks[i].vy = windAy * 0.18
            streaks[i].node.position.x -= CGFloat(dt) * 650
            streaks[i].node.position.y += CGFloat(dt) * streaks[i].vy
        }
        streaks.removeAll { s in if s.node.position.x < -120 { s.node.removeFromParent(); return true }; return false }
    }

    // MARK: Darkness mode: a lantern around the bird
    private func makeDarkness() -> SKSpriteNode {
        let px = 1024, r: CGFloat = 52   // gradient radius in texture pixels
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(UIColor(red: 4 / 255, green: 4 / 255, blue: 12 / 255, alpha: 0.94).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))
        let c = CGPoint(x: px / 2, y: px / 2)
        ctx.setBlendMode(.copy)
        let colors = [UIColor(red: 0.016, green: 0.016, blue: 0.047, alpha: 0).cgColor, UIColor(red: 0.016, green: 0.016, blue: 0.047, alpha: 0.06).cgColor,
                      UIColor(red: 0.016, green: 0.016, blue: 0.047, alpha: 0.62).cgColor, UIColor(red: 0.016, green: 0.016, blue: 0.047, alpha: 0.94).cgColor] as CFArray
        let g = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.45, 0.8, 1])!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
        let t = SKTexture(cgImage: ctx.makeImage()!)
        let n = SKSpriteNode(texture: t)
        n.size = CGSize(width: CGFloat(px) * 125 / r, height: CGFloat(px) * 125 / r)   // the light reaches 125 points
        let glow = SKShapeNode(circleOfRadius: 90); glow.fillColor = UIColor(red: 1, green: 0.75, blue: 0.35, alpha: 0.10); glow.strokeColor = .clear
        n.addChild(glow)
        n.isHidden = true
        return n
    }

    // MARK: autopilot (for the build's screenshots)
    private func bot() {
        guard phase == .playing, dynamic, !showingGameOver else { return }
        let next = pipes.first { $0.gx + pipeW / 2 + birdRadius > birdX - 5 }
        let target: CGFloat = next.map { groupY + $0.y + pipeH / 2 + $0.gap / 2 - 8 } ?? H / 2
        if birdY < target - 30 && vy <= 0 { flap() }   // a flap rises about 65 points, so this keeps the bird near the middle of the gap
    }
}

/// The score card after a round (score counting up, best, medal), like the original ResultBoard.
final class ScoreBoard: SKSpriteNode {
    private let cur = SKLabelNode(fontNamed: "04b19"), curIn = SKLabelNode(fontNamed: "inside")
    private let best = SKLabelNode(fontNamed: "04b19"), bestIn = SKLabelNode(fontNamed: "inside")
    private let medal = SKSpriteNode(), newTag: SKSpriteNode, sparkle: SKSpriteNode
    private let atlas: SKTextureAtlas

    init(atlas: SKTextureAtlas) {
        self.atlas = atlas
        let t = atlas.textureNamed("scoreboard"); t.filteringMode = .nearest
        let nt = atlas.textureNamed("new"); nt.filteringMode = .nearest
        let st = atlas.textureNamed("sparkle"); st.filteringMode = .nearest
        newTag = SKSpriteNode(texture: nt); sparkle = SKSpriteNode(texture: st)
        super.init(texture: t, color: .clear, size: t.size())
        for (l, c, x, y, z) in [(cur, UIColor.black, CGFloat(75), CGFloat(7), CGFloat(2)), (curIn, .white, 74.5, 7, 1), (best, .black, 75, -35, 2), (bestIn, .white, 74.5, -35, 1)] {
            l.fontSize = 16; l.fontColor = c; l.position = CGPoint(x: x, y: y); l.zPosition = z; l.horizontalAlignmentMode = .center; addChild(l)
        }
        medal.position = CGPoint(x: -64, y: -6); medal.zPosition = 1; addChild(medal)
        newTag.position = CGPoint(x: 35, y: -6); newTag.zPosition = 1; newTag.setScale(0); addChild(newTag)
        sparkle.zPosition = 3; sparkle.setScale(0); addChild(sparkle)
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func show(score: Int, previousBest: Int) {
        removeAllActions(); newTag.setScale(0); sparkle.removeAllActions(); sparkle.setScale(0)
        set(cur, curIn, 0); set(best, bestIn, previousBest)
        let steps = max(score, 1), each = 1.5 / Double(steps)
        var acts: [SKAction] = []
        if score > 0 {
            for i in 1...score {
                acts.append(.wait(forDuration: each))
                acts.append(.run { [weak self] in
                    guard let s = self else { return }
                    s.set(s.cur, s.curIn, i)
                    if i > previousBest { s.set(s.best, s.bestIn, i); if i == score { s.newTag.run(.sequence([.scale(to: 0.7, duration: 0.05), .scale(to: 1, duration: 0.05)])) } }
                })
            }
        }
        run(.sequence(acts))
        let b = max(previousBest, 1)
        let name: String? = score <= 0 ? nil : score < b / 2 ? "copper-medal" : score < b ? "silver-medal" : score < b * 2 ? "gold-medal" : "platinum-medal"
        if let n = name { let t = atlas.textureNamed(n); t.filteringMode = .nearest; medal.texture = t; medal.size = t.size(); medal.isHidden = false } else { medal.isHidden = true }
        if score > 0 {
            sparkle.run(.repeatForever(.sequence([
                .run { [weak self] in self?.sparkle.position = CGPoint(x: CGFloat.random(in: -88...(-40)), y: CGFloat.random(in: -26...15)) },
                .scale(to: 0.7, duration: 0.3), .wait(forDuration: 0.5), .scale(to: 0, duration: 0.3)])))
        }
    }
    private func set(_ a: SKLabelNode, _ b: SKLabelNode, _ v: Int) { a.text = "\(v)"; b.text = "\(v)" }
}
