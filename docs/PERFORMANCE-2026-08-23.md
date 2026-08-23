# Amigo performance — measured findings and what to change

*Handover from the amimcp session, 2026-08-23. Every number here was measured on
real devices through `amiagent` running **inside** the Amigo guest; nothing is
extrapolated. One-page summary with the full tables: `~/Desktop/amigo-vs-fsuae.pdf`.*

---

## The short version

1. **The emulation core is not the problem.** Under identical settings Amigo is
   *faster* than FS-UAE — +5.8% integer, +28% Dhrystone — on less host CPU.
   There is nothing worth winning by optimising the interpreter.
2. **MMU emulation costs 2.23×** and is on by default for 68040/060.
   That is the one change worth making, and it is three edits.
3. **The JIT is the only route to another order of magnitude.** The AArch64
   backend is already vendored and switched off. FS-UAE cannot lend you one —
   its arm64 build has no JIT compiled in at all.
4. **Three settings people fiddle with cost nothing**: 68040 data-cache
   emulation, FPU unimplemented-instruction handling, audio. Measured at zero.
5. Everything else in `ConfigStore.applyMachine` is already tuned correctly —
   see "What is already right", and please don't "fix" it.

---

## 1 · MMU emulation costs 2.23×

> [!important] **DECIDED 2026-08-23: MMU stays ON by default for 040/060.**
> The measurement below is accepted in full — the 2.23× is real and well
> evidenced. The *recommendation* is not taken. Authenticity wins: real 040/060
> have an MMU, SysInfo reports `IN USE`, and Enforcer/MuForce and any
> MMU-programming software need it. Amigo emulating an accelerated Amiga that
> silently lacks an MMU is the wrong default, and a user who loses two thirds of
> their speed can see the toggle, whereas a user whose debugger silently does
> nothing cannot see the cause.
>
> **The three edits in this section are therefore NOT to be made.** The comment
> at `MachinePanel.swift:47` still needs fixing — it claims MMU is *faster*,
> which is backwards by 2.23× — but the `m.mmu = true` line it guards stays.
>
> What replaces the recommendation: **make the MMU path cheaper.** See §7.

Measured on **Amigo, Mac M1 Max, guest 68040**, four runs per arm, only the MMU
toggle changed between them (same build, same CPU, same FPU, same guest image):

| | MMU on | MMU off | gain |
|---|---|---|---|
| amibench integer | 4.22 M ops/s | **9.41 M ops/s** | **2.23×** |
| amibench copy / set / read (MB/s) | 183 / 332 / 126 | 593 / 1174 / 430 | 3.2–3.5× |
| SysInfo Dhrystones | 79,832 | **213,556** | **2.68×** |
| SysInfo MIPS | 83.90 | 222.91 | 2.66× |
| SysInfo hardware panel | `MMU 68040 (IN USE)` | `MMU 68040 (NOT IN USE)` | — |

The MMU-off run was taken at *higher* host load (12.6 vs ~11), so the figure is
if anything conservative. Corroborated independently on FS-UAE with a
single-line config change: **2.08×** on amibench, **2.86×** on Dhrystone.

### The edits

**`app/Sources/MachinePanel.swift:47-50`** — the comment is half wrong and it
drives an auto-enable:

```swift
// MMU on is both faster and more authentic for 040/060
// (measured); default it on when moving up to them.
if newCPU >= 68040 { m.mmu = true }
if newCPU < 68030 { m.mmu = false }
```

*More authentic* is correct — real 040/060 have an MMU and SysInfo reports
`IN USE`. *Faster* is backwards by a factor of two, and line 49 turns it on for
exactly the CPUs where it costs the most. Suggested replacement:

```swift
// MMU emulation is authentic for 040/060 but costs ~2.2x interpreter
// throughput (measured 2026-08-23, both amibench and SysInfo; see
// docs/PERFORMANCE-2026-08-23.md). Leave it off unless the user asks —
// only Enforcer/MuForce and MMU-programming software need it.
if newCPU < 68030 { m.mmu = false }
```

**`app/Sources/ConfigStore.swift:419` and `:422`** — the `turbo` (68060) and
`rtgStation` (68040) presets both carry `mmu: true`. `rtgStation` is what the
fleet guests run, so this is the default path, not an edge case. Change both to
`mmu: false`.

**Keep `MachinePanel.swift:118`** — the `Toggle("MMU emulation (68030+)")` stays,
so anyone running Enforcer/MuForce or MMU-based memory protection can switch it
back on. This is a default change, not a removal.

