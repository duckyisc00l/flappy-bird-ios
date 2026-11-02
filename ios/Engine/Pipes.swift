import Foundation
import CoreLocation
import UIKit

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

// ---------- Auto weather = the live weather (where you are, or Daytona Beach) ----------
// Open-Meteo (free, no key), refreshed every 10 minutes. The first time you tap play the app asks for your location
// (rounded to about 1 km, only used for the weather); say no and it plays Daytona Beach's weather.
// "Weather from" on the Weather page switches between the two. If nothing can be reached, Auto falls back to the
// old random weather for the season.
let FL_PLACE = (name: "Daytona Beach, FL", lat: 29.2108, lon: -81.0228)
struct FLData: Codable { var w: String; var code: Int; var temp: Int; var wind: Int; var day: Bool; var t: Double; var lat: Double; var lon: Double; var name: String; var here: Bool }
struct HereData: Codable { var lat: Double; var lon: Double; var name: String; var t: Double }
var wxFrom = "daytona"   // "daytona" | "here"
var HERE: HereData? = {
    guard let s = localStorage.getItem("fb_wxHere") else { return nil }
    return try? JSONDecoder().decode(HereData.self, from: Data(s.utf8))
}()
var FLWX: FLData? = {
    guard let s = localStorage.getItem("fb_wxLive"), let o = try? JSONDecoder().decode(FLData.self, from: Data(s.utf8)), !o.w.isEmpty else { return nil }
    return o
}()
var hereMsg = ""
struct WxPlace { let name: String, lat: Double, lon: Double, here: Bool }
func wxPlace() -> WxPlace {
    if wxFrom == "here", let h = HERE { return WxPlace(name: h.name, lat: h.lat, lon: h.lon, here: true) }
    return WxPlace(name: FL_PLACE.name, lat: FL_PLACE.lat, lon: FL_PLACE.lon, here: false)
}
func samePlace(_ f: FLData, _ p: WxPlace) -> Bool { abs(f.lat - p.lat) < 0.05 && abs(f.lon - p.lon) < 0.05 }
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
func flFresh() -> Bool { if let f = FLWX { return nowMs() - f.t < 3 * 3600 * 1000 && samePlace(f, wxPlace()) }; return false }
private var flBusy = false
func fetchFlorida() {
    if flBusy { return }; flBusy = true
    let pl = wxPlace()
    let u = "https://api.open-meteo.com/v1/forecast?latitude=" + String(format: "%.2f", pl.lat) + "&longitude=" + String(format: "%.2f", pl.lon) +
        "&current=temperature_2m,weather_code,wind_speed_10m,wind_gusts_10m,is_day&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto"
    var rq = URLRequest(url: URL(string: u)!); rq.cachePolicy = .reloadIgnoringLocalCacheData; rq.timeoutInterval = 15
    URLSession.shared.dataTask(with: rq) { d, r, _ in
        DispatchQueue.main.async {
            flBusy = false
            guard let d = d, (r as? HTTPURLResponse)?.statusCode == 200, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let c = j["current"] as? [String: Any], let code = (c["weather_code"] as? NSNumber)?.intValue else { return }
            let wind = (c["wind_speed_10m"] as? NSNumber)?.doubleValue ?? 0, gust = (c["wind_gusts_10m"] as? NSNumber)?.doubleValue ?? 0
            let temp = (c["temperature_2m"] as? NSNumber)?.doubleValue ?? 0
            let f = FLData(w: wmoToWx(code, wind, gust), code: code, temp: Int(jsRound(temp)), wind: Int(jsRound(wind)), day: (c["is_day"] as? NSNumber)?.intValue == 1,
                           t: nowMs(), lat: pl.lat, lon: pl.lon, name: pl.name, here: pl.here)
            FLWX = f
            if let s = try? JSONEncoder().encode(f) { localStorage.setItem("fb_wxLive", String(decoding: s, as: UTF8.self)) }
            if weatherPick == "auto" && WX.weather != f.w { WX.weather = f.w; WX.seeded = false }
            UIBridge.shared.refresh()
        }
    }.resume()
}
func floridaLine() -> String {
    if !hereMsg.isEmpty { return hereMsg }
    let pl = wxPlace()
    let whereTxt = pl.here ? (pl.name.isEmpty || pl.name == "your location" ? "where you are" : "where you are (" + pl.name + ")") : "in " + pl.name
    guard let f = FLWX, samePlace(f, pl) else { return "Auto weather follows the live weather " + whereTxt + ". Checking..." }
    let ago = Int(jsRound((nowMs() - f.t) / 60000))
    return "Live " + whereTxt + ": \(f.temp)F, " + wmoText(f.code) + (f.wind >= 15 ? ", wind \(f.wind) mph" : "") +
        (ago >= 15 ? " (" + (ago < 120 ? "\(ago) min" : "\(Int(jsRound(Double(ago) / 60))) h") + " ago)" : "") + ". Auto weather plays it."
}
/// Auto weather uses the live weather when it's fresh (called at the end of rollWeather)
func floridaOverride() { if weatherPick == "auto" && flFresh(), let f = FLWX { WX.weather = f.w } }
private var flTimer: Timer?
func startFlorida() {
    wxFrom = loadStr("wxFrom", "daytona")
    _ = WXLoc.shared   // (if you already allowed it: refreshes where you are)
    fetchFlorida()
    flTimer?.invalidate()
    flTimer = Timer.scheduledTimer(withTimeInterval: 10 * 60, repeats: true) { _ in if appActive { fetchFlorida() } }
}
/// the app came back: refresh where you are and the weather if it's more than 10 minutes old
func floridaWake() {
    if wxFrom == "here" && WXLoc.shared.allowed { WXLoc.shared.locate() }
    else if FLWX == nil || nowMs() - FLWX!.t > 10 * 60 * 1000 || !flFresh() { fetchFlorida() }
}
/// the first time you tap play: ask for your location (once)
func wxAskOnce() {
    if ProcessInfo.processInfo.arguments.contains("-shots") { return }   // (the build's screenshot run)
    if loadBool("wxAsked", false) { return }
    saveBool("wxAsked", true)
    WXLoc.shared.ask()
}
/// "My location" on the Weather page
func wxUseHere() {
    let L = WXLoc.shared
    if L.status == .denied || L.status == .restricted {
        hereMsg = "Location is off for Flappy Bird. Turn it on in Settings, then come back."
        wxFrom = "daytona"; saveStr("wxFrom", "daytona")
        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { hereMsg = ""; UIBridge.shared.refresh() }
        UIBridge.shared.refresh(); return
    }
    wxFrom = "here"; saveStr("wxFrom", "here")
    hereMsg = HERE == nil ? "Finding you..." : ""
    L.ask(); UIBridge.shared.refresh(); fetchFlorida()
}
func wxUseDaytona() { wxFrom = "daytona"; saveStr("wxFrom", "daytona"); hereMsg = ""; UIBridge.shared.refresh(); fetchFlorida() }

