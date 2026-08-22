# Amigo — Agent Guide

## Long-term memory: the Obsidian vault

This project's durable state lives in the **Loki** Obsidian vault:

```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Loki/20 - Private/Retro Computing/Projects/Amigo.md
```

**Read that note at the start of a session** — its `## Status` and `## Next Actions` are the current state and the agreed next steps, and it holds the decisions and findings that are not in the code. **Update it when the state changes**: refresh `## Status` (dated), rewrite `## Next Actions`, bump `updated:` in the frontmatter.

This repo's own backlog stays the fine-grained list; the vault note is the durable summary and the cross-project view. Directory-wide rules: `~/Development/CLAUDE.md`.

## Use the Amiga tooling we already have — do not rebuild it

There is a mature toolchain next door in `~/Development/`. Before writing a
script to poke at a disk image, hand-type on the Amiga, or hand-roll a 68k test
binary, check this list. Almost every Amiga-side question Amigo raises has an
existing tool that answers it.

### Real hardware and the emulated guest: amimcp + amiagent

`~/Development/amimcp/` is the MCP server on the Mac; **`amiagent` 0.13.0** is
the daemon on the Amiga side (the fleet still runs 0.12.0 until upgraded). It
autostarts on the **Amiga 4000** from `S:User-Startup`, after Roadshow — it
needs `bsdsocket.library` — and answers ~6 s after the network comes up. It can
also be started from its Workbench icon, with the token in the icon's tool types.

It runs AmigaDOS commands, moves files both ways, reads system state, grabs the
screen, injects input, lists and prioritises tasks (`TASKLIST`/`TASKPRI`), does
chunked downloads (`GETRANGE`), and drives GUI programs over the local
`AMIAGENT` ARexx port (`ACTIVATEWINDOW`/`ENTERTEXT`/`KEY`/`REXXPORTS`/`QUIT`).
`tools/amifleet` is the VNC/RFB fleet console.

**The trick specific to Amigo: point `amiagent` at the guest running *inside
Amigo on the iPad*.** The emulated Amiga is just another node — that is how the
clipboard path was diagnosed (`docs/BACKLOG.md` → the `CBD_CHANGEHOOK` item),
and it doubles as a liveness probe, since amiagent answering at all proves the
emulator is still running.

> Two gotchas worth not rediscovering:
> - amiagent output is **off by default on purpose**. An AmigaShell pauses output
>   the moment someone clicks in the window to mark text, and a process writing
>   to a paused console *blocks* — which would stop the daemon accepting
>   connections because of a window nobody is looking at. `VERBOSE` opts back in.
> - **The M4 iPad is also an amimcp fleet node.** Every `devicectl` install kills
>   the guest and any live amiagent session on it. Coordinate before installing
>   (`docs/FINDINGS-2026-08-19.md:538`).

### Disk images: AmigaDiskKit / AmigaDiskCLI

`~/Development/AmigaDiskKit/` — a pure-Swift library (Apache-2.0) for Amiga
media, also vendored into Amiga Imager as `AmigaImager/AmigaDiskKit`. MBR + RDB
layouts, FFS/OFS and PFS3 format/mount/read/write, ADF, FAT32, LHA, ILBM/icon
decode. All offsets are `Int64`, so >4 GiB partitions behave like small ones.

The CLI is the fast path for building test media. It is **not on `PATH`**:

```
~/Development/AmigaDiskKit/.build/arm64-apple-macosx/release/AmigaDiskCLI
```

```
disk rdb-build <img> <bytes> --part Name:DOS3:::0     # blank image with an RDB
disk rdb-format <img> <part> <vol>                    # real empty FFS volume
disk fs dir|mkdir|copy|extract <img> <part> …         # file I/O into the image
lha create <out.lha> <dir>                            # packs -lh5-
```

Size is in **bytes**; partitions are addressed by **name**, not index. This is
what made the multi-HDD work testable. Two traps already paid for:
**name test volumes uniquely** — the 8 GB system image is an RDB with
`Workbench` *and* `Work`, and a second volume also called `Work` is silently
dropped by AmigaOS while looking mounted at the emulator level; and two copies
of one image are useless for a multi-drive test, since the volumes are
indistinguishable.

### Writing 68k C: the amiga-gcc cross-toolchain

bebbo's amiga-gcc is **built and working on this Mac**, but **not on `PATH`**:

```
~/opt/amiga/bin/m68k-amigaos-gcc          # GCC 6.5.0b (built 2026-06-02)
~/opt/amiga/m68k-amigaos/{ndk,ndk-include,ndk13-include,libnix,ixemul}
~/m68k-amigaos-gcc/                       # the build tree it came from
```

Also there: `m68k-amigaos-{as,ld,objdump,nm,strip,gprof}`, `g++`, plus
`fd2pragma`, `fd2sfd` and the `ira` disassembler. Verified working 2026-08-22 —
a `-m68000` build against `<exec/execbase.h>` links and `file` reports an
"AmigaOS loadseg()ble executable".

Use it rather than guessing about guest-side behaviour. A ten-line C program
run inside Amigo instruments the *guest* in a way no amount of reading
`ios_glue.cpp` will — the open `CBD_CHANGEHOOK` question is exactly this shape.
`~/Development/amipkg/Makefile` is the reference invocation (`-Os
-fomit-frame-pointer -m68000`, `-lgcc` **after** the objects, because newlib's
printf pulls in libgcc's 64-bit and soft-float helpers).

### Software onto a test image: amipkg + amiga-pkg

- `~/Development/amipkg/` — the on-Amiga package manager for AmigaOS 3.x, in C
  (`amipkg install <id>`): signed catalog, SHA-256 verification, CPU-aware
  dependency resolution, receipts for clean removal. CLI + GadTools GUI + MUI
  GUI. `make` (68000 baseline) / `make CPU=68020`; `Makefile.host` builds the
  portable core for host-side testing without the cross-toolchain.
- `~/Development/amiga-pkg/` — the catalog gateway: package submissions,
  validation, and the single signed index amipkg trusts. Python (`amigapkg.py`).

For Amigo this is how you populate a guest with real software instead of
hand-copying files — and it makes Amigo a live target for the same images
Amiga Imager builds.

### Whole bootable systems: Amiga Imager

`~/Development/AmigaImager/` builds bootable Amiga systems (PiStorm/Emu68,
Classic, and emulators — UAE included) through a native Swift engine, with
`AmigaImagerTools/main.swift` as its CLI. When a test needs a *complete* working
system rather than a blank volume, build one there.

Vault notes for all of the above: `20 - Private/Retro Computing/Projects/` —
`amimcp.md` (+ its `amimcp/amiagent.md`), `Amiga Imager.md`, `amipkg.md`.
See `~/Development/CLAUDE.md` for the directory-wide description.
