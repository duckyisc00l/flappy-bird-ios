import SpriteKit
import SwiftUI

/// The website's look: cream panels, dark brown outlines, orange highlights, the pixel fonts.
enum Px {
    static let cream = Color(red: 0.871, green: 0.847, blue: 0.584)
    static let light = Color(red: 0.937, green: 0.918, blue: 0.663)
    static let brown = Color(red: 0.325, green: 0.220, blue: 0.275)
    static let orange = Color(red: 0.988, green: 0.471, blue: 0.345)
    static let green = Color(red: 0.498, green: 0.812, blue: 0.353)
    static let sky = Color(red: 0.306, green: 0.753, blue: 0.792)
    static let line = Color(red: 0.77, green: 0.74, blue: 0.48)
    static func text(_ size: CGFloat) -> Font { .custom("KongtextRegular", size: size) }
    static func title(_ size: CGFloat) -> Font { .custom("04b19", size: size) }
    static func hex(_ v: UInt32) -> Color { Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) }
}

/// a chunky game button
struct PxButtonStyle: ButtonStyle {
    var fill: Color = Px.light, fg: Color = Px.brown, size: CGFloat = 12
    func makeBody(configuration c: Configuration) -> some View {
        c.label.font(Px.text(size)).foregroundColor(fg)
            .padding(.vertical, 12).padding(.horizontal, 14).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Px.brown, lineWidth: 3))
            .shadow(color: .black.opacity(c.isPressed ? 0 : 0.25), radius: 0, x: 0, y: c.isPressed ? 0 : 4)
            .offset(y: c.isPressed ? 3 : 0)
    }
}

/// a panel like the website's (title in the big pixel font, a close button)
struct Panel<Content: View>: View {
    let title: String
    var onClose: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(Px.title(30)).foregroundColor(.white).shadow(color: Px.brown, radius: 0, x: 2, y: 2)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundColor(.white).frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Px.orange)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Px.brown, lineWidth: 3)) }
            }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
            content
        }
        .background(Px.cream.ignoresSafeArea())
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Px.brown, lineWidth: 5).ignoresSafeArea())
    }
}

/// a row card inside panels
struct Card<Content: View>: View {
    var on = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color(red: 1, green: 0.965, blue: 0.784) : Px.light))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? Px.orange : Px.line, lineWidth: on ? 3 : 2))
    }
}

/// a pixel bird picture
struct BirdPic: View {
    let id: String
    var size: CGFloat = 48
    var bg: Color? = Px.sky
    var body: some View {
        ZStack {
            if let bg = bg { RoundedRectangle(cornerRadius: size * 0.18).fill(bg) }
            if id != "random", let im = Birds.shared.image(id, scale: 2) {
                Image(uiImage: im).interpolation(.none).resizable().aspectRatio(contentMode: .fit).padding(size * 0.1)
            }
        }.frame(width: size, height: size * 0.86)
    }
}

/// the game, drawn by SpriteKit
struct GameView: UIViewRepresentable {
    let scene: SKScene
    func makeUIView(context: Context) -> SKView {
        let v = SKView(); v.ignoresSiblingOrder = false; v.isMultipleTouchEnabled = false
        v.presentScene(scene); return v
    }
    func updateUIView(_ v: SKView, context: Context) {}
}
