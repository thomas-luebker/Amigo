# iPadUAE

An iPad port of [WinUAE](https://github.com/tonioni/WinUAE), built directly on the
upstream Unix/SDL3 layer (`od-unix/`), targeting iPadOS and App Store distribution.

## Layout

- `vendor/WinUAE` — upstream WinUAE as a git submodule (do not edit in place;
  patches to upstream live as small commits in the submodule fork or in `patches/`)
- `app/` — the iPad application (Xcode project, Swift/SwiftUI shell)
- `scripts/` — build scripts (iOS cross-compile of the core, dependency builds)

## Building

```sh
./scripts/build-ios-core.sh      # cross-compiles build/ios/libuaecore.a (arm64 iOS)
xcodegen -s app/project.yml      # regenerates app/iPadUAE.xcodeproj
open app/iPadUAE.xcodeproj       # build & run the iPadUAE target on an iPad
```

Upstream patches needed for iOS live in `patches/` and are also applied in the
`vendor/WinUAE` submodule working tree.

## Constraints

- **No JIT** on iPadOS (no writable+executable pages) — CPU emulation runs interpreted.
- **No Qt** — the desktop Qt config UI is replaced by a native SwiftUI surface.
- **No bundled Kickstart ROMs** — users import ROMs via the Files app; the
  built-in AROS ROM (`aros.rom.cpp`, already in the WinUAE tree) is the fallback.
