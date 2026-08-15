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
- **Machine** — model, CPU, memory, RTG graphics card, networking, MMU
- **Configurations** — save/load whole setups
- **Amiga Keyboard / Virtual Joystick** — on-screen overlays
- **Display / Speed / RTG Accel / LED Bar / 1:1 Mouse** — display & input options
- **Reset**

## Adding your own files (Files app)

**On My iPad › Amigo**:

| Folder | Put here |
|---|---|
| `Kickstarts` | Amiga Kickstart ROM files |
| `Floppies` | `.adf` disk images (also `.adz`, `.dms`, `.ipf`, and `.zip`/`.lha`/`.lzx`/`.7z` archives) |
| `HardDrives` | `.hdf` hard-disk images |
| `Configuration` | saved setups (`.uae`) |

Drag files in with the Files app or AirDrop them to the iPad, then pick them
from the gear menu. You supply your own ROMs and software — nothing copyrighted
is bundled.

## Controls

**Touch (trackpad style, default):** slide to move · tap = left click ·
two-finger tap = right click.

**1:1 Mouse (menu toggle):** pointer follows your finger · touch = left click ·
second finger = right button · two-finger drag = scroll.

**Hardware:** Magic Keyboard, trackpad, and Bluetooth mice work directly.

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
