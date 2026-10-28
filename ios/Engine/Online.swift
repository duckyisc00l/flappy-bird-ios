import Foundation
import UIKit

// ===================== online: accounts, leaderboard, races, live duels, friends, saves (the website's v134-v148) =====================

// ---------- accounts ----------
final class AcctState { var user: [String: Any]? = nil, profile: [String: Any]? = nil, needCode = false, ready = false, bests: [String: Int] = [:], recovering = false
    var uid: String? { user?["id"] as? String } }
let ACCT = AcctState()
extension AcctState { var userId: String? { uid } }
extension Optional where Wrapped == [String: Any] { var id: String? { self?["id"] as? String } }
func accSignedIn() -> Bool { ACCT.user != nil && ACCT.profile != nil && !ACCT.needCode }
func onlineName() -> String { accSignedIn() ? (ACCT.profile?["username"] as? String ?? "") : "" }
func myUsername() -> String { ACCT.profile?["username"] as? String ?? "" }
var playerName = ""
func accErr(_ e: Error) -> String {
    let m = (e as? NetError)?.message ?? e.localizedDescription, code = (e as? NetError)?.code ?? ""
    let mc = m + code
    func has(_ p: String, _ s: String) -> Bool { s.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil }
    if has("invalid login credentials", m) { return "Wrong username or password" }
    if has("database error saving new user", m) { return "That username is taken" }
    if has("already registered|already been registered|email_exists|user_already_exists", mc) { return "That email already has an account" }
    if has("rate limit|over_email_send", mc) { return "Too many emails right now. Try again in an hour" }
    if has("email.*invalid|invalid.*email", m) { return "That email doesn't look right" }
    if has("password should be|weak_password", mc) { return "Pick a longer password (8+ letters)" }
    if has("same_password|should be different", mc) { return "That's your old password. Pick a new one" }
    if has("invalid totp|invalid code|mfa_verification_failed|expired", mc) { return "Wrong code. Try the newest one" }
    if has("aal2|insufficient_aal", mc) { return "Enter your 2FA code first" }
    if has("failed to fetch|network|load failed", m) { return "You're offline" }
    return m.isEmpty ? "Something went wrong" : m
}
func accKey() -> String { (ACCT.uid ?? "-") + (ACCT.profile != nil ? "p" : "") + (ACCT.needCode ? "c" : "") }
@MainActor func accLoadProfile() async {
    guard let uid = ACCT.uid else { return }
    if let rows = try? await sbAsync("profiles?select=*&id=eq.\(uid)") as? [[String: Any]] {
        if ACCT.uid != uid { return }
        ACCT.profile = rows.first
    }
    if ACCT.profile != nil {
        playerName = myUsername(); saveStr("playerName", playerName)
        if let b = try? await accBests(uid) { ACCT.bests = b; lbSetSent(b) }
        accPushLook(); accFlushStats(); lbFlush()
        palsSignedIn()
    }
}
func accInit() {
    Auth.shared.onChange = { ev, s in Task { @MainActor in await accSession(ev, s) } }
    Task { @MainActor in
        if Auth.shared.session != nil { _ = await Auth.shared.token(); await accSession("INITIAL_SESSION", Auth.shared.session) }
        else { ACCT.ready = true }
    }
}
@MainActor func accSession(_ ev: String, _ session: [String: Any]?) async {
    let was = ACCT.uid, before = accKey()
    if let s = session, ACCT.profile != nil, (s["access_token"] as? String) == lastToken, ev != "PASSWORD_RECOVERY" { ACCT.user = s["user"] as? [String: Any] ?? ACCT.user; return }
    lastToken = session?["access_token"] as? String
    ACCT.user = session?["user"] as? [String: Any]
    if session == nil {
        ACCT.profile = nil; ACCT.needCode = false; ACCT.bests = [:]; if was != nil { lbSetSent([:]) }
        palsSignedOut(); ACCT.ready = true
        if accKey() != before { accChanged() }
        return
    }
    if ACCT.user == nil { _ = try? await Auth.shared.getUser(); ACCT.user = Auth.shared.user }
    let (cur, next) = Auth.shared.aal()
    ACCT.needCode = next == "aal2" && cur != "aal2"
    if !ACCT.needCode && (ACCT.profile == nil || (ACCT.profile?["id"] as? String) != ACCT.uid || ev == "SIGNED_IN" || ev == "MFA_CHALLENGE_VERIFIED") { await accLoadProfile() }
    ACCT.ready = true
    if accKey() != before { accChanged() }
}
private var lastToken: String? = nil
@MainActor func accSignOut() async {
    saveStr("pushUid", "")
    await Auth.shared.signOut()
    await accSession("SIGNED_OUT", nil)
}
func accChanged() {
    UIBridge.shared.accountChanged()
    lbFlush()
}
// ---- stats you build up while signed in ----
var ACC_ST = (g: 0, p: 0, f: 0, s: 0)
func loadAccStats() { if let o = jsonObj(localStorage.getItem("fb_accStats")) { ACC_ST = (Int(num(o["g"]) ?? 0), Int(num(o["p"]) ?? 0), Int(num(o["f"]) ?? 0), Int(num(o["s"]) ?? 0)) } }
func accSaveStats() { localStorage.setItem("fb_accStats", jsonStr(["g": ACC_ST.g, "p": ACC_ST.p, "f": ACC_ST.f, "s": ACC_ST.s])) }
func accCounting() -> Bool { accSignedIn() && !autoplay && !runUsedBot && START_SCORE == 0 && !devGod && !devSlow }
private var accStatBusy = false
func accFlushStats() {
    if !accSignedIn() || accStatBusy || (ACC_ST.g == 0 && ACC_ST.p == 0 && ACC_ST.f == 0 && ACC_ST.s == 0) { return }
    let d = ACC_ST; accStatBusy = true
    sb("rpc/add_stats", method: "POST", body: ["g": d.g, "p": d.p, "f": d.f, "s": d.s]) { r in
        accStatBusy = false
        if case .success(_) = r {
            ACC_ST = (max(0, ACC_ST.g - d.g), max(0, ACC_ST.p - d.p), max(0, ACC_ST.f - d.f), max(0, ACC_ST.s - d.s)); accSaveStats()
            if var p = ACCT.profile {
                for (k, v) in [("games", d.g), ("pipes", d.p), ("flaps", d.f), ("seconds", d.s)] { p[k] = Int(num(p[k]) ?? 0) + v }
                ACCT.profile = p
            }
        }
        accPushLook()
    }
}
func accPushLook() {
    guard accSignedIn(), let p = ACCT.profile, let id = p["id"] as? String else { return }
    let b = String(birdColor.prefix(40)), t = String(trailPick.prefix(40))
    if (p["bird"] as? String) == b && (p["trail"] as? String) == t { return }
    sb("profiles?id=eq.\(id)", method: "PATCH", body: ["bird": b, "trail": t], headers: ["Prefer": "return=minimal"]) { r in if case .success(_) = r { ACCT.profile?["bird"] = b; ACCT.profile?["trail"] = t } }
}
func accBests(_ uid: String) async throws -> [String: Int] {
    let rows = try await sbAsync("scores?select=mode,score&user_id=eq.\(uid)&order=score.desc&limit=300") as? [[String: Any]] ?? []
    var b: [String: Int] = [:]
    for r in rows { if let m = r["mode"] as? String, let s = num(r["score"]) { if b[m] == nil || Int(s) > b[m]! { b[m] = Int(s) } } }
    if let d = b[dailyKey()] { b["daily"] = d }
    return b
}
var accProfileId: String? = nil
func accGo(_ kind: String, _ id: String? = nil, replace: Bool = false) {
    if kind == "profile" { accProfileId = id ?? ACCT.uid }
    if !PK.open { openSheet(kind); return }
    if !replace && PK.kind != kind { PK.from[kind] = PK.kind }
    showPage(kind)
}

