import SpriteKit

/// Couch party: everybody's bird flies the same pipes; each phone flaps its own bird. Last bird flying wins.
/// Same physics as the one-player game. Uses the picked mode's pipes (Hard, Tiny Gap, Wavy, Turbo and Windy work;
/// Upside Down and Darkness play as Normal here, since several birds share the screen).
protocol PartySceneDelegate: AnyObject {
    func partyChanged()   // someone joined / left / flapped through a pipe / crashed, or the round started / ended
}

final class PartyScene: SKScene {
    enum Phase: String { case lobby, count, play, over }
    final class Player {
        let id: String
        var name: String, birdId: String, frames: [SKTexture] = []
        let node = SKSpriteNode(), tag = SKLabelNode(fontNamed: "KongtextRegular"), tagShadow = SKLabelNode(fontNamed: "KongtextRegular")
        var x: CGFloat = 0, y: CGFloat = 0, vy: CGFloat = 0, rot: CGFloat = 0
        var inRound = false, alive = false, landed = false, lastFlap: TimeInterval = -9, animT: TimeInterval = 0, speed: CGFloat = 1
        var score = 0, diedAt: TimeInterval = 0, lastSeen = Date(), slot = 0
        init(id: String, name: String, birdId: String) { self.id = id; self.name = name; self.birdId = birdId }
    }

    weak var party: PartySceneDelegate?
    private(set) var phase: Phase = .lobby
    private(set) var players: [Player] = []
    private(set) var round = 0
    private(set) var winners: [String] = []
    private(set) var countLeft: Double = 0

    private let W: CGFloat = 1024, H: CGFloat = 768, PTM: CGFloat = 150
    private lazy var gravity: CGFloat = -12 * PTM
    private let birdScale: CGFloat = 1.5, R: CGFloat = 18
    private lazy var mass: CGFloat = .pi * R * R / (PTM * PTM)
    private let groundTop: CGFloat = 224, pipeW: CGFloat = 60, pipeH: CGFloat = 1024, groupY: CGFloat = -352
    private var mode = "normal"
    private var time: TimeInterval = 0, last: TimeInterval = 0, idleT: TimeInterval = 0
    private var groundX: CGFloat = 0, skyX: CGFloat = 0, spawnTimer: TimeInterval = 0, moving: CGFloat = 1
    private var windAy: CGFloat = 0, windTarget: CGFloat = 0, windTimer: TimeInterval = 0
    private var bestScore = 0

    private struct Pipe { let node: SKNode, up: SKSpriteNode, down: SKSpriteNode; var gx: CGFloat, traveled: CGFloat = 0, y: CGFloat, gap: CGFloat; var scoredBy = Set<String>(); var wave: (CGFloat, CGFloat, CGFloat, CGFloat)? }
    private var pipes: [Pipe] = []
    private let atlas = SKTextureAtlas(named: "textures")
    private let pipeLayer = SKNode()
    private var skyNodes: [SKSpriteNode] = [], groundNodes: [SKSpriteNode] = []
    private let bigLabel = SKLabelNode(fontNamed: "04b19"), bigInside = SKLabelNode(fontNamed: "inside")
    private let sWing = SKAction.playSoundFileNamed("sfx_wing.caf", waitForCompletion: false)
    private let sPoint = SKAction.playSoundFileNamed("sfx_point.wav", waitForCompletion: false)
    private let sHit = SKAction.playSoundFileNamed("sfx_hit.caf", waitForCompletion: false)
    private let sSwoosh = SKAction.playSoundFileNamed("sfx_swooshing.caf", waitForCompletion: false)
    private func sound(_ a: SKAction) { if Prefs.sound { run(a) } }
    private func tex(_ n: String) -> SKTexture { let t = atlas.textureNamed(n); t.filteringMode = .nearest; return t }

