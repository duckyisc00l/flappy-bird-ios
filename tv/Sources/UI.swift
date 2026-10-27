import UIKit

/// Colours from the game, plus fonts. Menus use Apple's system font like other Apple TV apps;
/// the pixel fonts stay inside the game itself.
enum Look {
    static let cream = UIColor(red: 0.871, green: 0.847, blue: 0.584, alpha: 1)      // #ded895
    static let light = UIColor(red: 0.937, green: 0.918, blue: 0.663, alpha: 1)      // #efeaa9
    static let brown = UIColor(red: 0.325, green: 0.220, blue: 0.275, alpha: 1)      // #533846
    static let orange = UIColor(red: 0.988, green: 0.471, blue: 0.345, alpha: 1)     // #fc7858
    static let green = UIColor(red: 0.498, green: 0.812, blue: 0.353, alpha: 1)      // #7fcf5a
    static let sky = UIColor(red: 0.306, green: 0.753, blue: 0.792, alpha: 1)        // #4ec0ca
    static let dim = UIColor(white: 1, alpha: 0.6)
    static func pixel(_ size: CGFloat) -> UIFont { UIFont(name: "KongtextRegular", size: size) ?? .systemFont(ofSize: size, weight: .heavy) }
    static func title(_ size: CGFloat) -> UIFont { UIFont(name: "04b19", size: size) ?? .systemFont(ofSize: size, weight: .black) }
    static func font(_ size: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: size, weight: w) }
    static func rgb(_ v: UInt32) -> UIColor { UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1) }
}

/// A standard Apple TV button: it turns white, lifts and tilts under your thumb like Apple's own.
final class TVButton: UIButton {
    var onSelect: (() -> Void)?
    static func make(_ title: String) -> TVButton {
        let b = TVButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = Look.font(36, .medium)
        b.addTarget(b, action: #selector(tapped), for: .primaryActionTriggered)
        return b
    }
    @objc private func tapped() { onSelect?() }
}

/// Every menu screen: the game stays behind a frosted-glass blur, with a big title like Apple's apps.
class PanelController: UIViewController {
    let panel = UIView()
    let heading = UILabel()
    let content = UIView()

    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        modalPresentationStyle = .blurOverFullScreen
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        heading.font = Look.font(66, .bold); heading.textColor = .white
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(heading); panel.addSubview(content)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: g.leadingAnchor), panel.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            panel.topAnchor.constraint(equalTo: g.topAnchor), panel.bottomAnchor.constraint(equalTo: g.bottomAnchor),
            heading.topAnchor.constraint(equalTo: panel.topAnchor), heading.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            content.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 30), content.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor), content.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])
    }

    /// a standard Apple TV table (rows turn white and lift when focused)
    func makeTable(rowHeight: CGFloat) -> UITableView {
        let t = UITableView(frame: .zero, style: .plain)
        t.backgroundColor = .clear; t.rowHeight = rowHeight; t.remembersLastFocusedIndexPath = true
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }
    static func cell(_ t: UITableView, _ style: UITableViewCell.CellStyle, _ id: String) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: id) ?? UITableViewCell(style: style, reuseIdentifier: id)
        c.textLabel?.font = Look.font(36, .medium); c.detailTextLabel?.font = Look.font(27)
        c.detailTextLabel?.numberOfLines = 2
        return c
    }
}

// MARK: - pictures for cards (made here from the game's pixel art)