// ---------- leaderboard ----------
var LB_MODES = ["normal", "daily", "hard", "wavy", "flipped", "tiny", "turbo", "windy", "dark"]
var lbSent: [String: Int] = [:]
struct LBQ { var mode: String, score: Int, bird: String, uid: String }
var lbQueue: [LBQ] = []
func lbLoad() {
    if let o = jsonObj(localStorage.getItem("fb_lbSent")) { for (k, v) in o { lbSent[k] = Int(num(v) ?? 0) } }
    let a = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_lbQueue") ?? "[]").utf8))) as? [[String: Any]] ?? []
    lbQueue = a.compactMap { q in guard let m = q["mode"] as? String, let s = num(q["score"]), let u = q["uid"] as? String else { return nil }; return LBQ(mode: m, score: Int(s), bird: q["bird"] as? String ?? "yellow", uid: u) }
}
func lbSave() {
    localStorage.setItem("fb_lbSent", jsonStr(lbSent))
    localStorage.setItem("fb_lbQueue", jsonStr(lbQueue.map { ["mode": $0.mode, "score": $0.score, "bird": $0.bird, "uid": $0.uid] }))
}
func lbEligible(_ s: Int) -> Bool { s > 0 && s <= 1500 && START_SCORE == 0 && !runUsedBot && afterlife == 0 && !haunted && !(ending.on && s >= 1000) && !devGod && !devSlow }
private var lbBusy = false
func lbFlush() {
    Task { @MainActor in
        await lbFlushAsync()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { watchUploadBests() }
    }
}
@MainActor func lbFlushAsync() async {
    guard !onlineName().isEmpty, !lbBusy, let uid = ACCT.uid else { return }
    lbBusy = true; defer { lbBusy = false }
    lbQueue = lbQueue.filter { $0.uid == uid }
    while let q = lbQueue.first, accSignedIn(), ACCT.uid == uid {
        do { _ = try await sbAsync("scores", method: "POST", body: ["name": onlineName(), "mode": q.mode, "score": q.score, "bird": String(q.bird.prefix(40)), "device": deviceId, "user_id": uid], headers: ["Prefer": "return=minimal"]) }
        catch { return }
        lbSent[q.mode] = max(lbSent[q.mode] ?? 0, q.score); lbQueue.removeFirst(); lbSave()
    }
}
func lbRecord(_ s: Int) {
    let m = gameMode == "daily" ? dailyKey() : gameMode
    guard accSignedIn(), lbEligible(s), s > (lbSent[m] ?? 0), let uid = ACCT.uid else { return }
    lbQueue = lbQueue.filter { $0.uid == uid && !($0.mode == m && $0.score <= s) }; lbQueue.append(LBQ(mode: m, score: s, bird: birdColor, uid: uid)); lbSave()
    lbFlush()
}
func lbSetSent(_ b: [String: Int]) { lbSent = b; lbSave() }
func lbFetch(_ mode0: String, _ week: Bool) async throws -> [[String: Any]] {
    let mode = mode0 == "daily" ? dailyKey() : mode0
    var q = "scores?select=name,score,bird,user_id,created_at,profiles(avatar,avatar_bg)&mode=eq.\(mode)&user_id=not.is.null&order=score.desc,created_at.asc&limit=400"
    if week { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; q += "&created_at=gte." + f.string(from: Date(timeIntervalSinceNow: -7 * 86400)) }
    let rows = try await sbAsync(q) as? [[String: Any]] ?? []
    var seen = Set<String>(), out: [[String: Any]] = []
    for r in rows { if let u = r["user_id"] as? String, !seen.contains(u) { seen.insert(u); out.append(r) } }
    return out
}
var lbMode = "normal", lbWeek = false
let deviceId: String = {
    var d = loadStr("device", "")
    if d.range(of: "^[A-Za-z0-9]{16}$", options: .regularExpression) == nil { d = rid(16); saveStr("device", d) }
    return d
}()

