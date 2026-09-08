# Review of "Amigo improvement plan (LLM work spec)" — 2026-09-08

The plan (`~/Downloads/Amigo-Improvement-Plan.md`, external, unattributed) was
checked claim by claim against this tree at `1c92b57` and against the vault
note. This file records what holds, what is stale, and what the plan gets
wrong, so that nobody implements against a premise the repo has already
moved past. Section numbers follow the plan.

## What is correct and can be trusted

- **§0 touch map, build loop, hard rules.** Every file it names exists. The
  build chain (`apply-patches.sh` → `build-ios-core.sh` → `xcodegen`) is the
  real one. Bundle id `de.amiga-imager.uae`, iCloud container
  `iCloud.de.amiga-imager.uae`, iOS 17 only, device family `1,2`, no tvOS
  conditionals anywhere — all verified. The DF1 / `GF_RTG` / `didSet`
  footguns are quoted accurately from `docs/BACKLOG.md:69-87`.
- **A1 (clicks die after pairing a controller).** Still open, still the top
  device bug. The plan's summary matches `docs/BACKLOG.md:90-135` exactly,
  including the disproven port-steal theory and the two surviving suspects
  (`UIDropInteraction` in `MediaImport.swift:118`, a stuck button-down).
- **A3 (boot / disk-insert failures).** Not in the backlog as an item, but
  it is the shape of both recent 2★ reviews (Beronk 08-27, Dethmuerte
  09-03). A diagnostic sheet is a sound response. One correction below.
- **A5 (audio).** Accurate: the UAESND board fix shipped in 0.7.6, "AHI
  plays sound" is unproven, and `uae.audio` is to ship as an amipkg
  package. Matches `docs/BACKLOG.md` *From user mail*.
- **B4 (hygiene warnings).** Matches *Product hygiene* verbatim. The
  Kick/CPU mismatch check is a new, sensible addition.
- **§5 display.** Scanlines already touch only scanline fields (the
  `gfx_filter_bilinear` regression is fixed). The SDL3 scene patch is
  real: `patches/sdl3-0001-scene-connect-single-main.patch`. External
  display with controls staying on the iPad shipped with
  `feature/showcase`.
- **§6 performance.** Every bullet is on the backlog. The 32 MB RTG option
  was removed as stated.
- **§8 tvOS constraints table.** Consistent with the 2026-09-05 assessment.
  The SDL3 xcframework question is settled: `vendor/SDL3/SDL3.xcframework`
  carries `ios-arm64` and `ios-arm64_x86_64-simulator` only, and
  `scripts/build-sdl3.sh` builds for `iphoneos` only. tvOS would need a
  new SDL3 build before anything else.

## What is stale or wrong

- **A2 iCloud: the premise is wrong.** The plan says "users report it does
  not work". No user has reported that. iCloud sync shipped in 0.7.2 and
  was verified on the M4 iPad (`docs/BACKLOG.md` *iCloud — in 0.7.2 after
  all*). Container, entitlements and the mounted-file exclusion are done.
  What remains is exactly two backlog items: the **second-device check**
  and the awkwardness of the mount exclusion. The plan's "fix container /
  ubiquity identity" and "never sync a mounted HDF" are already done.
  Still worth doing from A2: the exclusion list is not shown in the UI,
  and there is no conflict policy for save states (CloudSync is a
  push/pull copy, not `NSFileVersion`-aware).
- **A4 Pencil: the symptoms it lists are fixed.** "Drag-as-click, TVPaint
  always-down, no lift between strokes" were Chad's 0.7.5 complaints;
  0.7.6 fixed all of them (vault note, Next Actions). The three open Pencil
  items are the ones the plan lists second: the DPaint `<< 15` range
  check, which tablet TVPaint's launch menu lists, and the separate 1:1
  click bug (`docs/BACKLOG.md:620`). The "input profiles" split is a new
  product idea, not a fix; today there is one toggle (`tabletMode`).
- **A3 correction.** There are no `ipaduae_*` prefs getters for Kickstart
  version, chipset or CPU. `ios_glue.cpp` exports only floppy LED mask,
  drive count, floppy speed and vpos. `ConfigStore` works from the `.uae`
  text. A diagnostic sheet needs new read-only getters, or must derive
  everything from the config text. The app also does no ROM
  identification (no CRC or version parsing anywhere in `app/Sources`).
- **§4 autofire: already shipped.** `VirtualJoystickView` has
  `autoFireTimer` and reads `OverlayState.autoFireRate`; the controller
  submenu has an "Auto-Fire: N/sec" row (0/6/10/15). It went out in 0.7.5
  (commit `9da5d82`, What's New: "port routing and autofire"). The backlog
  line asking for it was stale and is corrected in this commit. Only the
  "UI polish" half of Smurfy2000's request is open.
- **B1 presets: partly exists.** `MachinePanel` already offers A500,
  A1200, A1200 Turbo, RTG + Net and CD32 chips, and the Original/Maximum
  speed switch. The plan's template table is close to `ConfigStore.Machine`
  (A500 is `ecs_agnus` 68000 1 MB chip; A1200 is AGA 68020 2+8 MB). What
  does not exist is the goal-first flow, Kickstart identification and the
  mismatch warnings. B1 is therefore a wizard over existing presets, not
  new machine definitions.
- **B2 WHDLoad browser.** New, not on the backlog. LHA-as-floppy works and
  LZX is compiled in (`archivers/lzx`, symbols present in
  `libuaecore.a`). Nothing scans folders for titles today.
- **B3 host folder as volume: feasible.** `fsdb_unix.cpp` and
  `filesys_host.cpp` are in the core build and `my_opendir` is defined in
  `libuaecore.a`, so `filesystem2=rw,DH2:Name:/path,0` would work at the
  emulator level. Nothing in `ConfigStore` or the UI touches
  `filesystem2` yet. The iOS-specific work is a security-scoped bookmark
  for a Files-picked folder; the app's own `amigo/` folders need nothing.
- **§5 integer scale.** Only Fit/Stretch exist in the UI. The core patch
  has an integer branch for RTG (`patches/0001-ios-port-fixes.patch:1652`)
  that is not exposed. Overscan crop and bezel do not exist.
- **§6 omission.** The plan does not know about `perf/mmu-hostptr`
  (`patches/0002-mmu-host-pointer-cache.patch`, +7 to +20 %), which is the
  furthest-along performance lever and has one known correctness hole
  (stale pointer on bank remap without ATC flush).
- **§8 tvOS mouse: now verified, the plan was right.** `GCMouse` is
  available on tvOS 14.0+ (Apple docs, `platforms` array). SDL3's
  `SDL_uikitevents.m` initialises `GCMouse` under
  `@available(iOS 14.1, tvOS 14.1, *)` with no tvOS exclusion, so a
  Bluetooth mouse would reach SDL on Apple TV. That closes the
  load-bearing unknown in the 2026-09-05 assessment: a tvOS Amigo could be
  "an Amiga on a TV", not only games. The ingest problem (no Files app)
  stands unchanged.
- **§8 milestone 0** ("fix iCloud") should read "verify iCloud on a second
  device". It is a test, not a fix.
- **§9 order.** Holds once A2 and A4 are re-scoped as above. Step 7
  (autofire) drops out.

## What the plan does not know that would change its priorities

- Both 2★ reviews are onboarding failures, not defects. The store text was
  reworded on 2026-09-07 but only ships with the next submission. A3 and
  B1 are the code-side answers to the same problem and are the highest
  product leverage right now, above A1.
- Two public review replies are outstanding (Chad 4★, Dethmuerte 2★).
  Those are cheaper than any item in the plan.
