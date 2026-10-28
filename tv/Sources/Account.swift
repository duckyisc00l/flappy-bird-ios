import CryptoKit
import Foundation
import Security

/// Your account on the Apple TV. You sign in by approving a code on your phone (no typing passwords with a remote);
/// the TV then has its own login (kept here), scores go to the online leaderboard, and stats add up on your profile.
final class Account {
    static let shared = Account()
    struct Session: Codable { var access: String; var refresh: String; var expires: Double; var userId: String; var username: String; var needCode: Bool }
    private(set) var session: Session?
    var signedIn: Bool { session != nil && session?.needCode == false }
    var username: String { session?.username ?? "" }
    var userId: String? { session?.userId }
    private let base = Online.url
    private let store = "tvSession"

    private init() {
        if let d = UserDefaults.standard.data(forKey: store), let s = try? JSONDecoder().decode(Session.self, from: d) { session = s }
    }
    private func save() {
        if let s = session, let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: store) } else { UserDefaults.standard.removeObject(forKey: store) }
        NotificationCenter.default.post(name: .accountChanged, object: nil)
    }
    func signOut() {
        if let s = session { request("/auth/v1/logout?scope=local", body: [:], token: s.access) { _, _ in } }
        session = nil; save()
    }

    // MARK: talking to Supabase
    private func request(_ path: String, method: String = "POST", body: [String: Any]?, token: String? = nil, done: @escaping (Int, Any?) -> Void) {
        guard let url = URL(string: base + path) else { return done(0, nil) }
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.httpMethod = method
        r.setValue(Online.key, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        if let b = body, method != "GET" { r.httpBody = try? JSONSerialization.data(withJSONObject: b) }
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: [.fragmentsAllowed]) }
            DispatchQueue.main.async { done(code, obj) }
        }.resume()
    }

    // MARK: sign in with your phone
    struct Link { let code: String; let secret: String }
    /// make a one-time code; the secret stays on this TV (the database only gets its SHA-256)
    func startLink(done: @escaping (Link?) -> Void) {
        let A = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        let code = String((0..<8).map { _ in A.randomElement()! })
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let secret = bytes.map { String(format: "%02x", $0) }.joined()
        request("/rest/v1/rpc/tv_link_start", body: ["code": code, "secret_hash": Self.sha256(secret)]) { status, _ in
            done(status >= 200 && status < 300 ? Link(code: code, secret: secret) : nil)
        }
    }
    enum Poll { case waiting, done, failed(String) }
    /// ask whether the phone has approved yet; when it has, sign in
    func poll(_ link: Link, done: @escaping (Poll) -> Void) {
        request("/functions/v1/tv-link", body: ["code": link.code, "secret": link.secret]) { [weak self] status, obj in
            guard let self = self else { return }
            let o = obj as? [String: Any]
            if status == 200, o?["waiting"] as? Bool == true { return done(.waiting) }
            if status == 200, let hash = o?["token_hash"] as? String {
                self.request("/auth/v1/verify", body: ["type": "magiclink", "token_hash": hash]) { st, sess in
                    guard st == 200, let s = sess as? [String: Any], self.take(s, username: o?["username"] as? String) else { return done(.failed("The sign-in didn't work. Try again.")) }
                    self.checkTwoFactor { done(.done) }
                }
                return
            }
            if status == 404 && (o?["error"] as? String) == nil { return done(.failed("The TV sign-in isn't set up on the server yet.")) }
            switch o?["error"] as? String {
            case "expired": done(.failed("The code ran out. Getting a new one..."))
            case "used": done(.failed("That code was already used."))
            case "not found": done(.failed("The TV sign-in isn't set up on the server yet."))
            default: done(status == 0 ? .waiting : .failed("Couldn't reach the server (\(status))."))
            }
        }
    }
    @discardableResult private func take(_ s: [String: Any], username: String?) -> Bool {
        guard let a = s["access_token"] as? String, let r = s["refresh_token"] as? String else { return false }
        let user = s["user"] as? [String: Any]
        let exp = (s["expires_at"] as? Double) ?? (Date().timeIntervalSince1970 + ((s["expires_in"] as? Double) ?? 3600))
        let uid = (user?["id"] as? String) ?? session?.userId ?? ""
        session = Session(access: a, refresh: r, expires: exp, userId: uid, username: username ?? session?.username ?? "", needCode: session?.needCode ?? false)
        save(); return true
    }

    // MARK: 2FA (if you use it, the TV asks for the 6-digit code once)
    private var factorId: String?
    private func checkTwoFactor(done: @escaping () -> Void) {
        guard let s = session else { return done() }
        request("/auth/v1/user", method: "GET", body: nil, token: s.access) { [weak self] _, obj in
            let factors = ((obj as? [String: Any])?["factors"] as? [[String: Any]]) ?? []
            let totp = factors.first { ($0["status"] as? String) == "verified" && ($0["factor_type"] as? String) == "totp" }
            self?.factorId = totp?["id"] as? String
            self?.session?.needCode = totp != nil
            self?.save(); done()
        }
    }
    func verifyCode(_ code: String, done: @escaping (Bool) -> Void) {
        guard let s = session else { return done(false) }
        let go: (String) -> Void = { fid in
            self.request("/auth/v1/factors/\(fid)/challenge", body: [:], token: s.access) { st, obj in
                guard st == 200, let cid = (obj as? [String: Any])?["id"] as? String else { return done(false) }
                self.request("/auth/v1/factors/\(fid)/verify", body: ["challenge_id": cid, "code": code], token: s.access) { st2, sess in
                    guard st2 == 200, let d = sess as? [String: Any] else { return done(false) }
                    self.session?.needCode = false
                    done(self.take(d, username: nil))
                }
            }
        }
        if let f = factorId { go(f) } else { checkTwoFactor { if let f = self.factorId { go(f) } else { self.session?.needCode = false; self.save(); done(true) } } }
    }

    // MARK: staying signed in
    private func withToken(_ use: @escaping (String?) -> Void) {
        guard let s = session, !s.needCode else { return use(nil) }
        if s.expires - Date().timeIntervalSince1970 > 60 { return use(s.access) }
        request("/auth/v1/token?grant_type=refresh_token", body: ["refresh_token": s.refresh]) { [weak self] st, obj in
            guard let self = self else { return }
            if st == 200, let d = obj as? [String: Any], self.take(d, username: nil) { use(self.session?.access) }
            else if st == 400 || st == 401 { self.session = nil; self.save(); use(nil) }   // signed out somewhere else
            else { use(nil) }
        }
    }

    // MARK: after a round: the leaderboard and your profile's stats
    func roundFinished(mode: String, score: Int, bird: String, seconds: Double) {
        guard signedIn else { return }
        withToken { [weak self] t in
            guard let self = self, let t = t, let s = self.session else { return }
            self.request("/rest/v1/rpc/add_stats", body: ["g": 1, "p": max(0, score), "f": 0, "s": Int(seconds)], token: t) { _, _ in }
            let mode = Daily.scoreMode(mode)   // (Daily: today's own board)
            let key = "sent_" + s.userId + "_" + mode
            guard score > 0, score > UserDefaults.standard.integer(forKey: key) else { return }
            self.request("/rest/v1/scores", body: ["name": s.username, "mode": mode, "score": score, "bird": String(bird.prefix(40)),
                                                   "device": Self.devicePrefix + Self.deviceId, "user_id": s.userId], token: t) { st, _ in
                if st >= 200 && st < 300 { UserDefaults.standard.set(score, forKey: key) }
            }
        }
    }
    #if os(tvOS)
    static let devicePrefix = "appletv-"
    #else
    static let devicePrefix = "ios-"
    #endif
    static var deviceId: String {
        if let d = UserDefaults.standard.string(forKey: "deviceId") { return d }
        let d = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
        UserDefaults.standard.set(String(d), forKey: "deviceId"); return String(d)
    }

    static func sha256(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
}