> **The trap that hid this for so long.** The setting only takes effect when the
> core restarts. Toggle it and measure immediately and you measure the *old*
> configuration — which is exactly what happened on the iPad during this
> session: MMU toggled off, benchmark returned an identical 9.08 M ops/s,
> because nothing had been applied yet. Get the sequence wrong once and you can
> conclude the opposite of the truth, annotate it "(measured)", and it survives
> for months. **Always confirm from inside the guest**: SysInfo's INTERNAL
> HARDWARE MODES panel prints `MMU <model> (IN USE)` or `(NOT IN USE)`. That is
> ground truth; the config file is only an intention.

---

## 2 · What is already right — please leave it alone

`ConfigStore.applyMachine` is well tuned. Verified against measurement:

| setting | value | verdict |
|---|---|---|
| `cycle_exact` etc. (`:467` `let exact = m.cpu == 68000`) | 68000 only | **correct, and important.** Cycle-exact CPU emulation measured **100× slower** on FS-UAE at 68040. Keeping it to 68000 for game timing is exactly the right call. |
| `cpu_compatible` | `false` for 030+ | correct — measured to cost 30% when on |
| `cpu_data_cache` | `false` | fine, though the "is slow" reasoning is wrong: measured at **1.01×**, i.e. free either way |
| `fpu_strict`, `fpu_softfloat` | `false` | correct |
| `cpu_no_unimplemented` / `fpu_no_unimplemented` | `true` | **not contradicted.** The benchmark has no FPU phase, so the "big win for FPU-heavy code" claim was never tested here — treat it as still standing |
| audio | — | switching it off measured at **1.00×**; not a performance lever |

---

## 3 · The JIT — the only remaining order of magnitude

For scale, on the same benchmark: real A4000/060 = 2.81 M ops/s, Amigo
interpreting = 9.41, **PiStorm32/Emu68 with a JIT = 151.70**. A JIT is worth
roughly 16× over the best interpreted figure measured here, on far weaker
silicon than an M4.

**You already have the backend.** `vendor/WinUAE/jit/arm/` contains
`codegen_arm64.cpp`, `compemu_midfunc_arm64.cpp`, `compemu_midfunc_arm64_2.cpp`
and `aarch64.h`. It is disabled in two places:

- `scripts/build-ios-core.sh:52` — `-DWINUAE_UNIX_WITH_JIT=OFF`
- `app/Sources/ConfigStore.swift:463` — `set("cachesize", "0")  // no JIT on iOS`

**FS-UAE cannot help.** Its arm64 build accepts `jit_compiler = 1`, logs
`cachesize 8192` and `NATMEM: jit compiler 1`, and still resolves to `JIT=0` —
the binary contains no `compemu`/`comptbl` code at all. The option is plumbed
but hollow. Amigo's vendored backend is genuinely further along.

**Suggested next step: a macOS target as a measurement rig, not a product.**
Same CMake core with `WINUAE_UNIX_WITH_JIT=ON` and a non-zero `cachesize`, plus
`com.apple.security.cs.allow-jit` in the entitlements — macOS grants that
freely. Today's "Mac Amigo" is the iOS app running in the iOS runtime
(`…/X/<uuid>/d/Wrapper/Amigo.app`), so it inherits an iOS restriction that does
not apply to the platform it is running on. Build that and you learn what the
JIT is actually worth on Apple silicon before anyone spends effort on the iOS
entitlement question (dev-signed + debugger works for personal use; App Store
distribution does not).

Expect friction: UAE's JIT is the most fragile part of the codebase and the
ARM64 backend carries Amiberry's quirks. It belongs behind a toggle.

---

## 4 · Worth building: let the config be driven from outside

Every experiment in this session cost a human toggle and a round trip, because
Amigo's config lives in `Documents/Configuration/default.uae` on the device and
is only reloaded on core restart. FS-UAE, by contrast, takes a config file path
on the command line — which is why its seven-variant sweep ran unattended in 15
minutes while Amigo's single MMU question took all evening.

If Amigo could take a config override at launch — or apply one handed to it
through the agent already running inside the guest — the same harness would
sweep Amigo's whole settings surface automatically. That turns every future
performance question from an evening into a coffee break.

---

## 5 · How to reproduce any of this

The guest is a normal amimcp fleet node, so measurement is scriptable from the Mac:

```python
import sys; sys.path.insert(0, "~/Development/amimcp/server")
from amiga import Amiga
a = Amiga("127.0.0.1", token="a4000")     # or 192.168.178.142 for the iPad
a.write_file("RAM:amibench", open(".../dist/stage/amibench/amibench","rb").read())
rc, out = a.exec_command("RAM:amibench")   # reps + ticks; 50 ticks/sec, 4 MiB buffer
```

Rules that made the numbers trustworthy, learned the hard way:

