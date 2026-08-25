# Amigo — Feature Backlog

> Evidence and reasoning behind the 2026-08-19/21 investigations —
> upstream bugs, the hang diagnosis, the diagnostic tooling, the layout
> diagnostics, and the mistakes worth not repeating — are in
> [`FINDINGS-2026-08-19.md`](FINDINGS-2026-08-19.md). This file stays the
> working list.

Planning home: the Obsidian vault (see ../CLAUDE.md) —
`20 - Private/Retro Computing/Projects/Amigo.md` for Status + Next Actions, and
`Amigo/Roadmap & Open Questions.md` for the long form. Kept in sync manually;
this file is the repo-visible mirror.

## 0.7.2 — SHIPPED (live 2026-08-19; confirmed READY_FOR_SALE 2026-08-21)

Released with de-DE fully populated — see APPSTORE.md for what went into
de-DE and why it could not be done on 0.7.1. Everything below under
"Done in 0.7.2" is live to users.

### Blocking — before submission (all cleared)

- [x] **Push the 0.7.2 What's New to ASC.** Done 2026-08-19, both
  locales. Promotional text now reads "New in 0.7.2" / "Neu in 0.7.2" —
  verified against ASC 2026-08-21, so the old "still says 0.7.1" note is
  no longer true.

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
  menu is 20 rows, 24 with DF2/DF3 enabled. (Warp was placed at the top
  level as a mid-load control, then removed entirely later the same day
  once measured — see "Quick wins" below.)

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

### Bugs found on device 2026-08-18 (not yet fixed)

- [ ] **Clicks stop reaching the guest after pairing a controller.** The
  cursor keeps moving; nothing is clickable, from *any* source — mouse,
  trackpad, Pencil, touch. Cleared by restarting the app; not persisted
  in the config.

  Instrumented `unix_input_mouse_button` on the device and captured the
  healthy state for comparison:

      iPadUAE click: btn=0 down tablet=1 mh_alive=52 \
        jport0=(id 200 mode 0) jport1=(id -1 mode 0) mouseactive=1

  `JSEM_MICE` is 200 (`include/inputdevice.h:355`), so port 0 is bound to
  mouse device 0 — correct — and clicks work. Note `tablet=1`: **1:1
  Mouse / mousehack is NOT the cause**, which was the leading theory
  until this trace killed it.

  **The controller hypothesis is DISPROVEN.** The console stayed attached
  across a re-pair and logged 176 clicks in both states:

      28 clicks   jport0=(id 200 mode 0)  jport1=(id -1  mode 0)   no pad
     148 clicks   jport0=(id 200 mode 0)  jport1=(id 100 mode 7)   pad on

  `JSEM_JOYS` = 100 and `JSEM_MODE_JOYSTICK_CD32` = 7, so that is the pad
  correctly on port 1 in CD32 mode — and **port 0 stayed bound to the
  mouse throughout, with 148 clicks delivered while the pad was
  attached**. `joystick_apply_controller_prefs` does *not* displace the
  mouse. Do not spend time there.

  So the trigger is still unknown. What is now excluded, each by
  measurement rather than argument: mousehack/1:1 Mouse (clicks work with
  `tablet=1`), the controller and its port routing (above), a missing
  `UIApplicationSupportsIndirectInputEvents` (present in the plist), and
  the Pencil hover recognizer driving the absolute path (it is
  `allowedTouchTypes = [.pencil]`, so a mouse cannot reach it).

  Still open as suspects: the `UIDropInteraction` added to SDL's root
  view for drag & drop (no mechanism, but it is on the view that handles
  input), and a stuck button state — if a button-down is delivered and
  its matching up is swallowed, the guest sees the button held forever
  and every later click is a no-op. The latter fits "cleared by a
  restart" better than anything else and has precedent in this codebase
  (the FINGER_CANCELED stuck-touch class).

  Next time it happens, catch it live: the diagnostic is a single
  `write_log` in `unix_input_mouse_button` (see this entry's trace
  format). If `btn=0 down` appears with no matching `up`, that is the
  answer.

- [x] **Display stays stale after a WHDLoad title exits back to RTG —
  DOES NOT REPRODUCE (2026-08-19).** Retested with Turrican 2 AGA on the
  current build: exits cleanly and repaints. Most likely never an RTG
  re-init fault at all but warp's `gfx_framerate = 10` frame skip — see
  the warp entry. Reopen if it recurs, and check whether warp is involved
  before looking at the RTG path.

  *Original report:*
  Reported from the amimcp session: launched Turrican 2 AGA (native AGA,
  kills the OS) in the guest; after F10 the iPad's picture stayed frozen
  while the guest was demonstrably fine — clean 1280x720 screen grabs,
  CPU 0%, clock ticking, windows opening. So the emulator is running and
  Amigo is not repainting. Look at the RTG re-init path on the native-AGA
  → RTG transition.

### Candidates — undecided

- [x] **Pro Controller in Project X — CLOSED 2026-08-19, the report was
  stale.** u/Working_Ladder_51 reported it while **0.6.5** was the only
  downloadable build, and Bluetooth controller support did not arrive
  until 0.7.0. Thomas's own correction in that thread says so explicitly:
  "Bluetooth controller support is new in 0.7.0, which is still in App
  Store review, so it's not in the version you can download today
  (0.6.5)." So the pad was not working in *anything* at that point —
  Project X is simply what he happened to test it in.

  Nothing was ever game-specific, and three later confirmations back that
  up: a PS4 pad in Pang (u/NeilDeWheel), a BT pad in CD32 layout in the
  Turrican 2 AGA Remake, and the routing code having no game-specific
  path at all. Reopen only if someone reports it on 0.7.1 or later.



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

## Apple Pencil pressure — `feature/pencil-pressure` (started 2026-08-24)

From Chad Essley (artist on *Jake and Peppy*, Apollo V4), by email: the
Pencil works in TVPaint but the pointer is offset unless 1:1 is on, and
then clicking misbehaves — and the dream is pressure-sensitive painting
on a tablet Amiga.

**What the port was actually missing.** WinUAE has carried the guest-side
half of this for years and the Unix port never wired it up:

- `tabletlibrary.cpp` — the boot ROM offers the guest a **`tablet.library`**
  serving position, proximity, buttons and `TABLETA_Pressure`. It was
  Windows-only (`WITH_TABLETLIBRARY` defined solely in
  `od-win32/sysconfig.h:108`) and not in `WINUAE_CORE_SOURCES` at all.
- `filesys.asm:2932` — the mousehack driver can also post
  `IESUBCLASS_NEWTABLET` input events carrying pressure, gated on
  `input_tablet == TABLET_REAL` and on `is_tablet()`, which od-unix stubs
  to `0` (`od-unix/input.cpp:1533`).
- Both are fed by `inputdevice_tablet()` / `tabletlib_tablet()`, whose
  only caller in the tree is `od-win32/dinput.cpp:694`.

**Why tablet.library and not the input events:** upstream's own changelog
says *"Deluxe Paint requires it for pressure support"* (line 13527).
That settles which interface DPaint opens.

**Done on the branch:**

- [x] `WINUAE_UNIX_WITH_TABLETLIBRARY` (default ON) compiles
  `tabletlibrary.cpp` into the iOS core.
