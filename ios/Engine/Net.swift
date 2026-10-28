import Foundation

// Supabase, the same backend as the website: REST (database), Auth (accounts + 2FA) and Realtime (rooms + who's online).
// Only the publishable key lives in the app; every table is protected by Row Level Security on the server.
let SB_URL = "https://umnmgkbzsfpockrorcqd.supabase.co"
let SB_KEY = "sb_publishable_Mtltj8MvHzXQyMHTWprIzg_DjOU2XJz"
let SITE = "https://duckyisc00l.github.io/flappy-bird/"
let ACC_MAIL = "@players.flappybird.app"

struct NetError: Error, LocalizedError { let message: String; var code: String? = nil; var errorDescription: String? { message } }

/// one HTTP call; returns the parsed JSON (or nil for an empty body)
func http(_ url: String, method: String = "GET", body: Any? = nil, headers: [String: String] = [:], timeout: Double = 9) async throws -> (Int, Any?) {
    guard let u = URL(string: url) else { throw NetError(message: "Something went wrong") }
    var r = URLRequest(url: u, timeoutInterval: timeout)
    r.httpMethod = method
    r.setValue(SB_KEY, forHTTPHeaderField: "apikey")
    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
    if let b = body { r.httpBody = (b as? String).map { Data($0.utf8) } ?? (try? JSONSerialization.data(withJSONObject: b, options: [.fragmentsAllowed])) }
    do {
        let (data, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = data.isEmpty ? nil : try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return (code, obj)
    } catch let e as URLError {
        if e.code == .timedOut { throw NetError(message: "Couldn't reach the internet") }
        throw NetError(message: "You're offline")
    }
}
/// a call to the database (REST); throws a short, friendly message on trouble. Signed in: carries your sign-in.
func sbAsync(_ path: String, method: String = "GET", body: Any? = nil, headers: [String: String] = [:]) async throws -> Any? {
    var h = headers
    if let t = await Auth.shared.token(), !ACCT.needCode, h["Authorization"] == nil { h["Authorization"] = "Bearer " + t }
    let (code, obj) = try await http(SB_URL + "/rest/v1/" + path, method: method, body: body, headers: h)
    if !(200..<300).contains(code) {
        let m = (obj as? [String: Any])?["message"] as? String ?? ""
        throw NetError(message: code >= 500 ? "The server is busy, try again" : (m.isEmpty ? "Something went wrong (\(code))" : m))
    }
    return obj
}
enum SBResult { case success(Any?), failure(NetError) }
func sb(_ path: String, method: String = "GET", body: Any? = nil, headers: [String: String] = [:], done: ((SBResult) -> Void)? = nil) {
    Task { @MainActor in
        do { let v = try await sbAsync(path, method: method, body: body, headers: headers); done?(.success(v)) }
        catch let e as NetError { done?(.failure(e)) }
        catch { done?(.failure(NetError(message: "Something went wrong"))) }
    }
}
func rid(_ n: Int) -> String {
    let A = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789")
    var g = SystemRandomNumberGenerator()
    return String((0..<n).map { _ in A[Int(g.next() % UInt64(256)) % A.count] })
}

// MARK: - Auth (GoTrue REST), the same accounts as the website

struct Session: Codable { var access_token: String, refresh_token: String, expires_at: Double, user: [String: AnyCodable] }
struct AnyCodable: Codable {
    let value: Any
    init(_ v: Any) { value = v }
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if c.decodeNil() { value = NSNull() }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let s = try? c.decode(String.self) { value = s }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
        else if let o = try? c.decode([String: AnyCodable].self) { value = o.mapValues { $0.value } }
        else { value = NSNull() }
    }
    func encode(to e: Encoder) throws {
        var c = e.singleValueContainer()
        switch value {
        case let b as Bool: try c.encode(b)
        case let n as NSNumber: try c.encode(n.doubleValue)
        case let s as String: try c.encode(s)
        case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]: try c.encode(o.mapValues { AnyCodable($0) })
        default: try c.encodeNil()
        }
    }
}
final class Auth {
    static let shared = Auth()
    private(set) var session: [String: Any]? = nil
    private var refreshing: Task<Bool, Never>? = nil
    var onChange: ((String, [String: Any]?) -> Void)?   // (event, session)