final class WXLoc: NSObject, CLLocationManagerDelegate {
    static let shared = WXLoc()
    private let m = CLLocationManager()
    private var asked = false
    private let geo = CLGeocoder()
    override init() {
        super.init()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    var status: CLAuthorizationStatus { m.authorizationStatus }
    var allowed: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    func ask() {
        if status == .notDetermined { asked = true; m.requestWhenInUseAuthorization() }
        else if allowed { if asked || wxFrom == "here" { locate() } }
    }
    func locate() { m.requestLocation() }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if allowed {
            if asked { wxFrom = "here"; saveStr("wxFrom", "here") }   // you just said yes
            if wxFrom == "here" { locate() }
        } else if status == .denied || status == .restricted {
            if wxFrom == "here" || asked { wxFrom = "daytona"; saveStr("wxFrom", "daytona"); hereMsg = ""; fetchFlorida() }
        }
        if status != .notDetermined { asked = false }
        UIBridge.shared.refresh()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        let lat = (l.coordinate.latitude * 100).rounded() / 100, lon = (l.coordinate.longitude * 100).rounded() / 100
        let moved = HERE == nil || abs(HERE!.lat - lat) > 0.05 || abs(HERE!.lon - lon) > 0.05
        HERE = HereData(lat: lat, lon: lon, name: moved ? "your location" : HERE!.name, t: nowMs()); saveHere()
        hereMsg = ""
        fetchFlorida(); UIBridge.shared.refresh()
        if moved || HERE!.name == "your location" {
            // the town's name, worked out on the phone by Apple (from the rounded spot)
            geo.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)) { marks, _ in
                DispatchQueue.main.async {
                    guard let p = marks?.first, var h = HERE else { return }
                    let town = p.locality ?? p.subAdministrativeArea ?? p.name ?? ""
                    let st = p.administrativeArea ?? ""
                    if !town.isEmpty { h.name = st.isEmpty ? town : town + ", " + st; HERE = h; saveHere()
                        if var f = FLWX, f.here { f.name = h.name; FLWX = f }
                        UIBridge.shared.refresh() }
                }
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if HERE == nil && wxFrom == "here" { hereMsg = "Couldn't find you right now. Using Daytona Beach until it can."; DispatchQueue.main.asyncAfter(deadline: .now() + 5) { hereMsg = ""; UIBridge.shared.refresh() } }
        else { hereMsg = "" }
        fetchFlorida(); UIBridge.shared.refresh()
    }
    private func saveHere() { if let h = HERE, let s = try? JSONEncoder().encode(h) { localStorage.setItem("fb_wxHere", String(decoding: s, as: UTF8.self)) } }
}