- [x] `ipaduae_pen_tablet()` in `core-ios/ios_glue.cpp` feeds it; hover
  supplies proximity + position at zero pressure, the touch layer
  supplies tip pressure (`pen_feed_from_finger` / `pen_end_stroke` in
  `od-unix/video_sdl.cpp`).
- [x] **Pressure scaling.** `tabletlibrary.cpp` encodes pressure as
  `pressure << 15` into the signed 32-bit tag, so full scale is `0xFFFF`
  — we feed 0..65535. The Windows path passes raw device units instead
  (a Wacom reports 0..1023), which lands at **1.5% of full scale**. That
  is the most likely reason for upstream's note at changelog line 8154:
  *"dpaint5 does not seem to do anything with pressure data. It reads
  pressure tag contents but nothing seems to happen."* Untested claim —
  it is the first thing to check on device.
- [x] `tablet_library=true` written into the config (seeded for existing
  setups in `ipaduae_heal_config_paths`), *Pencil Pressure* toggle in
  the gear menu. Installed by the boot ROM at reset, so unlike 1:1 Mouse
  it needs a restart.

**Serial Wacom tablet — done on the same branch (2026-08-24).**

TVPaint does not open `tablet.library` and never will: its tablet support
is built into the application and talks to a serial tablet directly, from
the menu it shows on a right-click at launch. The people who actually ran
it did so with Wacom UD/UltraPad units — an A4000 with a **UD-0806** and
an A1200 with an **UltraPad A5** are both on record in the TVPaint forum
thread, which turns out to be Chad's own from 2019. Those are Protocol IV
tablets. So the answer for TVPaint is not a driver: it is to *be* the
tablet.

`core-ios/wacom_serial.cpp` is a Wacom Protocol IV device on the emulated
serial port, selected with `serial_port=WACOM_TABLET` (parsed at
`od-unix/config.cpp:407`, which sets `sername` and `use_serial` together).
It is a device, not a byte generator — it answers `~#`, `~C` and `~R`,
honours `ST`/`SP`/`PH`, and only then streams 7-byte packets.

Hooks in `od-unix/serial.cpp`, all guarded to iOS, following the shape
upstream already established for `LOOPBACK_SERIAL`:

| hook | what it does |
|---|---|
| `serial_open()` | recognises the device name |
| `serial_read_byte()` / `readseravail()` | receive from the tablet |
| `writeser()` | guest bytes become tablet commands |
| `serial_readstatus()` | reports DSR/CAR/CTS, as loopback does |
| `serial_hsynchandler()` | one scanline of baud-rate credit |

**Pacing matters more than it looks.** `checkreceive_serial()` runs per
scanline (~15.6 kHz), so an unmetered buffer would deliver a whole packet
between two scanlines and overrun a driver expecting 9600 baud. Credit
accrues from the baud the guest programmed into SERPER, spent one byte at
a time, with a 32-byte burst bucket.

**Tested without an Amiga.** `scripts/test-wacom-serial.sh` compiles the
device against stub headers, drives the full Protocol IV handshake and
decodes its own packets back — 31 checks covering framing, coordinate and
pressure round-trip, proximity, buttons, `ST`/`SP` gating and baud pacing
at 9600 and 19200. All pass. It also pinned the burst bucket: the measured
overshoot is exactly 32 bytes.

Unverified and marked as such in the source: the exact `~#`/`~R` reply
text, and the Y origin corner (Wacom digitizers historically count Y up
from the bottom; `WACOM_Y_DOWN` is the one line to flip if TVPaint draws
mirrored).

**Bonus:** with a serial Wacom present, the real Amiga drivers —
PenPartner, Tableau Pro, FormAldiHyd, AccuPoint — work inside Amigo too
and feed the genuine `tablet.library`, rather than the boot ROM's
stand-in.

**End-to-end test in the Simulator — the tablet reaches AmigaOS (2026-08-25).**

`scripts/test-tablet-simulator.sh` boots a bootable 8 MB test disk
(`scripts/build-guest-tests.sh`) whose Startup-Sequence runs a 68k probe,
`core-ios/tests/guest/sertest.c`, with `AMIGO_TABLET_SELFTEST=1` so the
tablet moves its own pen. No Pencil, no device, no human.

**Result: the Amiga sees the tablet.** The probe read the model string and
the coordinate range off the wire, and in one run decoded a live packet
stream — `x= 6689 y= 3112 pressure= 81 prox=1 tip=1` climbing smoothly
with monotonic pressure (`build/tests/tablet-test7.png`). That is a real
AmigaOS program reading a Wacom Protocol IV tablet through Amigo's
emulated serial port.

**Four real bugs, none of them in the protocol.** Every one was invisible
to the Mac-side unit test and would have been invisible to reasoning:

1. **`serial_port=` is not a config key — `unix.serial_port=` is.** Target
   options only reach `target_parse_option()` when they carry the
   `TARGET_NAME.` prefix (`cfgfile.cpp:3543`), and TARGET_NAME is "unix".
   Written without it the core logs "unknown config entry" and the port
   silently stays closed. `ConfigStore.setSerialTablet` was wrong and is
   fixed.
2. **The TBE interrupt was never raised.** `SERDATR` reports TBE and TSRE,
   but AmigaOS's serial.device is interrupt-driven: it hands a byte to
   SERDAT and waits for `INTB_TBE`. Nothing in the port ever raised it, so
   **every `CMD_WRITE` from the guest blocked forever in DoIO**. The old
   UAE `serial.cpp` at the repo root does `intreq |= 1` right there; the
   Unix port lost it. Fixed in `od-unix/serial.cpp` — this affects any
   Amiga program that writes to the serial port, not just the tablet.
3. **Every transmitted byte was doubled.** SERDAT emitted a `0xa8|bit`
   prefix whenever SERDAT bit 8 was set, to convey a ninth data bit — but
   AmigaOS sets that bit as the *stop bit* on ordinary 8N1 writes, so the
   host saw `a9` before every byte. The guest's commands arrived as
   `"\xa9S\xa9T\xa9"`. Now gated on 9-bit mode (SERPER bit 15).
4. **The RDB boot flag is not the default.** `rdb-build --part "DH0:DOS3"`
   produces a partition that mounts, reads and never boots — `Flags:
   00000000`, insert-disk screen. It is the fourth field: `DH0:DOS3::1`.
   Worth carrying into the `amiga-disk` skill.

Also learned, and worth keeping: **`serial.device` is not in the Kickstart
ROM.** A bare boot disk has nine devices and serial is not among them —
it lives in `DEVS:`. `build-guest-tests.sh` borrows one from a system
image rather than committing Amiga OS files here.

> **Xcode will not relink when only `libuaecore.a` changed.** The static
> library is not in its dependency graph, so `xcodebuild` reports BUILD
> SUCCEEDED and installs a stale binary — which cost an hour of chasing a
> bug that was already fixed. Touch a Swift source, or delete DerivedData,
> whenever the core changes. Verify with
> `strings Amigo.app/Amigo.debug.dylib | grep "virtual Wacom"` (debug
> builds put the code in `Amigo.debug.dylib`, not the 37 KB launcher).

**Both halves proven on AmigaOS (2026-08-25).** `TabTest`
(`core-ios/tests/guest/tabtest.c`) opens `tablet.library`, calls
`AllocTablet`/`DoTablet` and reads the tag list; `SerTest` drives the
serial Wacom. One run shows both:

    [11] x= 2107/ 4095 y= 2048/ 4095 pressure= 2084831232 ( 97%)
    TabTest: pressure reached the Amiga side
    [ 150] x= 5863 y= 3810 pressure=216 prox=1 tip=1

