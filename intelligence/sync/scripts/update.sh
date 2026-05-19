#!/bin/bash
# intelligence-sync: self-update
# Pulls the latest upstream-owned content into the local vendored module:
#   <umbrella>/sync/scripts/            sync engine + adapters
#   <umbrella>/sync/INIT.md             bootstrap prompt
#   <umbrella>/sync/skills/intelligence-*  meta-skills (by reserved prefix)
#   <umbrella>/sync/docs/               vendored docs
# Project content (config.yaml, rules/, agents/, non-meta skills/) is never
# touched — except an idempotent additive line in config.yaml sources.skills
# when migrating a pre-0.3.1 flat project.
#
# The umbrella folder name is not hardcoded (intelligence/, Intelligence/, …).
# Pre-0.3.1 projects laid the engine out flat under the umbrella; this script
# transparently migrates them into the <umbrella>/sync/ module.
#
# Usage:
#   bash <umbrella>/sync/scripts/update.sh            # interactive
#   bash <umbrella>/sync/scripts/update.sh --yes      # apply without prompt
#   REPO_URL=<url> bash .../update.sh                 # custom upstream
#
# Cross-platform: uses `mktemp -d` (Linux/macOS/Windows Git Bash).
# Honors $TMPDIR / $TMP / $TEMP — never hardcodes /tmp.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/ainova-systems/intelligence-sync.git}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_NAME="sync"
AUTO_YES=0
[ "${1:-}" = "--yes" ] && AUTO_YES=1

source "$SCRIPT_DIR/lib/layout.sh"
source "$SCRIPT_DIR/lib/migrations.sh"

detect_layout "$SCRIPT_DIR"
UMBRELLA="$LS_UMBRELLA_DIR"
MODULE_DIR="$UMBRELLA/$MODULE_NAME"

WORK_DIR=$(mktemp -d -t intelligence-sync-update-XXXXXX 2>/dev/null || mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT INT TERM

echo "=== intelligence-sync: self-update ==="
echo "  Upstream:    $REPO_URL"
echo "  Umbrella:    $UMBRELLA  (layout: $LS_LAYOUT)"
echo "  Module:      $MODULE_DIR"
echo "  Work dir:    $WORK_DIR"
echo ""

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is required."
    exit 1
fi

echo "  Cloning latest..."
git clone --depth=1 --quiet "$REPO_URL" "$WORK_DIR"

# Normalize the upstream into a single module-shaped staging dir so the rest
# of this script is layout-agnostic. Accept either upstream shape:
#   modular: $WORK_DIR/intelligence/sync/{scripts,INIT.md,docs,skills}
#   legacy : $WORK_DIR/intelligence/{scripts,INIT.md,skills} + $WORK_DIR/docs
UPMOD="$WORK_DIR/_module"
mkdir -p "$UPMOD/skills"
if [ -d "$WORK_DIR/intelligence/$MODULE_NAME/scripts" ]; then
    _SRC="$WORK_DIR/intelligence/$MODULE_NAME"
    cp -r "$_SRC/scripts" "$UPMOD/scripts"
    [ -f "$_SRC/INIT.md" ] && cp "$_SRC/INIT.md" "$UPMOD/INIT.md"
    [ -d "$_SRC/docs" ] && cp -r "$_SRC/docs" "$UPMOD/docs"
    for s in "$_SRC"/skills/intelligence-*; do
        [ -d "$s" ] && cp -r "$s" "$UPMOD/skills/"
    done
elif [ -d "$WORK_DIR/intelligence/scripts" ]; then
    cp -r "$WORK_DIR/intelligence/scripts" "$UPMOD/scripts"
    [ -f "$WORK_DIR/intelligence/INIT.md" ] && cp "$WORK_DIR/intelligence/INIT.md" "$UPMOD/INIT.md"
    [ -d "$WORK_DIR/docs" ] && cp -r "$WORK_DIR/docs" "$UPMOD/docs"
    for s in "$WORK_DIR/intelligence"/skills/intelligence-*; do
        [ -d "$s" ] && cp -r "$s" "$UPMOD/skills/"
    done
else
    echo "ERROR: upstream layout unrecognized — no intelligence/$MODULE_NAME/scripts/ or intelligence/scripts/."
    exit 1
fi

# Local module dir to diff against: the existing module, or (pre-migration)
# the flat legacy locations.
if [ -d "$MODULE_DIR/scripts" ]; then
    _LOCAL="$MODULE_DIR"
else
    _LOCAL="$UMBRELLA"   # legacy flat
fi

echo ""
echo "  Diff (scripts/):"
diff -ruN "$_LOCAL/scripts" "$UPMOD/scripts" || true
echo ""
echo "  Diff (INIT.md):"
diff -uN "$_LOCAL/INIT.md" "$UPMOD/INIT.md" 2>/dev/null || true
echo ""
echo "  Diff (meta-skills intelligence-*):"
for up in "$UPMOD"/skills/intelligence-*; do
    [ -d "$up" ] || continue
    name=$(basename "$up")
    diff -ruN "$_LOCAL/skills/$name" "$up" 2>/dev/null || true
done
if [ -d "$UPMOD/docs" ]; then
    echo ""
    echo "  Diff (docs/):"
    diff -ruN "$_LOCAL/docs" "$UPMOD/docs" 2>/dev/null || true
fi

if [ $AUTO_YES -ne 1 ]; then
    echo ""
    if [ "$LS_LAYOUT" = "legacy" ]; then
        echo "  NOTE: pre-0.3.1 flat layout — the engine will be MIGRATED into '$MODULE_NAME/'."
        echo "        Legacy scripts/, INIT.md, docs/, and intelligence-* skills move there;"
        echo "        a single additive line is added to config.yaml sources.skills."
    fi
    read -r -p "Apply update? Engine/INIT/meta-skills/docs overwritten; rules/agents/project skills NOT touched. [y/N] " confirm
    case "$confirm" in
        y|Y|yes|YES) ;;
        *) echo "  Cancelled."; exit 0 ;;
    esac
