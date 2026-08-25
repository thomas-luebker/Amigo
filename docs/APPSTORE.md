# App Store Listing — Amigo — Amiga Emulator

Copy-paste source for App Store Connect. Keep in sync with releases.

Renamed from "iPadUAE" for resubmission (guideline 5.2.5 — "iPad" is not
permitted inside a product name). Repo/bundle ID/internal target name are
unchanged; only App Store metadata and the on-device display name changed.

## Name (30 chars max)

    Amigo — Amiga Emulator

## Subtitle (30 chars max)

    Classic Amiga Emulator

    (Decided 2026-08-18. ASC already held this string; the doc's older
    "Classic Amiga computing" was the odd one out and has been dropped.
    The German subtitle is deliberately NOT a translation of it —
    "Klassisches Amiga-Erlebnis" avoids repeating "Amiga Emulator",
    which the app name already carries.)

## Promotional Text (170 chars, changeable without review)

LIVE on 0.7.1 since 2026-08-18. The 0.7.1 What's New in ASC is the 0.7.0
list (the "prepend" note below became a replace), so the Reddit-feedback
batch is announced here instead — promo text is the only field editable
without a review.

    New in 0.7.1: CD32 console with CD/CHD images, drag with touch for
    Deluxe Paint, cursor keys fixed, LHA/LZX/7z archives, and an in-app
    Controls & Help screen.

    (158 chars. Set as one line; wrapped here for readability.)

Evergreen fallback, for when the 0.7.1 news goes stale:

    Full classic Amiga experience: RTG graphics, 68000–68060, touch or
    trackpad pointer, hardware keyboards and controllers. Free and open
    source, no ads.

## Description (4000 chars max)

    Amigo brings the classic Commodore Amiga to your iPhone and iPad. It
    is a native
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
    • Apple Pencil support: tap and double-tap on Pencil 2 and Pro;
      hover pointer and squeeze-to-click with Apple Pencil Pro
      (hover needs an M2 or newer iPad)
    • TV output via USB-C or AirPlay — fullscreen Amiga on the big screen
    • Save states with automatic saving
    • Bluetooth game controllers — plug and play, with CD32 pad mode,
      port routing and autofire
    • Hardware keyboards, mice and trackpads supported
    • Virtual Amiga keyboard, numpad, function keys and joystick overlays
    • Floppy images (ADF/ADZ/DMS) and hard drive images (HDF, RDB and
      plain), added via the Files app
    • Internet access for Amiga software through the bsdsocket library
    • Save and switch between named machine configurations
    • Works out of the box with the bundled open-source AROS Kickstart
      replacement ROM

    BRING YOUR OWN SYSTEM

    Amigo includes no Amiga operating system, games or copyrighted ROMs.
    If you own Kickstart ROMs and AmigaOS (for example from a licensed
    distribution), copy them into the Amigo folder in the Files app for
    the authentic experience. The bundled AROS ROM boots many titles
    without any Amiga files.

    FREE SOFTWARE

    Amigo is free, with no ads, purchases or accounts. It is licensed
    under the GNU GPL v2; the complete source code for every released
    build is available at github.com/thomas-luebker/Amigo.

    Based on WinUAE by Toni Wilen; original UAE by Bernd Schmidt.
    Amiga is a trademark of Amiga Corporation. This app is not affiliated
    with or endorsed by the trademark holder.

## Keywords (100 chars max, comma-separated, no spaces)

    amiga,emulator,retro,workbench,uae,winuae,68000,adf,hdf,whdload,a500,a1200,rtg,cd32,gamepad

    (91 chars, 9 spare. `cd32` and `gamepad` added 2026-08-23 for the
    0.7.5 submission — both shipped features and real search terms that
    the list omitted. Keywords are VERSION-SCOPED: this only takes effect
    when pushed to the 0.7.5 App Store version record, which must exist
    and be editable (Prepare for Submission) first.

    `joystick` also fits — all three together are exactly 100, the limit.
    Left off deliberately: `gamepad` already covers the pad, and sitting
    exactly on the cap leaves no room if a term ever needs adjusting.

    Previous value was 78 chars — a stray leading space was live through
    0.7.1 and trimmed on 0.7.2. "Commodore" deliberately omitted —
    third-party trademarks in keywords are a rejection trigger; "amiga"
    is needed for search and is standard across shipping emulators.)

