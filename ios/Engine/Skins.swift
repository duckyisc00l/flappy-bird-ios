import Foundation

// Birds: 2,265 from the website (sheets), plus your own from the Bird Maker (built here exactly like the website does).
let CLASSIC_SKINS = ["yellow", "red", "blue", "green", "peach", "purple", "kup"]
let CAT_ORDER = ["My Birds", "Classic", "Real Birds", "Animals", "Food & Drink", "Outfits & Jobs", "Sports & Music", "Fantasy", "Spooky", "Holidays", "Space",
                 "Nature & Weather", "Things", "Moods & Faces", "Cartoon", "Patterns & Colors", "Countries", "US States"]
let BASE_PAL: [String: String] = ["O": "#533846", "E": "#fafafa", "P": "#533846", "W": "#fafafa", "G": "#d7e6cc", "R": "#fc3800", "D": "#d32f00", "L": "#fc730f", "B": "#f8b733"]
let SKIN_PX = 4.0, SKIN_PY = 8.0
struct Cell { let x: Int, y: Int, t: String }
let SKIN_FRAMES: [[Cell]] = ((Assets.data["SKIN_FRAMES"] as? [[[String: Any]]]) ?? []).map { f in f.map { Cell(x: Int(num($0["x"]) ?? 0), y: Int(num($0["y"]) ?? 0), t: $0["t"] as? String ?? "O") } }
let MK_COLORS: [String] = (Assets.data["MK_COLORS"] as? [String]) ?? []
let MK_PARTS: [(String, String)] = [("R", "Body"), ("D", "Belly"), ("L", "Shine"), ("W", "Wing"), ("G", "Wing tip"), ("B", "Beak"), ("E", "Eye"), ("P", "Pupil"), ("O", "Outline")]

struct CustomBird { var id: String, name: String, pal: [String: String], px: [String: String] }
var customBirds: [CustomBird] = []
var birdPick = "random"
var favBirds: [String] = []
func saveFavs() { localStorage.setItem("fb_favBirds", jsonStr(favBirds)) }
func loadCustomBirdsList() {
    let arr = (try? JSONSerialization.jsonObject(with: Data((localStorage.getItem("fb_customBirds") ?? "[]").utf8))) as? [[String: Any]] ?? []
    customBirds = arr.compactMap { o in
        guard let id = o["id"] as? String else { return nil }
        return CustomBird(id: id, name: o["name"] as? String ?? "My bird", pal: o["pal"] as? [String: String] ?? [:], px: o["px"] as? [String: String] ?? [:])
    }
}
@discardableResult func saveCustomBirds() -> Bool {
    localStorage.setItem("fb_customBirds", jsonStr(customBirds.map { ["id": $0.id, "name": $0.name, "pal": $0.pal, "px": $0.px] as [String: Any] }))
    return true
}
private var customIds: [String] = []
private var customBuilt: Set<String> = []   // in the order they were registered (like Object.keys(EXTRA_SKINS))
func registerCustom(_ cb: CustomBird) {
    if !customIds.contains(cb.id) { customIds.append(cb.id) }
    customBuilt.remove(cb.id)
    for n in 1...3 { Assets.drop(cb.id + "_\(n)") }
}
func unregisterCustom(_ id: String) { customIds.removeAll { $0 == id }; customBuilt.remove(id); for n in 1...3 { Assets.drop(id + "_\(n)") } }
func prepareSkins() { loadCustomBirdsList(); for cb in customBirds { registerCustom(cb) } }
func extraSkinIds() -> [String] { Birds2.all.map { $0.id }.filter { !CLASSIC_SKINS.contains($0) } + customIds }
func skinExists(_ id: String) -> Bool { CLASSIC_SKINS.contains(id) || Birds2.byId[id] != nil || customIds.contains(id) }
func customBird(_ id: String) -> CustomBird? { customBirds.first { $0.id == id } }
func skinName(_ id: String) -> String {
    if let c = customBird(id) { return c.name }
    if let b = Birds2.byId[id] { return b.name }
    return id.replacingOccurrences(of: "_", with: " ").capitalized
}
func skinCat(_ id: String) -> String {
    if id.hasPrefix("custom_") { return "My Birds" }
    if CLASSIC_SKINS.contains(id) { return "Classic" }
    return Birds2.byId[id]?.cat ?? "Patterns & Colors"
}
func allSkins() -> [String] { customIds + Birds2.all.map { $0.id } }
func pickedSkin() -> String? {
    if birdPick == "favs" { let f = favBirds.filter(skinExists); return f.isEmpty ? nil : f[Int(floor(mrand() * Double(f.count)))] }
    if birdPick != "random" && skinExists(birdPick) { return birdPick }
    return nil
}
/// your own birds' frames are drawn the first time they're used (the website's buildSkin2)
func ensureSkin(_ id: String) {
    guard let cb = customBird(id), !customBuilt.contains(id) else { return }
    for n in 1...3 { Assets.put(id + "_\(n)", buildCustomFrame(n - 1, pal: cb.pal, px: cb.px)) }
    customBuilt.insert(id)
}
func buildCustomFrame(_ f: Int, pal: [String: String], px: [String: String]) -> Img {
    let c = CGCanvas(Int(34 + SKIN_PX * 2), Int(24 + SKIN_PY * 2))
    let ox = SKIN_PX / 2, oy = SKIN_PY / 2
    var P = BASE_PAL; for (k, v) in pal { P[k] = v }; P["S"] = nil
    func put(_ x: Int, _ y: Int, _ col: String) { c.fill(col); c.fillRect((Double(x) + ox) * 2, (Double(y) + oy) * 2, 2, 2) }
    for cell in (f < SKIN_FRAMES.count ? SKIN_FRAMES[f] : []) {
        let col = cell.t == "S" ? (P["S"] ?? P["G"]!) : (P[cell.t] ?? P["O"]!)
        put(cell.x, cell.y, col)
    }
    for (k, col) in px { let p = k.split(separator: ","); if p.count == 2, let x = Int(p[0]), let y = Int(p[1]) { put(x, y, col) } }
    return c.image()
}

