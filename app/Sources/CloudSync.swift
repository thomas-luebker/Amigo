// iCloud Drive sync.
//
// Three sets, each independently useful and independently risky:
//
//   Configuration/*.uae   — tiny text snapshots, always safe to mirror
//   SaveStates/*.uss      — a few MB each; the point of the whole feature
//                           (stop on the iPad, carry on at the Mac)
//   Floppies/HardDrives/CDs/Kickstarts — opt-in, off by default
//
// Media is off by default on purpose. HDFs run to hundreds of megabytes
// and would silently eat a 5 GB free iCloud tier, and a disk image that
// the emulator has *mounted* is being written underneath us — pulling a
// newer copy over it, or uploading it mid-write, corrupts the image. Any
// file the running config references is therefore skipped entirely,
// whichever direction it would have moved.
//
// The container is user-visible in Files (NSUbiquitousContainers in
// Info.plist), so "Amigo" appears under iCloud Drive and files can be
// dropped in from a Mac and picked up on the next sync.
//
// All file access goes through NSFileCoordinator: the ubiquity container
// is written by iCloud itself, and an uncoordinated copy can read a file
// that is halfway through being replaced.

import Foundation
import SwiftUI

enum CloudSync {
    static let containerID = "iCloud.de.amiga-imager.uae"

