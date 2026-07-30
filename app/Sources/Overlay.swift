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
    }

    // Autosave (quick-state slot 0): every 5 minutes while running, and a
    // best-effort save when the app is backgrounded (the queued save runs
    // if the emulator gets a few more frames during the transition).
    private var autosaveTimer: Timer?

    private func installAutosave() {
        let timer = Timer(timeInterval: 300, repeats: true) { _ in
            ipaduae_state_op(0, 1)
        }
        RunLoop.main.add(timer, forMode: .common)
        autosaveTimer = timer
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { _ in
            ipaduae_state_op(0, 1)
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
                let first = ((try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil)) ?? [])
                    .filter { ["adf", "adz", "dms"].contains($0.pathExtension.lowercased()) }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                    .first
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
    @Published var showJoystick = false
    @Published var showFKeys = false
    @Published var showNumpad = false
    @Published var fullscreenDisplay = UserDefaults.standard.bool(forKey: "fullscreenDisplay")
    @Published var showLEDs = UserDefaults.standard.object(forKey: "showLEDs") as? Bool ?? true
    @Published var rtgAccel = UserDefaults.standard.object(forKey: "rtgAccel") as? Bool ?? false
    @Published var vsync = UserDefaults.standard.object(forKey: "vsync") as? Bool ?? false
    @Published var tabletMode = ConfigStore.tabletMode
    // Default OFF, matching the core's default — see unix_video_external_enabled
    // in video_sdl.cpp for why auto-detection must not run on the very first
    // boot before this preference has a chance to sync.
    @Published var externalDisplay = UserDefaults.standard.object(forKey: "externalDisplay") as? Bool ?? false
    /// Opacity of the input overlays (keyboard, numpad, F-keys, joystick).
    /// Floor of 0.25 keeps them findable — invisible-but-touchable panels
    /// would eat emulator input with no visual explanation.
    @Published var overlayOpacity = UserDefaults.standard.object(forKey: "overlayOpacity") as? Double ?? 1.0
    /// Global frames of touch-interactive overlay elements, keyed by id.
    /// Read by PassthroughWindow.hitTest on every touch; written from
    /// SwiftUI geometry callbacks. Main-thread only.
    var interactiveRects: [String: CGRect] = [:]
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
                .opacity(expanded ? 1.0 : (faded ? 0.18 : 0.85))
                .interactiveArea("gear")
                .onAppear(perform: wake)

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

            if state.showJoystick {
                VStack {
                    Spacer()
                    VirtualJoystickView()
                }
                .opacity(state.overlayOpacity)
            }

            if state.showKeyboard {
                VStack {
                    Spacer()
                    AmigaKeyboardView()
                        .interactiveArea("keyboard")
                        .padding(.bottom, state.showJoystick ? 200 : 12)
                        .padding(.horizontal, 12)
                }
                .opacity(state.overlayOpacity)
            }

            if state.showNumpad {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NumpadView()
                            .interactiveArea("numpad")
                            .padding(.trailing, 16)
                            .padding(.bottom, state.showJoystick ? 200 : 60)
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

struct ControlPanel: View {
    enum Submenu { case none, df0, df1, kickstart, harddrive, machine, configs, states, about }
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
            case .kickstart: KickstartPicker { submenu = .none }
            case .harddrive: HardDrivePicker { submenu = .none }
            case .machine: MachinePanel { submenu = .none }
            case .configs: ConfigurationsPanel { submenu = .none }
            case .states: StatePanel { submenu = .none }
            case .about: AboutPanel { submenu = .none }
            }
        }
        .padding(12)
    }

    private var mainMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Amigo").font(.headline).padding(.bottom, 6)
            MenuRow(icon: "opticaldiscdrive", title: "Insert DF0…") { submenu = .df0 }
            MenuRow(icon: "opticaldiscdrive", title: "Insert DF1…") { submenu = .df1 }
            MenuRow(icon: "eject", title: "Eject DF0") { ipaduae_eject_floppy(0) }
            MenuRow(icon: "eject", title: "Eject DF1") { ipaduae_eject_floppy(1) }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "memorychip", title: "Kickstart ROM…") { submenu = .kickstart }
            MenuRow(icon: "internaldrive", title: "Hard Drive…") { submenu = .harddrive }
            MenuRow(icon: "cpu", title: "Machine (CPU / RAM / RTG / Net)…") { submenu = .machine }
            MenuRow(icon: "square.stack.3d.up", title: "Configurations (save/load setups)…") { submenu = .configs }
            MenuRow(icon: "clock.arrow.circlepath", title: "Save States…") { submenu = .states }
            Divider().padding(.vertical, 4)
            MenuRow(icon: state.vsync ? "speedometer" : "speedometer",
                    title: state.vsync ? "Speed: Smooth (vsync on)" : "Speed: Fast (vsync off)",
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
            MenuRow(icon: "tv", title: state.externalDisplay ? "TV Out: On (when connected)" : "TV Out: Off",
                    active: state.externalDisplay) {
                state.externalDisplay.toggle()
                UserDefaults.standard.set(state.externalDisplay, forKey: "externalDisplay")
                ipaduae_set_external_display(state.externalDisplay ? 1 : 0)
            }
            MenuRow(icon: state.tabletMode ? "hand.point.up.left.fill" : "hand.point.up.left",
                    title: state.tabletMode ? "1:1 Mouse: On" : "1:1 Mouse: Off (relative/trackpad)",
                    active: state.tabletMode) {
                state.tabletMode.toggle()
                ConfigStore.setTabletMode(state.tabletMode)
            }
            MenuRow(icon: "keyboard", title: state.showKeyboard ? "Hide Amiga Keyboard" : "Amiga Keyboard",
                    active: state.showKeyboard) {
                state.showKeyboard.toggle()
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
            Divider().padding(.vertical, 4)
            MenuRow(icon: "arrow.counterclockwise", title: "Reset") { ipaduae_reset(0) }
            MenuRow(icon: "exclamationmark.arrow.circlepath", title: "Hard Reset") { ipaduae_reset(1) }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "info.circle", title: "About & Licenses…") { submenu = .about }
            Text("Add disks & Kickstart ROMs via Files:\nOn My iPad › Amigo")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        ConfigStore.files(in: ConfigStore.kickstartsDir,
                          extensions: ["rom", "bin", "zip", "a500", "a600", "a1200", "a4000"])
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
                Text("No ROM files found.\nDrop Kickstart images into Files › Amigo › Kickstarts.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(roms, id: \.self) { url in
                        MenuRow(icon: current == url.path ? "checkmark.circle.fill" : "memorychip",
                                title: url.lastPathComponent) {
                            ConfigStore.selectKickstart(path: url.path)
                            onDone()
                        }
                    }
                }
            }
            .frame(maxHeight: 420)
        }
    }
}

