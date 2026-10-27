import UIKit

/// The online leaderboard (read only): the same Supabase project as the phone app and the website.
/// Only the publishable key is here, which is meant to be inside apps; the database only lets it read scores.
enum Online {
    static let url = "https://umnmgkbzsfpockrorcqd.supabase.co"
    static let key = "sb_publishable_Mtltj8MvHzXQyMHTWprIzg_DjOU2XJz"

    struct Row { let name: String; let score: Int; let bird: String; let userId: String; let avatar: String?; let avatarBg: String? }

    static func leaderboard(mode: String, week: Bool, done: @escaping (Result<[Row], Error>) -> Void) {
        var q = "scores?select=name,score,bird,user_id,created_at,profiles(avatar,avatar_bg)&mode=eq.\(Daily.scoreMode(mode))&user_id=not.is.null&order=score.desc,created_at.asc&limit=400"
        if week {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q += "&created_at=gte." + f.string(from: Date().addingTimeInterval(-7 * 86400))
        }
        guard let u = URL(string: url + "/rest/v1/" + q) else { return }
        var req = URLRequest(url: u, timeoutInterval: 10)
        req.setValue(key, forHTTPHeaderField: "apikey")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let result: Result<[Row], Error>
            if let err = err { result = .failure(err) }
            else if let data = data, let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var seen = Set<String>(), rows: [Row] = []
                for r in arr {   // one line per player: their best
                    guard let uid = r["user_id"] as? String, !seen.contains(uid) else { continue }
                    seen.insert(uid)
                    let p = r["profiles"] as? [String: Any]
                    rows.append(Row(name: r["name"] as? String ?? "?", score: r["score"] as? Int ?? 0, bird: r["bird"] as? String ?? "yellow",
                                    userId: uid, avatar: p?["avatar"] as? String, avatarBg: p?["avatar_bg"] as? String))
                }
                result = .success(rows)
            } else { result = .failure(NSError(domain: "board", code: (resp as? HTTPURLResponse)?.statusCode ?? 0)) }
            DispatchQueue.main.async { done(result) }
        }.resume()
    }

    /// profile picture background colours (same as the web game)
    static func color(_ k: String?) -> UIColor {
        let hex: [String: UInt32] = ["sky": 0x4ec0ca, "night": 0x26345e, "sunset": 0xfc7858, "grass": 0x7fcf5a, "gold": 0xf5c542,
                                     "pink": 0xf49ac2, "purple": 0x9b6bd6, "mint": 0x7fe0c0, "snow": 0xeef2f6, "coal": 0x4a4048]
        let v = hex[k ?? "sky"] ?? 0x4ec0ca
        return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}
