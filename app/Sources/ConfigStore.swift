// Reads and patches the active .uae config, then restarts the core with it.
//
// The Unix port loads Configuration/default.uae at startup and again on
// every uae_restart, so machine changes (Kickstart, mounted hardfiles) are
// applied by rewriting that file and restarting — the same flow the desktop
// GUI uses. Simple line-level patching keeps user-added keys intact.

import Foundation

enum ConfigStore {
    // Resource root: the app's Documents folder (shown as "Amigo" in the
    // Files app). Subfolders (Kickstarts, Floppies, …) live directly here.
    static var winuaeDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var configURL: URL {
        winuaeDir.appendingPathComponent("Configuration/default.uae")
    }
    static var kickstartsDir: URL { winuaeDir.appendingPathComponent("Kickstarts") }
    static var hardDrivesDir: URL { winuaeDir.appendingPathComponent("HardDrives") }

    private static func readLines() -> [String] {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func writeLines(_ lines: [String]) {
        let text = lines.joined(separator: "\n")
        try? text.write(to: configURL, atomically: true, encoding: .utf8)
    }

    /// Replace the first `key=` line (or append one). Removes duplicates.
    static func set(_ key: String, _ value: String) {
        var lines = readLines().filter { !$0.hasPrefix(key + "=") }
        while lines.last?.isEmpty == true { lines.removeLast() }
        lines.append("\(key)=\(value)")
        writeLines(lines)
    }

    static func removeAll(_ key: String) {
        writeLines(readLines().filter { !$0.hasPrefix(key + "=") })
    }

    static func currentValue(_ key: String) -> String? {
        readLines().first { $0.hasPrefix(key + "=") }
            .map { String($0.dropFirst(key.count + 1)) }
    }

    // MARK: Machine changes (each restarts the emulator)

    static func selectKickstart(path: String) {
        set("kickstart_rom_file", path)
        restart()
    }

    static func selectBuiltInAROS() {
        set("kickstart_rom_file", ":AROS")
        restart()
    }

    static func mountHardfile(url: URL) {
        // RDB images carry their own geometry (zeros); plain hardfiles get
        // the classic 32/1/2/512 defaults.
        let rdb = isRDB(url: url)
        let geo = rdb ? "0,0,0,512" : "32,1,2,512"
        set("hardfile2", "rw,DH0:\(url.path),\(geo),0,,uae0")
        restart()
    }

    static func unmountHardfile() {
        removeAll("hardfile2")
        restart()
    }

    /// 1:1 pointer sync (WinUAE tablet/mousehack mode): the Amiga pointer
    /// follows the finger/mouse position absolutely. Needs Kickstart 2.0+.
    static var tabletMode: Bool {
        currentValue("absolute_mouse") == "mousehack"
    }

    static func setTabletMode(_ on: Bool) {
        // Live toggle — the mousehack driver engages on the next touch;
        // the config write only persists the choice for future boots.
        ipaduae_set_tablet_runtime(on ? 1 : 0)
        if on {
            set("absolute_mouse", "mousehack")
        } else {
            removeAll("absolute_mouse")
        }
    }

    private static func restart() {
        NSLog("iPadUAE: restarting with config %@", configURL.path)
        ipaduae_restart_with_config(configURL.path)
    }

    // MARK: Machine configuration (CPU / RAM / RTG / network)

    struct Machine: Equatable {
        var chipset: String   // "ocs" | "ecs_agnus" | "aga"
        var cpu: Int          // 68000, 68020, 68030, 68040, 68060
        var chipHalfMB: Int   // chipmem in 0.5MB units: 1, 2, 4
        var fastMB: Int       // 0, 4, 8
        var z3MB: Int         // 0, 64, 128, 256
        var rtgMB: Int        // 0, 8, 16, 32
        var network: Bool     // bsdsocket_emu
        var mmu: Bool = false // emulate the 68030/040/060 MMU

        static let a500 = Machine(chipset: "ecs_agnus", cpu: 68000, chipHalfMB: 2,
                                  fastMB: 0, z3MB: 0, rtgMB: 0, network: false)
        static let a1200 = Machine(chipset: "aga", cpu: 68020, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 0, rtgMB: 0, network: false)
        static let turbo = Machine(chipset: "aga", cpu: 68060, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 64, rtgMB: 0, network: false, mmu: true)
        static let rtgStation = Machine(chipset: "aga", cpu: 68040, chipHalfMB: 4,
                                        fastMB: 8, z3MB: 128, rtgMB: 16, network: true, mmu: true)
    }

    static func currentMachine() -> Machine {
        func intVal(_ key: String, _ def: Int) -> Int {
            currentValue(key).flatMap { Int($0) } ?? def
        }
        return Machine(
            chipset: currentValue("chipset") ?? "aga",
            cpu: intVal("cpu_model", 68020),
            chipHalfMB: intVal("chipmem_size", 4),
            fastMB: intVal("fastmem_size", 8),
            z3MB: intVal("z3mem_size", 0),
            rtgMB: intVal("gfxcard_size", 0),
            network: currentValue("bsdsocket_emu") == "true",
            mmu: (currentValue("mmu_model").flatMap { Int($0) } ?? 0) > 0)
    }

    static func apply(machine m: Machine) {
        // cpu_type would fight cpu_model/fpu_model — manage the explicit
        // keys only. 24-bit addressing only for small 68000/EC020 setups.
        removeAll("cpu_type")
        set("chipset", m.chipset)
        set("chipset_compatible", "-")
        set("cpu_model", String(m.cpu))
        let fpu: Int = switch m.cpu {
        case 68000, 68020: 0
        case 68030: 68882
        default: m.cpu   // 040/060 internal FPU
        }
        set("fpu_model", String(fpu))
        let wants32bit = m.cpu >= 68030 || m.z3MB > 0 || m.rtgMB > 0
        set("cpu_24bit_addressing", wants32bit ? "false" : "true")
        set("cpu_compatible", m.cpu >= 68030 ? "false" : "true")
        set("cpu_speed", "max")
        set("cachesize", "0")  // no JIT on iOS
        // Interpreter throughput: accuracy features cost real speed with no
        // JIT available. Keep cycle-exactness for 68000 (game timing);
        // 020+ "workstation" setups get the fast loose profile.
        let exact = m.cpu == 68000
        set("cycle_exact", exact ? "true" : "false")
        set("cpu_cycle_exact", exact ? "true" : "false")
        set("cpu_memory_cycle_exact", exact ? "true" : "false")
        set("blitter_cycle_exact", exact ? "true" : "false")
        set("cpu_data_cache", "false")   // 040/060 cache emulation is slow
        set("fpu_strict", "false")
        set("fpu_softfloat", "false")    // host FPU, not softfloat
        // Emulate 68040/68060 silicon-unimplemented instructions natively
        // instead of trapping out to the guest 680x0.library — big win for
        // FPU-heavy code, and avoids the slow library path entirely.
        set("cpu_no_unimplemented", (m.cpu >= 68040) ? "true" : "false")
        set("fpu_no_unimplemented", "true")
        // MMU emulation (the authentic 68030/040/060 config; WinUAE's own
        // 040/060 presets enable it). Routes memory through the MMU
        // translation path — needed for MMU-using software and reported as
        // "MMU: IN USE" in SysInfo.
        if m.mmu && m.cpu >= 68030 {
            set("mmu_model", String(m.cpu))
        } else {
            removeAll("mmu_model")
        }
        set("chipmem_size", String(m.chipHalfMB))
        set("fastmem_size", String(m.fastMB))
        set("z3mem_size", String(m.z3MB))
        if m.rtgMB > 0 {
            set("gfxcard_size", String(m.rtgMB))
            set("gfxcard_type", "ZorroIII")
            // Host-rendered cursor sprite: pointer moves without VRAM
            // redraws — noticeably smoother, especially with 1:1 mouse.
            set("gfxcard_hardware_sprite", "true")
        } else {
            removeAll("gfxcard_size")
            removeAll("gfxcard_type")
            removeAll("gfxcard_hardware_sprite")
        }
        set("bsdsocket_emu", m.network ? "true" : "false")
        restart()
    }

    /// A Rigid Disk Block ("RDSK") may sit in any of the first 16 blocks.
    private static func isRDB(url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url),
              let data = try? fh.read(upToCount: 16 * 512) else { return false }
        defer { try? fh.close() }
        let magic: [UInt8] = [0x52, 0x44, 0x53, 0x4B] // "RDSK"
        for block in 0..<(data.count / 512) {
            let o = block * 512
            if Array(data[o..<(o + 4)]) == magic { return true }
        }
        return false
    }