enum Cards {
    static func render(_ size: CGSize, radius: CGFloat = 14, _ draw: (CGContext, CGRect) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            let r = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: r, cornerRadius: radius).addClip()
            ctx.cgContext.interpolationQuality = .none
            draw(ctx.cgContext, r)
        }
    }
    static func gradient(_ g: CGContext, _ r: CGRect, _ a: UIColor, _ b: UIColor) {
        let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [a.cgColor, b.cgColor] as CFArray, locations: [0, 1])!
        g.drawLinearGradient(gr, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: r.height), options: [])
    }
    static func symbol(_ name: String, _ size: CGFloat, at c: CGPoint, color: UIColor = .white) {
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .bold)
        guard let s = UIImage(systemName: name, withConfiguration: cfg)?.withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        s.draw(in: CGRect(x: c.x - s.size.width / 2, y: c.y - s.size.height / 2, width: s.size.width, height: s.size.height))
    }
    /// a pixel bird, scaled by a whole number so its pixels stay square
    static func bird(_ id: String, height: CGFloat, at c: CGPoint, flip: Bool = false) {
        guard let im = Birds.shared.image(id, scale: 1) else { return }
        let k = max(1, (height / im.size.height).rounded()), w = im.size.width * k, h = im.size.height * k
        let r = CGRect(x: (c.x - w / 2).rounded(), y: (c.y - h / 2).rounded(), width: w, height: h)
        if flip, let g = UIGraphicsGetCurrentContext() { g.saveGState(); g.translateBy(x: r.midX, y: 0); g.scaleBy(x: -1, y: 1); g.translateBy(x: -r.midX, y: 0); im.draw(in: r); g.restoreGState() }
        else { im.draw(in: r) }
    }
    /// sky, a green hill and the ground stripe, like the game
    static func scenery(_ g: CGContext, _ r: CGRect) {
        gradient(g, r, Look.rgb(0x4ec0ca), Look.rgb(0x9fe3e8))
        Look.rgb(0x5ee270).setFill(); g.fill(CGRect(x: 0, y: r.height * 0.72, width: r.width, height: r.height))
        Look.rgb(0xe8fcd9).setFill(); g.fill(CGRect(x: 0, y: r.height * 0.70, width: r.width, height: 4))
        Look.rgb(0x73bf2e).setFill(); g.fill(CGRect(x: 0, y: r.height * 0.86, width: r.width, height: r.height))
        Look.rgb(0xded895).setFill(); g.fill(CGRect(x: 0, y: r.height * 0.93, width: r.width, height: r.height))
    }
    private static var cache: [String: UIImage] = [:]
    /// a bird / trail tile for the pickers: a coloured card with the pixel art in the middle
    static func tile(key: String, size: CGSize, bg: UIColor, picked: Bool, _ draw: @escaping (CGRect) -> Void) -> UIImage {
        let k = key + (picked ? "+" : "") + "\(size)"
        if let im = cache[k] { return im }
        let im = render(size) { g, r in
            gradient(g, r, bg, bg.withAlphaComponent(0.75))
            draw(r)
            if picked { symbol("checkmark.circle.fill", 30, at: CGPoint(x: r.maxX - 26, y: 26)) }
        }
        cache[k] = im
        return im
    }
}

/// A picture card that lifts and tilts when focused (Apple's own effect), with its name underneath.
final class CardCell: UICollectionViewCell {
    let pic = UIImageView(), label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        pic.adjustsImageWhenAncestorFocused = true
        pic.translatesAutoresizingMaskIntoConstraints = false
        label.font = Look.font(24, .medium); label.textColor = Look.dim; label.textAlignment = .center; label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pic); contentView.addSubview(label)
        NSLayoutConstraint.activate([
            pic.topAnchor.constraint(equalTo: contentView.topAnchor), pic.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pic.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), pic.heightAnchor.constraint(equalTo: pic.widthAnchor, multiplier: 0.7),
            label.topAnchor.constraint(equalTo: pic.focusedFrameGuide.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -16), label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 16),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({ self.label.textColor = self.isFocused ? .white : Look.dim; self.label.font = Look.font(24, self.isFocused ? .bold : .medium) })
    }
}

// MARK: - Modes

