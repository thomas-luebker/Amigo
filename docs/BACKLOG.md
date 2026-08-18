# Amigo — Feature Backlog

Planning home: the Obsidian vault (see ../CLAUDE.md) —
`20 - Private/Retro Computing/Projects/Amigo.md` for Status + Next Actions, and
`Amigo/Roadmap & Open Questions.md` for the long form. Kept in sync manually;
this file is the repo-visible mirror.

## 0.7.2 — in progress (opened 2026-08-18)

Release container exists on both sides: `app/project.yml` is bumped to
MARKETING_VERSION 0.7.2 / CURRENT_PROJECT_VERSION 20260818, and App Store
Connect version 0.7.2 is created in PREPARE_FOR_SUBMISSION
(id 69da2f0e-ad82-4e28-b9d8-cd297a3edb20) with de-DE fully populated.
See APPSTORE.md for what went into de-DE and why it could not be done on
0.7.1.

### Blocking — before submission

- [ ] **Push the 0.7.2 What's New to ASC.** Drafted for both locales and
  dry-run clean (en-US 824 → 1982 chars, de-DE → ~2800, both under the
  4000 limit). The script prepends rather than replaces and is
  idempotent. Not yet written — an outward-facing store edit awaiting an
  explicit go-ahead. Script: `whatsnew.py --write`.

That is the only thing left.

### Done in 0.7.2

- [x] **Per-side shift keys — FIXED and hardware-verified 2026-08-18.**
  Merged from `fix/shift-keys` (branch can be deleted). Tested on the
  iPad Pro M4 with a physical keyboard, all four press/release orderings,
  `hw=1` throughout (GameController answering with real per-side state):

  | case | trace |
  |---|---|
  | L alone | `L1 R0 → L0 R0` |
  | R alone | `L0 R1 → L0 R0` |
  | L held, R tapped | `L1 R0 → L1 R1 → L1 R0` — left survives |
  | both, L released first | `L1 R1 → L0 R1 → L0 R0` — right survives |

  Rows 3 and 4 are the reported bug (holding one flipper while tapping
  the other). No phantom release, sides fully independent. Diagnostic
  `write_log` removed and the patch regenerated — only hunk offsets and
  the blob hash moved. **Closes the last r/amiga launch-thread item.**

  Worth knowing: the branch was correct all along and sat blocked for a
  month on a five-minute test. The `GCKeyboard` approach, the no-hardware
  fallback and the stuck-shift reconcile were all right as written.

- [x] **Menu restructure.** The main menu had reached 36 rows (four added
  by this release) and only worked because `ViewThatFits` drops it into a
  ScrollView. Display and Input & Overlays are now submenus; the main
  menu is 20 rows, 24 with DF2/DF3 enabled. Warp deliberately stayed at
  the top level — it is a mid-load control and burying it defeats it.

- [x] **Subtitle decided: "Classic Amiga Emulator."** ASC already held it;
  APPSTORE.md's "Classic Amiga computing" was the outlier and is gone.
  The German subtitle stays "Klassisches Amiga-Erlebnis" on purpose — a
  literal translation would repeat "Amiga Emulator" from the app name.

- [x] **de-DE screenshots.** Confirmed through the API: de-DE has zero
  screenshot sets, en-US has both required ones (APP_IPHONE_67,
  APP_IPAD_PRO_3GEN_129). Zero sets on a secondary locale is exactly the
  condition for Apple's fallback to the primary locale. The API cannot
  render the fallback, so the only remaining confirmation is visual in
  the ASC UI — or the submission itself.

### Regressions introduced and fixed on 2026-08-18

Both found by running on the device, both the same root mistake: code
whose job was to *read* the machine config wrote an inferred value back.

- [x] **DF1 silently disabled.** The shipped `default.uae` carries no
  `floppyNtype` lines, and in WinUAE absent means *default* — DF0 **and**
  DF1 — not disabled. `configuredFloppyDrives` parsed the text, read
  absent as `-1`, returned 1, and a `didSet` wrote `floppy1type=-1` back.
  Now reads `currprefs.floppyslots` through `ipaduae_floppy_drives()` and
  the `didSet` is gone. *Devices already carrying `floppy1type=-1` need
  one manual "+ DF1" to heal — a reinstall does not undo it.*
- [x] **RTG stopped activating.** The CRT toggle drove
  `gfx_filter_bilinear` across all three `gf[]` slots — including
  `GF_RTG` — on every launch. The card mapped fine ("Card 05: UAE RTG",
  16M Z3) but the guest stayed at `RTG=0/0`. Scanlines now touch only
  scanline fields. *Not bisected against the DF1 fix, so which of the two
  cured it is unconfirmed; the `gf[]` write is by far the likelier cause.*

