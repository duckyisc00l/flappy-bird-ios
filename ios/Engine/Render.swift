import Foundation
import UIKit

// ---------- Rendering (y-up scene points) ----------
let screen = SKCanvas()
var ctx: Canvas2D = screen

func spr(_ im: Img?, _ x: Double, _ y: Double, _ sx: Double, _ sy: Double, _ rot: Double) {
    guard let im = im, sx != 0, sy != 0 else { return }
    let w = Double(im.width), h = Double(im.height)
    ctx.save()
    ctx.translate(x, y)
    if rot != 0 { ctx.rotate(rot) }
    ctx.scale(sx, -sy)
    ctx.imageSmoothingEnabled = false
    ctx.drawImage(im, -w / 2, -h / 2, w, h)
    ctx.restore()
}
var LABEL_DX = 0.0, LABEL_DY = -1.05
func label(_ text: String, _ x: Double, _ y: Double, _ font: String, _ px: Double, _ color: String, _ grow: Double = 0) {
    ctx.save()
    ctx.translate(x, y); ctx.scale(1, -1)
    ctx.textAlign = "left"; ctx.textBaseline = "alphabetic"
    ctx.font = "400 \(px)px \(font), monospace"
    ctx.fill(color)
    let m = ctx.measureText(text)
    let inkMid = (m.actualBoundingBoxRight - m.actualBoundingBoxLeft) / 2
    ctx.fillText(text, -inkMid + LABEL_DX, LABEL_DY)
    if grow > 0 { ctx.lineJoin = "round"; ctx.lineWidth = grow; ctx.strokeStyle = .s(color); ctx.strokeText(text, -inkMid + LABEL_DX, LABEL_DY) }
    ctx.restore()
}
func nodeSpr(_ node: GNode, _ im: Img?, _ extraRot: Double = 0) { if node.added { spr(im, node.x, node.y, node.scale, node.scale, extraRot) } }

