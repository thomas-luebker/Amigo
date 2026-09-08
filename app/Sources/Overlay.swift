// Native control overlay hosted on top of SDL's UIKit window.
//
// SDL owns the root view controller; we attach a UIHostingController as a
// child. The emulator loop starves the main runloop (SDL pumps it briefly
// each frame), so UIKit modal presentation is unreliable here — the menu is
// therefore a plain SwiftUI state-driven panel, and the hosting view is
// resized to exactly fit the visible content so it never blocks emulator
// touches outside itself.

import SwiftUI
import UIKit

@_cdecl("ipaduae_install_overlay")
public func ipaduae_install_overlay() {
    FileHandle.standardError.write("iPadUAE: overlay install dispatched\n".data(using: .utf8)!)
    DispatchQueue.main.async { OverlayInstaller.shared.installWhenReady() }
}

/// A window that only claims touches landing on actual overlay content;
/// everything else falls through to SDL's window below.
///
/// SwiftUI hosts all controls in one flat _UIHostingView (gestures, not
/// subviews), so hit-view identity cannot distinguish a button from empty
/// background. Instead, the SwiftUI content reports the global frames of
/// its interactive elements (see .interactiveArea) and the window claims
/// only touches inside those rects.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // A presented modal (the document picker) covers the screen and
        // reports no interactive rects of its own — keep filtering and it
        // would be visible but untouchable.
        if OverlayState.shared.modalActive {
            return super.hitTest(point, with: event)
        }
        let rects = OverlayState.shared.interactiveRects
        guard rects.values.contains(where: { $0.insetBy(dx: -8, dy: -8).contains(point) }) else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

/// Reports a view's global frame into OverlayState so PassthroughWindow can
/// route touches; removes it when the view disappears.
struct InteractiveArea: ViewModifier {
    let id: String
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo -> Color in
                    let frame = geo.frame(in: .global)
                    DispatchQueue.main.async {
                        OverlayState.shared.interactiveRects[id] = frame
                    }
                    return Color.clear
                }
            )
            .onDisappear {
                OverlayState.shared.interactiveRects.removeValue(forKey: id)
            }
    }
}

extension View {
    func interactiveArea(_ id: String) -> some View {
        modifier(InteractiveArea(id: id))
    }
}

final class OverlayInstaller {
    static let shared = OverlayInstaller()
    private var overlayWindow: PassthroughWindow?

    func installWhenReady() {
        guard overlayWindow == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { !$0.windows.isEmpty }) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.installWhenReady() }
            return
        }
        FileHandle.standardError.write("iPadUAE: overlay installing on scene\n".data(using: .utf8)!)
        NSLog("iPadUAE overlay: installing overlay window on scene")
        // Apply persisted display preferences to the core.
        ipaduae_set_safe_area(OverlayState.shared.fullscreenDisplay ? 0 : 1)
        ipaduae_set_rtg_accel(OverlayState.shared.rtgAccel ? 1 : 0)
        ipaduae_set_vsync(OverlayState.shared.vsync ? 1 : 0)
        ipaduae_set_external_display(OverlayState.shared.externalDisplay ? 1 : 0)
        let host = UIHostingController(rootView: OverlayRoot { _ in })
        host.view.backgroundColor = .clear
        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .alert
        window.isHidden = false
        overlayWindow = window
        PencilHoverDriver.shared.install(on: scene)
        installAutosave()
        installDebugHooks()
        // Controller routing prefs must be live before the first
        // connect event, not first panel-open.
        ControllerPanel.applyStored()
        // Free the cursor keys: the joystick overlay starts hidden, so
        // the joyport drops kbd2 until the user shows it (didSet keeps
        // the core in sync from then on).
        ipaduae_set_kbd_joystick(OverlayState.shared.showJoystick ? 1 : 0)
        ipaduae_set_aspect_fit(OverlayState.shared.aspectFit ? 1 : 0)
        ipaduae_set_crt(Int32(OverlayState.shared.crtLevel))
        // Drops land on SDL's view, under the overlay window — the
        // overlay rejects touches outside its own controls.
        MediaDropDelegate.shared.install(on: scene)
        FloppyHaptics.shared.startIfEnabled()
        CloudSync.sync()
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { _ in
            CloudSync.sync()
        }


        // The overlay only installs once SDL's window (and thus video) is
        // up; 30s beyond that counts as a stable boot, so a crash later on
        // won't roll back the last machine/media change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            ConfigStore.markBootStable()
        }
    }



    // Autosave (quick-state slot 0): every 5 minutes while running, and a
    // best-effort save when the app is backgrounded (the queued save runs
    // if the emulator gets a few more frames during the transition).
    private var autosaveTimer: Timer?

    private func installAutosave() {
        // Deliberately does NOT sync: the autosave slot is several MB and
        // is rewritten every five minutes forever, so syncing here meant a
        // multi-megabyte upload every five minutes for as long as the app
        // was open. The handoff moment that actually matters is putting
        // the device down, which is willResignActive below.
        let timer = Timer(timeInterval: 300, repeats: true) { _ in
            ipaduae_state_op(0, 1)
        }
        RunLoop.main.add(timer, forMode: .common)
        autosaveTimer = timer
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { _ in
            ipaduae_state_op(0, 1)
            // One upload when the device is put down — the "stop here,
            // carry on over there" moment the sync exists for.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { CloudSync.sync() }
        }
    }

    // DEBUG: lets automated tests drive the menu without synthetic touches
    // (simulator host clicks need Accessibility permission we may not have):
    //   xcrun simctl spawn <sim> notifyutil -p de.amiga-imager.uae.toggleMenu
    private func installDebugHooks() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = "de.amiga-imager.uae.toggleMenu" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async {
                NSLog("iPadUAE overlay: debug toggleMenu received")
                OverlayState.shared.expanded.toggle()
            }
        }, name, nil, .deliverImmediately)

        let insertName = "de.amiga-imager.uae.insertFirstFloppy" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async {
                let dir = ConfigStore.winuaeDir.appendingPathComponent("Floppies")
                let first = ConfigStore.mediaFiles(in: dir,
                                                   extensions: ["adf", "adz", "dms"]).first
                if let first {
                    NSLog("iPadUAE overlay: debug insert DF0 %@", first.path)
                    ipaduae_insert_floppy(0, first.path)
                } else {
                    NSLog("iPadUAE overlay: debug insert DF0 — no images found")
                }
            }
        }, insertName, nil, .deliverImmediately)

        // Dismisses an Amiga system requester (LAmiga+B) and types "dir\n" —
        // used to verify the virtual-key path end to end in the simulator.
        let kbName = "de.amiga-imager.uae.toggleKeyboard" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async { OverlayState.shared.showKeyboard.toggle() }
        }, kbName, nil, .deliverImmediately)

        let joyName = "de.amiga-imager.uae.toggleJoystick" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async { OverlayState.shared.showJoystick.toggle() }
        }, joyName, nil, .deliverImmediately)

        let hdfName = "de.amiga-imager.uae.mountFirstHDF" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async {
                if let first = ConfigStore.files(in: ConfigStore.hardDrivesDir,
                                                 extensions: ["hdf", "hdz", "vhd"]).first {
                    NSLog("iPadUAE overlay: debug mount HDF %@", first.path)
                    ConfigStore.mountHardfile(url: first)
                } else {
                    NSLog("iPadUAE overlay: debug mount HDF — none found")
                }
            }
        }, hdfName, nil, .deliverImmediately)

        let typeName = "de.amiga-imager.uae.typeDirTest" as CFString
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async {
                NSLog("iPadUAE overlay: debug typeDirTest")
                sendKeyTap(SC.b, delay: 0.0, modifier: SC.lamiga)   // cancel requester
                sendKeyTap(SC.d, delay: 1.0)
                sendKeyTap(SC.i, delay: 1.3)
                sendKeyTap(SC.r, delay: 1.6)
                sendKeyTap(SC.ret, delay: 2.0)
            }
        }, typeName, nil, .deliverImmediately)
    }
}

