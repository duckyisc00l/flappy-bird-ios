import AuthenticationServices
import SwiftUI

/// the "signed in as ..." / "Sign in" bar at the top of every online page
struct AccBar: View {
    @ObservedObject var ui = UIBridge.shared
    var body: some View {
        _ = ui.tick
        let nw = palsBadge()
        return Button {
            playSound("swoosh")
            if accSignedIn() { accGo("profile", ACCT.uid) } else { accGo("account") }
        } label: {
            HStack(spacing: 8) {
                if accSignedIn() { Avatar(av: ACCT.profile?["avatar"] as? String, bg: ACCT.profile?["avatar_bg"] as? String, w: 38, h: 32, border: 2) }
                VStack(alignment: .leading, spacing: 3) {
                    KT(accSignedIn() ? myUsername() : (ACCT.needCode ? "Finish signing in" : "Sign in"), 12, accSignedIn() ? K.brown : .white, shadow: accSignedIn() ? nil : Color(hex: 0xc8482c), lines: 1)
                    KT(accSignedIn() ? (nw > 0 ? "Your profile and friends - \(nw) new" : "Your profile and friends") : (ACCT.needCode ? "Enter your 2FA code" : "or create an account to get on the board"), 6, accSignedIn() ? K.brown : .white).opacity(0.8)
                }.padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
                Arrow()
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 10).fill(accSignedIn() ? K.cream : K.orange); (accSignedIn() ? Color(hex: 0xe4dc9c) : Color(hex: 0xd85a3c)).frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 10)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(K.brown, lineWidth: 2))
            .overlay(alignment: .topTrailing) { if nw > 0 { Dot(n: nw).offset(x: 4, y: -6) } }
        }.buttonStyle(.plain).padding(.bottom, 8)
    }
}
struct Dot: View { let n: Int
    var body: some View { Text("\(n)").font(K.kong(9)).foregroundColor(.white).padding(.horizontal, 3).frame(minWidth: 18, minHeight: 18).background(Capsule().fill(K.red)).overlay(Capsule().stroke(K.cream, lineWidth: 2)) } }
/// a button that shows "..." while working and puts errors into msg (accWork)
struct WorkBtn: View {
    let t: String; var busy: String = "..."; var style: MkStyle = .save; var size: CGFloat = 9; var pad: CGFloat = 11; @Binding var msg: String; @Binding var ok: Bool
    let fn: () async throws -> Void
    @State var working = false
    var body: some View {
        MkBtn(working ? busy : t, style, size: size, pad: pad, disabled: working) {
            working = true; msg = ""; ok = false
            Task { @MainActor in
                do { try await fn() } catch { msg = accErr(error); playSound("hit") }
                working = false
            }
        }.padding(.bottom, 6)
    }
}

// MARK: - Race a Friend (from the score card)

struct FriendsPage: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var pasted = ""
    @State private var msg = ""
    @State private var link = "Making your link..."
    @State private var linkErr = false
    @State private var copied = false
    @State private var room = ""
    @State private var liveMsg = ""
    var body: some View {
        _ = ui.tick
        let mi = modeInfo(), best = ghostScore(gameMode)
        return Scroll {
            AccBar()
            Sec(t: "Share your best run (\(mi.title))", top: 6)
            if best > 0 {
                Note(t: "Your best \(mi.title) run: \(best). Send this link to a friend. They tap it and race your ghost on the same pipes.")
                Text(link).font(K.kong(8)).foregroundColor(K.brown).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 7).padding(.horizontal, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(K.input)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2)).padding(.bottom, 5)
                MkBtn(linkErr ? "Try again" : copied ? "Link copied!" : "Share link", .save) {
                    if link.hasPrefix("http") { playSound("swoosh"); share(["Race my Flappy Bird ghost! I got \(best) in \(mi.title). Tap to race me:\n" + link]) } else { makeLink() }
                }
            } else { Note(t: "Play a round in \(mi.title) first (with no autoplay). Your best run becomes your ghost.") }
            Sec(t: "Add a friend's run", top: 6)
            CodeBox(text: $pasted, ph: "Paste a race link (or a code)", lines: 3)
            Msg(t: msg)
            MkBtn("Add friend", .save) { addFriend() }
            if !friendList.isEmpty {
                Sec(t: "Friends", top: 6)
                VStack(spacing: 5) {
                    ForEach(friendList, id: \.id) { f in
                        HStack(spacing: 8) {
                            PixImage(img: skinCanvas(skinExists(f.skin) ? f.skin : "yellow", 2), w: 36, h: 30, bg: K.sky, radius: 4)
                            VStack(alignment: .leading, spacing: 3) { KT(f.name, 8, K.orange, lines: 1); KT(modeInfo(f.m).title + " - \(f.score)" + (f.duel != nil ? " - duel round \(f.round ?? 1)" : ""), 6) }.frame(maxWidth: .infinity, alignment: .leading)
                            Button { setRace(f.id == raceId ? nil : f.id); playSound("swoosh"); haptic(); showPage("friends") } label: {
                                KT(f.id == raceId ? "Racing" : "Race", 7, f.id == raceId ? .white : K.brown).padding(.vertical, 6).padding(.horizontal, 8).background(RoundedRectangle(cornerRadius: 9).fill(f.id == raceId ? Color(hex: 0x78d850) : K.light)).overlay(RoundedRectangle(cornerRadius: 9).stroke(K.brown, lineWidth: 2))
                            }.buttonStyle(.plain)
                            Button { friendList.removeAll { $0.id == f.id }; if raceId == f.id { setRace(nil) }; saveFriends(); playSound("swoosh"); showPage("friends") } label: {
                                Text("\u{2715}").font(.system(size: 11)).foregroundColor(K.brown).frame(width: 24, height: 24).background(RoundedRectangle(cornerRadius: 6).fill(.white)).overlay(RoundedRectangle(cornerRadius: 6).stroke(K.brown, lineWidth: 2))
                            }.buttonStyle(.plain)
                        }.padding(.vertical, 4).padding(.horizontal, 6).tile(f.id == raceId, radius: 8)
                    }
                }
                Note(t: raceId.isEmpty ? "Tap Race to race a friend. The game switches to their mode." : "You race the friend marked Racing every round (in their mode). Tap Racing to stop.").padding(.top, 5)
            }
            Sec(t: "Live duel", top: 6)
            if let L = liveRoom {
                Note(t: liveStatusText())
                MkBtn("Invite with a link", .save) { share(["Live duel me in Flappy Bird! Room \(L.code):\n" + SITE + "#live=" + L.code]) }.padding(.bottom, 5)
                MkBtn("Leave the duel") { leaveLive(); showPage("friends") }
            } else {
                Note(t: "Fly at the same time as a friend on the same pipes. Make a room and send the link, or type their room code.")
                MkBtn("Make a room", .save) {
                    if onlineName().isEmpty { liveMsg = "Sign in first (button at the top)"; return }
                    playSound("swoosh"); joinLive(rid(5).uppercased().map { ($0.isLetter || $0.isNumber) ? String($0) : "X" }.joined(), host: true); showPage("friends")
                }
                HStack(spacing: 5) {
                    Field(ph: "Room code", text: $room, size: 16, caps: true).padding(.bottom, -6)
                    MkBtn("Join") {
                        let c = room.trimmingCharacters(in: .whitespaces).uppercased()
                        if c.range(of: "^[A-Z0-9]{4,8}$", options: .regularExpression) == nil { room = ""; return }
                        if onlineName().isEmpty { liveMsg = "Sign in first (button at the top)"; return }
                        joinLive(c); showPage("friends")
                    }.frame(width: 70)
                }.padding(.top, 5)
                Msg(t: liveMsg)
            }
        }
        .onAppear { makeLink() }
    }
    private func makeLink() {
        if ghostScore(gameMode) <= 0 { return }
        link = "Making your link..."; linkErr = false
        Task { @MainActor in
            if onlineName().isEmpty { link = "Sign in first (button above), then tap Try again"; linkErr = true; return }
            do { link = try await myBestLink(gameMode) ?? "Couldn't make a link" } catch { link = accErr(error); linkErr = true }
        }
    }
    private func addFriend() {
        let t = pasted
        if let r = t.range(of: "#r=([A-Za-z0-9]{8,12})", options: .regularExpression) ?? t.range(of: "^\\s*[A-Za-z0-9]{10}\\s*$", options: .regularExpression) {
            let id = String(t[r]).replacingOccurrences(of: "#r=", with: "").trimmingCharacters(in: .whitespaces)
            msg = "Getting the race..."
            Task { @MainActor in
                do { try addFriendFromRun(try await fetchRun(id)); playSound("point"); showPage("friends") } catch { msg = accErr(error); playSound("hit") }
            }
            return
        }
        do {
            let o = try fgUnpack(t)
            guard let gEnc = o["g"] as? [String: Any], let g = fgDecode(gEnc) else { return }
            let id = "f" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), name = String((o["name"] as? String ?? "Friend").prefix(14)), m = o["m"] as? String ?? "normal"
            friendList.removeAll { $0.name == name && $0.m == m && num($0.g["seed"]) == num(gEnc["seed"]) }
            friendList.insert(Friend(id: id, name: name, m: m, g: gEnc, score: g.score, skin: g.skin, when: Date().timeIntervalSince1970 * 1000), at: 0)
            if friendList.count > 20 { friendList = Array(friendList.prefix(20)) }
            saveFriends(); setRace(id); playSound("point"); haptic(); showPage("friends")
        } catch { msg = accErr(error); playSound("hit") }
    }
}