fi

# Migrate legacy → modular if needed (authoritative content from upstream).
# Idempotent: a no-op on already-modular projects.
run_migrations "$UMBRELLA" "$MODULE_NAME" "$UPMOD"

# In-place refresh of the module (covers already-modular projects, and
# re-asserts content post-migration). Idempotent.
mkdir -p "$MODULE_DIR/skills"
if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$UPMOD/scripts/" "$MODULE_DIR/scripts/"
else
    rm -rf "$MODULE_DIR/scripts"; cp -r "$UPMOD/scripts" "$MODULE_DIR/scripts"
fi
[ -f "$UPMOD/INIT.md" ] && cp "$UPMOD/INIT.md" "$MODULE_DIR/INIT.md"
if [ -d "$UPMOD/docs" ]; then
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$UPMOD/docs/" "$MODULE_DIR/docs/"
    else
        rm -rf "$MODULE_DIR/docs"; cp -r "$UPMOD/docs" "$MODULE_DIR/docs"
    fi
fi
for up in "$UPMOD"/skills/intelligence-*; do
    [ -d "$up" ] || continue
    name=$(basename "$up")
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$up/" "$MODULE_DIR/skills/$name/"
    else
        rm -rf "$MODULE_DIR/skills/$name"; cp -r "$up" "$MODULE_DIR/skills/$name"
    fi
done
# Prune local meta-skills no longer upstream (deprecated ones disappear; no
# duplicates, project skills untouched).
for local_skill in "$MODULE_DIR"/skills/intelligence-*; do
    [ -d "$local_skill" ] || continue
    name=$(basename "$local_skill")
    [ -d "$UPMOD/skills/$name" ] || { echo "  Removing meta-skill no longer upstream: $name"; rm -rf "$local_skill"; }
done

# Stamp the applied version (from upstream VERSION if present, else 0.3.1).
_ver="0.3.1"
[ -f "$UPMOD/scripts/VERSION" ] && _ver="$(tr -d ' \r\n' < "$UPMOD/scripts/VERSION")"
stamp_version "$MODULE_DIR" "$_ver"

find "$MODULE_DIR/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

echo ""
echo "  Updated:   $MODULE_NAME/scripts/, $MODULE_NAME/INIT.md, $MODULE_NAME/skills/intelligence-*, $MODULE_NAME/docs/  (version $_ver)"
echo "  Untouched: config.yaml (except idempotent sources.skills line on migration), rules/, agents/, project skills."
echo "  Next: bash $MODULE_NAME/scripts/sync.sh"
