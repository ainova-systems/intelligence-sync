#!/bin/bash
# intelligence-sync: Unified sync entry point
# Reads config.yaml from the umbrella folder and syncs to all enabled targets.
#
# Usage:
#   bash <umbrella>/sync/scripts/sync.sh           # Sync all enabled targets
#   bash <umbrella>/sync/scripts/sync.sh claude    # Sync only Claude
#   bash <umbrella>/sync/scripts/sync.sh cursor    # Sync only Cursor
#
# Layout-agnostic: detect_layout finds the umbrella (the dir holding
# config.yaml; name not hardcoded) and migrates a pre-0.3.1 flat layout into
# the <umbrella>/sync/ module. REPO_ROOT: auto-detected from git, or via env.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_NAME="sync"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/layout.sh"
source "$SCRIPT_DIR/lib/migrations.sh"

# Umbrella is whatever folder holds config.yaml — name not hardcoded.
detect_layout "$SCRIPT_DIR"
INTELLIGENCE_DIR="$LS_UMBRELLA_DIR"

# Legacy flat layout: stage the engine into the module subfolder and re-exec
# from there. The destructive legacy cleanup then never deletes the directory
# of the running process (some Windows shells lock open script files).
if [ "$LS_LAYOUT" = "legacy" ] && [ -z "${INTELLIGENCE_SYNC_REEXEC:-}" ] \
   && [ -d "$INTELLIGENCE_DIR/scripts" ]; then
    _mig_copy_dir "$INTELLIGENCE_DIR/scripts" "$INTELLIGENCE_DIR/$MODULE_NAME/scripts"
    if [ -s "$INTELLIGENCE_DIR/$MODULE_NAME/scripts/sync.sh" ]; then
        export INTELLIGENCE_SYNC_REEXEC=1
        exec bash "$INTELLIGENCE_DIR/$MODULE_NAME/scripts/sync.sh" "$@"
    fi
fi

# Apply pending migrations (offline: relocate local files). Idempotent —
# a fully migrated or fresh project is a silent no-op. On a state bash will
# not resolve (ahead-of-engine / incomplete), it emits IS_STATUS + a stable
# code and we exit so the intelligence-update skill can take over.
_mig_rc=0
run_migrations "$INTELLIGENCE_DIR" "$MODULE_NAME" "" || _mig_rc=$?
if [ "$_mig_rc" -ne 0 ]; then exit "$_mig_rc"; fi

# After migration the engine lives in the module subfolder; re-point at it
# (adapters are sourced lazily from SCRIPT_DIR further down).
if [ -d "$INTELLIGENCE_DIR/$MODULE_NAME/scripts" ]; then
    SCRIPT_DIR="$INTELLIGENCE_DIR/$MODULE_NAME/scripts"
fi

# Normalize REPO_ROOT to the same `cd && pwd` style as INTELLIGENCE_DIR so
# prefix-stripping in path comparisons works (Git Bash on Windows: git
# rev-parse returns `D:/...` while cd && pwd returns `/d/...`; the styles
# do not match without normalization).
REPO_ROOT_RAW="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || (cd "$INTELLIGENCE_DIR/.." && pwd))}"
REPO_ROOT="$(cd "$REPO_ROOT_RAW" && pwd)"
unset REPO_ROOT_RAW

# Config: explicit env > config.yaml in the umbrella folder
if [ -n "${CONFIG_FILE:-}" ]; then
    CONFIG_FILE="$CONFIG_FILE"
elif [ -f "$INTELLIGENCE_DIR/config.yaml" ]; then
    CONFIG_FILE="$INTELLIGENCE_DIR/config.yaml"
else
    CONFIG_FILE=""
fi

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
    is_status config-missing "umbrella=$INTELLIGENCE_DIR"
    echo "ERROR: Config file not found."
    echo "Looked for: config.yaml (in $INTELLIGENCE_DIR)"
    echo "Run INIT.md bootstrap or create config.yaml manually."
    exit "$IS_RC_CONFIG_MISSING"
fi

TARGET_FILTER="${1:-}"

echo "=== intelligence-sync ==="
echo "  Config: $CONFIG_FILE"
echo "  Root:   $REPO_ROOT"
echo ""