- **Only one emulator running at a time.** Both Amigo and FS-UAE bind host port
  7846. Whichever boots second fails to bind, its agent exits, and probes are
  silently answered by the *other* one. A whole seven-variant sweep was thrown
  away for exactly this. Check *who* answered: `a.ping()` returns the agent
  version, and the guests differ (Amigo 0.13.0, the FS-UAE image 0.10.0).
- **Confirm the setting applied** from inside the guest before trusting a
  number — SysInfo's hardware panel, or UAE's own `CPU=… MMU=… JIT=…` log line.
- **amibench, not Dhrystone, for comparisons.** amibench held within 0.5% over
  21 runs and seven emulator restarts. SysInfo repeats to 1.1% within a session
  but moved 26% *between* sessions on an unchanged guest, and its MIPS column is
  just Dhrystones ÷ 958 — one measurement printed twice.
- **Change one thing.** The iPad run moved CPU model, MMU and FPU together and
  had to be discarded as evidence for any single one of them.

## 6 · One framing worth keeping

Emulation does not slow an Amiga uniformly — it **reshapes** it. Ratio of copy
throughput to integer throughput:

| | copy : int |
|---|---|
| real A4000/060 | 6.0 |
| PiStorm32 / Emu68 (JIT) | 11.0 |
| every interpreter measured | 41–66 |

Guest data movement is a host `memcpy` and runs near-native; every guest
*instruction* pays interpretation. So an emulated Amiga is quick at RTG
blitting, file copying and memory fills, and disproportionately slow at
instruction-dense work — compiling, ARexx, interpreters. Pulling that ratio back
toward real hardware is what a JIT actually buys, and it is a better argument
for the work than any single multiplier.

---

## 7 · Where the MMU cost actually is — and the room to optimise it

*Added 2026-08-23 after the decision above. The mechanism below is code reading;
the **results** were measured the same evening and are in §8. Read §8 before
acting on any of it — one of the two levers named here turned out to be worth
nothing, which is exactly why the counters went in first.*

### The cost is mostly not the MMU

Reading `newcpu.cpp:1915-1950`, enabling the MMU does something bigger than
adding address translation: it moves the whole CPU core onto a different
instruction table **and off its direct-PC fast path**.

    if (!currprefs.cachesize) {
        if (currprefs.mmu_model) {
            ... mode = 5;              // (6 with cpu_compatible, 7 with cycle_exact)
        } else if (currprefs.cpu_cycle_exact) { mode = 4;
        } else if (currprefs.cpu_compatible) { mode = 3;
        } else                                 mode = 0;
        m68k_pc_indirect = mode != 0 ? 1 : 0;    // <- the expensive bit
    }

Amigo's own settings (`cpu_compatible=false`, `cycle_exact=false`,
`cachesize=0`) mean the **only** thing standing between the config and `mode 0`
— "generic+direct", the fastest interpreter path there is — is `mmu_model`.
Turn the MMU on and `m68k_pc_indirect` flips to 1: every opcode and every
extension word stops being a direct host-pointer read and becomes a TTR check,
a page-cache tag compare, a physical-address compose and an `x_phys_get_iword()`
function-pointer dispatch.

For 68040 the table is the same for modes 5, 6 and 7 (`op_smalltbl_31`), so
`cpu_compatible` and `cycle_exact` are already free once the MMU is on — worth
knowing, but not a lever.

This predicts exactly the shape of the measured data: an instruction-dense
integer benchmark pays the fetch penalty alone (**2.23×**), while copy/set/read
pay fetch *and* data translation (**3.2–3.5×**).

### Lever B — the instruction page cache has ONE entry

`include/cpummu.h`. The data path has a 256-entry direct-mapped cache:

    #define MMUFASTCACHE_ENTRIES 256
    extern struct mmufastcache atc_data_cache_read[MMUFASTCACHE_ENTRIES];
    extern struct mmufastcache atc_data_cache_write[MMUFASTCACHE_ENTRIES];

The instruction path has a single scalar:

    extern uae_u32 atc_last_ins_laddr, atc_last_ins_paddr;

So any code alternating between two pages — a loop that straddles a page
boundary, or a main loop calling a routine in another page — misses on **every
fetch** and takes the full `mmu_translate()` walk. That asymmetry looks
unintentional, and code locality across 2–4 pages is the normal case, not a
corner. Widening it to a small direct-mapped array mirroring the data cache is a
contained change.

### Lever A — cache the host pointer, not just the physical address

Both caches end their hit path the same way:

    addr = atc_data_cache_read[idx2].phys | (addr & mmu_pagemask);
    ...
    return x_phys_get_long(addr);          // function-pointer bank dispatch

The hit already knows the physical page. If `mmu_translate` also stored the
**host base pointer** for pages that resolve into a directly-addressable RAM
bank, the hit path would become a plain load — roughly what the non-MMU direct
path does, which is the whole 2.23× being argued about.