- **tablet.library carries pressure at 97% of full scale.** That is the
  scaling fix confirmed from the Amiga side: raw device units, as the
  Windows path feeds, would arrive at ~1.5% — indistinguishable from
  "barely touching", and the likeliest reason for upstream's note that
  dpaint5 "does not seem to do anything with pressure data".
- **Sustained serial streaming works** — 150+ packets, coordinates
  tracking, pressure climbing. The earlier stall was the probe's own
  serial IO: one IORequest shared between a queued read and writes,
  byte-at-a-time reads, and `io_RBufLen` left at 0. A driver does none of
  those. Nothing in the device changed.
- The self-test sweep now feeds `ipaduae_pen_tablet()` rather than the
  serial device directly, so one sample fans out to both consumers
  exactly as a Pencil sample does — which is why both pressure curves
  move together above.

**Open — needs the device:**

- [ ] **Does SDL report Pencil pressure at all on iOS?** The feed keys
  off `event.tfinger.pressure` being strictly between 0 and 1
  (`touch_pressure_is_pen`). If iOS flattens finger and Pencil to the
  same value, the fallback is a UIKit-side `UITouch.force` feed from a
  passive recognizer in `PencilSupport.swift`. The existing `iPadUAE
  finger:` diag lines already print pressure — one Pencil session with a
  log answers this. New `iPadUAE pen: stroke start` line marks detection.
- [ ] Test in DPaint (pressure-capable per upstream) and confirm whether
  the `<< 15` scaling reads as full range on the Amiga side.
- [ ] **Which tablet TVPaint's launch menu actually lists.** Protocol IV
  is the educated bet from what people ran, but UD tablets also speak the
  older Wacom II-S, and a 1995 program may target that — or the menu may
  offer SummaSketch/Kurta instead. One photo of that right-click menu
  from Chad settles it; the II-S variant would be a second packet format
  in the same device, not a rewrite.
- [ ] Chad's other report — Pencil clicks misbehaving in 1:1 mode — is a
  separate bug: `FINGER_DOWN` palm-rejects the whole touch when
  `unix_input_pen_hover_active` is set, and nothing guarantees the hover
  recognizer reaches `.ended` before SDL delivers the tip's touch.

## 0.7.5 — on TestFlight (build 20260824, 2026-08-21)

- [x] **RTG silently dies at 32 MB — option removed and existing configs
  repaired (2026-08-21).** Setting *Machine → RTG Graphics Card* to
  **32 MB** kills RTG completely. The emulator builds the board fine —
  `Card 5: Z3 0x48000000 32M IO RTG RAM` — but Picasso96 then refuses it
  and the guest reports:

      P96: Could not create graphics board context for 'Uaegfx'

  At 16 MB it returns immediately: `uaegfx.card 3.4 init`, `RTG host mode
  list: 12 modes`, `RTG=1/1`. Single-variable result — `gfxcard_size` was
  the **only** line differing from `.last-good.uae`.

  **Why it was a nasty trap:** the machine still boots, so
  `recoverFromCrashedChange()` never fires. The user just loses their
  screen with no message and no obvious way back, and this has been
  shipping since the picker existed.

  Fix: 32 MB removed from the picker, and `rtgMB` clamped to
  `maxRTGMegabytes = 16` **on read as well as write**, so a config
  already sitting at 32 is repaired on next launch instead of obeyed.

  Root cause inside P96 not chased — the size flows through
  `PSSO_BoardInfo_MemorySize` and this port's own uaegfx.card in
  `od-unix/rtg.cpp`. Only worth revisiting if someone needs >16 MB.

  > **Diagnosed with amiagent against the iPad's *emulated* Amiga** —
  > `ipad-4.local:7846`, token `a4000`. The host log showed only an
  > *absence* of uaegfx lines; the guest gave the exact error string in
  > two minutes. Reach for it first for anything guest-side.

- [x] **Multiple HDFs as separate volumes — the 4★ review (2026-08-21).**
  WlkAme's US review is the whole of that rating and its entire body was
  *"Still missing multi-hdd support, to mount several HDF images as diff
  volumes."*

  `ConfigStore` had a hard single-drive assumption: `set("hardfile2", …)`
  **deletes every line with that key**, so a second mount could only ever
  replace the first. Now `append` / `allValues` / `removeWhere` let the
  key repeat, `mountedHardfiles` **parses the config** rather than
  remembering state (so it is right for hand-edited and imported
  configs), each drive gets its own `uae<n>` controller unit, and mounting
  takes the **lowest free** DH number so ejecting DH1 of three refills
  the hole instead of leaving a permanent gap.

  **Verified on the M4 iPad:** two drives mount as DH0/uae0 + DH1/uae1
  with independent hardfile threads; ejecting one leaves the other
  running; after an eject the next mount refills the freed unit rather
  than incrementing. Guest-side, AmigaOS `info` shows the second HDF as
  its own device:

      AmigoTest   98M   Read/Write  AmigoTest     <- second HDF file
      DH0       2047M   Read/Write  Workbench     ] both partitions of
      DH1       5579M   Read/Write  Work          ] the first 8 GB image

  > **Trap that nearly produced a false pass:** the 8 GB system image is
  > an RDB with **two** partitions, `Workbench` and `Work`, so a guest
  > volume list reading `RAM Disk, Work, Workbench` looks like multi-drive
  > success while proving nothing — it is identical with one HDF mounted.
  > The first purpose-built test image was also named `Work`, collided
  > with that partition, and was silently dropped by AmigaOS despite
  > mounting correctly at the emulator level (`Mounting uaehf.device 1`,
  > `Partition 'Work'`). **Give test images a name that cannot collide**
  > — `AmigoTest` is what finally gave an unambiguous result.

  > **Bug found on device, not in review:** `/var` is a symlink to
  > `/private/var`, and the two spellings arrive from different places —
  > config lines (and `healPaths` output) are `/var/…`, while `URL.path`
  > from the file enumerator is `/private/var/…`. The duplicate check
  > compared raw strings, so the *same* image mounted twice. WinUAE's own
  > `directory/hardfile '…' already added` caught it. Both compare and
  > write now go through `canonicalPath()`.

  **Test tooling:** `AmigaDiskCLI` (from `~/Development/AmigaDiskKit`)
  builds what was missing — `disk rdb-build <img> <bytes> --part
  Name:DOS3:::0` then `disk rdb-format <img> <part> <vol>` gives a real
  empty FFS volume, so two drives are visibly different instead of two
  copies of one 8 GB image. Note the size is in **bytes** and partitions
  are addressed by **name**, not index.