extension Notification.Name { static let accountChanged = Notification.Name("accountChanged") }

// MARK: - typing your username + password (the iPhone app; the TV signs in with your phone instead)
extension Account {
    static let mailDomain = "@players.flappybird.app"
    static let site = "https://duckyisc00l.github.io/flappy-bird/"

    /// a friendly message from an auth error
    private func authMessage(_ obj: Any?, _ fallback: String) -> String {
        let o = obj as? [String: Any]
        let m = (o?["msg"] as? String) ?? (o?["error_description"] as? String) ?? (o?["message"] as? String) ?? ""
        let code = (o?["error_code"] as? String) ?? (o?["code"] as? String) ?? ""
        if m.range(of: "invalid login credentials", options: .caseInsensitive) != nil { return "Wrong username or password" }
        if (m + code).range(of: "weak_password|password should be", options: [.regularExpression, .caseInsensitive]) != nil { return "Pick a longer password (8+ letters)" }
        if (m + code).range(of: "already registered|user_already_exists|email_exists", options: [.regularExpression, .caseInsensitive]) != nil { return "That email is already used by another account" }
        if (m + code).range(of: "rate limit|over_.*_rate", options: [.regularExpression, .caseInsensitive]) != nil { return "Too many tries. Wait a minute and try again" }
        return m.isEmpty ? fallback : m
    }
    private func validName(_ u: String) -> Bool { u.range(of: "^[A-Za-z0-9_]{3,14}$", options: .regularExpression) != nil }

