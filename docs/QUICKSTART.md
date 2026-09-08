# Amigo Quick Start

**From a fresh install to a running Amiga, step by step.** This is the long
version of the in-app help. If you only read one thing, read
[Which Kickstart, which machine](#3-which-kickstart-which-machine) and
[Path A](#path-a--a-floppy-game-adf).

Amigo runs on iPad, iPhone and Apple Silicon Macs (as a "Designed for iPad"
app). It is a port of WinUAE, the reference Amiga emulator, with a native
touch interface. It is free, open source (GPL-2) and contains no Amiga ROMs
or software: you bring your own.

---

## Contents

1. [The one idea that explains everything](#1-the-one-idea-that-explains-everything)
2. [What the built-in AROS ROM does and does not do](#2-what-the-built-in-aros-rom-does-and-does-not-do)
3. [Which Kickstart, which machine](#3-which-kickstart-which-machine)
4. [Getting files into Amigo](#4-getting-files-into-amigo)
5. [Path A — a floppy game (ADF)](#path-a--a-floppy-game-adf)
6. [Path B — a hard-drive game pack (WHDLoad, AGS)](#path-b--a-hard-drive-game-pack-whdload-ags)
7. [Path C — Workbench and applications](#path-c--workbench-and-applications)
8. [Path D — CD32](#path-d--cd32)
9. [Saving what you built](#9-saving-what-you-built)
10. [Controls in two minutes](#10-controls-in-two-minutes)
11. [When it does not boot](#11-when-it-does-not-boot)
12. [Frequently asked](#12-frequently-asked)
13. [On a Mac](#13-on-a-mac)

---

## 1. The one idea that explains everything

An Amiga is three things stacked on each other, and Amigo lets you choose
each one:

| Layer | What it is | Where you set it |
|---|---|---|
| **Kickstart ROM** | The firmware. Decides which operating system and which games can start at all. | *gear › Kickstart ROM…* |
| **Machine** | CPU, chipset (OCS / ECS / AGA), memory, graphics card. Decides which software runs *correctly*. | *gear › Machine…* |
| **Media** | The floppy, hard drive or CD you boot from. | disk button, *gear › Hard Drives…*, *gear › CD-ROM…* |

Almost every "it does not work" on day one is one of these three not
matching the other two. A 1989 game on a fast AGA machine, a Workbench
built for a graphics card on a machine without one, a game disk on the free
replacement ROM. Once you can name the three layers, you can fix any of it
in two taps.

## 2. What the built-in AROS ROM does and does not do

Amigo starts immediately with **AROS**, a free, open-source replacement for
the Amiga's Kickstart. That is why the app can be free and on the App Store
without shipping Commodore's copyrighted firmware.

**AROS is good for:** Workbench-style software, hard-drive installs of many
programs, productivity tools, anything written "properly" against the
operating system. A lot of Amiga software runs fine on it.

**AROS is not good for:** the original floppy games. Most of them bypass the
operating system and talk to the Kickstart's internals or the hardware
directly, in ways a replacement cannot copy. The disk is read, the
Amiga shows the insert-disk hand again, and nothing you change in the
machine will help.

> If a game "works in every other emulator but not this one", that
> emulator had a real Kickstart configured already. Amigo has none until
> you add one.

## 3. Which Kickstart, which machine

### Getting a Kickstart ROM

The ROM is copyrighted. Legal sources:

- **Amiga Forever** by Cloanto sells all versions. Its ROM files are
  encrypted; copy the `rom.key` from the same installation next to them
  and Amigo decrypts on the fly.
- **Dump your own Amiga's ROM** with a transfer tool such as
  TransROM or GrabKick.
- Some AmigaOS distributions ship ROM images under licence.

### Recognising ROM files

| Kickstart | Version it reports | Size | Machines it came in |
|---|---|---|---|
| 1.2 | 33.180 | 256 KB | A500, A1000, A2000 |
| **1.3** | 34.5 | 256 KB | A500, A2000 — **the games ROM** |
| 2.04 / 2.05 | 37.175 / 37.350 | 512 KB | A500+, A600 |
| 3.0 | 39.106 | 512 KB | A1200, A4000 |
| **3.1** | 40.63 (A500/A600/A2000), **40.68 (A1200)**, 40.70 (A4000) | 512 KB | everything |
| CD32 | 40.60 + extended ROM | 512 KB each | CD32 (needs both files) |
| 3.1.4 / 3.2 | 46.143 / 47.x | 512 KB | modern AmigaOS releases |

Anything much smaller than 256 KB or much larger than 1 MB is not a
Kickstart, whatever it is called. A 1 MB file is usually two ROMs joined
and works. The setup check in the app (*Controls & Help › Why won't it
boot?*) reads the version straight out of the file.

### The matching table

| You want to run | Kickstart | Machine preset | Why |
|---|---|---|---|
| Games from 1985–1992 (most ADFs) | **1.3**, or 2.04 / 3.1 (40.63) | **A500** | 68000, no fast RAM, OCS/ECS: what the games assume |
| AGA games (1993+) | 3.1 A1200 (40.68) or 3.0 | **A1200** | 68020, AGA, 2 MB chip |
| WHDLoad packs, AGS, hard-drive game menus | 3.1 A1200 or 3.1.4 / 3.2 | **A1200 Turbo** | 68060, lots of RAM, loads instantly |
| Workbench, applications, big screen | 3.1, 3.1.4 or 3.2 | **RTG + Net** | graphics card and internet |
| CD32 | CD32 + extended ROM | **CD32** (CD-ROM menu) | the real console |
| Just look around | built-in AROS | anything | no files needed |

The default machine on a fresh install is an **A1200 with a 68020 and
8 MB fast memory**. That is a fine machine for hard-drive software and a
poor one for old floppy games, which is why the A500 preset exists.

## 4. Getting files into Amigo

Four ways, all ending up in the same place:

1. **Files app** → *On My iPad › Amigo* and drop files into the folder for
   their type.
2. **gear › Import Files…** opens a picker and files each item by its
   extension.
3. **Drag a file onto the Amiga screen** from Files or another app in
   Split View. A single dragged floppy goes straight into DF0.
4. **AirDrop** to the device, then choose Amigo.

| Folder | Put here |
|---|---|
| `Kickstarts` | ROM files, plus `rom.key` for Amiga Forever ROMs |
| `Floppies` | `.adf`, `.adz`, `.dms`, `.ipf`; archives `.zip` `.lha` `.lzx` `.7z` |
| `HardDrives` | `.hdf` hard-drive images (rename a raw `.img` to `.hdf`) |
| `CDs` | `.cue`+`.bin`, `.ccd`, `.mds`, `.nrg`, `.iso`, `.chd` |
| `Configuration` | saved setups (`.uae`) |

Subfolders are fine: `Floppies/Games/Lemmings.adf` shows up as
`Games/Lemmings.adf`. The pickers only look inside these folders, so a
file dropped in the top level of `Amigo` is not seen.

> **Importing a ROM does not select it.** This one step is where most
> first sessions go wrong. Until you tap the ROM under *Kickstart ROM…*,
> Amigo is still on AROS.

## Path A — a floppy game (ADF)

1. **Add the ROM** by any route above. The notice says *Imported … —
   select it under Kickstart ROM…*.
2. **Select it:** *gear › Kickstart ROM…*, tap the file. The Amiga restarts
   on the real Kickstart. The row with the filled check mark is the active
   ROM.
3. **Set the machine:** *gear › Machine…* › **A500**. Games from the OCS/ECS
   era were written for a 68000 with no fast memory; many refuse to start
   or crash on anything faster.
4. **Insert the disk:** tap the **disk button** in the bottom-right corner.
   Pick *DF0* if the drive selector is shown, then tap the ADF. The Amiga
   boots it. Multi-disk games: put disk 2 in *DF1* now so the game finds it
   without a swap.
5. **Play:** open *gear › Input & Overlays › Virtual Joystick*, or pair a
   Bluetooth controller and set it to *Joystick Port* under *gear › Game
   Controller…*. Fire is the button on the right of the on-screen stick.
6. **Save the machine** as a named setup (section 9) so "Games A500" is one
   tap next time.

**Floppy speed.** The disk panel has a speed selector. *Turbo* loads
instantly and is right for most games; copy-protected or timing-sensitive
disks fall back to real speed on their own, and if a game misbehaves while
loading, *1×* is the safe setting.

## Path B — a hard-drive game pack (WHDLoad, AGS)

The Amiga community packages hundreds of games onto one hard-drive image
with a menu. This is the best way to play a lot of games, and the recipe is
short. One App Store reviewer's exact words: "It took me longer to copy the
files than it did to get AGS running."

1. Put the image into *HardDrives*. If it is called `.img`, rename it to
   `.hdf` first.
2. Put a **Kickstart 3.1 (A1200)** or newer into *Kickstarts* and **select
   it** under *Kickstart ROM…*.
3. *gear › Hard Drives…* › tap the image. It mounts as DH0.
4. *gear › Machine…* › **A1200 Turbo**. Most packs expect a fast machine
   with plenty of RAM; a plain A1200 works but loads slowly.
5. *gear › Reset*. The image boots into its own menu.

Quit keys: WHDLoad games leave with a numpad key, usually `*` or `-`.
*gear › Input & Overlays › Numpad* puts those on screen.

**About `.lha` archives.** WHDLoad games are also distributed as single
`.lha` archives. Amigo can insert an archive as a floppy, but the game
inside still needs WHDLoad installed on a Workbench hard drive to run, so
start from a pre-built image unless you already have that.

## Path C — Workbench and applications

**From a ready-made hard-drive image.** Same as Path B, and pick
**RTG + Net** instead of Turbo when the Workbench on the image was set up
for a graphics card: RTG is what gives you a 1280×720 or larger
high-colour screen instead of a PAL display. Inside the Amiga, the screen
mode lives in *Prefs › ScreenMode*; look for the UAE or uaegfx modes.

**From install floppies.** Boot the Install disk in DF0 with the matching
Kickstart, mount an empty hard-drive image under *Hard Drives…*, and follow
the installer inside the Amiga. Amigo cannot create an empty image yet; use
one from an AmigaOS distribution or make one on a computer with a
disk-image tool.

**On AROS.** The built-in ROM runs Workbench-compatible software from a
hard-drive image with no Kickstart at all. Good for trying things out.

**Networking.** The *RTG + Net* preset turns on the `bsdsocket.library`
bridge, so Amiga internet software (browsers, FTP, IRC) goes straight
through the device's connection. No TCP/IP stack is needed inside the
Amiga.

## Path D — CD32

1. Both CD32 ROM files, the Kickstart **and** the extended ROM, into
   *Kickstarts*.
2. The CD image into *CDs*.
3. *gear › CD-ROM & CD32 Console…* › **Switch to CD32 console**. This
   replaces the whole machine with WinUAE's CD32.
4. Insert the CD from the same panel. Use a controller in **CD32 pad
   mode** (*Game Controller…*) for the extra buttons.

Applying any Machine preset switches back to a computer.

## 9. Saving what you built

*gear › Configurations…* saves the current ROM, machine, drives and disks
under a name. Keep one per purpose:

- **Games A500** — 1.3, A500 preset
- **WHDLoad** — 3.1, A1200 Turbo, the games image
- **Workbench** — 3.2, RTG + Net, your system image

Switching is one tap and restarts the Amiga into that setup. Setups
survive reinstalling the app, and **iCloud Sync** (*gear › iCloud Sync…*)
carries setups and save states to your other devices. Disk images are
not synced unless you turn that on, because hard-drive images are large.

**Save States** (*gear › Save States…*) freeze the running Amiga into one
of three slots, with an automatic save every five minutes. They belong to
the machine they were taken on; change the machine and they will not
restore.

## 10. Controls in two minutes

**Touch, the default.** The screen is a trackpad. Slide to move the
pointer. Tap = left click. Two-finger tap = right click. Two-finger slide
= scroll. **To drag** an icon or draw: tap, then touch again and drag, or
hold still a moment until the button engages and then drag.

**1:1 Mouse** (*Input & Overlays*) makes the pointer jump to your finger,
touch holds the button, a second finger is the right button. Needs
Kickstart 2.0 or newer; on 1.3 it falls back to trackpad style.

**Keyboard.** *Input & Overlays › Amiga Keyboard*. Modifier keys latch:
tap Shift, then the key. Function keys and the numpad are separate
overlays. A Magic Keyboard or any Bluetooth keyboard works directly.

**Joystick.** *Input & Overlays › Virtual Joystick*. While it is shown,
the cursor keys and right Ctrl also act as the joystick. Bluetooth pads
(Xbox, PlayStation, Switch Pro, MFi) pair in iOS Settings and are routed
under *Game Controller…*; *Joystick Port* suits almost every game.
Auto-fire is there too.

**Apple Pencil.** Touch = left button, double-tap = right click (Pencil 2
and Pro), squeeze = right click (Pencil Pro). On an M2 or newer iPad,
hovering moves the pointer without clicking. Pressure for paint programs
is off by default: *Pencil Pressure* for programs that use the system
tablet interface (Deluxe Paint), *Serial Tablet* for programs that drive a
Wacom themselves (TVPaint: set its tablet type to *Wacom A4+ Pressure*).
Both take effect after a restart.

**Display.** *Display…* has *Picture: Fit / Stretch*, CRT scanlines, *Safe
Area / Fullscreen* for the notch and rounded corners, and *TV Out*, which
puts the Amiga fullscreen on a USB-C or AirPlay screen while the controls
stay on the iPad.

## 11. When it does not boot

Open **gear › Controls & Help › Why won't it boot?** (also at the bottom of
the disk panel). It reads the ROM file, the machine and the inserted disk,
and lists what does not match, most serious first. *Copy* puts the report
on the clipboard for a support mail or a GitHub issue.

What it will usually find, and what to do:

| Symptom | Likely cause | Fix |
|---|---|---|
| Insert-disk hand stays, or comes back after the disk is read | AROS is still selected | *Kickstart ROM…* › tap your ROM |
| Same, with a real ROM selected | Machine too modern for the game | *Machine…* › **A500** |
| Same, and the disk is disk 2 or a data disk | Not a boot disk | Boot disk 1 or a Workbench first |
| "ROM file is not a Kickstart" | Wrong file, or an archive renamed `.rom` | Check size: 256 or 512 KB |
| Amiga Forever ROM never starts | `rom.key` missing | Copy it into *Kickstarts* |
| Game shows garbage, freezes or resets | Fast RAM / CPU / AGA mismatch | A500 preset; floppy speed 1× |
| Hard drive boots to a black screen | Workbench expects a graphics card | **RTG + Net** preset |
| Hi-colour screens look wrong | RTG acceleration | *Display › RTG Accel* off (default) |
| Pointer moves but nothing clicks, after pairing a controller | Known bug | Quit and reopen Amigo; the pad stays paired |
| Files do not appear in a picker | Wrong folder | ROMs in `Kickstarts`, disks in `Floppies`, images in `HardDrives` |

## 12. Frequently asked

**Is it fast?** Amigo interprets the 68k CPU, because Apple does not allow
JIT compilation on the App Store. An emulated 68060 still runs several
times faster than the real chip on a recent iPad, so Workbench, tools and
nearly all games are comfortable. Demanding 3D or heavily compiled
software runs slower than on a desktop emulator with a JIT.

**Original or Maximum speed?** In *Machine…*. *Original* paces the CPU
like real hardware, uses far less battery, and is what unregulated old
games expect. *Maximum* uses every spare cycle. The 68000 is always paced
originally.

**Where did my files go after an update?** Nowhere: the `Amigo` folder in
Files survives updates and reinstalls, and saved setups repair their paths
automatically.

**Can I use several hard drives?** Yes. Each mounts as its own DH0, DH1 …
volume under *Hard Drives…*. Give every partition a different name; AmigaOS
silently drops a second volume with the same name as one already mounted.

**Copy and paste with iOS?** *gear › Clipboard…* turns on sharing; text
copied in the Amiga appears on the iOS clipboard and vice versa after a
restart.

**Does it run on iPhone?** Yes, the same app. Landscape is the comfortable
orientation; a 4:3 Amiga screen cannot fill a tall phone in portrait.

**Apple TV?** Not as a native app. Use an iPad with *TV Out* over USB-C or
AirPlay.

**Where do I report a problem?** Open an issue at
https://github.com/thomas-luebker/Amigo/issues with the report from
*Why won't it boot?*, your device and iOS version, and which Kickstart you
used. Reviews on the App Store cannot be answered in detail, GitHub issues
can.

## 13. On a Mac

Amigo runs on Apple Silicon Macs as a "Designed for iPad" app. Everything
above applies; the `Amigo` folder lives inside the app's sandbox container
rather than in Files. The exact path and a one-line shortcut to open it
are in [MACOS.md](MACOS.md).

---

*More detail on every control and menu row: [USER_GUIDE.md](USER_GUIDE.md).
The app is GPL-2; source and issues: https://github.com/thomas-luebker/Amigo.*
