import SwiftUI

// The website's menu look (picker95.css) as SwiftUI pieces: same colours, borders, fonts and sizes (CSS px = points).
enum K {
    static let brown = Color(hex: 0x533846), panel = Color(hex: 0xded895), light = Color(hex: 0xefeaa9), cream = Color(hex: 0xfff6c8), orange = Color(hex: 0xfc7858)
    static let orangeDark = Color(hex: 0xd85c40), line = Color(hex: 0xc4bd7a), line2 = Color(hex: 0xd8d18c), input = Color(hex: 0xfffbe0), green = Color(hex: 0x7fcf5a), greenDark = Color(hex: 0x5ca83a)
    static let sky = Color(hex: 0x4ec0ca), blue = Color(hex: 0x3cb0ff), blueDark = Color(hex: 0x2a88cc), red = Color(hex: 0xd84030), placeholder = Color(hex: 0xb0a87a), okGreen = Color(hex: 0x3f8a26)
    static func kong(_ s: CGFloat) -> Font { .custom("KongtextRegular", size: s) }
    static func b19(_ s: CGFloat) -> Font { .custom("04b19", size: s) }
}
extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: alpha) }
    init(css s: String) { let c = css(s); self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a) }
}
/// kongtext, uppercase (most of the menus)
struct KT: View {
    let t: String; var size: CGFloat = 8; var color: Color = K.brown; var shadow: Color? = nil; var upper = true; var align: TextAlignment = .leading; var lines: Int? = nil; var spacing: CGFloat = 0
    init(_ t: String, _ size: CGFloat = 8, _ color: Color = K.brown, shadow: Color? = nil, upper: Bool = true, align: TextAlignment = .leading, lines: Int? = nil, spacing: CGFloat = 0) {
        self.t = t; self.size = size; self.color = color; self.shadow = shadow; self.upper = upper; self.align = align; self.lines = lines; self.spacing = spacing
    }
    var body: some View {
        Text(upper ? t.uppercased() : t).font(K.kong(size)).foregroundColor(color).multilineTextAlignment(align).lineLimit(lines).lineSpacing(spacing)
            .shadow(color: shadow ?? .clear, radius: 0, x: 0, y: shadow == nil ? 0 : 2)
    }
}
/// the big white title with the brown pixel outline (04b19)
struct OutlinedTitle: View {
    let t: String; var size: CGFloat = 22; var color: Color = .white; var outline: CGFloat = 2; var drop: CGFloat = 4
    var body: some View {
        let txt = Text(t).font(K.b19(size)).foregroundColor(K.brown)
        ZStack {
            ForEach(0..<9, id: \.self) { i in
                let d: [(CGFloat, CGFloat)] = [(-outline, 0), (outline, 0), (0, -outline), (0, outline), (outline, outline), (-outline, outline), (outline, -outline), (-outline, -outline), (0, drop)]
                txt.offset(x: d[i].0, y: d[i].1)
            }
            Text(t).font(K.b19(size)).foregroundColor(color)
        }.fixedSize()
    }
}
/// pixel picture, sharp
struct PixImage: View {
    let img: Img?; var w: CGFloat; var h: CGFloat; var bg: Color? = nil; var radius: CGFloat = 0; var border: Color? = nil; var borderW: CGFloat = 2; var smooth = false
    var body: some View {
        ZStack {
            if let bg = bg { bg }
            if let im = img { Image(uiImage: im.ui).interpolation(smooth ? .high : .none).resizable().aspectRatio(contentMode: .fit) }
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(border ?? .clear, lineWidth: border == nil ? 0 : borderW))
    }
}
/// a bird drawn like drawSkinInto(canvas 48x40): centred, 1 picture pixel = 1 canvas pixel, flapping
func skinCanvas(_ id: String, _ f: Int, _ w: Int = 48, _ h: Int = 40) -> Img? {
    ensureSkin(id)
    guard let im = img(id + "_\(f)") else { return nil }
    let c = CGCanvas(w, h); c.imageSmoothingEnabled = false
    c.drawImage(im, jsRound(Double(w - im.width) / 2), jsRound(Double(h - im.height) / 2))
    return c.image()
}
struct BirdView: View {
    let id: String; var w: CGFloat = 54; var h: CGFloat = 45; var flap = true; var bg: Color? = nil; var radius: CGFloat = 0; var border: Color? = nil; var borderW: CGFloat = 2
    var body: some View {
        if flap {
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let n = Int(ctx.date.timeIntervalSinceReferenceDate * 10)
                PixImage(img: skinCanvas(id, [1, 2, 3, 2][n % 4]), w: w, h: h, bg: bg, radius: radius, border: border, borderW: borderW)
            }
        } else { PixImage(img: skinCanvas(id, 2), w: w, h: h, bg: bg, radius: radius, border: border, borderW: borderW) }
    }
}
/// the avatar canvas (a bird on its background colour)
struct Avatar: View {
    let av: String?; let bg: String?; var w: CGFloat = 32; var h: CGFloat = 27; var radius: CGFloat = 7; var border: CGFloat = 0
    var body: some View {
        PixImage(img: skinCanvas(skinExists(av ?? "") ? av! : "yellow", 2), w: w, h: h, bg: Color(css: avBg(bg)), radius: radius, border: border > 0 ? K.brown : nil, borderW: border)
    }
}