    /// Configurations and save states. On by default — small, and the
    /// reason most people want this at all.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "icloudSync") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "icloudSync") }
    }

    /// Disk images and ROMs. Off by default: potentially many gigabytes.
    static var syncMedia: Bool {
        get { UserDefaults.standard.bool(forKey: "icloudSyncMedia") }
        set { UserDefaults.standard.set(newValue, forKey: "icloudSyncMedia") }
    }

    /// Whether the container was reachable on the last attempt (false when
    /// the user is signed out of iCloud, or Drive is off for the app).
    private(set) static var available = false

    /// Human-readable outcome of the last sync, for the panel.
    private(set) static var lastSummary: String?

    private static let queue = DispatchQueue(label: "de.amiga-imager.uae.cloudsync",
                                             qos: .utility)
    private static var running = false

    /// A folder that participates in the sync.
    private struct Folder {
        let name: String
        let extensions: Set<String>
        /// Skip files the running machine has mounted.
        let mountSensitive: Bool
    }

    private static let baseFolders = [
        Folder(name: "Configuration", extensions: ["uae"], mountSensitive: false),
        Folder(name: "SaveStates", extensions: ["uss"], mountSensitive: false),
    ]

    private static let mediaFolders = [
        Folder(name: "Floppies",
               extensions: ["adf", "adz", "dms", "ipf", "zip", "gz", "lha", "lzh", "lzx", "7z"],
               mountSensitive: true),
        Folder(name: "HardDrives", extensions: ["hdf", "hdz", "vhd"], mountSensitive: true),
        Folder(name: "CDs",
               extensions: ["cue", "bin", "ccd", "img", "sub", "mds", "mdf", "nrg", "iso", "chd"],
               mountSensitive: true),
        Folder(name: "Kickstarts",
               extensions: ["rom", "bin", "a500", "a600", "a1200", "a4000"],
               mountSensitive: true),
    ]

    /// Files that are never mirrored: the live config the core rewrites
    /// constantly, and the crash-recovery snapshot, which is meaningful
    /// only on the device that wrote it.
    private static let neverSync: Set<String> = ["default.uae", ".last-good.uae"]

    /// iCloud's own per-file ceiling is 50 GB, but anything this large in
    /// an Amiga folder is a mistake worth not acting on.
    private static let maxFileBytes: Int64 = 4 * 1024 * 1024 * 1024

    // MARK: Entry points

    /// Full sync. Completion runs on the main thread with `true` when
    /// local files changed and the pickers should re-read their folders.
    static func sync(completion: ((Bool) -> Void)? = nil) {
        guard enabled else { completion?(false); return }
        // Overlapping passes would fight over the same files; a sync that
        // arrives while one is running is simply dropped, and the next
        // trigger (foreground, save, launch) picks the work up.
        queue.async {
            guard !running else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            running = true
            let changed = syncBlocking()
            running = false
            DispatchQueue.main.async { completion?(changed) }
        }
    }

    /// Propagate a local delete, so the file does not resurrect from the
    /// cloud copy on the next pass.
    static func pushDelete(name: String, folder: String = "Configuration") {
        guard enabled else { return }
        queue.async {
            guard let remote = remoteURL(folder) else { return }
            let target = remote.appendingPathComponent(name)
            coordinateWrite(target) { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: Container

    private static func containerURL() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: containerID)
    }

    private static func remoteURL(_ folder: String) -> URL? {
        containerURL()?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
    }

    // MARK: Coordination helpers

    private static func coordinateRead(_ url: URL, _ body: (URL) -> Void) {
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { body($0) }
    }

    private static func coordinateWrite(_ url: URL, _ body: (URL) -> Void) {
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error) { body($0) }
    }

    /// Coordinated copy that replaces the destination atomically.
    private static func copy(from src: URL, to dst: URL) -> Bool {
        var ok = false
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: src, options: [],
                                       writingItemAt: dst, options: .forReplacing,
                                       error: &error) { readURL, writeURL in
            let fm = FileManager.default
            try? fm.removeItem(at: writeURL)
            do {
                try fm.copyItem(at: readURL, to: writeURL)
                ok = true
            } catch {
                NSLog("iPadUAE cloud: copy failed %@ (%@)",
                      readURL.lastPathComponent, String(describing: error))
            }
        }
        return ok
    }

    // MARK: The pass

    private static func syncBlocking() -> Bool {
        guard containerURL() != nil else {
            available = false
            lastSummary = "iCloud unavailable — sign in to iCloud Drive."
            return false
        }
        available = true

        // Read the live config once; mount checks are substring tests
        // against it, which catches every form a path appears in
        // (floppyN=, hardfile2=…,path,…, cdimage0=, kickstart_rom_file=).
        let configText = (try? String(contentsOf: ConfigStore.configURL, encoding: .utf8)) ?? ""

        var folders = baseFolders
        if syncMedia { folders += mediaFolders }

        var changedLocal = false
        var pushed = 0, pulled = 0, skipped = 0

        for folder in folders {
            let result = syncFolder(folder, configText: configText)
            changedLocal = changedLocal || result.changedLocal
            pushed += result.pushed
            pulled += result.pulled
            skipped += result.skipped
        }

        var parts: [String] = []
        if pushed > 0 { parts.append("\(pushed) up") }
        if pulled > 0 { parts.append("\(pulled) down") }
        if skipped > 0 { parts.append("\(skipped) in use, skipped") }
        lastSummary = parts.isEmpty ? "Up to date" : parts.joined(separator: " · ")
        NSLog("iPadUAE cloud: %@", lastSummary ?? "")
        return changedLocal
    }

    private struct FolderResult {
        var changedLocal = false
        var pushed = 0
        var pulled = 0
        var skipped = 0
    }

    private static func syncFolder(_ folder: Folder, configText: String) -> FolderResult {
        var result = FolderResult()
        let fm = FileManager.default
        guard let remote = remoteURL(folder.name) else { return result }

        let local = ConfigStore.winuaeDir.appendingPathComponent(folder.name, isDirectory: true)
        try? fm.createDirectory(at: local, withIntermediateDirectories: true)
        coordinateWrite(remote) { url in
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }

        // Ask iCloud to materialize anything still in the cloud. Those
        // entries are picked up on a later pass, once local.
        requestDownloads(in: remote)

        let locals = index(local, folder)
        let remotes = index(remote, folder)

        func inUse(_ name: String) -> Bool {
            folder.mountSensitive && configText.contains(name)
        }

        // Local → cloud. The 1s slack absorbs the mtime drift a copy
        // introduces, so a file does not ping-pong between devices.
        for (name, entry) in locals {
            if inUse(name) { result.skipped += 1; continue }
            guard entry.size <= maxFileBytes else { continue }
            let target = remote.appendingPathComponent(name)
            if let cloud = remotes[name] {
                guard entry.modified > cloud.modified.addingTimeInterval(1) else { continue }
            }
            if copy(from: entry.url, to: target) { result.pushed += 1 }
        }

        // Cloud → local.
        for (name, entry) in remotes {
            if inUse(name) { result.skipped += 1; continue }
            guard entry.downloaded, entry.size <= maxFileBytes else { continue }
            let target = local.appendingPathComponent(name)
            if let mine = locals[name] {
                guard entry.modified > mine.modified.addingTimeInterval(1) else { continue }
            }
            if copy(from: entry.url, to: target) {
                result.pulled += 1
                result.changedLocal = true
            }
        }
        return result
    }

    // MARK: Directory indexing

    private struct Entry {
        let url: URL
        let modified: Date
        let size: Int64
        let downloaded: Bool
    }

    /// Map of filename → entry for the syncable files in `dir`.
    ///
    /// A file that iCloud has not downloaded yet is listed under a
    /// placeholder name (".Disk.adf.icloud"); it is indexed under its real
    /// name so it still compares against the local copy, but flagged
    /// undownloaded so nothing tries to read it.
    private static func index(_ dir: URL, _ folder: Folder) -> [String: Entry] {
        var map: [String: Entry] = [:]
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey,
                                      .ubiquitousItemDownloadingStatusKey, .isDirectoryKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]) else { return map }

        for url in entries {
            let raw = url.lastPathComponent
            let placeholder = raw.hasSuffix(".icloud") && raw.hasPrefix(".")
            let name = placeholder
                ? String(raw.dropFirst().dropLast(".icloud".count))
                : raw
            guard !neverSync.contains(name) else { continue }
            guard folder.extensions.contains((name as NSString).pathExtension.lowercased()) else {
                continue
            }
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            let status = values?.ubiquitousItemDownloadingStatus
            let downloaded = !placeholder
                && (status == nil || status == .current || status == .downloaded)
            map[name] = Entry(url: placeholder ? dir.appendingPathComponent(name) : url,
                              modified: values?.contentModificationDate ?? .distantPast,
                              size: Int64(values?.fileSize ?? 0),
                              downloaded: downloaded)
        }
        return map
    }

    private static func requestDownloads(in dir: URL) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil,
            options: [.skipsSubdirectoryDescendants]) else { return }
        for url in entries where url.lastPathComponent.hasSuffix(".icloud") {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }
}

