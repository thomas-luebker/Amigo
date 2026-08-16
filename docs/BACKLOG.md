# Amigo — Feature Backlog

Planning home: the Obsidian note "iPadUAE — Roadmap & Open Questions"
(kept in sync manually; this file is the repo-visible mirror).

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
- [ ] **CD support, stage 1: mounting UI + CD32 preset** — core already
  compiles cue/iso/ccd/mds/nrg (akiko, cdtv, blkdev_cdimage, cda_play).
  App needs: CDs folder, picker, `cdimage0`/`cd32cd` config writing,
  CD32 machine preset + extended ROM handling. ~1-2 days.
- [ ] **CD support, stage 2: CHD** — all source vendored with unix shims;
  zlib+LZMA already linked. Only blocker: static libFLAC for iOS + a
  non-pkg-config detection path, then flip WINUAE_UNIX_WITH_CHD(_FLAC).
  ~0.5 day, zero C++ changes. Pointless before stage 1.
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

- [ ] **External display** — Amiga fullscreen on TV via USB-C/AirPlay,
  controls stay on the iPad (SDL3 + UIScene).
- [ ] **Apple Pencil hover as pointer** — hover moves the Workbench
  pointer, tap clicks.
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
  perception — keep Performance one tap away.
- [ ] Idle throttle: no input/disk activity for N minutes → vsync on
  until next input (invisible energy win).
- [ ] Skip present when the emulated framebuffer is unchanged (GPU idle
  win at Workbench).

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