/// Shared observable state so debug hooks can drive the menu.
final class OverlayState: ObservableObject {
    static let shared = OverlayState()
    @Published var expanded = false
    @Published var showKeyboard = false
    /// Showing the joystick overlay also puts keyboard layout B (cursor
    /// keys + right Ctrl) on the Amiga joystick port — the overlay sends
    /// those scancodes. Hidden, the port drops to "none" so cursor keys
    /// type as cursor keys (a controller assignment overrides either way).
    @Published var showJoystick = false {
        didSet { ipaduae_set_kbd_joystick(showJoystick ? 1 : 0) }
    }
    @Published var showFKeys = false
    @Published var showNumpad = false
    @Published var fullscreenDisplay = UserDefaults.standard.bool(forKey: "fullscreenDisplay")
    @Published var showLEDs = UserDefaults.standard.object(forKey: "showLEDs") as? Bool ?? true
    @Published var rtgAccel = UserDefaults.standard.object(forKey: "rtgAccel") as? Bool ?? false
    @Published var vsync = UserDefaults.standard.object(forKey: "vsync") as? Bool ?? false
    @Published var tabletMode = ConfigStore.tabletMode
    @Published var penPressure = ConfigStore.penPressure
    @Published var serialTablet = ConfigStore.serialTablet
    // Default OFF, matching the core's default — see unix_video_external_enabled
    // in video_sdl.cpp for why auto-detection must not run on the very first
    // boot before this preference has a chance to sync.
    @Published var externalDisplay = UserDefaults.standard.object(forKey: "externalDisplay") as? Bool ?? false
    /// Letterbox the picture to its own proportions instead of stretching
    /// to fill (matters most in portrait, where full-stretch is grotesque).
    @Published var aspectFit = UserDefaults.standard.object(forKey: "aspectFit") as? Bool ?? false
    /// Classic keyboard style: translucent overlay on the full-bleed
    /// picture (the pre-0.7.1 look, default). Off = the picture lays out
    /// above the keyboard instead (portrait-friendly, no occlusion).
    @Published var keyboardOverlayStyle = UserDefaults.standard.object(forKey: "keyboardOverlayStyle") as? Bool ?? true
    /// Opacity of the input overlays (keyboard, numpad, F-keys, joystick).
    /// Floor of 0.25 keeps them findable — invisible-but-touchable panels
    /// would eat emulator input with no visual explanation.
    @Published var overlayOpacity = UserDefaults.standard.object(forKey: "overlayOpacity") as? Double ?? 1.0
    /// True while a UIKit modal is presented over the overlay window.
    /// Read by PassthroughWindow.hitTest on every touch.
    var modalActive = false

    /// CRT scanline strength, 0 = off … 3 = heavy.
    @Published var crtLevel = UserDefaults.standard.object(forKey: "crtLevel") as? Int ?? 0 {
        didSet {
            UserDefaults.standard.set(crtLevel, forKey: "crtLevel")
            ipaduae_set_crt(Int32(crtLevel))
        }
    }

    /// Emulated floppy drives, 1…4. DF2/DF3 only appear in the menu once
    /// the count reaches them.
    ///
    /// Deliberately has NO didSet. An earlier version wrote the config
    /// from here, which meant merely *reading* a machine and mirroring it
    /// wrote an inferred value back — and silently disabled DF1 on every
    /// stock setup. This property mirrors the core; only an explicit user
    /// action (applyFloppyDrives) is allowed to change the machine.
    @Published var floppyDrives = ConfigStore.configuredFloppyDrives

    /// Apply a user-chosen drive count, then mirror it. The only path
    /// that writes floppyNtype.
    func applyFloppyDrives(_ count: Int) {
        ConfigStore.setFloppyDrives(count)
        floppyDrives = count
    }

    /// Re-read the drive count after something else changed the machine
    /// (loading a saved setup). Read-only — writes nothing back.
    func refreshFloppyDrivesFromConfig() {
        floppyDrives = ConfigStore.configuredFloppyDrives
    }

    /// Tick the drive on each floppy step. Hardware-gated: only devices
    /// with a Taptic Engine can play it at all.
    @Published var floppyHaptics = FloppyHaptics.enabled {
        didSet { FloppyHaptics.enabled = floppyHaptics }
    }

    /// Amiga-side clipboard sharing. Read from the config, which is the
    /// truth the core booted with — the Amiga starts its clipboard task at
    /// boot, so this cannot be flipped live.
    @Published var clipboardSharing = ConfigStore.currentValue("clipboard_sharing") == "true"

    /// Changing it rewrites the config and restarts, through the same
    /// crash-safe path as any other machine change.
    func setClipboardSharing(_ on: Bool) {
        clipboardSharing = on
        ConfigStore.setClipboardSharing(on)
    }

    /// Emulated floppy speed, mirrored from the core. No didSet: only
    /// applyFloppySpeed() may change the machine.
    @Published var floppySpeed = ConfigStore.currentFloppySpeed

    func applyFloppySpeed(_ speed: Int) {
        ConfigStore.setFloppySpeed(speed)
        floppySpeed = speed
    }

    /// Measured height of the on-screen keyboard, so the quick-controls
    /// button can sit clear of it instead of over the top row of keys.
    /// Written from the keyboard's own geometry each layout pass.
    @Published var keyboardHeight: CGFloat = 0

    /// Quick-controls cluster expanded (the extra overlay toggles).
    /// Auto-fire rate for the virtual joystick's FIRE button, in shots
    /// per second. 0 = off (hold means hold, the classic behaviour).
    ///
    /// Requested in Smurfy2000's 5★ review: "some enhancement to the
    /// virtual joystick would perhaps improve use ability (UI
    /// enhancements and auto fire support)".
    @Published var autoFireRate = UserDefaults.standard.object(forKey: "autoFireRate") as? Int ?? 0 {
        didSet { UserDefaults.standard.set(autoFireRate, forKey: "autoFireRate") }
    }

    @Published var quickExpanded = false
    @Published var quickDisplayExpanded = false

    /// Disk panel (bottom-right) expanded.
    @Published var diskExpanded = false

    /// Transient confirmation after a drag & drop or in-app import.
    @Published var importNotice: String?
    private var importNoticeWork: DispatchWorkItem?