// MARK: - Leaderboard

struct LeadersPage: View {
    @State private var rows: [[String: Any]]? = nil
    @State private var err: String? = nil
    var body: some View {
        VStack(spacing: 0) {
            AccBar()
            Flow(spacing: 4, center: true) {
                ForEach(LB_MODES, id: \.self) { m in
                    Button { lbMode = m; playSound("swoosh"); showPage("leaders") } label: {
                        KT(modeInfo(m).title, 7, m == lbMode ? .white : K.brown).padding(.vertical, 6).padding(.horizontal, 8).background(Capsule().fill(m == lbMode ? K.orange : K.light)).overlay(Capsule().stroke(K.brown, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }.padding(.bottom, 6)
            HStack(spacing: 5) { ForEach([(false, "All time"), (true, "This week")], id: \.0) { w, t in Opt(t: t, on: lbWeek == w, grow: true) { lbWeek = w; showPage("leaders") } } }.padding(.bottom, 6)
            FitScroll {
                VStack(spacing: 3) {
                    if let e = err { Note(t: e) }
                    else if let rs = rows {
                        if rs.isEmpty { Note(t: "No scores yet. Be the first!") }
                        ForEach(Array(rs.prefix(50).enumerated()), id: \.offset) { i, r in lbRow(i, r) }
                    } else { Note(t: "Loading...") }
                }.padding(2)
            }
            KT(meText, 7, align: .center).frame(maxWidth: .infinity).padding(.top, 6).padding(.horizontal, 2)
        }
        .task {
            await lbFlushAsync()
            do { rows = try await lbFetch(lbMode, lbWeek) } catch { err = accErr(error) }
        }
    }
    private var meText: String {
        if onlineName().isEmpty { return "Sign in to put your best scores on the board." }
        guard let rs = rows else { return "" }
        if let i = rs.firstIndex(where: { ($0["user_id"] as? String) == ACCT.uid }) { return "You are #\(i + 1) with \(Int(num(rs[i]["score"]) ?? 0))" }
        return "Play a \(modeInfo(lbMode).title) round to get on the board."
    }
    private func lbRow(_ i: Int, _ r: [String: Any]) -> some View {
        let me = accSignedIn() && (r["user_id"] as? String) == ACCT.uid
        let p = r["profiles"] as? [String: Any]
        let bg: Color = me ? K.cream : i == 0 ? Color(hex: 0xfff0a0) : i == 1 ? Color(hex: 0xeef0f4) : i == 2 ? Color(hex: 0xf4dcc0) : K.light
        let uid = r["user_id"] as? String ?? "", name = r["name"] as? String ?? ""
        return Button { playSound("swoosh"); accGo("profile", uid) } label: {
            HStack(spacing: 6) {
                KT(i < 3 ? ["1ST", "2ND", "3RD"][i] : "\(i + 1)", 7, K.orange, align: .center).frame(width: 26)
                Avatar(av: p?["avatar"] as? String ?? r["bird"] as? String, bg: p?["avatar_bg"] as? String ?? "sky")
                KT(name, 7, lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                Text("\(Int(num(r["score"]) ?? 0))").font(K.kong(11)).foregroundColor(K.brown).padding(.trailing, 2)
                Button { watchBest(uid, lbMode, name) } label: { Text("\u{25B6}").font(.system(size: 9)).foregroundColor(.white).padding(.leading, 2).frame(width: 22, height: 22).background(Circle().fill(K.brown)) }.buttonStyle(.plain).padding(.leading, 8)
            }
            .padding(.vertical, 2).padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(bg)).overlay(RoundedRectangle(cornerRadius: 7).stroke(me ? K.orange : K.line, lineWidth: 2))
        }.buttonStyle(.plain)
    }
}

// MARK: - Challenge (a race link) and Live (a room link)

struct ChallengePage: View {
    @State private var hist: [[String: Any]] = []
    var body: some View {
        if let r = challengeRow {
            let round = Int(num(r["round"]) ?? 1), name = r["name"] as? String ?? "Friend", sc = Int(num(r["score"]) ?? 0)
            Scroll {
                PixImage(img: skinCanvas(skinExists(r["bird"] as? String ?? "") ? r["bird"] as! String : "yellow", 2), w: 72, h: 60, bg: K.sky, radius: 8, border: K.brown).padding(.vertical, 4)
                ChT(t: name + (round > 1 ? " replied!" : " challenged you!"))
                ChS(t: modeInfo(r["mode"] as? String ?? "normal").title + " - score \(sc)" + (round > 1 ? " - round \(round)" : ""))
                if hist.count >= 2 {
                    Sec(t: "The duel so far")
                    ForEach(Array(hist.enumerated()), id: \.offset) { i, q in
                        let prev = i > 0 ? Int(num(hist[i - 1]["score"]) ?? 0) : nil, s = Int(num(q["score"]) ?? 0)
                        let w = prev == nil ? "" : (s > prev! ? " (won)" : s == prev! ? " (tie)" : " (lost)")
                        KT("Round \(Int(num(q["round"]) ?? 1)): \(q["name"] as? String ?? "") \(s)" + w, 7).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 2).padding(.horizontal, 4)
                    }
                }
                Note(t: "You fly the exact same pipes as \(name). Beat \(sc), then send your reply from the Score Card.")
                AccBar()
                MkBtn("Race!", .save) { playSound("swoosh"); closePicker(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if !bird.dynamic && !isWaitingToStart && playButton.added { handlePlayTap() } } }
            }
            .task { if let d = r["duel"] as? String { hist = (try? await fetchDuel(d)) ?? [] } }
        }
    }
}
struct LivePage: View {
    @ObservedObject var ui = UIBridge.shared
    var body: some View {
        _ = ui.tick
        return Scroll {
            AccBar()
            ChT(t: "Live duel")
            Note(t: liveStatusText())
            if liveRoom?.opp != nil { MkBtn("Ready - tap Play", .save) { closePicker() } }
        }
    }
}

// MARK: - accounts

final class AppLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AppLogin()
    var session: ASWebAuthenticationSession?
    func presentationAnchor(for s: ASWebAuthenticationSession) -> ASPresentationAnchor { UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor() }
    /// sign in through a Safari sheet (so the Passwords app can fill and save the password); the website hands back a login
    func start() {
        guard let u = URL(string: SITE + "#applogin") else { return }
        let s = ASWebAuthenticationSession(url: u, callbackURLScheme: "flappybird-auth") { url, _ in
            guard let url = url, let frag = url.fragment else { return }
            var a: String?, r: String?
            for part in frag.split(separator: "&") { let kv = part.split(separator: "=", maxSplits: 1); if kv.count == 2 { if kv[0] == "a" { a = String(kv[1]).removingPercentEncoding }; if kv[0] == "r" { r = String(kv[1]).removingPercentEncoding } } }
            guard let at = a, let rt = r else { return }
            Task { @MainActor in
                let exp = num(jwt(at)["exp"]) ?? (Date().timeIntervalSince1970 + 3600)
                Auth.shared.take(["access_token": at, "refresh_token": rt, "expires_at": exp, "user": jwt(at)], "SIGNED_IN")
                _ = try? await Auth.shared.getUser()
                await accSession("SIGNED_IN", Auth.shared.session)
                playSound("point")
                if ACCT.needCode { showPage("account") } else if accSignedIn() { accGo("profile", ACCT.uid, replace: true) }
            }
        }
        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = false
        session = s
        s.start()
    }
}
var accTab = "in"
struct AccountPage: View {
    @State private var user = ""
    @State private var pass = ""
    @State private var email = ""
    @State private var code = ""
    @State private var msg = ""
    @State private var ok = false
    var body: some View {
        Scroll {
            if ACCT.needCode {
                ChS(t: "Open your authenticator app and type the 6-digit code for Flappy Bird.")
                Field(ph: "123456", text: $code, size: 20, center: true, kerning: 6, numeric: true, content: .oneTimeCode)
                Msg(t: msg, ok: ok)
                WorkBtn(t: "Verify", busy: "Checking...", msg: $msg, ok: $ok) {
                    let v = code.filter { $0.isNumber }; if v.count != 6 { throw NetError(message: "Type all 6 numbers") }
                    let f = try await Auth.shared.factors(); guard let fid = f.totp.first?["id"] as? String else { throw NetError(message: "No 2FA found on this account") }
                    try await Auth.shared.challengeAndVerify(fid, v)
                    ACCT.needCode = false; playSound("point"); await accSession("MFA_CHALLENGE_VERIFIED", Auth.shared.session)
                    if ACCT.recovering { accGo("newpass", replace: true) } else { accGo("profile", ACCT.uid, replace: true) }
                }
                MkBtn("Cancel", .link, size: 9, pad: 11) { playSound("swoosh"); Task { @MainActor in await accSignOut(); showPage("account") } }.padding(.bottom, 6)
            } else {
                HStack(spacing: 5) {
                    Opt(t: "Sign in", on: accTab != "new", grow: true) { accTab = "in"; playSound("swoosh"); showPage("account") }
                    Opt(t: "Create account", on: accTab == "new", grow: true) { accTab = "new"; playSound("swoosh"); showPage("account") }
                }.padding(.bottom, 10)
                if accTab != "forgot" {
                    MkBtn("Sign in with Safari", .safari, size: 9, pad: 11) { playSound("swoosh"); AppLogin.shared.start() }.padding(.top, 4).padding(.bottom, 6)
                    Note(t: "Safari fills in and saves your password. Or type it here:", center: true).padding(.top, 4)
                }
                if accTab == "forgot" {
                    ChS(t: "Type the email on your account. We'll send you a link to pick a new password.")
                    Field(ph: "Email", text: $email, content: .emailAddress)
                    Msg(t: msg, ok: ok)
                    WorkBtn(t: "Send the link", busy: "Sending...", msg: $msg, ok: $ok) {
                        let e = email.trimmingCharacters(in: .whitespaces); if e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) == nil { throw NetError(message: "That email doesn't look right") }
                        try await Auth.shared.recover(email: e); ok = true; msg = "Sent! Open the link in the email to pick a new password."
                    }
                    MkBtn("Back to sign in", .link, size: 9, pad: 11) { accTab = "in"; playSound("swoosh"); showPage("account") }.padding(.bottom, 6)
                    Note(t: "No email on your account? Then the password can\u{2019}t be reset, so you\u{2019}d need a new account.")
                } else if accTab == "in" {
                    Field(ph: "Username or email", text: $user, content: .username)
                    Field(ph: "Password", text: $pass, secure: true, content: .password)
                    Msg(t: msg, ok: ok)
                    WorkBtn(t: "Sign in", busy: "Signing in...", msg: $msg, ok: $ok) {
                        let u = user.trimmingCharacters(in: .whitespaces); if u.isEmpty || pass.isEmpty { throw NetError(message: "Type your username and password") }
                        var em = u
                        if !u.contains("@") {
                            if u.range(of: "^[A-Za-z0-9_]{3,14}$", options: .regularExpression) == nil { throw NetError(message: "Usernames are 3-14 letters, numbers or _") }
                            let rows = try await sbAsync("profiles?select=email_login&handle=eq." + u.lowercased()) as? [[String: Any]] ?? []
                            guard let r = rows.first else { throw NetError(message: "No player called " + u) }
                            if r["email_login"] as? Bool == true { throw NetError(message: "This account signs in with its email. Type your email instead") }
                            em = u.lowercased() + ACC_MAIL
                        }
                        _ = try await Auth.shared.signIn(email: em, password: pass)
                        await accSession("SIGNED_IN", Auth.shared.session)
                        playSound("point")
                        if ACCT.needCode { showPage("account") } else { accGo("profile", ACCT.uid, replace: true) }
                    }
                    MkBtn("Forgot password?", .link, size: 9, pad: 11) { accTab = "forgot"; playSound("swoosh"); showPage("account") }.padding(.bottom, 6)
                } else {
                    Field(ph: "Username", text: Binding(get: { user }, set: { user = String($0.filter { $0.isLetter && $0.isASCII || $0.isNumber || $0 == "_" }.prefix(14)) }), content: .username)
                    Field(ph: "Password (8+ letters)", text: $pass, secure: true, content: .newPassword)
                    Field(ph: "Email (optional)", text: $email, content: .emailAddress)
                    Note(t: "Your username shows on the leaderboard. The email is optional: with one you can reset a forgotten password.")
                    Msg(t: msg, ok: ok)
                    WorkBtn(t: "Create account", busy: "Creating...", msg: $msg, ok: $ok) {
                        let u = user.trimmingCharacters(in: .whitespaces), e = email.trimmingCharacters(in: .whitespaces)
                        if u.range(of: "^[A-Za-z0-9_]{3,14}$", options: .regularExpression) == nil { throw NetError(message: "Usernames are 3-14 letters, numbers or _") }
                        if pass.count < 8 { throw NetError(message: "Pick a longer password (8+ letters)") }
                        if !e.isEmpty && e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) == nil { throw NetError(message: "That email doesn't look right") }
                        let taken = try await sbAsync("profiles?select=id&handle=eq." + u.lowercased()) as? [[String: Any]] ?? []
                        if !taken.isEmpty { throw NetError(message: "That username is taken") }
                        let s = try await Auth.shared.signUp(email: e.isEmpty ? u.lowercased() + ACC_MAIL : e, password: pass, data: ["username": u, "email_login": !e.isEmpty])
                        if s == nil { ok = true; msg = "Almost done! Open the link we emailed you, then sign in."; accTab = "in"; return }
                        await accSession("SIGNED_IN", Auth.shared.session)
                        playSound("point"); haptic()
                        accGo("profile", ACCT.uid, replace: true)
                    }
                }
            }
        }
    }
}
func accTime(_ s0: Int) -> String { let s = s0, h = s / 3600, m = (s / 60) % 60; return h > 0 ? "\(h)h \(m)m" : m > 0 ? "\(m)m" : "\(s)s" }
func accNum(_ n0: Double) -> String { let n = n0; return n >= 1e6 ? String(format: "%.1fM", n / 1e6) : n >= 1e4 ? "\(Int(jsRound(n / 1e3)))K" : "\(Int(n))" }