final class ModesController: PanelController, UITableViewDataSource, UITableViewDelegate {
    var onDone: (() -> Void)?
    private lazy var table = makeTable(rowHeight: 116)

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Mode"
        table.dataSource = self; table.delegate = self
        content.addSubview(table)
        NSLayoutConstraint.activate([table.topAnchor.constraint(equalTo: content.topAnchor), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                                     table.centerXAnchor.constraint(equalTo: content.centerXAnchor), table.widthAnchor.constraint(equalToConstant: 1200)])
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [table] }
    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? { IndexPath(row: Modes.all.firstIndex { $0.id == Prefs.mode } ?? 0, section: 0) }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { Modes.all.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = Self.cell(t, .subtitle, "m"), m = Modes.all[ip.row], b = Prefs.best(m.id)
        c.textLabel?.text = m.title
        c.detailTextLabel?.text = m.desc + (b > 0 ? "   Best: \(b)" : "")
        c.accessoryType = m.id == Prefs.mode ? .checkmark : .none
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        Prefs.mode = Modes.all[ip.row].id
        onDone?(); dismiss(animated: true)
    }
}

// MARK: - Birds

final class BirdsController: PanelController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    var onDone: (() -> Void)?
    private lazy var cats = makeTable(rowHeight: 70)
    private var grid: UICollectionView!
    private var shown: [BirdInfo] = []
    private var catIndex = 0
    private let pickedName = UILabel()
    private var categoryNames: [String] { ["All Birds"] + Birds.shared.categories }

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Birds"
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 200, height: 200); layout.minimumInteritemSpacing = 40; layout.minimumLineSpacing = 60
        layout.sectionInset = UIEdgeInsets(top: 30, left: 40, bottom: 60, right: 40)
        grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
        grid.backgroundColor = .clear; grid.dataSource = self; grid.delegate = self; grid.remembersLastFocusedIndexPath = true; grid.clipsToBounds = false
        grid.register(CardCell.self, forCellWithReuseIdentifier: "b")
        cats.dataSource = self; cats.delegate = self
        pickedName.font = Look.font(30); pickedName.textColor = Look.dim; pickedName.textAlignment = .right
        for v in [cats, grid!, pickedName] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            cats.leadingAnchor.constraint(equalTo: content.leadingAnchor), cats.topAnchor.constraint(equalTo: content.topAnchor),
            cats.bottomAnchor.constraint(equalTo: content.bottomAnchor), cats.widthAnchor.constraint(equalToConstant: 470),
            grid.leadingAnchor.constraint(equalTo: cats.trailingAnchor, constant: 40), grid.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grid.topAnchor.constraint(equalTo: content.topAnchor), grid.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            pickedName.trailingAnchor.constraint(equalTo: panel.trailingAnchor), pickedName.lastBaselineAnchor.constraint(equalTo: heading.lastBaselineAnchor),
        ])
        updatePicked()
        load(0)
    }
    private func updatePicked() {
        let id = Prefs.bird
        pickedName.text = "Now: " + (id == "random" ? "Random" : (Birds.shared.info(id)?.name ?? "Random"))
    }
    private func load(_ i: Int) {
        catIndex = i
        shown = i == 0 ? Birds.shared.all : Birds.shared.birds(in: categoryNames[i])
        grid.reloadData()
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [grid] }

    // categories
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { categoryNames.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = Self.cell(t, .value1, "c")
        let n = ip.row == 0 ? Birds.shared.all.count : Birds.shared.birds(in: categoryNames[ip.row]).count
        c.textLabel?.text = categoryNames[ip.row]; c.textLabel?.font = Look.font(28, ip.row == catIndex ? .bold : .regular)
        c.textLabel?.adjustsFontSizeToFitWidth = true; c.textLabel?.minimumScaleFactor = 0.7
        c.detailTextLabel?.text = "\(n)"; c.detailTextLabel?.font = Look.font(24)
        return c
    }
    func tableView(_ t: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let ip = context.nextFocusedIndexPath, ip.row != catIndex { load(ip.row); restyle(t) }
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) { load(ip.row); restyle(t); setNeedsFocusUpdate() }
    private func restyle(_ t: UITableView) { for c in t.visibleCells { if let ip = t.indexPath(for: c) { c.textLabel?.font = Look.font(28, ip.row == catIndex ? .bold : .regular) } } }

    // birds (the first card of "All Birds" is Random)
    private var offset: Int { catIndex == 0 ? 1 : 0 }
    func collectionView(_ c: UICollectionView, numberOfItemsInSection s: Int) -> Int { shown.count + offset }
    func collectionView(_ c: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = c.dequeueReusableCell(withReuseIdentifier: "b", for: ip) as! CardCell
        let size = CGSize(width: 200, height: 140)
        if ip.item < offset {
            cell.pic.image = Cards.tile(key: "random", size: size, bg: Look.rgb(0x9b6bd6), picked: Prefs.bird == "random") { r in Cards.symbol("shuffle", 54, at: CGPoint(x: r.midX, y: r.midY)) }
            cell.label.text = "Random"
        } else {
            let b = shown[ip.item - offset]
            cell.pic.image = Cards.tile(key: "b:" + b.id, size: size, bg: Look.sky, picked: Prefs.bird == b.id) { r in Cards.bird(b.id, height: 100, at: CGPoint(x: r.midX, y: r.midY)) }
            cell.label.text = b.name
        }
        return cell
    }
    func collectionView(_ c: UICollectionView, didSelectItemAt ip: IndexPath) {
        Prefs.bird = ip.item < offset ? "random" : shown[ip.item - offset].id
        onDone?(); dismiss(animated: true)
    }
}