### Candidates — undecided

- [ ] **Pro Controller in Project X.** DotMatrixHead reported the pad not
  working in that game specifically. Still uninvestigated, and not
  diagnosable without the game: the routing code
  (`joystick_apply_controller_prefs` in `od-unix/input.cpp`) is generic
  and has no game-specific path, so a fault would be in how Project X
  reads the port, not in which port we assign. Triage when someone has
  the game: try port 0 vs 1, CD32 mode off, autofire off, and confirm the
  same pad works in another game on the same machine config.

### Explicitly not in 0.7.2 unless decided otherwise

- Vision Pro "Designed for iPad" — verify on the visionOS sim first (see
  below). A broken compat-mode experience earns 1-star reviews that are
  hard to undo.

### iCloud — in 0.7.2 after all

The blocker recorded on `feature/icloud-sync` ("team profile lacks the
iCloud capability/container, needs a one-time Xcode GUI Run") **no longer
applies**: a Release build for `generic/platform=iOS` with
`-allowProvisioningUpdates` resolves a profile that already carries
`iCloud.de.amiga-imager.uae`, and `codesign -d --entitlements` confirms
the container plus CloudDocuments in the signed app. No GUI step needed.

Landed on main, superseding that branch (which was stale — it still
carried the pre-rename `iPadUAE-Info.plist` / `iPadUAE.entitlements` and
was configs-only). `feature/icloud-sync` can be deleted.

Scope: `Configuration/*.uae` and `SaveStates/*.uss` always; disk images,
hard drives and ROMs opt-in and **off by default** — HDFs run to hundreds
of megabytes and would quietly fill a free iCloud tier. Any file the
running config mentions is skipped in both directions, so a mounted image
is never raced against mid-write. All access goes through
`NSFileCoordinator`. The container is user-visible in Files as "Amigo".

- [x] **Verified on the iPad Pro M4 (2026-08-18).** Container resolves at
  `/private/var/mobile/Library/Mobile Documents/iCloud~de~amiga-imager~uae`,
  the first pass pushes, later passes report "Up to date" — idempotent.
  Note the first-ever `url(forUbiquityContainerIdentifier:)` call takes
  ~25 s, so an early log check reads as a failure when it is not.
- [ ] **Still to check: the second device.** A setup saved on the iPad
  appearing on the Mac, and a save state round-tripping. Also worth
  watching the first sync with media enabled on a large HardDrives
  folder.
- [ ] **Mount exclusion is safe but awkward.** The most valuable thing to
  sync is usually the Workbench HDF that is currently mounted — exactly
  the file that is skipped. "Unmount to sync" is a workaround, not an
  answer. Doing better means quiescing the emulator and flushing before
  the copy. Scope it separately if media sync is to be more than
  "CDs, ROMs and unmounted disks".

## Quick wins — all done 2026-08-18

- [x] **Warp button** — `ipaduae_set_warp` through the core's own
  `warpmode()`; a floating button beside the gear, plus a menu row.
- [x] **Drag & drop from Files** — drop onto the picture; a single floppy
  goes straight into DF0. The interaction sits on SDL's view, since
  `PassthroughWindow` rejects touches outside its own controls.
- [x] **Floppy haptics** — polls `gui_ledstate` at 30 Hz rather than
  adding a cross-thread callback out of `gui_led()`. iPhone only; iPads
  have no Taptic Engine, so the row is hidden there.
- [x] **DF2/DF3** — drive count in the Machine panel, applied through
  `changed_prefs` with no restart; extra rows appear only when the
  machine has the drives.
- [x] **CRT shader** — landed as scanlines rather than a shader: the SDL
  renderer already composites a scanline overlay from `currprefs.gf[]`
  every frame, so four strength steps over those prefs get the look with
  no shader pipeline and no restart.
- [x] **Keyboard layout polish** — rows totalled 13 to 15.3 key-units, so
  the shared unit was set by the widest row and short rows ended ragged.
  Every row now totals 15.0, and the unit is solved per row so differing
  gap counts still end flush.
- [x] **In-app import** — `UIDocumentPickerViewController` from the
  overlay window. Needed a `modalActive` escape hatch in
  `PassthroughWindow.hitTest`, or the picker would have been visible and
  completely untouchable.

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
- [x] **Both shift keys read as left shift** (DotMatrixHead) — "makes
  playing pinball impossible". **FIXED and hardware-verified 2026-08-18**,
  merged; see the 0.7.2 section above. This was the last open item from
  the thread — every reported issue now has an answer.
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