func render() {
    screen.begin()
    ctx = screen
    screen.boxH = boxH
    ctx.setTransform(1, 0, 0, 1, 0, 0)
    ctx.fill("#000"); ctx.fillRect(0, 0, boxW, boxH)
    if afterlife >= 4 { screen.end(); return }
    ctx.imageSmoothingEnabled = false
    let shk = shakeT < 1.3 ? pow(1 - shakeT / 1.3, 2) * 26 : 0
    let shx = (mrand() - 0.5) * 2 * shk, shy = (mrand() - 0.5) * 2 * shk
    ctx.setTransform(DPR * camS, 0, 0, -DPR * camS, DPR * (camX + shx), DPR * (camY + shy + camS * SH))

    let sky = skyIsNight ? img("night_sky") : img("day_sky")
    let skyW = 288 * 1.5, skyH = 512 * 1.5
    let flipWorld = worldFlipped()
    if flipWorld { ctx.save(); ctx.translate(0, SH); ctx.scale(1, -1) }
    for i in 0..<(2 + Int(floor(width / skyW))) { spr(sky, skyX + Double(i) * (skyW - 1), skyH / 3.5 + 112 * 2, 1.5, 1.5, 0) }
    drawCreepySky(skyX, skyW, skyH)
    drawCreepyFog()
    drawWeatherSky()

    if pipesNode.scale > 0 {
        renderEndingPipes()
        drawSeasonPipes()
    }

    drawStrangers()
    drawGhost()
    drawTrail(0)
    if bird.added { spr(birdFrame(), bird.x, bird.y, bird.scale, bird.scale, bird.rot) }
    drawTrail(1)

    let landW = 336 * 2.0
    for i in 0..<(2 + Int(floor(width / landW))) { spr(img("land"), groundX + Double(i) * (landW - 1), 112, 2, 2, 0) }
    drawSeasonGround()
    if score <= -1 { drawMassGraves() }
    drawArmyFill()
    drawCreepyOverlay()
    drawDevBoxes()
    if flipWorld { ctx.restore() }
    drawWeatherFront(flipWorld)
    drawDarkness(flipWorld)

    nodeSpr(flappyBird, img("flappy_logo"))
    nodeSpr(getReady, img("get_ready"))
    drawModeTag()
    nodeSpr(tapTap, img("taptap"))
    nodeSpr(githubButton, img("github_button"))
    nodeSpr(settingsButton, img("settings_button"))
    nodeSpr(shareButton, img("share_btn"))
    nodeSpr(replayButton, img("replay_btn"))
    nodeSpr(leadersButton, img("leaders_btn"))
    nodeSpr(playButton, img("play_button"))

    if scoreLabel.added && scoreLabel.scale > 0 {
        ctx.save(); ctx.translate(scoreLabel.x, scoreLabel.y); ctx.scale(scoreLabel.scale, scoreLabel.scale)
        label(String(score), -1.5, 0, "\"inside_font\"", 50, "#fff", 2.2)
        label(String(score), 0, 0, "\"inside_font\"", 50, "#fff", 2.2)
        label(String(score), 0, 0, "\"04b19\"", 50, "#000")
        if score < 0 {
            ctx.scale(1, -1)
            ctx.font = "400 50px \"04b19\", monospace"; ctx.textAlign = "left"; ctx.textBaseline = "alphabetic"
            let mAll = ctx.measureText(String(score))
            let mx = -(mAll.actualBoundingBoxRight - mAll.actualBoundingBoxLeft) / 2 + LABEL_DX
            ctx.lineJoin = "miter"; ctx.miterLimit = 10
            ctx.strokeStyle = "#000"; ctx.lineWidth = 2 * (0.5 + 2.5); ctx.strokeText("-", mx, LABEL_DY)
            ctx.strokeStyle = "#fff"; ctx.lineWidth = 2 * 0.5; ctx.strokeText("-", mx, LABEL_DY)
            ctx.fill("#fff"); ctx.fillText("-", mx, LABEL_DY)
        }
        ctx.restore()
    }

    nodeSpr(gameOverNode, img("gameover_text"))

    if resultNode.added && resultNode.scale > 0 {
        ctx.save(); ctx.translate(resultNode.x, resultNode.y); ctx.scale(resultNode.scale, resultNode.scale)
        spr(img("scoreboard"), 0, 0, 1, 1, 0)
        if newBadge.scale > 0 { spr(img("new_badge"), newBadge.x, newBadge.y, newBadge.scale, newBadge.scale, 0) }
        if let m = result.medal { spr(img(m), -64, -6, 1, 1, 0) }
        let cur = result.currentText ?? "0"
        label(cur, 75 - 0.49, 7, "\"inside_font\"", 16, "#fff", 0.8)
        label(cur, 75, 7, "\"inside_font\"", 16, "#fff", 0.8)
        label(cur, 75, 7, "\"04b19\"", 16, "#000")
        label(resultBestLabel, 75 - 0.49, -35, "\"inside_font\"", 16, "#fff", 0.8)
        label(resultBestLabel, 75, -35, "\"inside_font\"", 16, "#fff", 0.8)
        label(resultBestLabel, 75, -35, "\"04b19\"", 16, "#000")
        if sparkle.scale > 0 { spr(img("sparkle"), sparkle.x, sparkle.y, sparkle.scale, sparkle.scale, 0) }
        ctx.restore()
    }

    if afterlife < 3 { drawStopButton() }

    for f in flashes where f.alpha > 0 {
        ctx.globalAlpha = f.alpha; ctx.fill(f.color)
        ctx.fillRect(-5, -5, width + 10, height + 10)
        ctx.globalAlpha = 1
    }
    if afterlife == 3 { drawVision() }
}

