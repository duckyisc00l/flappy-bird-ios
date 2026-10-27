import Foundation
import TVServices

/// Flappy Bird's Top Shelf: when the app is in the top row of the Apple TV Home screen and you hover it,
/// the whole TV plays a looping video of a bird flying through pipes, with three slides:
/// today's Daily Challenge (and who leads it), Play, and the Leaderboard (top 3). Their buttons open the app.
final class ContentProvider: TVTopShelfContentProvider {
    private let base = "https://umnmgkbzsfpockrorcqd.supabase.co/rest/v1/"
    private let key = "sb_publishable_Mtltj8MvHzXQyMHTWprIzg_DjOU2XJz"   // the publishable key (read-only for scores)
    private let video = URL(string: "https://duckyisc00l.github.io/flappy-bird/tv/topshelf.mp4")

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        let group = DispatchGroup()
        var daily: [(String, Int)] = [], normal: [(String, Int)] = []
        group.enter(); top("daily-" + dateKey()) { daily = $0; group.leave() }
        group.enter(); top("normal") { normal = $0; group.leave() }
        group.notify(queue: .main) {
            let d = self.item("daily", title: "Daily Challenge", context: "Today",
                              summary: daily.first.map { "Today's pipes are the same for everyone. Leader: \($0.0) with \($0.1). Can you beat it?" }
                                ?? "Today's pipes are the same for everyone. Nobody has played yet: be the first on the board!",
                              image: "shelf_daily", play: "flappytv://daily", attrs: daily.isEmpty ? [] : [("Leader", ["\(daily[0].0) \u{00B7} \(daily[0].1)"])])
            let p = self.item("play", title: "Flappy Bird", context: "Play",
                              summary: "Click the remote to flap through the pipes. 8 modes, 2,265 birds, 100 trails, party mode with phones as controllers.",
                              image: "shelf_play", play: "flappytv://play", attrs: normal.first.map { [("Top player", ["\($0.0) \u{00B7} \($0.1)"])] } ?? [])
            let lines = normal.prefix(3).enumerated().map { "\($0.offset + 1). \($0.element.0)  \($0.element.1)" }
            let b = self.item("leaderboard", title: "Leaderboard", context: "Online",
                              summary: lines.isEmpty ? "The best scores from phones, the website and Apple TVs." : lines.joined(separator: "     "),
                              image: "shelf_board", play: "flappytv://leaderboard", attrs: [])
            completionHandler(TVTopShelfCarouselContent(style: .actions, items: [d, p, b]))
        }
    }

    private func item(_ id: String, title: String, context: String, summary: String, image: String, play: String, attrs: [(String, [String])]) -> TVTopShelfCarouselItem {
        let it = TVTopShelfCarouselItem(identifier: id)
        it.title = title
        it.contextTitle = context
        it.summary = summary
        it.genre = "Arcade"
        it.previewVideoURL = video
        if let u = Bundle.main.url(forResource: image, withExtension: "jpg") { it.setImageURL(u, for: .screenScale1x); it.setImageURL(u, for: .screenScale2x) }
        if let u = URL(string: play) { it.playAction = TVTopShelfAction(url: u); it.displayAction = TVTopShelfAction(url: u) }
        it.namedAttributes = attrs.map { TVTopShelfNamedAttribute(name: $0.0, values: $0.1) }
        return it
    }

    /// the top scores of one board (one line per player)
    private func top(_ mode: String, done: @escaping ([(String, Int)]) -> Void) {
        guard let url = URL(string: base + "scores?select=name,score,user_id&mode=eq.\(mode)&user_id=not.is.null&order=score.desc,created_at.asc&limit=40") else { return done([]) }
        var r = URLRequest(url: url, timeoutInterval: 6); r.setValue(key, forHTTPHeaderField: "apikey")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            var out: [(String, Int)] = [], seen = Set<String>()
            if let data = data, let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for row in rows {
                    guard let uid = row["user_id"] as? String, !seen.contains(uid), let n = row["name"] as? String, let s = row["score"] as? Int else { continue }
                    seen.insert(uid); out.append((n, s))
                }
            }
            done(out)
        }.resume()
    }
    private func dateKey() -> String {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(identifier: "UTC"); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"; return f.string(from: Date())
    }
}
