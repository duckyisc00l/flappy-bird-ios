import SwiftUI

// MARK: - Leaderboard (the same online board as the website and the Apple TV)
struct LeaderboardView: View {
    @EnvironmentObject var g: GameModel
    @State private var mode = Prefs.mode
    @State private var week = false
    @State private var rows: [Online.Row] = []
    @State private var note = "Loading..."
    var body: some View {
        Panel(title: "Leaderboard", onClose: { g.sheet = nil }) {
            VStack(spacing: 10) {
                if !Account.shared.signedIn {
                    Button { g.sheet = .account } label: { VStack(alignment: .leading, spacing: 4) { Text("SIGN IN"); Text("OR CREATE AN ACCOUNT TO GET ON THE BOARD").font(Px.text(7)) } }
                        .buttonStyle(PxButtonStyle(fill: Px.orange, fg: .white, size: 12))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Modes.all, id: \.id) { m in
                            Button { mode = m.id; load() } label: { Text(m.title.uppercased()).font(Px.text(8)).padding(.vertical, 8).padding(.horizontal, 10)
                                .background(Capsule().fill(m.id == mode ? Px.orange : Px.light)).foregroundColor(m.id == mode ? .white : Px.brown).overlay(Capsule().stroke(Px.brown, lineWidth: 2)) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    ForEach([(false, "ALL TIME"), (true, "THIS WEEK")], id: \.0) { w in
                        Button { week = w.0; load() } label: { Text(w.1) }.buttonStyle(PxButtonStyle(fill: week == w.0 ? Px.orange : Px.light, fg: week == w.0 ? .white : Px.brown, size: 9))
                    }
                }
                ScrollView {
                    VStack(spacing: 6) {
                        if rows.isEmpty { Text(note.uppercased()).font(Px.text(9)).foregroundColor(Px.brown).multilineTextAlignment(.center).padding(.top, 30) }
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                            let mine = Account.shared.signedIn && r.userId == Account.shared.userId
                            Card(on: mine) {
                                HStack(spacing: 10) {
                                    Text(i < 3 ? ["1ST", "2ND", "3RD"][i] : "\(i + 1)").font(Px.text(10)).foregroundColor(Px.orange).frame(width: 40)
                                    BirdPic(id: r.avatar ?? r.bird, size: 40, bg: Color(Online.color(r.avatarBg)))
                                    Text(r.name.uppercased()).font(Px.text(11)).foregroundColor(Px.brown).lineLimit(1)
                                    Spacer()
                                    Text("\(r.score)").font(Px.title(26)).foregroundColor(Px.brown)
                                }
                            }
                        }
                    }.padding(.bottom, 30)
                }
            }.padding(.horizontal, 16)
        }.onAppear(perform: load)
    }
    private func load() {
        note = "Loading..."; rows = []
        let m = mode, w = week
        Online.leaderboard(mode: m, week: w) { r in
            guard m == mode, w == week else { return }
            switch r {
            case .success(let list): rows = Array(list.prefix(50)); note = list.isEmpty ? "No scores yet. Be the first!" : ""
            case .failure: note = "Couldn't reach the leaderboard. Check the internet."
            }
        }
    }
}

