import Foundation

// ===================== v150: seasonal pipes + live Florida weather (the website's t_zzzzpipes.js) =====================
// Every season has its own pipes (pixel art, same shape as the classic pipe so all the decorations still fit).
// Pick them on the Weather page: Auto follows the season, or choose any set.
let PIPE_SETS: [(String, String, String)] = [("auto", "AUTO", "Auto (by season)"), ("classic", "CLASSIC", "Classic"), ("halloween", "SPOOKY", "Spooky"),
    ("christmas", "CANDY", "Candy cane"), ("winter", "ICE", "Ice"), ("spring", "BLOSSOM", "Blossom"), ("summer", "BAMBOO", "Bamboo"), ("fall", "BARK", "Bark"),
    ("valentine", "HEARTS", "Hearts"), ("newyear", "MIDNIGHT", "Midnight")]
private let PIPE_ART: Set<String> = ["halloween", "christmas", "winter", "spring", "summer", "fall", "valentine", "newyear"]
var pipePick = "auto"
/// the set the game draws right now ("classic" during the ending, haunted mode and the -1 run)
var pipeSkin = "classic"
func pipeSetFor(_ season: String) -> String { PIPE_ART.contains(season) ? season : "classic" }
func pipeSet() -> String { pipePick == "auto" ? pipeSetFor(WX.season) : pipePick }
func applyPipes() {
    var set = "classic"
    if weatherOn() { set = pipeSet() }
    if set != "classic" && Assets.img("pipe_\(set)_up") == nil { set = "classic" }
    pipeSkin = set
}
/// img["pipe_up"] / img["pipe_down"] follow the chosen set (the red and gold pipes have their own pictures)
func themedImg(_ k: String) -> Img? {
    if pipeSkin != "classic" && (k == "pipe_up" || k == "pipe_down") {
        return Assets.img("pipe_" + pipeSkin + (k == "pipe_up" ? "_up" : "_down")) ?? Assets.img(k)
    }
    return Assets.img(k)
}

// ---------- Auto weather = the weather in Florida right now ----------
// Open-Meteo (free, no key). Orlando, in the middle of the state. Refreshed every 10 minutes; if it can't be
// reached, Auto falls back to the old random weather for the season.
let FL_PLACE = (name: "Orlando, FL", lat: 28.5384, lon: -81.3789)
struct FLData: Codable { var w: String; var code: Int; var temp: Int; var wind: Int; var day: Bool; var t: Double }
var FLWX: FLData? = {
    guard let s = localStorage.getItem("fb_flwx"), let o = try? JSONDecoder().decode(FLData.self, from: Data(s.utf8)), !o.w.isEmpty else { return nil }
    return o
}()
func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }
func wmoToWx(_ code: Int, _ wind: Double, _ gust: Double) -> String {
    if [95, 96, 99].contains(code) { return "storm" }
    if (71...77).contains(code) || code == 85 || code == 86 { return "snow" }
    if (51...67).contains(code) || (80...82).contains(code) { return "rain" }
    if code == 45 || code == 48 { return "fog" }
    if wind >= 20 || gust >= 32 { return "windy" }
    return "clear"
}
func wmoText(_ code: Int) -> String {
    let T: [Int: String] = [0: "clear sky", 1: "mostly clear", 2: "partly cloudy", 3: "cloudy", 45: "fog", 48: "freezing fog", 51: "light drizzle", 53: "drizzle", 55: "heavy drizzle",
        56: "freezing drizzle", 57: "freezing drizzle", 61: "light rain", 63: "rain", 65: "heavy rain", 66: "freezing rain", 67: "freezing rain", 71: "light snow",
        73: "snow", 75: "heavy snow", 77: "snow grains", 80: "rain showers", 81: "rain showers", 82: "heavy showers", 85: "snow showers", 86: "snow showers",
        95: "thunderstorm", 96: "thunderstorm with hail", 99: "thunderstorm with hail"]
    return T[code] ?? "weather"
}
func flFresh() -> Bool { if let f = FLWX { return nowMs() - f.t < 3 * 3600 * 1000 }; return false }
private var flBusy = false
func fetchFlorida() {
    if flBusy { return }; flBusy = true
    let u = "https://api.open-meteo.com/v1/forecast?latitude=\(FL_PLACE.lat)&longitude=\(FL_PLACE.lon)" +
        "&current=temperature_2m,weather_code,wind_speed_10m,wind_gusts_10m,is_day&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=America%2FNew_York"
    var rq = URLRequest(url: URL(string: u)!); rq.cachePolicy = .reloadIgnoringLocalCacheData; rq.timeoutInterval = 15
    URLSession.shared.dataTask(with: rq) { d, r, _ in
        DispatchQueue.main.async {
            flBusy = false
            guard let d = d, (r as? HTTPURLResponse)?.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let c = j["current"] as? [String: Any], let code = (c["weather_code"] as? NSNumber)?.intValue else { return }
            let wind = (c["wind_speed_10m"] as? NSNumber)?.doubleValue ?? 0, gust = (c["wind_gusts_10m"] as? NSNumber)?.doubleValue ?? 0
            let temp = (c["temperature_2m"] as? NSNumber)?.doubleValue ?? 0
            let f = FLData(w: wmoToWx(code, wind, gust), code: code, temp: Int(jsRound(temp)), wind: Int(jsRound(wind)), day: (c["is_day"] as? NSNumber)?.intValue == 1, t: nowMs())
            FLWX = f
            if let s = try? JSONEncoder().encode(f) { localStorage.setItem("fb_flwx", String(decoding: s, as: UTF8.self)) }
            if weatherPick == "auto" && WX.weather != f.w { WX.weather = f.w; WX.seeded = false }
            UIBridge.shared.refresh()
        }
    }.resume()
}
func floridaLine() -> String {
    guard let f = FLWX else { return "Auto weather follows the live weather in " + FL_PLACE.name + ". Checking..." }
    let ago = Int(jsRound((nowMs() - f.t) / 60000))
    return "Live in " + FL_PLACE.name + ": \(f.temp)F, " + wmoText(f.code) + (f.wind >= 15 ? ", wind \(f.wind) mph" : "") +
        (ago >= 15 ? " (" + (ago < 120 ? "\(ago) min" : "\(Int(jsRound(Double(ago) / 60))) h") + " ago)" : "") + ". Auto weather plays it."
}
/// Auto weather uses Florida's when it's fresh (called at the end of rollWeather)
func floridaOverride() { if weatherPick == "auto" && flFresh(), let f = FLWX { WX.weather = f.w } }
private var flTimer: Timer?
func startFlorida() {
    fetchFlorida()
    flTimer?.invalidate()
    flTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { _ in if appActive { fetchFlorida() } }
}
/// the app came back: refresh if the data is more than 10 minutes old
func floridaWake() { if FLWX == nil || nowMs() - FLWX!.t > 10 * 60 * 1000 { fetchFlorida() } }