// MARK: buttons

/// .mk-btn and its colour classes
enum MkStyle { case plain, save, del, share, purple, card, safari, link }
struct MkBtn: View {
    let t: String; var style: MkStyle = .plain; var size: CGFloat = 7; var pad: CGFloat = 8; var full = true; var disabled = false; let act: () -> Void
    init(_ t: String, _ style: MkStyle = .plain, size: CGFloat = 7, pad: CGFloat = 8, full: Bool = true, disabled: Bool = false, act: @escaping () -> Void) {
        self.t = t; self.style = style; self.size = size; self.pad = pad; self.full = full; self.disabled = disabled; self.act = act
    }
    var body: some View {
        let (bg, sh, fg): (Color, Color, Color) = {
            switch style {
            case .plain: return (K.light, K.line2, K.brown)
            case .save: return (K.green, K.greenDark, .white)
            case .del: return (K.orange, K.orangeDark, .white)
            case .share: return (K.blue, K.blueDark, .white)
            case .purple: return (Color(hex: 0x9b6bd6), Color(hex: 0x7a4fb5), .white)
            case .card: return (Color(hex: 0x8a7ae0), Color(hex: 0x6a5ac0), .white)
            case .safari: return (Color(hex: 0x3b82f6), Color(hex: 0x2563eb), .white)
            case .link: return (.clear, .clear, K.brown)
            }
        }()
        Button(action: { if !disabled { act() } }) {
            Text(t.uppercased()).font(K.kong(size)).foregroundColor(fg).underline(style == .link)
                .shadow(color: style == .save ? Color(hex: 0x3f7a26) : .clear, radius: 0, x: 0, y: 1)
                .frame(maxWidth: full ? .infinity : nil).padding(.vertical, pad).padding(.horizontal, full ? 0 : 9)
                .padding(style == .link ? 0 : 2)
                .background(ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 9).fill(bg)
                    if style != .link { RoundedRectangle(cornerRadius: 9).fill(sh).frame(height: 3).mask(RoundedRectangle(cornerRadius: 9).padding(.top, -20)) }
                })
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(style == .link ? .clear : K.brown, lineWidth: 2))
                .opacity(disabled ? 0.6 : 1)
        }.buttonStyle(PressStyle())
    }
}
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 1, dy: CGFloat = 2
    func makeBody(configuration c: Configuration) -> some View { c.label.offset(y: c.isPressed ? dy : 0).scaleEffect(c.isPressed ? scale : 1) }
}
/// .pk-opt (round option chips)
struct Opt: View {
    let t: String; let on: Bool; var size: CGFloat = 7; var warn = false; var grow = false; let act: () -> Void
    var body: some View {
        Button(action: act) {
            Text(t.uppercased()).font(K.kong(size)).foregroundColor(on || warn ? .white : K.brown)
                .frame(maxWidth: grow ? .infinity : nil)
                .padding(.vertical, 6).padding(.horizontal, 8).padding(2)
                .background(Capsule().fill(warn ? K.red : on ? K.orange : K.light)).overlay(Capsule().strokeBorder(K.brown, lineWidth: 2))
        }.buttonStyle(PressStyle(scale: 0.95, dy: 0))
    }
}
/// a wrapping row (flex-wrap)
struct Flow: Layout {
    var spacing: CGFloat = 4, center = false
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 300; var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > w && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }; x += sz.width + spacing; rowH = max(rowH, sz.height) }
        return CGSize(width: w, height: y + rowH)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rows: [[(LayoutSubview, CGSize)]] = [[]]; var x: CGFloat = 0
        for s in subviews { let sz = s.sizeThatFits(.unspecified); if x + sz.width > b.width && x > 0 { rows.append([]); x = 0 }; rows[rows.count - 1].append((s, sz)); x += sz.width + spacing }
        var y = b.minY
        for r in rows {
            let rw = r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, r.count - 1)), rh = r.map { $0.1.height }.max() ?? 0
            var xx = center ? b.minX + (b.width - rw) / 2 : b.minX
            for (s, sz) in r { s.place(at: CGPoint(x: xx, y: y), proposal: ProposedViewSize(sz)); xx += sz.width + spacing }
            y += rh + spacing
        }
    }
}
/// .pk-note, .pk-sec, .mk-hint, .lb-ch-t, .lb-ch-s, .mk-msg
struct Note: View { let t: String; var center = false
    var body: some View { KT(t, 6, K.brown, align: center ? .center : .leading, spacing: 3).opacity(0.8).frame(maxWidth: .infinity, alignment: center ? .center : .leading).padding(.horizontal, 2).padding(.bottom, 7) } }