struct HardDrivePicker: View {
    let onDone: () -> Void
    private var images: [URL] {
        ConfigStore.files(in: ConfigStore.hardDrivesDir, extensions: ["hdf", "hdz", "vhd"])
    }
    private var mounted: String? { ConfigStore.currentValue("hardfile2") }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Hard Drive").font(.headline)
            }
            .padding(.bottom, 6)
            Text("Mounts as DH0: and restarts the Amiga.")
                .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 4)

            if mounted != nil {
                MenuRow(icon: "eject", title: "Unmount Hard Drive") {
                    ConfigStore.unmountHardfile()
                    onDone()
                }
                Divider().padding(.vertical, 4)
            }
            if images.isEmpty {
                Text("No HDF images found.\nDrop .hdf files into Files › Amigo › HardDrives.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(images, id: \.self) { url in
                        MenuRow(icon: mounted?.contains(url.path) == true ? "checkmark.circle.fill" : "internaldrive",
                                title: url.lastPathComponent) {
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

struct FloppyPicker: View {
    let drive: Int
    let onDone: () -> Void

    private var floppyDir: URL {
        ConfigStore.winuaeDir.appendingPathComponent("Floppies")
    }

    private var images: [URL] {
        let exts = ["adf", "adz", "dms", "ipf", "zip", "gz"]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: floppyDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { exts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
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
                        MenuRow(icon: "opticaldiscdrive", title: url.lastPathComponent) {
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
