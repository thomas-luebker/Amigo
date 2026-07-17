// Virtual Amiga keyboard and joystick overlays.
//
// Both send SDL scancodes through ipaduae_send_key into the core's Unix
// input layer — the exact path hardware keyboards use, so WinUAE's own
// SDL→Amiga key mapping applies. The joystick relies on the default
// config's `joyport1=kbd2` (keyboard layout B: cursor keys + right Ctrl).

import SwiftUI

// SDL3 scancodes (USB HID usage IDs).
enum SC {
    static let a = 4, b = 5, c = 6, d = 7, e = 8, f = 9, g = 10, h = 11, i = 12
    static let j = 13, k = 14, l = 15, m = 16, n = 17, o = 18, p = 19, q = 20
    static let r = 21, s = 22, t = 23, u = 24, v = 25, w = 26, x = 27, y = 28, z = 29
    static let n1 = 30, n2 = 31, n3 = 32, n4 = 33, n5 = 34, n6 = 35, n7 = 36
    static let n8 = 37, n9 = 38, n0 = 39
    static let ret = 40, esc = 41, backspace = 42, tab = 43, space = 44
    static let minus = 45, equals = 46, lbracket = 47, rbracket = 48, backslash = 49
    static let semicolon = 51, apostrophe = 52, grave = 53, comma = 54, period = 55, slash = 56
    static let capslock = 57
    static let f1 = 58, f2 = 59, f3 = 60, f4 = 61, f5 = 62, f6 = 63, f7 = 64
    static let f8 = 65, f9 = 66, f10 = 67
    static let del = 76, right = 79, left = 80, down = 81, up = 82
    static let help = 117
    static let lctrl = 224, lshift = 225, lalt = 226, lamiga = 227
    static let rctrl = 228, rshift = 229, ralt = 230, ramiga = 231
}

struct Key: Identifiable {
    let id = UUID()
    let label: String
    let code: Int
    var width: CGFloat = 1
    var modifier = false
}

