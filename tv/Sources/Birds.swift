import SpriteKit
import UIKit

/// All 2,265 birds from the web game, exported as sprite sheets.
/// Each sheet: 16 birds per row, each bird = 3 frames of 42x40 pixels side by side.
struct BirdInfo {
    let id: String
    let name: String
    let category: String
    let sheet: Int
    let col: Int
    let row: Int
}

final class Birds {
    static let shared = Birds()

    private(set) var all: [BirdInfo] = []
    private(set) var categories: [String] = []
    private var byId: [String: BirdInfo] = [:]
    private var sheetTextures: [Int: SKTexture] = [:]
    private var sheetImages: [Int: CGImage] = [:]
    private var frameCache: [String: [SKTexture]] = [:]
    private var imageCache: [String: UIImage] = [:]
    private let cols = 16, cellW = 42, cellH = 40

    private init() {
        guard let url = Bundle.main.url(forResource: "birds", withExtension: "json", subdirectory: "birds"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skins = obj["skins"] as? [[Any]] else { return }
        var cats: [String] = []
        for s in skins {
            guard s.count >= 6, let id = s[0] as? String, let name = s[1] as? String, let cat = s[2] as? String,
                  let sh = s[3] as? Int, let c = s[4] as? Int, let r = s[5] as? Int else { continue }
            let b = BirdInfo(id: id, name: name, category: cat, sheet: sh, col: c, row: r)
            all.append(b); byId[id] = b
            if !cats.contains(cat) { cats.append(cat) }
        }
        // a friendly order: the classics first, then the rest as they come
        categories = (cats.contains("Classic") ? ["Classic"] : []) + cats.filter { $0 != "Classic" }
    }

    func info(_ id: String) -> BirdInfo? { byId[id] }

    func birds(in category: String?) -> [BirdInfo] {
        guard let c = category else { return all }
        return all.filter { $0.category == c }
    }

    private func sheetImage(_ i: Int) -> CGImage? {
        if let im = sheetImages[i] { return im }
        guard let url = Bundle.main.url(forResource: "birds\(i)", withExtension: "png", subdirectory: "birds"),
              let ui = UIImage(contentsOfFile: url.path), let cg = ui.cgImage else { return nil }
        sheetImages[i] = cg
        return cg
    }

    private func sheetTexture(_ i: Int) -> SKTexture? {
        if let t = sheetTextures[i] { return t }
        guard let cg = sheetImage(i) else { return nil }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        sheetTextures[i] = t
        return t
    }

    /// The 3 flapping frames of a bird (wings up, middle, down).
    func frames(_ id: String) -> [SKTexture] {
        if let f = frameCache[id] { return f }
        guard let b = byId[id] ?? byId["yellow"], let sheet = sheetTexture(b.sheet) else { return [] }
        let W = sheet.size().width, H = sheet.size().height
        var out: [SKTexture] = []
        for f in 0..<3 {
            let x = CGFloat(b.col * cellW * 3 + f * cellW), yTop = CGFloat(b.row * cellH)
            let rect = CGRect(x: x / W, y: 1 - (yTop + CGFloat(cellH)) / H, width: CGFloat(cellW) / W, height: CGFloat(cellH) / H)
            let t = SKTexture(rect: rect, in: sheet)
            t.filteringMode = .nearest
            out.append(t)
        }
        frameCache[id] = out
        return out
    }

    /// A picture of the bird for menus (crisp pixels, scaled up).
    func image(_ id: String, scale: CGFloat = 4) -> UIImage? {
        let key = "\(id)@\(scale)"
        if let im = imageCache[key] { return im }
        guard let b = byId[id] ?? byId["yellow"], let cg = sheetImage(b.sheet),
              let crop = cg.cropping(to: CGRect(x: b.col * cellW * 3, y: b.row * cellH, width: cellW, height: cellH)) else { return nil }
        let size = CGSize(width: CGFloat(cellW) * scale, height: CGFloat(cellH) * scale)
        let r = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let im = r.image { ctx in
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.translateBy(x: 0, y: size.height); ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.draw(crop, in: CGRect(origin: .zero, size: size))
        }
        imageCache[key] = im
        return im
    }

    func randomId() -> String { all.randomElement()?.id ?? "yellow" }
}
