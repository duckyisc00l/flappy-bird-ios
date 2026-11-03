import Foundation

// ===================== v170: leaving the game in the middle of a round pauses it =====================
// (a notification, another app, a call, Control Center: before, the round went on, or carried on the moment you
// came back, and the bird crashed before you could react). Tap to go on: that tap is a flap, like any other.
final class PauseState { var on = false, t = 0.0 }
let PAUSE = PauseState()
func pauseNow() {
    if PAUSE.on || !bird.dynamic || isGameOver || isShowingGameOver || autoplay || runUsedBot || afterlife != 0 || GL.phase == "crash" || liveRoom != nil || WATCH != nil { return }
    PAUSE.on = true; PAUSE.t = 0
}
/// the top of update(): true = everything stops, exactly where it was
func pauseFrozen(_ dt: Double) -> Bool { if PAUSE.on { PAUSE.t += dt; return true }; return false }
/// touchesBegan's add-on (the tap still flaps)
func pauseResume() { if PAUSE.on { PAUSE.on = false; playSound("swoosh") } }
func drawPause() {
    if !PAUSE.on { return }
    let v = viewBox()
    ctx.fill("rgba(0,0,0,0.45)"); ctx.fillRect(v.L - 10, -10, v.R - v.L + 20, SH + 20)
    let t1 = "PAUSED", t2 = "TAP TO GO ON", cx = width / 2, y = SH / 2 + 70
    glyphText(t1, jsRound(cx - glyphWidth(t1, 6) / 2), y, "#ffffff", 6)
    if Int(floor(Date().timeIntervalSince1970 / 0.6)) % 2 == 0 { glyphText(t2, jsRound(cx - glyphWidth(t2, 2) / 2), y - 52, "#efeaa9", 2) }
}