/// iCloud panel: what is synced, whether the container is reachable, and
/// a manual pass for when someone has just dropped a file in on the Mac.
struct CloudPanel: View {
    let onDone: () -> Void
    @State private var enabled = CloudSync.enabled
    @State private var syncMedia = CloudSync.syncMedia
    @State private var busy = false
    @State private var summary = CloudSync.lastSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("iCloud").font(.headline)
            }

            Text("Keeps your setups and save states on every device signed in to the same iCloud account. The folder is visible in Files › iCloud Drive › Amigo.")
                .font(.footnote).foregroundStyle(.secondary)

            Toggle("Sync setups & save states", isOn: $enabled)
                .font(.subheadline)
                .onChange(of: enabled) { _, on in
                    CloudSync.enabled = on
                    if on { runSync() }
                }

            Toggle("Also sync disks, hard drives & ROMs", isOn: $syncMedia)
                .font(.subheadline)
                .disabled(!enabled)
                .onChange(of: syncMedia) { _, on in
                    CloudSync.syncMedia = on
                    if on { runSync() }
                }
            Text("Disk images are large — a few hard drives can fill a free iCloud plan. A disk the Amiga currently has mounted is never synced in either direction, so it can't be corrupted mid-write.")
                .font(.caption).foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            HStack(spacing: 8) {
                Image(systemName: CloudSync.available ? "checkmark.icloud" : "exclamationmark.icloud")
                    .foregroundStyle(CloudSync.available ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                Text(summary ?? "Not synced yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button(action: runSync) {
                Text(busy ? "Syncing…" : "Sync Now")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(enabled && !busy ? 0.9 : 0.5),
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!enabled || busy)
        }
    }

    private func runSync() {
        guard !busy else { return }
        busy = true
        CloudSync.sync { _ in
            busy = false
            summary = CloudSync.lastSummary
        }
    }
}
