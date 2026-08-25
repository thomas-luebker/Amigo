#!/usr/bin/python3
# System python on purpose: it has the CA trust store, and the ASC monitor
# this borrows make_token() from runs under it too. The python.org build
# fails ASC with CERTIFICATE_VERIFY_FAILED.
"""Push a release's What's New and promotional text to App Store Connect.

Reads the texts out of docs/APPSTORE.md so there is one copy of them, not
two: the file the release is drafted and reviewed in is the file that gets
pushed. Run it with no arguments for a dry run that prints exactly what
would go up, and --push when the build is attached and you mean it.

    scripts/asc-push-metadata.py 0.7.6            # dry run
    scripts/asc-push-metadata.py 0.7.6 --push

Two things learned the hard way and encoded here:

  * A localization can only be created while the version is in
    PREPARE_FOR_SUBMISSION. POSTing one against a version already
    submitted returns 409 ENTITY_ERROR.RELATIONSHIP.INVALID. So de-DE has
    to exist before you submit, not after.
  * Always read back. The 0.7.5 keyword edit went up half-applied and
    nobody noticed until a later read-back — so this prints the stored
    value after writing, and compares.

Credentials come from ~/.asc-monitor (the same key the monitor uses).
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path.home() / ".asc-monitor"))
from asc_monitor import make_token  # noqa: E402  (shared JWT signing)

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "de.amiga-imager.uae"
LOCALES = ("en-US", "de-DE")
APPSTORE_MD = Path(__file__).resolve().parent.parent / "docs" / "APPSTORE.md"


def request(method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + token)
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise SystemExit("%s %s -> HTTP %d\n%s" % (method, url, e.code, detail))


def parse_release_notes(version):
    """Pull the drafted texts for one version out of docs/APPSTORE.md.

    The block is recognisable rather than structured: a heading naming the
    version, then per-locale markers, then indented lines. Bullets are
    joined with newlines the way ASC stores them.
    """
    text = APPSTORE_MD.read_text(encoding="utf-8")
    start = text.find("## %s " % version)
    if start < 0:
        raise SystemExit("no '## %s' section in %s" % (version, APPSTORE_MD))
    end = text.find("\n## ", start + 1)
    block = text[start:end if end > 0 else len(text)]

    out = {}
    for locale in LOCALES:
        notes = re.search(
            r"%s What's New[^\n]*\n\n((?:    .*\n|\n)+)" % re.escape(locale), block)
        # en-US's marker carries no locale prefix ("Promotional text,
        # draft:"); de-DE's does. Accept either rather than silently
        # pushing notes with no promotional text.
        promo = re.search(
            r"%s promotional text[^\n]*\n\n((?:    .*\n|\n)+)" % re.escape(locale),
            block, re.IGNORECASE)
        if not promo and locale == "en-US":
            promo = re.search(
                r"\nPromotional text[^\n]*\n\n((?:    .*\n|\n)+)", block, re.IGNORECASE)
        if not notes:
            continue
        bullets = [l.strip() for l in notes.group(1).split("\n")
                   if l.strip().startswith("•")]
        entry = {"whatsNew": "\n".join(bullets)}
        if promo:
            lines = [l.strip() for l in promo.group(1).split("\n") if l.strip()]
            if lines:
                entry["promotionalText"] = " ".join(lines)
        out[locale] = entry
    return out


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    version = sys.argv[1]
    push = "--push" in sys.argv

    drafts = parse_release_notes(version)
    if not drafts:
        raise SystemExit("found no locale drafts for %s" % version)

    for locale, d in drafts.items():
        print("== %s ==" % locale)
        print("  What's New: %d chars, %d bullets"
              % (len(d["whatsNew"]), d["whatsNew"].count("•")))
        if len(d["whatsNew"]) > 4000:
            raise SystemExit("  What's New exceeds the 4000-char limit")
        if "promotionalText" in d:
            n = len(d["promotionalText"])
            print("  Promotional: %d chars%s" % (n, "  OVER 170!" if n > 170 else ""))
            if n > 170:
                raise SystemExit("  promotional text exceeds the 170-char limit")

    token = make_token()
    apps = request("GET", "%s/apps?filter[bundleId]=%s" % (API, BUNDLE_ID), token)
    if not apps.get("data"):
        raise SystemExit("app %s not found" % BUNDLE_ID)
    app_id = apps["data"][0]["id"]
    print("\napp %s (%s)" % (apps["data"][0]["attributes"]["name"], app_id))

    versions = request(
        "GET", "%s/apps/%s/appStoreVersions?limit=10" % (API, app_id), token)
    target = None
    for v in versions.get("data", []):
        a = v["attributes"]
        mark = "  <- target" if a["versionString"] == version else ""
        print("  %-8s %-28s %s%s"
              % (a["versionString"], a["appStoreState"], v["id"], mark))
        if a["versionString"] == version:
            target = v
    if target is None:
        raise SystemExit(
            "\nNo %s version record exists yet. Create it in ASC (or upload the\n"
            "build and let ASC create it) BEFORE pushing metadata — de-DE cannot\n"
            "be added once the version has been submitted." % version)

    state = target["attributes"]["appStoreState"]
    if state != "PREPARE_FOR_SUBMISSION":
        print("\n!! version is %s, not PREPARE_FOR_SUBMISSION." % state)
        print("   Creating a missing localization will fail with 409 in this state.")

    locs = request("GET", "%s/appStoreVersions/%s/appStoreVersionLocalizations"
                   % (API, target["id"]), token)
    existing = {l["attributes"]["locale"]: l for l in locs.get("data", [])}
    print("\nlocalizations present: %s" % ", ".join(sorted(existing)) or "none")

    if not push:
        print("\nDRY RUN — nothing sent. Re-run with --push when the build is up.")
        for locale, d in drafts.items():
            print("\n--- %s whatsNew ---\n%s" % (locale, d["whatsNew"]))
            if "promotionalText" in d:
                print("--- %s promotionalText ---\n%s" % (locale, d["promotionalText"]))
        return

    for locale, d in drafts.items():
        attrs = dict(d)
        if locale in existing:
            request("PATCH", "%s/appStoreVersionLocalizations/%s"
                    % (API, existing[locale]["id"]), token,
                    {"data": {"type": "appStoreVersionLocalizations",
                              "id": existing[locale]["id"], "attributes": attrs}})
            print("patched %s" % locale)
        else:
            attrs["locale"] = locale
            request("POST", "%s/appStoreVersionLocalizations" % API, token,
                    {"data": {"type": "appStoreVersionLocalizations",
                              "attributes": attrs,
                              "relationships": {"appStoreVersion": {
                                  "data": {"type": "appStoreVersions",
                                           "id": target["id"]}}}}})
            print("created %s" % locale)

    time.sleep(2)
    print("\n== read-back ==")
    locs = request("GET", "%s/appStoreVersions/%s/appStoreVersionLocalizations"
                   % (API, target["id"]), token)
    for l in locs.get("data", []):
        loc = l["attributes"]["locale"]
        if loc not in drafts:
            continue
        stored_new = l["attributes"].get("whatsNew") or ""
        stored_promo = l["attributes"].get("promotionalText") or ""
        want = drafts[loc]
        ok_new = stored_new.strip() == want["whatsNew"].strip()
        print("  %s whatsNew %s (%d chars stored)"
              % (loc, "MATCHES" if ok_new else "DIFFERS", len(stored_new)))
        if "promotionalText" in want:
            ok_p = stored_promo.strip() == want["promotionalText"].strip()
            print("  %s promotionalText %s (%d chars stored)"
                  % (loc, "MATCHES" if ok_p else "DIFFERS", len(stored_promo)))


if __name__ == "__main__":
    main()