## 0.7.6 — archive built 2026-08-25, NOT yet pushed to ASC

Build `20260825`, `MARKETING_VERSION 0.7.6`. Archive at
`build/Amigo.xcarchive`. Two user-reported bugs fixed, both verified on
real hardware the day they arrived, plus Apple Pencil pressure.

Drafted from `git log 5b15217..HEAD`, per the warning below — not from a
release commit.

en-US What's New, draft (needs pushing to ASC):

    • AHI sound works again — the emulated sound card was never actually placed on the Amiga's expansion bus, so drivers found nothing to open. Existing setups repair themselves on the next launch
    • Apple Pencil pressure reaches the Amiga. Turn on Pencil Pressure in Input & Overlays for programs that read tablet pressure through the system, such as Deluxe Paint
    • Serial Tablet, in the same menu, puts a Wacom graphics tablet on the Amiga's serial port for programs that drive one themselves. In TVPaint set the tablet type to "Wacom A4+ Pressure"
    • Fixed: the Apple Pencil's own tip could be mistaken for a resting palm and ignored, so taps and strokes went missing or seemed to stick
    • Fixed: the emulated serial port never told the Amiga a byte had been sent, so any program writing to it waited forever. Terminal and comms software could not work at all
    • Fixed: every byte the Amiga sent out of the serial port was doubled

Promotional text, draft:

    New in 0.7.6: Apple Pencil pressure in Amiga paint programs, AHI sound working again, and the serial port fixed — plus Pencil taps no longer mistaken for your palm.

de-DE What's New, draft (needs pushing to ASC):

    • AHI-Sound funktioniert wieder — die emulierte Soundkarte lag nie am Erweiterungsbus des Amiga, weshalb Treiber kein Gerät zum Öffnen fanden. Bestehende Konfigurationen reparieren sich beim nächsten Start selbst
    • Der Druck des Apple Pencil erreicht jetzt den Amiga. Schalten Sie unter „Input & Overlays" den Pencil-Druck ein — für Programme, die Tablett-Druck über das System lesen, etwa Deluxe Paint
    • „Serial Tablet" im selben Menü legt ein Wacom-Grafiktablett an die serielle Schnittstelle des Amiga, für Programme, die ein Tablett selbst ansteuern. In TVPaint als Typ „Wacom A4+ Pressure" wählen
    • Behoben: Die Spitze des Apple Pencil konnte für eine aufliegende Handfläche gehalten und ignoriert werden — Striche und Klicks gingen verloren oder schienen hängen zu bleiben
    • Behoben: Die emulierte serielle Schnittstelle meldete dem Amiga nie, dass ein Byte gesendet war. Programme, die darauf schrieben, warteten endlos — Terminal- und Kommunikationssoftware konnte gar nicht arbeiten
    • Behoben: Jedes Byte, das der Amiga über die serielle Schnittstelle sendete, wurde verdoppelt

de-DE promotional text, draft:

    Neu in 0.7.6: Apple-Pencil-Druck in Malprogrammen, AHI-Sound läuft wieder, serielle Schnittstelle repariert — und die Pencil-Spitze gilt nicht mehr als Handfläche.

> [!warning] Not pushed yet — this went no further than the archive
> Nothing has been uploaded to App Store Connect and no metadata has been
> set. Remaining: Xcode → Organizer → Distribute App, then What's New,
> promotional text and the de-DE translations. **de-DE is ~45% of
> downloads** and its What's New still has to be written.

## 0.7.5 — LIVE on ASC (pushed 2026-08-24, verified by read-back)

**What's New** — en-US 1,254 chars / de-DE 1,371, 11 bullets each.
**Promotional text** — en-US 155 / de-DE 169.
**Keywords** — en-US 91 with `cd32,gamepad`; de-DE unchanged at 91.

