// Save and load named Amiga setups (full .uae snapshots).

import SwiftUI

struct ConfigurationsPanel: View {
    let onDone: () -> Void
    @State private var saved = ConfigStore.savedConfigurations()
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

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
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if saved.isEmpty {
                Text("No saved setups yet.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(saved, id: \.self) { name in
                        HStack {
                            Button {
                                ConfigStore.loadConfiguration(name: name)
                                onDone()
                            } label: {
                                Label(name, systemImage: "square.stack.3d.up")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button(role: .destructive) {
                                ConfigStore.deleteConfiguration(name: name)
                                saved = ConfigStore.savedConfigurations()
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }

    private func save() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        ConfigStore.saveCurrentConfiguration(name: name)
        newName = ""
        nameFocused = false
        saved = ConfigStore.savedConfigurations()
    }
}