    func scheduleImportNoticeDismissal() {
        importNoticeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            withAnimation { self?.importNotice = nil }
        }
        importNoticeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    /// Global frames of touch-interactive overlay elements, keyed by id.
    /// Read by PassthroughWindow.hitTest on every touch; written from
    /// SwiftUI geometry callbacks. Main-thread only.
    var interactiveRects: [String: CGRect] = [:]

    /// Shown once, on a genuinely fresh install: with no hard drive and no
    /// floppy configured, AROS boots to its own "Waiting for bootable
    /// media" screen — legitimate, but a static logo with a small unlabeled
    /// gear icon reads as "this does nothing" to anyone who doesn't
    /// recognize an Amiga boot sequence (this is what an App Review
    /// rejection screenshot actually showed). Dismissed for good the first
    /// time the menu is opened.
    @Published var showFirstRunHint =
        !UserDefaults.standard.bool(forKey: "hasOpenedMenuOnce")
        && !ConfigStore.isHardfileMounted
        && (ConfigStore.currentValue("floppy0") ?? "").isEmpty

    func dismissFirstRunHint() {
        guard showFirstRunHint else { return }
        showFirstRunHint = false
        UserDefaults.standard.set(true, forKey: "hasOpenedMenuOnce")
    }

    /// Set when startup rolled default.uae back to the last good config
    /// because the previous session crashed (or restart-looped) before its
    /// first stable boot after a machine/media change.
    @Published var showRecoveryNotice =
        UserDefaults.standard.bool(forKey: ConfigStore.recoveredKey)

    func dismissRecoveryNotice() {
        guard showRecoveryNotice else { return }
        showRecoveryNotice = false
        UserDefaults.standard.removeObject(forKey: ConfigStore.recoveredKey)
    }
}

/// Sends a scancode press+release with a small gap so the emulated 50Hz
/// input polling reliably observes it; used by debug hooks and macros.
func sendKeyTap(_ code: Int, delay: Double, modifier: Int? = nil) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        if let m = modifier { ipaduae_send_key(Int32(m), 1) }
        ipaduae_send_key(Int32(code), 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            ipaduae_send_key(Int32(code), 0)
            if let m = modifier { ipaduae_send_key(Int32(m), 0) }
        }
    }
}

struct OverlayRoot: View {
    let sizeChanged: (CGSize) -> Void
    @ObservedObject private var state = OverlayState.shared
    private var expanded: Bool { state.expanded }

    // The gear dims to a subtle ghost when idle so it doesn't block the
    // Amiga screen, and returns to full opacity on tap. A larger invisible
    // hit area keeps it easy to find even while faded.
    @State private var faded = false
    @State private var fadeWork: DispatchWorkItem?

    private func wake() {
        fadeWork?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { faded = false }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 1.2)) { faded = true }
        }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: work)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    state.expanded.toggle()
                    state.dismissFirstRunHint()
                    state.dismissRecoveryNotice()
                    NSLog("iPadUAE overlay: menu %@", expanded ? "opened" : "closed")
                    wake()
                } label: {
                    Image(systemName: expanded ? "xmark" : "gearshape.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background((expanded ? Color.red.opacity(0.7)
                                             : Color.black.opacity(0.35)), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                // Stay fully visible (skip the idle fade) while the
                // first-run hint is pointing at this exact button.
                .opacity(expanded ? 1.0 : (faded && !state.showFirstRunHint ? 0.18 : 0.85))
                .interactiveArea("gear")
                .onAppear(perform: wake)


                if state.showFirstRunHint && !expanded {
                    HStack(spacing: 6) {
                        Text("Tap here to add a disk or hard drive")
                            .font(.footnote.weight(.medium))
                        Image(systemName: "arrow.turn.right.up")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 6)
                    .transition(.opacity)
                }

                if state.showRecoveryNotice && !expanded {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle")
                        Text("Undid the last machine/disk change —\nthe app couldn't start with it")
                            .font(.footnote.weight(.medium))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 6)
                    .transition(.opacity)
                }

                if let notice = state.importNotice, !expanded {
                    HStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill")
                        Text(notice).font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 6)
                    .transition(.opacity)
                }

                if expanded {
                    ControlPanel()
                        .frame(width: 352)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)
                        .interactiveArea("panel")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            // Inset from the top-right corner so the gear/close button clears
            // the rounded corner and is comfortably reachable (was flush in
            // the corner, too tight on 11" iPads).
            .padding(.top, 10)
            .padding(.trailing, 18)
            .padding(.bottom, 12)
            // The menu must always draw (and hit-test) above the input
            // overlays — a keyboard covering the open menu makes it unusable.
            .zIndex(10)

            // Must draw and hit-test above the input overlays, same as the
            // menu — a keyboard covering its own toggle would be absurd.
            QuickControls(faded: faded, wake: wake)
                .zIndex(9)
            QuickDisk(faded: faded, wake: wake)
                .zIndex(9)
            QuickDisplay(faded: faded, wake: wake)
                .zIndex(9)

            if state.showJoystick {
                VStack {
                    Spacer()
                    VirtualJoystickView()
                }
                .opacity(state.overlayOpacity)
            }

            if state.showKeyboard {
                GeometryReader { geo in
                    VStack {
                        Spacer()
                        // iPhone only: cap the keyboard so the emulator
                        // stays visible. iPad keeps its full-size keys
                        // unconditionally (maxHeight stays .infinity).
                        AmigaKeyboardView(maxHeight: UIDevice.current.userInterfaceIdiom == .phone
                                          ? geo.size.height * 0.48 : .infinity)
                            .interactiveArea("keyboard")
                            // Report the strip the keyboard occupies so the
                            // core lays the picture out above it instead of
                            // underneath (the r/amiga portrait request).
                            // Every layout pass re-reports; cheap & idempotent.
                            .background(GeometryReader { kb -> Color in
                                let frac = state.keyboardOverlayStyle ? 0
                                    : (geo.size.height - kb.frame(in: .global).minY)
                                      / max(geo.size.height, 1)
                                // Its OWN height, not a screen-minus-origin
                                // subtraction: geo is safe-area-inset while
                                // .global is full-screen, and mixing them put
                                // the quick button on top of Esc on iPhone.
                                let h = kb.size.height
                                DispatchQueue.main.async {
                                    // Guard: this block is queued from a
                                    // layout pass, and onDisappear may run
                                    // before it does. Without the check a
                                    // stale inset is restored AFTER the
                                    // keyboard is gone, and the picture
                                    // stays laid out above a keyboard that
                                    // is not there — permanent black band.
                                    guard state.showKeyboard else { return }
                                    ipaduae_set_bottom_inset(Float(max(0, min(0.7, frac))))
                                    state.keyboardHeight = max(0, h)
                                }
                                return Color.clear
                            })
                            .padding(.bottom, state.showJoystick
                                     ? (inputCompact ? 140 : 200) : 12)
                            .padding(.horizontal, 12)
                    }
                }
                .opacity(state.overlayOpacity)
                .onDisappear {
                    ipaduae_set_bottom_inset(0)
                    state.keyboardHeight = 0
                }
            }

            if state.showNumpad {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NumpadView()
                            .interactiveArea("numpad")
                            .padding(.trailing, 16)
                            .padding(.bottom, state.showJoystick
                                     ? (inputCompact ? 140 : 200)
                                     : (inputCompact ? 24 : 60))
                    }
                }
                .opacity(state.overlayOpacity)
            }

            if state.showFKeys {
                VStack {
                    HStack {
                        Spacer()
                        FunctionKeyBar()
                            .interactiveArea("fkeys")
                        Spacer()
                    }
                    .padding(.top, 8)
                    Spacer()
                }
                .opacity(state.overlayOpacity)
            }
        }
        .tint(.red)
    }
}