struct AmigaKeyboardView: View {
    static let rows: [[Key]] = [
        [Key(label: "Esc", code: SC.esc), Key(label: "F1", code: SC.f1), Key(label: "F2", code: SC.f2),
         Key(label: "F3", code: SC.f3), Key(label: "F4", code: SC.f4), Key(label: "F5", code: SC.f5),
         Key(label: "F6", code: SC.f6), Key(label: "F7", code: SC.f7), Key(label: "F8", code: SC.f8),
         Key(label: "F9", code: SC.f9), Key(label: "F10", code: SC.f10),
         Key(label: "Del", code: SC.del), Key(label: "Help", code: SC.help)],
        [Key(label: "`", code: SC.grave), Key(label: "1", code: SC.n1), Key(label: "2", code: SC.n2),
         Key(label: "3", code: SC.n3), Key(label: "4", code: SC.n4), Key(label: "5", code: SC.n5),
         Key(label: "6", code: SC.n6), Key(label: "7", code: SC.n7), Key(label: "8", code: SC.n8),
         Key(label: "9", code: SC.n9), Key(label: "0", code: SC.n0), Key(label: "-", code: SC.minus),
         Key(label: "=", code: SC.equals), Key(label: "\\", code: SC.backslash),
         Key(label: "⌫", code: SC.backspace)],
        [Key(label: "Tab", code: SC.tab, width: 1.5), Key(label: "Q", code: SC.q), Key(label: "W", code: SC.w),
         Key(label: "E", code: SC.e), Key(label: "R", code: SC.r), Key(label: "T", code: SC.t),
         Key(label: "Y", code: SC.y), Key(label: "U", code: SC.u), Key(label: "I", code: SC.i),
         Key(label: "O", code: SC.o), Key(label: "P", code: SC.p), Key(label: "[", code: SC.lbracket),
         Key(label: "]", code: SC.rbracket), Key(label: "Return", code: SC.ret, width: 1.8)],
        [Key(label: "Ctrl", code: SC.lctrl, modifier: true), Key(label: "Caps", code: SC.capslock),
         Key(label: "A", code: SC.a), Key(label: "S", code: SC.s), Key(label: "D", code: SC.d),
         Key(label: "F", code: SC.f), Key(label: "G", code: SC.g), Key(label: "H", code: SC.h),
         Key(label: "J", code: SC.j), Key(label: "K", code: SC.k), Key(label: "L", code: SC.l),
         Key(label: ";", code: SC.semicolon), Key(label: "'", code: SC.apostrophe)],
        [Key(label: "Shift", code: SC.lshift, width: 1.8, modifier: true), Key(label: "Z", code: SC.z),
         Key(label: "X", code: SC.x), Key(label: "C", code: SC.c), Key(label: "V", code: SC.v),
         Key(label: "B", code: SC.b), Key(label: "N", code: SC.n), Key(label: "M", code: SC.m),
         Key(label: ",", code: SC.comma), Key(label: ".", code: SC.period), Key(label: "/", code: SC.slash),
         Key(label: "Shift", code: SC.rshift, width: 1.4, modifier: true), Key(label: "↑", code: SC.up)],
        [Key(label: "A⃝", code: SC.lamiga, modifier: true), Key(label: "Alt", code: SC.lalt, modifier: true),
         Key(label: "Space", code: SC.space, width: 6), Key(label: "Alt", code: SC.ralt, modifier: true),
         Key(label: "A⃝", code: SC.ramiga, modifier: true),
         Key(label: "←", code: SC.left), Key(label: "↓", code: SC.down), Key(label: "→", code: SC.right)],
    ]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<Self.rows.count, id: \.self) { r in
                HStack(spacing: 4) {
                    ForEach(Self.rows[r]) { key in
                        KeyButton(key: key)
                    }
                }
            }
        }
        .padding(8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct KeyButton: View {
    let key: Key
    @State private var pressed = false
    @State private var latched = false

    var body: some View {
        Text(key.label)
            .font(.system(size: 13, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .frame(minWidth: 30 * key.width, maxWidth: key.width > 1 ? .infinity : 34, minHeight: 34)
            .background((pressed || latched) ? Color.red.opacity(0.8) : Color.white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 6))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        if key.modifier {
                            latched.toggle()
                            ipaduae_send_key(Int32(key.code), latched ? 1 : 0)
                        } else {
                            ipaduae_send_key(Int32(key.code), 1)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        if !key.modifier {
                            ipaduae_send_key(Int32(key.code), 0)
                        }
                    }
            )
    }
}

/// D-pad + fire button driving keyboard-layout-B joystick (joyport1=kbd2).
struct VirtualJoystickView: View {
    @State private var activeCodes: Set<Int> = []

    private func setDirection(_ codes: Set<Int>) {
        for c in activeCodes.subtracting(codes) { ipaduae_send_key(Int32(c), 0) }
        for c in codes.subtracting(activeCodes) { ipaduae_send_key(Int32(c), 1) }
        activeCodes = codes
    }

    var body: some View {
        HStack {
            // D-pad: drag anywhere in the circle; 8-way via dead zone.
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 150, height: 150)
                .overlay(Circle().stroke(.red.opacity(0.5), lineWidth: 2))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let dx = v.location.x - 75, dy = v.location.y - 75
                            var codes: Set<Int> = []
                            if dx < -18 { codes.insert(SC.left) }
                            if dx > 18 { codes.insert(SC.right) }
                            if dy < -18 { codes.insert(SC.up) }
                            if dy > 18 { codes.insert(SC.down) }
                            setDirection(codes)
                        }
                        .onEnded { _ in setDirection([]) }
                )
            Spacer()
            // Fire button (right Ctrl in layout B).
            Circle()
                .fill(.red.opacity(0.55))
                .frame(width: 110, height: 110)
                .overlay(Text("FIRE").font(.headline).foregroundStyle(.white))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !activeCodes.contains(SC.rctrl) {
                                activeCodes.insert(SC.rctrl)
                                ipaduae_send_key(Int32(SC.rctrl), 1)
                            }
                        }
                        .onEnded { _ in
                            activeCodes.remove(SC.rctrl)
                            ipaduae_send_key(Int32(SC.rctrl), 0)
                        }
                )
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
}
