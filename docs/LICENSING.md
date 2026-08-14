# Amigo — Licensing

## Decision: release FREE

WinUAE is **GPL-2**. GPL-on-App-Store has historical friction (Apple's terms
arguably add restrictions contrary to GPLv2 §6 — basis of the 2011 VLC
takedown), but it has never been settled in court and only matters if a
copyright holder complains.

**Precedent is favorable:**
- **RetroArch** and **PPSSPP** (both GPL) have been on the App Store since
  2024 and remain there (mid-2026). Apple guideline 4.7 explicitly allows
  retro-console emulators.
- **Amiberry** (same WinUAE-derived GPL core) ships officially on Google Play;
  UAE4ARM/UAE4All2 did too. The UAE community has never enforced against a
  port — its culture *is* permissive forking.
- Copyright is concentrated in **Toni Wilen** (2000–2025, "complete rewrite
  2024–2025") and **Bernd Schmidt** (original UAE). Toni has cooperated with
  commercial WinUAE bundling (Cloanto Amiga Forever) for two decades.

## Plan (do in parallel, not as a blocker)

1. **Compliance hygiene** (what keeps RetroArch safe):
   - Public **GPL-2 repo**, submodule pinned + `patches/` included → anyone can
     rebuild the exact shipped binary. Tag every TestFlight/Store build.
   - In-app **About/Licenses** screen: GPL-2 text; "based on WinUAE by Toni
     Wilen, original UAE by Bernd Schmidt"; source link; SDL3 (zlib); AROS ROM
     (AROS Public License).
   - Free forever, no accounts, no added EULA.
2. **Courtesy note to Toni Wilen** — reframed as a contribution: "here's an iOS
   port of your od-unix layer, 4 small guarded patches offered upstream,
   shipping free with full source — any concerns?" Converts very-low risk to
   zero. Optional CC Bernd Schmidt.

## Third-party surface (small)

Amigo bundles no Amiga files. Only: **SDL3** (zlib — unconditionally fine),
**LZMA SDK** (public domain), **AROS ROM** (APL, redistributable — same ROM
WinUAE ships). The only license question is WinUAE itself.

## Fallback if Toni objects (unlikely)

AltStore PAL / EU marketplaces (where UTM/Delta live, terms don't conflict with
GPL), or a public build-it-yourself repo. App loses nothing technically.

Related: [[iPadUAE - Roadmap & Open Questions]]