/// How far up from the bottom a corner control must sit to clear whatever
/// overlay is showing. Shared by both bottom clusters.
///
/// Takes the maximum rather than the first match: the keyboard and the
/// joystick can be up together, and when they are the keyboard sits above
/// the D-pad and is the taller obstacle.
func overlayBottomClearance(_ state: OverlayState) -> CGFloat {
    var pad: CGFloat = 16
    if state.showJoystick {
        pad = max(pad, inputCompact ? 150 : 190)
    }
    if state.showKeyboard && state.keyboardHeight > 0 {
        let keyboardBottomInset: CGFloat = state.showJoystick
            ? (inputCompact ? 140 : 200) : 12
        pad = max(pad, state.keyboardHeight + keyboardBottomInset + 12)
    }
    return pad
}

/// Quick controls, bottom-left — the mirror of the gear.
///
/// The gear is for setup; this is for the things you flip mid-session.
/// One tap shows or hides the Amiga keyboard, which is by far the most
/// common thing to want and previously took three taps through the menu
/// (gear → Input & Overlays → Amiga Keyboard). A long press opens the
/// rest of the overlays.
///
/// Placement has to dodge two things it would otherwise sit under: the
/// keyboard covers the bottom strip, and the virtual joystick's D-pad
/// lives in this exact corner. It lifts clear of whichever is showing.
struct QuickControls: View {
    @ObservedObject private var state = OverlayState.shared
    let faded: Bool
    let wake: () -> Void

    private var bottomPadding: CGFloat { overlayBottomClearance(state) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)

            if state.quickExpanded {
                quickButton("number.square", on: state.showNumpad, id: "quick-numpad") {
                    state.showNumpad.toggle()
                }
                quickButton("f.cursive", on: state.showFKeys, id: "quick-fkeys") {
                    state.showFKeys.toggle()
                }
                quickButton("gamecontroller", on: state.showJoystick, id: "quick-joy") {
                    state.showJoystick.toggle()
                }
            }

