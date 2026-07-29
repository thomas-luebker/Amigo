// About & Licenses: attribution and license texts for App Store compliance.
//
// Amigo ships GPL-2 code (WinUAE); the screen credits upstream authors,
// links the buildable source repo, and carries the full GPL-2 text plus
// the SDL3 (zlib), AROS ROM (APL) and LZMA SDK notices.

import SwiftUI

struct AboutPanel: View {
    let onDone: () -> Void
    @State private var showGPL = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "?"
        let b = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(v) (\(b))"
    }

    private var gplText: String {
        guard let url = Bundle.main.url(forResource: "LICENSE-GPL2", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "GNU General Public License, version 2.\nhttps://www.gnu.org/licenses/old-licenses/gpl-2.0.html"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("About").font(.headline)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading) {
                            Text("Amigo — Amiga Emulator").font(.title3.weight(.semibold))
                            Text(version).font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Text("An Amiga emulator for iPad. Free software — no ads, no purchases, no accounts.")
                        .font(.footnote)

                    section("Credits")
                    Text("Based on **WinUAE** by Toni Wilen.\nOriginal **UAE** by Bernd Schmidt and contributors.\niOS port by Thomas Lübker.")
                        .font(.footnote)

                    section("Source Code")
                    Text("Amigo is licensed under the GNU General Public License v2. The complete source, including the exact WinUAE revision and all patches for every released build, is available at:")
                        .font(.footnote)
                    Link("github.com/thomas-luebker/iPadUAE",
                         destination: URL(string: "https://github.com/thomas-luebker/iPadUAE")!)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.red)

                    section("Third-Party Software")
                    Text("**SDL 3** — © Sam Lantinga and contributors, zlib license.\n**AROS Kickstart replacement ROM** — © the AROS Development Team, AROS Public License.\n**LZMA SDK** — Igor Pavlov, public domain.\nAmiga is a trademark of Amiga Corporation. This app contains no Amiga ROMs or software; users supply their own files.")
                        .font(.footnote)

                    section("License")
                    Button {
                        showGPL.toggle()
                    } label: {
                        Label(showGPL ? "Hide GNU GPL v2 text" : "Show GNU GPL v2 text",
                              systemImage: showGPL ? "chevron.down" : "chevron.right")
                            .font(.footnote.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    if showGPL {
                        Text(gplText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 480)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
            .textCase(.uppercase)
            .padding(.top, 4)
    }
}
