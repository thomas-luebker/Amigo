#!/bin/bash
# Apply Amigo's upstream patches to the vendor/WinUAE submodule working tree.
# Idempotent: skips patches that are already applied.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for p in "$ROOT"/patches/*.patch; do
    # sdl3-*.patch target an SDL source checkout, not this submodule —
    # SDL3 is vendored as a prebuilt xcframework (rebuild with
    # scripts/build-sdl3.sh against a patched SDL tree). Applying them
    # here always fails and used to abort the whole script, which broke
    # the documented build-from-clean-clone flow.
    case "$(basename "$p")" in
        sdl3-*) echo "skipped (not a WinUAE patch): $(basename "$p")"; continue ;;
    esac
    if git -C "$ROOT/vendor/WinUAE" apply --check "$p" 2>/dev/null; then
        git -C "$ROOT/vendor/WinUAE" apply "$p"
        echo "applied: $(basename "$p")"
    elif git -C "$ROOT/vendor/WinUAE" apply --reverse --check "$p" 2>/dev/null; then
        echo "already applied: $(basename "$p")"
    else
        echo "CONFLICT: $(basename "$p") no longer applies — rebase it against upstream" >&2
        exit 1
    fi
done
