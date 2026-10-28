import Foundation
import UIKit

/// The website's localStorage, kept in a file in the app (same keys: "fb_bestScore", "fb_ghost", ...),
/// so saved progress moves between the website and the app through your account unchanged.
final class LocalStorage {
    static let shared = LocalStorage()
    private(set) var items: [String: String] = [:]
    private var order: [String] = []
    private let url: URL
    private var pending: DispatchWorkItem?
    /// (key, before, after) after every change
    var onChange: ((String, String?, String?) -> Void)?

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("localStorage.json")
        if let d = try? Data(contentsOf: url), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            if let it = o["items"] as? [String: String] { items = it }
            order = (o["order"] as? [String]) ?? Array(items.keys)
            order = order.filter { items[$0] != nil }
            for k in items.keys where !order.contains(k) { order.append(k) }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.flush() }
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in self?.flush() }
    }
    var length: Int { order.count }
    func key(_ i: Int) -> String? { i >= 0 && i < order.count ? order[i] : nil }
    func getItem(_ k: String) -> String? { items[k] }
    func setItem(_ k: String, _ v: String) {
        let b = items[k]
        if b == nil { order.append(k) }
        items[k] = v
        later()
        onChange?(k, b, v)
    }
    func removeItem(_ k: String) {
        guard let b = items[k] else { return }
        items[k] = nil; order.removeAll { $0 == k }
        later()
        onChange?(k, b, nil)
    }
    /// set without telling anyone (used while applying a save from the account)
    func setQuiet(_ k: String, _ v: String?) {
        if let v = v { if items[k] == nil { order.append(k) }; items[k] = v } else { items[k] = nil; order.removeAll { $0 == k } }
        later()
    }
    private func later() {
        pending?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flush() }
        pending = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: w)
    }
    func flush() {
        pending?.cancel(); pending = nil
        if let d = try? JSONSerialization.data(withJSONObject: ["items": items, "order": order]) { try? d.write(to: url, options: .atomic) }
    }
}
var localStorage: LocalStorage { LocalStorage.shared }
/// sessionStorage: only while the app is open
var sessionStore: [String: String] = [:]
