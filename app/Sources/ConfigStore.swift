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
    static var cdsDir: URL { winuaeDir.appendingPathComponent("CDs") }
    static var floppiesDir: URL { winuaeDir.appendingPathComponent("Floppies") }
    static var saveStatesDir: URL { winuaeDir.appendingPathComponent("SaveStates") }

    /// Drive count as the *core* currently has it.
    ///
    /// Deliberately not parsed out of the config text: an absent
    /// `floppyNtype` line does NOT mean "disabled", it means "WinUAE
    /// default", which is DF0 **and** DF1. The shipped default.uae has no
    /// floppyNtype lines at all, so reading the text and writing the
    /// result back silently disabled DF1 on every stock setup.
    /// currprefs.floppyslots is the post-default, post-load truth.
    static var configuredFloppyDrives: Int {
        Int(ipaduae_floppy_drives())
    }

    /// Clipboard sharing with the host. The Amiga side installs its
    /// clipboard task during the uae-boot handshake (filesys.cpp mode 17),
    /// so this only takes effect on a restart — hence the snapshot and the
    /// same crash-safe path used by machine changes.
    static func setClipboardSharing(_ on: Bool) {
        snapshotBeforeRiskyChange()
        set("clipboard_sharing", on ? "true" : "false")
        ipaduae_set_clipboard_sharing(on ? 1 : 0)
        restart()
    }

    /// Emulated floppy speed. 100 = real hardware timing, 200/400/800 =
    /// proportionally faster, 0 = turbo (instant DMA, and the core
    /// declines it for non-standard ADFs). Live — DISK_check_change()
    /// picks it up every vsync — but persisted so it survives a restart.
    ///
    /// Only ever called from an explicit user action, never from a read
    /// path. Reading the machine must not mutate it; that mistake
    /// silently disabled DF1 once already.
    static func setFloppySpeed(_ speed: Int) {
        set("floppy_speed", String(speed))
        ipaduae_set_floppy_speed(Int32(speed))
    }

    /// Speed as the *core* currently has it — the post-default,
    /// post-load truth, not a guess parsed out of the config text.
    static var currentFloppySpeed: Int {
        Int(ipaduae_floppy_speed())
    }

    /// Number of emulated floppy drives (1…4). Persisted into the config
    /// so the count survives a restart, and pushed to the running core so
    /// it takes effect without one.
    static func setFloppyDrives(_ count: Int) {
        let n = min(4, max(1, count))
        for i in 0..<4 {
            set("floppy\(i)type", i < n ? "0" : "-1")
        }
        ipaduae_set_floppy_drives(Int32(n))
    }

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

    /// Every value for a key that may legitimately repeat. `hardfile2=`
    /// is the case that matters: WinUAE takes one line per drive, and
    /// `set()` would delete the others.
    static func allValues(_ key: String) -> [String] {
        readLines().filter { $0.hasPrefix(key + "=") }
            .map { String($0.dropFirst(key.count + 1)) }
    }

    /// Add a line without disturbing existing ones with the same key.
    static func append(_ key: String, _ value: String) {
        var lines = readLines()
        while lines.last?.isEmpty == true { lines.removeLast() }
        lines.append("\(key)=\(value)")
        writeLines(lines)
    }

    /// Drop only the lines for `key` whose value satisfies `where`.
    static func removeWhere(_ key: String, matching: (String) -> Bool) {
        writeLines(readLines().filter { line in
            guard line.hasPrefix(key + "=") else { return true }
            return !matching(String(line.dropFirst(key.count + 1)))
        })
    }

    // MARK: Crash-safe machine changes

    /// A machine/media change can leave default.uae unbootable — worst case
    /// the core hits a ROM/CPU mismatch (NUMSG_KS68EC020 & friends) and
    /// restart-loops forever BEFORE video init, so no UI ever appears to
    /// undo the change. Every restart-triggering change therefore snapshots
    /// the previous (known-bootable) config and arms a marker; the overlay
    /// clears it once the app has visibly booted, and a clean quit clears
    /// it too (ipaduae_fast_exit). If a launch still sees the marker, the
    /// previous session died before its first stable boot after the change
    /// — restore the snapshot and tell the user.
    static let riskyChangeKey = "riskyConfigChangePending"
    static let recoveredKey = "didRecoverConfig"
    static var lastGoodURL: URL {
        configurationsDir.appendingPathComponent(".last-good.uae")
    }

    private static func snapshotBeforeRiskyChange() {
        // Keep the oldest good config through a burst of changes: only
        // snapshot when no change is already pending.
        guard !UserDefaults.standard.bool(forKey: riskyChangeKey) else { return }
        try? FileManager.default.removeItem(at: lastGoodURL)
        guard (try? FileManager.default.copyItem(at: configURL, to: lastGoodURL)) != nil else { return }
        UserDefaults.standard.set(true, forKey: riskyChangeKey)
        armStabilityTimer()
    }

    /// Clear the pending marker once the change has survived 30 seconds.
    ///
    /// Without this the marker was only ever cleared 30s after the overlay
    /// installed — i.e. once per app *launch*. A machine change restarts
    /// the emulator, not the app, so any change made later in a session
    /// stayed armed for the rest of it, and a force-quit (swipe up: no
    /// chance to run ipaduae_fast_exit) made the next launch roll it back.
    /// Settings silently reverted, and every machine change was affected
    /// — not just the obvious ones. It is how the clipboard toggle kept
    /// being lost, which is what led to finding it. The crash-loop
    /// protection is unaffected: if the change really does break the
    /// boot, the app is gone before this fires.
    private static func armStabilityTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            markBootStable()
        }
    }

    /// Called by the overlay once the emulator has been up for a while.
    static func markBootStable() {
        UserDefaults.standard.removeObject(forKey: riskyChangeKey)
    }

    /// Called from main() before real_main reads default.uae.
    static func recoverFromCrashedChange() {
        guard UserDefaults.standard.bool(forKey: riskyChangeKey),
              FileManager.default.fileExists(atPath: lastGoodURL.path) else { return }
        try? FileManager.default.removeItem(at: configURL)
        try? FileManager.default.copyItem(at: lastGoodURL, to: configURL)
        UserDefaults.standard.removeObject(forKey: riskyChangeKey)
        UserDefaults.standard.set(true, forKey: recoveredKey)
        NSLog("iPadUAE: previous session never reached a stable boot after a config change — restored last good config")
    }

    // MARK: Machine changes (each restarts the emulator)

    static func selectKickstart(path: String) {
        snapshotBeforeRiskyChange()
        set("kickstart_rom_file", path)
        restart()
    }

    static func selectBuiltInAROS() {
        snapshotBeforeRiskyChange()
        set("kickstart_rom_file", ":AROS")
        restart()
    }

    /// One mounted hard drive, as parsed back out of a `hardfile2=` line.
    ///
    /// The line looks like
    /// `rw,DH0:/path/to.hdf,32,1,2,512,0,,uae0` — flags, then
    /// `DEVICE:path`, geometry, bootpri, filesys, controller.
    struct MountedDrive: Identifiable, Hashable {
        let unit: Int          // 0 for DH0/uae0, 1 for DH1/uae1, …
        let path: String
        var id: Int { unit }
        var volume: String { "DH\(unit):" }
        var name: String { (path as NSString).lastPathComponent }
    }

    /// Drives currently in the config, in unit order.
    ///
    /// Parsed rather than remembered, so it stays correct for configs the
    /// user imported or edited by hand.
    static var mountedHardfiles: [MountedDrive] {
        allValues("hardfile2").compactMap { value -> MountedDrive? in
            // rw,DH0:/path/to.hdf,sectors,surfaces,reserved,blocksize,bootpri,filesys,controller
            //  0        1            2       3        4         5        6       7        8
            // Nine fields, and only the path can contain commas — so the
            // path is everything from field 1 to (count - 8), rejoined.
            // Splitting naively on "," loses any HDF whose filename has a
            // comma in it, which is the kind of bug that only shows up in
            // somebody else's file names.
            let f = value.components(separatedBy: ",")
            guard f.count >= 9 else { return nil }
            let pathFields = f[1...(f.count - 8)]
            let devAndPath = pathFields.joined(separator: ",")
            guard let colon = devAndPath.firstIndex(of: ":") else { return nil }
            let device = String(devAndPath[devAndPath.startIndex..<colon])
            guard device.uppercased().hasPrefix("DH"),
                  let unit = Int(device.dropFirst(2)) else { return nil }
            let path = String(devAndPath[devAndPath.index(after: colon)...])
            guard !path.isEmpty else { return nil }
            return MountedDrive(unit: unit, path: path)
        }
        .sorted { $0.unit < $1.unit }
    }

    /// Lowest DH number not already taken. Reuses gaps, so ejecting DH1
    /// of three drives puts the next one back in the hole rather than
    /// leaving DH1 permanently missing.
    static func nextFreeHardfileUnit() -> Int {
        let used = Set(mountedHardfiles.map { $0.unit })
        var n = 0
        while used.contains(n) { n += 1 }
        return n
    }

    static var isHardfileMounted: Bool { !mountedHardfiles.isEmpty }

    /// True if this image is already mounted — mounting it twice would
    /// give the Amiga two volumes with the same name and identical
    /// contents, which confuses AmigaDOS rather than helping.
    /// `/var` is a symlink to `/private/var` on iOS, and the two spellings
    /// arrive from different places: paths already in the config (or healed
    /// by `healPaths`) tend to be `/var/…`, while `URL.path` from the file
    /// enumerator gives `/private/var/…`. Comparing raw strings therefore
    /// says "different file" about one and the same image — which mounted a
    /// duplicate on device until WinUAE itself refused it with
    /// "directory/hardfile '…' already added".
    static func canonicalPath(_ path: String) -> String {
        let prefix = "/private/"
        return path.hasPrefix(prefix) ? "/" + path.dropFirst(prefix.count) : path
    }

    static func isMounted(url: URL) -> Bool {
        let want = canonicalPath(url.path)
        return mountedHardfiles.contains { canonicalPath($0.path) == want }
    }

    /// Mount an HDF as the next free DH unit, keeping existing drives.
    /// Picasso96 refuses a uaegfx board above this size — the emulator
    /// creates it, the guest then fails with "Could not create graphics
    /// board context for 'Uaegfx'" and RTG never appears. Clamped on both
    /// read and write so a config that already says 32 (hand-edited, or
    /// written before this cap existed) is repaired rather than obeyed.
    static let maxRTGMegabytes = 16

    static func mountHardfile(url: URL) {
        guard !isMounted(url: url) else { return }
        snapshotBeforeRiskyChange()
        // RDB images carry their own geometry (zeros); plain hardfiles get
        // the classic 32/1/2/512 defaults.
        let rdb = isRDB(url: url)
        let geo = rdb ? "0,0,0,512" : "32,1,2,512"
        let unit = nextFreeHardfileUnit()
        // Each drive needs its own uaehf.device unit, or the second one
        // silently replaces the first at the controller level.
        append("hardfile2", "rw,DH\(unit):\(canonicalPath(url.path)),\(geo),0,,uae\(unit)")
        restart()
    }

    /// Eject one drive, leaving the others mounted.
    static func unmountHardfile(unit: Int) {
        snapshotBeforeRiskyChange()
        removeWhere("hardfile2") { $0.contains("DH\(unit):") }
        restart()
    }

    static func unmountAllHardfiles() {
        snapshotBeforeRiskyChange()
        removeAll("hardfile2")
        restart()
    }

    // MARK: CD-ROM (CD32/CDTV media; blkdev_cdimage handles cue/ccd/mds/nrg/iso)

    static var currentCD: String? { currentValue("cdimage0") }

    static func mountCD(url: URL) {
        snapshotBeforeRiskyChange()
        set("cdimage0", url.path)
        // CDs are not a CD32 feature. CD32 and CDTV have a drive built in,
        // but any other machine needs a controller before the guest can
        // see the slot at all — so give it uaescsi.device. Harmless where
        // a built-in drive already exists, and the difference between "the
        // CD does nothing" and "the CD is there" everywhere else.
        //
        // The Amiga still needs a CD filesystem to mount it as a volume;
        // AmigaOS 3.1+ installs generally have one (CDFileSystem).
        if !cd32Active {
            set("scsi", "true")
        }
        restart()
    }

    static func ejectCD() {
        snapshotBeforeRiskyChange()
        removeAll("cdimage0")
        restart()
    }

    /// CD32 console preset. `quickstart=cd32,0` invokes WinUAE's own
    /// built-in CD32 machine (EC020, AGA, Akiko, NVRAM) AND resolves the
    /// CD32 Kickstart + extended ROM from the startup ROM scan — so the
    /// user just needs the ROMs in Kickstarts. The explicit machine keys
    /// are removed first: set() appends, and lines after quickstart would
    /// override the built-in machine.
    static var cd32Active: Bool { currentValue("quickstart") != nil }

    /// The ROM scan recognizes CD32 ROMs wherever they are; this filename
    /// heuristic only powers the "ROM missing?" hint in the CD panel.
    static var cd32ROMLikelyPresent: Bool {
        !mediaFiles(in: kickstartsDir, extensions: ["rom", "bin", "cd32"])
            .filter { $0.lastPathComponent.lowercased().contains("cd32") }.isEmpty
    }

    static func applyCD32() {
        snapshotBeforeRiskyChange()
        for key in ["cpu_type", "cpu_model", "fpu_model", "chipset", "chipset_compatible",
                    "cpu_24bit_addressing", "cpu_compatible", "cycle_exact",
                    "cpu_cycle_exact", "cpu_memory_cycle_exact", "blitter_cycle_exact",
                    "cpu_data_cache", "mmu_model", "chipmem_size", "fastmem_size",
                    "z3mem_size", "gfxcard_size", "gfxcard_type", "gfxcard_hardware_sprite",
                    "kickstart_rom_file", "kickstart_ext_rom_file", "cachesize"] {
            removeAll(key)
        }
        set("quickstart", "cd32,0")
        // Console games need authentic pacing, not a pegged host core.
        set("cpu_speed", "real")
        restart()
    }

    static func leaveCD32() {
        removeAll("quickstart")
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

    /// Apple Pencil pressure. The UAE boot ROM can offer the guest a
    /// `tablet.library` — the interface Deluxe Paint opens to read stylus
    /// pressure — and `core-ios/ios_glue.cpp` feeds it from the Pencil.
    /// Position and clicking are unaffected either way; this only decides
    /// whether the library exists for a paint program to open.
    ///
    /// The library is installed by the boot ROM at reset, so a change
    /// takes effect on the next boot, not immediately.
    static var penPressure: Bool {
        currentValue("tablet_library") == "true"
    }

    static func setPenPressure(_ on: Bool) {
        set("tablet_library", on ? "true" : "false")
    }

    /// Serial tablet emulation: the Pencil appears on the Amiga's serial
    /// port as a Wacom Protocol IV tablet (`core-ios/wacom_serial.cpp`).
    /// This is the route for programs that drive a serial tablet
    /// themselves rather than opening `tablet.library` — TVPaint being
    /// the one that matters, where the tablet is picked from the menu it
    /// shows on a right-click at launch.
    ///
    /// The port is opened at reset, so this takes effect on the next boot.
    /// It claims the serial port for the tablet; nothing else in Amigo
    /// uses it today.
    static var serialTablet: Bool {
        currentValue("serial_port")?.uppercased() == "WACOM_TABLET"
    }

    static func setSerialTablet(_ on: Bool) {
        if on {
            set("serial_port", "WACOM_TABLET")
        } else {
            removeAll("serial_port")
        }
    }

    /// Default the library on for setups that predate it. Absent means
    /// "off" to the core (its own default), so the key has to be written
    /// rather than left out — and an explicit `false` is left alone.
    static func seedPenPressureDefault() {
        if currentValue("tablet_library") == nil {
            set("tablet_library", "true")
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
        // cpu_speed max vs real. Maximum spends every spare host cycle on
        // extra guest CPU speed — a permanently pegged core (~2.4x the
        // battery drain of Original, measured). Original paces like real
        // hardware and lets the host sleep. 68000 is cycle-exact and always
        // paces originally regardless of this flag.
        var maxSpeed: Bool = false

        static let a500 = Machine(chipset: "ecs_agnus", cpu: 68000, chipHalfMB: 2,
                                  fastMB: 0, z3MB: 0, rtgMB: 0, network: false)
        static let a1200 = Machine(chipset: "aga", cpu: 68020, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 0, rtgMB: 0, network: false)
        static let turbo = Machine(chipset: "aga", cpu: 68060, chipHalfMB: 4,
                                   fastMB: 8, z3MB: 64, rtgMB: 0, network: false, mmu: true,
                                   maxSpeed: true)
        static let rtgStation = Machine(chipset: "aga", cpu: 68040, chipHalfMB: 4,
                                        fastMB: 8, z3MB: 128, rtgMB: 16, network: true, mmu: true,
                                        maxSpeed: true)
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
            rtgMB: min(intVal("gfxcard_size", 0), maxRTGMegabytes),
            network: currentValue("bsdsocket_emu") == "true",
            mmu: (currentValue("mmu_model").flatMap { Int($0) } ?? 0) > 0,
            maxSpeed: (currentValue("cpu_speed") ?? "max") == "max")
    }

    static func apply(machine m: Machine) {
        snapshotBeforeRiskyChange()
        // cpu_type would fight cpu_model/fpu_model — manage the explicit
        // keys only. 24-bit addressing only for small 68000/EC020 setups.
        removeAll("cpu_type")
        // Leaving the CD32 preset: the quickstart line would override
        // everything below (config lines are parsed in order).
        leaveCD32()
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
        set("cpu_speed", m.maxSpeed ? "max" : "real")
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
            set("gfxcard_size", String(min(m.rtgMB, maxRTGMegabytes)))
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
        CloudSync.sync()
    }

    static func loadConfiguration(name: String) {
        let src = configurationsDir.appendingPathComponent("\(name).uae")
        guard FileManager.default.fileExists(atPath: src.path) else { return }
        snapshotBeforeRiskyChange()
        try? FileManager.default.removeItem(at: configURL)
        try? FileManager.default.copyItem(at: src, to: configURL)
        healPaths(in: configURL)
        // The loaded setup carries its own drive count; adopt it rather
        // than leaving the menu showing this device's previous one.
        OverlayState.shared.refreshFloppyDrivesFromConfig()
        restart()
    }

    static func deleteConfiguration(name: String) {
        try? FileManager.default.removeItem(
            at: configurationsDir.appendingPathComponent("\(name).uae"))
        CloudSync.pushDelete(name: "\(name).uae")
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

    /// Recursive variant for user media (Floppies/Kickstarts/HardDrives):
    /// users drop whole folder trees in via the Files app, so the pickers
    /// must see nested files too. Sorted by relative path so files group
    /// by folder in the list.
    static func mediaFiles(in dir: URL, extensions: [String]) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var found: [URL] = []
        for case let url as URL in enumerator {
            if extensions.contains(url.pathExtension.lowercased()),
               (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                found.append(url)
            }
        }
        return found.sorted {
            relativeName($0, in: dir)
                .localizedCaseInsensitiveCompare(relativeName($1, in: dir)) == .orderedAscending
        }
    }

    /// "Games/Lemmings.adf" for nested files; bare filename at the top level.
    static func relativeName(_ url: URL, in dir: URL) -> String {
        let base = dir.standardizedFileURL.path + "/"
        let path = url.standardizedFileURL.path
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : url.lastPathComponent
    }
}

/// Called from main() before real_main reads default.uae.
@_cdecl("ipaduae_heal_config_paths")
public func ipaduae_heal_config_paths() {
    // Order matters: restore the last good config first (if the previous
    // session crashed mid-change), then heal container paths in it.
    ConfigStore.recoverFromCrashedChange()
    ConfigStore.healAllConfigurations()
    ConfigStore.seedPenPressureDefault()
}
