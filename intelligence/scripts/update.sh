#!/bin/bash
# intelligence-sync: self-update
# Pulls the latest upstream-owned content into the local vendored copy:
#   - intelligence/scripts/
#   - intelligence/INIT.md
#   - intelligence/skills/intelligence-*  (meta-skills only, by prefix)
#   - docs/  (vendored as intelligence/docs/)
# Project content (config.yaml, rules/, agents/, non-meta skills/) is never touched.
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
UPSTREAM_DOCS="$WORK_DIR/docs"
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

echo ""
echo "  Diff (meta-skills intelligence-*):"
for upstream_skill in "$UPSTREAM_INTEL"/skills/intelligence-*; do
    [ -d "$upstream_skill" ] || continue
    skill_name=$(basename "$upstream_skill")
    diff -ruN "$INTELLIGENCE_DIR/skills/$skill_name" "$upstream_skill" || true
done

if [ -d "$UPSTREAM_DOCS" ]; then
    echo ""
    echo "  Diff (docs/):"
    diff -ruN "$INTELLIGENCE_DIR/docs" "$UPSTREAM_DOCS" || true
fi

if [ $AUTO_YES -ne 1 ]; then
    echo ""
    read -r -p "Apply update? scripts/, INIT.md, meta-skills (intelligence-*), and docs/ will be overwritten; config.yaml / rules / agents / project skills will NOT be touched. [y/N] " confirm
    case "$confirm" in
        y|Y|yes|YES) ;;
        *) echo "  Cancelled."; exit 0 ;;
    esac
fi

# Apply scripts/ (full sync)
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$UPSTREAM_INTEL/scripts/" "$INTELLIGENCE_DIR/scripts/"
else
    rm -rf "$INTELLIGENCE_DIR/scripts"
    cp -r "$UPSTREAM_INTEL/scripts" "$INTELLIGENCE_DIR/scripts"
fi

# Apply INIT.md
cp "$UPSTREAM_INTEL/INIT.md" "$INTELLIGENCE_DIR/INIT.md"

# Apply meta-skills (intelligence-* prefix only)
mkdir -p "$INTELLIGENCE_DIR/skills"
for upstream_skill in "$UPSTREAM_INTEL"/skills/intelligence-*; do
    [ -d "$upstream_skill" ] || continue
    skill_name=$(basename "$upstream_skill")
    target="$INTELLIGENCE_DIR/skills/$skill_name"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$upstream_skill/" "$target/"
    else
        rm -rf "$target"
        cp -r "$upstream_skill" "$target"
    fi
done

# Remove local meta-skills that no longer exist upstream
# (so deleted meta-skills disappear on update, while project skills remain untouched)
for local_skill in "$INTELLIGENCE_DIR"/skills/intelligence-*; do
    [ -d "$local_skill" ] || continue
    skill_name=$(basename "$local_skill")
    if [ ! -d "$UPSTREAM_INTEL/skills/$skill_name" ]; then
        echo "  Removing local meta-skill no longer in upstream: $skill_name"
        rm -rf "$local_skill"
    fi
done

# Apply docs/ if upstream has them — vendored as <intel>/docs/
if [ -d "$UPSTREAM_DOCS" ]; then
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$UPSTREAM_DOCS/" "$INTELLIGENCE_DIR/docs/"
    else
        rm -rf "$INTELLIGENCE_DIR/docs"
        cp -r "$UPSTREAM_DOCS" "$INTELLIGENCE_DIR/docs"
    fi
fi

# Normalize LF for shell scripts on Windows just in case
find "$INTELLIGENCE_DIR/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

echo ""
echo "  Updated:   scripts/, INIT.md, meta-skills (intelligence-*), docs/"
echo "  Untouched: config.yaml, rules/, agents/, project skills."
echo "  Next: bash intelligence/scripts/sync.sh"
