import CoreHaptics
import GameController

/// Game controllers (PlayStation, Xbox, MFi) give a short rumble when you crash. The Siri Remote has no motor.
enum Rumble {
    private static var engines: [ObjectIdentifier: CHHapticEngine] = [:]

    static func crash() { play(intensity: 1, sharpness: 0.35, duration: 0.32) }
    static func point() { play(intensity: 0.35, sharpness: 0.8, duration: 0.05) }

    private static func play(intensity: Float, sharpness: Float, duration: TimeInterval) {
        for c in GCController.controllers() {
            guard let h = c.haptics else { continue }
            let key = ObjectIdentifier(c)
            guard let engine = engines[key] ?? h.createEngine(withLocality: .default) else { continue }
            engines[key] = engine
            do {
                try engine.start()
                let ev = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)], relativeTime: 0, duration: duration)
                try engine.makePlayer(with: CHHapticPattern(events: [ev], parameters: [])).start(atTime: CHHapticTimeImmediate)
            } catch { engines[key] = nil }
        }
    }
}
