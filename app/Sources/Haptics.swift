// Floppy drive haptics: a physical tick while a drive is stepping, so a
// long disk load feels like the machine it is emulating.
//
// The core owns drive state on the emulation thread; rather than adding a
// cross-thread callback out of gui_led(), the app polls
// ipaduae_floppy_led_mask() (a plain read of gui_ledstate) and turns
// edges and sustained activity into taps. A missed poll costs one tick.
//
// Only devices with a Taptic Engine have haptics at all — iPads do not,
// so on iPad this stays permanently dormant and the menu row is hidden.

import CoreHaptics
import UIKit

final class FloppyHaptics {
    static let shared = FloppyHaptics()

    /// True on hardware that can actually play haptics (iPhone).
    static let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    static var enabled: Bool {
        get {
            guard supported else { return false }
            return UserDefaults.standard.object(forKey: "floppyHaptics") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "floppyHaptics")
            newValue ? shared.start() : shared.stop()
        }
    }

    private var engine: CHHapticEngine?
    private var timer: Timer?
    private var lastMask: Int = 0
    private var lastTick = Date.distantPast

    /// Polling rate. Drive activity is bursty and short; 30 Hz catches the
    /// individual steps of a seek without costing a measurable amount of
    /// main-thread time (one integer read per poll).
    private let pollInterval = 1.0 / 30.0
    /// Floor between two ticks. Without it a long read fires continuously
    /// and just buzzes; ~11 Hz reads as a drive chattering.
    private let minTickGap = 0.09

    func startIfEnabled() {
        guard Self.enabled else { return }
        start()
    }

    private func start() {
        guard Self.supported, timer == nil else { return }
        do {
            let engine = try CHHapticEngine()
            // The engine is stopped by the system on interruption (a phone
            // call, backgrounding); restart lazily rather than giving up.
            engine.stoppedHandler = { [weak self] _ in self?.engine = nil }
            engine.resetHandler = { [weak self] in try? self?.engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            NSLog("iPadUAE haptics: engine unavailable (%@)", String(describing: error))
            return
        }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        engine?.stop()
        engine = nil
        lastMask = 0
    }

    private func poll() {
        let mask = Int(ipaduae_floppy_led_mask())
        defer { lastMask = mask }
        guard mask != 0 else { return }
        // Tick on a drive becoming busy, and keep ticking while it stays
        // busy — a seek holds the LED across many polls.
        let becameBusy = (mask & ~lastMask) != 0
        let now = Date()
        guard becameBusy || now.timeIntervalSince(lastTick) >= minTickGap else { return }
        lastTick = now
        tick()
    }

    private func tick() {
        guard let engine else { return }
        // Short, dry click — a drive step, not a notification thud.
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85),
        ], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // A failed tick is not worth tearing the engine down for.
        }
    }
}