    private init() {
        if let o = jsonObj(localStorage.getItem("fb_auth")), o["access_token"] != nil { session = o }
    }
    private func store() { if let s = session { localStorage.setQuiet("fb_auth", jsonStr(s)) } else { localStorage.setQuiet("fb_auth", nil) } }
    var user: [String: Any]? { session?["user"] as? [String: Any] }
    /// a valid access token (refreshed when it's about to run out)
    func token() async -> String? {
        guard let s = session else { return nil }
        let exp = num(s["expires_at"]) ?? 0
        if exp - Date().timeIntervalSince1970 < 60 { if await refresh() == false { return session?["access_token"] as? String } }
        return session?["access_token"] as? String
    }
    @discardableResult func refresh() async -> Bool {
        if let t = refreshing { return await t.value }
        let t = Task<Bool, Never> { @MainActor in
            defer { refreshing = nil }
            guard let rt = session?["refresh_token"] as? String else { return false }
            guard let (code, obj) = try? await http(SB_URL + "/auth/v1/token?grant_type=refresh_token", method: "POST", body: ["refresh_token": rt]) else { return false }
            if code == 200, let o = obj as? [String: Any] { take(o, "TOKEN_REFRESHED"); return true }
            if (400..<500).contains(code) { session = nil; store(); onChange?("SIGNED_OUT", nil) }
            return false
        }
        refreshing = t
        return await t.value
    }
    @MainActor func take(_ o: [String: Any], _ ev: String) {
        var s = o
        if s["expires_at"] == nil { s["expires_at"] = Date().timeIntervalSince1970 + (num(o["expires_in"]) ?? 3600) }
        session = s; store()
        onChange?(ev, s)
    }
    func authErr(_ code: Int, _ obj: Any?) -> NetError {
        let o = obj as? [String: Any] ?? [:]
        let m = (o["msg"] as? String) ?? (o["message"] as? String) ?? (o["error_description"] as? String) ?? (o["error"] as? String) ?? "Something went wrong (\(code))"
        return NetError(message: m, code: o["error_code"] as? String ?? o["code"] as? String)
    }
    func signIn(email: String, password: String) async throws -> [String: Any] {
        let (code, obj) = try await http(SB_URL + "/auth/v1/token?grant_type=password", method: "POST", body: ["email": email, "password": password])
        guard code == 200, let o = obj as? [String: Any] else { throw authErr(code, obj) }
        await take(o, "SIGNED_IN")
        return o
    }
    /// returns the session, or nil when an email has to be confirmed first
    func signUp(email: String, password: String, data: [String: Any]) async throws -> [String: Any]? {
        let (code, obj) = try await http(SB_URL + "/auth/v1/signup?redirect_to=" + (SITE.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""), method: "POST", body: ["email": email, "password": password, "data": data])
        guard code == 200, let o = obj as? [String: Any] else { throw authErr(code, obj) }
        if o["access_token"] != nil { await take(o, "SIGNED_IN"); return o }
        return nil
    }
    func recover(email: String) async throws {
        let (code, obj) = try await http(SB_URL + "/auth/v1/recover?redirect_to=" + (SITE.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""), method: "POST", body: ["email": email])
        if !(200..<300).contains(code) { throw authErr(code, obj) }
    }
    func signOut() async {
        if let t = session?["access_token"] as? String { _ = try? await http(SB_URL + "/auth/v1/logout?scope=local", method: "POST", body: [:], headers: ["Authorization": "Bearer " + t]) }
        await MainActor.run { session = nil; store() }
    }
    private func authed(_ path: String, method: String, body: Any? = nil) async throws -> Any? {
        guard let t = await token() else { throw NetError(message: "Sign in first") }
        let (code, obj) = try await http(SB_URL + "/auth/v1/" + path, method: method, body: body, headers: ["Authorization": "Bearer " + t])
        if !(200..<300).contains(code) { throw authErr(code, obj) }
        return obj
    }
    func getUser() async throws -> [String: Any]? {
        let o = try await authed("user", method: "GET") as? [String: Any]
        if let u = o { await MainActor.run { session?["user"] = u; store() } }
        return o
    }
    func updateUser(_ attrs: [String: Any], redirect: Bool = false) async throws -> [String: Any]? {
        let o = try await authed("user" + (redirect ? "?redirect_to=" + (SITE.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "") : ""), method: "PUT", body: attrs) as? [String: Any]
        if let u = o { await MainActor.run { session?["user"] = u; store() } }
        return o
    }
    // 2FA (TOTP)
    func factors() async throws -> (totp: [[String: Any]], all: [[String: Any]]) {
        let u = try await getUser()
        let all = u?["factors"] as? [[String: Any]] ?? []
        return (all.filter { ($0["factor_type"] as? String) == "totp" && ($0["status"] as? String) == "verified" }, all)
    }
    /// (current, next) assurance level, like supabase-js
    func aal() -> (String, String) {
        let cur = jwt(session?["access_token"] as? String)["aal"] as? String ?? "aal1"
        let verified = (user?["factors"] as? [[String: Any]] ?? []).contains { ($0["status"] as? String) == "verified" }
        return (cur, verified ? "aal2" : "aal1")
    }
    func enroll(name: String) async throws -> [String: Any] {
        guard let o = try await authed("factors", method: "POST", body: ["factor_type": "totp", "friendly_name": name, "issuer": "Flappy Bird"]) as? [String: Any] else { throw NetError(message: "Something went wrong") }
        return o
    }
    func unenroll(_ id: String) async throws { _ = try await authed("factors/" + id, method: "DELETE") }
    func challengeAndVerify(_ factor: String, _ code: String) async throws {
        guard let ch = try await authed("factors/\(factor)/challenge", method: "POST", body: [:]) as? [String: Any], let cid = ch["id"] as? String else { throw NetError(message: "Something went wrong") }
        guard let v = try await authed("factors/\(factor)/verify", method: "POST", body: ["challenge_id": cid, "code": code]) as? [String: Any] else { throw NetError(message: "Something went wrong") }
        await take(v, "MFA_CHALLENGE_VERIFIED")
    }
}
func jwt(_ t: String?) -> [String: Any] {
    guard let t = t else { return [:] }
    let parts = t.split(separator: ".")
    guard parts.count > 1 else { return [:] }
    var b = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while b.count % 4 != 0 { b += "=" }
    guard let d = Data(base64Encoded: b) else { return [:] }
    return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] ?? [:]
}

