# Amigo — TestFlight Release Prep

## One-shot archive build

```sh
cd ~/Development/Amigo
./scripts/build-release.sh 20260824.1   # PASS THE BUILD NUMBER — see below
# 20260824 is already on ASC (duplicate); 20260825 is a future date and the
# script's guard rejects it. The .1 suffix clears both. Next: 20260824.2
```

Then: open **Xcode → Window → Organizer → Distribute App → TestFlight &
App Store**, and upload.

> **Copy the archive where Organizer can see it.** The script writes to
> `build/Amigo.xcarchive`, but Organizer only indexes
> `~/Library/Developer/Xcode/Archives/<date>/`. Copy it there (naming it
> `Amigo <version> (<build>).xcarchive`) or it will not appear in the
> list.

> **2026-09-08: the scheme is one day ahead again.** Two builds went up
> that afternoon, `20260908` (attached to 0.7.7, submitted) and a stray
> `20260909` four minutes later from a second archive. So `20260909` is
> already taken: on 2026-09-09 the script's default number will be
> rejected as a duplicate. **Next build: `20260909.1`.** From 09-10 the
> plain date works again.

> **Never advance the date to get a higher number. Add a suffix.**
> On 2026-08-20 six builds went up as `20260819`…`20260824` because each
> same-day rebuild bumped the *date* instead of adding `.N`. That left the
> scheme four days ahead of the calendar, and for the next four days
> `date +%Y%m%d` produced a number ASC rejected as not-higher.
>
> - Second build today → `20260822.1`, `20260822.2`, …
> - Scheme still ahead and ASC needs higher → suffix the **last uploaded**
>   build (`20260824.1`), which re-syncs sooner than picking a new date.
>
> `build-release.sh` now refuses a future date part outright (override with
> `ALLOW_FUTURE_BUILD=1`), and validates before building so it fails in
> milliseconds rather than after a full core compile.

> **The upload itself cannot be scripted on this Mac.** There is no iOS
> Distribution certificate in the keychain (only *Developer ID
> Application*, which is for Mac distribution outside the App Store), so
> `xcodebuild -exportArchive` fails with `No signing certificate "iOS
> Distribution" found`. Organizer works because it cloud-signs through
> Xcode's signed-in Apple ID, which `xcodebuild` cannot see (`error: No
> Accounts`). Using an ASC API key instead fails with `Cloud signing
> permission error` — cloud signing needs an **Admin** key, and
> `4AA2Q26Z9Q` is App Manager. Raising it to Admin in ASC → Users and
> Access → Integrations would make end-to-end CLI release possible.

## Manual steps (what the script does)

```sh
./scripts/build-ios-core.sh device
xcodegen -s app/project.yml
xcodebuild -project app/Amigo.xcodeproj -scheme Amigo \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  -archivePath build/Amigo.xcarchive archive
```

## Before first upload (one-time, needs your Apple account)

1. **App Store Connect** → create app record, bundle ID `de.amiga-imager.uae`.
   (Originally iPad-only; iPhone shipped in 0.7.1 and is now the larger
   share of new installs.) (Paid Apple Developer Program membership required for TestFlight.)
2. Automatic signing mints the Distribution profile during **Organizer**
   distribution. It does *not* work from `xcodebuild` on this machine —
   see the signing note above.

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
