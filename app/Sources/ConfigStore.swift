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

    private static func restart() {
        NSLog("iPadUAE: restarting with config %@", configURL.path)
        ipaduae_restart_with_config(configURL.path)
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