// MARK: - Leaderboard (the same online board as the phone and the website)

final class LeaderboardController: PanelController, UITableViewDataSource {
    private let modes = UISegmentedControl(items: Modes.all.map { $0.title })
    private let when = UISegmentedControl(items: ["All Time", "This Week"])
    private lazy var table = makeTable(rowHeight: 100)
    private let note = UILabel()
    private var rows: [Online.Row] = []
    private var mode = Prefs.mode

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Leaderboard"
        modes.selectedSegmentIndex = Modes.all.firstIndex { $0.id == mode } ?? 0
        when.selectedSegmentIndex = 0
        for s in [modes, when] { s.addTarget(self, action: #selector(changed), for: .valueChanged) }
        table.dataSource = self
        table.register(ScoreRow.self, forCellReuseIdentifier: "r")
        note.font = Look.font(32); note.textColor = Look.dim; note.textAlignment = .center; note.numberOfLines = 0
        for v in [modes, when, table, note] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            modes.topAnchor.constraint(equalTo: content.topAnchor), modes.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            modes.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor),
            when.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 24), when.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            table.topAnchor.constraint(equalTo: when.bottomAnchor, constant: 30), table.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            table.widthAnchor.constraint(equalToConstant: 1100), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            note.centerXAnchor.constraint(equalTo: table.centerXAnchor), note.centerYAnchor.constraint(equalTo: table.centerYAnchor),
            note.widthAnchor.constraint(equalTo: table.widthAnchor),
        ])
        fetch()
    }
    @objc private func changed() { mode = Modes.all[modes.selectedSegmentIndex].id; fetch() }
    private func fetch() {
        note.text = "Loading..."; rows = []; table.reloadData()
        let m = mode, week = when.selectedSegmentIndex == 1
        Online.leaderboard(mode: m, week: week) { [weak self] result in
            guard let s = self, s.mode == m else { return }
            switch result {
            case .success(let r): s.rows = Array(r.prefix(50)); s.note.text = r.isEmpty ? "No scores yet. Be the first!" : ""
            case .failure: s.note.text = "Couldn't reach the leaderboard. Check the internet."
            }
            s.table.reloadData()
        }
    }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { rows.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "r", for: ip) as! ScoreRow
        c.set(rank: ip.row + 1, row: rows[ip.row])
        return c
    }
}

