# Amigo — Amiga Emulator

**The classic Commodore Amiga on iPad, iPhone and Apple Silicon Macs.**
A native port of [WinUAE](https://github.com/tonioni/WinUAE), free, without
ads or accounts, and **GPL-2** like WinUAE itself.

[**Download on the App Store**](https://apps.apple.com/app/id6792285150) ·
[**Quick Start guide**](docs/QUICKSTART.md) ·
[User guide](docs/USER_GUIDE.md) ·
[Report a problem](https://github.com/thomas-luebker/Amigo/issues)

**0.7.7 is on the App Store** (live 2026-09-09 —
[release notes](https://github.com/thomas-luebker/Amigo/releases)).

## First start

Amigo boots the free AROS ROM on first launch, so there is nothing to set up
to look around. To run real Amiga software you bring your own Kickstart ROM
and disks; the app ships none. The three things that decide whether something
runs are the **Kickstart**, the **machine** and the **media**, and the
[Quick Start](docs/QUICKSTART.md) walks through each one, with one path each
for floppy games, WHDLoad packs, Workbench and CD32, a table of which
Kickstart file is which, and a symptom table for when the Amiga keeps showing
the insert-disk hand. The same check is built in: *Controls & Help › Why
won't it boot?* reads your setup and names the mismatch.

## What it does

- Emulates the whole classic range, from a stock A500 to a 68060 with RTG
  graphics, up to 256 MB of Zorro III RAM and networking through
  `bsdsocket.library`; presets for A500, A1200, A1200 Turbo, RTG + Net and a
  one-tap **CD32 console**
- Floppies (ADF, ADZ, DMS, IPF, and ZIP/LHA/LZX/7z archives), several
  hard-drive images mounted at once, CD images on any machine
- Touch as a trackpad or 1:1 pointer, on-screen Amiga keyboard, numpad,
  function keys and joystick, hardware keyboards, mice and trackpads
- Bluetooth and USB game controllers with port routing, CD32 pad mode and
  autofire
- **Apple Pencil**: hover pointer, squeeze and double-tap right-click, and
  pressure for paint programs through `tablet.library` or an emulated serial
  Wacom tablet (TVPaint)
- AHI sound through the UAE sound card, copy and paste with iOS both ways
- **TV output** over USB-C or AirPlay with the controls staying on the iPad,
  save states with autosave, named machine configurations, **iCloud sync**
  of configurations and save states
- A "Why won't it boot?" setup check that reads the ROM, machine and disk and
  says what does not match

The 68k CPU is interpreted, since Apple does not allow JIT on the App Store;
an emulated 68060 still runs several times faster than the real chip on a
recent iPad.

Ships with upstream fixes discovered during the port — a WinUAE
mousehack-after-reboot fix, an SDL3 UIScene fix (a second scene re-ran
`SDL_main` and crashed any SDL iOS app on AirPlay connect), and bounds
checks in the LHA decoder — see `patches/`.

> Formerly developed under the working title "iPadUAE"; the bundle ID and
> the `ipaduae_*` internal symbols keep that name.

## Docs

- [`docs/QUICKSTART.md`](docs/QUICKSTART.md) — first start: fresh install to a running Amiga, by goal
- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — every menu and control, troubleshooting
- [`docs/MACOS.md`](docs/MACOS.md) — running Amigo on an Apple Silicon Mac, and
  where to put your ROMs and disk images there
- [`docs/TESTER_GUIDE.md`](docs/TESTER_GUIDE.md) — TestFlight tester guide
- [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) — release/archive steps
- [`docs/LICENSING.md`](docs/LICENSING.md) — GPL-2 / App Store plan
- Deep design notes live in the author's Obsidian vault (`iPadUAE/` folder).

## Layout

- `vendor/WinUAE` — upstream WinUAE as a git submodule (do not edit in place;
  patches to upstream live in `patches/`, applied via `scripts/apply-patches.sh`)
- `vendor/SDL3` — official SDL3 xcframework (device + simulator)
- `core-ios/` — CMake wrapper: builds the core as `libuaecore.a`, adds `ios_glue.cpp`
- `app/` — the iPad application (XcodeGen project, Swift/SwiftUI + ObjC++ bridge)
- `scripts/` — `build-ios-core.sh`, `build-release.sh`, `apply-patches.sh`
- `docs/` — user- and tester-facing documentation

## Building

```sh
git submodule update --init      # vendor/WinUAE
./scripts/apply-patches.sh       # applies patches/*.patch (idempotent)
./scripts/build-ios-core.sh      # cross-compiles build/ios/libuaecore.a (arm64 iOS)
xcodegen -s app/project.yml      # regenerates app/Amigo.xcodeproj
open app/Amigo.xcodeproj       # build & run the Amigo target on an iPad
```

For a TestFlight/App Store archive: `./scripts/build-release.sh`.

Upstream patches needed for iOS live in `patches/` and are also applied in the
`vendor/WinUAE` submodule working tree.

## Constraints

- **No JIT** on iPadOS (no writable+executable pages) — CPU emulation runs interpreted.
- **No Qt** — the desktop Qt config UI is replaced by a native SwiftUI surface.
- **No bundled Kickstart ROMs** — users import ROMs via the Files app; the
  built-in AROS ROM (`aros.rom.cpp`, already in the WinUAE tree) is the fallback.
