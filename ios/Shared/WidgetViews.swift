import SwiftUI
import WidgetKit

// The Home Screen widget's look (shared, so the app's test run can draw it too): your bird, your best, your Daily streak and today's Daily (medium adds the live weather).
// It reads what the app wrote into the shared App Group folder (see WidgetShare.swift).

struct FlappyEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
    let bird: UIImage?
}

struct FlappyProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlappyEntry {
        var d = WidgetData(); d.best = 42; d.streak = 3; d.streakLast = WidgetShare.day(); d.dailyDay = WidgetShare.day(); d.dailyScore = 12
        return FlappyEntry(date: Date(), data: d, bird: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (FlappyEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<FlappyEntry>) -> Void) {
        // now, and again when the new Daily arrives (midnight UTC); the app also refreshes it after every game
        let now = Date(), next = WidgetShare.nextDaily(after: now)
        completion(Timeline(entries: [entry(now), entry(next.addingTimeInterval(5))], policy: .after(next.addingTimeInterval(3600))))
    }
    private func entry(_ d: Date) -> FlappyEntry {
        let img = WidgetShare.birdURL.flatMap { try? Data(contentsOf: $0) }.flatMap { UIImage(data: $0) }
        return FlappyEntry(date: d, data: WidgetShare.load(), bird: img)
    }
}

// the game's look
private enum WG {
    static let sky = Color(red: 0x4e / 255, green: 0xc0 / 255, blue: 0xca / 255)
    static let brown = Color(red: 0x53 / 255, green: 0x38 / 255, blue: 0x46 / 255)
    static let orange = Color(red: 0xfc / 255, green: 0x78 / 255, blue: 0x58 / 255)
    static let cream = Color(red: 0xde / 255, green: 0xd8 / 255, blue: 0x95 / 255)
    static let grass = Color(red: 0x73 / 255, green: 0xbf / 255, blue: 0x2e / 255)
    static let grassLight = Color(red: 0x9c / 255, green: 0xe6 / 255, blue: 0x59 / 255)
    static func kong(_ s: CGFloat) -> Font { .custom("KongtextRegular", size: s) }
    static func big(_ s: CGFloat) -> Font { .custom("04b19", size: s) }
}

/// white digits with the dark outline, like the score in the game
private struct WGOutlined: View {
    let t: String; let size: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                Text(t).font(WG.big(size)).foregroundColor(WG.brown).offset(x: cos(a) * 1.6, y: sin(a) * 1.6 + 0.6)
            }
            Text(t).font(WG.big(size)).foregroundColor(.white)
        }
    }
}

private struct WGGround: View {
    var body: some View {
        VStack(spacing: 0) {
            WG.brown.frame(height: 2)
            HStack(spacing: 0) { ForEach(0..<24, id: \.self) { i in (i % 2 == 0 ? WG.grass : WG.grassLight).frame(width: 7) } }.frame(height: 6).clipped()
            WG.brown.opacity(0.35).frame(height: 1)
            WG.cream
        }
    }
}

private struct WGSky: View {
    var body: some View { ZStack(alignment: .bottom) { WG.sky; WGGround().frame(height: 26) } }
}

private struct WGBirdPic: View {
    let img: UIImage?; let w: CGFloat
    var body: some View {
        Group {
            if let i = img { Image(uiImage: i).interpolation(.none).resizable().aspectRatio(contentMode: .fit) }
            else { Text("\u{1F426}").font(.system(size: w * 0.6)) }
        }.frame(width: w, height: w * 40 / 48)
    }
}

struct FlappyWidgetView: View {
    @Environment(\.widgetFamily) var envFamily
    let e: FlappyEntry
    var forced: WidgetFamily? = nil     // (the app's test run draws it outside a widget)
    private var family: WidgetFamily { forced ?? envFamily }

    private var today: String { WidgetShare.day(e.date) }
    private var streak: Int {
        guard let d = e.data else { return 0 }
        let y = WidgetShare.day(e.date.addingTimeInterval(-86400))
        return d.streakLast == today || d.streakLast == y ? d.streak : 0
    }
    private var dailyToday: Int? { e.data.flatMap { $0.dailyDay == today ? $0.dailyScore : nil } }
    private var hoursLeft: Int { max(1, Int(ceil(WidgetShare.nextDaily(after: e.date).timeIntervalSince(e.date) / 3600))) }

    var body: some View {
        let content = Group {
            if e.data == nil { empty } else if family == .systemSmall { small } else { medium }
        }
        .widgetURL(URL(string: "flappybird://daily"))
        if forced != nil {
            content.background(WGSky())
        } else if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { WGSky() }
        } else {
            content.background(WGSky())
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            WGBirdPic(img: nil, w: 40)
            Text("OPEN FLAPPY BIRD ONCE").font(WG.kong(7)).foregroundColor(WG.brown).multilineTextAlignment(.center)
            Spacer(minLength: 20)
        }.padding(.top, 10)
    }

    private var small: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                WGBirdPic(img: e.bird, w: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BEST").font(WG.kong(7)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                    WGOutlined(t: "\(e.data?.best ?? 0)", size: 22)
                }
            }
            HStack(spacing: 4) {
                Text("\u{1F525}").font(.system(size: 12))
                Text(streak == 1 ? "1 DAY" : "\(streak) DAYS").font(WG.kong(8)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
            }
            Text(dailyToday == nil ? "DAILY: PLAY!" : "DAILY: \(dailyToday!)").font(WG.kong(7))
                .foregroundColor(dailyToday == nil ? .white : WG.brown)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(dailyToday == nil ? WG.orange : WG.cream))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(WG.brown, lineWidth: 1.5))
            Spacer(minLength: 18)
        }.padding(.top, 8)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                WGBirdPic(img: e.bird, w: 56)
                Text("BEST").font(WG.kong(7)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                WGOutlined(t: "\(e.data?.best ?? 0)", size: 24)
            }.frame(width: 92)
            VStack(alignment: .leading, spacing: 5) {
                Text("TODAY'S DAILY").font(WG.kong(8)).foregroundColor(WG.orange)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(RoundedRectangle(cornerRadius: 4).fill(WG.cream))
                if let s = dailyToday {
                    Text("YOUR SCORE: \(s)").font(WG.kong(8)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                } else {
                    Text("NOT PLAYED YET").font(WG.kong(8)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                }
                Text("\u{1F525} " + (streak == 1 ? "1 DAY STREAK" : "\(streak) DAY STREAK")).font(WG.kong(7)).foregroundColor(.white).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                Text("NEW DAILY IN \(hoursLeft)H").font(WG.kong(6)).foregroundColor(.white.opacity(0.9)).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                if let w = e.data?.weather {
                    Text(w.uppercased()).font(WG.kong(6)).foregroundColor(.white.opacity(0.9)).lineLimit(1).shadow(color: WG.brown, radius: 0, x: 0, y: 1)
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }.padding(.top, 10).padding(.horizontal, 12).padding(.bottom, 26)
    }
}

