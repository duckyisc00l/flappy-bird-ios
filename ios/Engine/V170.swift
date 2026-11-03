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

// ===================== v171: "NEW BEST" the moment you pass your best score =====================
final class NewBestState { var best = 0, t = 9.0 }
let NB = NewBestState()
/// pixel letters with a dark edge, so they read on any sky
func glyphOutlined(_ text: String, _ x: Double, _ top: Double, _ col: String, _ k: Double) {
    for (dx, dy) in [(-k, 0.0), (k, 0), (0, -k), (0, k)] { glyphText(text, x + dx, top + dy, "#533846", k) }
    glyphText(text, x, top, col, k)
}
func newBestStart() { NB.best = bestScore(); NB.t = 9 }
func newBestScore() { if realRun() && !haunted && NB.best > 0 && score == NB.best + 1 { NB.t = 0; appHaptic("medium") } }
private var nbLastT = 0.0
func drawNewBest() {
    let now = Date().timeIntervalSince1970, dt = nbLastT > 0 ? min(0.1, now - nbLastT) : 0; nbLastT = now
    if NB.t > 1.6 { return }
    NB.t += dt
    if !scoreLabel.added || isShowingGameOver || PAUSE.on { return }
    let t = NB.t, a = min(1, (1.6 - t) / 0.35), k = t < 0.12 ? 4.0 : 3, txt = "NEW BEST"
    ctx.globalAlpha = max(0, a)
    glyphOutlined(txt, jsRound(width / 2 - glyphWidth(txt, k) / 2), jsRound(scoreLabel.y - 46 + min(t, 0.2) * 20), "#ffd23c", k)
    ctx.globalAlpha = 1
}

// ===================== v172: your own runs never stay in your race list =====================
// (a race of your own run saved before v164 kept coming back every time the game opened, and the list
// syncs with your account, so it's checked again every few seconds and before every round)
func ownFriend(_ f: Friend) -> Bool {
    let me = accSignedIn() ? ACCT.uid : nil
    if let me = me, let u = f.uid, u == me { return true }
    if let g = f.gid, lsList("fb_myRuns").contains(g) || linkCache.values.contains(g) { return true }
    return false
}
func purgeOwnRaces() {
    let gone = friendList.filter(ownFriend).map { $0.id }
    if gone.isEmpty { return }
    friendList.removeAll { gone.contains($0.id) }; saveFriends()
    if !raceId.isEmpty && gone.contains(raceId) { setRace(""); raceInfo = nil }
}
private var purgeTimer: Timer? = nil
func v172Start() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { purgeOwnRaces() }
    purgeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in purgeOwnRaces() }
}

// ===================== v172: tap anywhere to play again =====================
// once the score board has finished counting up, a tap anywhere that isn't a button starts the next round
func touchesBegan(_ px: Double, _ py: Double) {
    let ready = isGameOver && playButton.added && playButton.scale >= 0.99 && resultNode.added && sceneTime - result.shownAt > 1.4 && !hitButton && !PK.open && afterlife == 0
    touchesBeganBase(px, py)
    if ready && !hitButton && isGameOver && playButton.added { handlePlayTap() }
}