/// LoadingViewController: black, the DotGears logo, "Done", the info lines; then a cross-dissolve into the game
let INFO_TEXT = ["Flappy Bird 4.5", "Copyright \u{00a9} 2019 - \(Calendar.current.component(.year, from: Date()))", "Brandon Plank, ThatcherDev", "Remix by Jordan Valladares", "See license for details."]
func renderLoading() {
    defer { screen.end() }
    if loadingAlpha <= 0 { return }
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0)
    ctx.globalAlpha = loadingAlpha
    ctx.fill("#000"); ctx.fillRect(0, 0, boxW, boxH)
    if let g = img("dotgears") {
        let s = min(240 / Double(g.width), 128 / Double(g.height))
        let w = Double(g.width) * s, h = Double(g.height) * s
        ctx.imageSmoothingEnabled = true
        ctx.drawImage(g, boxW / 2 - w / 2, boxH / 2 - h / 2, w, h)
    }
    ctx.fill("#fff"); ctx.textAlign = "center"; ctx.textBaseline = "alphabetic"
    ctx.font = "14px \"kongtext\", monospace"
    ctx.fillText("Done", boxW / 2, boxH / 2 + 64 + 8 + 14 * 896 / 1024)
    ctx.font = "10px \"kongtext\", monospace"
    let lh = 10.0 * (896 + 128 + 92) / 1024
    let bottom = boxH - 13
    for (i, line) in INFO_TEXT.enumerated() {
        let top = bottom - Double(INFO_TEXT.count - i) * lh
        ctx.fillText(line, boxW / 2, top + 10 * 896 / 1024)
    }
    ctx.globalAlpha = 1
}

