// Open in Amigo: images handed over by Amiga Imager (de.amiga-imager.ipad).
//
// Amiga Imager clones a built image into the shared App Group with the
// machine it was built for, then opens amigo://import?id=<id>:
//
//   <group>/AmigoInbox/<id>/<image>.hdf
//   <group>/AmigoInbox/<id>/machine.json
//
// The CPU has to travel with the image: emulator images carry only the CPU
// library of the CPU they were built for, so a 68060 image on Amigo's 68040
// stops at "CPU library is missing", and a 68040 image on a 68060 at the
// "68040 Installation Alert" (both reproduced 2026-10-11).
//
// The URL is only the wake-up call. SDL owns the app and scene delegates
// (an amigo:// URL ends up as an SDL drop event the core ignores), and on
// a cold launch it arrives before anything here runs. So the inbox is the
// source of truth: it is checked once the overlay is up and every time the
// app becomes active. Contract: AmigaImagerPad docs/AMIGO-HANDOFF.md.

import UIKit

enum ImagerHandoff {
    static let appGroup = "group.de.amiga-imager"
    static let inboxFolder = "AmigoInbox"
    static let machineFile = "machine.json"
    /// The user's setup before a handover replaced it — restorable from
    /// Configurations.
    static let previousSetupName = "Before Amiga Imager image"

    /// machine.json, version 1. Unknown keys are ignored.
    struct Machine: Decodable {
        var version: Int
        var imageFile: String
        var cpu: Int
        var chipKB: Int
        var fastMB: Int
        var z3MB: Int
        var rtgMB: Int
        var network: Bool
        var builtBy: String?
    }

    struct Pending {
        let dir: URL
        let image: URL
        let machine: Machine
    }

    private static var presenting = false

    static var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(inboxFolder, isDirectory: true)
    }

    /// The newest valid handover. Invalid folders are left for Amiga
    /// Imager's own pruning (it removes them after a day).
    static func pending() -> Pending? {
        guard let inbox = inboxURL,
              let dirs = try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: [.creationDateKey]) else { return nil }
        let newestFirst = dirs.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return a > b
        }
        for dir in newestFirst {
            guard let data = try? Data(contentsOf: dir.appendingPathComponent(machineFile)),
                  let m = try? JSONDecoder().decode(Machine.self, from: data),
                  m.version == 1,
                  [68020, 68030, 68040, 68060].contains(m.cpu),
                  // A bare file name — never a path out of the folder.
                  m.imageFile == (m.imageFile as NSString).lastPathComponent,
                  ["hdf", "hdz", "vhd"].contains((m.imageFile as NSString).pathExtension.lowercased())
            else { continue }
            let image = dir.appendingPathComponent(m.imageFile)
            guard FileManager.default.fileExists(atPath: image.path) else { continue }
            return Pending(dir: dir, image: image, machine: m)
        }
        return nil
    }

    /// Amigo's machine for a handover: the image's CPU, RAM, RTG and
    /// network; MMU and speed stay what the user set.
    static func machine(for m: Machine) -> ConfigStore.Machine {
        var machine = ConfigStore.currentMachine()
        machine.chipset = "aga"
        machine.cpu = m.cpu
        machine.chipHalfMB = max(1, min(4, m.chipKB / 512))
        machine.fastMB = m.fastMB
        machine.z3MB = m.z3MB
        machine.rtgMB = min(m.rtgMB, ConfigStore.maxRTGMegabytes)
        machine.network = m.network
        return machine
    }

    static func summary(_ m: Machine) -> String {
        var parts = ["\(m.cpu)"]
        if m.z3MB > 0 { parts.append("\(m.z3MB) MB Z3") }
        if m.rtgMB > 0 { parts.append("RTG \(min(m.rtgMB, ConfigStore.maxRTGMegabytes)) MB") }
        if m.network { parts.append("Net") }
        return parts.joined(separator: " · ")
    }

    /// Move the image into HardDrives (same volume: a rename, no copy)
    /// and clear the inbox folder.
    static func take(_ p: Pending) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: ConfigStore.hardDrivesDir, withIntermediateDirectories: true)
        let dest = MediaImport.uniqueDestination(
            ConfigStore.hardDrivesDir.appendingPathComponent(p.machine.imageFile))
        try fm.moveItem(at: p.image, to: dest)
        try? fm.removeItem(at: p.dir)
        return dest
    }

    /// Offer the newest handover, if any. Safe to call repeatedly.
    static func checkInbox() {
        guard !presenting, let p = pending() else { return }
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0 is PassthroughWindow })?.rootViewController,
              root.presentedViewController == nil else {
            NSLog("iPadUAE handoff: %@ waiting, nothing to present from yet", p.machine.imageFile)
            return
        }
        presenting = true
        NSLog("iPadUAE handoff: offering %@ (%@)", p.machine.imageFile, summary(p.machine))

        let alert = UIAlertController(
            title: "Image from Amiga Imager",
            message: "\(p.machine.imageFile)\nBuilt for: \(summary(p.machine))\n\n"
                + "Boot restarts the Amiga with this machine and this image as DH0. "
                + "Your current setup is saved as “\(previousSetupName)” in Configurations.",
            preferredStyle: .alert)
        let done = {
            presenting = false
            OverlayState.shared.modalActive = false
        }
        alert.addAction(UIAlertAction(title: "Boot", style: .default) { _ in
            done()
            do {
                let url = try take(p)
                ConfigStore.saveCurrentConfiguration(name: previousSetupName)
                ConfigStore.bootHandedOverImage(url: url, machine: machine(for: p.machine))
                NSLog("iPadUAE handoff: booting %@", url.lastPathComponent)
            } catch {
                NSLog("iPadUAE handoff: failed (%@)", String(describing: error))
                OverlayState.shared.importNotice = "Could not take \(p.machine.imageFile)"
                OverlayState.shared.scheduleImportNoticeDismissal()
            }
        })
        alert.addAction(UIAlertAction(title: "Add to Hard Drives", style: .default) { _ in
            done()
            if let url = try? take(p) {
                OverlayState.shared.importNotice = "Imported \(url.lastPathComponent)"
                OverlayState.shared.scheduleImportNoticeDismissal()
            }
        })
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in done() })
        OverlayState.shared.modalActive = true
        OverlayState.shared.expanded = false
        root.present(alert, animated: true)
    }
}