    /// username -> the email the account signs in with (username-only accounts use username@players.flappybird.app)
    private func resolveEmail(_ user: String, done: @escaping (String?, String?) -> Void) {
        let u = user.trimmingCharacters(in: .whitespaces)
        if u.contains("@") { return done(u, nil) }
        guard validName(u) else { return done(nil, "Usernames are 3-14 letters, numbers or _") }
        request("/rest/v1/profiles?select=email_login&handle=eq.\(u.lowercased())", method: "GET", body: nil) { st, obj in
            guard st == 200, let rows = obj as? [[String: Any]] else { return done(nil, "Couldn't reach the server. Check the internet") }
            guard let r = rows.first else { return done(nil, "No player called \(u)") }
            if r["email_login"] as? Bool == true { return done(nil, "This account signs in with its email. Type your email instead") }
            done(u.lowercased() + Self.mailDomain, nil)
        }
    }
    private func fetchUsername(_ uid: String, token: String, done: @escaping (String) -> Void) {
        request("/rest/v1/profiles?select=username&id=eq.\(uid)", method: "GET", body: nil, token: token) { _, obj in
            done(((obj as? [[String: Any]])?.first?["username"] as? String) ?? "")
        }
    }
    /// sign in; done(nil) = signed in (check session.needCode for 2FA), done(message) = a problem
    func signIn(user: String, password: String, done: @escaping (String?) -> Void) {
        guard !user.isEmpty, !password.isEmpty else { return done("Type your username and password") }
        resolveEmail(user) { [weak self] email, err in
            guard let self = self, let email = email else { return done(err) }
            self.request("/auth/v1/token?grant_type=password", body: ["email": email, "password": password]) { st, obj in
                guard st == 200, let s = obj as? [String: Any], let tok = s["access_token"] as? String else { return done(self.authMessage(obj, "Wrong username or password")) }
                let uid = ((s["user"] as? [String: Any])?["id"] as? String) ?? ""
                self.fetchUsername(uid, token: tok) { name in
                    self.session = nil
                    guard self.take(s, username: name) else { return done("The sign-in didn't work. Try again") }
                    self.checkTwoFactor { done(nil) }
                }
            }
        }
    }
    /// create an account (the email is optional: with one you can reset a forgotten password)
    func signUp(username: String, password: String, email: String, done: @escaping (String?) -> Void) {
        let u = username.trimmingCharacters(in: .whitespaces), e = email.trimmingCharacters(in: .whitespaces)
        guard validName(u) else { return done("Usernames are 3-14 letters, numbers or _") }
        guard password.count >= 8 else { return done("Pick a longer password (8+ letters)") }
        if !e.isEmpty && e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) == nil { return done("That email doesn't look right") }
        request("/rest/v1/profiles?select=id&handle=eq.\(u.lowercased())", method: "GET", body: nil) { [weak self] st, obj in
            guard let self = self else { return }
            if let rows = obj as? [[String: Any]], !rows.isEmpty { return done("That username is taken") }
            let body: [String: Any] = ["email": e.isEmpty ? u.lowercased() + Self.mailDomain : e, "password": password,
                                       "data": ["username": u, "email_login": !e.isEmpty]]
            self.request("/auth/v1/signup?redirect_to=" + (Self.site.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""), body: body) { st, obj in
                guard st == 200, let s = obj as? [String: Any] else { return done(self.authMessage(obj, "Couldn't make the account")) }
                if s["access_token"] == nil { return done("Almost done! Open the link we emailed you, then sign in.") }
                self.session = nil
                guard self.take(s, username: u) else { return done("Couldn't make the account") }
                done(nil)
            }
        }
    }
    /// forgot your password: a link by email
    func recover(email: String, done: @escaping (String?) -> Void) {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard e.range(of: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", options: .regularExpression) != nil else { return done("That email doesn't look right") }
        request("/auth/v1/recover?redirect_to=" + (Self.site.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""), body: ["email": e]) { st, obj in
            done(st == 200 ? nil : self.authMessage(obj, "Couldn't send the email"))
        }
    }
    /// a database call as you (signed in) or as a guest
    func rest(_ path: String, method: String = "GET", body: [String: Any]? = nil, prefer: String? = nil, done: @escaping (Int, Any?) -> Void) {
        let go: (String?) -> Void = { t in self.request("/rest/v1/" + path, method: method, body: body, token: t, done: done) }
        if signedIn { withToken { go($0) } } else { go(nil) }
    }
}
