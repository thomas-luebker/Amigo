// "Why won't it boot?" — a read-only diagnosis of the current setup.
//
// Both 2★ reviews so far were onboarding failures, not defects: a ROM
// imported but never selected, or an OCS-era floppy handed to the default
// A1200 with fast memory. The emulator cannot tell the user that — the
// Amiga just shows the insert-disk hand again — so this panel looks at the
// three things that decide whether software runs (ROM, machine, media) and
// says which one does not match.
//
// Everything here READS. It never writes a preference, never restarts the
// Amiga and never infers a value back into the config: the DF1/RTG
// regressions in docs/BACKLOG.md came from exactly that.

import SwiftUI
import UIKit

enum BootCheck {
    enum Severity: Int, Comparable {
        case problem = 0, warning, info, ok
        static func < (a: Severity, b: Severity) -> Bool { a.rawValue < b.rawValue }

        var icon: String {
            switch self {
            case .problem: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info:    return "info.circle.fill"
            case .ok:      return "checkmark.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .problem: return .red
            case .warning: return .orange
            case .info:    return .secondary
            case .ok:      return .green
            }
        }
        var label: String {
            switch self {
            case .problem: return "PROBLEM"
            case .warning: return "CHECK"
            case .info:    return "NOTE"
            case .ok:      return "OK"
            }
        }
    }

    struct Finding: Identifiable {
        let id = UUID()
        let severity: Severity
        let title: String
        let detail: String
    }

    struct Report {
        var setup: [(String, String)]   // label, value — what is configured
        var findings: [Finding]

        var worst: Severity { findings.map(\.severity).min() ?? .ok }

        /// Plain text for the clipboard, so a user can paste it into a
        /// support mail or an issue.
        var text: String {
            var out = ["Amigo setup check"]
            for (k, v) in setup { out.append("\(k): \(v)") }
            out.append("")
            for f in findings { out.append("[\(f.severity.label)] \(f.title) — \(f.detail)") }
            return out.joined(separator: "\n")
        }
    }

    // MARK: ROM inspection

    struct RomInfo {
        var sizeBytes: Int
        var encrypted = false
        var byteSwapped = false
        var version = 0
        var revision = 0
        /// Header recognised as a Kickstart (0x1114 / 0x1111 magic, or
        /// Cloanto's AMIROMTYPE1 wrapper).
        var isKickstart = false

        var sizeKB: Int { sizeBytes / 1024 }
        var plausibleSize: Bool { [256, 512, 1024, 2048].contains(sizeKB) }

        /// "3.1 (40.63)" — the family name a user recognises plus the
        /// exact version the ROM reports about itself.
        var describe: String {
            guard version > 0 else { return encrypted ? "encrypted (Amiga Forever)" : "unknown" }
            let family: String
            switch version {
            case ..<34: family = "1.2"
            case 34:    family = "1.3"
            case 35:    family = "1.4"
            case 36:    family = "2.0"
            case 37:    family = "2.04/2.05"
            case 38:    family = "2.1"
            case 39:    family = "3.0"
            case 40:    family = "3.1"
            case 41...43: family = "3.1 (custom)"
            case 44:    family = "3.5"
            case 45:    family = "3.9"
            case 46:    family = "3.1.4"
            case 47:    family = "3.2"
            default:    family = "3.x"
            }
            return "\(family) (\(version).\(revision))"
        }
    }

    static func inspectRom(_ url: URL) -> RomInfo? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var info = RomInfo(sizeBytes: size)
        guard let head = try? handle.read(upToCount: 16), head.count >= 16 else { return info }
        let b = [UInt8](head)