struct Sec: View { let t: String; var top: CGFloat = 0
    var body: some View { KT(t, 8, K.orange, shadow: K.cream).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 2).padding(.top, top + 2).padding(.bottom, 4) } }
struct Hint: View { let t: String
    var body: some View { KT(t, 6, K.brown, spacing: 3).opacity(0.75).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 2).padding(.top, 2).padding(.bottom, 5) } }
struct ChT: View { let t: String; var color: Color = K.orange; var size: CGFloat = 18
    var body: some View { Text(t).font(K.b19(size)).foregroundColor(color).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 4) } }
struct ChS: View { let t: String
    var body: some View { KT(t, 7, K.brown, align: .center, spacing: 3).frame(maxWidth: .infinity).padding(.bottom, 6) } }
struct Msg: View { let t: String; var ok = false
    var body: some View { KT(t, 7, ok ? K.okGreen : K.red, spacing: 4).frame(maxWidth: .infinity, minHeight: 12, alignment: .leading).padding(.horizontal, 2).padding(.bottom, 6) } }
/// .pk-search inputs
struct Field: View {
    let ph: String; @Binding var text: String; var secure = false; var size: CGFloat = 16; var center = false; var kerning: CGFloat = 0; var caps = false; var numeric = false; var content: UITextContentType? = nil; var submit: (() -> Void)? = nil
    var body: some View {
        ZStack(alignment: center ? .center : .leading) {
            if text.isEmpty { Text(ph).font(K.kong(10)).foregroundColor(K.placeholder) }
            Group {
                if secure { SecureField("", text: $text) } else { TextField("", text: $text) }
            }
            .font(K.kong(size)).kerning(kerning).foregroundColor(K.brown).multilineTextAlignment(center ? .center : .leading)
            .textInputAutocapitalization(caps ? .characters : .never).autocorrectionDisabled()
            .keyboardType(numeric ? .numberPad : .default)
            .textContentType(content)
            .onSubmit { submit?() }
        }
        .padding(.vertical, 5).padding(.horizontal, 9).padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(K.input)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(K.brown, lineWidth: 2))
        .padding(.bottom, 6)
    }
}
/// .mk-code text areas
struct CodeBox: View {
    @Binding var text: String; var readOnly = false; var ph = ""; var lines: CGFloat = 5; var size: CGFloat = 11
    var body: some View {
        ZStack(alignment: .topLeading) {
            if readOnly {
                ScrollView { Text(text).font(.system(size: size, design: .monospaced)).foregroundColor(K.brown).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
            } else {
                if text.isEmpty { Text(ph).font(.system(size: 16, design: .monospaced)).foregroundColor(K.placeholder).padding(.top, 8).padding(.leading, 4) }
                TextEditor(text: $text).font(.system(size: 16, design: .monospaced)).foregroundColor(K.brown).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
        }
        .padding(7).frame(height: lines * 15 + 14).padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(K.input)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(K.brown, lineWidth: 2))
        .padding(.bottom, 7)
    }
}
/// .st-sw switch
struct Sw: View { let on: Bool; var small = true
    var body: some View {
        let w: CGFloat = small ? 34 : 46, h: CGFloat = small ? 18 : 24, k: CGFloat = small ? 12 : 16
        ZStack(alignment: .leading) {
            Capsule().fill(on ? K.green : K.line)
            Circle().fill(Color(hex: 0xf0a050)).overlay(Circle().stroke(K.brown, lineWidth: 2)).frame(width: k, height: k).padding(.leading, on ? w - k - 5 : 1).padding(.top, 0)
        }
        .frame(width: w - 4, height: h - 4).padding(2).overlay(Capsule().stroke(K.brown, lineWidth: 2))
        .animation(.spring(response: 0.25, dampingFraction: 0.55), value: on)
    }
}
struct Arrow: View { var body: some View { Text("\u{203A}").font(.system(size: 22, weight: .bold)).foregroundColor(K.brown).padding(.trailing, 4) } }

/// the card every menu sits in (.pk-panel)
struct PanelCard<C: View>: View {
    let title: String; var back: (() -> Void)?; var compact = false; var fill = false; let close: () -> Void
    @ViewBuilder var content: C
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let b = back { HeadBtn(t: "\u{2039}", big: true, act: b) }
                OutlinedTitle(t: title, size: 22).frame(maxWidth: .infinity, alignment: .leading)
                HeadBtn(t: "\u{2715}", act: close)
            }.padding(.bottom, 7)
            if fill { content.frame(maxHeight: .infinity, alignment: .top) } else { content }
        }
        .padding(9).padding(3)
        .background(ZStack {
            RoundedRectangle(cornerRadius: 10).fill(K.panel)
            VStack { K.light.frame(height: 3); Spacer(); K.line.frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 10))
        })
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(K.brown, lineWidth: 3))
        .compositingGroup().shadow(color: .black.opacity(0.28), radius: 0, x: 0, y: 6)
    }
}
struct HeadBtn: View { let t: String; var big = false; let act: () -> Void
    var body: some View {
        Button(action: act) {
            Text(t).font(.system(size: big ? 22 : 15, weight: .bold)).foregroundColor(.white).padding(.bottom, big ? 3 : 0)
                .frame(width: 30, height: 30)
                .background(ZStack(alignment: .bottom) { RoundedRectangle(cornerRadius: 7).fill(K.orange); K.orangeDark.frame(height: 3) }.clipShape(RoundedRectangle(cornerRadius: 7)))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(K.brown, lineWidth: 2))
        }.buttonStyle(PressStyle())
    }
}
/// a tile border like .pk-cell / .fg-row
extension View {
    func tile(_ sel: Bool, radius: CGFloat = 7, border: CGFloat = 2, bg: Color = K.light) -> some View {
        // like CSS: the border takes its own space inside the box; the selected ring is a 1px box-shadow outside it
        self.padding(border).background(RoundedRectangle(cornerRadius: radius).fill(sel ? K.cream : bg))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(sel ? K.orange : K.line, lineWidth: border))
            .overlay(RoundedRectangle(cornerRadius: radius + 1).strokeBorder(sel ? K.orange : .clear, lineWidth: 1).padding(-1))
    }
}