struct ProfilePage: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var p: [String: Any]? = nil
    @State private var bests: [String: Int] = [:]
    @State private var matches: [[String: Any]]? = nil
    @State private var err: String? = nil
    @State private var msg = ""
    @State private var ok = false
    @State private var rmArmed = false
    @State private var delArmed = false
    @State private var delText: String? = nil
    var body: some View {
        _ = ui.tick
        let id = accProfileId ?? ACCT.uid ?? ""
        let mine = ACCT.uid == id
        let prof = p ?? (mine ? ACCT.profile : nil)
        return Scroll {
            VStack(spacing: 0) {
                let skin = skinExists(prof?["avatar"] as? String ?? "") ? prof!["avatar"] as! String : skinExists(prof?["bird"] as? String ?? "") ? prof!["bird"] as! String : "yellow"
                BirdView(id: skin, w: 96, h: 80, bg: Color(css: avBg(prof?["avatar_bg"] as? String)), radius: 8, border: K.brown).padding(.vertical, 4)
                ChT(t: err ?? (prof?["username"] as? String ?? "..."), size: 22).padding(.vertical, -2)
                if let c = prof?["created_at"] as? String { ChS(t: "Playing since " + since(c)) }
                if mine { Button { playSound("swoosh"); accGo("avatar") } label: { KT("Change picture", 7).underline().padding(.horizontal, 6).padding(.top, 2).padding(.bottom, 6) }.buttonStyle(.plain) }
            }
            if let pp = prof, !mine, accSignedIn() { social(pp) }
            if let pp = prof {
                HStack(spacing: 4) {
                    ForEach([("Games", accNum(num(pp["games"]) ?? 0)), ("Pipes", accNum(num(pp["pipes"]) ?? 0)), ("Flaps", accNum(num(pp["flaps"]) ?? 0)), ("Time", accTime(Int(num(pp["seconds"]) ?? 0)))], id: \.0) { k, v in
                        VStack(spacing: 4) { Text(v).font(K.kong(12)).foregroundColor(K.brown); KT(k, 6, K.orange) }.frame(maxWidth: .infinity).padding(.vertical, 6).tile(false, radius: 8)
                    }
                }.padding(.vertical, 4)
            }
            Sec(t: "Best scores")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)], spacing: 3) {
                ForEach(LB_MODES, id: \.self) { m in
                    let b = bests[m]
                    Button { if b != nil { watchBest(id, m, prof?["username"] as? String ?? "") } } label: {
                        HStack { KT(modeInfo(m).title, 6, lines: 1); Spacer(); Text(b.map { String($0) } ?? "-").font(K.kong(11)).foregroundColor(K.brown).opacity(b == nil ? 0.4 : 1); if b != nil { Text("\u{25B6}").font(.system(size: 10)).opacity(0.7).padding(.leading, 6) } }
                            .padding(.vertical, 5).padding(.horizontal, 7).tile(false)
                    }.buttonStyle(.plain).disabled(b == nil)
                }
            }
            if let t = prof?["trail"] as? String, t != "none", let td = trailDef(t) { ChS(t: "Trail: " + td.name).padding(.top, 6) }
            duelsView(id, prof?["username"] as? String ?? "")
            if mine { myButton; accountSettings }
        }
        .task {
            if mine, ACCT.profile != nil { bests = ACCT.bests }
            do {
                async let rows = sbAsync("profiles?select=*&id=eq.\(id)")
                async let b = accBests(id)
                let (r, bb) = try await (rows, b)
                let pr = (r as? [[String: Any]])?.first
                if mine, let pr = pr { ACCT.profile = pr; ACCT.bests = bb }
                p = pr; bests = bb
                if pr == nil { err = "Player not found" }
                matches = (try? await fetchMatches(id)) ?? []
                if FR.at == 0 { await palsLoadAsync() }
            } catch { if !(mine && ACCT.profile != nil) { err = accErr(error) } }
            if mine { accFlushStats() }
        }
    }
    private func since(_ s: String) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date()
        let o = DateFormatter(); o.dateFormat = "MMM d, yyyy"; return o.string(from: d)
    }
    @ViewBuilder private func social(_ pp: [String: Any]) -> some View {
        let pid = pp["id"] as? String ?? "", uname = pp["username"] as? String ?? ""
        let rel = palsRel(pid)
        VStack(spacing: 0) {
            if rel == "friend" {
                HStack(spacing: 8) { KT("Friends", 7, K.okGreen); OnlineDot(uid: pid) }.padding(.bottom, 6)
                HStack(spacing: 6) {
                    if isOnline(pid) {
                        WorkBtn(t: "Duel live", size: 8, pad: 10, msg: $msg, ok: $ok) {
                            let room = rid(5).uppercased().map { ($0.isLetter || $0.isNumber) ? String($0) : "X" }.joined()
                            joinLive(room, host: true); rtSend(pid, ["t": "live", "room": room])
                            toast("Invite sent to " + uname); accGo("friends")
                        }
                    }
                    WorkBtn(t: "Send a race", style: .purple, size: 8, pad: 10, msg: $msg, ok: $ok) {
                        let m = gameMode
                        guard let enc = jsonObj(localStorage.getItem(ghostKey(m))), num(enc["v"]) == 1 else { throw NetError(message: "Play a \(modeInfo(m).title) round first") }
                        _ = try await uploadRun(enc, m, ["to_user": pid]); rtSend(pid, ["t": "race"])
                        ok = true; msg = "Sent your best \(modeInfo(m).title) run (\(Int(num(enc["score"]) ?? 0))) to \(uname)!"; playSound("point")
                    }
                }
                Msg(t: msg, ok: ok)
                Button {
                    if !rmArmed { rmArmed = true; DispatchQueue.main.asyncAfter(deadline: .now() + 3) { rmArmed = false }; return }
                    Task { @MainActor in _ = try? await sbAsync("rpc/friend_remove", method: "POST", body: ["other": pid]); await palsLoadAsync() }
                } label: { KT(rmArmed ? "Tap again to remove" : "Remove friend", 7).underline().padding(.horizontal, 8).padding(.top, 2).padding(.bottom, 4) }.buttonStyle(.plain)
            } else {
                if rel == "incoming" { ChS(t: uname + " wants to be your friend") }
                if rel == "outgoing" { ChS(t: "Friend request sent. Waiting for " + uname) }
                HStack(spacing: 6) {
                    if rel == "incoming" {
                        WorkBtn(t: "Accept", size: 8, pad: 10, msg: $msg, ok: $ok) { _ = try await sbAsync("rpc/friend_add", method: "POST", body: ["name": uname]); rtSend(pid, ["t": "yes"]); playSound("point"); await palsLoadAsync() }
                        WorkBtn(t: "Decline", style: .plain, size: 8, pad: 10, msg: $msg, ok: $ok) { _ = try await sbAsync("rpc/friend_remove", method: "POST", body: ["other": pid]); await palsLoadAsync() }
                    } else if rel == "outgoing" {
                        WorkBtn(t: "Cancel request", style: .plain, size: 8, pad: 10, msg: $msg, ok: $ok) { _ = try await sbAsync("rpc/friend_remove", method: "POST", body: ["other": pid]); await palsLoadAsync() }
                    } else {
                        WorkBtn(t: "Add friend", size: 8, pad: 10, msg: $msg, ok: $ok) {
                            let r = try await sbAsync("rpc/friend_add", method: "POST", body: ["name": uname]) as? String
                            rtSend(pid, ["t": r == "friends" ? "yes" : "req"]); playSound("point"); await palsLoadAsync()
                        }
                    }
                }
                Msg(t: msg, ok: ok)
            }
        }.padding(.top, 2).padding(.bottom, 6)
    }
    @ViewBuilder private func duelsView(_ id: String, _ name: String) -> some View {
        if let rows = matches {
            Sec(t: "Duels", top: 6)
            let view = rows.compactMap { m -> (my: Int, their: Int, other: [String: Any], kind: String, mode: String, at: String)? in
                let me = (m["a"] as? String) == id
                guard let other = (me ? m["pb"] : m["pa"]) as? [String: Any] else { return nil }
                return (Int(num(me ? m["a_score"] : m["b_score"]) ?? 0), Int(num(me ? m["b_score"] : m["a_score"]) ?? 0), other, m["kind"] as? String ?? "", m["mode"] as? String ?? "normal", m["created_at"] as? String ?? "")
            }
            if view.isEmpty { Note(t: "No duels yet. Race a friend or duel them live!") }
            else {
                let w = view.filter { $0.my > $0.their }.count, l = view.filter { $0.my < $0.their }.count, t = view.count - w - l
                HStack(spacing: 4) {
                    ForEach([("Won", w, K.okGreen), ("Lost", l, K.red), ("Tied", t, Color(hex: 0x8a8270))], id: \.0) { k, v, c in
                        VStack(spacing: 3) { Text("\(v)").font(K.kong(13)).foregroundColor(c); KT(k, 6) }.frame(maxWidth: .infinity).padding(.vertical, 5).tile(false, radius: 8)
                    }
                }.padding(.bottom, 5)
                if let viewer = ACCT.uid, viewer != id {
                    let h = view.filter { pid($0.other) == viewer }
                    if !h.isEmpty {
                        HStack(spacing: 10) { KT("You", 7, .white); Text("\(h.filter { $0.their > $0.my }.count) - \(h.filter { $0.my > $0.their }.count)").font(K.kong(16)).foregroundColor(Color(hex: 0xf5c542)); KT(name, 7, .white) }
                            .frame(maxWidth: .infinity).padding(7).background(RoundedRectangle(cornerRadius: 9).fill(K.brown)).padding(.bottom, 5)
                    }
                }
                VStack(spacing: 3) {
                    ForEach(Array(view.prefix(12).enumerated()), id: \.offset) { _, v in
                        let res = v.my > v.their ? "Won" : v.my < v.their ? "Lost" : "Tied", col = v.my > v.their ? Color(hex: 0x4ccc3a) : v.my < v.their ? K.red : Color(hex: 0xb0a88a)
                        Button { playSound("swoosh"); accGo("profile", pid(v.other)) } label: {
                            HStack(spacing: 7) {
                                Avatar(av: v.other["avatar"] as? String, bg: v.other["avatar_bg"] as? String, w: 30, h: 25)
                                VStack(alignment: .leading, spacing: 2) { KT("\(res) vs \(v.other["username"] as? String ?? "")", 7, lines: 1); KT((v.kind == "live" ? "Live" : "Race") + " - " + modeInfo(v.mode).title + " - " + agoText(v.at), 6).opacity(0.7) }.frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(v.my) : \(v.their)").font(K.kong(10)).foregroundColor(K.brown)
                            }.padding(.vertical, 3).padding(.horizontal, 7)
                                .background(RoundedRectangle(cornerRadius: 7).fill(K.light)).overlay(RoundedRectangle(cornerRadius: 7).stroke(K.line, lineWidth: 2))
                                .overlay(alignment: .leading) { col.frame(width: 5).clipShape(RoundedRectangle(cornerRadius: 2)) }
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }
    private var myButton: some View {
        let nw = palsBadge(), on = FR.list.filter { $0.accepted && isOnline(pid($0.p)) }.count, all = FR.list.filter { $0.accepted }.count
        return Button { playSound("swoosh"); accGo("pals") } label: {
            VStack(spacing: 4) { KT("Friends", 10, .white); KT(all > 0 ? "\(all)" + (all == 1 ? " friend" : " friends") + (on > 0 ? " - \(on) online" : "") : "Add your friends by username", 6, .white).opacity(0.9) }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 9).fill(K.green); K.greenDark.frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 9)))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(K.brown, lineWidth: 2))
                .overlay(alignment: .topTrailing) { if nw > 0 { Dot(n: nw).offset(x: 4, y: -6) } }
        }.buttonStyle(PressStyle()).padding(.top, 10).padding(.bottom, 2)
    }
    private var accountSettings: some View {
        let u = Auth.shared.user ?? ACCT.user ?? [:]
        let em = u["email"] as? String ?? "", realEmail = em.hasSuffix(ACC_MAIL) ? "" : em
        let tfa = (u["factors"] as? [[String: Any]] ?? []).contains { ($0["status"] as? String) == "verified" }
        return VStack(spacing: 0) {
            Sec(t: "Your account", top: 6)
            VStack(spacing: 0) {
                arow("Two-factor (2FA)", tfa ? "On" : "Off") { accGo("twofa") }
                arow("Email", realEmail.isEmpty ? "Add" : "Change") { accGo("email") }
                arow("Password", "") { accGo("newpass") }
                arow("Sign out", "") { Task { @MainActor in await accSignOut(); accGo("account", replace: true) } }
                arow(delText ?? (delArmed ? "Tap again to delete for good" : "Delete account"), "", danger: true, last: true) {
                    if !delArmed { delArmed = true; DispatchQueue.main.asyncAfter(deadline: .now() + 4) { delArmed = false }; return }
                    delText = "Deleting..."
                    Task { @MainActor in
                        do { _ = try await sbAsync("rpc/delete_my_account", method: "POST", body: "{}"); await accSignOut(); lbQueue = []; lbSetSent([:]); toast("Your account was deleted"); accGo("account", replace: true) }
                        catch { delText = accErr(error) }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(delArmed ? Color(hex: 0xffd8cc) : K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2)).padding(.top, 2)
            KT(SV.lastSent.isEmpty ? "Saving your progress to your account..." : "Your best scores, ghosts, birds and settings are saved to your account.", 6, K.okGreen, align: .center, spacing: 3).padding(.top, 8).padding(.bottom, 2)
        }
        .onAppear { if SV.lastSent.isEmpty { Task { @MainActor in await savePushAsync(force: true); UIBridge.shared.refresh() } } }
    }
    private func arow(_ name: String, _ val: String, danger: Bool = false, last: Bool = false, _ act: @escaping () -> Void) -> some View {
        Button { playSound("swoosh"); haptic(); act() } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) { KT(name, 8, danger ? K.red : K.orange, shadow: K.cream).frame(maxWidth: .infinity, alignment: .leading); KT(val, 6).opacity(0.75); Arrow() }.padding(.vertical, 7).padding(.horizontal, 9).frame(minHeight: 33)
                if !last { K.line2.frame(height: 1) }
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
struct OnlineDot: View { let uid: String
    var body: some View { let on = isOnline(uid); HStack(spacing: 4) { Circle().fill(on ? Color(hex: 0x4ccc3a) : Color(hex: 0xb0a88a)).frame(width: 7, height: 7).shadow(color: on ? Color(hex: 0x4ccc3a) : .clear, radius: 2); KT(on ? "Online" : "Offline", 6, on ? K.okGreen : Color(hex: 0x8a8270)) } } }

struct TwoFaPage: View {
    @State private var state: String = "loading"
    @State private var on: [String: Any]? = nil
    @State private var enroll: [String: Any]? = nil
    @State private var code = ""
    @State private var msg = ""
    @State private var ok = false
    @State private var keyCopied = false
    var body: some View {
        Scroll {
            if state == "loading" { Note(t: "Loading...") }
            else if state == "on" {
                ChT(t: "2FA is on", color: K.okGreen)
                ChS(t: "When you sign in, you type a code from your authenticator app after your password.")
                Msg(t: msg, ok: ok)
                WorkBtn(t: "Turn 2FA off", busy: "Turning off...", style: .link, msg: $msg, ok: $ok) {
                    try await Auth.shared.unenroll(on?["id"] as? String ?? ""); await Auth.shared.refresh(); _ = try? await Auth.shared.getUser(); ACCT.user = Auth.shared.user
                    playSound("swoosh"); showPage("twofa")
                }
            } else if let en = enroll, let totp = en["totp"] as? [String: Any] {
                ChS(t: "1. Add Flappy Bird to an authenticator app (iPhone Passwords, Google Authenticator...).")
                MkBtn("Open in authenticator app", .save, size: 9, pad: 11) { if let u = URL(string: totp["uri"] as? String ?? "") { UIApplication.shared.open(u) } }.padding(.bottom, 6)
                ChS(t: "On another phone? Scan this:")
                if let qr = qrImage(totp["uri"] as? String ?? "") { Image(uiImage: qr).interpolation(.none).resizable().frame(width: 138, height: 138).padding(6).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2)).padding(.top, 2).padding(.bottom, 8) }
                ChS(t: "Or type this key (tap to copy):")
                let secret = totp["secret"] as? String ?? ""
                Button { UIPasteboard.general.string = secret; keyCopied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { keyCopied = false } } label: {
                    Text(stride(from: 0, to: secret.count, by: 4).map { i in String(Array(secret)[i..<min(i + 4, secret.count)]) }.joined(separator: " ")).font(.system(size: 11, design: .monospaced)).foregroundColor(K.brown)
                        .frame(maxWidth: .infinity).padding(8).background(RoundedRectangle(cornerRadius: 8).fill(keyCopied ? Color(hex: 0xd8f0c8) : K.input)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                }.buttonStyle(.plain).padding(.bottom, 10)
                ChS(t: "2. Type the 6-digit code it shows:")
                Field(ph: "123456", text: $code, size: 20, center: true, kerning: 6, numeric: true, content: .oneTimeCode)
                Msg(t: msg, ok: ok)
                WorkBtn(t: "Turn on 2FA", busy: "Checking...", msg: $msg, ok: $ok) {
                    let v = code.filter { $0.isNumber }; if v.count != 6 { throw NetError(message: "Type all 6 numbers") }
                    try await Auth.shared.challengeAndVerify(en["id"] as? String ?? "", v)
                    _ = try? await Auth.shared.getUser(); ACCT.user = Auth.shared.user
                    playSound("point"); haptic(); toast("2FA is on"); showPage("twofa")
                }
            } else { Note(t: msg) }
        }
        .task {
            do {
                let f = try await Auth.shared.factors()
                if let v = f.totp.first { on = v; state = "on"; return }
                for x in f.all where (x["status"] as? String) != "verified" { try? await Auth.shared.unenroll(x["id"] as? String ?? "") }
                enroll = try await Auth.shared.enroll(name: "Flappy Bird " + rid(4)); state = "enroll"
            } catch { msg = accErr(error); state = "error" }
        }
    }
}
func qrImage(_ s: String) -> UIImage? {
    guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    f.setValue(Data(s.utf8), forKey: "inputMessage")
    guard let o = f.outputImage, let cg = CIContext().createCGImage(o, from: o.extent) else { return nil }
    return UIImage(cgImage: cg)
}
struct EmailPage: View {
    @State private var email = ""
    @State private var msg = ""
    @State private var ok = false
    var body: some View {
        let em = ACCT.user?["email"] as? String ?? "", real = em.hasSuffix(ACC_MAIL) ? "" : em
        return Scroll {
            ChS(t: !real.isEmpty ? "Your email is \(real). Type a new one to change it." : "Add an email so you can reset your password if you forget it. Nobody else sees it.")
            if real.isEmpty { Note(t: "After this you sign in with your email instead of your username.") }
            Field(ph: "Email", text: $email, content: .emailAddress)
            Msg(t: msg, ok: ok)
            WorkBtn(t: real.isEmpty ? "Add email" : "Change email", busy: "Sending...", msg: $msg, ok: $ok) {
                let e = email.trimmingCharacters(in: .whitespaces); if e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) == nil { throw NetError(message: "That email doesn't look right") }
                let u = try await Auth.shared.updateUser(["email": e], redirect: true)
                if let u = u { ACCT.user = u }
                ok = true; msg = (u?["email"] as? String) == e ? "Done! Your email is saved." : "Check \(e) and tap the link to confirm it."
            }
        }
    }
}
struct NewPassPage: View {
    @State private var a = ""
    @State private var b = ""
    @State private var msg = ""
    @State private var ok = false
    var body: some View {
        Scroll {
            ChS(t: ACCT.recovering ? "Pick a new password for \(myUsername().isEmpty ? "your account" : myUsername())." : "Pick a new password.")
            Field(ph: "New password (8+ letters)", text: $a, secure: true, content: .newPassword)
            Field(ph: "Type it again", text: $b, secure: true, content: .newPassword)
            Msg(t: msg, ok: ok)
            WorkBtn(t: "Save password", busy: "Saving...", msg: $msg, ok: $ok) {
                if a.count < 8 { throw NetError(message: "Pick a longer password (8+ letters)") }
                if a != b { throw NetError(message: "The two passwords don't match") }
                _ = try await Auth.shared.updateUser(["password": a])
                ACCT.recovering = false; playSound("point"); toast("Password saved"); accGo("profile", ACCT.uid, replace: true)
            }
        }
    }
}

