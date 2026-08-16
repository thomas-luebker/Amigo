# Amigo — User Guide

Amigo runs classic **Commodore Amiga** software on your iPad. It's a port of
WinUAE. Out of the box it boots a free open-source Amiga-like system (AROS);
add your own Kickstart ROMs and software to run the genuine thing.

**Requires:** iPadOS 17 or later.

## First launch

The app boots straight into an emulated Amiga using its built-in ROM — no setup.

## The menu

Tap the **gear** (top-right; it fades while you work — tap to bring it back):

- **Insert / Eject disks** — floppy drives DF0/DF1
- **Kickstart ROM** — built-in AROS, or your own
- **Hard Drive** — mount an `.hdf`
- **CD-ROM (CD32)** — insert a CD image; one tap switches to a full CD32
  console (needs the CD32 Kickstart + extended ROM in `Kickstarts`)
- **Machine** — model, CPU, memory, RTG graphics card, networking, MMU
- **Configurations** — save/load whole setups
- **Amiga Keyboard / Virtual Joystick** — on-screen overlays
- **Display / Picture / Speed / RTG Accel / LED Bar / 1:1 Mouse** — display &
  input options. **Keyboard Style** picks the see-through overlay (default)
  or the screen above the keyboard (portrait-friendly); **Picture: Fit**
  keeps proportions instead of stretching.
- **Reset**

## Adding your own files (Files app)

**On My iPad › Amigo**:

| Folder | Put here |
|---|---|
| `Kickstarts` | Amiga Kickstart ROM files |
| `Floppies` | `.adf` disk images (also `.adz`, `.dms`, `.ipf`, and `.zip`/`.lha`/`.lzx`/`.7z` archives) |
| `HardDrives` | `.hdf` hard-disk images |
| `CDs` | CD images (`.cue`+`.bin`, `.ccd`, `.mds`, `.nrg`, `.iso`, compressed `.chd`) |
| `Configuration` | saved setups (`.uae`) |

Drag files in with the Files app or AirDrop them to the iPad, then pick them
from the gear menu. You supply your own ROMs and software — nothing copyrighted
is bundled.

## Controls

**Touch (trackpad style, default):** slide to move · tap = left click ·
two-finger tap = right click · two-finger slide = scroll. **To drag** (move
icons, draw, select): tap, then touch again and drag — or hold still a moment
until the button engages, then drag.

**1:1 Mouse (menu toggle):** pointer follows your finger · touch = left click ·
second finger = right button · two-finger drag = scroll. Exact positioning
needs Kickstart 2.0+; on 1.3 your finger drags the pointer instead.

**Hardware:** Magic Keyboard, trackpad, and Bluetooth mice work directly.

**Cursor keys** type as cursor keys. Showing the **Virtual Joystick** turns
them (plus right Ctrl) into the emulated joystick — hide it to type again.

## Tips

- **Hi-color graphics wrong?** Keep **RTG Accel** off (default) — correct at all
  depths.
- **Screen clipped by rounded corners?** Toggle **Display** (Safe Area ⇄
  Fullscreen).
- **Faster?** Keep **Speed: Fast**. Heavier software wants a 68040/68060 + more
  RAM (Machine panel).
- **Save your setup** with **Configurations**.

## Notes

Amigo interprets the Amiga CPU (Apple doesn't permit JIT on the App Store),
so demanding software runs slower than on a PC — everyday Workbench, tools, and
many games run well. Files and setups survive app updates.