        if String(bytes: b[0..<11], encoding: .ascii) == "AMIROMTYPE1" {
            info.encrypted = true
            info.isKickstart = true
            return info
        }
        // A Kickstart begins 0x11 0x14 (512 KB) or 0x11 0x11 (256 KB),
        // followed by a JMP; the exec version word sits at offset 12 and
        // the revision at 14, big-endian. WinUAE reads the same bytes.
        if b[0] == 0x11 && (b[1] == 0x14 || b[1] == 0x11) {
            info.isKickstart = true
            info.version = Int(b[12]) << 8 | Int(b[13])
            info.revision = Int(b[14]) << 8 | Int(b[15])
        } else if b[1] == 0x11 && (b[0] == 0x14 || b[0] == 0x11) {
            info.isKickstart = true
            info.byteSwapped = true
            info.version = Int(b[13]) << 8 | Int(b[12])
            info.revision = Int(b[15]) << 8 | Int(b[14])
        }
        return info
    }

    // MARK: Floppy inspection

    struct FloppyInfo {
        var sizeBytes: Int
        var isPlainADF: Bool          // .adf we can read; archives are opaque
        var blank = false             // boot block all zero
        var dosMagic = false          // "DOS" at offset 0
        var kickDisk = false          // "KICK" — A1000 Kickstart disk
        var checksumOK = false

        var standardSize: Bool { sizeBytes == 901_120 || sizeBytes == 1_802_240 }
    }

    static func inspectFloppy(_ path: String) -> FloppyInfo? {
        let url = URL(fileURLWithPath: path)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else { return nil }
        let ext = url.pathExtension.lowercased()
        var info = FloppyInfo(sizeBytes: size, isPlainADF: ext == "adf")
        guard info.isPlainADF, let handle = try? FileHandle(forReadingFrom: url) else { return info }
        defer { try? handle.close() }
        guard let block = try? handle.read(upToCount: 1024), block.count == 1024 else { return info }
        let b = [UInt8](block)

        info.blank = !b.contains { $0 != 0 }
        info.dosMagic = b[0] == 0x44 && b[1] == 0x4F && b[2] == 0x53          // "DOS"
        info.kickDisk = b[0] == 0x4B && b[1] == 0x49 && b[2] == 0x43 && b[3] == 0x4B // "KICK"

        // Boot block checksum: the 256 longwords summed with end-around
        // carry must come to 0xFFFFFFFF. Kickstart's strap refuses
        // anything else, which is why a data disk shows the hand again.
        if info.dosMagic {
            var sum: UInt32 = 0
            for i in stride(from: 0, to: 1024, by: 4) {
                let w = UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
                let (r, carry) = sum.addingReportingOverflow(w)
                sum = carry ? r &+ 1 : r
            }
            info.checksumOK = sum == 0xFFFF_FFFF
        }
        return info
    }

    // MARK: The check itself

    static func run() -> Report {
        var setup: [(String, String)] = []
        var findings: [Finding] = []

        let romValue = ConfigStore.currentValue("kickstart_rom_file") ?? ":AROS"
        let usingAROS = romValue == ":AROS" || romValue.isEmpty
        let cd32 = ConfigStore.cd32Active
        let machine = ConfigStore.currentMachine()
        let hardfiles = ConfigStore.mountedHardfiles
        let drives = Int(ipaduae_floppy_drives())
        let inserted: [(Int, String)] = (0..<max(drives, 1)).compactMap { d in
            guard let c = ipaduae_floppy_name(Int32(d)) else { return nil }
            let s = String(cString: c)
            return s.isEmpty ? nil : (d, s)
        }
        let romFiles = ConfigStore.mediaFiles(in: ConfigStore.kickstartsDir,
                                              extensions: ["rom", "bin", "a500", "a600", "a1200", "a4000"])

        // --- ROM ---------------------------------------------------------
        var rom: RomInfo? = nil
        if cd32 {
            setup.append(("Kickstart", "CD32 console (built-in CD32 machine)"))
        } else if usingAROS {
            setup.append(("Kickstart", "built-in AROS ROM"))
        } else {
            let url = URL(fileURLWithPath: romValue)
            rom = inspectRom(url)
            setup.append(("Kickstart", "\(url.lastPathComponent) — \(rom?.describe ?? "file missing")"))
        }

        if !cd32 && usingAROS {
            let detailTail = romFiles.isEmpty
                ? "No ROM files are in Files › Amigo › Kickstarts yet. Add one with Import Files… or the Files app, then select it under Kickstart ROM…."
                : "Not selected: \(romFiles.map(\.lastPathComponent).joined(separator: ", ")). Importing a ROM does not select it — tap it under Kickstart ROM…."
            if !inserted.isEmpty {
                findings.append(Finding(
                    severity: .problem,
                    title: "A floppy is inserted but the built-in AROS ROM is selected",
                    detail: "AROS boots Workbench-style software; most original floppy games talk to the real Kickstart's internals and show the insert-disk hand again on AROS. " + detailTail))
            } else if hardfiles.isEmpty {
                findings.append(Finding(
                    severity: .info,
                    title: "Nothing to boot yet",
                    detail: "No floppy is inserted and no hard drive is mounted. The insert-disk hand is what an empty Amiga shows. " + detailTail))
            } else {
                findings.append(Finding(
                    severity: .info,
                    title: "Booting a hard drive on the built-in AROS ROM",
                    detail: "Fine for Workbench-compatible software. A hard-drive image that expects a real AmigaOS (WHDLoad packs, AGS) needs a Kickstart 3.1 or newer. " + detailTail))
            }
        }

        if let rom {
            if !FileManager.default.fileExists(atPath: romValue) {
                findings.append(Finding(
                    severity: .problem,
                    title: "The selected ROM file is missing",
                    detail: "\(romValue) no longer exists — moved or deleted in Files. Select another under Kickstart ROM…."))
            } else if rom.encrypted {
                let dir = URL(fileURLWithPath: romValue).deletingLastPathComponent()
                let keyHere = FileManager.default.fileExists(atPath: dir.appendingPathComponent("rom.key").path)
                let keyRoot = FileManager.default.fileExists(atPath: ConfigStore.kickstartsDir.appendingPathComponent("rom.key").path)
                if keyHere || keyRoot {
                    findings.append(Finding(severity: .ok, title: "Amiga Forever ROM with rom.key present",
                                            detail: "The encrypted ROM is decoded with the key beside it."))
                } else {
                    findings.append(Finding(
                        severity: .problem,
                        title: "Encrypted Amiga Forever ROM without rom.key",
                        detail: "This ROM is Cloanto-encrypted (AMIROMTYPE1) and cannot start without the rom.key file from the same Amiga Forever installation. Copy rom.key into Files › Amigo › Kickstarts."))
                }
            } else if !rom.isKickstart {
                findings.append(Finding(
                    severity: .problem,
                    title: "The selected file is not a Kickstart ROM",
                    detail: "\(rom.sizeKB) KB, and it does not start with a Kickstart header. A Kickstart is 256 KB or 512 KB (some 1 MB). A renamed archive or disk image will not boot."))
            } else {
                if !rom.plausibleSize {
                    findings.append(Finding(
                        severity: .warning,
                        title: "Unusual ROM size: \(rom.sizeKB) KB",
                        detail: "Kickstarts are 256 KB (1.x, 2.0x) or 512 KB (3.x). The header looks right, so it may still work; if it does not, re-copy the file."))
                }
                if rom.byteSwapped {
                    findings.append(Finding(
                        severity: .info,
                        title: "Byte-swapped ROM image",
                        detail: "The dump has its byte pairs reversed (a programmer-format image). WinUAE corrects this on load; nothing to do."))
                }
                if rom.version > 0 {
                    findings.append(Finding(severity: .ok, title: "Kickstart \(rom.describe) recognised",
                                            detail: "\(rom.sizeKB) KB, header valid."))
                }
            }
        }

        // --- Machine -----------------------------------------------------
        let chipsetName: String = {
            switch machine.chipset {
            case "aga": return "AGA"
            case "ecs_agnus", "ecs": return "ECS"
            default: return "OCS"
            }
        }()
        let chipMB = machine.chipHalfMB % 2 == 0 ? "\(machine.chipHalfMB / 2)" : "\(Double(machine.chipHalfMB) / 2)"
        var machineLine = "\(machine.cpu) · \(chipsetName) · \(chipMB) MB chip"
        if machine.fastMB > 0 { machineLine += " + \(machine.fastMB) MB fast" }
        if machine.z3MB > 0 { machineLine += " + \(machine.z3MB) MB Z3" }
        machineLine += machine.rtgMB > 0 ? " · RTG \(machine.rtgMB) MB" : " · no RTG"
        setup.append(("Machine", cd32 ? "CD32" : machineLine))

        let a500Like = machine.cpu == 68000 && machine.fastMB == 0 && machine.chipset != "aga"
        if !cd32, !inserted.isEmpty, !a500Like, hardfiles.isEmpty {
            findings.append(Finding(
                severity: .warning,
                title: "Floppy game on a \(machine.cpu) \(chipsetName) machine",
                detail: "Many games from the OCS/ECS era refuse to run with a faster CPU, fast memory or AGA. If the disk is read and then rejected, try Machine… › A500 (68000, no fast memory). AGA titles want A1200."))
        }
        if let rom, rom.isKickstart, rom.version > 0, rom.version < 39, machine.chipset == "aga" {
            findings.append(Finding(
                severity: .info,
                title: "Kickstart \(rom.describe) on an AGA machine",
                detail: "This ROM predates AGA. It boots, but software will not see AGA features, and OCS-era games are happier on the A500 preset."))
        }
        if !cd32, !hardfiles.isEmpty, machine.rtgMB == 0 {
            findings.append(Finding(
                severity: .warning,
                title: "Hard drive mounted, no RTG graphics card",
                detail: "If the Workbench on this image was set up for a graphics-card screen mode, it will boot to a black screen. Machine… › RTG + Net adds the card. A Workbench that uses a PAL screen does not need it."))
        }
        if let rom, rom.isKickstart, rom.version > 0, rom.version < 36, ConfigStore.tabletMode {
            findings.append(Finding(
                severity: .info,
                title: "1:1 Mouse needs Kickstart 2.0 or newer",
                detail: "On \(rom.describe) touch falls back to dragging the pointer. Everything still works, just not with the pointer under your finger."))
        }

        // --- Media -------------------------------------------------------
        if inserted.isEmpty {
            setup.append(("Floppies", "none inserted"))
        }
        for (d, path) in inserted {
            let name = (path as NSString).lastPathComponent
            setup.append(("DF\(d)", name))
            guard let fd = inspectFloppy(path) else {
                findings.append(Finding(severity: .problem, title: "DF\(d): \(name) is missing",
                                        detail: "The file is no longer where the config points. Eject it and insert it again from the disk panel."))
                continue
            }
            if !fd.isPlainADF {
                findings.append(Finding(severity: .info, title: "DF\(d): \(name) is compressed or an archive",
                                        detail: "Its contents are not inspected here. If it holds a single ADF it boots like one; a WHDLoad archive needs WHDLoad installed on a hard drive."))
                continue
            }
            if !fd.standardSize {
                findings.append(Finding(severity: .warning, title: "DF\(d): unusual ADF size (\(fd.sizeBytes) bytes)",
                                        detail: "A standard Amiga disk image is 901,120 bytes (DD) or 1,802,240 (HD). Something else is probably not a disk image at all."))
            }
            if fd.blank {
                findings.append(Finding(severity: .problem, title: "DF\(d): blank disk",
                                        detail: "The boot block is empty — an unformatted or freshly created image. It cannot boot; it can be formatted from a running Workbench."))
            } else if fd.kickDisk {
                findings.append(Finding(severity: .info, title: "DF\(d): Kickstart disk",
                                        detail: "An A1000-style Kickstart disk, not a boot disk. It only makes sense with an A1000 configuration."))
            } else if !fd.dosMagic {
                findings.append(Finding(severity: .warning, title: "DF\(d): no AmigaDOS boot block",
                                        detail: "Kickstart only boots disks whose first sector starts with \"DOS\". This one does not: a data disk, a later disk of a set, or a non-Amiga image. Boot disk 1 or a Workbench first."))
            } else if !fd.checksumOK {
                findings.append(Finding(severity: .warning, title: "DF\(d): boot block checksum is wrong",
                                        detail: "The disk carries a DOS signature but its boot block does not verify, so Kickstart refuses it — a data disk that was never made bootable, or a damaged image."))
            } else {
                findings.append(Finding(severity: .ok, title: "DF\(d): bootable AmigaDOS disk",
                                        detail: "Valid boot block. If it still shows the hand, the ROM or the machine is the mismatch, not the disk."))
            }
        }

        for hf in hardfiles {
            setup.append((hf.volume, hf.name))
            if !FileManager.default.fileExists(atPath: hf.path) {
                findings.append(Finding(severity: .problem, title: "\(hf.volume) \(hf.name) is missing",
                                        detail: "The image file is gone from HardDrives. Eject it under Hard Drives… and mount it again."))
            }
        }

        if findings.isEmpty {
            findings.append(Finding(severity: .ok, title: "Nothing obviously wrong",
                                    detail: "ROM, machine and media are consistent. If the software still does not run, it may need a different machine — try the presets under Machine…."))
        }

        findings.sort { $0.severity < $1.severity }
        return Report(setup: setup, findings: findings)
    }
}