// MARK: - Friends (accounts)

var palsDraft = ""
struct PalsPage: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var name = palsDraft
    @State private var msg = ""
    @State private var ok = false
    var body: some View {
        _ = ui.tick
        return Scroll {
            HStack(alignment: .top, spacing: 6) {
                Field(ph: "Friend's username", text: Binding(get: { name }, set: { name = String($0.filter { ($0.isLetter && $0.isASCII) || $0.isNumber || $0 == "_" }.prefix(14)); palsDraft = name }), content: .username)
                WorkBtn(t: "Add", size: 9, pad: 9, msg: $msg, ok: $ok) {
                    let n = name.trimmingCharacters(in: .whitespaces); if n.range(of: "^[A-Za-z0-9_]{3,14}$", options: .regularExpression) == nil { throw NetError(message: "Usernames are 3-14 letters, numbers or _") }
                    let r = try await sbAsync("rpc/friend_add", method: "POST", body: ["name": n]) as? String
                    if let who = (try await sbAsync("profiles?select=id&handle=eq." + n.lowercased()) as? [[String: Any]])?.first, r == "sent" || r == "friends" { rtSend(who["id"] as? String ?? "", ["t": r == "friends" ? "yes" : "req"]) }
                    palsDraft = ""; name = ""; playSound("point")
                    toast(r == "sent" ? "Friend request sent to \(n)" : r == "friends" ? "You and \(n) are friends!" : r == "waiting" ? "Still waiting for \(n)" : "Already friends with \(n)")
                    await palsLoadAsync()
                }.frame(width: 70)
            }
            Msg(t: msg, ok: ok).padding(.top, 5)
            if FR.at == 0 { Note(t: "Loading...") }
            else {
                let inc = FR.list.filter { $0.incoming }
                if !inc.isEmpty {
                    Sec(t: "Friend requests", top: 6)
                    ForEach(Array(inc.enumerated()), id: \.offset) { _, f in
                        friendRow(f.p, AnyView(KT("wants to be your friend", 6).opacity(0.8)), AnyView(HStack(spacing: 4) {
                            MkBtn("Accept", .save, full: false) { Task { @MainActor in _ = try? await sbAsync("rpc/friend_add", method: "POST", body: ["name": f.p["username"] ?? ""]); rtSend(pid(f.p), ["t": "yes"]); playSound("point"); await palsLoadAsync() } }.fixedSize()
                            MkBtn("\u{2715}", full: false) { Task { @MainActor in _ = try? await sbAsync("rpc/friend_remove", method: "POST", body: ["other": pid(f.p)]); await palsLoadAsync() } }.fixedSize()
                        }))
                    }
                }
                if !FR.inbox.isEmpty {
                    Sec(t: "Races for you", top: 6)
                    ForEach(Array(FR.inbox.prefix(10).enumerated()), id: \.offset) { _, g in
                        let gid = g["id"] as? String ?? "", fresh = !inboxSeen.contains(gid)
                        Button {
                            playSound("swoosh"); if fresh { inboxSeen.append(gid); saveSeen() }
                            closePicker(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { openLink("#r=" + gid) }
                        } label: {
                            HStack(spacing: 8) {
                                Avatar(av: g["bird"] as? String, bg: "sky", w: 36, h: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text((g["name"] as? String ?? "").uppercased()).font(K.kong(11)).foregroundColor(K.brown).lineLimit(1)
                                    KT((Int(num(g["round"]) ?? 1) > 1 ? "replied" : "sent a race") + " - " + modeInfo(g["mode"] as? String ?? "normal").title + " - beat \(Int(num(g["score"]) ?? 0)) - " + agoText(g["created_at"] as? String ?? ""), 6).opacity(0.8)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                KT(fresh ? "Race!" : "Again", 7, .white).padding(.vertical, 6).padding(.horizontal, 7).background(RoundedRectangle(cornerRadius: 7).fill(Color(hex: 0x9b6bd6)))
                            }.padding(.vertical, 4).padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(fresh ? Color(hex: 0xf3e8ff) : K.light)).overlay(RoundedRectangle(cornerRadius: 9).stroke(fresh ? Color(hex: 0x9b6bd6) : K.line, lineWidth: 2))
                        }.buttonStyle(.plain).padding(.bottom, 4)
                    }
                }
                let fr = FR.list.filter { $0.accepted }.sorted { (isOnline(pid($0.p)) ? 1 : 0, ($1.p["username"] as? String ?? "")) > (isOnline(pid($1.p)) ? 1 : 0, ($0.p["username"] as? String ?? "")) }
                Sec(t: "Friends" + (fr.isEmpty ? "" : " (\(fr.count))"), top: 6)
                if fr.isEmpty { Note(t: "No friends yet. Type a username above, or tap a player on the leaderboard.") }
                ForEach(Array(fr.enumerated()), id: \.offset) { _, f in friendRow(f.p, AnyView(OnlineDot(uid: pid(f.p))), AnyView(Arrow())) }
                let out = FR.list.filter { $0.outgoing }
                if !out.isEmpty {
                    Sec(t: "Waiting for", top: 6)
                    ForEach(Array(out.enumerated()), id: \.offset) { _, f in
                        friendRow(f.p, AnyView(KT("request sent", 6).opacity(0.8)), AnyView(MkBtn("Cancel", full: false) { Task { @MainActor in _ = try? await sbAsync("rpc/friend_remove", method: "POST", body: ["other": pid(f.p)]); await palsLoadAsync() } }.fixedSize()))
                    }
                }
            }
        }
        .task { if FR.at == 0 || Date().timeIntervalSince1970 * 1000 - FR.at > 15000 { await palsLoadAsync() } }
    }
    private func friendRow(_ p: [String: Any], _ sub: AnyView, _ right: AnyView) -> some View {
        Button { playSound("swoosh"); accGo("profile", pid(p)) } label: {
            HStack(spacing: 8) {
                Avatar(av: p["avatar"] as? String, bg: p["avatar_bg"] as? String, w: 36, h: 30)
                VStack(alignment: .leading, spacing: 3) { Text((p["username"] as? String ?? "").uppercased()).font(K.kong(11)).foregroundColor(K.brown).lineLimit(1); sub }.frame(maxWidth: .infinity, alignment: .leading)
                right
            }.padding(.vertical, 4).padding(.horizontal, 8).tile(false, radius: 9)
        }.buttonStyle(.plain).padding(.bottom, 4)
    }
}