en-US What's New, as pushed:

    • Quick controls, bottom-left — one tap shows the Amiga keyboard; hold it for the numpad, function keys and virtual joystick. That used to take three taps through the menu
    • New disk button, bottom-right — swap floppies, hard disks and CDs without opening the menu, and eject and swap now work properly from the disk panel
    • Copy and paste between iOS and the Amiga — text both ways, and pictures from the Amiga to iOS
    • Multiple hard disks at last — mount several HDF images side by side and each appears as its own volume. Eject one and the rest keep running
    • CDs now work beyond the CD32 — mount a CD image on an A1200 or A4000 and the machine actually sees it
    • A floppy speed setting for faster ADF loading, now in the disk panel
    • Sharper drive LEDs — the status bar is no longer blurred when scaled up
    • Fixed a crash when opening some LHA archives as a floppy — the way most WHDLoad titles ship. If Amigo quit on you inserting a .lha, that is this
    • Fixed a start-up hang where the emulator could spin instead of booting
    • Fixed: choosing 32 MB of RTG graphics memory silently disabled the graphics card. The option is gone, and a machine already stuck on it repairs itself on next launch
    • Fixed: the same hard disk image could be mounted twice

Promotional text, as pushed:

    New in 0.7.5: one-tap quick controls, a disk button, copy & paste with iOS, several hard disks at once, and CDs beyond the CD32 — plus the LHA crash fixed.

> [!important] Generate release notes from `git log <last shipped>..HEAD`, never from the release commit
> The first draft of this was built from the 0.7.5 commit message and
> covered barely a third of the release — it missed the quick controls,
> the disk button, iOS copy & paste, CDs beyond the CD32, floppy speed,
> the LED sharpness fix and the start-up hang fix. **0.7.3 and 0.7.4 were
> never released**, so everything since 0.7.2 ships here.
> `git log release/0.7.2..HEAD` is what produces the true list. Length is
> never the constraint — the limit is 4000 chars and the full list used
> 1,254.

## What's New — 0.7.1

    • CD32 console! One tap in the new CD-ROM menu turns Amigo into a
      CD32 — supply the CD32 Kickstart ROM and your CD images (CUE/BIN,
      CCD, MDS, NRG, ISO and space-saving CHD)
    • Drag with touch: tap-then-drag, or hold until the button engages —
      move icons, select, draw in Deluxe Paint. Works on Kickstart 1.3 too
    • Cursor keys now type as cursor keys — the emulated joystick only
      claims them while the Virtual Joystick overlay is shown
    • New Controls & Help screen in the gear menu — every gesture explained
    • New Keyboard Style option: keep the classic see-through overlay, or
      put the screen above the keyboard (great in portrait) — plus a
      Picture Fit/Stretch setting
    • Floppy and Kickstart pickers now open LHA, LZX and 7z archives
    • Fixed: a paired game controller stopped responding after changing
      the machine or Kickstart

    (If 0.7.0's review is cancelled and this ships directly over 0.6.5,
    prepend the 0.7.0 list below.)

## What's New — 0.7.0

    • Amigo now runs on iPhone! Landscape and portrait, with an
      iPhone-sized virtual keyboard
    • Bluetooth game controllers now work — pair one and play. New
      Controller menu with CD32 pad mode, port routing and autofire
    • New CPU Speed setting: "Original" paces like real hardware and
      dramatically reduces battery drain — now the default for classic
      machines. "Maximum" remains for power setups
    • Disk images and Kickstart ROMs are found in subfolders — organize
      your Files › Amigo library however you like
    • Fixed a rare crash when leaving the app
    • If the emulator can't start after a machine change, it now undoes
      that change automatically instead of refusing to launch

## What's New — 0.6.4 (resubmission)

    • Renamed to Amigo — Amiga Emulator
    • Save states: three slots plus an automatic save every five minutes
      — resume exactly where you left off
    • Apple Pencil support: hover pointer, squeeze to click
    • TV output via USB-C and AirPlay
    • Overlay transparency slider; menu always stays above the keyboard

## App Review Information → Notes (for the reviewer)

    Amigo is a retro computer emulator (App Review Guideline 4.7). Key
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
      this exact build: https://github.com/thomas-luebker/Amigo
      (tag v0.6.4).
    - No data is collected (see Privacy Nutrition Label / PrivacyInfo).

    RE: Guideline 2.5.8 (previous rejection, this submission). The
    "desktop" shown on first launch is AmigaOS's own graphical shell
    (Workbench) — the emulated computer's own GUI, rendered entirely
    inside the app's own view. This is the same category as already-
    approved emulators that boot a full desktop GUI of the emulated
    system (UTM SE boots Windows/Linux desktops; iDOS 2 boots DOS/
    Windows 3.x). The emulated desktop does not interact with, overlay,
    or replace iOS's Home Screen, Springboard, multitasking UI, or
    notifications — the app cannot launch other iOS apps, cannot add
    icons/widgets to the Home Screen, and is fully contained within its
    own sandboxed window. Happy to provide a screen recording if useful.