// MARK: - Realtime (Phoenix websocket): broadcast + presence, many channels on one connection

final class RTChannel {
    let topic: String, name: String
    var presenceKey: String
    var joined = false
    var onBroadcast: [String: ([String: Any]) -> Void] = [:]
    var onPresenceSync: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var presence: [String: [[String: Any]]] = [:]
    var tracked: [String: Any]? = nil
    var joinRef = ""
    init(_ name: String, presenceKey: String = "") { self.name = name; topic = "realtime:" + name; self.presenceKey = presenceKey }
    func on(_ event: String, _ f: @escaping ([String: Any]) -> Void) { onBroadcast[event] = f }
    func send(_ event: String, _ payload: [String: Any]) { Realtime.shared.push(self, "broadcast", ["type": "broadcast", "event": event, "payload": payload]) }
    func track(_ meta: [String: Any]) { tracked = meta; if joined { Realtime.shared.push(self, "presence", ["type": "presence", "event": "track", "payload": meta]) } }
    func subscribe() { Realtime.shared.join(self) }
    func unsubscribe() { Realtime.shared.leave(self) }
    func presenceState() -> [String: [[String: Any]]] { presence }
}
final class Realtime {
    static let shared = Realtime()
    private var task: URLSessionWebSocketTask?
    private var channels: [String: RTChannel] = [:]
    private var ref = 0
    private var hb: Timer?
    private var retry = 1.0
    private var connecting = false

