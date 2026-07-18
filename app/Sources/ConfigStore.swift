// Reads and patches the active .uae config, then restarts the core with it.
//
// The Unix port loads Configuration/default.uae at startup and again on
// every uae_restart, so machine changes (Kickstart, mounted hardfiles) are
// applied by rewriting that file and restarting — the same flow the desktop
// GUI uses. Simple line-level patching keeps user-added keys intact.

import Foundation

enum ConfigStore {
    static var winuaeDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WinUAE")
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

        static let a500 = Machine(chipset: "ecs_agnus", cpu: 68000, chipHalfMB: 2,
                                  fastMB: 0, z3MB: 0, rtgMB: 0, network: false)
        static let a1200 = Machine(chipset: "aga", cpu: 68020, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 0, rtgMB: 0, network: false)
        static let turbo = Machine(chipset: "aga", cpu: 68060, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 64, rtgMB: 0, network: false)
        static let rtgStation = Machine(chipset: "aga", cpu: 68040, chipHalfMB: 4,
                                        fastMB: 8, z3MB: 128, rtgMB: 16, network: true)
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
            network: currentValue("bsdsocket_emu") == "true")
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

    static func files(in dir: URL, extensions: [String]) -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []
        return all
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}
