import UIKit

/// The game's look for Apple TV menus: cream panels, dark brown outlines, the pixel font.
enum Look {
    static let cream = UIColor(red: 0.871, green: 0.847, blue: 0.584, alpha: 1)      // #ded895
    static let light = UIColor(red: 0.937, green: 0.918, blue: 0.663, alpha: 1)      // #efeaa9
    static let brown = UIColor(red: 0.325, green: 0.220, blue: 0.275, alpha: 1)      // #533846
    static let orange = UIColor(red: 0.988, green: 0.471, blue: 0.345, alpha: 1)     // #fc7858
    static let green = UIColor(red: 0.498, green: 0.812, blue: 0.353, alpha: 1)      // #7fcf5a
    static func pixel(_ size: CGFloat) -> UIFont { UIFont(name: "KongtextRegular", size: size) ?? .systemFont(ofSize: size, weight: .heavy) }
    static func title(_ size: CGFloat) -> UIFont { UIFont(name: "04b19", size: size) ?? .systemFont(ofSize: size, weight: .black) }
}

/// A big focusable button in the game's style. Grows and turns orange when the remote is on it.
final class PixelButton: UIButton {
    var onSelect: (() -> Void)?
    private let base: UIColor

    init(_ title: String, color: UIColor = Look.light) {
        base = color
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = Look.pixel(26)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        setTitleColor(Look.brown, for: .normal)
        setTitleColor(.white, for: .focused)
        backgroundColor = color
        layer.cornerRadius = 22
        layer.borderWidth = 6
        layer.borderColor = Look.brown.cgColor
        contentEdgeInsets = UIEdgeInsets(top: 22, left: 34, bottom: 22, right: 34)
        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onSelect?() }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            let f = self.isFocused
            self.transform = f ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            self.backgroundColor = f ? Look.orange : self.base
            self.layer.shadowColor = UIColor.black.cgColor
            self.layer.shadowOpacity = f ? 0.45 : 0
            self.layer.shadowRadius = 18; self.layer.shadowOffset = CGSize(width: 0, height: 12)
        })
    }
}

/// A cream card with a title, used by every menu screen.
class PanelController: UIViewController {
    let panel = UIView()
    let heading = UILabel()
    let content = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        panel.backgroundColor = Look.cream
        panel.layer.cornerRadius = 36; panel.layer.borderWidth = 10; panel.layer.borderColor = Look.brown.cgColor
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        heading.font = Look.title(64); heading.textColor = .white
        heading.layer.shadowColor = Look.brown.cgColor; heading.layer.shadowOpacity = 1; heading.layer.shadowRadius = 0; heading.layer.shadowOffset = CGSize(width: 4, height: 4)
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(heading); panel.addSubview(content)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor), panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            panel.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.86), panel.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.84),
            heading.topAnchor.constraint(equalTo: panel.topAnchor, constant: 34), heading.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 50),
            content.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 24), content.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 40),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -40), content.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -34),
        ])
    }
}

// MARK: - Modes

final class ModesController: PanelController, UITableViewDataSource, UITableViewDelegate {
    var onDone: (() -> Void)?
    private let table = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Modes"
        table.dataSource = self; table.delegate = self; table.backgroundColor = .clear; table.remembersLastFocusedIndexPath = true
        table.register(ModeCell.self, forCellReuseIdentifier: "m"); table.rowHeight = 112
        table.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(table)
        NSLayoutConstraint.activate([table.topAnchor.constraint(equalTo: content.topAnchor), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                                     table.leadingAnchor.constraint(equalTo: content.leadingAnchor), table.trailingAnchor.constraint(equalTo: content.trailingAnchor)])
    }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { [table] }
    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? { IndexPath(row: Modes.all.firstIndex { $0.id == Prefs.mode } ?? 0, section: 0) }
    func tableView(_ t: UITableView, numberOfRowsInSection s: Int) -> Int { Modes.all.count }
    func tableView(_ t: UITableView, cellForRowAt ip: IndexPath) -> UITableViewCell {
        let c = t.dequeueReusableCell(withIdentifier: "m", for: ip) as! ModeCell
        let m = Modes.all[ip.row]
        c.set(m, on: m.id == Prefs.mode, best: Prefs.best(m.id))
        return c
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) {
        Prefs.mode = Modes.all[ip.row].id
        onDone?(); dismiss(animated: true)
    }
}

