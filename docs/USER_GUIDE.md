# Amigo — User Guide

Amigo runs classic **Commodore Amiga** software on your iPad, iPhone and
Apple Silicon Mac. It is a port of WinUAE. Out of the box it boots a free,
open-source Amiga-compatible system (AROS); add your own Kickstart ROM and
software to run the genuine thing.

**Requires:** iOS / iPadOS 17 or later, or an Apple Silicon Mac.

---

## Five minutes to your first Amiga

Amigo is a configurable Amiga, not a game launcher. Three things decide
whether a program runs: **the Kickstart ROM**, **the machine model**, and
**the software itself**. Most first-day problems come from one of those not
matching the other two. Pick what you want to do and follow that path.

### What the built-in AROS ROM can and cannot do

Amigo starts immediately, using the bundled AROS ROM. That is real, free
software that behaves like an Amiga and runs Workbench-style programs,
hard-drive installs of many titles, and most productivity software.

**Most original floppy games will not boot on it.** They talk to the
hardware through the real Kickstart's internals, and AROS is a replacement,
not a copy. If a game "works on other emulators", those emulators almost
always had a real Kickstart set up already. **If you are here for games,
add a Kickstart ROM first.** Nothing else you change will help.

### Getting a Kickstart ROM

A Kickstart ROM is the Amiga's firmware. It is copyrighted, so Amigo cannot
include one. Legal sources:

- **Amiga Forever** (Cloanto) sells them. Its ROMs are encrypted; copy the
  `rom.key` file into the same folder as the ROMs and Amigo decrypts them.
- **Dump your own Amiga's ROM** with a transfer tool.
- Some AmigaOS distributions include ROMs under licence.

### Which Kickstart for what

| You want to run | Kickstart to pick | Machine preset |
|---|---|---|
| Games from 1985–1992 (most floppy games) | **1.3** (34.5) — or 2.04 / 3.1 for the A500/A2000 (40.63) | **A500** |
| AGA games, WHDLoad packs, AGS | **3.1 for the A1200** (40.68) or 3.1.4 / 3.2 | **A1200** or **A1200 Turbo** |
| Workbench / AmigaOS with a big screen | 3.1 (A1200/A4000), 3.1.4 or 3.2 | **RTG + Net** |
| CD32 games | CD32 ROM **plus** its extended ROM (both 40.60) | **CD32** (CD-ROM menu) |
| Just look around, no ROM | Built-in AROS | anything |

ROM files are 256 KB (Kickstart 1.x, 2.0x) or 512 KB (3.x). A 1 MB file is
usually two ROMs joined and works too. Anything much smaller or larger is
not a Kickstart, however it is named.

### Path A — floppy games (ADF)

1. **Get the ROM into Amigo.** Any of these: drop it into
   *Files › On My iPad › Amigo › Kickstarts*; use *gear › Import Files…*;
   drag the file onto the Amiga screen; AirDrop it to the device.
2. **Select the ROM.** *Gear › Kickstart ROM…* and tap it. **Importing a
   ROM does not select it** — until you tap it here, Amigo is still on
   AROS. The Amiga restarts on the new ROM.
3. **Pick the machine.** *Gear › Machine…* and tap the **A500** preset.
   The default machine is an A1200 with fast memory and a 68020, and a lot
   of older games refuse to run on that. A500 is what they were written
   for.
4. **Insert the disk.** Tap the **disk button** (bottom right), choose
   *DF0*, and tap the ADF. Put ADFs in *Files › Amigo › Floppies* or drag
   them onto the screen; a single dragged disk goes straight into DF0.
5. Play with the **Virtual Joystick** (*gear › Input & Overlays*) or a
   Bluetooth controller set to *Joystick Port* (*gear › Game Controller*).

**Multi-disk games:** insert disk 2 into DF1 (the disk panel has a drive
picker) so the game finds it without a swap.

### Path B — hard-drive games (WHDLoad, AGS and similar)

The easy route is a pre-built hard-drive image that already contains
Workbench, WHDLoad and the games. One reviewer's recipe, unchanged:

1. Put the image (`.hdf`; rename a raw `.img` to `.hdf`) into
   *Files › Amigo › HardDrives* and the A1200 Kickstart 3.1 into
   *Kickstarts*.
2. *Gear › Kickstart ROM…* — select the ROM.
3. *Gear › Hard Drives…* — mount the image.
4. *Gear › Machine…* — **A1200** (authentic speed) or **A1200 Turbo**
   (68060 and lots of RAM; WHDLoad games load and run much faster).
5. Reset. The image boots into its own menu.