            // Primary: one tap toggles the keyboard. Long press reveals
            // the rest rather than adding a second permanent button.
            Button {
                state.showKeyboard.toggle()
                wake()
            } label: {
                Image(systemName: state.showKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background((state.showKeyboard ? Color.red.opacity(0.7)
                                                    : Color.black.opacity(0.35)), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) { state.quickExpanded.toggle() }
                    wake()
                }
            )
            .opacity(state.showKeyboard || state.quickExpanded ? 1.0 : (faded ? 0.18 : 0.85))
            .interactiveArea("quick-keyboard")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 18)
        .padding(.bottom, bottomPadding)
        .animation(.easeOut(duration: 0.2), value: state.showKeyboard)
        .animation(.easeOut(duration: 0.2), value: state.showJoystick)
    }

    private func quickButton(_ icon: String, on: Bool, id: String,
                             action: @escaping () -> Void) -> some View {
        Button {
            action()
            wake()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background((on ? Color.red.opacity(0.7) : Color.black.opacity(0.35)), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .interactiveArea(id)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Display settings, top-left — the fourth corner.
///
/// The gear (top-right) is for setup, the quick controls (bottom-left)
/// for input, the disk (bottom-right) for media. Display was the one
/// thing you still had to open the menu for, and it is the one people
/// fiddle with while looking at the picture — which is precisely when a
/// modal menu covering that picture is useless.
///
/// One tap flips Picture between Fit and Stretch; that is the lever for
/// "why is there so much black", which on a phone in portrait is a
/// question the geometry guarantees somebody asks. Long press reveals
/// the rest, matching the quick-controls idiom rather than inventing a
/// second one.
///
/// Expands downward, since it hangs from the top edge. TV Out stays in
/// the menu deliberately — it is a connect-time decision, not something
/// flipped mid-session.
struct QuickDisplay: View {
    @ObservedObject private var state = OverlayState.shared
    let faded: Bool
    let wake: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                state.aspectFit.toggle()
                UserDefaults.standard.set(state.aspectFit, forKey: "aspectFit")
                ipaduae_set_aspect_fit(state.aspectFit ? 1 : 0)
                wake()
            } label: {
                Image(systemName: state.aspectFit ? "aspectratio" : "aspectratio.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background((state.aspectFit ? Color.red.opacity(0.7)
                                                 : Color.black.opacity(0.35)), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) { state.quickDisplayExpanded.toggle() }
                    wake()
                }
            )
            .opacity(state.quickDisplayExpanded ? 1.0 : (faded ? 0.18 : 0.85))
            .interactiveArea("quick-display")

            if state.quickDisplayExpanded {
                quickButton(state.fullscreenDisplay ? "rectangle.inset.filled" : "rectangle",
                            on: state.fullscreenDisplay, id: "quick-fullscreen") {
                    state.fullscreenDisplay.toggle()
                    UserDefaults.standard.set(state.fullscreenDisplay, forKey: "fullscreenDisplay")
                    ipaduae_set_safe_area(state.fullscreenDisplay ? 0 : 1)
                }
                quickButton(state.crtLevel > 0 ? "tv.fill" : "tv",
                            on: state.crtLevel > 0, id: "quick-crt") {
                    // Same 4-step cycle as the menu row; crtLevel's didSet
                    // persists and pushes to the core.
                    state.crtLevel = (state.crtLevel + 1) % 4
                }
                quickButton(state.showLEDs ? "circle.grid.2x1.fill" : "circle.grid.2x1",
                            on: state.showLEDs, id: "quick-leds") {
                    state.showLEDs.toggle()
                    UserDefaults.standard.set(state.showLEDs, forKey: "showLEDs")
                    ipaduae_set_leds(state.showLEDs ? 1 : 0)
                    ConfigStore.set("show_leds", state.showLEDs ? "true" : "false")
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 10)
        .padding(.leading, 18)
        .animation(.easeOut(duration: 0.2), value: state.quickDisplayExpanded)
        .animation(.easeOut(duration: 0.2), value: state.aspectFit)
    }

    private func quickButton(_ icon: String, on: Bool, id: String,
                             action: @escaping () -> Void) -> some View {
        Button {
            action()
            wake()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 34, height: 34)
                .background((on ? Color.red.opacity(0.7) : Color.black.opacity(0.35)), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .interactiveArea(id)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Disk access, bottom-right — swap media without opening the menu.
///
/// Inserting a disk is the single most common thing anyone does with an
/// emulator, and it was buried behind gear → Insert DF0… → pick. Eight
/// menu rows existed purely for insert/eject across four drives; this
/// replaces all of them.
///
/// Sits opposite the quick controls and clears the same obstacles — note
/// the joystick's FIRE button lives in this corner, not just the D-pad.
struct QuickDisk: View {
    @ObservedObject private var state = OverlayState.shared
    let faded: Bool
    let wake: () -> Void

    @State private var drive = 0
    @State private var showingCDs = false
    @State private var refresh = 0

    private var floppyDir: URL { ConfigStore.floppiesDir }

    private var images: [URL] {
        showingCDs
            ? ConfigStore.mediaFiles(in: ConfigStore.cdsDir,
                                     extensions: ["cue", "ccd", "mds", "nrg", "iso", "chd"])
            : ConfigStore.mediaFiles(in: floppyDir,
                                     extensions: ["adf", "adz", "dms", "ipf", "zip", "gz",
                                                  "lha", "lzh", "lzx", "7z"])
    }

    /// What the selected drive currently holds — read from the CORE, not
    /// the config. Inserting goes through disk_insert() and never writes
    /// the config, so the config says "empty" no matter what is in the
    /// drive.
    private var mounted: String? {
        if showingCDs { return ConfigStore.currentCD }
        guard let c = ipaduae_floppy_name(Int32(drive)) else { return nil }
        return String(cString: c)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Spacer(minLength: 0)

            if state.diskExpanded {
                panel
                    .frame(width: 300)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 8)
                    .interactiveArea("disk-panel")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button {
                withAnimation(.easeOut(duration: 0.15)) { state.diskExpanded.toggle() }
                refresh += 1
                wake()
            } label: {
                Image(systemName: state.diskExpanded ? "xmark" : "opticaldiscdrive")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .background((state.diskExpanded ? Color.red.opacity(0.7)
                                                    : Color.black.opacity(0.35)), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(state.diskExpanded ? 1.0 : (faded ? 0.18 : 0.85))
            .interactiveArea("disk-button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 18)
        .padding(.bottom, overlayBottomClearance(state))
        .animation(.easeOut(duration: 0.2), value: state.showKeyboard)
        .animation(.easeOut(duration: 0.2), value: state.showJoystick)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("", selection: $showingCDs) {
                Text("Floppies").tag(false)
                Text("CDs").tag(true)
            }
            .pickerStyle(.segmented)

            // Drive selector only when there is a choice to make.
            if !showingCDs && state.floppyDrives > 1 {
                Picker("", selection: $drive) {
                    ForEach(0..<state.floppyDrives, id: \.self) { d in
                        Text("DF\(d)").tag(d)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Floppy speed lives here, not in the Machine panel. Among CPU
            // and RAM settings "speed" reads as machine speed; next to the
            // disks it can only mean one thing.
            if !showingCDs {
                Picker("", selection: Binding(
                    get: { state.floppySpeed },
                    set: { state.applyFloppySpeed($0) })) {
                    Text("1×").tag(100)
                    Text("2×").tag(200)
                    Text("4×").tag(400)
                    Text("8×").tag(800)
                    Text("Turbo").tag(0)
                }
                .pickerStyle(.segmented)
                Text(state.floppySpeed == 100
                     ? "Drive speed: real hardware timing."
                     : (state.floppySpeed == 0
                        ? "Drive speed: turbo — loads complete instantly. Copy-protected disks fall back to real speed on their own."
                        : "Drive speed: faster loading. Sound and picture are unaffected."))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if let mounted {
                MenuRow(icon: "eject", title: "Eject — \(URL(fileURLWithPath: mounted).lastPathComponent)") {
                    if showingCDs {
                        ConfigStore.ejectCD()
                    } else {
                        ipaduae_eject_floppy(Int32(drive))
                    }
                    // disk_eject is queued into the emulator; re-read a
                    // moment later so the row reflects reality.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { refresh += 1 }
                }
            }

            if images.isEmpty {
                Text(showingCDs
                     ? "No CD images. Drop .cue/.iso/.chd into Files › Amigo › CDs, or drag one onto the screen."
                     : "No disk images. Drop .adf files into Files › Amigo › Floppies, or drag one onto the screen.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(images, id: \.self) { url in
                        let isIn = mounted.map { $0 == url.path } ?? false
                        MenuRow(icon: isIn ? "checkmark.circle.fill"
                                           : (showingCDs ? "opticaldisc" : "opticaldiscdrive"),
                                title: ConfigStore.relativeName(
                                    url, in: showingCDs ? ConfigStore.cdsDir : floppyDir),
                                active: isIn ? true : nil) {
                            if showingCDs {
                                ConfigStore.mountCD(url: url)
                            } else {
                                NSLog("iPadUAE quickdisk: insert DF%d %@", drive, url.path)
                                ipaduae_insert_floppy(Int32(drive), url.path)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { refresh += 1 }
                            }
                            withAnimation { state.diskExpanded = false }
                        }
                    }
                }
            }
            .frame(maxHeight: 260)

            if showingCDs {
                Text("Inserting a CD restarts the Amiga.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .id(refresh)
    }
}

struct ControlPanel: View {
    enum Submenu { case none, df0, df1, df2, df3, kickstart, harddrive, cdrom, machine, controller, configs, states, cloud, clipboard, display, inputs, help, about }
    @State private var submenu: Submenu = .none
    @ObservedObject private var state = OverlayState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch submenu {
            // The main menu outgrew small screens (11" landscape: the panel
            // ran off the bottom and pushed the close button into the status
            // bar). Render it plain when it fits, scrollable when it doesn't.
            case .none:
                ViewThatFits(in: .vertical) {
                    mainMenu
                    ScrollView { mainMenu }
                }
            case .df0: FloppyPicker(drive: 0) { submenu = .none }
            case .df1: FloppyPicker(drive: 1) { submenu = .none }
            case .df2: FloppyPicker(drive: 2) { submenu = .none }
            case .df3: FloppyPicker(drive: 3) { submenu = .none }
            case .kickstart: KickstartPicker { submenu = .none }
            case .harddrive: HardDrivePicker { submenu = .none }
            case .cdrom: CDPicker { submenu = .none }
            case .machine: MachinePanel { submenu = .none }
            case .controller: ControllerPanel { submenu = .none }
            case .configs: ConfigurationsPanel { submenu = .none }
            case .states: StatePanel { submenu = .none }
            case .cloud: CloudPanel { submenu = .none }
            case .clipboard: ClipboardPanel { submenu = .none }
            case .display: DisplayPanel { submenu = .none }
            case .inputs: InputPanel { submenu = .none }
            case .help: HelpPanel { submenu = .none }
            case .about: AboutPanel { submenu = .none }
            }
        }
        .padding(12)
    }

    private var mainMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Amigo").font(.headline).padding(.bottom, 6)
            // Inserting and ejecting moved to the disk button, bottom-right
            // — eight rows for four drives, replaced by the thing people
            // actually reach for mid-game.
            // Drive count is a property of the machine, so it is set in
            // the Machine panel; multi-disk games are the reason anyone
            // wants more than two.
            MenuRow(icon: "tray.and.arrow.down", title: "Import Files (disks, ROMs, HDFs)…") {
                MediaPickerPresenter.shared.present()
            }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "memorychip", title: "Kickstart ROM…") { submenu = .kickstart }
            MenuRow(icon: "internaldrive", title: "Hard Drives…") { submenu = .harddrive }
            MenuRow(icon: "opticaldisc", title: "CD-ROM & CD32 Console…") { submenu = .cdrom }
            MenuRow(icon: "cpu", title: "Machine (CPU / RAM / RTG / Net)…") { submenu = .machine }
            // "Controller (CD32 pad)…" read as CD32-only: users asking for
            // gamepad support scanned right past it. CD32 mode lives inside
            // the panel; the row says what people are looking for.
            MenuRow(icon: "gamecontroller", title: "Game Controller (Bluetooth/USB)…") { submenu = .controller }
            MenuRow(icon: "square.stack.3d.up", title: "Configurations (save/load setups)…") { submenu = .configs }
            MenuRow(icon: "clock.arrow.circlepath", title: "Save States…") { submenu = .states }
            MenuRow(icon: "icloud", title: "iCloud Sync…") { submenu = .cloud }
            MenuRow(icon: "doc.on.clipboard", title: "Clipboard (copy/paste with iOS)…") { submenu = .clipboard }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "display", title: "Display (picture, CRT, TV out)…") { submenu = .display }
            MenuRow(icon: "hand.tap", title: "Input & Overlays (keyboard, joystick)…") { submenu = .inputs }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "arrow.counterclockwise", title: "Reset") { ipaduae_reset(0) }
            MenuRow(icon: "exclamationmark.arrow.circlepath", title: "Hard Reset") { ipaduae_reset(1) }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "questionmark.circle", title: "Controls & Help…") { submenu = .help }
            MenuRow(icon: "info.circle", title: "About & Licenses…") { submenu = .about }
            Text("Add disks & Kickstart ROMs via Files:\nOn My iPad › Amigo")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Everything that changes how the picture looks. Split out of the main
/// menu, which had grown to 36 rows.
struct DisplayPanel: View {
    let onDone: () -> Void
    @ObservedObject private var state = OverlayState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Display").font(.headline)
            }
            .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MenuRow(icon: state.crtLevel > 0 ? "tv.fill" : "tv",
                            title: {
                                switch state.crtLevel {
                                case 1: return "CRT Scanlines: Light"
                                case 2: return "CRT Scanlines: Medium"
                                case 3: return "CRT Scanlines: Heavy"
                                default: return "CRT Scanlines: Off"
                                }
                            }(),
                            active: state.crtLevel > 0) {
                        state.crtLevel = (state.crtLevel + 1) % 4
                    }
                    MenuRow(icon: "speedometer",
                            title: state.vsync ? "Display Sync: On (smooth)" : "Display Sync: Off (fast)",
                            active: state.vsync) {
                        state.vsync.toggle()
                        UserDefaults.standard.set(state.vsync, forKey: "vsync")
                        ipaduae_set_vsync(state.vsync ? 1 : 0)
                    }
                    MenuRow(icon: state.rtgAccel ? "bolt.fill" : "bolt.slash",
                            title: state.rtgAccel ? "RTG Accel: On (fast)" : "RTG Accel: Off (correct >8-bit)",
                            active: state.rtgAccel) {
                        state.rtgAccel.toggle()
                        UserDefaults.standard.set(state.rtgAccel, forKey: "rtgAccel")
                        ipaduae_set_rtg_accel(state.rtgAccel ? 1 : 0)
                    }
                    MenuRow(icon: state.showLEDs ? "circle.grid.2x1.fill" : "circle.grid.2x1",
                            title: state.showLEDs ? "Hide LED Bar" : "Show LED Bar",
                            active: state.showLEDs) {
                        state.showLEDs.toggle()
                        UserDefaults.standard.set(state.showLEDs, forKey: "showLEDs")
                        ipaduae_set_leds(state.showLEDs ? 1 : 0)
                        ConfigStore.set("show_leds", state.showLEDs ? "true" : "false")
                    }
                    MenuRow(icon: state.fullscreenDisplay ? "rectangle.inset.filled" : "rectangle",
                            title: state.fullscreenDisplay ? "Display: Fullscreen (corners may crop)" : "Display: Safe Area",
                            active: state.fullscreenDisplay) {
                        state.fullscreenDisplay.toggle()
                        UserDefaults.standard.set(state.fullscreenDisplay, forKey: "fullscreenDisplay")
                        ipaduae_set_safe_area(state.fullscreenDisplay ? 0 : 1)
                    }
                    MenuRow(icon: state.aspectFit ? "aspectratio" : "aspectratio.fill",
                            title: state.aspectFit ? "Picture: Fit (keeps proportions)" : "Picture: Stretch (fills screen)",
                            active: state.aspectFit) {
                        state.aspectFit.toggle()
                        UserDefaults.standard.set(state.aspectFit, forKey: "aspectFit")
                        ipaduae_set_aspect_fit(state.aspectFit ? 1 : 0)
                    }
                    MenuRow(icon: "tv", title: state.externalDisplay ? "TV Out: On (when connected)" : "TV Out: Off",
                            active: state.externalDisplay) {
                        state.externalDisplay.toggle()
                        UserDefaults.standard.set(state.externalDisplay, forKey: "externalDisplay")
                        ipaduae_set_external_display(state.externalDisplay ? 1 : 0)
                    }
                }
            }
            .frame(maxHeight: 460)
        }
    }
}

/// Keyboard, joystick and the on-screen overlays.
struct InputPanel: View {
    let onDone: () -> Void
    @ObservedObject private var state = OverlayState.shared
    /// Polled while the panel is open: mousehack goes live a moment after
    /// the first touch, so a single read at render time would mislead.
    @State private var mousehackLive = ipaduae_mousehack_alive() != 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Input & Overlays").font(.headline)
            }
            .padding(.bottom, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if FloppyHaptics.supported {
                        MenuRow(icon: state.floppyHaptics ? "waveform" : "waveform.slash",
                                title: state.floppyHaptics ? "Floppy Haptics: On" : "Floppy Haptics: Off",
                                active: state.floppyHaptics) {
                            state.floppyHaptics.toggle()
                        }
                    }
                    MenuRow(icon: state.autoFireRate > 0 ? "bolt.horizontal.fill" : "bolt.horizontal",
                            title: state.autoFireRate == 0
                                ? "Auto-Fire: Off (hold to fire)"
                                : "Auto-Fire: \(state.autoFireRate)/sec",
                            active: state.autoFireRate > 0) {
                        // Off → 6 → 10 → 15 → off. 6 is comfortable for
                        // shooters, 15 is about as fast as an Amiga game
                        // will register.
                        switch state.autoFireRate {
                        case 0:  state.autoFireRate = 6
                        case 6:  state.autoFireRate = 10
                        case 10: state.autoFireRate = 15
                        default: state.autoFireRate = 0
                        }
                    }
                    MenuRow(icon: state.tabletMode ? "hand.point.up.left.fill" : "hand.point.up.left",
                            title: state.tabletMode
                                ? (mousehackLive ? "1:1 Mouse: On" : "1:1 Mouse: On — not active")
                                : "1:1 Mouse: Off (relative/trackpad)",
                            active: state.tabletMode) {
                        state.tabletMode.toggle()
                        ConfigStore.setTabletMode(state.tabletMode)
                    }
                    // 1:1 needs the guest mousehack driver (Kickstart
                    // 2.0+). On 1.3 the core silently falls back to
                    // relative drag-and-hold while this row still said
                    // "On" — reported from EAB as "1:1 touch doesn't
                    // seem to work".
                    if state.tabletMode {
                        Text(mousehackLive
                             ? "Active — the pointer follows your finger exactly."
                             : "Not active yet. 1:1 needs Kickstart 2.0 or newer; on Kickstart 1.3 touch falls back to drag-and-hold, which still draws and moves icons. On a capable ROM it turns active as soon as you touch the screen.")
                            .font(.caption)
                            .foregroundStyle(mousehackLive ? AnyShapeStyle(.secondary)
                                                           : AnyShapeStyle(.orange))
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                            .onReceive(tick) { _ in
                                mousehackLive = ipaduae_mousehack_alive() != 0
                            }
                    }
                    MenuRow(icon: state.penPressure ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle",
                            title: state.penPressure
                                ? "Pencil Pressure: On"
                                : "Pencil Pressure: Off",
                            active: state.penPressure) {
                        state.penPressure.toggle()
                        ConfigStore.setPenPressure(state.penPressure)
                    }
                    // The library the Amiga side opens is installed by the
                    // boot ROM at reset, so this cannot be a live toggle
                    // like 1:1 Mouse above it.
                    Text(state.penPressure
                         ? "On. Deluxe Paint and other programs that read tablet pressure follow the Pencil's tip force. Restart the Amiga to apply."
                         : "Off — paint programs see a plain mouse. Switch on for Pencil pressure in Deluxe Paint and the like, then restart the Amiga.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    MenuRow(icon: state.serialTablet ? "cable.connector.horizontal" : "cable.connector",
                            title: state.serialTablet
                                ? "Serial Tablet: On (Wacom)"
                                : "Serial Tablet: Off",
                            active: state.serialTablet) {
                        state.serialTablet.toggle()
                        ConfigStore.setSerialTablet(state.serialTablet)
                    }
                    Text(state.serialTablet
                         ? "On. The Pencil is a Wacom tablet on the serial port. In TVPaint set the tablet Type to \"Wacom A4+ Pressure\". Restart the Amiga to apply."
                         : "Off — the serial port is empty. Switch on for TVPaint and other programs that drive a tablet themselves, then restart the Amiga.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    MenuRow(icon: "keyboard", title: state.showKeyboard ? "Hide Amiga Keyboard" : "Amiga Keyboard",
                            active: state.showKeyboard) {
                        state.showKeyboard.toggle()
                    }
                    MenuRow(icon: state.keyboardOverlayStyle ? "square.on.square" : "rectangle.bottomthird.inset.filled",
                            title: state.keyboardOverlayStyle ? "Keyboard Style: Overlay (see-through)"
                                                              : "Keyboard Style: Screen above",
                            active: !state.keyboardOverlayStyle) {
                        state.keyboardOverlayStyle.toggle()
                        UserDefaults.standard.set(state.keyboardOverlayStyle, forKey: "keyboardOverlayStyle")
                    }
                    MenuRow(icon: "f.cursive", title: state.showFKeys ? "Hide Function Keys" : "Function Keys (F1–F10)",
                            active: state.showFKeys) {
                        state.showFKeys.toggle()
                    }
                    MenuRow(icon: "number.square", title: state.showNumpad ? "Hide Numpad" : "Numpad (WHDLoad quit keys)",
                            active: state.showNumpad) {
                        state.showNumpad.toggle()
                    }
                    MenuRow(icon: "gamecontroller", title: state.showJoystick ? "Hide Joystick" : "Virtual Joystick",
                            active: state.showJoystick) {
                        state.showJoystick.toggle()
                    }
                    // Overlay transparency: applies to keyboard/numpad/F-keys/joystick.
                    HStack(spacing: 10) {
                        Image(systemName: "circle.lefthalf.filled").frame(width: 22)
                        Slider(value: Binding(
                            get: { state.overlayOpacity },
                            set: {
                                state.overlayOpacity = $0
                                UserDefaults.standard.set($0, forKey: "overlayOpacity")
                            }), in: 0.25...1.0)
                        Text("\(Int(state.overlayOpacity * 100)) %")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxHeight: 460)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    /// nil = plain action row; true/false = a toggle showing its state.
    var active: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(active == true ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                Text(title)
                Spacer()
                if let active {
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(active ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

struct KickstartPicker: View {
    let onDone: () -> Void
    private var roms: [URL] {
        ConfigStore.mediaFiles(in: ConfigStore.kickstartsDir,
                               extensions: ["rom", "bin", "zip", "lha", "7z",
                                            "a500", "a600", "a1200", "a4000"])
    }
    private var current: String { ConfigStore.currentValue("kickstart_rom_file") ?? ":AROS" }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Kickstart").font(.headline)
            }
            .padding(.bottom, 6)
            Text("Changing the ROM restarts the Amiga.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)

            MenuRow(icon: current == ":AROS" ? "checkmark.circle.fill" : "circle",
                    title: "Built-in AROS ROM") {
                ConfigStore.selectBuiltInAROS()
                onDone()
            }
            if roms.isEmpty {
                Text("No ROM files found.\nDrop Kickstart images into Files › Amigo › Kickstarts, or use Import Files… in the gear menu.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            } else if current == ":AROS" {
                // The single most common onboarding failure: the ROM is
                // imported, listed here, and never tapped. Say it where it
                // is about to happen.
                Text("Your ROM is imported but AROS is still selected — tap the ROM below to use it. Most original floppy games need a real Kickstart.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 4)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roms, id: \.self) { url in
                        MenuRow(icon: current == url.path ? "checkmark.circle.fill" : "memorychip",
                                title: ConfigStore.relativeName(url, in: ConfigStore.kickstartsDir)) {
                            ConfigStore.selectKickstart(path: url.path)
                            onDone()
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
            if !roms.isEmpty {
                Text("After choosing a ROM, pick a matching Machine preset: A500 for most floppy games, A1200 for AGA titles and WHDLoad. Amiga Forever ROMs need their rom.key file in the same folder.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
    }
}

/// Game-controller routing. Persisted in UserDefaults and re-applied to
/// the core at overlay install and on every change; the core itself
/// re-applies on controller connect/disconnect.
struct ControllerPanel: View {
    let onDone: () -> Void
    @State private var port = UserDefaults.standard.object(forKey: "controllerPort") as? Int ?? 1
    @State private var cd32 = UserDefaults.standard.bool(forKey: "controllerCD32")
    @State private var autofire = UserDefaults.standard.bool(forKey: "controllerAutofire")

    static func applyStored() {
        let port = UserDefaults.standard.object(forKey: "controllerPort") as? Int ?? 1
        ipaduae_set_controller(Int32(port),
                               UserDefaults.standard.bool(forKey: "controllerCD32") ? 1 : 0,
                               UserDefaults.standard.bool(forKey: "controllerAutofire") ? 1 : 0)
    }

    private func apply() {
        UserDefaults.standard.set(port, forKey: "controllerPort")
        UserDefaults.standard.set(cd32, forKey: "controllerCD32")
        UserDefaults.standard.set(autofire, forKey: "controllerAutofire")
        ipaduae_set_controller(Int32(port), cd32 ? 1 : 0, autofire ? 1 : 0)
    }

    private var connectedName: String? {
        ipaduae_controller_name().map { String(cString: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Game Controller").font(.headline)
            }
            .padding(.bottom, 6)

            if let name = connectedName {
                Label(name, systemImage: "gamecontroller.fill")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)
            } else {
                Text("No controller connected.\nPair one in Settings › Bluetooth, or plug it into USB-C — it is picked up automatically.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)
            }

            // UAE joyport1 is the physical Amiga joystick port (port 2 on
            // the case); joyport0 is the mouse port (port 1).
            MenuRow(icon: port == 1 ? "checkmark.circle.fill" : "circle",
                    title: "Joystick Port — games (default)") { port = 1; apply() }
            MenuRow(icon: port == 0 ? "checkmark.circle.fill" : "circle",
                    title: "Mouse Port — replaces mouse") { port = 0; apply() }
            MenuRow(icon: port == -1 ? "checkmark.circle.fill" : "circle",
                    title: "Off — use on-screen joystick") { port = -1; apply() }

            Divider().padding(.vertical, 4)

            MenuRow(icon: cd32 ? "checkmark.circle.fill" : "circle",
                    title: "CD32 Pad Mode (red/blue/… buttons)",
                    active: cd32) { cd32.toggle(); apply() }
            MenuRow(icon: autofire ? "checkmark.circle.fill" : "circle",
                    title: "Autofire",
                    active: autofire) { autofire.toggle(); apply() }

            Text("CD32 mode gives games the 7-button CD32 pad. Plain joystick mode is right for most Amiga games.")
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
        }
    }
}

struct HardDrivePicker: View {
    let onDone: () -> Void
    private var images: [URL] {
        ConfigStore.mediaFiles(in: ConfigStore.hardDrivesDir, extensions: ["hdf", "hdz", "vhd"])
    }
    private var mounted: [ConfigStore.MountedDrive] { ConfigStore.mountedHardfiles }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Hard Drives").font(.headline)
            }
            .padding(.bottom, 6)
            Text("Mount several HDF images at once — they appear as DH0:, DH1:, DH2:… Adding or ejecting one restarts the Amiga.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)

            // The fresh-install footgun: most ready-made Workbench images
            // are built for RTG, and with no graphics card configured they
            // boot to a PAL screen (or nothing recognisable) with no clue
            // why. Cheaper to say so here than to have someone conclude
            // the image is broken.
            if !mounted.isEmpty && (Int(ConfigStore.currentValue("gfxcard_size") ?? "0") ?? 0) == 0 {
                Text("No RTG graphics card is configured. Workbench images built for RTG (most 3.x installs) will not reach their normal screen — set Machine → RTG Graphics Card to 16 MB.")
                    .font(.caption).foregroundStyle(.orange)
                    .padding(.horizontal, 4).padding(.bottom, 4)
            }

            if !mounted.isEmpty {
                Text("MOUNTED").font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).padding(.top, 2)
                ForEach(mounted) { drive in
                    MenuRow(icon: "eject",
                            title: "\(drive.volume)  \(drive.name)",
                            active: true) {
                        ConfigStore.unmountHardfile(unit: drive.unit)
                        onDone()
                    }
                }
                if mounted.count > 1 {
                    MenuRow(icon: "eject.fill", title: "Eject All (\(mounted.count))") {
                        ConfigStore.unmountAllHardfiles()
                        onDone()
                    }
                }
                Divider().padding(.vertical, 4)
            }

            if images.isEmpty {
                Text("No HDF images found.\nDrop .hdf files into Files › Amigo › HardDrives.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                Text(mounted.isEmpty ? "AVAILABLE" : "ADD ANOTHER")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary).padding(.top, 2)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(images, id: \.self) { url in
                        let isUp = ConfigStore.isMounted(url: url)
                        MenuRow(icon: isUp ? "checkmark.circle.fill" : "internaldrive",
                                title: ConfigStore.relativeName(url, in: ConfigStore.hardDrivesDir)
                                    + (isUp ? "  · mounted" : ""),
                                active: isUp) {
                            // Mounting an already-mounted image would give
                            // the Amiga two identical volumes; the row is a
                            // no-op rather than an error.
                            guard !isUp else { return }
                            ConfigStore.mountHardfile(url: url)
                            onDone()
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }
}

struct CDPicker: View {
    let onDone: () -> Void
    private var images: [URL] {
        ConfigStore.mediaFiles(in: ConfigStore.cdsDir,
                               extensions: ["cue", "ccd", "mds", "nrg", "iso", "chd"])
    }
    private var mounted: String? { ConfigStore.currentCD }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("CD-ROM").font(.headline)
            }
            .padding(.bottom, 6)
            Text("CDs are not just for the CD32 — CDTV and any Amiga with a CD drive can read them. Inserting one restarts the Amiga, and on a non-CD32 machine Amigo adds a SCSI CD drive so the Amiga can see it (you still need a CD filesystem in Workbench). For CD32 titles, switch on the console preset below.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)

            if !ConfigStore.cd32Active {
                MenuRow(icon: "gamecontroller",
                        title: "Switch to CD32 console…") {
                    ConfigStore.applyCD32()
                    onDone()
                }
                if !ConfigStore.cd32ROMLikelyPresent {
                    Text("No CD32 Kickstart found — put the CD32 ROM (and its extended ROM) into Files › Amigo › Kickstarts first, or the console can't start.")
                        .font(.footnote).foregroundStyle(.orange).padding(.bottom, 2)
                }
            } else {
                Text("CD32 console active — leave it via a preset in the Machine panel.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 2)
            }
            if mounted != nil {
                MenuRow(icon: "eject", title: "Eject CD") {
                    ConfigStore.ejectCD()
                    onDone()
                }
            }
            Divider().padding(.vertical, 4)
            if images.isEmpty {
                Text("No CD images found.\nDrop .cue (+bin), .ccd, .mds, .nrg or .iso files into Files › Amigo › CDs.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(images, id: \.self) { url in
                        MenuRow(icon: mounted?.contains(url.path) == true ? "checkmark.circle.fill" : "opticaldisc",
                                title: ConfigStore.relativeName(url, in: ConfigStore.cdsDir)) {
                            ConfigStore.mountCD(url: url)
                            onDone()
                        }
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }
}

struct FloppyPicker: View {
    let drive: Int
    let onDone: () -> Void

    private var floppyDir: URL {
        ConfigStore.winuaeDir.appendingPathComponent("Floppies")
    }

    private var images: [URL] {
        ConfigStore.mediaFiles(in: floppyDir,
                               extensions: ["adf", "adz", "dms", "ipf", "zip", "gz",
                                            "lha", "lzh", "lzx", "7z"])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) {
                    Label("Back", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Insert DF\(drive)").font(.headline)
            }
            .padding(.bottom, 6)

            if images.isEmpty {
                Text("No disk images found.\nDrop .adf files into Files › Amigo › Floppies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(images, id: \.self) { url in
                        MenuRow(icon: "opticaldiscdrive",
                                title: ConfigStore.relativeName(url, in: floppyDir)) {
                            NSLog("iPadUAE overlay: insert DF%d %@", drive, url.path)
                            ipaduae_insert_floppy(Int32(drive), url.path)
                            onDone()
                        }
                    }
                }
            }
            .frame(maxHeight: 460)
        }
    }
}
