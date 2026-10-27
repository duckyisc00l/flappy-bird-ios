import UIKit
import WebKit

/// Serves the game from the app bundle under its own address (flappy://game/...),
/// so saved data (best scores, your birds, settings) is kept between launches.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root = Bundle.main.resourceURL!.appendingPathComponent("web")

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        var file = root.appendingPathComponent(String(path.dropFirst()))
        if path == "/index.html", let hot = GameUpdate.newerGame() { file = hot }   // a newer game downloaded with the Update button
        guard let data = try? Data(contentsOf: file) else {
            task.didFailWithError(NSError(domain: "FlappyBird", code: 404))
            return
        }
        let types = ["html": "text/html", "js": "text/javascript", "css": "text/css",
                     "png": "image/png", "json": "application/json", "mp3": "audio/mpeg"]
        let mime = types[file.pathExtension.lowercased()] ?? "application/octet-stream"
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)",
                                                      "Cache-Control": "no-cache"])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

/// One-tap updates: the game (one HTML file) can be replaced by a newer one from the website without reinstalling.
/// The newer file is kept in Application Support and used while its build is newer than the one inside the app.
enum GameUpdate {
    static var bundledBuild: Int { Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0 }
    static var folder: URL {
        let u = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("game", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    static var hotFile: URL { folder.appendingPathComponent("index.html") }
    static func newerGame() -> URL? {
        let b = UserDefaults.standard.integer(forKey: "hotBuild")
        guard b > bundledBuild, FileManager.default.fileExists(atPath: hotFile.path) else { return nil }
        return hotFile
    }
}

/// The game posts { build, url } to window.webkit.messageHandlers.update when you tap Update.
final class UpdateBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let build = body["build"] as? Int,
              let s = body["url"] as? String, let url = URL(string: s), url.scheme == "https",
              url.host == "duckyisc00l.github.io" else { return fail("That update doesn't look right") }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        req.url = URL(string: s + "?t=\(Int(Date().timeIntervalSince1970))")
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self = self else { return }
            guard err == nil, (resp as? HTTPURLResponse)?.statusCode == 200, let data = data, data.count > 300_000,
                  let text = String(data: data, encoding: .utf8), text.contains("const APP_BUILD = \(build);") else {
                return self.fail(err == nil ? "The download wasn't complete. Try again." : "Couldn't download. Check your internet.")
            }
            do {
                try data.write(to: GameUpdate.hotFile, options: .atomic)
                UserDefaults.standard.set(build, forKey: "hotBuild")
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript("try { sessionStorage.setItem('fb_justUpdated', '\(build)') } catch (e) {}")
                    self.webView?.load(URLRequest(url: URL(string: "flappy://game/index.html")!))
                }
            } catch { self.fail("Couldn't save the update") }
        }.resume()
    }

    private func fail(_ msg: String) {
        DispatchQueue.main.async {
            let m = msg.replacingOccurrences(of: "'", with: "")
            self.webView?.evaluateJavaScript("window.fbUpdateFailed && window.fbUpdateFailed('\(m)')")
        }
    }
}

/// Haptics for the app only: the game posts "flap", "light", "medium", "heavy" or "error"
/// to window.webkit.messageHandlers.haptic and the phone's Taptic Engine plays it.
final class HapticBridge: NSObject, WKScriptMessageHandler {
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notice = UINotificationFeedbackGenerator()

    override init() {
        super.init()
        [soft, light, medium, heavy].forEach { $0.prepare() }
        notice.prepare()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.body as? String ?? "" {
        case "flap": soft.impactOccurred(intensity: 0.7); soft.prepare()
        case "medium": medium.impactOccurred(); medium.prepare()
        case "heavy": heavy.impactOccurred(); heavy.prepare()
        case "error": notice.notificationOccurred(.error); notice.prepare()
        default: light.impactOccurred(); light.prepare()
        }
    }
}

final class GameViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {
    private var webView: WKWebView!
    private var downloadFile: URL?

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "flappy")
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.userContentController.add(HapticBridge(), name: "haptic")
        let updater = UpdateBridge()
        config.userContentController.add(updater, name: "update")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        updater.webView = webView
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: URL(string: "flappy://game/index.html")!))
    }

    // Links (TikTok) open outside the game.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {           // "Save picture" / "Download clip"
            decisionHandler(.download)
            return
        }
        if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // Saved pictures / clips go to a temporary file, then the share sheet opens (Save Image, Save Video, Messages...).
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let name = suggestedFilename.isEmpty ? "flappy-bird" : suggestedFilename
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + name)
        downloadFile = url
        completionHandler(url)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = downloadFile else { return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(sheet, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {}

    // The game's own JavaScript alerts (none normally) shouldn't freeze the app.
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