// MARK: - Account: sign in, create, 2FA, forgot password, your profile
struct AccountView: View {
    @EnvironmentObject var g: GameModel
    @State private var tab = 0          // 0 sign in, 1 create, 2 forgot
    @State private var user = ""
    @State private var pass = ""
    @State private var email = ""
    @State private var code = ""
    @State private var msg = ""
    @State private var ok = false
    @State private var busy = false
    var body: some View {
        let a = Account.shared
        Panel(title: a.signedIn ? "Profile" : "Account", onClose: { g.sheet = nil }) {
            ScrollView {
                VStack(spacing: 12) {
                    if a.signedIn { ProfileView() }
                    else if a.session?.needCode == true { twoFA }
                    else { signInForms }
                }.padding(16)
            }
        }.id(g.accountTick)
    }
    private var message: some View {
        Text(msg.uppercased()).font(Px.text(8)).foregroundColor(ok ? Px.hex(0x3f8f2a) : Px.hex(0xc0392b)).lineSpacing(3).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func field(_ ph: String, _ text: Binding<String>, secure: Bool = false, kind: UITextContentType? = nil, keyboard: UIKeyboardType = .default) -> some View {
        Group {
            if secure { SecureField(ph, text: text) } else { TextField(ph, text: text) }
        }
        .textContentType(kind).keyboardType(keyboard).autocorrectionDisabled().textInputAutocapitalization(.never)
        .font(Px.text(12)).padding(12).background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 1, green: 0.98, blue: 0.88)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Px.brown, lineWidth: 2))
    }
    private var signInForms: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach([(0, "SIGN IN"), (1, "CREATE ACCOUNT")], id: \.0) { t in
                    Button { tab = t.0; msg = "" } label: { Text(t.1) }.buttonStyle(PxButtonStyle(fill: tab == t.0 || (tab == 2 && t.0 == 0) ? Px.orange : Px.light, fg: tab == t.0 || (tab == 2 && t.0 == 0) ? .white : Px.brown, size: 9))
                }
            }
            if tab == 0 {
                field("Username or email", $user, kind: .username)
                field("Password", $pass, secure: true, kind: .password)
                message
                Button(busy ? "SIGNING IN..." : "SIGN IN") { run { done in Account.shared.signIn(user: user, password: pass, done: done) } }.buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 13))
                Button("FORGOT PASSWORD?") { tab = 2; msg = "" }.font(Px.text(9)).foregroundColor(Px.brown).underline()
            } else if tab == 1 {
                field("Username", $user, kind: .username)
                field("Password (8+ letters)", $pass, secure: true, kind: .newPassword)
                field("Email (optional)", $email, kind: .emailAddress, keyboard: .emailAddress)
                Text("YOUR USERNAME SHOWS ON THE LEADERBOARD. THE EMAIL IS OPTIONAL: WITH ONE YOU CAN RESET A FORGOTTEN PASSWORD.").font(Px.text(7)).foregroundColor(Px.brown).lineSpacing(3)
                message
                Button(busy ? "CREATING..." : "CREATE ACCOUNT") { run { done in Account.shared.signUp(username: user, password: pass, email: email, done: done) } }.buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 13))
            } else {
                Text("TYPE THE EMAIL ON YOUR ACCOUNT. WE'LL SEND YOU A LINK TO PICK A NEW PASSWORD.").font(Px.text(8)).foregroundColor(Px.brown).lineSpacing(3)
                field("Email", $email, kind: .emailAddress, keyboard: .emailAddress)
                message
                Button(busy ? "SENDING..." : "SEND THE LINK") {
                    busy = true; msg = ""
                    Account.shared.recover(email: email) { err in busy = false; ok = err == nil; msg = err ?? "Sent! Open the link in the email to pick a new password." }
                }.buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 13))
                Button("BACK TO SIGN IN") { tab = 0; msg = "" }.font(Px.text(9)).foregroundColor(Px.brown).underline()
            }
        }
    }
    private var twoFA: some View {
        VStack(spacing: 12) {
            Text("OPEN YOUR AUTHENTICATOR APP AND TYPE THE 6-DIGIT CODE FOR FLAPPY BIRD.").font(Px.text(9)).foregroundColor(Px.brown).lineSpacing(3)
            field("123456", $code, kind: .oneTimeCode, keyboard: .numberPad)
            message
            Button(busy ? "CHECKING..." : "VERIFY") {
                let c = code.filter { $0.isNumber }
                guard c.count == 6 else { ok = false; msg = "Type all 6 numbers"; return }
                busy = true; msg = ""
                Account.shared.verifyCode(c) { good in busy = false; ok = good; msg = good ? "" : "Wrong code. Try the newest one."; if good { g.accountTick += 1 } }
            }.buttonStyle(PxButtonStyle(fill: Px.green, fg: .white, size: 13))
            Button("CANCEL") { Account.shared.signOut() }.buttonStyle(PxButtonStyle(size: 11))
        }
    }
    private func run(_ f: (@escaping (String?) -> Void) -> Void) {
        guard !busy else { return }
        busy = true; msg = ""
        f { err in
            busy = false; ok = err == nil || (err ?? "").hasPrefix("Almost done")
            msg = err ?? ""
            if err == nil { g.accountTick += 1; if Account.shared.signedIn { g.show("Signed in as \(Account.shared.username)") } }
        }
    }
}