// MARK: - Profile picture (5 even columns; the grid never runs under "Show more", birds keep their shape)

var avPick: String? = nil, avBgPick: String? = nil, avSearch = ""
struct AvatarPage: View {
    @State private var pickId = "yellow"
    @State private var bg = "sky"
    @State private var q = avSearch
    @State private var shown = 60
    @State private var msg = ""
    @State private var ok = false
    var body: some View {
        let pool = avPool()
        return Scroll {
            BirdView(id: pickId, w: 96, h: 80, bg: Color(css: avBg(bg)), radius: 8, border: K.brown).padding(.vertical, 4)
            ChS(t: skinName(pickId))
            Flow(spacing: 6, center: true) {
                ForEach(AV_BG, id: \.0) { k, c in
                    Button { bg = k; playSound("swoosh") } label: {
                        Circle().fill(Color(css: c)).frame(width: 30, height: 30).overlay(Circle().stroke(K.brown, lineWidth: 2))
                            .overlay(Circle().stroke(k == bg ? K.cream : .clear, lineWidth: 3).padding(-4)).overlay(Circle().stroke(k == bg ? K.brown : .clear, lineWidth: 2).padding(-6))
                    }.buttonStyle(.plain).padding(k == bg ? 4 : 0)
                }
            }.padding(.top, 4).padding(.bottom, 8)
            Msg(t: msg, ok: ok)
            WorkBtn(t: "Save picture", busy: "Saving...", msg: $msg, ok: $ok) {
                guard let id = ACCT.profile?["id"] as? String else { return }
                _ = try await sbAsync("profiles?id=eq.\(id)", method: "PATCH", body: ["avatar": pickId, "avatar_bg": bg], headers: ["Prefer": "return=minimal"])
                ACCT.profile?["avatar"] = pickId; ACCT.profile?["avatar_bg"] = bg; avPick = nil; playSound("point"); toast("Picture saved"); accGo("profile", id, replace: true)
            }
            Field(ph: "Search birds", text: Binding(get: { q }, set: { q = $0; avSearch = $0; shown = 60 }))
            if pool.isEmpty { Note(t: "No birds called \"\(q)\"") }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 5), spacing: 4) {
                ForEach(Array(pool.prefix(shown)), id: \.self) { id in
                    Button { pickId = id; avPick = id; playSound("swoosh") } label: {
                        PixImage(img: skinCanvas(id, 2), w: 48, h: 40).frame(maxWidth: .infinity).aspectRatio(6.0 / 5.0, contentMode: .fit)
                            .padding(2).background(RoundedRectangle(cornerRadius: 7).fill(K.sky)).overlay(RoundedRectangle(cornerRadius: 7).stroke(id == pickId ? K.orange : K.line, lineWidth: 2))
                    }.buttonStyle(.plain)
                }
            }
            if shown < pool.count { MkBtn("Show more", pad: 9) { shown += 60 }.padding(.vertical, 6) }
        }
        .onAppear {
            if avPick == nil { avPick = skinExists(ACCT.profile?["avatar"] as? String ?? "") ? ACCT.profile!["avatar"] as? String : "yellow"; avBgPick = AV_BG.contains { $0.0 == (ACCT.profile?["avatar_bg"] as? String) } ? ACCT.profile?["avatar_bg"] as? String : "sky" }
            pickId = avPick ?? "yellow"; bg = avBgPick ?? "sky"
        }
        .onChange(of: bg) { avBgPick = $0 }
    }
    private func avPool() -> [String] {
        let s = q.trimmingCharacters(in: .whitespaces).lowercased()
        var seen = Set<String>(), pool: [String] = []
        for id in ([birdColor] + favBirds).filter(skinExists) + allSkins() {
            if seen.contains(id) { continue }; seen.insert(id)
            if !s.isEmpty && !skinName(id).lowercased().contains(s) && !id.contains(s) { continue }
            pool.append(id)
        }
        return pool
    }
}

