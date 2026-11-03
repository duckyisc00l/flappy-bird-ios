import SwiftUI

// v158: the Achievements page (the website's buildAchPage)

func achCount() -> Int { let got = lsList("fb_ach"); return ACH.filter { got.contains($0.id) }.count }
/// a gold trophy, or a lock (20 x 20 pixels)
func achIcon(_ on: Bool, _ secret: Bool) -> Img {
    let g = CGCanvas(20, 20); g.imageSmoothingEnabled = false
    func P(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: String) { g.fill(c); g.fillRect(x, y, w, h) }
    if !on {
        P(6, 3, 8, 2, "#8a8a9a"); P(5, 4, 2, 6, "#8a8a9a"); P(13, 4, 2, 6, "#8a8a9a"); P(3, 9, 14, 9, secret ? "#5a4a6a" : "#7a7a8a"); P(9, 12, 2, 3, "#2a2a34")
        return g.image()
    }
    P(4, 2, 12, 2, "#f8d040"); P(5, 4, 10, 6, "#f8b733"); P(6, 10, 8, 2, "#e09a20"); P(9, 12, 2, 3, "#c88a20"); P(6, 15, 8, 3, "#8a5a20")
    P(2, 4, 3, 2, "#f8b733"); P(15, 4, 3, 2, "#f8b733"); P(2, 6, 2, 2, "#f8b733"); P(16, 6, 2, 2, "#f8b733"); P(7, 5, 2, 3, "#fff2a0")
    return g.image()
}

struct AchievementsPage: View {
    @State private var tick = 0
    var body: some View {
        _ = tick
        let got = lsList("fb_ach"), n = ACH.filter { got.contains($0.id) }.count
        let d = lsNum("fb_lifeDeaths"), next = SCAR_AT.first { $0 > d }
        return VStack(spacing: 0) {
            Note(t: "\(n) of \(ACH.count) unlocked")
            HStack(spacing: 6) {
                stat("Crashes", lsNum("fb_lifeDeaths")); stat("Pipes", lsNum("fb_lifePipes")); stat("Rounds", lsNum("fb_lifeGames"))
            }.padding(.bottom, 8)
            ScrollView(showsIndicators: false) {   // v160: always scrolls inside the card (the long list spilled out of it)
                VStack(spacing: 0) {
                    Button {
                        scarsOn.toggle(); saveBool("scars", scarsOn); playSound("swoosh"); haptic(); tick += 1
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    KT("Battle scars", 8, K.orange)
                                    KT(next != nil ? "Your bird gets a new scar at \(next!) crashes" : "Your bird has seen it all", 6, spacing: 2).opacity(0.8)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Sw(on: scarsOn)
                            }.padding(.vertical, 7).padding(.horizontal, 9)
                            K.line2.frame(height: 1)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Button {   // v161
                        graveOn.toggle(); saveBool("graveyard", graveOn); playSound("swoosh"); haptic(); tick += 1
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    KT("Pipe graveyard", 8, K.orange)
                                    KT("The pipes that got you, as little gravestones on the ground", 6, spacing: 2).opacity(0.8)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Sw(on: graveOn)
                            }.padding(.vertical, 7).padding(.horizontal, 9)
                            K.line2.frame(height: 1)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    ForEach(Array(ACH.enumerated()), id: \.offset) { i, a in
                        let on = got.contains(a.id), hide = a.secret && !on
                        VStack(spacing: 0) {
                            HStack(spacing: 10) {
                                PixImage(img: achIcon(on, a.secret), w: 22, h: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    KT(hide ? "???" : a.name, 8, K.orange)
                                    KT(hide ? "Secret" : a.desc, 6, spacing: 2).opacity(0.8)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(.vertical, 5).padding(.horizontal, 9).opacity(on ? 1 : 0.6)
                            if i < ACH.count - 1 { K.line2.frame(height: 1) }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .background(RoundedRectangle(cornerRadius: 8).fill(K.light)).overlay(RoundedRectangle(cornerRadius: 8).stroke(K.brown, lineWidth: 2))
        }
    }
    private func stat(_ t: String, _ v: Int) -> some View {
        VStack(spacing: 3) { KT(String(v), 12); KT(t, 6, K.orange) }
            .frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(K.light)).overlay(RoundedRectangle(cornerRadius: 6).stroke(K.brown, lineWidth: 2))
    }
}