- [x] **Fixed the 0.7.1 field crash: stack overflow in the LHA decoder
  (2026-08-21).** All five App Store crash reports on 0.7.1 were one
  signature — `__stack_chk_fail` in `lha_make_table`, reached by
  inserting a `.lha` as a floppy (i.e. any WHDLoad archive). Upstream's
  own validity check was inert because `lha.h` has `#define error
  write_log`, so it logged and fell through into the overflow.

  Three archive-reachable overflows bounded: `count[bitlen[i]]` with a
  17-entry stack array and bit lengths up to 19; `n = getbits(9)` up to
  511 into `c_len[510]`; and run lengths of `getbits(9) + 20` = 531 with
  no bound at all. Plus the Huffman tree walk and a cycle guard.

  **Verified on device 2026-08-21**, not only host-side: inserting
  `diskarc-bad.lha` (a real ADF packed -lh5-, corrupted so it SIGBUSes the
  unpatched decoder) as a floppy made the guard fire **136 times**,
  AmigaOS reported "Not a DOS disk", and the app stayed alive — confirmed
  by amiagent still answering, which requires the emulator running.

  Note the earlier test archives could never have shown this: WinUAE only
  decompresses an archive member it decides to use as a disk image, so an
  `.lha` with no ADF inside (e.g. `Picasso96.lha`) is rejected at the
  header stage and never reaches the Huffman decoder. Build test archives
  with `AmigaDiskCLI lha create <out.lha> <dir>` (packs -lh5-).

  **Also verified against the real decoder**: 150
  fuzzed variants of a real Aminet archive crash upstream **139 times**
  (SIGSEGV/SIGBUS/SIGABRT) and the fixed decoder **zero** times, while
  decoded output for the valid archive is byte-identical
  (`fnv=8392c356fac831b1`, 118 members). Detail in `FINDINGS-2026-08-19.md` §4b.

  **Decided: we fix it ourselves — not filed upstream.**

> **Build numbers have outrun the calendar.** ASC already held `20260823`
> on 2026-08-20, so `scripts/build-release.sh`'s default (`date +%Y%m%d`)
> now produces a number *lower* than the last upload and ASC rejects it.
> Pass an explicit number — `./scripts/build-release.sh 20260824` — until
> the calendar catches up. The script's own comment predicted this.
>
> **Uploading is a manual Organizer step on this Mac.** There is no iOS
> Distribution certificate in the keychain (only *Developer ID
> Application*, which is Mac-outside-the-App-Store), so `xcodebuild
> -exportArchive` fails with `No signing certificate "iOS Distribution"
> found`. Organizer works because it cloud-signs via Xcode's Apple ID
> session, which the CLI cannot see (`error: No Accounts`). The ASC API
> key `4AA2Q26Z9Q` fails differently — `Cloud signing permission error`,
> because it is App Manager and cloud signing needs **Admin**. Flow:
> `build-release.sh <number>` here, then Distribute from Organizer.

- [x] **Keyboard bottom-inset race fixed (2026-08-21).** `Overlay.swift`
  reports the on-screen keyboard's height to the core by scheduling
  `ipaduae_set_bottom_inset(frac)` from a `GeometryReader` via
  `DispatchQueue.main.async`. On hide, `onDisappear` set the inset to 0 —
  and then the *already-queued* block ran and restored the stale value,
  so the picture stayed laid out above a keyboard that was no longer
  there until the next lucky toggle. The queued block now bails unless
  the keyboard is still shown.

  **This was found while chasing a different bug and is not its cause** —
  see below. It only bites with `keyboardOverlayStyle = false`; with the
  default (overlay) style `frac` is pinned to 0 and the inset is never
  set at all.

- [x] **"Too much black on iPhone" — investigated, not a bug
  (2026-08-21).** Reported as over-cropping. Nothing crops: **a 4:3 Amiga
  screen cannot fill a 19.5:9 phone in portrait.** Measured on an iPhone
  17, portrait picture area 1206 x 2333:

  | source | uniform scale | drawn | height used | black |
  |---|---|---|---|---|
  | Amiga 756x576 | x1.595 | 1206x919 | 39% | **61%** |
  | RTG 1280x720 | x0.942 | 1206x678 | 29% | **71%** |

  Landscape is healthy: RTG scales x1.59 to 2035x1145, fills the height,
  ~107 px bars each side. So both modes are bad in portrait — **Fit**
  keeps proportions and leaves 61-71% black, **Stretch** removes the
  black but draws 2.5x too tall. **Decided: leave it centred, accept the
  black.**

  A uniform-scale-and-crop **"Fill" mode was built, measured on device,
  judged far too aggressive, and reverted. Do not re-add it** — in
  portrait it would crop ~60% of the *width*.

  The safe area is dearer than expected and was deliberately left alone:
  **186 px off the top in portrait, 186 px off _each side_ in landscape**
  for the Dynamic Island — 372 of 2622 gone before anything is drawn.
  "Display: Fullscreen" reclaims it.


- [x] **CDs work beyond the CD32 (2026-08-20).** The menu said "CD-ROM
  (CD32)…" and the behaviour matched: `cdimage0` fills a CD slot, but the
  guest only sees it with a CD controller (`cdconmodes`: uae, ide, scsi,
  cdtv, cd32). CD32 and CDTV have one built in; an A1200 or A4000 has
  none, so mounting a CD there did nothing. `mountCD` now sets
  `scsi=true` on non-CD32 machines. Row renamed to "CD-ROM & CD32
  Console…".

  **Boundary:** mounting the CD as a *volume* needs a CD filesystem on
  the Amiga side — `CDFileSystem` plus a `DEVS:DOSDrivers/CD0` mountlist.
  That belongs to the disk image, not to Amigo. **See [[Amiga Imager]]**:
  shipping CD0 in the built images would make CDs work out of the box on
  non-CD32 machines. Not an Amigo bug; do not "fix" it here.



- [x] **Quick controls, bottom-left (2026-08-20).** One tap toggles the
  Amiga keyboard; a long press expands to numpad, function keys and
  virtual joystick. Mirrors the gear: the gear is for setup, this is for
  what you flip mid-session. Showing the keyboard previously took three
  taps through the menu.

  Placement dodges the two things that share that corner — the keyboard's
  bottom strip and the joystick D-pad — by lifting clear of whichever is
  showing, using the keyboard's measured height (already computed for the
  core's bottom-inset report, now also kept in OverlayState). Draws above
  the input overlays; a keyboard covering its own toggle would be absurd.

## Decided against

- [x] **MMU off by default for 040/060 — DECIDED AGAINST 2026-08-23.**
  `docs/PERFORMANCE-2026-08-23.md` measured MMU emulation at **2.23x**
  interpreter throughput (corroborated independently on FS-UAE at 2.08x)
  and recommended defaulting it off. The measurement is accepted; the
  recommendation is not. Real 040/060 have an MMU, SysInfo reports
  `IN USE`, and Enforcer/MuForce and MMU-programming software need it.
  A user who loses speed can see the toggle; a user whose debugger
  silently does nothing cannot see why. **`MachinePanel.swift:49` and the
  `mmu: true` in the `turbo`/`rtgStation` presets all stay.**

  Still to fix: the comment at `MachinePanel.swift:47` claims MMU is
  "both faster and more authentic ... (measured)". The authenticity half
  is right; the speed half is backwards by 2.23x, and the "(measured)"
  is what let it survive — the same failure shape as
  `FINDINGS-2026-08-19.md` §4.1/§4.6. Fix the comment, keep the code.

  Replacement direction: **make the MMU path cheaper** rather than avoid
  it — `docs/PERFORMANCE-2026-08-23.md` §7.


- **Automatic rating prompt.** Built and removed 2026-08-19 at the user's
  call. The numbers argued for it — 445 installs, 5 ratings, a 5.00
  average nobody browsing can see — but Amigo is free, no ads, no IAP and
  GPL, and an r/amiga audience is precisely the crowd that resents being
  nagged. A prompt that costs goodwill to buy ranking is a bad trade for
  this app. Don't re-add it without a decision, not just a metric.

  If the rating count ever needs addressing, the acceptable shape is
  *passive*: a "Rate Amigo" row in About & Licenses that the user taps
  because they want to, never something that appears on its own.