final class ScoreRow: UITableViewCell {
    private let rank = UILabel(), pic = UIImageView(), name = UILabel(), score = UILabel()
    private var mine = false
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        rank.font = Look.font(30, .bold); rank.textAlignment = .center
        name.font = Look.font(34, .medium)
        score.font = UIFont.monospacedDigitSystemFont(ofSize: 40, weight: .bold); score.textAlignment = .right
        pic.layer.magnificationFilter = .nearest; pic.layer.cornerRadius = 12; pic.clipsToBounds = true
        for v in [rank, pic, name, score] { v.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(v) }
        NSLayoutConstraint.activate([
            rank.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14), rank.widthAnchor.constraint(equalToConstant: 80),
            rank.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pic.leadingAnchor.constraint(equalTo: rank.trailingAnchor, constant: 10), pic.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pic.widthAnchor.constraint(equalToConstant: 84), pic.heightAnchor.constraint(equalToConstant: 70),
            name.leadingAnchor.constraint(equalTo: pic.trailingAnchor, constant: 26), name.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            score.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30), score.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: score.leadingAnchor, constant: -20),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(rank r: Int, row: Online.Row) {
        mine = Account.shared.signedIn && row.userId == Account.shared.userId
        rank.text = r == 1 ? "1st" : r == 2 ? "2nd" : r == 3 ? "3rd" : "\(r)"
        name.text = row.name + (mine ? "  (you)" : ""); score.text = "\(row.score)"
        pic.image = Birds.shared.image(row.avatar ?? row.bird, scale: 2)
        pic.backgroundColor = Online.color(row.avatarBg)
        recolor(isFocused)
    }
    private func recolor(_ f: Bool) {
        name.textColor = f ? .black : .white; score.textColor = f ? .black : .white
        rank.textColor = f ? .black : (mine ? Look.orange : Look.rgb(0xf5c542))
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({ self.recolor(self.isFocused) })
    }
}

// MARK: - Settings: sound, trail, season

final class SettingsController: PanelController, UITableViewDataSource, UITableViewDelegate {
    var onDone: (() -> Void)?
    private lazy var table = makeTable(rowHeight: 100)
    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Settings"
        table.dataSource = self; table.delegate = self; content.addSubview(table)
        NSLayoutConstraint.activate([table.topAnchor.constraint(equalTo: content.topAnchor), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                                     table.centerXAnchor.constraint(equalTo: content.centerXAnchor), table.widthAnchor.constraint(equalToConstant: 1100)])
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); table.reloadData() }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { 3 }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = Self.cell(t, .value1, "s")
        switch ip.row {
        case 0: c.textLabel?.text = "Sound"; c.detailTextLabel?.text = Prefs.sound ? "On" : "Off"; c.accessoryType = .none
        case 1: c.textLabel?.text = "Trail"; c.detailTextLabel?.text = Trails.shared.def(Prefs.trail)?.name ?? "None"; c.accessoryType = .disclosureIndicator
        default: c.textLabel?.text = "Season"; c.detailTextLabel?.text = Seasons.title(Prefs.season); c.accessoryType = .disclosureIndicator
        }
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        switch ip.row {
        case 0: Prefs.sound.toggle(); t.reloadRows(at: [ip], with: .none); onDone?()
        case 1: let c = TrailsController(); c.onDone = { [weak self] in self?.table.reloadData(); self?.onDone?() }; present(c, animated: true)
        default: let c = SeasonsController(); c.onDone = { [weak self] in self?.table.reloadData(); self?.onDone?() }; present(c, animated: true)
        }
    }
}

final class SeasonsController: PanelController, UITableViewDataSource, UITableViewDelegate {
    var onDone: (() -> Void)?
    private lazy var table = makeTable(rowHeight: 96)
    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Season"
        table.dataSource = self; table.delegate = self; content.addSubview(table)
        NSLayoutConstraint.activate([table.topAnchor.constraint(equalTo: content.topAnchor), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                                     table.centerXAnchor.constraint(equalTo: content.centerXAnchor), table.widthAnchor.constraint(equalToConstant: 1100)])
    }
    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? { IndexPath(row: Seasons.all.firstIndex { $0.id == Prefs.season } ?? 0, section: 0) }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { Seasons.all.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = Self.cell(t, .subtitle, "s"), s = Seasons.all[ip.row]
        c.textLabel?.text = s.title
        c.detailTextLabel?.text = s.id == "auto" ? "Right now: " + Seasons.title(Seasons.byDate()) : nil
        c.accessoryType = s.id == Prefs.season ? .checkmark : .none
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) { Prefs.season = Seasons.all[ip.row].id; onDone?(); dismiss(animated: true) }
}

