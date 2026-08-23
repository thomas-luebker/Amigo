// Machine configuration panel: CPU, RAM, RTG graphics, networking.
// Edits are staged locally and applied with a restart of the emulated
// machine (config rewrite + uae_restart, like the desktop GUI).

import SwiftUI

struct MachinePanel: View {
    let onDone: () -> Void
    @State private var m = ConfigStore.currentMachine()
    private let initial = ConfigStore.currentMachine()
    @ObservedObject private var state = OverlayState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Machine").font(.headline)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Presets").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        presetChip("A500", .a500)
                        presetChip("A1200", .a1200)
                        presetChip("A1200 Turbo", .turbo)
                        presetChip("RTG + Net", .rtgStation)
                        cd32Chip
                    }
                    if ConfigStore.cd32Active {
                        Text("CD32 console active — WinUAE's built-in CD32 machine with its own Kickstart. Applying any preset or setting below switches back to a computer.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Text("CPU").font(.caption).foregroundStyle(.secondary)
                    Picker("CPU", selection: $m.cpu) {
                        Text("68000").tag(68000)
                        Text("020").tag(68020)
                        Text("030").tag(68030)
                        Text("040").tag(68040)
                        Text("060").tag(68060)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: m.cpu) { _, newCPU in
                        // MMU on is more authentic for 040/060 — real ones
                        // have one and SysInfo reports IN USE — and it is
                        // what Enforcer/MuForce need. It is NOT faster: it
                        // costs 1.84x on integer and 2.45-2.83x on memory
                        // work (measured on the M4 iPad 2026-08-23, single
                        // variable, docs/PERFORMANCE-2026-08-23.md). Keeping
                        // it on is a deliberate decision — see that file's
                        // section 1 before "optimising" this line away.
                        if newCPU >= 68040 { m.mmu = true }
                        if newCPU < 68030 { m.mmu = false }
                    }

                    Text("CPU Speed").font(.caption).foregroundStyle(.secondary)
                    Picker("CPU Speed", selection: $m.maxSpeed) {
                        Text("Original").tag(false)
                        Text("Maximum").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .disabled(m.cpu == 68000)
                    Text(m.cpu == 68000
                         ? "68000 runs cycle-exact — always original speed."
                         : "Original paces like real hardware — cooler and easier on the battery. Maximum uses all available power for the fastest Amiga.")
                        .font(.footnote).foregroundStyle(.secondary)

                    Text("Chipset").font(.caption).foregroundStyle(.secondary)
                    Picker("Chipset", selection: $m.chipset) {
                        Text("OCS").tag("ocs")
                        Text("ECS").tag("ecs_agnus")
                        Text("AGA").tag("aga")
                    }
                    .pickerStyle(.segmented)

                    Text("Chip RAM").font(.caption).foregroundStyle(.secondary)
                    Picker("Chip RAM", selection: $m.chipHalfMB) {
                        Text("512 K").tag(1)
                        Text("1 MB").tag(2)
                        Text("2 MB").tag(4)
                    }
                    .pickerStyle(.segmented)

                    Text("Fast RAM").font(.caption).foregroundStyle(.secondary)
                    Picker("Fast RAM", selection: $m.fastMB) {
                        Text("None").tag(0)
                        Text("4 MB").tag(4)
                        Text("8 MB").tag(8)
                    }
                    .pickerStyle(.segmented)

                    Text("Zorro III Fast RAM (32-bit CPU)").font(.caption).foregroundStyle(.secondary)
                    Picker("Z3 RAM", selection: $m.z3MB) {
                        Text("None").tag(0)
                        Text("64 MB").tag(64)
                        Text("128 MB").tag(128)
                        Text("256 MB").tag(256)
                    }
                    .pickerStyle(.segmented)

                    Text("RTG Graphics Card (uaegfx, Zorro III)").font(.caption).foregroundStyle(.secondary)
                    // 32 MB is deliberately absent. The emulator builds the
                    // board fine at that size ("Card 5: Z3 0x48000000 32M IO
                    // RTG RAM"), but Picasso96 then refuses it — the guest
                    // logs "P96: Could not create graphics board context for
                    // 'Uaegfx'" and RTG never comes up. Verified on device
                    // 2026-08-21: 16 MB works, 32 MB does not, nothing else
                    // in the config differing. It is a silent trap because
                    // the machine still BOOTS, so the risky-change recovery
                    // never fires and the user just loses their screen.
                    Picker("RTG", selection: $m.rtgMB) {
                        Text("Off").tag(0)
                        Text("8 MB").tag(8)
                        Text("16 MB").tag(16)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Network (bsdsocket.library → host)", isOn: $m.network)
                        .font(.subheadline)

                    Toggle("MMU emulation (68030+)", isOn: $m.mmu)
                        .font(.subheadline)
                        .disabled(m.cpu < 68030)

                    // Applied immediately rather than staged with the rest:
                    // WinUAE takes a drive-count change through changed_prefs
                    // without a restart, and multi-disk games are usually
                    // being set up mid-session.
                    Text("Floppy Drives").font(.caption).foregroundStyle(.secondary)
                    Picker("Floppy Drives", selection: Binding(
                        get: { state.floppyDrives },
                        set: { state.applyFloppyDrives($0) })) {
                        Text("DF0").tag(1)
                        Text("+ DF1").tag(2)
                        Text("+ DF2").tag(3)
                        Text("+ DF3").tag(4)
                    }
                    .pickerStyle(.segmented)
                    Text("Extra drives save disk swapping in multi-disk games. Applies straight away — no restart.")
                        .font(.footnote).foregroundStyle(.secondary)

                    if m.z3MB > 0 || m.rtgMB > 0, m.cpu < 68020 {
                        Text("Z3 RAM and RTG need a 32-bit CPU (68020+).")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .frame(maxHeight: 420)

            // Pinned below the scroll area so it is ALWAYS visible: edits
            // are staged and silently lost on Back — testers changed
            // settings, never scrolled to the button, and reported
            // "settings do not stick".
            if m != initial {
                Text("Not applied yet — restart to use these settings.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Button {
                ConfigStore.apply(machine: m)
                onDone()
            } label: {
                Text(m == initial ? "Restart Amiga" : "Apply & Restart Amiga")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(m == initial ? 0.5 : 0.9),
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    /// CD32 can't be staged in the Machine struct (it's a WinUAE built-in
    /// quickstart, ROMs included) — the chip applies immediately.
    private var cd32Chip: some View {
        Button {
            ConfigStore.applyCD32()
            onDone()
        } label: {
            Text("CD32")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(ConfigStore.cd32Active ? Color.red.opacity(0.8) : Color.white.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func presetChip(_ label: String, _ preset: ConfigStore.Machine) -> some View {
        Button {
            m = preset
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(m == preset ? Color.red.opacity(0.8) : Color.white.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}
