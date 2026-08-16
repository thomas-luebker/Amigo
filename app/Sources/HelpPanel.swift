// Controls & Help: in-app quick reference for touch gestures, Pencil,
// controllers, and file locations. The most-asked question ("how do I
// right-click?") should never need a trip to Reddit. Content mirrors
// docs/USER_GUIDE.md — keep the two in sync.

import SwiftUI

struct HelpPanel: View {
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onDone) { Label("Back", systemImage: "chevron.left") }
                    .buttonStyle(.plain)
                Spacer()
                Text("Controls & Help").font(.headline)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    section("Touch — trackpad style (default)")
                    row("hand.draw", "Slide anywhere to move the pointer")
                    row("hand.tap", "Tap = left click · two-finger tap = right click")
                    row("hand.point.up.left", "Tap, touch again & drag — or hold still, then drag — to drag with the left button held (move icons, draw, select)")
                    row("arrow.up.and.down", "Two-finger slide = scroll")

                    section("1:1 Mouse (gear menu toggle)")
                    row("cursorarrow.rays", "Pointer jumps to your finger; touching holds the left button")
                    row("hand.point.up.braille", "Second finger: rest = right button · slide = scroll")
                    row("exclamationmark.circle", "Exact positioning needs Kickstart 2.0+; on 1.3 your finger drags the pointer instead")

                    section("Apple Pencil")
                    row("pencil.tip", "Hover moves the pointer · touch = left button · squeeze = right click")

                    section("Keyboard & overlays")
                    row("keyboard", "Amiga Keyboard, F-keys, Numpad and Virtual Joystick live in the gear menu")
                    row("rectangle.bottomthird.inset.filled", "Keyboard Style: see-through overlay (default) or the screen above the keyboard — great in portrait; Picture: Fit keeps proportions")
                    row("shift", "Shift / Ctrl / Alt / Amiga keys latch: tap the modifier, then the key")
                    row("arrowkeys", "Cursor keys type normally — showing the Virtual Joystick turns them (plus right Ctrl) into joystick port 2")
                    row("circle.lefthalf.filled", "The slider in the menu sets overlay transparency")

                    section("Game controllers")
                    row("gamecontroller", "Pair in iOS Settings › Bluetooth, then assign a port in the Controller panel")
                    row("button.horizontal.top.press", "CD32 pad mode for CD32 titles; optional autofire")

                    section("Hardware")
                    row("desktopcomputer", "Magic Keyboard, trackpads and Bluetooth mice work directly")

                    section("Your files (Files app · On My iPad › Amigo)")
                    row("folder", "Kickstarts — ROM files · Floppies — ADF/ADZ/DMS/IPF, also ZIP/LHA/LZX/7z · HardDrives — HDF · CDs — CUE/CCD/MDS/NRG/ISO · Configuration — saved setups")
                    row("opticaldisc", "CD32: put the CD32 Kickstart (+ extended ROM) in Kickstarts, drop a CD image in CDs, then CD-ROM menu › Switch to CD32 console")
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

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.red)
            Text(text).font(.footnote)
        }
    }
}