This is the bigger win and the riskier change. It must fall back to the bank
call for anything with side effects (custom chip registers, RTG), and the
pointer must be invalidated wherever the physical mapping can move. The
invalidation hook already exists — the caches are flushed on `PFLUSH` today.

### Measure before touching either

There is already an instrument, and it is switched off:

    include/cpummu.h:36:  #define CACHE_HIT_COUNT 0

Set it to 1 and the counters `mmu_ins_hit/miss`, `mmu_data_read_hit/miss` and
`mmu_data_write_hit/miss` start incrementing — but nothing reports them, so a
`write_log` of the six counters is needed too. That single number — the
instruction cache miss rate under amibench — decides whether Lever B is worth
anything before a line of it is written.

This repo has been bitten three times by reasoning where it could have measured
(`FINDINGS-2026-08-19.md` §4.1, §4.5, §4.6), and once by a comment that said
"(measured)" and was backwards. **Enable the counters first.**

---

## 8 · Measured: one lever is dead, the other is worth ~20%

*2026-08-23, M4 iPad, 68040 + MMU. `CACHE_HIT_COUNT` was enabled in a
throwaway build with a `write_log` reporter, then reverted; the release tree
was afterwards verified byte-identical to a fresh application of
`patches/0001-ios-port-fixes.patch`.*

### Lever B is dead — the instruction cache does not thrash

Miss rates over five-second windows under amibench:

    ins 582,582,098  miss 325,202 (0.06%)   rd 198,662,145  miss 561,978 (0.28%)
    ins 559,366,743  miss 457,580 (0.08%)   rd 182,466,965  miss 581,090 (0.32%)
    ins 347,233,457  miss 124,111 (0.04%)   ...

**0.04–0.29%.** The single-entry instruction page cache hits essentially
always. The §7 reasoning — that two hot code pages would alternate and miss
every fetch — is **wrong**, and wrong for a plain reason: the cache holds a
*page*, and instruction fetch is overwhelmingly sequential within one. A loop
inside a page hits every time; crossing a boundary costs one miss and then
stays hit. Widening that cache would buy nothing.

Had this been "fixed" on the strength of the code reading, the change would
have shipped with no effect — and probably been credited with someone else's
improvement later.

### So the cost is the hit path, not the misses

All three caches hit >99.7% under load, at roughly **116M instruction fetches
per second**. Nearly every access takes the hit path, so the only thing worth
attacking is what a *hit* costs.

### Lever A works: +7% to +20.5%

Host pointer cached in the page caches, resolved once per page fill, hit path
reads host RAM directly instead of dispatching through `x_phys_get_*`. Branch
`perf/mmu-hostptr`, commit `8779c39`, carried as
`patches/0002-mmu-host-pointer-cache.patch`.

| test | MMU on | Lever A | gain | MMU off | gap closed |
|---|---|---|---|---|---|
| int | 8.37 M ops/s | **10.08** | **+20.5%** | 15.42 | 24% |
| copy | 377.6 MiB/s | **450.7** | **+19.4%** | 1066.7 | 11% |
| set | 766.5 MiB/s | **820.5** | +7.1% | 2124.5 | 4% |
| read | 310.7 MiB/s | **358.5** | +15.4% | 761.9 | 11% |

Two runs per arm agreed to one tick. Rates, not ticks — **amibench rescales
`reps` between arms**, so comparing tick counts directly is wrong.

It recovers about a fifth of the MMU penalty on instruction-dense work
(1.84x → ~1.53x), not the whole thing. Reads only: the write cache stores
`host = NULL`, which is likely why `set` gained least.

> [!warning] Not shippable as it stands
> A bank remap that moves `baseaddr` without an ATC flush leaves a stale
> pointer. Banks are set up at reset and do not normally move, but that must be
> resolved first. Guest correctness was otherwise clean: boots, all four
> volumes, RTG 1280x720, and a 2 MiB round-trip through FFS matched SHA-256.

### The MMU cost itself, re-measured single-variable

Same machine, same guest, only `mmu_model` changed — a cleaner method than the
cross-emulator comparison in §1, and an independent confirmation of it:

| test | MMU ON | MMU OFF | cost |
|---|---|---|---|
| int | 8.37 M ops/s | 15.42 | **1.84x** |
| copy | 377.6 MiB/s | 1066.7 | **2.83x** |
| set | 766.5 MiB/s | 2124.5 | **2.77x** |
| read | 310.7 MiB/s | 761.9 | **2.45x** |

Lower than §1's 2.23x/3.2–3.5x on an M1 Max, same shape: memory work pays
roughly 1.5x the penalty instruction work does, consistent with fetch and data
each being charged separately.
