# Amigo — Feature Backlog

Planning home: the Obsidian note "iPadUAE — Roadmap & Open Questions"
(kept in sync manually; this file is the repo-visible mirror).

## 0.7.2 — in progress (opened 2026-08-18)

Release container exists on both sides: `app/project.yml` is bumped to
MARKETING_VERSION 0.7.2 / CURRENT_PROJECT_VERSION 20260818, and App Store
Connect version 0.7.2 is created in PREPARE_FOR_SUBMISSION
(id 69da2f0e-ad82-4e28-b9d8-cd297a3edb20) with de-DE fully populated.
See APPSTORE.md for what went into de-DE and why it could not be done on
0.7.1.

### Blocking — before submission

- [ ] **Per-side shift keys.** Code is on `fix/shift-keys` (08ec0bf),
  untested on hardware. The only bug from the r/amiga launch thread that
  0.7.1 did not answer — DotMatrixHead: both shifts arrive as left
  shift, "makes playing pinball impossible". To land: build Release to
  the test iPad, stream the log, press each shift alone and both
  together on a hardware keyboard, confirm iOS reports the sides
  separately, then **remove the temporary diagnostic log line** and
  merge. Not verifiable from the agent side — needs hands on a keyboard.
- [ ] **Top both What's New lists with the real 0.7.2 changes.** en-US
  and de-DE on the 0.7.2 record currently hold the 0.7.1 batch, which
  never reached the store (0.7.1 shipped with 0.7.0's notes). Prepend to
  it, do not replace it.
- [ ] **Pick a subtitle.** ASC has "Classic Amiga Emulator", APPSTORE.md
  says "Classic Amiga computing". They disagree.
- [ ] **Confirm de-DE inherits the en-US screenshots** in the ASC UI —
  the de-DE localization has no screenshot sets of its own. Expected to
  fall back to the primary locale, but that is not visible through the
  API.

### Candidates — undecided

- [ ] **Pro Controller in Project X.** DotMatrixHead reported the pad
  not working in that game specifically. Uninvestigated; could be
  mapping, could be game-specific. The 0.7.0/0.7.1 controller work did
  not target it.
- [ ] Quick wins from the section below. Verified absent from the code
  on 2026-08-18 (grep over `app/`, `core-ios/`, all branches): warp
  button, drag & drop from Files, DF2/DF3, CRT shader. Each is real
  work, not a stale checkbox.

### Explicitly not in 0.7.2 unless decided otherwise

- Vision Pro "Designed for iPad" — verify on the visionOS sim first (see
  below). A broken compat-mode experience earns 1-star reviews that are
  hard to undo.
- iCloud sync — `feature/icloud-sync`, still blocked on the one-time
  Xcode GUI Run to register the capability.

## Quick wins (a session each)

- [ ] **Warp button** — hold to uncap emulation during disk loads (WinUAE
  warp mode exists, just expose it).
- [ ] **Drag & drop from Files** — drop an `.adf` anywhere → insert DF0.
- [ ] **Floppy haptics** — CoreHaptics tick on drive activity (setting-gated).
- [ ] **DF2/DF3** — four drives in the menu for multi-disk games.
- [ ] Keyboard layout polish (flex widths uneven).
- [ ] In-app `.fileImporter` import (nice-to-have; Files app already works).

## From the r/amiga launch thread (2026-08-15, prioritized)

- [x] **Portrait "keyboard below screen" layout** — done: keyboard strip
  reported as bottom inset, picture lays out above it; Picture Fit/Stretch
  menu toggle (default Stretch).
- [x] **Cursor keys type again** (r/amiga 08-16) — kbd2 occupies the
  joystick port only while the Virtual Joystick overlay is shown.
- [x] **CD support, stage 1: mounting UI + CD32 preset** — done: CDs
  folder, CD-ROM picker (cue/ccd/mds/nrg/iso), cdimage0 plumbing, CD32
  via `quickstart=cd32,0` (built-in machine + auto ROM resolution).
- [x] **CD support, stage 2: CHD** — done: vendored static libFLAC 1.5.0
  (scripts/build-flac-ios.sh), CMake escape hatch, CHD flags on, .chd in
  the CD picker.
- [ ] **Both shift keys read as left shift** (DotMatrixHead) — "makes
  playing pinball impossible". Code on `fix/shift-keys`, hardware test
  pending; see the 0.7.2 section above.
- [ ] **Pro Controller not working in Project X** (DotMatrixHead) —
  uninvestigated; see the 0.7.2 section above.
- [ ] **Vision Pro "Designed for iPad"** — ASC availability checkbox, no
  build change. Verify on visionOS sim first: overlay UIWindow composites,
  right-click reachable (recommend Bluetooth mouse in help). Native
  target: 1-2 weeks, only if compat mode shows demand.

Done: controller-routing-lost-on-restart fix, LHA/LZX/7z pickers,
Controls & Help panel, tap-then-drag + hold-to-drag + KS1.3 1:1
fallback (all 0.7.1 candidates). iPhone: shipped with 0.7.0.

## Killer features (medium)

- [x] **Save-state UI** — shipped: 3 slots + 5-min autosave (quick-state
  machinery, StatePanel). Later polish: screen thumbnails per slot, pin
  the config per slot (states are fragile across config changes).
- [ ] **CRT shader** — scanlines/phosphor Metal post-process on the SDL
  texture; the most-requested emulator feature.
- [ ] **Disk-set swap strip** — detect "Disk 1 of 3" filename sets, show a
  one-tap swap bar when a game asks for the next disk.
- [ ] **In-app disk creation via AmigaDiskKit** — "New blank ADF / new
  RDB-formatted HDF…" in the Hard Drive menu.
- [ ] AmigaDiskKit-powered media browser (peek inside HDFs/ADFs).

## Ambitious (demo-day)

- [x] **External display** — shipped with `feature/showcase`:
  `ipaduae_set_external_display`, TV Out row in Overlay.swift. USB-C and
  AirPlay, controls stay on the iPad.
- [x] **Apple Pencil hover as pointer** — shipped:
  `PencilSupport.swift` / `PencilHoverDriver`. Needs an M2+ iPad.
- [ ] **iCloud-synced setups** — IMPLEMENTED on feature/icloud-sync
  (CloudSync engine, entitlements, panel toggle, visible iCloud Drive
  folder); blocked on one-time Xcode GUI Run to register the iCloud
  capability + container iCloud.de.amiga-imager.uae on the App ID
  (CLI signing cannot). Resume: checkout branch, GUI Run once, test
  13"↔11" sync.
- [ ] **App Intents/Shortcuts** — "Boot <config>" from Spotlight/widgets.

## Power / energy

- [ ] **Power modes** — replace the binary Speed toggle: Performance
  (today's cpu max + vsync off), Balanced (cpu max + vsync on, ~1/3
  energy cut — measured 38% thread-block; proposed default), Authentic
  (m68k_speed=0 real pacing + vsync on — longest battery AND correct
  speed for unregulated games). Auto-downshift on iOS Low Power Mode,
  always visibly (menu label change). Nothing removed; defaults decide
  perception — keep Performance one tap away. 8414a8e added the
  `cpu_idle` config key, but left the default at 0: the measured
  effect oscillates (sleepmode arms and resets) and needs tuning.
- [x] Idle throttle — landed in 8414a8e (vsync_isdone returns -2 when
  vsynced so the host actually idles).
- [x] Skip present when the emulated framebuffer is unchanged — landed
  in 8414a8e (static-frame skip, ~30% of samples on an idle RTG
  Workbench).

## Product hygiene

- [ ] Warn when an HDF is mounted but no RTG board is configured (the
  "never boots in RTG" fresh-install footgun).
- [ ] Device-independent RTG mode list (host-derived modes get index-based
  IDs → guest screenmodes break when a setup moves between devices).

## Performance (carried from roadmap)

- [ ] Emulation on its own thread (structural lever if benchmarks demand).
- [ ] Root-cause the >8-bit RTG accelerated-blit bug (bisect the 8 ops),
  fix properly, offer upstream.
- [ ] Offer the patch set upstream to Toni Wilen (iOS guards, RTG reset
  handler, mousehack mode-4 fix, toggle_rtg robustness).
- [ ] Try `gfxcard_multithread`.
