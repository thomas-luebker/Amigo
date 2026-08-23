# Amigo — Agent Guide

## Long-term memory: the Obsidian vault

This project's durable state lives in the **Loki** Obsidian vault:

```
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Loki/20 - Private/Retro Computing/Projects/Amigo.md
```

**Read that note at the start of a session** — its `## Status` and `## Next Actions` are the current state and the agreed next steps, and it holds the decisions and findings that are not in the code. **Update it when the state changes**: refresh `## Status` (dated), rewrite `## Next Actions`, bump `updated:` in the frontmatter.

This repo's own backlog stays the fine-grained list; the vault note is the durable summary and the cross-project view. Directory-wide rules: `~/Development/CLAUDE.md`.

## Amiga tooling — the `amiga` plugin has it

The shared inventory (disk images, 68k cross-compiler, amipkg, Amiga Imager,
amiagent) now lives in the **`amiga` plugin** — `~/Development/AllAmigaTooling/`,
installed at user scope, so `amiga-tooling`, `amiga-fleet`, `amiga-disk`,
`amiga-68k`, `amiga-package`, `amiga-image-build`, `amiga-icon`, `amiga-arexx`
and `amiga-release` load in every directory. Nothing is on `PATH`;
`amiga-tooling` says where each binary is.

What follows is only what is **specific to Amigo** and is written nowhere else.

### The guest is a fleet node

**Point `amiagent` at the guest running *inside Amigo on the iPad*.** The
emulated Amiga is just another node — that is how the clipboard path was
diagnosed (`docs/BACKLOG.md` → the `CBD_CHANGEHOOK` item), and it doubles as a
liveness probe, since amiagent answering at all proves the emulator is still
running.

The same door works for instrumenting the guest directly: a ten-line 68k C
program run inside Amigo tells you what no amount of reading `ios_glue.cpp`
will. Cross-compiler details are in the `amiga-68k` skill.

> **The M4 iPad is also an amimcp fleet node.** Every `devicectl` install kills
> the guest and any live amiagent session on it. Coordinate before installing
> (`docs/FINDINGS-2026-08-19.md:538`).

### Name test volumes uniquely

The 8 GB system image is an RDB carrying both `Workbench` **and** `Work`. Add a
second volume also called `Work` and **AmigaOS silently drops it** while it
still looks mounted at the emulator level — a multi-drive test that quietly
tests one drive. For the same reason two copies of one image are useless for
multi-drive work: the volumes are indistinguishable. Build media with the
`amiga-disk` skill and give every volume its own name.

