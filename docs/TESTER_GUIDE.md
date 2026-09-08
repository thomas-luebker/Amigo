# Amigo — TestFlight Tester Guide

*Paste into TestFlight "What to Test" / send to testers.*

---

## Welcome to the Amigo beta 🕹️

Thanks for testing! Amigo runs classic **Amiga** software on your iPad. This
is an early build — expect rough edges, and please tell me what breaks.

### Getting started (1 minute)

1. Install from the TestFlight link.
2. Open it — it boots a built-in free Amiga system automatically. No setup.
3. Tap the **gear** (top-right, it fades — tap to bring it back) to explore.

### To run real AmigaOS / your own software

1. Open the **Files** app → **On My iPad** → **Amigo**.
2. Put your **Kickstart ROM** in `Kickstarts/`, disk images (`.adf`) in
   `Floppies/`, hard-disk images (`.hdf`) in `HardDrives/`.
   *(You provide these — nothing copyrighted is included.)*
3. In the gear menu: **Kickstart ROM…** and tap your ROM (importing alone
   does not select it), choose a machine in **Machine** (A500 for most
   floppy games, A1200 for AGA and WHDLoad), insert a disk or mount a hard
   drive, and reset.
4. Save the setup with **Configurations** so you can return to it.
5. If the Amiga keeps showing the insert-disk hand: **Controls & Help ›
   Why won't it boot?** (also in the disk panel) says which of ROM, machine
   or disk does not match. Tap **Copy** and paste it into your feedback.

### What I'd love feedback on

- **Does it boot and run on your iPad model?** (tell me which iPad + iPadOS)
- **Touch feel** — pointer accuracy, the 1:1 Mouse mode, two-finger scroll.
- **Graphics correctness** — especially hi-color (16/32-bit) Workbench screens.
- **Speed** — is it usable for what you tried? (If you run SysInfo, send the
  numbers.)
- **The menu** — anything confusing or missing?
- **Anything that crashes, hangs, or looks wrong.**

### Known limitations

- No JIT (Apple's rule) → demanding software runs slower than on a PC.
- RTG acceleration defaults **off** for correct graphics; turn on for a bit
  more 8-bit speed.
- Early build — UI and performance are still being tuned.

### Reporting

Use TestFlight's **screenshot → feedback** (screenshot in the app, then send),
or message me directly. Screenshots + "what I did / what happened / which iPad"
are gold.

Thanks! — Thomas

Related: [[iPadUAE - Handbook]]
