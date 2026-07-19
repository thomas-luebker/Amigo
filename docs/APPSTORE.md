# App Store Listing — iPadUAE

Copy-paste source for App Store Connect. Keep in sync with releases.

## Name (30 chars max)

    iPadUAE — Amiga Emulator

## Subtitle (30 chars max)

    Classic Amiga on your iPad

## Promotional Text (170 chars, changeable without review)

    Full classic Amiga experience: RTG graphics, 68000–68060, touch or
    trackpad pointer, hardware keyboards and controllers. Free and open
    source, no ads.

## Description (4000 chars max)

    iPadUAE brings the classic Commodore Amiga to your iPad. It is a native
    port of WinUAE, the most accurate Amiga emulator, running the complete
    range of classic machines from a stock A500 to a 68060 workstation with
    RTG graphics and networking.

    FEATURES

    • Emulates 68000–68060 CPUs, OCS/ECS/AGA chipsets, FPU and MMU
    • RTG graphics card (Picasso96-compatible) for high-resolution
      Workbench desktops
    • Fast interpreter core: a 68060 benchmarks faster than desktop-class
      emulators without JIT
    • 1:1 touch pointer — the Amiga mouse follows your finger — or classic
      trackpad-style relative mode, with two-finger scrolling in both
    • Hardware keyboards, mice, trackpads and game controllers supported
    • Virtual Amiga keyboard, numpad, function keys and joystick overlays
    • Floppy images (ADF/ADZ/DMS) and hard drive images (HDF, RDB and
      plain), added via the Files app
    • Internet access for Amiga software through the bsdsocket library
    • Save and switch between named machine configurations
    • Works out of the box with the bundled open-source AROS Kickstart
      replacement ROM

    BRING YOUR OWN SYSTEM

    iPadUAE includes no Amiga operating system, games or copyrighted ROMs.
    If you own Kickstart ROMs and AmigaOS (for example from a licensed
    distribution), copy them into the iPadUAE folder in the Files app for
    the authentic experience. The bundled AROS ROM boots many titles
    without any Amiga files.

    FREE SOFTWARE

    iPadUAE is free, with no ads, purchases or accounts. It is licensed
    under the GNU GPL v2; the complete source code for every released
    build is available at github.com/thomas-luebker/iPadUAE.

    Based on WinUAE by Toni Wilen; original UAE by Bernd Schmidt.
    Amiga is a trademark of Amiga Corporation. This app is not affiliated
    with or endorsed by the trademark holder.

## Keywords (100 chars max, comma-separated, no spaces)

    amiga,emulator,retro,workbench,uae,winuae,68000,adf,hdf,whdload,a500,a1200,rtg

    (98 chars. "Commodore" deliberately omitted — third-party trademarks
    in keywords are a rejection trigger; "amiga" is needed for search and
    is standard across shipping emulators.)

## What's New — 0.4.1

    • Menu overlay now adapts to every iPad size and orientation
    • 1:1 mouse mode reliably re-engages after WHDLoad sessions and resets
    • Saved configurations show machine, disks and date at a glance
    • Clear on/off indicators for all menu toggles
    • About & Licenses screen with full source-code information

## App Review Information → Notes (for the reviewer)

    iPadUAE is a retro computer emulator (App Review Guideline 4.7). Key
    facts for review:

    - The app contains NO copyrighted Amiga ROMs, operating systems or
      games. The only bundled system software is the AROS Kickstart
      replacement ROM, an open-source re-implementation licensed under
      the AROS Public License and redistributed by upstream WinUAE for
      years.
    - On first launch the app boots this open-source ROM immediately —
      no downloads, no accounts, nothing to configure. Users who own
      Amiga system files may add their own via the Files app.
    - The app runs no downloaded executable code in the iOS sense: it is
      a pure interpreter (no JIT), the same approach as other approved
      emulators (UTM SE).
    - The app is free software (GPL-2). Complete, buildable source for
      this exact build: https://github.com/thomas-luebker/iPadUAE
      (tag v0.4.1).
    - No data is collected (see Privacy Nutrition Label / PrivacyInfo).

## Category / Rating

    Primary: Utilities (alt: Entertainment). Age rating: 4+.
    Privacy: no data collected. Export compliance: no encryption
    (ITSAppUsesNonExemptEncryption=NO already in the binary).

## Screenshots

    Required: 13" iPad class (2752×2064 landscape) — shoot on the 13" M4
    (native resolution matches exactly). 11" optional but we have the
    device (2388×1668).

    Shot list (landscape, gear menu closed unless noted):
    1. AmigaOS 3.2 Workbench RTG desktop, a few windows open — hero shot
    2. A game running (user-supplied, rights-safe: use an Aminet/PD title
       or AROS Workbench — do NOT screenshot commercial games)
    3. Virtual Amiga keyboard + a Shell window
    4. Gear menu open showing the control panel (toggles visible)
    5. Machine panel (CPU/RAM/RTG choices)
    6. Configurations panel with 2–3 saved setups

    Raw PNGs → docs/screenshots/raw/. Captioning/framing is scripted
    (scripts/make_screenshots.py) once raw shots exist.
