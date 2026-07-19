// Save and load named Amiga setups (full .uae snapshots).

import SwiftUI

struct ConfigurationsPanel: View {
    let onDone: () -> Void
    @State private var saved = ConfigStore.savedConfigurationDetails()
    @State private var newName = ""
    @State private var confirmingDelete: String?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespaces)
    }
    private var nameExists: Bool {
        saved.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Configurations").font(.headline)
            }

            Text("Save the current machine, disks, Kickstart and hard drives as a named setup.")
                .font(.footnote).foregroundStyle(.secondary)

            HStack {
                TextField("New setup name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                Button(nameExists ? "Overwrite" : "Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(trimmedName.isEmpty)
            }

            if saved.isEmpty {
                HStack {
                    Image(systemName: "square.stack.3d.up.slash")
                        .foregroundStyle(.secondary)
                    Text("No saved setups yet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(saved) { cfg in
                        row(cfg)
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }

    private func row(_ cfg: ConfigStore.SavedConfiguration) -> some View {
        HStack(spacing: 8) {
            Button {
                ConfigStore.loadConfiguration(name: cfg.name)
                onDone()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(.red)
                        Text(cfg.name)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                        if let date = cfg.modified {
                            Text(date.formatted(.dateTime.day().month()))
                                .font(.caption2).foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    if !cfg.machine.isEmpty {
                        Text(cfg.machine)
                            .font(.caption).foregroundStyle(.white)
                    }
                    if !cfg.media.isEmpty {
                        Text(cfg.media)
                            .font(.caption2).foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1).truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if confirmingDelete == cfg.name {
                Button("Delete") {
                    ConfigStore.deleteConfiguration(name: cfg.name)
                    confirmingDelete = nil
                    saved = ConfigStore.savedConfigurationDetails()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    confirmingDelete = cfg.name
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        ConfigStore.saveCurrentConfiguration(name: trimmedName)
        newName = ""
        nameFocused = false
        confirmingDelete = nil
        saved = ConfigStore.savedConfigurationDetails()
    }
}
