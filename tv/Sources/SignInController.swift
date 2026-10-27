import CoreImage
import UIKit

/// Sign in with your phone: a QR code for SITE#tv=CODE. Scan it, tap Approve on the phone, and the TV signs in.
/// Signed in already: your name and a Sign out button. 2FA accounts type their 6-digit code once.
final class SignInController: PanelController {
    private let qr = UIImageView(), info = UILabel(), codeLabel = UILabel(), status = UILabel()
    private let codeField = UITextField()
    private let mainButton = PixelButton("SIGN OUT")
    private var link: Account.Link?
    private var pollTimer: Timer?
    private var busy = false

    override func viewDidLoad() {
        super.viewDidLoad()
        heading.text = "Account"
        qr.layer.magnificationFilter = .nearest; qr.backgroundColor = .white; qr.layer.cornerRadius = 16; qr.clipsToBounds = true
        for l in [info, codeLabel, status] { l.numberOfLines = 0; l.textAlignment = .center; l.textColor = Look.brown }
        info.font = Look.pixel(24); codeLabel.font = Look.pixel(56); status.font = Look.pixel(20)
        codeField.font = Look.pixel(40); codeField.textAlignment = .center; codeField.keyboardType = .numberPad
        codeField.placeholder = "6-DIGIT CODE"; codeField.backgroundColor = Look.light
        mainButton.onSelect = { [weak self] in self?.mainTapped() }
        for v in [qr, info, codeLabel, status, codeField, mainButton] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(v) }
        NSLayoutConstraint.activate([
            qr.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 60), qr.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            qr.widthAnchor.constraint(equalToConstant: 520), qr.heightAnchor.constraint(equalToConstant: 520),
            info.leadingAnchor.constraint(equalTo: qr.trailingAnchor, constant: 70), info.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
            info.topAnchor.constraint(equalTo: content.topAnchor, constant: 60),
            codeLabel.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 40), codeLabel.centerXAnchor.constraint(equalTo: info.centerXAnchor),
            codeField.topAnchor.constraint(equalTo: info.bottomAnchor, constant: 40), codeField.centerXAnchor.constraint(equalTo: info.centerXAnchor),
            codeField.widthAnchor.constraint(equalToConstant: 520),
            status.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 50), status.leadingAnchor.constraint(equalTo: info.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: info.trailingAnchor),
            mainButton.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 40), mainButton.centerXAnchor.constraint(equalTo: info.centerXAnchor),
        ])
        refresh()
    }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); pollTimer?.invalidate() }
    override var preferredFocusEnvironments: [UIFocusEnvironment] { Account.shared.session?.needCode == true ? [codeField] : [mainButton] }

    private func refresh() {
        let a = Account.shared
        codeField.isHidden = true; codeLabel.isHidden = false; qr.isHidden = false
        if a.signedIn {
            pollTimer?.invalidate(); link = nil
            qr.image = Birds.shared.image(Prefs.bird == "random" ? "yellow" : Prefs.bird, scale: 12); qr.backgroundColor = UIColor(red: 0.306, green: 0.753, blue: 0.792, alpha: 1)
            info.text = "SIGNED IN AS"; codeLabel.text = a.username.uppercased()
            status.text = "YOUR SCORES ON THIS TV GO ON THE ONLINE LEADERBOARD,\nAND YOUR GAMES ADD UP ON YOUR PROFILE."
            mainButton.setTitle("SIGN OUT", for: .normal); mainButton.isHidden = false
        } else if a.session?.needCode == true {
            pollTimer?.invalidate()
            qr.image = nil; qr.isHidden = true; codeLabel.isHidden = true; codeField.isHidden = false
            info.text = "YOUR ACCOUNT USES 2FA.\nTYPE THE 6-DIGIT CODE FROM YOUR AUTHENTICATOR APP:"
            status.text = ""
            mainButton.setTitle("VERIFY", for: .normal); mainButton.isHidden = false
        } else {
            qr.backgroundColor = .white
            info.text = "SCAN THIS WITH YOUR PHONE CAMERA,\nTHEN TAP APPROVE ON YOUR PHONE.\n\nYOUR PHONE NEEDS TO BE SIGNED IN\nTO FLAPPY BIRD."
            mainButton.isHidden = true
            if link == nil { newCode() }
        }
        setNeedsFocusUpdate()
    }

    private func newCode() {
        codeLabel.text = "..."; status.text = "GETTING A CODE..."; qr.image = nil
        Account.shared.startLink { [weak self] l in
            guard let self = self else { return }
            guard let l = l else { self.status.text = "COULDN'T REACH THE SERVER.\nCHECK THE INTERNET."; DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.newCode() }; return }
            self.link = l
            self.qr.image = Self.qrImage(PartyController.site + "#tv=" + l.code)
            self.codeLabel.text = String(l.code.prefix(4)) + " " + String(l.code.suffix(4))
            self.status.text = "WAITING FOR YOUR PHONE..."
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in self?.poll() }
        }
    }
    private func poll() {
        guard let l = link, !busy else { return }
        busy = true
        Account.shared.poll(l) { [weak self] r in
            guard let self = self else { return }
            self.busy = false
            switch r {
            case .waiting: break
            case .done: self.link = nil; self.refresh()
            case .failed(let m):
                self.status.text = m.uppercased()
                if m.contains("ran out") || m.contains("already used") { self.link = nil; self.pollTimer?.invalidate(); DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.newCode() } }
                else if m.contains("set up") { self.pollTimer?.invalidate() }
            }
        }
    }
    private func mainTapped() {
        let a = Account.shared
        if a.signedIn { a.signOut(); refresh(); return }
        if a.session?.needCode == true {
            let c = (codeField.text ?? "").filter { $0.isNumber }
            guard c.count == 6 else { status.text = "TYPE ALL 6 NUMBERS"; return }
            status.text = "CHECKING..."
            a.verifyCode(c) { [weak self] ok in self?.status.text = ok ? "" : "WRONG CODE. TRY THE NEWEST ONE."; if ok { self?.refresh() } }
        }
    }

    static func qrImage(_ s: String) -> UIImage? {
        guard let f = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        f.setValue(Data(s.utf8), forKey: "inputMessage"); f.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 14, y: 14)), let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        let pad: CGFloat = 42, size = CGSize(width: CGFloat(cg.width) + pad * 2, height: CGFloat(cg.height) + pad * 2)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.interpolationQuality = .none
            UIImage(cgImage: cg).draw(in: CGRect(x: pad, y: pad, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
    }
}