final class ModeCell: UITableViewCell {
    private let name = UILabel(), desc = UILabel(), best = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let box = UIView(); box.backgroundColor = Look.light; box.layer.cornerRadius = 16; box.layer.borderWidth = 4; box.layer.borderColor = Look.brown.cgColor
        backgroundView = box
        let sel = UIView(); sel.backgroundColor = Look.orange; sel.layer.cornerRadius = 16; sel.layer.borderWidth = 4; sel.layer.borderColor = Look.brown.cgColor
        selectedBackgroundView = sel
        name.font = Look.pixel(26); desc.font = Look.pixel(16); best.font = Look.pixel(22)
        for l in [name, desc, best] { l.textColor = Look.brown; l.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(l) }
        desc.numberOfLines = 2; best.textAlignment = .right
        NSLayoutConstraint.activate([
            name.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28), name.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            desc.leadingAnchor.constraint(equalTo: name.leadingAnchor), desc.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 10),
            desc.trailingAnchor.constraint(equalTo: best.leadingAnchor, constant: -20),
            best.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28), best.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            best.widthAnchor.constraint(equalToConstant: 220),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(_ m: GameMode, on: Bool, best b: Int) {
        name.text = (on ? "\u{2713} " : "") + m.title.uppercased(); desc.text = m.desc.uppercased(); best.text = b > 0 ? "BEST \(b)" : ""
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            let f = self.isFocused
            (self.backgroundView)?.backgroundColor = f ? Look.orange : Look.light
            for l in [self.name, self.desc, self.best] { l.textColor = f ? .white : Look.brown }
            self.transform = f ? CGAffineTransform(scaleX: 1.02, y: 1.02) : .identity
        })
    }
}

// MARK: - Birds