// MARK: - Panel

struct BootCheckPanel: View {
    let onDone: () -> Void
    @State private var report = BootCheck.run()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(report.setup.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.0).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                            Text(item.1)
                        }
                        .font(.footnote)
                    }
                } header: {
                    Text("What is configured")
                }

                Section {
                    ForEach(report.findings) { f in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: f.severity.icon)
                                .foregroundStyle(f.severity.color)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(f.title).font(.subheadline.weight(.semibold))
                                Text(f.detail).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Findings")
                } footer: {
                    Text("This only reads your setup; it changes nothing. Full guide: github.com/thomas-luebker/Amigo › docs › USER_GUIDE.md")
                }
            }
            .navigationTitle("Why won't it boot?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = report.text
                        copied = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}

/// Presents the panel as a sheet from the overlay window, the same way
/// the document picker is shown: `modalActive` lets PassthroughWindow
/// route touches to it, and is cleared however the sheet goes away.
final class BootCheckPresenter: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = BootCheckPresenter()

    func present() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0 is PassthroughWindow })?.rootViewController else {
            NSLog("iPadUAE bootcheck: no overlay window to present from")
            return
        }
        let host = UIHostingController(rootView: BootCheckPanel { [weak root] in
            root?.dismiss(animated: true) { OverlayState.shared.modalActive = false }
        })
        host.modalPresentationStyle = .formSheet
        host.presentationController?.delegate = self
        OverlayState.shared.modalActive = true
        OverlayState.shared.expanded = false
        NSLog("iPadUAE bootcheck: opened")
        root.present(host, animated: true)
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        OverlayState.shared.modalActive = false
    }
}
