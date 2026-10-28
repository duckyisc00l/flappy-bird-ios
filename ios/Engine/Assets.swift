import AVFoundation
import Foundation
import UIKit

/// The website's pictures, exported to files (web/img), plus every bird from the sheets (web/birds).
enum Assets {
    static let base = Bundle.main.resourceURL!.appendingPathComponent("web")
    private static var cache: [String: Img] = [:]
    private static var missing: Set<String> = []
    static func file(_ name: String) -> Img? {
        let u = base.appendingPathComponent("img/" + name + ".png")
        guard let d = try? Data(contentsOf: u), let ui = UIImage(data: d), let cg = ui.cgImage else { return nil }
        return Img(cg)
    }
    /// img[key] on the web page
    static func img(_ k: String) -> Img? {
        if let i = cache[k] { return i }
        if missing.contains(k) { return nil }
        var found = file(k)
        if found == nil, let us = k.lastIndex(of: "_"), let n = Int(k[k.index(after: us)...]), (1...3).contains(n) {
            found = Birds2.frame(String(k[..<us]), n)
        }
        if let f = found { cache[k] = f } else { missing.insert(k) }
        return found
    }
    static func put(_ k: String, _ im: Img?) { cache[k] = im; if im != nil { missing.remove(k) } else { cache[k] = nil } }
    static func drop(_ k: String) { cache[k] = nil; missing.remove(k) }

    /// the data the website keeps in code (trails, glyphs, the bird's cells...), exported as JSON
    static let data: [String: Any] = {
        guard let d = try? Data(contentsOf: base.appendingPathComponent("data.json")), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return o
    }()
}

/// Every bird's 3 flapping frames, from the exported sheets (16 birds a row, 3 frames of 42x40 each).
enum Birds2 {
    struct Info { let id: String, name: String, cat: String, sheet: Int, col: Int, row: Int }
    static let all: [Info] = {
        guard let d = try? Data(contentsOf: Assets.base.appendingPathComponent("birds/birds.json")), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let s = o["skins"] as? [[Any]] else { return [] }
        return s.compactMap { r in
            guard r.count >= 6, let id = r[0] as? String, let n = r[1] as? String, let c = r[2] as? String, let sh = r[3] as? Int, let co = r[4] as? Int, let ro = r[5] as? Int else { return nil }
            return Info(id: id, name: n, cat: c, sheet: sh, col: co, row: ro)
        }
    }()
    static let byId: [String: Info] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    private static var sheets: [Int: CGImage] = [:]
    static func frame(_ id: String, _ n: Int) -> Img? {
        guard let b = byId[id] else { return nil }
        if sheets[b.sheet] == nil, let d = try? Data(contentsOf: Assets.base.appendingPathComponent("birds/birds\(b.sheet).png")), let ui = UIImage(data: d) { sheets[b.sheet] = ui.cgImage }
        guard let sh = sheets[b.sheet], let c = sh.cropping(to: CGRect(x: b.col * 126 + (n - 1) * 42, y: b.row * 40, width: 42, height: 40)) else { return nil }
        return Img(c)
    }
}

