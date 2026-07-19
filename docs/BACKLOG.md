# iPadUAE — Feature Backlog

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

## Killer features (medium)

- [ ] **Save-state UI** — slots with screen thumbnails (`SaveStates/`
  exists); pin the config per slot — states are fragile across config
  changes.
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
- [ ] **iCloud-synced setups** — configs (optionally HDFs) shared between
  iPads.
- [ ] **App Intents/Shortcuts** — "Boot <config>" from Spotlight/widgets.

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