    private func connect() {
        if task != nil || connecting { return }
        connecting = true
        let s = SB_URL.replacingOccurrences(of: "https://", with: "wss://") + "/realtime/v1/websocket?apikey=" + SB_KEY + "&vsn=1.0.0"
        let t = URLSession.shared.webSocketTask(with: URL(string: s)!)
        task = t; t.resume(); connecting = false
        receive(t)
        hb?.invalidate()
        hb = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in self?.raw(["topic": "phoenix", "event": "heartbeat", "payload": [:]]) }
        for c in channels.values { sendJoin(c) }
    }
    private func nextRef() -> String { ref += 1; return String(ref) }
    private func raw(_ m: [String: Any]) {
        var msg = m; msg["ref"] = nextRef()
        guard let d = try? JSONSerialization.data(withJSONObject: msg), let s = String(data: d, encoding: .utf8) else { return }
        task?.send(.string(s)) { _ in }
    }
    func push(_ c: RTChannel, _ event: String, _ payload: [String: Any]) {
        guard c.joined else { return }
        raw(["topic": c.topic, "event": event, "payload": payload, "join_ref": c.joinRef])
    }
    private func sendJoin(_ c: RTChannel) {
        c.joinRef = nextRef()
        var payload: [String: Any] = ["config": ["broadcast": ["self": false, "ack": false], "presence": ["key": c.presenceKey], "private": false]]
        if let t = Auth.shared.session?["access_token"] as? String { payload["access_token"] = t }
        raw(["topic": c.topic, "event": "phx_join", "payload": payload, "join_ref": c.joinRef])
    }
    func join(_ c: RTChannel) {
        channels[c.topic] = c
        if task == nil { connect() } else { sendJoin(c) }
    }
    func leave(_ c: RTChannel) {
        if c.joined { raw(["topic": c.topic, "event": "phx_leave", "payload": [:], "join_ref": c.joinRef]) }
        c.joined = false
        if channels[c.topic] === c { channels[c.topic] = nil }
        if channels.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in if self?.channels.isEmpty == true { self?.close() } } }
    }
    private func close() { hb?.invalidate(); hb = nil; task?.cancel(with: .goingAway, reason: nil); task = nil }
    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] res in
            guard let self = self, t === self.task else { return }
            switch res {
            case .failure: DispatchQueue.main.async { self.dropped() }
            case .success(let m):
                var text: String?
                switch m { case .string(let s): text = s; case .data(let d): text = String(data: d, encoding: .utf8); @unknown default: break }
                if let s = text, let d = s.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { DispatchQueue.main.async { self.handle(o) } }
                self.receive(t)
            }
        }
    }
    private func dropped() {
        task?.cancel(); task = nil; hb?.invalidate()
        for c in channels.values { c.joined = false; c.onStatus?("CHANNEL_ERROR") }
        if channels.isEmpty { return }
        let w = retry; retry = min(retry * 2, 15)
        DispatchQueue.main.asyncAfter(deadline: .now() + w) { [weak self] in self?.connect() }
    }
    private func handle(_ o: [String: Any]) {
        guard let topic = o["topic"] as? String, let c = channels[topic] else { return }
        let ev = o["event"] as? String ?? "", p = o["payload"] as? [String: Any] ?? [:]
        switch ev {
        case "phx_reply":
            if !c.joined, (p["status"] as? String) == "ok", (o["ref"] as? String) == c.joinRef || (o["join_ref"] as? String) == c.joinRef || true {
                if c.joined { return }
                c.joined = true; retry = 1
                c.onStatus?("SUBSCRIBED")
                if let m = c.tracked { push(c, "presence", ["type": "presence", "event": "track", "payload": m]) }
            }
        case "phx_error", "phx_close": c.joined = false; c.onStatus?("CHANNEL_ERROR")
        case "broadcast":
            if let e = p["event"] as? String { c.onBroadcast[e]?(p["payload"] as? [String: Any] ?? [:]) }
        case "presence_state":
            c.presence = [:]
            for (k, v) in p { c.presence[k] = ((v as? [String: Any])?["metas"] as? [[String: Any]]) ?? [] }
            c.onPresenceSync?()
        case "presence_diff":
            for (k, v) in p["joins"] as? [String: Any] ?? [:] { let metas = ((v as? [String: Any])?["metas"] as? [[String: Any]]) ?? []; c.presence[k, default: []].append(contentsOf: metas) }
            for (k, v) in p["leaves"] as? [String: Any] ?? [:] {
                let refs = Set((((v as? [String: Any])?["metas"] as? [[String: Any]]) ?? []).compactMap { $0["phx_ref"] as? String })
                c.presence[k] = (c.presence[k] ?? []).filter { !refs.contains($0["phx_ref"] as? String ?? "") }
                if c.presence[k]?.isEmpty == true { c.presence[k] = nil }
            }
            c.onPresenceSync?()
        default: break
        }
    }
}
