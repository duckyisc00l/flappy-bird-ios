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
            let key = "sent_" + s.userId + "_" + mode
            guard score > 0, score > UserDefaults.standard.integer(forKey: key) else { return }
            self.request("/rest/v1/scores", body: ["name": s.username, "mode": mode, "score": score, "bird": String(bird.prefix(40)),
                                                   "device": "appletv-" + Self.deviceId, "user_id": s.userId], token: t) { st, _ in
                if st >= 200 && st < 300 { UserDefaults.standard.set(score, forKey: key) }
            }
        }
    }
    static var deviceId: String {
        if let d = UserDefaults.standard.string(forKey: "deviceId") { return d }
        let d = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
        UserDefaults.standard.set(String(d), forKey: "deviceId"); return String(d)
    }

    static func sha256(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
}

extension Notification.Name { static let accountChanged = Notification.Name("accountChanged") }