// ---------- friends' ghosts and race links ----------
let FG_PREFIX = "FBGHOST1:"
struct Friend { var id: String, name: String, m: String, g: [String: Any], score: Int, skin: String, when: Double, gid: String? = nil, duel: String? = nil, round: Int? = nil, uid: String? = nil }
var friendList: [Friend] = []
var raceId = ""
var raceInfo: (name: String, score: Int)? = nil
var fgCache: [String: GhostRun] = [:]
func loadFriends() {
    raceId = loadStr("raceFriend", ""); playerName = loadStr("playerName", "")
    let a = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_friends") ?? "[]").utf8))) as? [[String: Any]] ?? []
    friendList = a.compactMap { o in
        guard let id = o["id"] as? String, let g = o["g"] as? [String: Any] else { return nil }
        return Friend(id: id, name: o["name"] as? String ?? "Friend", m: o["m"] as? String ?? "normal", g: g, score: Int(num(o["score"]) ?? 0), skin: o["skin"] as? String ?? "yellow", when: num(o["when"]) ?? 0,
                      gid: o["gid"] as? String, duel: o["duel"] as? String, round: num(o["round"]).map { Int($0) }, uid: o["uid"] as? String)
    }
}
@discardableResult func saveFriends() -> Bool {
    localStorage.setItem("fb_friends", jsonStr(friendList.map { f -> [String: Any] in
        var o: [String: Any] = ["id": f.id, "name": f.name, "m": f.m, "g": f.g, "score": f.score, "skin": f.skin, "when": f.when]
        if let v = f.gid { o["gid"] = v }; if let v = f.duel { o["duel"] = v }; if let v = f.round { o["round"] = v }; o["uid"] = f.uid ?? NSNull()
        return o
    }))
    return true
}
func setRace(_ id: String?) {
    raceId = id ?? ""; saveStr("raceFriend", raceId)
    if let f = friendList.first(where: { $0.id == raceId }), f.m != gameMode { setGameMode(f.m) }
}
func b64url(_ d: Data) -> String { d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
func fromB64url(_ s0: String) -> Data? { var s = s0.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/"); while s.count % 4 != 0 { s += "=" }; return Data(base64Encoded: s) }
func fgPack(_ obj: [String: Any]) -> String {
    let bytes = Data(jsonStr(obj).utf8)
    if let z = zlibDeflate(bytes) { return FG_PREFIX + "z" + b64url(z) }
    return FG_PREFIX + "j" + b64url(bytes)
}
func fgUnpack(_ text: String) throws -> [String: Any] {
    var t = text.filter { !$0.isWhitespace }
    guard let at = t.uppercased().range(of: FG_PREFIX) else { throw NetError(message: "That isn't a ghost code (it starts with \(FG_PREFIX))") }
    t = String(t[at.upperBound...])
    guard let kind = t.first else { throw NetError(message: "The code is cut off or has a typo") }
    guard var bytes = fromB64url(String(t.dropFirst())) else { throw NetError(message: "The code is cut off or has a typo") }
    if kind == "z" { guard let d = zlibInflate(bytes) else { throw NetError(message: "The code is cut off or has a typo") }; bytes = d }
    else if kind != "j" { throw NetError(message: "The code is cut off or has a typo") }
    guard let o = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any] else { throw NetError(message: "The code is cut off or has a typo") }
    guard let g = o["g"] as? [String: Any], num(g["v"]) == 1, MODES.contains(where: { $0.id == (o["m"] as? String) }) else { throw NetError(message: "This ghost is from a different version of the game") }
    if fgDecode(g) == nil { throw NetError(message: "The ghost inside the code is damaged") }
    return o
}
struct LastRun { var enc: [String: Any], score: Int, mode: String, raced: String?, bot: Bool }
var lastRun: LastRun? = nil
var linkCache: [String: String] = [:]
func uploadRun(_ enc: [String: Any], _ mode: String, _ extra: [String: Any] = [:]) async throws -> String {
    let id = rid(10)
    var body: [String: Any] = ["id": id, "name": onlineName().isEmpty ? "Player" : onlineName(), "user_id": ACCT.uid as Any? ?? NSNull(), "mode": mode, "score": enc["score"] ?? 0,
                               "bird": String((enc["skin"] as? String ?? "yellow").prefix(40)), "data": enc, "round": 1, "duel": id]
    for (k, v) in extra { body[k] = v }
    _ = try await sbAsync("ghosts", method: "POST", body: body, headers: ["Prefer": "return=minimal"])
    return id
}
func myBestLink(_ mode: String) async throws -> String? {
    guard let enc = jsonObj(localStorage.getItem(ghostKey(mode))), num(enc["v"]) == 1 else { return nil }
    let key = "\(mode):\(num(enc["seed"]) ?? 0):\(num(enc["score"]) ?? 0):\(onlineName())"
    if let id = linkCache[key] { return SITE + "#r=" + id }
    let id = try await uploadRun(enc, mode)
    linkCache[key] = id; localStorage.setItem("fb_links", jsonStr(linkCache))
    return SITE + "#r=" + id
}
func fetchRun(_ id: String) async throws -> [String: Any] {
    if id.range(of: "^[A-Za-z0-9]{8,12}$", options: .regularExpression) == nil { throw NetError(message: "That link isn't right") }
    guard let rows = try await sbAsync("ghosts?select=*&id=eq.\(id)") as? [[String: Any]], let r = rows.first else { throw NetError(message: "That race was not found") }
    return r
}
func fetchDuel(_ duel: String) async throws -> [[String: Any]] { try await sbAsync("ghosts?select=id,name,score,round,bird,created_at&duel=eq.\(duel)&order=round.asc") as? [[String: Any]] ?? [] }
@discardableResult func addFriendFromRun(_ row: [String: Any]) throws -> Friend {
    guard let data = row["data"] as? [String: Any], let g = fgDecode(data), let rowId = row["id"] as? String else { throw NetError(message: "That race is damaged") }
    let id = "r" + rowId, duel = row["duel"] as? String, round = Int(num(row["round"]) ?? 1)
    friendList = friendList.filter { $0.id != id && !($0.duel != nil && $0.duel == duel && ($0.round ?? 1) < round) }
    friendList.insert(Friend(id: id, name: String((row["name"] as? String ?? "Friend").prefix(14)), m: row["mode"] as? String ?? "normal", g: data, score: Int(num(row["score"]) ?? 0), skin: g.skin,
                             when: Date().timeIntervalSince1970 * 1000, gid: rowId, duel: duel, round: round, uid: row["user_id"] as? String), at: 0)
    if friendList.count > 20 { friendList = Array(friendList.prefix(20)) }
    saveFriends(); setRace(id)
    return friendList[0]
}
var challengeRow: [String: Any]? = nil
/// a race link or room link (pasted, or opened as flappybird://...)
func openLink(_ text: String) {
    let s = text
    if let r = s.range(of: "[#&?]live=([A-Za-z0-9]{4,8})", options: .regularExpression) {
        let code = String(s[r].split(separator: "=").last ?? "").uppercased(); joinLive(code); openSheet("live"); return
    }
    if let r = s.range(of: "[#&?]party=([A-Za-z0-9]{4,12})", options: .regularExpression) { _ = joinParty(String(s[r].split(separator: "=").last ?? "")); return }
    if let r = s.range(of: "[#&?]tv=([A-Za-z0-9]{8})", options: .regularExpression) { tvCode = String(s[r].split(separator: "=").last ?? "").uppercased(); if PK.open { showPage("tvapprove") } else { openSheet("tvapprove") }; return }
    guard let r = s.range(of: "[#&?]r=([A-Za-z0-9]{8,12})", options: .regularExpression) else { return }
    let id = String(s[r].split(separator: "=").last ?? "")
    Task { @MainActor in
        do {
            let row = try await fetchRun(id)
            try addFriendFromRun(row); challengeRow = row
            if PK.open { closePicker() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { openSheet("challenge") }
        } catch { challengeRow = nil; toast(accErr(error)) }
    }
}

// ---------- live duels ----------
final class LiveRoom {
    let code: String; var host: Bool; let ch: RTChannel
    var status = "connecting", opp: (device: String, name: String, bird: String, uid: String?)? = nil
    var oppState: (y: Double, r: Double, score: Int, round: Int, dead: Bool, at: Date)? = nil
    var ready = false, oppReady = false, go: Date? = nil, seed: UInt32 = 0, round = 0, myScore: Int? = nil, oppScore: Int? = nil, last = Date.distantPast, result: String? = nil
    init(_ c: String, _ h: Bool, _ ch: RTChannel) { code = c; host = h; self.ch = ch }
}
var liveRoom: LiveRoom? = nil
func joinLive(_ code: String, host: Bool = false) {
    leaveLive()
    let ch = RTChannel("fb-live-" + code, presenceKey: deviceId)
    let L = LiveRoom(code, host, ch); liveRoom = L
    ch.onPresenceSync = {
        let st = ch.presenceState(), others = st.keys.filter { $0 != deviceId }.sorted()
        let o = others.first.flatMap { st[$0]?.first }
        if let o = o, L.opp == nil || L.opp!.device != others[0] { L.opp = (others[0], o["name"] as? String ?? "Friend", o["bird"] as? String ?? "yellow", o["uid"] as? String); playSound("point") }
        if o == nil && L.opp != nil { L.opp = nil; L.oppReady = false; toast("Your friend left the duel") }
        if let o = o, L.opp != nil { L.opp!.name = o["name"] as? String ?? L.opp!.name; L.opp!.bird = o["bird"] as? String ?? L.opp!.bird; L.opp!.uid = o["uid"] as? String ?? L.opp!.uid }
        if let first = others.first, !L.host { L.host = deviceId < first ? false : L.host }
        liveRefresh()
    }
    ch.on("ready") { _ in L.oppReady = true; liveMaybeGo(); liveRefresh() }
    ch.on("go") { p in
        let sent = num(p["sent"]) ?? Date().timeIntervalSince1970 * 1000
        liveBegin(seedU32(num(p["seed"]) ?? 0), Int(num(p["round"]) ?? 1), 2600 - min(800, max(0, Date().timeIntervalSince1970 * 1000 - sent)))
    }
    ch.on("s") { p in
        let s = (num(p["y"]) ?? 0, num(p["r"]) ?? 0, Int(num(p["score"]) ?? 0), Int(num(p["round"]) ?? 0), p["dead"] as? Bool ?? false, Date())
        L.oppState = s
        if s.4 && L.oppScore == nil && s.3 == L.round { L.oppScore = s.2; liveCheckEnd() }
    }
    ch.onStatus = { st in
        if st == "SUBSCRIBED" { L.status = "in"; ch.track(["name": onlineName().isEmpty ? "Player" : onlineName(), "bird": birdColor, "uid": accSignedIn() ? (ACCT.uid! as Any) : (NSNull() as Any)]) }
        else if st == "CHANNEL_ERROR" { L.status = "error" }
        liveRefresh()
    }
    ch.subscribe()
}
func leaveLive() { guard let L = liveRoom else { return }; L.ch.unsubscribe(); liveRoom = nil; liveRefresh() }
func liveRefresh() { UIBridge.shared.refresh() }
func liveStatusText() -> String {
    guard let L = liveRoom else { return "" }
    if L.status == "connecting" { return "Connecting..." }
    if L.status == "error" { return "Couldn't connect. Check your internet and try again." }
    guard let o = L.opp else { return "Room \(L.code) - waiting for your friend to join..." }
    return o.name + " is here! Close this and tap Play when you are ready."
}
func liveReady() {
    guard let L = liveRoom, L.opp != nil else { return }
    L.ready = true; L.result = nil
    L.ch.send("ready", [:])
    liveMaybeGo()
}
func liveMaybeGo() {
    guard let L = liveRoom, L.ready, L.oppReady, L.go == nil, L.host else { return }
    let seed = UInt32.random(in: 0...UInt32.max), round = L.round + 1
    L.ch.send("go", ["seed": seed, "round": round, "sent": Date().timeIntervalSince1970 * 1000])
    liveBegin(seed, round, 2600)
}
func liveBegin(_ seed: UInt32, _ round: Int, _ ms: Double) {
    guard let L = liveRoom else { return }
    L.seed = seed; L.round = round; L.go = Date(timeIntervalSinceNow: ms / 1000); L.myScore = nil; L.oppScore = nil; L.oppState = nil; L.ready = false; L.oppReady = false; L.result = nil
    if PK.open { closePicker() }
    func enter() { if !isWaitingToStart && !bird.dynamic && playButton.added && !hitButton { handlePlayTap() } }
    enter(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { enter() }
}
var liveCourseNext = false
func liveTick() {
    guard let L = liveRoom else { return }
    if let g = L.go, Date() >= g { L.go = nil; if isWaitingToStart { liveCourseNext = true; startGame() } }
    if bird.dynamic && L.myScore == nil && L.round != 0 {
        if Date().timeIntervalSince(L.last) > 0.066 { L.last = Date(); L.ch.send("s", ["y": jsRound(bird.y), "r": (bird.rot * 100).rounded() / 100, "score": score, "round": L.round, "dead": false]) }
    }
}
func liveCourse() -> Bool {
    guard liveCourseNext, let L = liveRoom else { return false }
    liveCourseNext = false
    ghostRec = nil; ghostPlay = nil; raceInfo = nil
    pipeList = []; setSpawnerRemaining(0.75)
    courseRng = mulberry32(L.seed)
    return true
}
func liveDied(_ s: Int) {
    guard let L = liveRoom, L.round != 0, L.myScore == nil else { return }
    L.myScore = s
    L.ch.send("s", ["y": jsRound(bird.y), "r": 0, "score": s, "round": L.round, "dead": true])
    liveCheckEnd()
}
func liveCheckEnd() {
    guard let L = liveRoom, let my = L.myScore, let op = L.oppScore else { return }
    let n = L.opp != nil ? fgLabel(L.opp!.name) : "FRIEND", d = my - op
    L.result = d > 0 ? "YOU WIN BY \(d)!" : d == 0 ? "TIE WITH \(n)" : "\(n) WINS BY \(-d)"
    playSound(d > 0 ? "point" : "swoosh")
    if L.host, let ouid = L.opp?.uid, accSignedIn(), ouid != ACCT.uid { recordMatch("live", "live-\(L.code)-\(L.round)-\(L.seed % 1000000)", ouid, my, op, gameMode) }
}

// ---------- friends (accounts), presence, invites ----------
struct FriendRel { var p: [String: Any], accepted: Bool, incoming: Bool, outgoing: Bool, at: String }
final class FRState { var list: [FriendRel] = [], inbox: [[String: Any]] = [], at = 0.0, loading = false }
let FR = FRState()
var inboxSeen: [String] = []
func saveSeen() { localStorage.setItem("fb_inboxSeen", jsonStr(Array(inboxSeen.suffix(200)))) }
func pid(_ p: [String: Any]) -> String { p["id"] as? String ?? "" }
func palsIsFriend(_ uid: String) -> Bool { FR.list.contains { $0.accepted && pid($0.p) == uid } }
func palsRel(_ uid: String) -> String { guard let f = FR.list.first(where: { pid($0.p) == uid }) else { return "none" }; return f.accepted ? "friend" : f.incoming ? "incoming" : "outgoing" }
func palsBadge() -> Int { if !accSignedIn() { return 0 }; return FR.list.filter { $0.incoming }.count + FR.inbox.filter { !inboxSeen.contains($0["id"] as? String ?? "") }.count }
@MainActor func palsLoadAsync() async {
    guard accSignedIn(), let me = ACCT.uid, !FR.loading else { return }
    FR.loading = true; defer { FR.loading = false; palsRedraw() }
    let P = "id,username,avatar,avatar_bg"
    async let a = sbAsync("friendships?select=a,b,accepted,created_at,pa:profiles!friendships_a_fkey(\(P)),pb:profiles!friendships_b_fkey(\(P))&order=created_at.desc&limit=400")
    async let b = sbAsync("ghosts?select=id,name,mode,score,bird,round,duel,created_at,user_id&to_user=eq.\(me)&order=created_at.desc&limit=20")
    guard let fs = try? await a as? [[String: Any]], let inbox = try? await b as? [[String: Any]] else { return }
    if !accSignedIn() || ACCT.uid != me { return }
    FR.list = fs.compactMap { f in
        let out = (f["a"] as? String) == me
        guard let p = (out ? f["pb"] : f["pa"]) as? [String: Any] else { return nil }
        let acc = f["accepted"] as? Bool ?? false
        return FriendRel(p: p, accepted: acc, incoming: !out && !acc, outgoing: out && !acc, at: f["created_at"] as? String ?? "")
    }
    FR.inbox = inbox; FR.at = Date().timeIntervalSince1970 * 1000
}
func palsLoad() { Task { @MainActor in await palsLoadAsync() } }
func palsRedraw() { UIBridge.shared.refresh() }
final class RTState { var uid: String? = nil, online: RTChannel? = nil, me: RTChannel? = nil, people = Set<String>() }
let RT = RTState()
func palsSignedIn() {
    guard accSignedIn(), let uid = ACCT.uid else { return }
    palsLoad()
    if RT.uid != uid {
        palsSignedOutBase(); RT.uid = uid
        let on = RTChannel("fb-online", presenceKey: uid)
        on.onPresenceSync = { RT.people = Set(on.presenceState().keys); palsRedraw() }
        on.onStatus = { st in if st == "SUBSCRIBED" { on.track(["at": Date().timeIntervalSince1970 * 1000]) } }
        on.subscribe()
        let me = RTChannel("fb-u-" + uid)
        me.on("m") { p in rtMessage(p) }
        me.subscribe()
        RT.online = on; RT.me = me
    }
    // v139: saved progress; v143: come back to the Apple TV approval
    if SV.uid != ACCT.uid { saveSync() }
    if tvCode != nil && PK.kind == "profile" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { if PK.open && tvCode != nil { showPage("tvapprove") } } }
}
private func palsSignedOutBase() {
    for c in [RT.online, RT.me] { c?.unsubscribe() }
    RT.online = nil; RT.me = nil; RT.uid = nil; RT.people = []; FR.list = []; FR.inbox = []; FR.at = 0
}
func palsSignedOut() { palsSignedOutBase(); SV.uid = nil; SV.lastSent = ""; SV.timer?.invalidate() }
func isOnline(_ uid: String) -> Bool { RT.people.contains(uid) }
func rtSend(_ uid: String, _ payload: [String: Any]) {
    guard accSignedIn(), uid != ACCT.uid, let p = ACCT.profile else { return }
    let ch = RTChannel("fb-u-" + uid)
    var msg = payload
    msg["from"] = ["id": ACCT.uid!, "name": myUsername(), "av": p["avatar"] ?? NSNull(), "bg": p["avatar_bg"] ?? NSNull()]
    var sent = false
    ch.onStatus = { st in if st == "SUBSCRIBED" && !sent { sent = true; ch.send("m", msg); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { ch.unsubscribe() } } }
    ch.subscribe()
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { if !sent { ch.unsubscribe() } }
}
func rtMessage(_ m: [String: Any]) {
    let f = m["from"] as? [String: Any] ?? [:], n = String((f["name"] as? String ?? "A friend").prefix(14))
    guard let fid = f["id"] as? String, fid != ACCT.uid else { return }
    switch m["t"] as? String {
    case "req": toast(n + " wants to be your friend"); palsLoad()
    case "yes": toast(n + " is your friend now!"); palsLoad()
    case "race": toast(n + " sent you a race!"); palsLoad()
    case "live": if let room = m["room"] as? String, room.range(of: "^[A-Z0-9]{4,8}$", options: .regularExpression) != nil { UIBridge.shared.showInvite(fid, n, f["av"] as? String, f["bg"] as? String, room) }
    case "no": toast(n + " can't play right now"); if let L = liveRoom, L.code == (m["room"] as? String), L.opp == nil { leaveLive() }
    default: break
    }
}
func recordMatch(_ kind: String, _ ref: String, _ other: String, _ mine: Int, _ theirs: Int, _ mode: String) {
    guard accSignedIn(), other != ACCT.uid, let me = ACCT.uid else { return }
    sb("matches?on_conflict=a,ref", method: "POST", body: ["kind": kind, "ref": String(ref.prefix(40)), "a": me, "b": other, "a_score": max(0, min(1500, mine)), "b_score": max(0, min(1500, theirs)), "mode": String(mode.prefix(20))],
       headers: ["Prefer": "resolution=ignore-duplicates,return=minimal"])
}
func fetchMatches(_ id: String) async throws -> [[String: Any]] {
    let P = "id,username,avatar,avatar_bg"
    return try await sbAsync("matches?select=kind,a,b,a_score,b_score,mode,created_at,pa:profiles!matches_a_fkey(\(P)),pb:profiles!matches_b_fkey(\(P))&or=(a.eq.\(id),b.eq.\(id))&order=created_at.desc&limit=200") as? [[String: Any]] ?? []
}
let AV_BG: [(String, String)] = [("sky", "#4ec0ca"), ("night", "#26345e"), ("sunset", "#fc7858"), ("grass", "#7fcf5a"), ("gold", "#f5c542"), ("pink", "#f49ac2"), ("purple", "#9b6bd6"), ("mint", "#7fe0c0"), ("snow", "#eef2f6"), ("coal", "#4a4048")]
func avBg(_ k: String?) -> String { AV_BG.first { $0.0 == k }?.1 ?? "#4ec0ca" }
func agoText(_ t: String) -> String {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let d = f.date(from: t) ?? ISO8601DateFormatter().date(from: t) ?? Date()
    let s = max(0, Date().timeIntervalSince(d))
    return s < 90 ? "just now" : s < 3600 ? "\(Int(jsRound(s / 60)))m ago" : s < 86400 ? "\(Int(jsRound(s / 3600)))h ago" : "\(Int(jsRound(s / 86400)))d ago"
}

// ---------- the TV party (your phone as the Apple TV's controller) ----------
final class PartyState { var code: String? = nil, ch: RTChannel? = nil, id = "", st: [String: Any]? = nil, lastTv = Date.distantPast, hello: Timer? = nil, nick = "" }
let PARTY = PartyState()
func partyName() -> String { String((accSignedIn() ? myUsername() : (PARTY.nick.isEmpty ? "PLAYER" : PARTY.nick)).prefix(14)) }
func partyBird() -> String { skinExists(birdPick) ? birdPick : birdColor }
func partySend(_ e: String, _ p: [String: Any] = [:]) { var m = p; m["id"] = PARTY.id; PARTY.ch?.send(e, m) }
func partyHello() { partySend("p", ["name": partyName(), "bird": partyBird()]) }
func joinParty(_ raw: String) -> Bool {
    let code = raw.uppercased().filter { ($0 >= "A" && $0 <= "Z") || ($0 >= "0" && $0 <= "9") }
    if code.count < 4 || code.count > 12 { return false }
    leaveParty(quiet: true)
    if PK.open { closePicker() }
    PARTY.code = code; PARTY.id = "ph" + rid(10); PARTY.st = nil; PARTY.lastTv = .distantPast
    let ch = RTChannel("fb-party-" + code)
    ch.on("st") { p in PARTY.st = p; PARTY.lastTv = Date(); UIBridge.shared.refresh() }
    ch.onStatus = { s in if s == "SUBSCRIBED" { partyHello(); UIBridge.shared.refresh() } }
    ch.subscribe()
    PARTY.ch = ch
    PARTY.hello = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in partyHello(); UIBridge.shared.refresh() }
    UIApplication.shared.isIdleTimerDisabled = true
    UIBridge.shared.partyOpen = true
    return true
}
func leaveParty(quiet: Bool = false) {
    if let ch = PARTY.ch {
        partySend("bye")
        PARTY.ch = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { ch.unsubscribe() }
        PARTY.hello?.invalidate()
        PARTY.code = nil; PARTY.st = nil
        if !quiet { playSound("swoosh") }
    }
    UIApplication.shared.isIdleTimerDisabled = false
    UIBridge.shared.partyOpen = false
}
func partyMe() -> [String: Any]? { (PARTY.st?["pl"] as? [[String: Any]])?.first { ($0["id"] as? String) == PARTY.id } }

// ---------- v139: saved progress ----------
let SAVE_SCALARS: [String] = ["birdPick", "trail", "gameMode", "weather", "season", "playSounds", "ghostOn", "adaptiveBackground", "appHaptics", "dailyStreak", "dailyLast"].map { "fb_" + $0 }
let SAVE_UNION = ["fb_favBirds", "fb_inboxSeen"], SAVE_BYID = ["fb_customBirds", "fb_friends"]
func LIVE_KEYS(_ k: String) -> Bool { k.hasPrefix("fb_bestScore") || k.range(of: "^fb_ghost(Hard|_[a-z]+)?$", options: .regularExpression) != nil || k == "fb_inboxSeen" }
func saveKind(_ k: String) -> String? {
    if k.range(of: "_daily$", options: .regularExpression) != nil { return nil }
    if k.range(of: "^fb_bestScore(Hard|_[a-z]+)?$", options: .regularExpression) != nil { return "max" }
    if k.range(of: "^fb_ghost(Hard|_[a-z]+)?$", options: .regularExpression) != nil { return "ghost" }
    if SAVE_UNION.contains(k) { return "union" }
    if SAVE_BYID.contains(k) { return "byid" }
    if SAVE_SCALARS.contains(k) { return "scalar" }
    return nil
}
final class SVState { var applying = false, timer: Timer? = nil, busy = false, uid: String? = nil, lastSent = "" }
let SV = SVState()
func localSave() -> [String: String] {
    var keys: [String: String] = [:]
    for i in 0..<localStorage.length { guard let k = localStorage.key(i), let kind = saveKind(k), let v = localStorage.getItem(k) else { continue }; if kind == "ghost" && !v.hasPrefix("{") { continue }; keys[k] = v }
    return keys
}
func saveAt() -> Double { Double(localStorage.getItem("fb_saveAt") ?? "0") ?? 0 }
func installSaveHook() {
    localStorage.onChange = { k, before, after in
        if SV.applying || saveKind(k) == nil || before == after { return }
        if before == nil && saveKind(k) == "scalar" { return }
        localStorage.setQuiet("fb_saveAt", String(Int(Date().timeIntervalSince1970 * 1000)))
        saveSoon()
    }
}
func saveSoon(_ s: Double = 5) { SV.timer?.invalidate(); SV.timer = Timer.scheduledTimer(withTimeInterval: s, repeats: false) { _ in savePush() } }
func mergeKey(_ kind: String?, _ mine: String?, _ theirs: String?, _ newer: Bool) -> String? {
    guard let m = mine else { return theirs }; guard let t = theirs else { return m }
    func arr(_ s: String) -> [Any]? { (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [Any] }
    switch kind {
    case "max": return String(max(Int(m) ?? 0, Int(t) ?? 0))
    case "ghost":
        guard let a = jsonObj(m), let b = jsonObj(t) else { return newer ? t : m }
        let sa = num(a["score"]) ?? 0, sbv = num(b["score"]) ?? 0
        return (sbv > sa || (sbv == sa && newer)) ? t : m
    case "union":
        guard let a = arr(m), let b = arr(t) else { return newer ? t : m }
        var seen = Set<String>(), out: [Any] = []
        for x in (newer ? b + a : a + b) { let k = "\(x)"; if !seen.contains(k) { seen.insert(k); out.append(x) } }
        return jsonStr(out)
    case "byid":
        guard let a = arr(m), let b = arr(t) else { return newer ? t : m }
        var seen = Set<String>(), out: [Any] = []
        for x in (newer ? b + a : a + b) { guard let id = (x as? [String: Any])?["id"] as? String, !seen.contains(id) else { continue }; seen.insert(id); out.append(x) }
        return jsonStr(out)
    default: return newer ? t : m
    }
}
func saveSync() {
    guard accSignedIn(), !SV.busy, let uid = ACCT.uid else { return }
    SV.busy = true
    Task { @MainActor in
        defer { SV.busy = false }
        guard let rows = try? await sbAsync("saves?select=data,saved_at&user_id=eq.\(uid)") as? [[String: Any]], accSignedIn(), ACCT.uid == uid else { return }
        let remote = ((rows.first?["data"] as? [String: Any])?["keys"] as? [String: String]), rAt = num(rows.first?["saved_at"]) ?? 0
        let local = localSave(), lAt = saveAt(), last = localStorage.getItem("fb_saveUid"), same = last == nil || last == uid
        var merged = local
        if !same {
            merged = remote ?? [:]
            for (k, v) in local where merged[k] == nil && saveKind(k) == "scalar" { merged[k] = v }
        } else if let r = remote {
            merged = [:]
            let newer = rAt > lAt
            for k in Set(local.keys).union(r.keys) { merged[k] = mergeKey(saveKind(k), local[k], r[k], newer) }
        }
        var needReload = false, changed = 0
        SV.applying = true
        if !same { for k in local.keys where merged[k] == nil { localStorage.removeItem(k); changed += 1; if !LIVE_KEYS(k) { needReload = true } } }
        for (k, v) in merged where local[k] != v { localStorage.setItem(k, v); changed += 1; if !LIVE_KEYS(k) { needReload = true } }
        localStorage.setItem("fb_saveUid", uid)
        if remote != nil && rAt > lAt { localStorage.setItem("fb_saveAt", String(Int(rAt))) }
        SV.applying = false
        SV.uid = uid
        ghostCache = [:]
        if remote == nil || remote! != merged { await savePushAsync(force: true) }
        if changed > 0 && needReload { saveReload() } else if changed > 0 { toast("Your progress was loaded") }
    }
}
func savePush() { Task { @MainActor in await savePushAsync(force: false) } }
@MainActor func savePushAsync(force: Bool) async {
    SV.timer?.invalidate()
    guard accSignedIn(), let uid = ACCT.uid, localStorage.getItem("fb_saveUid") == uid, force || SV.uid == uid else { return }
    let at = saveAt()
    let body: [String: Any] = ["user_id": uid, "data": ["v": 1, "keys": localSave()], "saved_at": at > 0 ? at : Date().timeIntervalSince1970 * 1000]
    let s = jsonStr(body)
    if !force && s == SV.lastSent { return }
    if s.count > 1_900_000 { return }
    do { _ = try await sbAsync("saves?on_conflict=user_id", method: "POST", body: s, headers: ["Prefer": "resolution=merge-duplicates,return=minimal"]); SV.lastSent = s }
    catch { saveSoon(30) }
}
/// the birds / settings changed: start the game again with them (the website reloads the page)
func saveReload() {
    toast("Loading your progress...")
    func go() { reloadEverything(); DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { toast("Your progress is back!") } }
    if PK.open && ["account", "profile"].contains(PK.kind) { DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { go() }; return }
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in if !bird.dynamic && !isShowingGameOver && !isGameOver && !PK.open { t.invalidate(); go() } }
}
func reloadEverything() {
    loadSettings(); prepareSkins(); loadFriends(); lbLoad(); loadAccStats()
    inboxSeen = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_inboxSeen") ?? "[]").utf8))) as? [String] ?? []
    ghostCache = [:]
    if !bird.dynamic && !isGameOver { updateBirdTextures(); updateSky() }
    UIBridge.shared.refresh()
}

// ---------- v143: approve an Apple TV sign-in ----------
var tvCode: String? = nil

// ---------- v147: watch uploads (others can watch your best runs) ----------
private var watchUpBusy = false
func watchUploadBests() {
    guard accSignedIn(), !watchUpBusy, let uid = ACCT.uid else { return }
    watchUpBusy = true
    Task { @MainActor in
        defer { watchUpBusy = false }
        var up = (jsonObj(localStorage.getItem("fb_watchUp")) ?? [:]).mapValues { num($0) ?? 0 }
        for m in LB_MODES {
            guard let raw = localStorage.getItem(ghostKey(m)), raw.hasPrefix("{"), let enc = jsonObj(raw), num(enc["v"]) == 1, let sc = num(enc["score"]), sc > 0 else { continue }
            let key = m == "daily" ? dailyKey() : m, tag = uid + ":" + key
            if (up[tag] ?? 0) >= sc { continue }
            do { _ = try await uploadRun(enc, key, ["round": 1]); up[tag] = sc; localStorage.setItem("fb_watchUp", jsonStr(up)) } catch { break }
        }
    }
}

// ---------- v141: a new version is out ----------
func checkUpdate() {
    Task { @MainActor in
        guard let (code, obj) = try? await http(SITE + "version.json?t=\(Int(Date().timeIntervalSince1970))"), code == 200, let v = obj as? [String: Any] else { return }
        let mine = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        if let ios = num(v["ios"]), Int(ios) > mine { UIBridge.shared.showUpdate(v["version"] as? String ?? "", v["iosNote"] as? String ?? "A new iPhone app is ready. Install the new IPA to get it. Your progress stays.") }
    }
}

// ---------- toast ----------
func toast(_ t: String) { UIBridge.shared.toast(t) }

func startOnline() {
    lbLoad(); loadFriends(); loadAccStats(); installSaveHook()
    inboxSeen = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_inboxSeen") ?? "[]").utf8))) as? [String] ?? []
    if let o = jsonObj(localStorage.getItem("fb_links")) { for (k, v) in o { if let s = v as? String { linkCache[k] = s } } }
    accInit()
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in if accCounting() && bird.dynamic && !isGameOver && !isShowingGameOver && appActive { ACC_ST.s += 1 } }
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { lbFlush() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 6) { watchUploadBests() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { checkUpdate() }
    Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { _ in checkUpdate() }
    NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in if accSignedIn() { savePush() } }
}
