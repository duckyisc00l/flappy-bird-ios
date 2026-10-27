import Foundation

/// A tiny Supabase Realtime client (broadcast only), the same rooms the phone game uses for live duels.
/// One channel, JSON messages over a WebSocket (Phoenix protocol, vsn 1.0.0).
final class RealtimeRoom {
    let topic: String
    var onMessage: ((String, [String: Any]) -> Void)?
    var onStatus: ((Bool) -> Void)?
    private var task: URLSessionWebSocketTask?
    private var ref = 1
    private var joined = false
    private var heartbeat: Timer?
    private var closed = false
    private var retry: TimeInterval = 1

    init(channel: String) { topic = "realtime:" + channel }

    func connect() {
        closed = false
        let s = Online.url.replacingOccurrences(of: "https://", with: "wss://") + "/realtime/v1/websocket?apikey=" + Online.key + "&vsn=1.0.0"
        guard let url = URL(string: s) else { return }
        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()
        receive(t)
        send(["topic": topic, "event": "phx_join", "join_ref": "1",
              "payload": ["config": ["broadcast": ["self": false, "ack": false], "presence": ["key": ""], "private": false]]])
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            self?.send(["topic": "phoenix", "event": "heartbeat", "payload": [:]])
        }
    }

    func close() {
        closed = true
        heartbeat?.invalidate(); heartbeat = nil
        if joined { send(["topic": topic, "event": "phx_leave", "payload": [:], "join_ref": "1"]) }
        task?.cancel(with: .goingAway, reason: nil); task = nil
        joined = false
    }

    /// send a broadcast to everyone in the room
    func broadcast(_ event: String, _ payload: [String: Any]) {
        guard joined else { return }
        send(["topic": topic, "event": "broadcast", "join_ref": "1", "payload": ["type": "broadcast", "event": event, "payload": payload]])
    }

    private func send(_ msg: [String: Any]) {
        var m = msg
        ref += 1; m["ref"] = String(ref)
        guard let data = try? JSONSerialization.data(withJSONObject: m), let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self = self, t === self.task else { return }
            switch result {
            case .failure:
                DispatchQueue.main.async { self.dropped() }
            case .success(let msg):
                var text: String?
                switch msg { case .string(let s): text = s; case .data(let d): text = String(data: d, encoding: .utf8); @unknown default: break }
                if let text = text, let data = text.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async { self.handle(obj) }
                }
                self.receive(t)
            }
        }
    }

    private func handle(_ obj: [String: Any]) {
        let event = obj["event"] as? String ?? ""
        if event == "phx_reply", (obj["topic"] as? String) == topic, let p = obj["payload"] as? [String: Any], (p["status"] as? String) == "ok", !joined {
            joined = true; retry = 1; onStatus?(true); return
        }
        if event == "phx_error" || event == "phx_close" { dropped(); return }
        if event == "broadcast", let p = obj["payload"] as? [String: Any], let e = p["event"] as? String {
            onMessage?(e, p["payload"] as? [String: Any] ?? [:])
        }
    }

    private func dropped() {
        guard !closed else { return }
        joined = false; onStatus?(false)
        task?.cancel(); task = nil
        heartbeat?.invalidate()
        let wait = retry; retry = min(retry * 2, 15)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in if let s = self, !s.closed { s.connect() } }
    }
}
