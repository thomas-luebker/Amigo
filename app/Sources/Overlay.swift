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
    DispatchQueue.main.async { OverlayInstaller.shared.installWhenReady() }
}

/// A window that only claims touches landing on actual overlay content;
/// everything else falls through to SDL's window below.
final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        // Taps on the hosting view's transparent background return the
        // hosting view itself; taps on real controls return inner views.
        if v === rootViewController?.view { return nil }
        return v
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
        NSLog("iPadUAE overlay: installing overlay window on scene")
        let host = UIHostingController(rootView: OverlayRoot { _ in })
        host.view.backgroundColor = .clear
        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .alert
        window.isHidden = false
        overlayWindow = window
        installDebugHooks()
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
                let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("WinUAE/Floppies")
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

    var body: some View {
        ZStack {
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    state.expanded.toggle()
                    NSLog("iPadUAE overlay: menu %@", expanded ? "opened" : "closed")
                } label: {
                    Image(systemName: expanded ? "xmark" : "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.red.opacity(0.75), in: Circle())
                        .shadow(radius: 3)
                }
                .buttonStyle(.plain)

                if expanded {
                    ControlPanel()
                        .frame(width: 352)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if state.showJoystick {
                VStack {
                    Spacer()
                    VirtualJoystickView()
                }
            }

            if state.showKeyboard {
                VStack {
                    Spacer()
                    AmigaKeyboardView()
                        .padding(.bottom, state.showJoystick ? 200 : 12)
                        .padding(.horizontal, 12)
                }
            }
        }
        .tint(.red)
    }
}

struct ControlPanel: View {
    enum Submenu { case none, df0, df1 }
    @State private var submenu: Submenu = .none
    @ObservedObject private var state = OverlayState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch submenu {
            case .none: mainMenu
            case .df0: FloppyPicker(drive: 0) { submenu = .none }
            case .df1: FloppyPicker(drive: 1) { submenu = .none }
            }
        }
        .padding(12)
    }

    private var mainMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("iPadUAE").font(.headline).padding(.bottom, 6)
            MenuRow(icon: "opticaldiscdrive", title: "Insert DF0…") { submenu = .df0 }
            MenuRow(icon: "opticaldiscdrive", title: "Insert DF1…") { submenu = .df1 }
            MenuRow(icon: "eject", title: "Eject DF0") { ipaduae_eject_floppy(0) }
            MenuRow(icon: "eject", title: "Eject DF1") { ipaduae_eject_floppy(1) }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "keyboard", title: state.showKeyboard ? "Hide Amiga Keyboard" : "Amiga Keyboard") {
                state.showKeyboard.toggle()
            }
            MenuRow(icon: "gamecontroller", title: state.showJoystick ? "Hide Joystick" : "Virtual Joystick") {
                state.showJoystick.toggle()
            }
            Divider().padding(.vertical, 4)
            MenuRow(icon: "arrow.counterclockwise", title: "Reset") { ipaduae_reset(0) }
            MenuRow(icon: "exclamationmark.arrow.circlepath", title: "Hard Reset") { ipaduae_reset(1) }
            Divider().padding(.vertical, 4)
            Text("Add disks & Kickstart ROMs via Files:\nOn My iPad › iPadUAE › WinUAE")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 22)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

struct FloppyPicker: View {
    let drive: Int
    let onDone: () -> Void

    private var floppyDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WinUAE/Floppies")
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
                Text("No disk images found.\nDrop .adf files into Files › iPadUAE › WinUAE › Floppies.")
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