WHDLoad games also come as `.lha` archives. Amigo can insert one as a
floppy, but the game still needs WHDLoad installed in a Workbench on a hard
drive, so start with a pre-built image if you do not have one.

### Path C — Workbench and applications

- **From a hard-drive image:** as in Path B, with the **RTG + Net** preset
  for a large high-colour screen and internet access. Workbench 3.1 and
  newer can then open a 1280×720 or larger screen through the emulated
  graphics card — pick it in *Prefs › ScreenMode* inside the Amiga.
- **From install floppies:** boot the Install disk in DF0, mount an empty
  hard-drive image, and follow the installer. Amigo cannot create an empty
  image yet; take one from an AmigaOS distribution or make it on a computer
  with a disk-image tool.
- **On AROS:** the built-in ROM runs Workbench-compatible software from a
  hard-drive image without a Kickstart at all.

**Save the setup.** *Gear › Configurations…* stores the whole machine
(ROM, drives, memory, display) under a name. Switch between "Games A500",
"Workbench RTG" and "CD32" in one tap.

### Path D — CD32

1. Put the CD32 Kickstart **and** its extended ROM into *Kickstarts*.
2. Put the CD image (`.cue`+`.bin`, `.iso`, `.chd` …) into *CDs*.
3. *Gear › CD-ROM & CD32 Console…* › **Switch to CD32 console**, then
   insert the CD. Use a controller in **CD32 pad mode**.

---

## Troubleshooting

**The insert-disk hand stays, or comes back after the disk is read.**
The Amiga looked at the disk and rejected it. In order of likelihood:

1. The ROM is still **AROS**. Check *gear › Kickstart ROM…*: the selected
   entry has a filled check mark. Importing a ROM does not select it.
2. The machine is wrong for the game: the default is an **A1200** with a
   68020 and fast memory. Try the **A500** preset for anything from the
   OCS/ECS era.
3. The ROM file is not really a Kickstart — a 256 KB or 512 KB size is
   right; an Amiga Forever ROM needs `rom.key` beside it.
4. The image is not bootable: a data disk, disk 2 of a set, or a blank.
   Boot disk 1, or a Workbench, first.
5. The file is damaged or is not an ADF at all (a renamed archive, a
   text file with an `.adf` name).

**Games show garbage, freeze or reset.** Usually the machine, not the
game: use **A500** for older titles and turn fast memory off (*Machine*).
For AGA games use **A1200**. Try the floppy speed at **1×** (disk panel) for
copy-protected or timing-sensitive disks.

**"Works on other emulators, not on this one."** Those emulators had a real
Kickstart configured. Add one (above).

**Workbench from an HDF never appears, or the screen stays black.** A
hard-drive install set up for a graphics card needs the **RTG + Net** preset
(the RTG board is what its screen mode expects). Conversely, a plain
Workbench that opens a PAL screen does not need RTG at all.

**Clicks stopped working after pairing a controller.** The pointer still
moves but nothing clicks, from any source. Quit and reopen Amigo; the
controller stays paired. (Known bug, being tracked.)

**Hi-colour graphics look wrong.** Keep *Display › RTG Accel* off (the
default).

**Screen cut off by rounded corners or the notch.** *Display › Display:
Safe Area / Fullscreen*.

**Too much black around the picture on an iPhone in portrait.** A 4:3 Amiga
screen cannot fill a tall phone screen. Rotate to landscape, or use
*Picture: Stretch*.

**Right-click.** Two-finger tap. With a Pencil, double-tap (Pencil 2 / Pro)
or squeeze (Pencil Pro). With a mouse, the right button.

**Files I added do not appear.** Check the folder: ROMs in *Kickstarts*,
floppies in *Floppies*, hard-drive images in *HardDrives*, CDs in *CDs*.
The pickers only look there (subfolders are fine). On a Mac the folders are
inside the app's container — see [MACOS.md](MACOS.md).

---

## The menu

Tap the **gear** (top-right; it fades while you work — tap to bring it back):

- **Import Files…** — bring disks, ROMs and hard-drive images in without
  leaving the app
- **Kickstart ROM…** — built-in AROS, or your own
- **Hard Drives…** — mount `.hdf` images, several at once
- **CD-ROM & CD32 Console…** — insert a CD image; one tap switches to a
  full CD32 console (needs the CD32 Kickstart + extended ROM in `Kickstarts`)
- **Machine…** — presets (A500, A1200, A1200 Turbo, RTG + Net), CPU,
  memory, RTG graphics card, networking, MMU, Original/Maximum speed
