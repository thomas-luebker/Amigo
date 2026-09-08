# Amigo on Apple TV — plan and state (`feature/tvos`)

Branch opened 2026-09-08 after the request by mail (assessment in
`BACKLOG.md` → *Apple TV / tvOS*). This file is the working plan; the
backlog entry stays the decision record.

## What is settled

- **The emulator ports.** WinUAE on the Unix/SDL3 layer is platform-neutral;
  SDL3 supports tvOS. Controller support (MFi, CD32 pad mode, port routing,
  autofire) is already the right shape for a television.
- **A mouse works on tvOS.** `GCMouse` is available from tvOS 14.0 (Apple's
  GameController docs), and SDL3's `SDL_uikitevents.m` initialises it under
  `@available(iOS 14.1, tvOS 14.1, *)` with no tvOS exclusion. So Workbench
  is drivable with a Bluetooth mouse: this can be "an Amiga on a TV", not
  only games.
- **The app does not port.** tvOS has no Files app and no document picker,
  treats local storage as purgeable, has no touch, no Pencil and no dense
  inspector UI. Every Amigo panel and every import path is iOS-only.
- **Nothing in the tree targets tvOS yet.** `app/project.yml` is iOS 17,
  device family `1,2`; `vendor/SDL3/SDL3.xcframework` carries `ios-arm64`
  and the iOS simulator only; `scripts/build-sdl3.sh` builds `iphoneos`.

## The shape of the product

Not a `#if os(tvOS)` on the existing target. A **second app target,
`AmigoTV`**, sharing:

- `libuaecore.a` built for `appletvos`
- `core-ios/ios_glue.cpp`, UAE prefs handling, `ConfigStore`, save states,
  hardfile handling

and **not** sharing `PencilSupport.swift`, the touch 1:1 path, the virtual
keyboard/joystick overlays, or the Files-based `MediaImport` UI.

Three surfaces only:

1. **Library** — saved configurations and last-played, read from the same
   iCloud container the iPad app writes (`iCloud.de.amiga-imager.uae`).
   The iPad/iPhone app is the librarian; the TV plays.
2. **Play** — the Amiga fullscreen, a slim overlay for disk, pause, save
   state and reset.
3. **Settings** — presets, not raw UAE keys.

Input: game controller → joystick / CD32 pad (existing mapping); Bluetooth
mouse → real mouse; Siri Remote touch surface → relative mouse with
click-to-select; keyboard → Bluetooth keyboard. An empty state that says
"Workbench needs a mouse or a pad".

Media: iCloud (configs, save states, and optionally disk images) is the
ingest path. A LAN import (HTTP/SMB) is a later option and needs the
local-network entitlement. Apple TV storage is small and purgeable, so
multi-GB HDFs should stay in iCloud or on a NAS.

Store: Apple TV 4K only in the compatibility text. Same "bring your own
Kickstart" wording. No bundled ROMs. No JIT (same interpreter core; fine
for A500-class work, RTG 060 Workbench depends on the A-series chip).

## Milestones

0. **iCloud on a second device** — the TV reads what the iPad wrote, so this
   has to be verified first. Still open in `BACKLOG.md` (*iCloud — in 0.7.2
   after all*: "second device still to check").
1. **The core compiles for `appletvos`.** `scripts/build-ios-core.sh tvos`
   (added on this branch) builds `libuaecore.a` against the tvOS SDK using
   the iOS SDL3 headers (a static library needs no SDL binary) and without
   FLAC (no tvOS build of it yet). Result: see *State* below.
2. **SDL3 for tvOS.** Extend `scripts/build-sdl3.sh` with an `appletvos`
   slice (`-DCMAKE_SYSTEM_NAME=tvOS`, `-sdk appletvos`) and add it to the
   xcframework. Needs an SDL 3.4.12 source checkout; none is on disk.
3. **Render + audio in an empty window** on an Apple TV 4K or the tvOS
   simulator: `libuaecore.a` + SDL3, one hardcoded config, AROS ROM, no UI.
   This is the go/no-go.
4. **Minimal AmigoTV**: one config, Bluetooth pad, HDMI output, save state.
5. Library from iCloud; remote-as-mouse good enough for Workbench menus.
6. Then Top Shelf, LAN import, store listing.

Until step 3 is green, the answer to "Apple TV?" stays: **iPad with TV Out
over USB-C or AirPlay**, which already exists and is on the store page.

## State

- **2026-09-08 — milestone 1 green.** `scripts/build-ios-core.sh tvos`
  produces `build/tvos/libuaecore.a`: arm64, `LC_BUILD_VERSION` platform 3
  (tvOS), minos 17.0, tvOS 26.5 SDK, 85 MB, 261 translation units. Two
  changes were needed and both are small:
  - **CHD off** for this platform: the tree makes CHD require libFLAC and
    there is no `appletvos` FLAC build yet (`build-flac-ios.sh` needs an
    `appletvos` variant; it is a copy of the `iphoneos` case).
  - **slirp's `fork()`/`execvp()`** are marked unavailable on tvOS. They
    only serve "exec" port forwarding, which Amigo never configures, so
    `slirp/misc.cpp` now defines both to fail on `TARGET_OS_TV` and
    `fork_exec()` takes its existing failure path. Carried in
    `patches/0001-ios-port-fixes.patch`.
  Everything else — the 68k core, chipset, RTG, disk, filesystem, LHA/LZX,
  UAESND, bsdsocket, the SDL3 video/audio layer, `ios_glue.cpp` — compiled
  for tvOS unchanged. The `TARGET_OS_IPHONE` guards cover tvOS because
  tvOS defines it too.
  Not yet done: an `appletvos` SDL3 slice (milestone 2), so nothing has
  been linked or run. The next step is `build-sdl3.sh` with a tvOS case
  against an SDL 3.4.12 checkout, then an empty-window render test on the
  tvOS simulator.