// MARK: - TV party code, notifications, Apple TV approval

struct PartyCodePage: View {
    @State private var code = ""
    @State private var msg = ""
    var body: some View {
        Scroll {
            ChS(t: "On the Apple TV, open PARTY. Scan its QR code with your camera, or type the code you see on the TV:")
            Field(ph: "Code", text: $code, size: 20, center: true, kerning: 6, caps: true) { go() }
            Msg(t: msg)
            MkBtn("Join", .save, size: 9, pad: 11) { go() }
        }
    }
    private func go() { if !joinParty(code) { msg = "Check the code on the TV"; playSound("hit") } }
}
struct NotifyPage: View {
    var body: some View {
        Scroll {
            ChS(t: "Get a notification when a friend beats your score or sends you a race, even when the game is closed.")
            Note(t: "Notifications work in the website version: open duckyisc00l.github.io/flappy-bird in Safari, tap Share > Add to Home Screen, and turn them on there.")
        }
    }
}
struct TVApprovePage: View {
    @State private var msg = ""
    @State private var ok = false
    @State private var done = false
    var body: some View {
        Scroll {
            if done {
                ChT(t: "Done!", color: K.okGreen)
                ChS(t: "Look at your TV: it signs in as \(myUsername()) in a moment.")
                MkBtn("Close", .save, size: 9, pad: 11) { closePicker() }
            } else if tvCode == nil { Note(t: "Scan the QR code on your Apple TV to sign it in.") }
            else if !accSignedIn() {
                ChT(t: "Sign in first")
                ChS(t: "Sign in on this phone, then you can sign in the Apple TV with the same account.")
                MkBtn(ACCT.needCode ? "Enter your 2FA code" : "Sign in", .save, size: 9, pad: 11) { playSound("swoosh"); accGo("account") }
            } else {
                Avatar(av: ACCT.profile?["avatar"] as? String, bg: ACCT.profile?["avatar_bg"] as? String, w: 96, h: 80, radius: 8, border: 2).padding(.vertical, 4)
                ChT(t: "Sign in the Apple TV?")
                ChS(t: "As \(myUsername()). The TV shows code \(tvCode!) - check it matches.")
                Msg(t: msg, ok: ok)
                WorkBtn(t: "Approve", busy: "Approving...", msg: $msg, ok: $ok) {
                    let r = try await sbAsync("rpc/tv_link_approve", method: "POST", body: ["code": tvCode!])
                    if (r as? Bool) != true { throw NetError(message: "That code ran out or was already used. Get a new one on the TV") }
                    tvCode = nil; playSound("point"); haptic(); done = true
                }
                MkBtn("Cancel", .link, size: 9, pad: 11) { tvCode = nil; closePicker() }
            }
        }
    }
}

