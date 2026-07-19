// Machine configuration panel: CPU, RAM, RTG graphics, networking.
// Edits are staged locally and applied with a restart of the emulated
// machine (config rewrite + uae_restart, like the desktop GUI).

import SwiftUI

struct MachinePanel: View {
    let onDone: () -> Void
    @State private var m = ConfigStore.currentMachine()
    private let initial = ConfigStore.currentMachine()

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
                        // MMU on is both faster and more authentic for 040/060
                        // (measured); default it on when moving up to them.
                        if newCPU >= 68040 { m.mmu = true }
                        if newCPU < 68030 { m.mmu = false }
                    }

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
                    Picker("RTG", selection: $m.rtgMB) {
                        Text("Off").tag(0)
                        Text("8 MB").tag(8)
                        Text("16 MB").tag(16)
                        Text("32 MB").tag(32)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Network (bsdsocket.library → host)", isOn: $m.network)
                        .font(.subheadline)

                    Toggle("MMU emulation (68030+)", isOn: $m.mmu)
                        .font(.subheadline)
                        .disabled(m.cpu < 68030)

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