## 0.7.3 — on main, unreleased

- [x] **Clipboard: copy & paste between iOS and the Amiga (2026-08-19).**
  Both directions verified on the iPad Pro M4.

  Most of it already existed: WinUAE's clipboard machinery is complete and
  was already compiled in (Amiga side via the filesys uae-boot handler,
  `od-unix/clipboard.cpp` for IFF FTXT/ILBM, `clipboard_vsync` per frame,
  `WINUAE_UNIX_WITH_IMAGEIO` on). It was gated behind
  `currprefs.clipboard_sharing`, default false.

  **iOS-shaped design.** Reading `UIPasteboard` without user intent raises
  the system "Amigo pasted from <app>" banner, so on iOS the 2-second host
  poll is compiled out, as is the pasteboard read `amiga_clipboard_init`
  did on every Amiga boot. **No C++ reads the pasteboard at all.** iOS →
  Amiga comes in through a SwiftUI `PasteButton` (iOS 16+, we target 17)
  where the tap *is* the consent. Amiga → iOS is automatic, because
  *writing* raises no banner.

  Two paste routes, because `clipboard.device` alone disappoints: the
  Amiga clipboard (Workbench programs that read it), and **type as
  keystrokes**, which works in the Shell, editors and games — all the
  software that never implemented `clipboard.device`, which is most of it.

  ### Three upstream bugs found in `od-unix/clipboard.cpp`

  None of these are ours — they are upstream, in the vendored unix port.
  We are **not proactively filing them** with Toni; the fixes live in
  `patches/0001-ios-port-fixes.patch` and that series is the record.

  **This is not disengagement, and an earlier version of this note said
  so wrongly.** Toni is actively engaged: he replied personally on
  2026-08-18 about the `handle_rga_out` NULL check and mousehack mode 4,
  gave his current address (twilen@winuae.net — the ar.cpp one is
  ancient), and asked a direct question we owe an answer to. The
  distinction is: don't send him every small port-side finding; do finish
  the exchange already under way.

  1. **`clipboard_vsync` gated on `initialized`** — `od-win32` does not.
     The Amiga process blocks on `SIGBREAK_CTRL_D` at `cfloop2` *before*
     it can call mode 15, and mode 15 is the only thing that sets
     `initialized`. The host waited for an init that could only happen
     after a signal it refused to send. Symptom: "clipboard task init" in
     the log, never "clipboard initialized". Amiga → host dead forever.
  2. **The `CBD_CHANGEHOOK` never fires on this port.** Established on
     hardware via the amimcp session reading the guest: clip provably in
     `clipboard.device` unit 0 (read back through ConClip, twice,
     different nonces), `UAE clipboard sharing` alive at pri -10
     throughout, two distinct clip IDs behaving identically (so not
     `cliphook`'s `.same` branch). `filesys.asm` never tests the result of
     the `CBD_CHANGEHOOK` `DoIO`, so a failed install is silent and looks
     exactly like this. **Fix: leave `signaling` set in
     `amiga_clipboard_init`**, so `clipboard_vsync_cb` pokes the task once
     a second and drives `clipread` without the hook.
  3. **`clipboard_put_text` had no dedupe** — latent on desktop because
     nothing there polls. With the poll, `got_data` arrives every second
     and every poll rewrote the host clipboard: on iOS that stomps
     anything the user copies in another app, within a second, forever.
     It would have passed a quick test and ruined the clipboard in daily
     use. Now compares against `last_host_clipboard` first.

  Also fixed on the way: `write_host_clipboard_text` fell back to
  `/usr/bin/pbcopy` via `popen`, which cannot exist on iOS, so the
  direction had nowhere to go even once the handshake worked. Now writes
  `UIPasteboard` directly from `UAEBridge.mm`.

- [ ] **Why does the `CBD_CHANGEHOOK` not install?** The proper fix.
  Polling re-reads the entire clip every second — negligible for text,
  wasteful for a large one. Needs the boot ROM instrumented, which means
  rebuilding `filesys.asm`.

- [ ] **The in-app clipboard toggle has never been tested.** Sharing was
  only ever enabled by pushing `default.uae` to the device with
  `devicectl`. "Gear → Clipboard → Amiga Clipboard Sharing" is the path a
  real user takes and it is unverified — and it is exactly what silently
  reverted before the rollback fix below.

- [x] **Config changes silently reverted after a force-quit.**
  `markBootStable()` ran once per app *launch*, 30s after the overlay
  installed. A machine change restarts the emulator, not the app, so the
  risky-change marker stayed armed for the rest of the session; force-quit
  (swipe up — no chance to run `ipaduae_fast_exit`) and the next launch
  restored `.last-good.uae`. **Affected every machine setting**, not just
  clipboard, and cost most of one investigation.
  `snapshotBeforeRiskyChange` now arms its own 30s timer.

## Quick wins — done 2026-08-18 (warp built, measured, dropped)

- [~] **Warp button — BUILT, REMOVED 2026-08-18. The "slower" reading was
  probably wrong; see below.** Wired to the core's own `warpmode()`. On
  device it appeared to make the machine significantly slower, so it was
  removed rather than shipped.

  **Revised 2026-08-19.** `warpmode()` sets `gfx_framerate = 10` whenever
  turbo is on — the display draws **one frame in ten**. At roughly 5 fps
  the picture looks frozen and the machine feels sluggish while emulation
  is in fact running *uncapped* underneath. That fits the observation
  exactly, and it very likely also explains the separate "display stays
  stale after a WHDLoad title exits" report, which came from the same
  afternoon while warp was being tested and has NOT reproduced since warp
  was removed (Turrican 2 AGA, verified 2026-08-19).

  So warp was probably working and only *looked* broken. If it is ever
  revisited, the fix is to stop the frame skip applying — leave
  `gfx_framerate` at 1 and let the uncapped emulation show — rather than
  to abandon the feature. Not proven: nobody confirmed warp was actually
  on during the WHDLoad test.

  The backlog entry said "WinUAE warp mode exists, just expose it". That
  was wrong, and is the reason this got treated as a quick win.

  Leading theory, unconfirmed: with `sound_output=exact` (our default)
  WinUAE paces emulation from the audio buffer. `warpmode()` calls
  `pause_sound()`, and `finish_sound_buffer()` discards the buffer under
  turbo — so warp removes the clock the emulation was pacing against and
  pacing falls back to `compute_vsynctime()`. `gfx_framerate=10` (frame
  skip) may also not be honoured by the unix present path. Nothing in
  `od-unix/` reads `turbo_emulation` except that one line in `sound.cpp`.

  To retry properly: instrument emulated FPS on device, toggle warp, and
  find what actually paces the loop with vsync off and sound discarded.
  Real value is **floppy-based games**, where load time is wall-clock
  bound no matter how fast the CPU is — an HDF-booting 68060 does not
  need it, which is why this went unnoticed until someone timed it.
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

## Boot hang — FIXED 2026-08-20

`hardfile.cpp` `start_thread()` ignored `uae_start_thread`'s failure
return and then spun forever on the emulation thread waiting for a thread
that was never created. Return is checked now, the wait is bounded, and
`pthread_create`'s errno is logged. Detail in
`docs/FINDINGS-2026-08-19.md` §2.

Still open: **why** `pthread_create` fails. Thread exhaustion across
repeated resets is the suspect. The next occurrence logs the errno.

## (superseded) Boot hang — diagnosed, parked

**Paused deliberately.** Severity is low: only ever reached by a
deliberate stress sequence, no user reports, nothing from testers,
nothing on the live release. It does not bother anyone.

Diagnosed as a **host-side deadlock** between the emulation thread and
the hardfile thread, reached through an rtarea trap — not a chipset
problem. Full evidence, the ruled-out hypotheses and the reproduction
recipe are in **`docs/FINDINGS-2026-08-19.md` §2**.

Everything needed to resume is in place: file logging, the hang watchdog,
and `test/autostress` which reproduces it in about five minutes without a
human. Pick it up if it ever affects a real user.

## (superseded) Boot hang after screen switch + reset (2026-08-19)

Distinct from the RGA NULL crash, and **the RGA guard did not fire**, so
Toni's dummy-pointer variant held at those two sites. This is something
else.

Reproduced by the user: several screen switches, then a reset. The app
stays **alive** (process present) but the emulation stops dead and the
display freezes. Full log saved at
`~/Desktop/amigo/amigo-hang-20260819.log` (684 lines).

The log ends exactly here:

    Unix RTG host mode list: 12 modes
    Unix uaegfx.card 3.4 init @4000E1AC (2688 bytes modes)
    Unix RTG P96 RESINFO: 4000E250-4000ECD0 (2688 bytes)
    PAL mode V=49.7614Hz ... RTG=0/0
    PAL mode V=49.9204Hz ... RTG=0/0
    hardfile thread starting, unit 0
    <nothing further>

A healthy boot continues past that point with:

    hardfile thread starting, unit 0
    Tablet driver running (...)
    clipboard task init: ...
    Creating UAE bsdsocket.library 4.1

So the guest never reaches its own startup. It hangs after both RDB
partitions mount and uaegfx initialises, right as the host-side hardfile
thread starts — which makes a deadlock between that thread and the
emulation thread the obvious first suspect, though nothing has been
proven.

**Controlled 2026-08-19: the hang is NOT caused by Toni's dummy pointers.**
Three builds, same stress sequence (screen switches, then reset), all with
file logging:

| build | result |
|---|---|
| dummies + NULL guard | hang at `hardfile thread starting, unit 0` |
| dummies, guard REMOVED | same hang, **no crash**, process alive |
| `NULL` restored + guard (control) | same hang, identical signature |

The middle row is the useful one for upstream: with the guard removed a
genuine NULL dereference would have segfaulted, and it did not. So the
dummy pointers hold. The bottom row rules out the obvious confound — the
hang reproduces without them.

Also: the RGA guard did not fire once in any run today, so the original
crash was never reproduced and we still owe Toni no `reg`/`type` bits.

- [x] **Blocked or spinning — ANSWERED 2026-08-20: fully blocked.**
  A watchdog on its own thread (the main thread wedges with the emulation,
  so nothing scheduled there can report) dumps state when the beam stops:

      hangdiag[stall]:    pc=00f04004 stopped=0 intena=602c intreq=1040
                          bplcon0=0200 ERSY=0 genlock=0 beamcon0=0020 vpos=19 hpos=1
      hangdiag[stall+1s]: (byte-identical)

  `pc`, `vpos` and `hpos` are unchanged across a full second, so **the
  emulation thread is not executing at all** — not a guest-side poll,
  which would still advance the beam.

  This rules out three of Toni's four candidates: not STOP-with-interrupts
  -masked (`stopped=0`, and `intena` matches a healthy machine — note a
  healthy idle boot reads `stopped=1`, so that one would have misled us
  without the baseline), not ERSY (`ERSY=0`), not a CPU poll. BEAMCON0 had
  been written (`0020` vs `0000` healthy) but is not implicated.

  **PC is in the rtarea and the host thread is stopped, always right after
  `hardfile thread starting, unit 0`.** That reads as a host-side deadlock
  between the emulation thread and the hardfile thread, reached through a
  trap — not a chipset-timing bug, and so probably not upstream's.

- [x] **Reproduces automatically now** (`test/autostress`, DO NOT MERGE):
  injects left-Amiga+M screen switches and a reset on a timer, so the
  sequence runs without a human. Caught the hang within ~5 minutes.
  *Gotcha:* Swift `NSLog` does NOT reach the file log — only the core's
  `write_log` does — so the stress driver's own lines are invisible there.
  The second boot sequence in the log is the proof it ran.
- [ ] Try it with the HDF unmounted, to confirm the hardfile thread is
  involved at all.
- [ ] Try with RTG off — the hang follows uaegfx init, and every
  reproduction so far has involved screen switching.

Only found because the log is now written to a file. Three earlier
attempts at this produced nothing because `devicectl --console` had gone
silent while appearing connected.

## Upstream: the RGA thread with Toni Wilen — ANSWERED 2026-08-21

**Closed from our side.** Toni replied 2026-08-18 on two patches; Thomas
answered the same day and committed to shipping a build that logs the RGA
reg/type when the NULL slot fires and sending him the type bits. **Those
bits do not exist, and he has now been told so** — reply sent 2026-08-21
to `twilen@winuae.net`.

- [x] **Capture the RGA NULL-slot type bits and send them — CANNOT, and
  said so.** The logging shipped: `custom.cpp` `handle_rga_out()`, guarded
  by a `null_ref_logged` static so it fires once per session:

      RGA refresh/strobe slot with NULL pointer skipped (reg=%04x type=%08x)

  **It never fired.** Two days, many 68040+RTG boots, RTG screen switches
  (left-Amiga+M, opening and closing RTG screens), a native-AGA round trip
  in and out of Turrican 2 — with Toni's dummy pointers in place, with them
  reverted, and finally with the check removed entirely so a NULL would
  segfault outright rather than be skipped. So the crash predates the check
  and is rarer than we implied when we promised the data.

  The reply also thanked him for reversing the dummy pointers, and said
  why that mattered more here than upstream: our test machine is a 68040
  with `cycle_exact=false`, the one configuration where the bitplane DMA
  pointer conflict could never show, and the build was on its way to
  TestFlight.

  **The two standing offers were deliberately NOT renewed** — testing
  `clear_rga()`/`check_rga_out()` variants, and redoing the mousehack
  patch as an opt-in prefs flag. Both were offered on 08-18 and may still
  be live in his head; we chose to let them lapse rather than re-commit,
  on the grounds that Amigo is spare-time and there is no capacity for a
  back-and-forth. **Do not re-offer either without deciding the time is
  actually there.** If he takes one up, that is a decision to make then,
  not a promise already made.

  The unsent-hypothesis material — `bitplane_rga_ptmod()` sitting under
  `if (!custom_disabled)` in `do_cck()` while `handle_rga_out()` does not,
  `custom_disabled` following `ad->picasso_on`, and the exact-equality
  `r->type ==` tests — went in the long draft but was cut from what was
  sent. It stays in `docs/FINDINGS-2026-08-19.md` §1.4 in case the log
  ever does fire and the thread reopens.

  Our own guard stays local: the difference between a skipped refresh and
  a crashed app on someone's iPad. We are not asking upstream to carry it.

## From English Amiga Board (2026-08-19)

> Original post, kept verbatim because paraphrasing has already cost us
> once: *"Haven't found any particular bugs except 1:1 touch doesn't seem
> to work on iPhone (but I need more testing to be sure) and the fact that
> it's not saving to .last-good unless I overwrite the config myself. The
> LEDs also look weird in portrait mode - they look better in landscape
> mode but they seem stretched and blurry. IIRC the same happened on my
> iPad. Any plans of introducing an automatic Warp mode similar to
> vAmigaWeb? That's very handy on a smartphone."*

- [x] **"Not saving to .last-good unless I overwrite the config myself" —
  ALREADY FIXED, shipped in 0.7.2 (in review 2026-08-19).** This is the
  config-revert bug seen from outside. `markBootStable()` ran once per app
  *launch*, 30s after the overlay installed; a machine change restarts the
  emulator, not the app, so any change made later in a session stayed
  armed and a force-quit made the next launch restore `.last-good.uae`.
  From the user's seat: settings silently do not stick, and overwriting
  the config by hand is the only thing that survives.
  `snapshotBeforeRiskyChange` now arms its own 30s timer.

  **Tell him it is fixed and in the release currently in review** — he
  reported a real bug precisely and deserves to know it landed before he
  wrote in.



- [x] **LED bar blur — FIXED 2026-08-19, needs a look on device.** The bar
  was drawn once at 1x (`TD_TOTAL_HEIGHT` = 11 px tall) and magnified to
  `statusbar_display_height() * pixel_scale_y` with linear filtering — 4x
  on a 2x screen, 6x on a 3x phone. It is now supersampled: a per-frame
  `s_status_scale` (1..4) sizes the source buffer to
  `frame->width * scale` by `TD_TOTAL_HEIGHT * scale`, chosen in
  `make_video_layout()` from the height the bar is actually presented at.
  Magnification drops from 4-6x to about 1.0-1.5x vertically and to a
  *downscale* horizontally.

  Two things worth knowing about the implementation:
  - `statusline_set_multiplier()` **ignores its width/height arguments**
    and reads `currprefs.leds_on_screen_multiplier` instead. That pref is
    persisted as `show_leds_size`, so it is saved and restored around the
    call — a device-derived value must never reach a config file. Same
    read-path-must-not-write rule as the DF1 and RTG regressions.
  - Sizing the buffer to the *presented* width (the obvious first move,
    and what this was written as before the arithmetic was checked)
    **overflows**: `draw_status_line_single()` places the row at
    `totalwidth - (padx + VISIBLE_LEDS * td_width) * scale`, and with
    `VISIBLE_LEDS` = 13 at `td_width` = 30 that is -397 in portrait at
    scale 4. Scaling both axes by the same factor keeps `x_start`
    positive by construction.

- [ ] **LED bar stretch — NOT fixed, and it is a design decision, not a
  bug.** Supersampling scales both axes equally, so the on-screen *shape*
  is unchanged: the LEDs are as non-square as they were, just sharp now.
  The anisotropy is structural — vertical magnification comes from
  `pixel_scale_y`, horizontal from `safe_w / frame->width`, so they only
  agree by accident. Measured ratio: ~1.7:1 landscape, ~3.7:1 portrait.

  Square LEDs in portrait need `status_height = 11 * safe_w / 720`, i.e.
  about 18 px where the bar is currently 66 — a bar 3.7x shorter. Going
  the other way and widening the row does not fit either: 13 LEDs need
  `394 * scale` px and portrait only has room for about half that. So on
  a narrow screen there is genuinely no room for 13 square LEDs at this
  bar height, which is presumably why upstream stretches. Real options,
  all of them product calls: a shorter bar in portrait, fewer LEDs
  (hide disabled drives), or leave it.

- [ ] **"1:1 Mouse: On" lies on Kickstart 1.3.** mousehack needs KS 2.0+;
  below that `video_sdl.cpp` falls back to relative drag-hold, silently,
  while the menu row still claims 1:1. `mh_alive` is already known to the
  core. Reported from EAB as "1:1 touch doesn't seem to work on iPhone" —
  note that iPhone has neither trackpad nor Pencil, so finger-only 1:1 is
  a poor fit there regardless.

- [x] **Warp / automatic warp — DECLINED 2026-08-19.** EAB asked for
  vAmigaWeb-style automatic warp. Warp was built, measured and removed,
  and the decision is not to revisit it.

  Note for whoever answers EAB: the "it appeared slower" reading was
  almost certainly wrong — `warpmode()` sets `gfx_framerate = 10`, so the
  display draws one frame in ten while emulation runs uncapped. That is
  a fixable presentation problem, not a broken feature. So this is a
  product decision, not a technical dead end, and it declines a request
  someone made explicitly. Worth saying plainly to them rather than
  implying it does not work.

  Also worth knowing when replying: warp's real value *is* the ADF case
  they are asking about — floppy loading is wall-clock bound no matter
  how fast the CPU is, which is exactly why an HDF-booting setup sees no
  benefit from it.

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
- [x] **Pro Controller not working in Project X** — CLOSED 2026-08-19 as
  stale; the report predates Bluetooth controller support (0.7.0), see
  the Project X entry above. Attributed to DotMatrixHead here but it was
  u/Working_Ladder_51 who reported it.


- [ ] **Vision Pro "Designed for iPad"** — ASC availability checkbox, no
  build change. Verify on visionOS sim first: overlay UIWindow composites,
  right-click reachable (recommend Bluetooth mouse in help). Native
  target: 1-2 weeks, only if compat mode shows demand.

Done: controller-routing-lost-on-restart fix, LHA/LZX/7z pickers,
Controls & Help panel, tap-then-drag + hold-to-drag + KS1.3 1:1
fallback (all 0.7.1 candidates). iPhone: shipped with 0.7.0.

## From App Store reviews (2026-08-15 → 08-19)

Three written reviews so far, 11 ratings across DE/GB/US/SE. Two of the
three carry feature requests.

- [x] **PS4/PS5 joypad** (Smurfy2000, 5★ GB, 08-15) — "would really
  appreciate PS5 joypad support". Done. The later 08-19 review reports a
  PS4 pad working with no setup at all, so the original report was most
  likely a pairing problem rather than missing support.
- [ ] **Multiple HDFs mounted as separate volumes** (WlkAme, 4★ US,
  08-19) — "still missing multi-hdd support, to mount several HDF images
  as diff volumes". The whole review; it is the only 4★ to date and the
  reason the US average sits at 4.00. Being added.
- [ ] **Virtual joystick polish + auto-fire** (Smurfy2000, 5★ GB, 08-15)
  — "some enhancement to the virtual joystick would perhaps improve use
  ability (UI enhancements and auto fire support)". Nothing else in this
  file covers auto-fire.

Not a request, but worth keeping: NeilDeWheel's 5★ (GB, 08-19) is a
working recipe someone found without help — rename the AGS 3 AGA `.img`
to `.hdf` into `amigo/HardDrive`, Kickstart 3.1 into `amigo/Kickstart`,
select both, boot. "It took me longer to copy the files than it did to
get AGS running." That path is worth protecting in any Hard Drive UI
change, and it reads like the quick-start the help panel wants.

## Apple Vision Pro — "Designed for iPad" only (assessed 2026-08-22)

Decided: **compatibility mode, not a native visionOS port.**

> **TESTED AND WORKING — visionOS 26.5 simulator, 2026-08-22.** The app
> launches, the emulator runs and animates (AROS boots to "Waiting for
> bootable media", LED counters ticking), and **the whole SwiftUI overlay
> renders correctly over the SDL window** — gear, QuickDisplay, quick
> controls, disk button, first-run hint and LED bar all present and
> correctly placed. That was the main risk: the overlay lives in a
> separate `PassthroughWindow` at `.alert` level, exactly the arrangement
> compatibility mode can get wrong. It does not.
>
> Presented geometry is an iPad Pro 11" window with essentially no safe-area
> loss: `out=2388x1668 safe=0,0 2388x1628 status=44 frame_area=1584`.
> No errors in the log.
>
> Reproduce: `xcodebuild -downloadPlatform visionOS` (7.31 GB), then
> `xcrun simctl create "Vision Pro Test" …SimDeviceType.Apple-Vision-Pro-4K
> …SimRuntime.xrOS-26-5` — note the **4K** device type; the plain
> `Apple-Vision-Pro` type reports "Incompatible device". Build with
> `-destination 'platform=visionOS Simulator,name=Vision Pro Test'`; it
> produces a `Debug-iphonesimulator` binary, which is correct — compatibility
> mode runs the iOS build.
>
> **Still unverified: input.** The simulator drives look-and-pinch from a
> mouse, which is not eye tracking, and no Vision Pro hardware is paired.

**The app is already eligible, with zero code changes.** The four things
that normally disqualify an iPad app all check out:

| check | result |
|---|---|
| `UIRequiredDeviceCapabilities` | none declared |
| `UIRequiresFullScreen` | `false` |
| CoreHaptics | guarded by `capabilitiesForHardware().supportsHaptics`, no-ops cleanly |
| Device family / orientations | `1,2`, all four |

**Already enabled** (confirmed in App Store Connect 2026-08-22) — Apple
makes compatible iPad apps available on Vision Pro by default, opt-*out*
rather than opt-in. So Vision Pro support has effectively been shipping
since launch; what was missing was any evidence it worked, which the
simulator test now supplies.

**No installs yet:** the sales data buckets are iPad 467 / iPhone 176 /
Desktop 45 (688 total through 2026-08-21) with no Vision entry — and Mac
appears separately as "Desktop", so Vision Pro would too if anyone had
installed it.

> **Do not use `supportedDevices` from the iTunes lookup to check platform
> availability.** It reports **0 Mac** devices for an app that is
> demonstrably on Mac with 45 installs, so it does not enumerate
> compatibility platforms at all. The App Store Connect UI is the only
> reliable source; `appAvailabilityV2` in the API covers territories only.

> **Test before announcing.** visionOS synthesises touch from
> look-and-pinch, and Amigo deliberately bypasses SDL's touch-to-mouse
> synthesis (`SDL_TOUCH_MOUSE_EVENTS=0`) for a custom trackpad-style
> finger path in `video_sdl.cpp`. That is the most likely thing to feel
> wrong. The virtual joystick and Pencil paths do not translate either.
> Hardware keyboard + game controller on a large virtual screen use
> native paths and should be the recommended way to play.

**A native visionOS target is explicitly not planned.** SDL3 supports
visionOS, but `vendor/SDL3/SDL3.xcframework` currently ships only
`ios-arm64` and `ios-arm64_x86_64-simulator` slices, so it would need
rebuilding — and the whole input model (eye + pinch, no hover pointer,
no Pencil) would have to be reworked.

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

  > **Why it oscillates — the arithmetic, measured 2026-08-22.**
  > `custom.cpp` `vsync_handler_render()` computes
  > `mv = 12 - cpu_idle / 15` and only arms the sleep when
  > `mv >= 1 && mv <= 11`. At the shipped `cpu_idle = 0`, `mv` is 12 —
  > outside the band — so `reset_cpu_idle()` runs on **every frame** and
  > the host never sleeps at all. Inside the band the scale is inverted
  > and narrow: `cpu_idle=15` gives a 0% stopped-lines threshold (sleeps
  > almost always), `cpu_idle=150` gives 90% (sleeps almost never).
  > Tuning this means picking a point on a 10-step scale where the two
  > ends are "always" and "never" — hence the oscillation. Confirmed on
  > device: both the iPad config and the Mac "Designed for iPad"
  > container run `cpu_speed=max` with no `cpu_idle` line, so neither
  > ever idles the host while the guest sits in STOP.
  > `docs/FINDINGS-2026-08-19.md` §7.
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

- [x] **Baseline measured against real hardware (2026-08-22).** One
  `-m68000` binary, cross-compiled with amiga-gcc and self-timed with
  `DateStamp`, run on the iPad guest and on the A4000/060 over amiagent.
  Amigo is **4.9x** a real 68060 on integer code, **13.2x** on Fast RAM
  memcpy, and **103x** on Chip RAM — Chip and Fast are *identical* under
  emulation (no chipset contention), so chip-bound software gains far
  more than the CPU figure suggests. Storage is not a bottleneck: the
  hardfile matches the RAM disk at ~34 MB/s. Full method, source and the
  two false findings it produced first: `docs/FINDINGS-2026-08-19.md` §7.
- [ ] Emulation on its own thread (structural lever if benchmarks demand).
- [ ] Root-cause the >8-bit RTG accelerated-blit bug (bisect the 8 ops),
  fix properly, offer upstream.
- [~] **Offer the whole patch set upstream — not pursuing proactively.**
  Not because Toni is uninvolved (he is not: see the RGA thread below),
  but because he does not need a firehose of port-side findings. The
  patch series is the record and he knows the repo. Original note: (iOS
  guards, RTG reset
  handler, mousehack mode-4 fix, toggle_rtg robustness).
- [ ] Try `gfxcard_multithread`.
- [ ] **Cheapen the MMU path (opened 2026-08-23).** MMU stays on by
  default, so the 2.23x is now a cost to attack rather than avoid. Code
  reading (`docs/PERFORMANCE-2026-08-23.md` §7) says most of it is not
  translation at all: `newcpu.cpp:1936` sets `m68k_pc_indirect = 1`
  whenever `mmu_model` is set, which drops the core off the "generic+
  direct" fast path (mode 0) that Amigo's other settings would otherwise
  qualify for — so every opcode fetch becomes a bank dispatch. Two
  levers, in order:
  1. [x] **Measured 2026-08-23.** Counters enabled in a throwaway build,
     then reverted.
  2. [x] **Widening the instruction page cache — DROPPED.** Measured miss
     rate is **0.04–0.29%**; it does not thrash. The reasoning was wrong:
     the cache holds a *page* and instruction fetch is sequential within
     one. Would have been a no-op change.
  3. [~] **Host base pointer — PROTOTYPED, +7% to +20.5%.** Branch
     `perf/mmu-hostptr` (`8779c39`), carried as
     `patches/0002-mmu-host-pointer-cache.patch`. Recovers ~a fifth of the
     MMU penalty on instruction-dense work (1.84x → ~1.53x). Reads only.
     **Not shippable yet:** a bank remap moving `baseaddr` without an ATC
     flush leaves a stale pointer — resolve before merging. Writes are the
     obvious next gain (`set` gained least, +7.1%).

  Full numbers and method: `docs/PERFORMANCE-2026-08-23.md` §8.
