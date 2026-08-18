// Copy and paste between iOS and the Amiga.
//
// The two directions are deliberately asymmetric, because iOS treats them
// differently and pretending otherwise would either leak the pasteboard or
// pester the user:
//
//   Amiga → iOS   automatic. Copying in a Workbench program puts the text
//                 on the iOS clipboard. Writing to UIPasteboard needs no
//                 consent and raises no banner.
//   iOS → Amiga   explicit. Reading UIPasteboard without user intent
//                 raises the system "Amigo pasted from <app>" banner, so
//                 the core's 2-second host poll is compiled out on iOS
//                 and the only way in is the PasteButton below.
//
// PasteButton (iOS 16+, and we target 17) is the sanctioned way to do
// this: the tap IS the consent, so the system hands over the payload with
// no banner and no pasteboard access outside that moment. The app never
// touches UIPasteboard directly — which is the whole point.

import SwiftUI

struct ClipboardPanel: View {
    let onDone: () -> Void
    @ObservedObject private var state = OverlayState.shared
    @State private var lastAction: String?

    private var ready: Bool { ipaduae_clipboard_ready() != 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Clipboard").font(.headline)
            }

            Text("Copy text in a Workbench program and it lands on the iOS clipboard. To go the other way, use the paste buttons below — iOS only lets an app read your clipboard when you ask it to.")
                .font(.footnote).foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            // Paste through clipboard.device — the "proper" route. Needs
            // sharing enabled and the Amiga-side task running.
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard").frame(width: 22)
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    ipaduae_clipboard_push_text(text)
                    lastAction = "Sent \(text.count) characters to the Amiga clipboard"
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .disabled(!state.clipboardSharing || !ready)
            }
            Text(pasteHint)
                .font(.caption).foregroundStyle(.secondary)

            Divider().padding(.vertical, 2)

            // Paste as keystrokes — works in anything, including the very
            // large amount of Amiga software that never supported
            // clipboard.device. Needs no Amiga-side task at all.
            HStack(spacing: 10) {
                Image(systemName: "keyboard").frame(width: 22)
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    ipaduae_clipboard_type_text(text)
                    lastAction = "Typing \(min(text.count, 4096)) characters…"
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
            }
            Text("Types the clipboard in as if you had entered it on the keyboard. Works in the Shell, editors and games — anywhere that takes typing — and needs no Amiga-side support. Long text is capped at 4096 characters and arrives at typing speed.")
                .font(.caption).foregroundStyle(.secondary)

            if let lastAction {
                Text(lastAction)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            Divider().padding(.vertical, 2)

            MenuRow(icon: state.clipboardSharing ? "link" : "link.badge.plus",
                    title: state.clipboardSharing ? "Amiga Clipboard Sharing: On"
                                                  : "Amiga Clipboard Sharing: Off",
                    active: state.clipboardSharing) {
                state.setClipboardSharing(!state.clipboardSharing)
                onDone()
            }
            Text("Lets Workbench programs share their clipboard with iOS. The Amiga starts this at boot, so switching it restarts the Amiga.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var pasteHint: String {
        if !state.clipboardSharing {
            return "Switch on Amiga Clipboard Sharing below to use this. It puts the text on the Amiga's own clipboard, for programs that read it."
        }
        if !ready {
            return "Waiting for the Amiga to start its clipboard handler — this appears a few seconds after boot."
        }
        return "Puts the text on the Amiga's clipboard, ready to paste in a Workbench program."
    }
}