final class BirdsController: PanelController, UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    var onDone: (() -> Void)?
    private let cats = UITableView(frame: .zero, style: .plain)
    private var grid: UICollectionView!
    private var shown: [BirdInfo] = []
    private var catIndex = 0
    private let preview = UIImageView(), pickedName = UILabel()
    private var categoryNames: [String] { ["All birds"] + Birds.shared.categories }

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Birds"
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 170, height: 190); layout.minimumInteritemSpacing = 22; layout.minimumLineSpacing = 34
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)
        grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
        grid.backgroundColor = .clear; grid.dataSource = self; grid.delegate = self; grid.remembersLastFocusedIndexPath = true
        grid.register(BirdCell.self, forCellWithReuseIdentifier: "b")
        cats.dataSource = self; cats.delegate = self; cats.backgroundColor = .clear; cats.rowHeight = 66; cats.remembersLastFocusedIndexPath = true
        cats.register(UITableViewCell.self, forCellReuseIdentifier: "c")
        pickedName.font = Look.pixel(20); pickedName.textColor = Look.brown; pickedName.textAlignment = .right
        for v in [cats, grid!, pickedName] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            cats.leadingAnchor.constraint(equalTo: content.leadingAnchor), cats.topAnchor.constraint(equalTo: content.topAnchor),
            cats.bottomAnchor.constraint(equalTo: content.bottomAnchor), cats.widthAnchor.constraint(equalToConstant: 420),
            grid.leadingAnchor.constraint(equalTo: cats.trailingAnchor, constant: 24), grid.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            grid.topAnchor.constraint(equalTo: content.topAnchor), grid.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            pickedName.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -50), pickedName.centerYAnchor.constraint(equalTo: heading.centerYAnchor),
            pickedName.leadingAnchor.constraint(equalTo: heading.trailingAnchor, constant: 30),
        ])
        updatePicked()
        load(0)
    }
    private func updatePicked() {
        let id = Prefs.bird
        pickedName.text = "NOW: " + (id == "random" ? "RANDOM" : (Birds.shared.info(id)?.name.uppercased() ?? "RANDOM"))
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
        let c = t.dequeueReusableCell(withIdentifier: "c", for: ip)
        let n = ip.row == 0 ? Birds.shared.all.count : Birds.shared.birds(in: categoryNames[ip.row]).count
        c.textLabel?.text = categoryNames[ip.row].uppercased() + "  \(n)"
        c.textLabel?.font = Look.pixel(18); c.textLabel?.textColor = ip.row == catIndex ? Look.orange : Look.brown
        c.backgroundColor = .clear
        return c
    }
    func tableView(_ t: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        if let ip = context.nextFocusedIndexPath, ip.row != catIndex { load(ip.row); t.reloadData() }
    }
    func tableView(_ t: UITableView, didSelectRowAt ip: IndexPath) { load(ip.row); t.reloadData(); setNeedsFocusUpdate() }

    // birds (the first cell of "All birds" is Random)
    private var offset: Int { catIndex == 0 ? 1 : 0 }
    func collectionView(_ c: UICollectionView, numberOfItemsInSection s: Int) -> Int { shown.count + offset }
    func collectionView(_ c: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = c.dequeueReusableCell(withReuseIdentifier: "b", for: ip) as! BirdCell
        if ip.item < offset { cell.set(image: nil, name: "RANDOM", on: Prefs.bird == "random") }
        else { let b = shown[ip.item - offset]; cell.set(image: Birds.shared.image(b.id), name: b.name, on: Prefs.bird == b.id) }
        return cell
    }
    func collectionView(_ c: UICollectionView, didSelectItemAt ip: IndexPath) {
        Prefs.bird = ip.item < offset ? "random" : shown[ip.item - offset].id
        onDone?(); dismiss(animated: true)
    }
}

final class BirdCell: UICollectionViewCell {
    private let pic = UIImageView(), label = UILabel(), box = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        box.backgroundColor = UIColor(red: 0.306, green: 0.753, blue: 0.792, alpha: 1)
        box.layer.cornerRadius = 18; box.layer.borderWidth = 5; box.layer.borderColor = Look.brown.cgColor
        pic.contentMode = .scaleAspectFit; pic.layer.magnificationFilter = .nearest
        label.font = Look.pixel(13); label.textColor = Look.brown; label.textAlignment = .center; label.numberOfLines = 2
        for v in [box, pic, label] { v.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(v) }
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: contentView.topAnchor), box.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: contentView.trailingAnchor), box.heightAnchor.constraint(equalToConstant: 140),
            pic.centerXAnchor.constraint(equalTo: box.centerXAnchor), pic.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            pic.widthAnchor.constraint(equalToConstant: 126), pic.heightAnchor.constraint(equalToConstant: 120),
            label.topAnchor.constraint(equalTo: box.bottomAnchor, constant: 6), label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -10),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 10),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(image: UIImage?, name: String, on: Bool) {
        pic.image = image ?? UIImage(systemName: "shuffle")
        pic.tintColor = .white
        label.text = name.uppercased()
        box.layer.borderColor = (on ? Look.orange : Look.brown).cgColor
    }
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
            self.box.backgroundColor = self.isFocused ? Look.orange : UIColor(red: 0.306, green: 0.753, blue: 0.792, alpha: 1)
            self.layer.zPosition = self.isFocused ? 1 : 0
        })
    }
}

// MARK: - Leaderboard (the same online board as the phone and the website)

