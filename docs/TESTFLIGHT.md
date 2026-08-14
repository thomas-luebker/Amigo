# Amigo — TestFlight Release Prep

## One-shot archive build

```sh
cd ~/Development/Amigo
./scripts/build-release.sh          # builds core + archive, ready for Organizer
```

Then: open `build/Amigo.xcarchive` in **Xcode → Window → Organizer →
Distribute App → TestFlight & App Store**, and upload.

## Manual steps (what the script does)

```sh
./scripts/build-ios-core.sh device
xcodegen -s app/project.yml
xcodebuild -project app/Amigo.xcodeproj -scheme Amigo \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  -archivePath build/Amigo.xcarchive archive
```

## Before first upload (one-time, needs your Apple account)

1. **App Store Connect** → create app record, bundle ID `de.amiga-imager.uae`,
   iPad-only. (Paid Apple Developer Program membership required for TestFlight.)
2. Automatic signing will mint the Distribution profile on archive/upload
   (`-allowProvisioningUpdates`).

## App Review / compliance (guideline 4.7)

- ✅ Boots without a user ROM (built-in AROS) — functional as submitted.
- ✅ No copyrighted ROMs/software bundled — users supply via Files.
- ✅ No JIT — pure interpreter.
- ✅ Export compliance answered (`ITSAppUsesNonExemptEncryption=NO`).
- ⏳ Recommended before a *public* beta: in-app About/Licenses screen (GPL-2 +
  attributions) and the public GPL-2 source repo — see `docs/LICENSING.md`.

## Tester-facing copy

"What to Test" / tester guide text: `docs/TESTER_GUIDE.md`.
User guide: `docs/USER_GUIDE.md`.