/// Sounds: the website's five sounds, the haunted music loop, the army of flaps and the Morse beeps.
final class Audio {
    static let shared = Audio()
    private let engine = AVAudioEngine()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var pools: [String: [AVAudioPlayerNode]] = [:]
    private var next: [String: Int] = [:]
    private let music = AVAudioPlayerNode(), extra = AVAudioPlayerNode(), morse = AVAudioPlayerNode()
    private var musicOn = false
    private let fmt = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        for n in ["wing", "hit", "die", "swoosh", "point"] {
            guard let b = load("sounds/" + n + ".wav") else { continue }
            buffers[n] = b
            var list: [AVAudioPlayerNode] = []
            for _ in 0..<5 { let p = AVAudioPlayerNode(); engine.attach(p); engine.connect(p, to: engine.mainMixerNode, format: b.format); list.append(p) }
            pools[n] = list; next[n] = 0
        }
        for p in [music, extra, morse] { engine.attach(p); engine.connect(p, to: engine.mainMixerNode, format: fmt) }
        music.volume = 0.8
        engine.prepare()
        try? engine.start()
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in self?.restart() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.restart() }
    }
    private func restart() { if !engine.isRunning { try? engine.start() } }
    private func load(_ path: String) -> AVAudioPCMBuffer? {
        guard let f = try? AVAudioFile(forReading: Assets.base.appendingPathComponent(path)),
              let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else { return nil }
        try? f.read(into: b)
        return b
    }
    /// stereo 44.1 kHz copy (for mixing)
    private func stereo(_ b: AVAudioPCMBuffer) -> [[Float]] {
        let n = Int(b.frameLength), ch = Int(b.format.channelCount)
        guard let d = b.floatChannelData else { return [[], []] }
        let l = Array(UnsafeBufferPointer(start: d[0], count: n)), r = ch > 1 ? Array(UnsafeBufferPointer(start: d[1], count: n)) : l
        return [l, r]
    }
    func play(_ name: String) {
        guard let b = buffers[name], let list = pools[name] else { return }
        restart()
        let i = next[name] ?? 0; next[name] = (i + 1) % list.count
        let p = list[i]
        p.stop(); p.scheduleBuffer(b, at: nil, options: [], completionHandler: nil); p.play()
    }
    /// the haunted music: a seamless loop while it should play
    func setMusic(_ on: Bool) {
        if on == musicOn { return }
        musicOn = on
        if on {
            guard let b = load("sounds/haunted.mp3"), let conv = convert(b) else { musicOn = false; return }
            restart()
            music.stop(); music.scheduleBuffer(conv, at: nil, options: .loops, completionHandler: nil); music.play()
        } else { music.stop() }
    }
    private func convert(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if b.format == fmt { return b }
        guard let c = AVAudioConverter(from: b.format, to: fmt) else { return nil }
        let cap = AVAudioFrameCount(Double(b.frameLength) * fmt.sampleRate / b.format.sampleRate) + 1024
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else { return nil }
        var fed = false
        _ = c.convert(to: out, error: nil) { _, st in if fed { st.pointee = .endOfStream; return nil }; fed = true; st.pointee = .haveData; return b }
        return out
    }
    private func toBuffer(_ l: [Float], _ r: [Float]) -> AVAudioPCMBuffer? {
        guard let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(l.count)) else { return nil }
        out.frameLength = AVAudioFrameCount(l.count)
        l.withUnsafeBufferPointer { out.floatChannelData![0].update(from: $0.baseAddress!, count: l.count) }
        r.withUnsafeBufferPointer { out.floatChannelData![1].update(from: $0.baseAddress!, count: r.count) }
        return out
    }
    /// armyRush(): a hundred and ten flaps at once, each with its own speed, volume and side (mixed here, played as one sound)
    func army() {
        guard let wb = buffers["wing"] else { return }
        let src = stereo(wb), sr = 44100.0, srcRate = wb.format.sampleRate
        let total = Int(sr * 2.6)
        var L = [Float](repeating: 0, count: total), R = L
        for _ in 0..<110 {
            let t = pow(Double.random(in: 0..<1), 1.7) * 1.9, gain = 0.35 + Double.random(in: 0..<0.65), rate = 0.75 + Double.random(in: 0..<0.6), pan = Double.random(in: -1..<1)
            let gl = Float(gain * 0.55 * min(1, 1 - pan)), gr = Float(gain * 0.55 * min(1, 1 + pan))
            let start = Int(t * sr), step = rate * srcRate / sr
            var pos = 0.0, i = start
            while i < total { let k = Int(pos); if k >= src[0].count - 1 { break }; L[i] += src[0][k] * gl; R[i] += src[1][k] * gr; pos += step; i += 1 }
        }
        // a soft limiter (the web page uses a compressor)
        for i in 0..<total { L[i] = tanhf(L[i]); R[i] = tanhf(R[i]) }
        guard let b = toBuffer(L, R) else { return }
        restart(); extra.stop(); extra.scheduleBuffer(b, at: nil, options: [], completionHandler: nil); extra.play()
    }
    /// the Morse message: sine beeps at 620 Hz
    func playMorse(_ timeline: [(Bool, Int)], unit: Double) {
        let sr = 44100.0
        var L: [Float] = []
        let lead = Int(0.05 * sr); L.append(contentsOf: [Float](repeating: 0, count: lead))
        var phase = 0.0
        for (on, u) in timeline {
            let n = Int(Double(u) * unit * sr)
            for j in 0..<n {
                var v: Float = 0
                if on { let tt = Double(j) / sr, d = Double(n) / sr; let env = min(1, tt / 0.005, max(0, (d - tt) / 0.006)); v = Float(sin(phase) * 0.18 * env) }
                phase += 2 * .pi * 620 / sr
                L.append(v)
            }
        }
        guard let b = toBuffer(L, L) else { return }
        restart(); morse.stop(); morse.scheduleBuffer(b, at: nil, options: [], completionHandler: nil); morse.play()
    }
    func stopMorse() { morse.stop() }
}