## German localization (de-DE) — DE is ~45% of downloads

STATUS 2026-08-18: LIVE IN ASC on version 0.7.2 (PREPARE_FOR_SUBMISSION)
— description, keywords, What's New, promotional text and the German
subtitle are all filled in. Ships with the 0.7.2 submission.

The blocker was structural, not a review window: `POST
/v1/appStoreVersionLocalizations` against a released version returns 409
ENTITY_ERROR.RELATIONSHIP.INVALID, "Cannot create localization after the
app version has been submitted for review". Localizations can only be
added to a version in PREPARE_FOR_SUBMISSION. Creating the 0.7.2 version
record also spawned a second, editable appInfo, which is what unlocked
the German subtitle. Note the de-DE description is stored unwrapped (one
line per paragraph/bullet) so it reflows on iPhone; en-US still carries
the doc's hard wraps.

Before submitting 0.7.2: top both What's New lists with the actual 0.7.2
changes (they currently hold the 0.7.1 batch, which never reached the
store — see the Promotional Text note above), and confirm in the ASC UI
that de-DE inherits the en-US screenshots (it has no sets of its own).

### Subtitle (30 chars max)

    Klassisches Amiga-Erlebnis

### Promotional Text (170 chars)

    Neu in 0.7.1: CD32-Konsole mit CD/CHD-Images, Ziehen per Touch für
    Deluxe Paint, Cursortasten repariert, LHA/LZX/7z-Archive und ein
    Hilfe-Bildschirm für alle Gesten.

    (165 chars. Set as one line. Evergreen fallback below.)

    Das komplette Amiga-Erlebnis: RTG-Grafik, 68000–68060, Touch- oder
    Trackpad-Zeiger, Tastaturen und Controller. Kostenlos und Open
    Source, ohne Werbung.

### Keywords (100 chars max)

    amiga,emulator,retro,workbench,uae,winuae,68000,adf,hdf,whdload,a500,a1200,spiele,klassiker

    (91 chars. "spiele"/"klassiker" replace "rtg" — German search terms
    outrank a niche graphics acronym in the DE storefront.)

### Beschreibung (4000 chars max)

    Amigo bringt den klassischen Commodore Amiga auf iPhone und iPad.
    Die App ist eine native Portierung von WinUAE, dem genauesten
    Amiga-Emulator, und emuliert die gesamte klassische Palette — vom
    A500 bis zur 68060-Workstation mit RTG-Grafik und Netzwerk.

    FUNKTIONEN

    • Emuliert 68000–68060 CPUs, OCS/ECS/AGA-Chipsätze, FPU und MMU
    • RTG-Grafikkarte (Picasso96-kompatibel) für hochauflösende
      Workbench-Desktops
    • Schneller Interpreter-Kern: ein 68060 ist im Benchmark schneller
      als Desktop-Emulatoren ohne JIT
    • 1:1-Touch-Zeiger — die Amiga-Maus folgt dem Finger — oder
      klassischer Trackpad-Modus, mit Zwei-Finger-Scrollen in beiden
    • Apple-Pencil-Unterstützung: Tippen und Doppeltipp mit Pencil 2
      und Pro; Hover-Zeiger und Squeeze-Klick mit dem Apple Pencil Pro
      (Hover ab M2-iPad)
    • TV-Ausgabe über USB-C oder AirPlay — der Amiga im Vollbild auf
      dem großen Bildschirm
    • Spielstände (Save States) mit automatischem Sichern
    • Bluetooth-Controller — einfach koppeln und spielen, mit
      CD32-Pad-Modus, Port-Zuordnung und Autofeuer
    • Hardware-Tastaturen, Mäuse und Trackpads werden unterstützt
    • Virtuelle Amiga-Tastatur, Ziffernblock, Funktionstasten und
      Joystick-Overlays
    • Disketten-Images (ADF/ADZ/DMS) und Festplatten-Images (HDF, RDB
      und plain) — einfach über die Dateien-App hinzufügen
    • Internetzugang für Amiga-Software über die bsdsocket-Bibliothek
    • Benannte Maschinen-Konfigurationen speichern und umschalten
    • Läuft sofort mit dem mitgelieferten quelloffenen
      AROS-Kickstart-Ersatz-ROM

    EIGENES SYSTEM MITBRINGEN

    Amigo enthält kein Amiga-Betriebssystem, keine Spiele und keine
    urheberrechtlich geschützten ROMs. Wer eigene Kickstart-ROMs und
    AmigaOS besitzt (z. B. aus einer lizenzierten Distribution), kopiert
    sie über die Dateien-App in den Amigo-Ordner — für das authentische
    Erlebnis. Das mitgelieferte AROS-ROM startet viele Titel auch ohne
    eigene Amiga-Dateien.

    FREIE SOFTWARE

    Amigo ist kostenlos — ohne Werbung, Käufe oder Konten. Die App steht
    unter der GNU GPL v2; der vollständige Quellcode jeder
    veröffentlichten Version ist auf github.com/thomas-luebker/Amigo
    verfügbar.

    Basiert auf WinUAE von Toni Wilen; ursprüngliches UAE von Bernd
    Schmidt. Amiga ist eine Marke der Amiga Corporation. Diese App ist
    nicht mit dem Markeninhaber verbunden und wird von ihm nicht
    unterstützt.