final class LeaderboardController: PanelController, UITableViewDataSource {
    private let modes = UISegmentedControl(items: Modes.all.map { $0.title.uppercased() })
    private let when = UISegmentedControl(items: ["ALL TIME", "THIS WEEK"])
    private let table = UITableView(frame: .zero, style: .plain)
    private let note = UILabel()
    private var rows: [Online.Row] = []
    private var mode = Prefs.mode

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Leaderboard"
        modes.selectedSegmentIndex = Modes.all.firstIndex { $0.id == mode } ?? 0
        when.selectedSegmentIndex = 0
        for s in [modes, when] {
            s.setTitleTextAttributes([.font: Look.pixel(15), .foregroundColor: Look.brown], for: .normal)
            s.setTitleTextAttributes([.font: Look.pixel(15), .foregroundColor: UIColor.white], for: .selected)
            s.addTarget(self, action: #selector(changed), for: .valueChanged)
        }
        table.dataSource = self; table.backgroundColor = .clear; table.rowHeight = 92
        table.register(ScoreRow.self, forCellReuseIdentifier: "r")
        note.font = Look.pixel(22); note.textColor = Look.brown; note.textAlignment = .center; note.numberOfLines = 0
        for v in [modes, when, table, note] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            modes.topAnchor.constraint(equalTo: content.topAnchor), modes.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            modes.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            when.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 18), when.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            table.topAnchor.constraint(equalTo: when.bottomAnchor, constant: 18), table.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 120),
            table.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -120), table.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            note.centerXAnchor.constraint(equalTo: table.centerXAnchor), note.centerYAnchor.constraint(equalTo: table.centerYAnchor),
            note.widthAnchor.constraint(equalTo: table.widthAnchor),
        ])
        fetch()
    }
    @objc private func changed() { mode = Modes.all[modes.selectedSegmentIndex].id; fetch() }
    private func fetch() {
        note.text = "LOADING..."; rows = []; table.reloadData()
        let m = mode, week = when.selectedSegmentIndex == 1
        Online.leaderboard(mode: m, week: week) { [weak self] result in
            guard let s = self, s.mode == m else { return }
            switch result {
            case .success(let r): s.rows = Array(r.prefix(50)); s.note.text = r.isEmpty ? "NO SCORES YET. BE THE FIRST ON YOUR PHONE OR ONLINE!" : ""
            case .failure: s.note.text = "COULDN'T REACH THE LEADERBOARD. CHECK THE INTERNET."
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
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let box = UIView(); box.backgroundColor = Look.light; box.layer.cornerRadius = 14; box.layer.borderWidth = 4; box.layer.borderColor = UIColor(red: 0.77, green: 0.74, blue: 0.48, alpha: 1).cgColor
        backgroundView = box
        let fb = UIView(); fb.backgroundColor = Look.orange; fb.layer.cornerRadius = 14; selectedBackgroundView = fb
        rank.font = Look.pixel(22); rank.textColor = Look.orange; rank.textAlignment = .center
        name.font = Look.pixel(24); name.textColor = Look.brown
        score.font = Look.title(44); score.textColor = Look.brown; score.textAlignment = .right
        pic.layer.magnificationFilter = .nearest; pic.layer.cornerRadius = 10; pic.clipsToBounds = true
        for v in [rank, pic, name, score] { v.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(v) }
        NSLayoutConstraint.activate([
            rank.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12), rank.widthAnchor.constraint(equalToConstant: 90),
            rank.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pic.leadingAnchor.constraint(equalTo: rank.trailingAnchor, constant: 8), pic.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pic.widthAnchor.constraint(equalToConstant: 84), pic.heightAnchor.constraint(equalToConstant: 70),
            name.leadingAnchor.constraint(equalTo: pic.trailingAnchor, constant: 24), name.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            score.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28), score.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            name.trailingAnchor.constraint(lessThanOrEqualTo: score.leadingAnchor, constant: -20),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(rank r: Int, row: Online.Row) {
        rank.text = r == 1 ? "1ST" : r == 2 ? "2ND" : r == 3 ? "3RD" : "\(r)"
        name.text = row.name.uppercased(); score.text = "\(row.score)"
        pic.image = Birds.shared.image(row.avatar ?? row.bird, scale: 2)
        pic.backgroundColor = Online.color(row.avatarBg)
    }
}
