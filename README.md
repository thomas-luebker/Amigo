# iPadUAE

An iPad port of [WinUAE](https://github.com/tonioni/WinUAE), built directly on the
upstream Unix/SDL3 layer (`od-unix/`), targeting iPadOS and App Store distribution.
**Version 0.6.2.** Licensed **GPL-2** (see `LICENSE`), like WinUAE itself.

Runs full **AmigaOS 3.2 Workbench** on device with RTG graphics (reliable
across resets), networking, hard drives, 1:1 touch pointer + two-finger
scrolling, virtual keyboard/numpad/F-keys/joystick, hardware keyboard & mouse,
**Apple Pencil** (hover pointer, squeeze right-click, hover-drag, palm
rejection), **TV output** via USB-C or AirPlay (fullscreen Amiga on the big
screen, controls on the iPad), **save states** with 5-minute autosave,
user-saved machine configurations (reinstall-proof media paths), and a native
SwiftUI control surface. Emulated 68060 benchmarks ~2.8× faster than FS-UAE
on an M1 (interpreter vs interpreter; no JIT on iOS).

Ships with two upstream fixes discovered during the port: a WinUAE
mousehack-after-reboot fix and an SDL3 UIScene fix (second scene re-ran
`SDL_main`; crashed any SDL iOS app on AirPlay connect) — see `patches/`.

## Docs

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — how to use the app
- [`docs/TESTER_GUIDE.md`](docs/TESTER_GUIDE.md) — TestFlight tester guide
- [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md) — release/archive steps
- [`docs/LICENSING.md`](docs/LICENSING.md) — GPL-2 / App Store plan
- Deep design notes live in the author's Obsidian vault (`iPadUAE/` folder).

## Layout

- `vendor/WinUAE` — upstream WinUAE as a git submodule (do not edit in place;
  patches to upstream live in `patches/`, applied via `scripts/apply-patches.sh`)
- `vendor/SDL3` — official SDL3 xcframework (device + simulator)
- `core-ios/` — CMake wrapper: builds the core as `libuaecore.a`, adds `ios_glue.cpp`
- `app/` — the iPad application (XcodeGen project, Swift/SwiftUI + ObjC++ bridge)
- `scripts/` — `build-ios-core.sh`, `build-release.sh`, `apply-patches.sh`
- `docs/` — user- and tester-facing documentation

## Building

```sh
git submodule update --init      # vendor/WinUAE
./scripts/apply-patches.sh       # applies patches/*.patch (idempotent)
./scripts/build-ios-core.sh      # cross-compiles build/ios/libuaecore.a (arm64 iOS)
xcodegen -s app/project.yml      # regenerates app/iPadUAE.xcodeproj
open app/iPadUAE.xcodeproj       # build & run the iPadUAE target on an iPad
```

For a TestFlight/App Store archive: `./scripts/build-release.sh`.

Upstream patches needed for iOS live in `patches/` and are also applied in the
`vendor/WinUAE` submodule working tree.

## Constraints

- **No JIT** on iPadOS (no writable+executable pages) — CPU emulation runs interpreted.
- **No Qt** — the desktop Qt config UI is replaced by a native SwiftUI surface.
- **No bundled Kickstart ROMs** — users import ROMs via the Files app; the
  built-in AROS ROM (`aros.rom.cpp`, already in the WinUAE tree) is the fallback.
