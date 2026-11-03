import Foundation

// ===================== v174: animation: squash and stretch, and a feather puff when you crash =====================
// (only how things are drawn: the bird's hitbox, the physics and the pipes are exactly the same)
final class AnimState { var kind = "", t = 9.0 }
let ANIM = AnimState()
/// a spring that dies away: 1 at the start, then a small bounce back
func birdWobble() -> Double {
    let t = ANIM.t; if t > 0.6 || ANIM.kind.isEmpty || afterlife >= 2 { return 0 }
    return ANIM.kind == "flap" ? exp(-t * 9) * cos(t * 20) : exp(-t * 8) * cos(t * 18)
}
func birdSX() -> Double { let w = birdWobble(); return ANIM.kind == "flap" ? 1 - 0.13 * w : 1 + 0.26 * w }   // flap: taller and thinner; a hit: flat and wide
func birdSY() -> Double { let w = birdWobble(); return ANIM.kind == "flap" ? 1 + 0.15 * w : 1 - 0.22 * w }
func animFlap() { ANIM.kind = "flap"; ANIM.t = 0 }
func animHit(_ t: Double = 0) { ANIM.kind = "hit"; ANIM.t = t }
struct Feather { var x, y, vx, vy, t, life, ph: Double; var c: String }
var FEATHERS: [Feather] = []
func featherPuff() {
    var col = "#f8c030"
    if let im = birdFrame(), let e = birdEye(im) { col = e.L }
    for i in 0..<8 {
        let a = mrand() * .pi * 2, sp = 60 + mrand() * 110
        FEATHERS.append(Feather(x: bird.x + cos(a) * 6, y: bird.y + sin(a) * 6, vx: cos(a) * sp - 30, vy: sin(a) * sp + 80, t: 0, life: 0.9 + mrand() * 0.5, ph: mrand() * 6, c: i % 3 == 0 ? "#ffffff" : col))
    }
}
/// gameOver's add-on
func v174Crash(_ first: Bool) { if first { animHit(); if afterlife == 0 && !ending.on { featherPuff() } } }
/// the end of update()
func v174Tick(_ dt: Double) {
    ANIM.t += dt
    for i in FEATHERS.indices {
        var f = FEATHERS[i]
        f.t += dt; f.vy -= 260 * dt; f.vx *= pow(0.4, dt); f.vy = max(f.vy, -70)
        f.x += (f.vx + sin(f.t * 7 + f.ph) * 30) * dt; f.y += f.vy * dt
        FEATHERS[i] = f
    }
    FEATHERS.removeAll { $0.t > $0.life || $0.y < 112 }
    if !inRun() { FEATHERS.removeAll() }
}
func drawFeathers() {
    if FEATHERS.isEmpty || worldFlipped() { return }
    for f in FEATHERS {
        let a = min(1, (f.life - f.t) / 0.3), flip = sin(f.t * 9 + f.ph) > 0   // feathers flutter as they fall
        ctx.globalAlpha = max(0, a); ctx.fill("#533846")
        let w = flip ? 6.0 : 3, h = flip ? 3.0 : 6
        ctx.fillRect(jsRound(f.x - w / 2) - 1, jsRound(f.y - h / 2) - 1, w + 2, h + 2)
        ctx.fill(f.c); ctx.fillRect(jsRound(f.x - w / 2), jsRound(f.y - h / 2), w, h)
    }
    ctx.globalAlpha = 1
}