final class TrailsController: PanelController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    var onDone: (() -> Void)?
    private lazy var cats = makeTable(rowHeight: 70)
    private var grid: UICollectionView!
    private var catIndex = 0
    private var names: [String] { ["All Trails"] + Trails.shared.categories }
    private var shown: [TrailDef] { catIndex == 0 ? Trails.shared.all : Trails.shared.all.filter { $0.cat == names[catIndex] } }
    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Trails"
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 220, height: 210); layout.minimumInteritemSpacing = 40; layout.minimumLineSpacing = 60
        layout.sectionInset = UIEdgeInsets(top: 30, left: 40, bottom: 60, right: 40)
        grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
        grid.backgroundColor = .clear; grid.dataSource = self; grid.delegate = self; grid.clipsToBounds = false
        grid.register(CardCell.self, forCellWithReuseIdentifier: "t")
        cats.dataSource = self; cats.delegate = self
        for v in [cats, grid!] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            cats.leadingAnchor.constraint(equalTo: content.leadingAnchor), cats.topAnchor.constraint(equalTo: content.topAnchor),
            cats.bottomAnchor.constraint(equalTo: content.bottomAnchor), cats.widthAnchor.constraint(equalToConstant: 420),
            grid.leadingAnchor.constraint(equalTo: cats.trailingAnchor, constant: 40), grid.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grid.topAnchor.constraint(equalTo: content.topAnchor), grid.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [grid] }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { names.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = Self.cell(t, .default, "c")
        c.textLabel?.text = names[ip.row]; c.textLabel?.font = Look.font(28, ip.row == catIndex ? .bold : .regular); c.textLabel?.adjustsFontSizeToFitWidth = true
        return c
    }
    func tableView(_ t: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let ip = context.nextFocusedIndexPath, ip.row != catIndex {
            catIndex = ip.row; grid.reloadData()
            for c in t.visibleCells { if let i = t.indexPath(for: c) { c.textLabel?.font = Look.font(28, i.row == catIndex ? .bold : .regular) } }
        }
    }
    private var offset: Int { catIndex == 0 ? 1 : 0 }
    func collectionView(_ c: UICollectionView, numberOfItemsInSection s: Int) -> Int { shown.count + offset }
    func collectionView(_ c: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = c.dequeueReusableCell(withReuseIdentifier: "t", for: ip) as! CardCell
        let size = CGSize(width: 220, height: 154)
        if ip.item < offset {
            cell.pic.image = Cards.tile(key: "trail:none", size: size, bg: Look.rgb(0x3a3f4a), picked: Prefs.trail == "none") { r in Cards.symbol("nosign", 50, at: CGPoint(x: r.midX, y: r.midY)) }
            cell.label.text = "None"
        } else {
            let t = shown[ip.item - offset]
            cell.pic.image = Cards.tile(key: "trail:" + t.id, size: size, bg: Look.rgb(0x26345e), picked: Prefs.trail == t.id) { r in
                if let icon = Trails.shared.icon(t) { icon.draw(in: CGRect(x: r.midX - 70, y: r.midY - 50, width: 140, height: 100)) }
            }
            cell.label.text = t.name
        }
        return cell
    }
    func collectionView(_ c: UICollectionView, didSelectItemAt ip: IndexPath) {
        Prefs.trail = ip.item < offset ? "none" : shown[ip.item - offset].id
        onDone?(); dismiss(animated: true)
    }
}