    override init(size: CGSize) { super.init(size: size) }
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.31, green: 0.75, blue: 0.79, alpha: 1)
        pipeLayer.zPosition = -2; addChild(pipeLayer)
        let t = tex(Bool.random() ? "night-sky" : "day-sky")
        for i in 0..<4 {
            let s = SKSpriteNode(texture: t); s.setScale(1.5); s.zPosition = -3
            s.position = CGPoint(x: CGFloat(i) * (s.size.width - 1), y: s.size.height / 3.5 + groundTop); addChild(s); skyNodes.append(s)
            let g = SKSpriteNode(texture: tex("land")); g.setScale(2); g.zPosition = 0
            g.position = CGPoint(x: CGFloat(i) * (g.size.width - 1), y: g.size.height / 2); addChild(g); groundNodes.append(g)
        }
        for (l, c, z, dx) in [(bigLabel, UIColor.black, CGFloat(31), CGFloat(0)), (bigInside, UIColor.white, CGFloat(30), CGFloat(-2))] {
            l.fontSize = 90; l.fontColor = c; l.zPosition = z; l.position = CGPoint(x: W / 2 + dx, y: H / 2 + 40); addChild(l)
        }
        setBig("")
    }

    private func setBig(_ s: String) { bigLabel.text = s; bigInside.text = s }

    // MARK: players (called when phones talk to the TV)
    func playerSeen(id: String, name: String, bird: String) {
        let clean = String(name.trimmingCharacters(in: .whitespaces).prefix(14)).uppercased()
        if let p = players.first(where: { $0.id == id }) {
            p.lastSeen = Date()
            if !p.inRound || phase != .play { if p.name != clean || p.birdId != bird { p.name = clean.isEmpty ? p.name : clean; setBird(p, bird); party?.partyChanged() } }
            return
        }
        guard players.count < 8 else { return }
        let p = Player(id: id, name: clean.isEmpty ? "PLAYER \(players.count + 1)" : clean, birdId: bird)
        p.slot = (0..<8).first { s in !players.contains { $0.slot == s } } ?? 0
        setBird(p, bird)
        p.node.zPosition = -1
        for (l, c, z, d) in [(p.tagShadow, UIColor.black, CGFloat(5), CGFloat(2)), (p.tag, UIColor.white, CGFloat(6), CGFloat(0))] {
            l.fontSize = 11; l.fontColor = c; l.zPosition = z; l.horizontalAlignmentMode = .center; l.position = CGPoint(x: d, y: 30 - d)
            p.node.addChild(l)
        }
        p.tag.text = p.name; p.tagShadow.text = p.name
        addChild(p.node)
        players.append(p)
        layoutLobby()
        sound(sSwoosh)
        party?.partyChanged()
    }
    private func setBird(_ p: Player, _ bird: String) {
        p.birdId = Birds.shared.info(bird) != nil ? bird : Birds.shared.randomId()
        p.frames = Birds.shared.frames(p.birdId)
        if let f = p.frames.first { p.node.texture = f; p.node.size = CGSize(width: f.size().width * birdScale, height: f.size().height * birdScale) }
        p.tag.text = p.name; p.tagShadow.text = p.name
    }
    func playerLeft(_ id: String) {
        guard let i = players.firstIndex(where: { $0.id == id }) else { return }
        let p = players[i]
        if phase == .play && p.inRound && p.alive { kill(p, ground: false) }
        p.node.removeFromParent(); players.remove(at: i)
        layoutLobby(); checkEnd(); party?.partyChanged()
    }
    /// phones say hello every 2 seconds; one that has been quiet for 8 seconds has left
    func dropQuiet() {
        for p in players where Date().timeIntervalSince(p.lastSeen) > 8 { playerLeft(p.id) }
    }
    func flap(_ id: String) {
        guard phase == .play, let p = players.first(where: { $0.id == id }), p.inRound, p.alive, moving > 0, p.y < H + 20 else { return }
        p.lastFlap = time; p.rot = 0.45; p.vy = 22 / mass
        sound(sWing)
    }

    // MARK: rounds
    private func layoutLobby() {
        guard phase == .lobby || phase == .over else { return }
        let n = max(players.count, 1)
        for (i, p) in players.enumerated() where !(phase == .over && p.inRound) {
            p.x = W / 2 + (CGFloat(i) - CGFloat(n - 1) / 2) * 50; p.y = H / 2 - 40 + CGFloat(i % 2) * 34; p.rot = 0
        }
    }
    func startCountdown() {
        guard phase == .lobby || phase == .over, !players.isEmpty else { return }
        mode = Prefs.mode
        pipes.forEach { $0.node.removeFromParent() }; pipes = []
        winners = []; round += 1
        phase = .count; countLeft = 3
        for (i, p) in players.enumerated() {
            p.inRound = true; p.alive = true; p.landed = false; p.score = 0; p.vy = 0; p.rot = 0; p.speed = 1
            p.x = W / 2.5 - CGFloat(i % 4) * 6; p.y = H / 2 + CGFloat(i) * 6 - 20
        }
        moving = 1; windAy = 0; windTarget = 0
        sound(sSwoosh)
        party?.partyChanged()
    }
    private func beginRound() {
        phase = .play; setBig("")
        spawnTimer = 0.25
        for p in players where p.inRound { p.vy = 22 / mass; p.lastFlap = time; p.rot = 0.45 }
        party?.partyChanged()
    }
    private func kill(_ p: Player, ground: Bool) {
        guard p.alive else { return }
        p.alive = false; p.diedAt = time
        if !ground { p.vy = 20 / mass }
        sound(sHit)
        checkEnd()
        party?.partyChanged()
    }
    private func checkEnd() {
        guard phase == .play else { return }
        let inRound = players.filter { $0.inRound }
        if inRound.contains(where: { $0.alive }) { return }
        // the winner is the last bird down; birds that crashed in the same moment share it
        let lastDown = inRound.map { $0.diedAt }.max() ?? 0
        let top = inRound.filter { abs($0.diedAt - lastDown) < 0.05 }
        let best = top.map { $0.score }.max() ?? 0
        winners = top.filter { $0.score == best }.map { $0.name }
        bestScore = max(bestScore, best)
        moving = 0
        run(.sequence([.wait(forDuration: 1.4), .run { [weak self] in
            guard let s = self else { return }
            s.phase = .over
            s.setBig("")
            s.sound(s.sSwoosh); s.party?.partyChanged()
        }]))
    }

    // MARK: pipes (the picked mode's rules)
    private var turboMul: CGFloat { let best = players.filter { $0.alive }.map { $0.score }.max() ?? 0; return 1 + CGFloat(min(best, 50)) * 0.016 }
    private var speedMul: CGFloat { mode == "hard" ? 1.25 : mode == "turbo" ? turboMul : 1 }
    private var gapSize: CGFloat { mode == "hard" ? 110 : mode == "tiny" ? 106 : mode == "wavy" ? 140 : 130 }
    private var spawnEvery: TimeInterval { mode == "turbo" ? 1 / Double(turboMul.squareRoot()) : 1 }
    private func spawnPipe() {
        let q = Int(H / 4)
        var y = CGFloat(Int.random(in: q...(q * 2)))
        var wave: (CGFloat, CGFloat, CGFloat, CGFloat)? = nil
        if mode == "wavy" { let w = (y, 40 + CGFloat.random(in: 0..<30), CGFloat.random(in: 0..<(2 * .pi)), (2 * .pi) / (200 * (1.3 + CGFloat.random(in: 0..<0.8)))); wave = w; y = w.0 + w.1 * sin(w.2) }
        let node = SKNode(), up = SKSpriteNode(texture: tex("PipeUp")), down = SKSpriteNode(texture: tex("PipeDown"))
        for s in [up, down] { s.setScale(2); if mode == "hard" { s.color = UIColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1); s.colorBlendFactor = 0.55 }; node.addChild(s) }
        pipeLayer.addChild(node)
        var p = Pipe(node: node, up: up, down: down, gx: W + pipeW, y: y, gap: gapSize); p.wave = wave
        place(p); pipes.append(p)
    }
    private func place(_ p: Pipe) { p.node.position = CGPoint(x: p.gx, y: groupY); p.up.position = CGPoint(x: 0, y: p.y); p.down.position = CGPoint(x: 0, y: p.y + pipeH + p.gap) }

    // MARK: loop
    override func update(_ currentTime: TimeInterval) {
        let dt = last == 0 ? 1.0 / 60 : min(1.0 / 20, currentTime - last); last = currentTime
        time += dt
        let fdt = CGFloat(dt)
        if phase == .count {
            countLeft -= dt
            setBig(countLeft > 0 ? "\(Int(ceil(countLeft)))" : "")   // (the number font has no letters)
            if countLeft <= 0 { beginRound() }
        }
        // the world scrolls
        let md = fdt * moving * speedMul * 200
        groundX -= md; if groundX <= -672 { groundX += 672 }
        skyX -= md / 20; if skyX <= -432 { skyX += 432 }
        for (i, g) in groundNodes.enumerated() { g.position.x = groundX + CGFloat(i) * (g.size.width - 1) }
        for (i, s) in skyNodes.enumerated() { s.position.x = skyX + CGFloat(i) * (s.size.width - 1) }
        for i in pipes.indices {
            pipes[i].gx -= md; pipes[i].traveled += md
            if let w = pipes[i].wave { pipes[i].y = w.0 + w.1 * sin(w.2 + w.3 * pipes[i].traveled) }
            place(pipes[i])
        }
        pipes.removeAll { p in if p.traveled > W + 200 { p.node.removeFromParent(); return true }; return false }
        if phase == .play && moving > 0 {
            spawnTimer -= dt
            if spawnTimer <= 0 { spawnPipe(); spawnTimer += spawnEvery }
        }
        // wind
        if mode == "windy" && phase == .play && moving > 0 {
            windTimer -= dt
            if windTimer <= 0 { windTimer = 1.8 + Double.random(in: 0..<2); windTarget = Double.random(in: 0..<1) < 0.2 ? 0 : (Bool.random() ? -1 : 1) * (260 + CGFloat.random(in: 0..<300)) }
        } else { windTarget = 0 }
        windAy += (windTarget - windAy) * CGFloat(min(1, dt * 1.3))
        // birds
        idleT += dt
        for p in players {
            p.animT += dt * Double(p.speed)
            if !p.frames.isEmpty { p.node.texture = p.frames[[0, 1, 2, 1][Int(p.animT / 0.1) % 4]] }
            let flying = p.inRound && (phase == .play || (phase == .over && !p.landed)) && !p.landed
            if (phase == .lobby || phase == .count || (phase == .over && !p.inRound)) {
                let k = (idleT + Double(p.slot) * 0.25).truncatingRemainder(dividingBy: 2)
                p.node.position = CGPoint(x: p.x, y: p.y + 35 * CGFloat(k < 1 ? k : 2 - k) - 17)
                p.node.zRotation = 0
                continue
            }
            if flying {
                var rem = dt
                while rem > 1e-9 {
                    let h = CGFloat(min(1.0 / 120, rem)); rem -= Double(h)
                    p.vy += (gravity + (p.alive ? windAy : 0)) * h
                    p.vy *= 1 / (1 + h * 0.1)
                    p.y += p.vy * h
                    if p.alive {
                        for q in pipes {
                            let up = CGRect(x: q.gx - pipeW / 2, y: groupY + q.y - pipeH / 2, width: pipeW, height: pipeH)
                            let dn = CGRect(x: q.gx - pipeW / 2, y: groupY + q.y + pipeH + q.gap - pipeH / 2, width: pipeW, height: pipeH)
                            if hits(p, up) || hits(p, dn) { kill(p, ground: false); break }
                        }
                    }
                    if p.y - R < groundTop { p.y = groundTop + R; p.vy = 0; p.landed = true; p.speed = 0; if p.alive { kill(p, ground: true) }; break }
                }
                if p.alive {
                    for i in pipes.indices where !pipes[i].scoredBy.contains(p.id) && p.x + R > pipes[i].gx + 30 + 25.5 {
                        pipes[i].scoredBy.insert(p.id); p.score += 1; sound(sPoint); party?.partyChanged()
                    }
                }
                if p.alive && time - p.lastFlap < 0.6 { p.rot = 0.45 } else {
                    let target = min(max(p.vy * (p.vy < 0.4 ? 0.003 : 0.001), -1.57), 0.6)
                    p.rot += (target - p.rot) * CGFloat(1 - pow(1 - 0.15, dt * 60))
                    if p.alive { p.speed = target < -0.7 ? 2 : 1 }
                }
            } else if p.landed {
                p.x -= md   // a crashed bird lies on the ground and scrolls away with it
            }
            p.node.position = CGPoint(x: p.x, y: p.y); p.node.zRotation = p.rot
        }
    }
    private func hits(_ p: Player, _ r: CGRect) -> Bool {
        let nx = max(r.minX, min(p.x, r.maxX)), ny = max(r.minY, min(p.y, r.maxY))
        return (p.x - nx) * (p.x - nx) + (p.y - ny) * (p.y - ny) < (R + 1.5) * (R + 1.5)
    }

    /// after a round: back to everyone standing in a row
    func backToLobby() {
        guard phase == .over else { return }
        phase = .lobby
        pipes.forEach { $0.node.removeFromParent() }; pipes = []
        for p in players { p.inRound = false; p.alive = false; p.landed = false; p.speed = 1 }
        moving = 1; setBig(""); layoutLobby(); party?.partyChanged()
    }

    /// what the phones are told (every second, and whenever something changes)
    func stateForPhones() -> [String: Any] {
        let ranked = players.sorted { (a: Player, b: Player) -> Bool in a.score != b.score ? a.score > b.score : a.diedAt > b.diedAt }
        var list: [[String: Any]] = []
        for p in ranked {
            let alive: Int = (p.inRound && p.alive) ? 1 : 0
            let inRound: Int = p.inRound ? 1 : 0
            list.append(["id": p.id, "name": p.name, "alive": alive, "in": inRound, "score": p.score])
        }
        let count: Int = max(0, Int(ceil(countLeft)))
        var st: [String: Any] = ["s": phase.rawValue, "n": round, "c": count]
        st["win"] = winners; st["mode"] = Modes.info(mode).title; st["pl"] = list
        return st
    }

    // MARK: pretend players (for the build's screenshots)
    var botIds = Set<String>()
    func botsThink() {
        guard phase == .play else { return }
        for p in players where botIds.contains(p.id) && p.alive {
            var target: CGFloat = H / 2
            for q in pipes {
                let right: CGFloat = q.gx + pipeW / 2 + R
                if right > p.x - 5 {
                    let mid: CGFloat = groupY + q.y + pipeH / 2
                    target = mid + q.gap / 2 - 8
                    break
                }
            }
            let wobble: CGFloat = CGFloat(p.slot) * 7 - 14
            let low: Bool = p.y < target - 30 + wobble
            if low && p.vy <= 0 && Double.random(in: 0..<1) < 0.985 { flap(p.id) }
        }
    }
}
