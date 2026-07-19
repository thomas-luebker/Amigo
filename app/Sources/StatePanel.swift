// Save states: three user slots plus an autosave slot, backed by the
// core's quick-state machinery (SaveStates/state[_N].uss). Saves and
// restores are queued into the emulator and execute at the next vsync.

import SwiftUI

struct StatePanel: View {
    let onDone: () -> Void
    @State private var refresh = 0

    private var statesDir: URL {
        ConfigStore.winuaeDir.appendingPathComponent("SaveStates")
    }
    private func stateURL(_ slot: Int) -> URL {
        statesDir.appendingPathComponent(slot == 0 ? "state.uss" : "state_\(slot).uss")
    }
    private func info(_ slot: Int) -> String? {
        let url = stateURL(slot)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attrs[.modificationDate] as? Date else { return nil }
        let bytes = (attrs[.size] as? Int64) ?? 0
        let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return "\(date.formatted(.dateTime.day().month().hour().minute())) · \(size)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Save States").font(.headline)
            }

            Text("States belong to the current machine setup — loading one saved with a different configuration can fail.")
                .font(.footnote).foregroundStyle(.secondary)

            slotRow(0, title: "Autosave", subtitle: "every 5 min and on app switch",
                    canSave: false)
            ForEach(1...3, id: \.self) { slot in
                slotRow(slot, title: "Slot \(slot)", subtitle: nil, canSave: true)
            }
        }
        .id(refresh)
    }

    private func slotRow(_ slot: Int, title: String, subtitle: String?,
                         canSave: Bool) -> some View {
        let detail = info(slot)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: slot == 0 ? "clock.arrow.circlepath"
                                                : "square.and.arrow.down.on.square")
                        .foregroundStyle(.red)
                    Text(title).font(.subheadline.weight(.semibold))
                }
                Text(detail ?? "empty")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(detail == nil ? 0.45 : 0.75))
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if canSave {
                Button("Save") {
                    ipaduae_state_op(Int32(slot), 1)
                    // The state is written at the next vsync; re-read the
                    // file info shortly after.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { refresh += 1 }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            Button("Load") {
                ipaduae_state_op(Int32(slot), 0)
                onDone()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .disabled(detail == nil)
        }
        .padding(10)
        .background(Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10))
    }
}