/// your profile: stats, best scores, sign out
struct ProfileView: View {
    @EnvironmentObject var g: GameModel
    @State private var stats: [String: Any] = [:]
    @State private var bests: [String: Int] = [:]
    var body: some View {
        let a = Account.shared
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                BirdPic(id: (stats["avatar"] as? String) ?? (Prefs.bird == "random" ? "yellow" : Prefs.bird), size: 70, bg: Color(Online.color(stats["avatar_bg"] as? String)))
                VStack(alignment: .leading, spacing: 6) {
                    Text(a.username.uppercased()).font(Px.text(15)).foregroundColor(Px.brown)
                    if let d = stats["created_at"] as? String { Text("PLAYING SINCE \(String(d.prefix(10)))").font(Px.text(7)).foregroundColor(Px.brown) }
                }
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach([("GAMES", "games"), ("PIPES", "pipes"), ("FLAPS", "flaps"), ("TIME", "seconds")], id: \.1) { t in
                    VStack(spacing: 4) { Text(value(t.1)).font(Px.text(12)); Text(t.0).font(Px.text(6)) }.foregroundColor(Px.brown).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Px.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Px.line, lineWidth: 2))
                }
            }
            Text("BEST SCORES").font(Px.text(10)).foregroundColor(Px.brown).frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(Modes.all, id: \.id) { m in
                    let b = bests[Daily.scoreMode(m.id)] ?? 0
                    HStack { Text(m.title.uppercased()).font(Px.text(7)); Spacer(); Text(b > 0 ? "\(b)" : "-").font(Px.text(11)) }.foregroundColor(Px.brown.opacity(b > 0 ? 1 : 0.5))
                        .padding(8).background(RoundedRectangle(cornerRadius: 7).fill(Px.light)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Px.line, lineWidth: 2))
                }
            }
            Text("FRIENDS, DUELS, RACES AND REPLAYS ARE COMING TO THE SWIFT APP NEXT. FOR NOW THEY'RE ON THE WEBSITE.").font(Px.text(7)).foregroundColor(Px.brown.opacity(0.7)).lineSpacing(3)
            Button("SIGN OUT") { Account.shared.signOut(); g.accountTick += 1 }.buttonStyle(PxButtonStyle(size: 12))
        }.onAppear(perform: load)
    }
    private func value(_ k: String) -> String {
        let n = (stats[k] as? Int) ?? 0
        if k == "seconds" { let h = n / 3600, m = n / 60 % 60; return h > 0 ? "\(h)H \(m)M" : m > 0 ? "\(m)M" : "\(n)S" }
        return n >= 10000 ? "\(n / 1000)K" : "\(n)"
    }
    private func load() {
        guard let uid = Account.shared.userId else { return }
        Account.shared.rest("profiles?select=*&id=eq.\(uid)") { _, obj in if let r = (obj as? [[String: Any]])?.first { stats = r } }
        Account.shared.rest("scores?select=mode,score&user_id=eq.\(uid)&order=score.desc&limit=300") { _, obj in
            var b: [String: Int] = [:]
            for r in (obj as? [[String: Any]]) ?? [] { if let m = r["mode"] as? String, let s = r["score"] as? Int, s > (b[m] ?? 0) { b[m] = s } }
            bests = b
        }
    }
}