// ---------- Share / import a bird as a code ----------
let BIRD_CODE = "FLAPPYBIRD1:"
func birdToCode(_ cb: CustomBird) -> String {
    var pal: [String: String] = [:]
    for (k, v) in cb.pal where v != BASE_PAL[k] { pal[k] = v.replacingOccurrences(of: "#", with: "") }
    // (the website keeps the order you drew in; here the pixels are sorted, which decodes the same)
    let px = cb.px.keys.sorted().map { $0 + ":" + cb.px[$0]!.replacingOccurrences(of: "#", with: "") }.joined(separator: ";")
    let json = jsonStr(["n": cb.name, "p": pal, "x": px] as [String: Any])
    var b = Data(json.utf8).base64EncodedString()
    while b.hasSuffix("=") { b.removeLast() }
    return BIRD_CODE + b
}
struct CodeError: Error { let message: String }
func birdFromCode(_ text: String) throws -> (name: String, pal: [String: String], px: [String: String]) {
    guard let i = text.uppercased().range(of: BIRD_CODE) else { throw CodeError(message: "Not a bird code") }
    let rest = String(text[i.upperBound...])
    func tryDecode(_ raw: String) -> [String: Any]? {
        var b = raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/").filter { $0.isLetter && $0.isASCII || $0.isNumber && $0.isASCII || $0 == "+" || $0 == "/" }
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
    let compact = rest.filter { !$0.isWhitespace }
    var o = tryDecode(String(rest.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0.isWhitespace }).first ?? "")) ?? tryDecode(compact)
    if o == nil, let r = compact.range(of: "^[A-Za-z0-9+/=_-]+", options: .regularExpression) { o = tryDecode(String(compact[r])) }
    guard let obj = o else { throw CodeError(message: "The code is broken or cut off") }
    func hex(_ c: String) -> String? { c.range(of: "^[0-9a-fA-F]{6}$", options: .regularExpression) != nil ? "#" + c.lowercased() : nil }
    var pal = BASE_PAL
    for (k, v) in obj["p"] as? [String: Any] ?? [:] { if BASE_PAL[k] != nil, let s = v as? String, let h = hex(s) { pal[k] = h } }
    var px: [String: String] = [:]
    for part in String(describing: obj["x"] ?? "").split(separator: ";") {
        let s = String(part)
        guard let m = s.range(of: "^(-?\\d+),(-?\\d+):([0-9a-fA-F]{6})$", options: .regularExpression), m.lowerBound == s.startIndex else { continue }
        let a = s.split(separator: ":"), xy = a[0].split(separator: ",")
        guard let x = Int(xy[0]), let y = Int(xy[1]), x >= -2, x <= 18, y >= -4, y <= 15 else { continue }
        px["\(x),\(y)"] = "#" + a[1].lowercased()
    }
    var name = String((obj["n"] as? String ?? "Imported bird").unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0x7e }.map(Character.init)).prefix(16).description
    if name.isEmpty { name = "Imported bird" }
    return (name, pal, px)
}
func birdChanged() { if !bird.dynamic && !isGameOver && !isShowingGameOver { updateBirdTextures() } }