// MARK: - the phone as the Apple TV's controller

struct PartyController: View {
    @ObservedObject var ui = UIBridge.shared
    @State private var nick = PARTY.nick
    @State private var hit = false
    var body: some View {
        _ = ui.tick
        let st = PARTY.st, quiet = Date().timeIntervalSince(PARTY.lastTv) > 5, me = partyMe()
        var status = "", big = "TAP TO FLAP", small = "", cls = ""
        if st == nil || quiet { status = "Looking for TV \(PARTY.code ?? "")..."; big = "WAITING"; small = "Is the party open on the Apple TV?"; cls = "wait" }
        else if (st!["s"] as? String) == "closed" { status = "The TV closed the party"; big = "BYE!"; cls = "wait" }
        else if me == nil { status = "Joining..."; big = "WAITING"; small = ((st!["pl"] as? [Any])?.count ?? 0) >= 8 ? "The party is full (8 players)" : ""; cls = "wait" }
        else {
            let s = st!["s"] as? String ?? ""
            let alive = (me!["alive"] as? Bool) ?? ((me!["alive"] as? NSNumber)?.boolValue ?? false), inR = (me!["in"] as? Bool) ?? ((me!["in"] as? NSNumber)?.boolValue ?? false), sc = Int(num(me!["score"]) ?? 0)
            if s == "lobby" { status = "You're in! \((st!["pl"] as? [Any])?.count ?? 0) playing - " + (st!["mode"] as? String ?? "Normal"); big = "READY"; small = "The host starts with the Apple TV remote"; cls = "wait" }
            else if s == "count" { status = "Get ready!"; big = String(describing: st!["c"] ?? "GO"); small = "Tap to flap when it starts"; cls = "count" }
            else if s == "play" {
                if !inR { status = "Round in progress"; big = "NEXT ROUND"; small = "You'll fly in the next one"; cls = "wait" }
                else if alive { status = "Score \(sc)"; big = "FLAP!"; cls = "go" }
                else { status = "You crashed with \(sc)"; big = "OUCH!"; small = "Waiting for the others..."; cls = "dead" }
            } else if s == "over" {
                let win = st!["win"] as? [String] ?? [], won = win.contains(me!["name"] as? String ?? "")
                status = "Round over"; big = won ? "YOU WIN!" : win.count == 1 ? win[0].uppercased() + " WINS" : "TIE!"; small = "Your score: \(sc)"; cls = won ? "win" : "wait"
            }
        }
        let (bg, sh): (Color, Color) = cls == "wait" ? (K.panel, K.line) : cls == "count" || cls == "win" ? (Color(hex: 0xf5c542), Color(hex: 0xd6a52a)) : cls == "dead" ? (K.red, Color(hex: 0xa82a1e)) : (K.green, K.greenDark)
        return GeometryReader { geo in
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Avatar(av: partyBird(), bg: accSignedIn() ? ACCT.profile?["avatar_bg"] as? String : "sky", w: 54, h: 45, border: 3)
                    TextField("Your name", text: Binding(get: { accSignedIn() ? partyName() : nick }, set: { v in nick = String(v.filter { $0.isLetter || $0.isNumber || " .-!'_".contains($0) }.prefix(14)); PARTY.nick = nick; saveStr("partyNick", nick) }))
                        .disabled(accSignedIn()).font(K.kong(16)).textInputAutocapitalization(.characters).foregroundColor(K.brown)
                        .onSubmit { partyHello() }
                        .padding(.vertical, 9).padding(.horizontal, 10).background(RoundedRectangle(cornerRadius: 10).fill(K.cream)).overlay(RoundedRectangle(cornerRadius: 10).stroke(K.brown, lineWidth: 3))
                    Button { leaveParty() } label: { Text("\u{2715}").font(.system(size: 18)).foregroundColor(.white).frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 12).fill(K.orange)).overlay(RoundedRectangle(cornerRadius: 12).stroke(K.brown, lineWidth: 3)) }.buttonStyle(.plain)
                }
                KT(status, 10, .white, shadow: K.brown, align: .center).padding(.top, 12).padding(.bottom, 10)
                VStack(spacing: 14) {
                    OutlinedTitle(t: big, size: 46, outline: 3, drop: 4).multilineTextAlignment(.center).padding(.horizontal, 10)
                    if !small.isEmpty { KT(small, 9, K.brown, align: .center, spacing: 6).padding(.horizontal, 20) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 26).fill(bg); sh.frame(height: 10) }.clipShape(RoundedRectangle(cornerRadius: 26)))
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(K.brown, lineWidth: 5))
                .scaleEffect(hit ? 0.97 : 1)
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { v in
                    guard v.translation == .zero, (st?["s"] as? String) == "play" else { return }
                    if let m = me, ((m["alive"] as? Bool) ?? false) == false { return }
                    partySend("f"); appHaptic("flap")
                    hit = true; DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { hit = false }
                })
                Flow(spacing: 6, center: true) {
                    ForEach(Array(((st?["pl"] as? [[String: Any]]) ?? []).enumerated()), id: \.offset) { _, p in
                        let mine = (p["id"] as? String) == PARTY.id
                        HStack(spacing: 8) { KT(p["name"] as? String ?? "", 8, mine ? .white : K.brown); if (st?["s"] as? String) != "lobby" { Text("\(Int(num(p["score"]) ?? 0))").font(K.kong(10)).foregroundColor(mine ? .white : K.brown) } }
                            .padding(.vertical, 5).padding(.horizontal, 8).background(RoundedRectangle(cornerRadius: 8).fill(mine ? K.orange : K.cream)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
                    }
                }.frame(maxHeight: 92).clipped().padding(.top, 10)
            }
            .padding(.top, geo.safeAreaInsets.top + 10).padding(.horizontal, 12).padding(.bottom, geo.safeAreaInsets.bottom + 10)
            .background(K.sky)
        }
        .ignoresSafeArea()
    }
}
