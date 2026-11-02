import UIKit
import WidgetKit

// v156: feeds the Home Screen widget. Writes widget.json + bird.png into the shared App Group folder
// and asks iOS to redraw the widget. Nothing happens if the folder isn't there (e.g. installed without
// the App Group): the game doesn't need it.
private var widgetLast = ""
func widgetSync() {
    guard let url = WidgetShare.dataURL else { return }
    var d = WidgetData()
    d.best = Int(localStorage.getItem("fb_bestScore") ?? "0") ?? 0
    d.streak = Int(loadStr("dailyStreak", "0")) ?? 0
    d.streakLast = loadStr("dailyLast", "")
    if d.streakLast == dailyDate() {   // played today's Daily
        d.dailyDay = dailyDate()
        d.dailyScore = Int(localStorage.getItem("fb_bestScore_daily") ?? "0") ?? 0
    }
    let bid = pickedSkin() ?? birdColor
    d.birdName = skinName(bid)
    if flFresh(), let f = FLWX { d.weather = "\(f.temp)F, " + wmoText(f.code); d.place = f.name }
    d.season = WX.season
    guard let probe = try? JSONEncoder().encode(d) else { return }
    let key = String(decoding: probe, as: UTF8.self) + bid
    if key == widgetLast { return }   // nothing new to show
    widgetLast = key
    d.updated = nowMs()
    if let data = try? JSONEncoder().encode(d) { try? data.write(to: url, options: .atomic) }
    if let png = skinCanvas(bid, 2)?.ui.pngData(), let bu = WidgetShare.birdURL { try? png.write(to: bu, options: .atomic) }
    WidgetCenter.shared.reloadAllTimelines()
}