# Invariant: AGENTS.md is the canonical carrier of always-on rules for
# Cursor / Copilot / Codex (their adapters skip always-on rules to avoid
# duplication). If those targets are enabled, `agents` must also be enabled
# — otherwise always-on rules go nowhere for those tools.
# Skip the check when the user requested a single target via $TARGET_FILTER:
# they may be syncing only one IDE intentionally.
if [ -z "$TARGET_FILTER" ]; then
    agents_enabled=$(is_target_enabled "$CONFIG_FILE" "agents")
    if [ "$agents_enabled" != "1" ]; then
        for tool in cursor copilot codex; do
            if [ "$(is_target_enabled "$CONFIG_FILE" "$tool")" = "1" ]; then
                echo "ERROR: targets.$tool is enabled but targets.agents is not." >&2
                echo "  $tool relies on AGENTS.md to deliver always-on rules — without it," >&2
                echo "  always-on rules would be invisible to $tool." >&2
                echo "  Either enable targets.agents in $CONFIG_FILE, or disable targets.$tool." >&2
                exit 1
            fi
        done
    fi
fi

# Lint frontmatter across all source files (rules, agents, skills).
# Catches issues like unquoted colons that strict YAML consumers reject.
for section in rules agents skills; do
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        src_dir="$REPO_ROOT/$src"
        [ -d "$src_dir" ] || continue
        if [ "$section" = "skills" ]; then
            while IFS= read -r f; do
                [ -n "$f" ] && lint_frontmatter "$f"
            done < <(find "$src_dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null)
        else
            for f in "$src_dir"/*.md; do
                [ -f "$f" ] && lint_frontmatter "$f"
            done
        fi
    done < <(read_yaml_list "$CONFIG_FILE" "$section")
done

# Available adapters (filename without .sh, excluding _template)
ADAPTERS=()
for adapter_file in "$SCRIPT_DIR/adapters"/*.sh; do
    [ -f "$adapter_file" ] || continue
    adapter_name="$(basename "$adapter_file" .sh)"
    [ "$adapter_name" = "_template" ] && continue
    ADAPTERS+=("$adapter_name")
done

synced=0

for adapter in "${ADAPTERS[@]}"; do
    # Skip if user requested specific target and this isn't it
    if [ -n "$TARGET_FILTER" ] && [ "$adapter" != "$TARGET_FILTER" ]; then
        continue
    fi

    # Check if target is enabled in config
    enabled=$(is_target_enabled "$CONFIG_FILE" "$adapter")
    if [ "$enabled" != "1" ] && [ -z "$TARGET_FILTER" ]; then
        continue
    fi

    # Get output directory
    output=$(get_target_output "$CONFIG_FILE" "$adapter")
    if [ -z "$output" ]; then
        output=".$adapter"
    fi
    output_dir="$REPO_ROOT/$output"

    # Refuse to run if output would clobber repo content (e.g. config.yaml
    # accidentally sets `output: "."` or `output: "intelligence"`). The
    # `agents` adapter writes a single file (AGENTS.md) and is exempt.
    if [ "$adapter" != "agents" ]; then
        validate_output_path "$REPO_ROOT" "$CONFIG_FILE" "$adapter" "$output_dir"
    fi

    # Source adapter and run.
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/adapters/$adapter.sh"
    "sync_to_$adapter" "$REPO_ROOT" "$CONFIG_FILE" "$output_dir"
    echo ""
    synced=$((synced + 1))
done

if [ $synced -eq 0 ]; then
    if [ -n "$TARGET_FILTER" ]; then
        echo "ERROR: Adapter '$TARGET_FILTER' not found."
        echo "Available: ${ADAPTERS[*]}"
    else
        echo "WARNING: No targets enabled in $CONFIG_FILE"
    fi
    exit 1
fi

# Warn about unsynced directories
warn_unsynced "$REPO_ROOT" "$CONFIG_FILE"

# Report model overrides that drift from intelligence-sync defaults
# (helpful when defaults move forward — e.g., gpt-5.5 -> gpt-5.6).
report_model_drift "$CONFIG_FILE"

echo ""
if [ "${IS_MIGRATED:-0}" -eq 1 ]; then
    is_status migrated "synced=$synced"
else
    is_status ok "synced=$synced"
fi
echo "=== Done: $synced target(s) synced ==="