### Neue Funktionen — 0.7.1 (de)

    • CD32-Konsole! Ein Tipp im neuen CD-ROM-Menü macht Amigo zum CD32 —
      CD32-Kickstart-ROM und CD-Images bereitstellen (CUE/BIN, CCD, MDS,
      NRG, ISO und platzsparendes CHD)
    • Ziehen per Touch: Tippen-dann-Ziehen oder Halten bis die Taste
      einrastet — Icons verschieben, auswählen, in Deluxe Paint zeichnen.
      Funktioniert auch mit Kickstart 1.3
    • Cursortasten tippen jetzt als Cursortasten — der emulierte Joystick
      belegt sie nur, solange das Joystick-Overlay sichtbar ist
    • Neuer Hilfe-Bildschirm im Zahnrad-Menü — jede Geste erklärt
    • Neue Tastatur-Option: klassisches durchscheinendes Overlay oder
      Bildschirm über der Tastatur (ideal im Hochformat) — plus
      Bildanpassung (Einpassen/Strecken)
    • Disketten- und Kickstart-Auswahl öffnet jetzt LHA-, LZX- und
      7z-Archive
    • Behoben: gekoppelter Controller reagierte nach Maschinen- oder
      Kickstart-Wechsel nicht mehr

### Neue Funktionen — 0.7.0 (de)

    • Amigo läuft jetzt auf dem iPhone! Quer- und Hochformat, mit
      iPhone-gerechter virtueller Tastatur
    • Bluetooth-Controller funktionieren jetzt — koppeln und spielen.
      Neues Controller-Menü mit CD32-Pad-Modus, Port-Zuordnung und
      Autofeuer
    • Neue CPU-Tempo-Einstellung: „Original“ taktet wie echte Hardware
      und schont den Akku deutlich — jetzt Standard für klassische
      Maschinen. „Maximum“ bleibt für Power-Setups
    • Disketten-Images und Kickstart-ROMs werden auch in Unterordnern
      gefunden — die eigene Bibliothek frei organisieren
    • Seltener Absturz beim Verlassen der App behoben
    • Startet der Emulator nach einer Maschinen-Änderung nicht mehr,
      wird die Änderung jetzt automatisch rückgängig gemacht

## URLs (App Store Connect fields)

    Privacy Policy URL:
      https://github.com/thomas-luebker/Amigo/blob/main/PRIVACY.md
    Support URL (live in ASC):
      http://amiga-imager.com
    Marketing URL (live in ASC):
      http://amiga-imager.com

    (Repo renamed to match the product 2026-08-14: github.com/
    thomas-luebker/Amigo; old iPadUAE URLs redirect. All require the
    repo to be PUBLIC.)

## Copyright (App Store Connect field)

    © 2026 Thomas Lübker. Based on WinUAE © Toni Wilen, UAE © Bernd Schmidt — GPL-2.

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
    (scripts/make_screenshots.py) once raw shots exist. Existing composed
    screenshots in docs/screenshots/appstore/ say "Classic Amiga on your
    iPad" as a caption headline — should be regenerated to drop "iPad"
    from the caption text too before re-upload (cosmetic, not app
    metadata, but avoid any appearance of the same issue recurring).
