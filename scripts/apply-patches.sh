#!/bin/bash
# Apply Amigo's upstream patches to the vendor/WinUAE submodule working tree.
# Idempotent: skips patches that are already applied.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for p in "$ROOT"/patches/*.patch; do
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