    // MARK: Named configurations (user-created setups)
    //
    // A configuration is a full .uae snapshot in Configuration/, so it
    // captures machine + mounted disks/Kickstart/HDF together. default.uae
    // is the live config; saving copies it to <name>.uae, loading copies
    // back and restarts.

    static var configurationsDir: URL { winuaeDir.appendingPathComponent("Configuration") }

    static func savedConfigurations() -> [String] {
        files(in: configurationsDir, extensions: ["uae"])
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != "default" }
    }

    /// What a saved setup contains, for display in the Configurations list.
    struct SavedConfiguration: Identifiable {
        var id: String { name }
        let name: String
        let machine: String   // "68060 AGA · 128 MB Z3 · RTG 16 MB · Net"
        let media: String     // "system.hdf · A1200.47.115.rom"
        let modified: Date?
    }

    static func savedConfigurationDetails() -> [SavedConfiguration] {
        savedConfigurations().map { name in
            let url = configurationsDir.appendingPathComponent("\(name).uae")
            let lines = (try? String(contentsOf: url, encoding: .utf8))?
                .split(separator: "\n").map(String.init) ?? []
            func val(_ key: String) -> String? {
                lines.first { $0.hasPrefix(key + "=") }
                    .map { String($0.dropFirst(key.count + 1)) }
            }

            var machine: [String] = []
            var cpuChipset: [String] = []
            if let cpu = val("cpu_model") { cpuChipset.append(cpu) }
            if let chipset = val("chipset")?.uppercased() {
                cpuChipset.append(chipset == "ECS_AGNUS" ? "ECS" : chipset)
            }
            if !cpuChipset.isEmpty { machine.append(cpuChipset.joined(separator: " ")) }
            if let z3 = val("z3mem_size").flatMap(Int.init), z3 > 0 {
                machine.append("\(z3) MB Z3")
            }
            if let rtg = val("gfxcard_size").flatMap(Int.init), rtg > 0 {
                machine.append("RTG \(rtg) MB")
            }
            if val("bsdsocket_emu") == "true" { machine.append("Net") }

            var media: [String] = []
            if let hd = val("hardfile2"),
               let unit = hd.split(separator: ",").dropFirst().first {
                // "DH0:/path/to.hdf" — path is everything after the first colon
                let path = unit.split(separator: ":", maxSplits: 1)
                    .dropFirst().joined()
                if !path.isEmpty { media.append((path as NSString).lastPathComponent) }
            }
            if let f0 = val("floppy0"), !f0.isEmpty {
                media.append((f0 as NSString).lastPathComponent)
            }
            if let ks = val("kickstart_rom_file"), !ks.isEmpty {
                media.append(ks == ":AROS" ? "AROS ROM" : (ks as NSString).lastPathComponent)
            }

            let modified = (try? FileManager.default
                .attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
            return SavedConfiguration(name: name,
                                      machine: machine.joined(separator: " · "),
                                      media: media.joined(separator: " · "),
                                      modified: modified)
        }
    }

    private static func sanitized(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        return name.components(separatedBy: bad).joined().trimmingCharacters(in: .whitespaces)
    }

    static func saveCurrentConfiguration(name rawName: String) {
        let name = sanitized(rawName)
        guard !name.isEmpty, name != "default" else { return }
        let dest = configurationsDir.appendingPathComponent("\(name).uae")
        try? FileManager.default.removeItem(at: dest)
        // Persist any live-only runtime toggles into the config first.
        try? FileManager.default.copyItem(at: configURL, to: dest)
    }

    static func loadConfiguration(name: String) {
        let src = configurationsDir.appendingPathComponent("\(name).uae")
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        try? FileManager.default.removeItem(at: configURL)
        try? FileManager.default.copyItem(at: src, to: configURL)
        healPaths(in: configURL)
        restart()
    }

    static func deleteConfiguration(name: String) {
        try? FileManager.default.removeItem(
            at: configurationsDir.appendingPathComponent("\(name).uae"))
    }

    // MARK: Path healing
    //
    // Configs store absolute media paths that embed the app-container UUID,
    // which changes on every reinstall/update — Kickstart and hardfile paths
    // silently go stale ("settings don't stick"). Rewrite any container-
    // style path to the *current* Documents folder, and collapse the legacy
    // Documents/WinUAE/ nesting. Runs at startup (before the core reads
    // default.uae) and when loading a saved configuration.

    static func healPaths(in url: URL) {
        guard var text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let docs = winuaeDir.path  // current Documents
        let original = text

        // ".../Containers/Data/Application/<UUID>/Documents" → current docs
        let pattern = "/(?:private/)?var/mobile/Containers/Data/Application/[0-9A-Fa-f-]+/Documents"
        if let re = try? NSRegularExpression(pattern: pattern) {
            text = re.stringByReplacingMatches(
                in: text, range: NSRange(text.startIndex..., in: text),
                withTemplate: NSRegularExpression.escapedTemplate(for: docs))
        }
        // Legacy nesting from before the folder flatten.
        text = text.replacingOccurrences(of: docs + "/WinUAE/", with: docs + "/")

        if text != original {
            try? text.write(to: url, atomically: true, encoding: .utf8)
            NSLog("iPadUAE: healed media paths in %@", url.lastPathComponent)
        }
    }

    static func healAllConfigurations() {
        for url in files(in: configurationsDir, extensions: ["uae"]) {
            healPaths(in: url)
        }
        healPaths(in: configURL)
    }

    static func files(in dir: URL, extensions: [String]) -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return all
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

/// Called from main() before real_main reads default.uae.
@_cdecl("ipaduae_heal_config_paths")
public func ipaduae_heal_config_paths() {
    ConfigStore.healAllConfigurations()
}