// The panel's pixel letters (STOP, "WAVY MODE", names over ghosts)
let GLYPH: [String: [String]] = (Assets.data["GLYPH"] as? [String: [String]]) ?? [:]
func panelTextWidth(_ text: String) -> Double {
    var w = 0.0
    for ch in text { let k = String(ch); w += (ch == " " || GLYPH[k] == nil) ? 8 : Double(GLYPH[k]![0].count) * 2 + 2 }
    return w - 2
}
func drawPanelText(_ text: String, _ x0: Double, _ top: Double) {
    for pass in [0, 1] {
        ctx.fill(pass == 0 ? "#efeaa9" : "#fc7858")
        let dy = pass == 0 ? -2.0 : 0
        var x = x0
        for ch in text {
            if ch == " " { x += 8; continue }
            guard let g = GLYPH[String(ch)] else { x += 8; continue }
            for r in 0..<5 { let row = Array(g[r]); for c in 0..<row.count where row[c] == "#" { ctx.fillRect(x + Double(c) * 2, top - Double(r + 1) * 2 + dy, 2, 2) } }
            x += Double(g[0].count) * 2 + 2
        }
    }
}
func drawStopButton() {
    if !stopButtonVisible() { return }
    let r = stopButtonRect(), x = r.cx - r.w / 2, y = r.cy - r.h / 2
    ctx.fill("#533846"); ctx.fillRect(x, y, r.w, r.h)
    ctx.fill("#ded895"); ctx.fillRect(x + 2, y + 2, r.w - 4, r.h - 4)
    ctx.fill("#efeaa9"); ctx.fillRect(x + 2, y + r.h - 4, r.w - 4, 2)
    ctx.fill("#c4bd7a"); ctx.fillRect(x + 2, y + 2, r.w - 4, 2)
    drawPanelText("STOP", jsRound(r.cx - panelTextWidth("STOP") / 2), r.cy + 5)
}
func fgText(_ t: String, _ x: Double, _ top: Double, _ a: Double = 1) {
    let w = panelTextWidth(t)
    ctx.globalAlpha = 0.8 * a; ctx.fill("#533846"); ctx.fillRect(x - 6, top - 15, w + 12, 20)
    ctx.globalAlpha = a; drawPanelText(t, x, top); ctx.globalAlpha = 1
}
func fgLabel(_ name: String) -> String {
    let up = name.uppercased().filter { ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") || $0 == " " }
    let t = String(up.trimmingCharacters(in: .whitespaces).prefix(12))
    return t.isEmpty ? "FRIEND" : t
}
func drawModeTag() {
    // "WAVY MODE" under Get Ready
    if getReady.added && getReady.scale > 0 && gameMode != "normal" && !ending.on && afterlife == 0 {
        let t = modeInfo().name + " MODE"
        drawPanelText(t, jsRound(getReady.x - panelTextWidth(t) / 2), getReady.y - 44)
    }
    // v132: "RACING SAM 42" / who won
    if !(afterlife != 0 || ending.on) {
        if getReady.added && getReady.scale > 0, let f = friendList.first(where: { $0.id == raceId }), f.m == gameMode {
            let t = "RACING " + fgLabel(f.name) + " \((fgCache[f.id] ?? fgDecode(f.g))?.score ?? 0)"
            fgText(t, jsRound(getReady.x - panelTextWidth(t) / 2), getReady.y - (gameMode == "normal" ? 44 : 64))
        }
        if let ri = raceInfo, (isGameOver || isShowingGameOver) && gameOverNode.added && gameOverNode.scale > 0.5 {
            let n = fgLabel(ri.name), d = score - ri.score
            let t = d > 0 ? "YOU BEAT \(n) BY \(d)" : d == 0 ? "TIE WITH \(n)" : "\(n) WINS BY \(-d)"
            fgText(t, jsRound(gameOverNode.x - panelTextWidth(t) / 2), gameOverNode.y + 52)
        }
    }
    // v134: live duel countdown / status / result
    if let L = liveRoom {
        if let go = L.go {
            let left = Int(ceil(go.timeIntervalSinceNow)), t = left > 0 ? String(min(3, left)) : "GO"
            fgText("LIVE DUEL", jsRound(getReady.x - panelTextWidth("LIVE DUEL") / 2), getReady.y + 60)
            ctx.save(); ctx.translate(getReady.x, getReady.y - 70); ctx.scale(2.5, 2.5); fgText(t, jsRound(-panelTextWidth(t) / 2), 0); ctx.restore()
        } else if getReady.added && getReady.scale > 0, let o = L.opp {
            let t = L.ready ? "WAITING FOR " + fgLabel(o.name) : "LIVE VS " + fgLabel(o.name)
            fgText(t, jsRound(getReady.x - panelTextWidth(t) / 2), getReady.y - 64)
        }
        if (isGameOver || isShowingGameOver) && gameOverNode.added && gameOverNode.scale > 0.5 {
            let t = L.result ?? (L.myScore != nil && L.oppScore == nil && L.opp != nil ? fgLabel(L.opp!.name) + " IS STILL FLYING..." : "")
            if !t.isEmpty { fgText(t, jsRound(gameOverNode.x - panelTextWidth(t) / 2), gameOverNode.y + 52) }
        }
    }
}
func drawDevBoxes() {
    if !devBoxes { return }
    ctx.save(); ctx.lineWidth = 2
    ctx.strokeStyle = .s("rgba(255,40,40,0.9)")
    for p in pipeList where p.falling == nil {
        let R = pipeRects(p)
        for r in [R.up, R.down] { ctx.strokeRect(r.cx - r.w / 2, r.cy - r.h / 2, r.w, r.h) }
        ctx.strokeStyle = .s("rgba(255,220,0,0.8)"); ctx.strokeRect(R.sensor.cx - R.sensor.w / 2, R.sensor.cy - R.sensor.h / 2, R.sensor.w, R.sensor.h); ctx.strokeStyle = .s("rgba(255,40,40,0.9)")
    }
    ctx.strokeStyle = .s("rgba(0,255,120,0.95)"); ctx.beginPath(); ctx.arc(bird.x, bird.y, BIRD_RADIUS, 0, 7); ctx.stroke()
    ctx.strokeStyle = .s("rgba(255,140,0,0.9)"); ctx.beginPath(); ctx.moveTo(-2000, 224); ctx.lineTo(3000, 224); ctx.stroke()
    ctx.restore()
}