- **Game Controller…** — port routing, CD32 pad mode, autofire
- **Configurations…** — save and load whole setups
- **Save States…** — three slots plus a five-minute autosave
- **iCloud Sync…** — configurations and save states across your devices
- **Clipboard…** — copy and paste between iOS and the Amiga
- **Display…** — Picture Fit/Stretch, CRT scanlines, Safe Area/Fullscreen,
  RTG Accel, LED bar, TV Out
- **Input & Overlays…** — Amiga keyboard, function keys, numpad, virtual
  joystick, keyboard style, 1:1 Mouse, Pencil pressure, serial tablet,
  floppy haptics
- **Reset / Hard Reset**
- **Controls & Help** and **About & Licenses**

The **disk button** (bottom right) opens the floppy and CD panel: drive
selector, floppy speed, insert and eject.

## Adding your own files (Files app)

**On My iPad › Amigo**:

| Folder | Put here |
|---|---|
| `Kickstarts` | Kickstart ROM files (and `rom.key` for Amiga Forever ROMs) |
| `Floppies` | `.adf` disk images (also `.adz`, `.dms`, `.ipf`, and `.zip`/`.lha`/`.lzx`/`.7z` archives) |
| `HardDrives` | `.hdf` hard-disk images |
| `CDs` | CD images (`.cue`+`.bin`, `.ccd`, `.mds`, `.nrg`, `.iso`, compressed `.chd`) |
| `Configuration` | saved setups (`.uae`) |

Drag files in with the Files app, use *gear › Import Files…*, drag them onto
the Amiga screen, or AirDrop them to the device, then pick them from the
menu. You supply your own ROMs and software — nothing copyrighted is bundled.

**On a Mac?** Amigo also runs on Apple Silicon Macs, where these folders live
inside the app's sandbox container instead — see [MACOS.md](MACOS.md) for how to
find them.

## Controls

**Touch (trackpad style, default):** slide to move · tap = left click ·
two-finger tap = right click · two-finger slide = scroll. **To drag** (move
icons, draw, select): tap, then touch again and drag — or hold still a moment
until the button engages, then drag.

**1:1 Mouse (menu toggle):** pointer follows your finger · touch = left click ·
second finger = right button · two-finger drag = scroll. Exact positioning
needs Kickstart 2.0+; on 1.3 your finger drags the pointer instead.

**Hardware:** Magic Keyboard, trackpad, and Bluetooth mice work directly.

**Game controllers:** pair in Settings › Bluetooth or plug into USB-C — Xbox,
PlayStation, Switch Pro and MFi pads all work. Then pick a port under **Game
Controller** in the gear menu ("Joystick Port" suits nearly every game); CD32
pad mode and autofire live there too.

**Apple Pencil:** touch = left button; double-tap = right click (Pencil 2 &
Pro). Hover-as-pointer needs an M2 or newer iPad with a compatible Pencil;
squeeze (= right click) is Apple Pencil Pro only.

**Pencil pressure.** Amiga paint programs read pressure through one of two
interfaces, and Amigo can feed both. Under **Input & Overlays**:

- **Pencil Pressure** offers the Amiga a `tablet.library`, which is what
  Deluxe Paint opens.
- **Serial Tablet** puts a Wacom graphics tablet on the Amiga's serial
  port, for programs that drive a tablet themselves rather than going
  through the system — TVPaint being the one that matters.

**Both are off until you turn them on**, and both take effect on the next
restart, because the Amiga sets its hardware up at boot. Leaving them off
costs you nothing: the Pencil still works as a pointer either way.

**Using it with TVPaint:** turn on *Serial Tablet*, restart, and in
TVPaint's configuration set the tablet **Type** to **Wacom A4+ Pressure**.
That entry matches the tablet Amigo emulates; picking a different size
leaves the pointer stuck at the edge of the screen. Pressure then reaches
TVPaint — how much a stroke changes with it depends on the brush and
profile you choose inside TVPaint.

**Cursor keys** type as cursor keys. Showing the **Virtual Joystick** turns
them (plus right Ctrl) into the emulated joystick — hide it to type again.

## Tips

- **Faster?** *Machine › Maximum* speed, and a 68040/68060 with more RAM
  (the *A1200 Turbo* preset). *Original* paces like real hardware and is
  easier on the battery — and what unregulated old games want.
- **Save your setup** with **Configurations**, and let **iCloud Sync**
  carry it to your other devices.
- **TV Out** (Display menu) puts the Amiga fullscreen on a USB-C or AirPlay
  screen and keeps the controls on the iPad.

## Notes

Amigo interprets the Amiga CPU (Apple doesn't permit JIT on the App Store),
so demanding software runs slower than on a PC — everyday Workbench, tools, and
many games run well. Files and setups survive app updates.
