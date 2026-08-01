# Switching the core: WinUAE → Copperline?

Evaluation dated 2026-07-31. Subject:
[CopperlineHQ/Copperline](https://github.com/CopperlineHQ/Copperline) — an
Amiga emulator written in Rust.

**Recommendation: do not switch yet. Run a timeboxed spike with a hard
go/no-go gate on performance, because the one thing that would kill the
switch is unmeasured and cheap to measure.**

---

## 1. What Copperline is

Facts, gathered from the repo at `main` (shallow clone, 2026-07-31):

| | |
| --- | --- |
| Language | Rust (225k LOC excl. vendored), vendored pure-Rust `m68k` core (MIT) |
| License | **GPL-3.0-or-later** (we are GPL-2) |
| Age | First commit 2026-06-14. **Six weeks old**, at v0.13.0. 91 stars. |
| Development | Author states it was AI-driven, guided by hardware docs and test disks measured against real hardware |
| Coverage | OCS/ECS/AGA, independent Agnus/Denise revs, A500→A4000, CDTV, CD32, 68000–68060 + FPU + 030/040 MMU |
| Peripherals | Paula audio, floppy (ADF/ADZ/DMS/SCP), Gayle + A4000 IDE, A2091/A4091/A3000 SCSI, RDB HDFs, A2065 Ethernet w/ NAT, host dirs as AmigaDOS volumes, MIDI, parallel printer/sampler |
| Frontend | winit + pixels (wgpu), cpal audio, gilrs gamepads — **all behind an optional `frontend` feature** |
| Also ships | A WebAssembly build with a canvas/WebAudio frontend, live at copperline.dev/try |
| Accuracy | Cycle-driven on one colour-clock timeline; 68000 counts validated against TomHarte SingleStepTests; chip-bus timing cross-checked against real hardware via `timing-test/` |
| Open issues | Three. One of them is **#19 "RTG support", still open**, last touched 2026-07-30 |

This is not a toy. The timing model, the test discipline, and the docs are
better than most emulators twice its age. But it is six weeks old.

## 2. Why it is genuinely attractive

**a. The patch burden goes to zero.** We carry
`patches/0001-ios-port-fixes.patch` — 1,249 lines against upstream WinUAE,
which we rebase and regenerate by hand. Copperline needs **no core patches
at all**, because it already has the seam we would need:

```
crates/copperline-web/src/lib.rs   # 892 lines
  copperline = { path = "../..", default-features = false }
  # "The headless core only: no winit/pixels/cpal/wasmtime."
```

That file is a complete embedding frontend, and it is almost exactly the
API an iOS app wants:

```
run(now_ms, max_frames)      present_ptr() / present_rows() / present_width()
take_audio() -> Vec<f32>     key_event(code, pressed)
mouse_delta(dx, dy)          mouse_button(button, pressed)
set_joystick_port(...)       insert_floppy(drive, bytes, name) / eject_floppy(drive)
save_state() / load_state()  reset()  power_led() / fdd_led() / hdd_led()
set_overscan(mode)           set_volume_percent(...)  emulated_seconds()
```

An `copperline-ios` crate would be a near-copy of it with
`#[no_mangle] extern "C"` in place of `#[wasm_bindgen]`. The wasm32 build
already proves the core compiles and runs with no OS services, no SDL, no
filesystem — which is most of the risk of any new platform target.

**b. SDL3 goes away entirely.** We would drop the vendored SDL3
xcframework *and* `patches/sdl3-0001-scene-connect-single-main.patch` (the
AirPlay multi-`SDL_main` crash). Video becomes a Metal layer we own; audio
becomes an `AVAudioSourceNode` we own.

**c. 80% of our C++ patch becomes Swift.** Of ~790 added lines in the
WinUAE patch, **644 are in `od-unix/video_sdl.cpp`** — our touch handling,
palm rejection, Pencil hover, absolute-mouse mapping, TV-out window. That
logic is host-input plumbing living in a C++ file only because SDL owns the
event loop. On Copperline it moves to Swift, where it belongs and where we
can actually debug it.

**d. Memory safety.** Our two field crashes were a NULL deref in
`handle_rga_out` and a stale-pointer divergence in the RTG reset path.
Those failure classes largely do not exist in safe Rust. Given we ship to
TestFlight testers and the App Store, that is worth real money.

**e. Things we would gain for free.** Deterministic save states and input
recording; host directories mounted live as AmigaDOS volumes (a Files-app
folder appearing as an Amiga volume is a *great* iPad feature we do not
have); a JSON-RPC control protocol; CD32/CDTV.

**f. License is not the blocker it looks like.** GPL-3 is stricter than
our GPL-2, but [RetroArch is GPLv3 and has been on the iOS App Store since
May 2024](https://toucharcade.com/2024/05/15/retroarch-download-iphone-ipad-apple-tv-support-achievements-list-consoles/).
The precedent we already rely on covers GPL-3 too. Note it changes nothing
about the commercial question — the door stays shut either way, which we
already decided (2026-07-19) we are fine with.

## 3. What we would lose — ranked by how likely it is to kill the project

### R1 — Performance for *our* config is unmeasured, and the escape hatch does not exist

This is the gate. Everything else is negotiable.

Our 10× performance win (68060 SysInfo 16,674 → 164,513 Dhrystones, ~2.8×
faster than FS-UAE on M1) came from **turning cycle-exactness off**:
`cycle_exact=false`, `cpu_compatible=false`, direct memory access, no
prefetch, plus `fpu_no_unimplemented`. That is how a no-JIT interpreter
runs an AmigaOS 3.2 desktop at a pleasant speed.

Copperline has no such mode. `[emulation] speed` is *deprecated and
ignored* — the core is cycle-driven by design, and `CONTRIBUTING.md`'s
"hardware-first rule" means it is unlikely to grow a deliberately
inaccurate fast path. Warp mode exists, but that is uncapped throughput,
not reduced accuracy.

The published numbers are encouraging **for A500-class work**: the browser
(wasm!) build runs the default AROS machine at 6.4× realtime and a
Copper/blitter-heavy OCS demo at 2.7×, "roughly 1.3–1.5× slower than
native" — so native is ~9× and ~4× realtime on the author's Mac. An
A500/A1200 on an M4 iPad would have enormous headroom.

But nobody has published a 68060 + RTG + 256 MB Zorro III AmigaOS 3.2
figure, which is what we actually ship and what our users run. Cycle-driven
68060 emulation is a completely different cost class from cycle-driven
68000. **This must be measured before anything else is built.**

### R2 — Absolute pointer: our entire touch and Pencil UX has no equivalent

`src/pointer.rs` is not a mousehack. It is a **servo**: it injects relative
quadrature deltas, watches where Intuition draws sprite 0 on the next
frame, learns the pixels-per-count gain, and corrects — converging over
"a handful" of frames, up to a 60-frame budget, with a 2-pixel tolerance.
It is designed for an AI agent saying "click that gadget", and it is
explicit that a guest drawing its pointer into a bitplane (i.e. most games)
is "unobservable" and it will not move at all.

Our product is a tablet. Finger-down-is-the-pointer, Pencil hover moves the
pointer, palm rejection — all of it rests on WinUAE's mousehack
(`input_tablet` / `inputdevice_mh_abs` / the boot-ROM guest task), which
gives exact absolute positioning in one frame, for any guest. We fixed an
upstream bug in exactly that path (2026-07-19) to make it survive resets.

A closed-loop servo with ~100 ms convergence would feel like dragging the
pointer through syrup, and would fail outright in games. **We would have to
build mousehack for Copperline.** It is feasible — they already have
guest-side trap infrastructure (`amigaos.rs`, `filesys.rs`, `dirfs.rs`
serving host directories) — and it is upstreamable and genuinely useful to
them. But it is real work on the critical path, and it is the difference
between a tablet emulator and a desktop emulator running on a tablet.

### R3 — RTG is immature relative to what we ship today

We ship a working uaegfx Zorro III Picasso96 setup: 1280×720+, host-
accelerated blits, hardware sprite, and users running full RTG Workbench.

Copperline's RTG is a **Z3660** board — meaning the guest needs the
third-party open-source `Z3660.card` P96 driver, not the stock uaegfx our
users' existing HDF installs are configured for. `src/z3660.rs` says the
core blitter ops work but "**Still stubbed: the ACC_OP surface ops and
exotic minterms**", and upstream issue **#19 "RTG support" is still open**.

Practical consequence: every existing user hard drive would need its
graphics driver reinstalled and screenmodes redefined. That is a migration,
not an upgrade.

### R4 — Networking changes shape

We ship WinUAE `bsdsocket.library` emulation: the guest gets TCP with no
stack installed. Copperline offers an A2065 Ethernet card with NAT — which
is *more* honest hardware, but requires the guest to run Roadshow/AmiTCP
with a SANA-II driver bound to the A2065. Better in principle, worse for a
user who just wants a browser to work.

### R5 — Six weeks old, one maintainer, moving fast

v0.13.0 in six weeks means the API we build against will move under us. We
have just fought our way through App Review; rebasing onto a core this
young restarts the stability clock with real users on TestFlight. Also
worth weighing honestly: the author states development was AI-driven. The
test discipline (TomHarte, real-hardware timing disk, regression set)
is the reason to take it seriously anyway — but breadth of compatibility
with 30 years of Amiga software is earned over years, and WinUAE has them.

### R6 — WHDLoad and long-tail compatibility are unquantified

Our users run WHDLoad. Nothing in Copperline's docs claims WHDLoad
coverage. This needs a compatibility pass, not an assumption.

### R7 — Build-system surface

Rust in the Xcode build: `cargo build --target aarch64-apple-ios` (plus
`aarch64-apple-ios-sim`) producing a staticlib, driven from a run-script
phase — the same shape as our existing CMake core phase, so this is
familiar rather than novel. Features to disable for iOS: `frontend`
(winit/pixels/cpal/gilrs/rfd/arboard), `wasm-boards` (wasmtime/Cranelift
will not cross-compile usefully and is a JIT we cannot ship anyway),
`floppybridge` (compiles C++, wants a serial port), `midi` optional.
The wasm32 build already exercises exactly this "core only" configuration.

### R8 — JIT: neutral

No JIT either way. iOS forbids it, we are interpreter-only today, and
Copperline is interpreter-only everywhere. Nothing changes.

## 4. What survives from our app

Most of it. Of ~1,950 lines of Swift/ObjC++:

| Survives as-is | Needs rework |
| --- | --- |
| `Overlay.swift` (633) — window, menu, panels | `ConfigStore.swift` (359) — `.uae` → `.toml`, path healing keeps its shape |
| `VirtualInput.swift` (259) — keyboard/joystick | `UAEBridge.mm` / `UAEMain.mm` → Swift over the Rust C ABI |
| `PencilSupport.swift` (107) | `MachinePanel.swift` (140) — retarget to Copperline's config keys |
| `StatePanel.swift` (90), `ConfigurationsPanel.swift` (128) | `AboutPanel.swift` (98) — GPL-3 text, new attribution |
| Touch/palm-rejection *logic* (moves from C++ to Swift) | **New:** Metal present layer, CoreAudio sink, TV-out second layer (all currently SDL's job) |

The screenshots, listing copy, privacy policy, About screen structure, and
the whole App Store apparatus carry over unchanged.

## 5. The reframe worth stating plainly

The honest question is not "WinUAE or Copperline" — it is "what hurts today
that a core swap fixes?"

| Current pain | Does switching fix it? |
| --- | --- |
| App Store review friction (2.5.8 rejection) | **No.** Entirely core-independent. |
| Perf without JIT | **Probably makes it worse.** No inaccurate-fast mode. |
| Maintaining 1,249 lines of patch | **Yes, decisively.** Goes to zero. |
| Field crashes (SIGSEGV in C++) | **Yes.** Safe Rust removes the class. |
| Wanting a commercial product | **No.** GPL-3 is if anything stricter. |

So the switch is justified on **maintainability and safety**, not on
capability. That is a real argument, but it is not urgent — and it is worth
much less if R1 or R2 fails.

## 6. Proposed plan — spike, with gates

Timeboxed. Stop at the first failed gate; each phase is useful on its own.

**Phase 0 — measure before building (½ day)**
1. Install a Rust toolchain; `cargo build --release` upstream on this Mac.
2. Run `src/bin/bench.rs` headless: AROS/A500 baseline, then A1200/AGA,
   then a 68030 and a 68060 config with Zorro III fast RAM.
3. Record realtime factors. This Mac is Apple Silicon, so single-core it is
   a fair proxy for an M4 iPad.

> **GATE 1.** If a 68060 + fast-RAM config cannot hold ≥1.0× realtime with
> margin on the desktop, it will not hold it on an iPad under thermal
> limits, and our daily-driver config is dead. **Stop here** — the answer is
> "no switch", and we have spent half a day.

**Phase 1 — prove the embed (2–3 days)**
4. New `crates/copperline-ios`: C-ABI mirror of `copperline-web`, built as
   a staticlib for `aarch64-apple-ios` + `-sim`, core features only.
5. Minimal SwiftUI host: Metal layer fed from `present_ptr()`,
   `AVAudioSourceNode` fed from `take_audio()`, a run loop calling
   `run(now_ms, max_frames)`.
6. Boot the bundled AROS ROM on the M4 iPad. Measure on-device realtime
   factor for the same configs as Phase 0, including sustained (thermal)
   numbers.

> **GATE 2.** On-device 68060 + RTG must be usable. If it is not, the
> outcome is not "switch" — it is at most "keep Copperline as an optional
> *accuracy* core for OCS/ECS games and demos, WinUAE stays the default".
> That is a legitimate, much smaller product decision.

**Phase 2 — the UX make-or-break (2–4 days)**
7. Prototype absolute pointer. First try the existing servo with direct
   touch to confirm it feels as bad as predicted. Then implement a
   mousehack-equivalent guest trap, using their `filesys`/`amigaos` trap
   infrastructure as the model.
8. Offer it upstream — it is hardware-adjacent, generally useful, and the
   right way to build goodwill before depending on the project.

> **GATE 3.** If exact absolute pointing cannot be made to work, we ship a
> worse tablet than we ship today. Stop.

**Phase 3 — port the shell (1–2 weeks)**
9. Swift bridge, `ConfigStore` → TOML, machine panel retarget, save-state
   panel, Pencil/palm rejection in Swift, TV out as a second Metal layer.
10. Compatibility pass: WHDLoad, the RTG migration story, existing user
    HDFs, our own AmigaDiskKit-built test images.

**Before Phase 1, spend an hour on this:** talk to the author. There is
zero iOS work upstream, only three open issues, an active Discord, and a
Patreon whose stated goal includes *Apple code-signing subscriptions* — so
they care about shipping on Apple platforms. Their browser guide already
documents an iOS Safari quirk, meaning they have iOS users today. An
iPad frontend is a headline contribution, and knowing whether they want it
upstream (versus us maintaining a fork, which is the thing we are trying to
escape) changes the value of the whole plan.

## 7. What I would actually do

Run Phase 0. It is half a day and it decides the question — the entire case
turns on whether a cycle-driven core can run a 68060 desktop at speed on a
tablet, and right now nobody knows.

Meanwhile keep shipping WinUAE. Nothing here is urgent enough to interrupt
the App Store cycle we are in the middle of.

The most likely honest outcome, given R1–R3: **Copperline becomes a
second core for accuracy-critical OCS/ECS work in a year, once RTG lands
and the API settles — not a replacement now.** But Phase 0 is cheap enough
that guessing instead of measuring would be the wrong call.
