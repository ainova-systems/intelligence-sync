#!/bin/bash
# intelligence-sync: self-update
# Pulls the latest intelligence/scripts/ and intelligence/INIT.md from upstream
# without touching project content (config.yaml, rules/, agents/, skills/).
#
# Usage:
#   bash intelligence/scripts/update.sh                     # interactive
#   bash intelligence/scripts/update.sh --yes               # apply without prompt
#   REPO_URL=<url> bash intelligence/scripts/update.sh      # custom upstream
#
# Cross-platform note: uses `mktemp -d` (works on Linux/macOS/Windows Git Bash).
# Honors $TMPDIR / $TMP / $TEMP — never hardcodes /tmp.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/ainova-systems/intelligence-sync.git}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INTELLIGENCE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTO_YES=0
[ "${1:-}" = "--yes" ] && AUTO_YES=1

WORK_DIR=$(mktemp -d -t intelligence-sync-update-XXXXXX 2>/dev/null || mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

echo "=== intelligence-sync: self-update ==="
echo "  Upstream:    $REPO_URL"
echo "  Local copy:  $INTELLIGENCE_DIR"
echo "  Work dir:    $WORK_DIR"
echo ""

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is required."
    exit 1
fi

echo "  Cloning latest..."
git clone --depth=1 --quiet "$REPO_URL" "$WORK_DIR"

UPSTREAM_INTEL="$WORK_DIR/intelligence"
if [ ! -d "$UPSTREAM_INTEL/scripts" ]; then
    echo "ERROR: upstream layout unexpected — no intelligence/scripts/ at $UPSTREAM_INTEL"
    exit 1
fi

# Show what would change. diff returns 1 when files differ (not an error).
echo ""
echo "  Diff (scripts/):"
diff -ruN "$INTELLIGENCE_DIR/scripts" "$UPSTREAM_INTEL/scripts" || true
echo ""
echo "  Diff (INIT.md):"
diff -uN "$INTELLIGENCE_DIR/INIT.md" "$UPSTREAM_INTEL/INIT.md" || true

if [ $AUTO_YES -ne 1 ]; then
    echo ""
    read -r -p "Apply update? scripts/ and INIT.md will be overwritten; config.yaml / rules / agents / skills will NOT be touched. [y/N] " confirm
    case "$confirm" in
        y|Y|yes|YES) ;;
        *) echo "  Cancelled."; exit 0 ;;
    esac
fi

# Apply: replace scripts/ contents and INIT.md. Preserve any user files
# the user dropped under scripts/ (not present upstream) by using rsync if
# available, otherwise overwrite cleanly.
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$UPSTREAM_INTEL/scripts/" "$INTELLIGENCE_DIR/scripts/"
else
    rm -rf "$INTELLIGENCE_DIR/scripts"
    cp -r "$UPSTREAM_INTEL/scripts" "$INTELLIGENCE_DIR/scripts"
fi
cp "$UPSTREAM_INTEL/INIT.md" "$INTELLIGENCE_DIR/INIT.md"

# Normalize LF for shell scripts on Windows just in case
find "$INTELLIGENCE_DIR/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

echo ""
echo "  Updated. Untouched: config.yaml, rules/, agents/, skills/."
echo "  Next: bash intelligence/scripts/sync.sh"
