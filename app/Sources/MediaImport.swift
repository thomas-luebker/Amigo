// Getting files into the app without leaving it: drag & drop from Files
// (or any app that vends a file URL), and an in-app document picker.
//
// Both funnel into `MediaImport.receive`, which files an item into the
// folder its extension belongs to — the same folders the pickers read, so
// an imported disk shows up in "Insert DF0…" immediately.

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum MediaImport {
    /// Where each kind of file belongs, keyed by lowercase extension.
    /// Mirrors the extension lists the individual pickers filter on.
    static let routes: [String: String] = {
        var map: [String: String] = [:]
        for ext in ["adf", "adz", "dms", "ipf", "lha", "lzh", "lzx"] { map[ext] = "Floppies" }
        for ext in ["hdf", "hdz", "vhd"] { map[ext] = "HardDrives" }
        for ext in ["cue", "bin", "ccd", "img", "sub", "mds", "mdf", "nrg", "iso", "chd"] { map[ext] = "CDs" }
        for ext in ["rom", "a500", "a600", "a1200", "a4000"] { map[ext] = "Kickstarts" }
        // Amiga Forever's rom.key: the core's Cloanto decoder looks for it
        // next to the ROM, so it belongs in the same folder.
        map["key"] = "Kickstarts"
        map["uae"] = "Configuration"
        return map
    }()

    /// Ambiguous containers: an archive can be a disk or a ROM, and .bin
    /// is a CD track or a ROM. They land in Floppies, which is where a
    /// zipped ADF — by far the common case — is useful.
    static let ambiguous: Set<String> = ["zip", "7z", "gz", "bin"]

    static var acceptedTypes: [UTType] {
        // Almost none of these have registered UTIs, so accept data and
        // filter on the extension after the fact.
        [.data, .archive, .diskImage]
    }

    static func folder(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        if let known = routes[ext] { return known }
        if ambiguous.contains(ext) { return "Floppies" }
        return nil
    }

    /// Copy `url` into its folder. Returns the destination on success.
    /// Security-scoped access is required for anything handed over by
    /// Files or a drag session.
    @discardableResult
    static func receive(_ url: URL) -> URL? {
        guard let folder = folder(for: url) else {
            NSLog("iPadUAE import: ignoring unrecognized file %@", url.lastPathComponent)
            return nil
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let dir = ConfigStore.winuaeDir.appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var dest = dir.appendingPathComponent(url.lastPathComponent)
        // Never clobber: an import that silently replaced a disk the user
        // had saved games on would be unrecoverable.
        if FileManager.default.fileExists(atPath: dest.path) {
            let base = dest.deletingPathExtension().lastPathComponent
            let ext = dest.pathExtension
            var n = 2
            repeat {
                let name = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
                dest = dir.appendingPathComponent(name)
                n += 1
            } while FileManager.default.fileExists(atPath: dest.path) && n < 100
        }
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            NSLog("iPadUAE import: %@ → %@", url.lastPathComponent, folder)
            return dest
        } catch {
            NSLog("iPadUAE import: failed to copy %@ (%@)",
                  url.lastPathComponent, String(describing: error))
            return nil
        }
    }

    /// Import a batch, then act on it: a single dropped floppy goes
    /// straight into DF0, which is what dropping a disk on an emulator is
    /// obviously meant to do. Anything else is filed silently and picked
    /// up from the menu.
    static func receiveAndUse(_ urls: [URL]) {
        let imported = urls.compactMap { receive($0) }
        guard !imported.isEmpty else { return }
        OverlayState.shared.importNotice = imported.count == 1
            ? "Imported \(imported[0].lastPathComponent)"
            : "Imported \(imported.count) files"

        if imported.count == 1, let first = imported.first,
           folder(for: first) == "Floppies" {
            ipaduae_insert_floppy(0, first.path)
            OverlayState.shared.importNotice = "DF0: \(first.lastPathComponent)"
        } else if imported.contains(where: { folder(for: $0) == "Kickstarts" }) {
            // A ROM that is imported but never selected is the most common
            // way a first session ends at the insert-disk screen. Deliberately
            // not auto-selected: that would restart the Amiga under the
            // user's feet and silently change the machine.
            OverlayState.shared.importNotice = imported.count == 1
                ? "Imported \(imported[0].lastPathComponent) — select it under Kickstart ROM…"
                : "Imported \(imported.count) files — select the ROM under Kickstart ROM…"
        }
        OverlayState.shared.scheduleImportNoticeDismissal()
    }
}

/// Accepts file drops anywhere on the emulator picture.
///
/// The interaction is installed on SDL's own root view rather than on the
/// overlay window: PassthroughWindow.hitTest rejects everything outside a
/// registered control, so a drop over the picture never reaches the
/// overlay at all.
final class MediaDropDelegate: NSObject, UIDropInteractionDelegate {
    static let shared = MediaDropDelegate()

    func install(on scene: UIWindowScene) {
        guard let view = scene.windows
            .first(where: { !($0 is PassthroughWindow) })?.rootViewController?.view else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.install(on: scene) }
            return
        }
        guard !view.interactions.contains(where: { $0 is UIDropInteraction }) else { return }
        view.addInteraction(UIDropInteraction(delegate: self))
        NSLog("iPadUAE: file drop interaction installed")
    }

    func dropInteraction(_ interaction: UIDropInteraction,
                         canHandle session: any UIDropSession) -> Bool {
        session.canLoadObjects(ofClass: URL.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction,
                         sessionDidUpdate session: any UIDropSession) -> UIDropProposal {
        // Copy, not move — the source file stays in the user's Files.
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction,
                         performDrop session: any UIDropSession) {
        _ = session.loadObjects(ofClass: URL.self) { items in
            let urls = items.compactMap { $0 as? URL }
            DispatchQueue.main.async { MediaImport.receiveAndUse(urls) }
        }
    }
}

/// In-app file import. UIDocumentPickerViewController is presented from
/// the overlay window — which means PassthroughWindow must stop filtering
/// touches for as long as it is up, or the picker would be visible and
/// completely untouchable.
final class MediaPickerPresenter: NSObject, UIDocumentPickerDelegate {
    static let shared = MediaPickerPresenter()

    func present() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0 is PassthroughWindow })?.rootViewController else {
            NSLog("iPadUAE import: no overlay window to present from")
            return
        }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: MediaImport.acceptedTypes,
                                                    asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        OverlayState.shared.modalActive = true
        root.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        OverlayState.shared.modalActive = false
        MediaImport.receiveAndUse(urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        OverlayState.shared.modalActive = false
    }
}
