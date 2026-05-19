#!/bin/bash
# intelligence-sync: versioned migrations
# Source this file — never execute directly. Requires layout.sh already
# sourced (uses no globals from it directly; callers pass paths explicitly).
#
# Every migrate_to_<ver> is self-guarding and idempotent: it checks its own
# precondition and is a silent no-op when already applied, so the whole
# registry can be replayed any number of times without failing or producing
# duplicates. The dispatcher runs them in version order, so a project that
# fell several versions behind is brought forward step by step.
#
# Naming carries the target version (bash forbids dots → underscores):
#   migrate_to_0_3_1   flat <umbrella>/scripts → modular <umbrella>/sync/
# Future migrations are added to MIGRATIONS and as new migrate_to_* functions;
# nothing here is rewritten.

# Ordered list of migration suffixes. Append new ones; never reorder.
MIGRATIONS=( "0_3_1" )

_mig_stamp_file() { printf '%s/.intelligence-sync-version' "$1"; }

# stamp_version <module_dir> <version>
stamp_version() {
    [ -d "$1" ] || return 0
    printf '%s\n' "$2" > "$(_mig_stamp_file "$1")"
}

# Idempotent directory replace (rsync if present, else rm+cp).
_mig_copy_dir() {
    local src="$1" dst="$2"
    [ -d "$src" ] || return 0
    if command -v rsync >/dev/null 2>&1; then
        mkdir -p "$dst"
        rsync -a --delete "$src/" "$dst/"
    else
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
    fi
}

_mig_copy_file() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
}

# Idempotently add a skills source entry to config.yaml. No backup — the edit
# is a single additive list item and the relocated content is recoverable.
# Name-agnostic: caller passes the already-resolved "<base>/<module>/skills".
_mig_add_skill_source() {
    local config="$1" entry="$2"
    if [ ! -f "$config" ]; then
        echo "  [migrate] no config.yaml at $config — add this under sources.skills manually:" >&2
        echo "      - \"$entry\"" >&2
        return 0
    fi
    # Already present (quoted or bare) — nothing to do.
    if grep -Fq -- "\"$entry\"" "$config" || grep -Fq -- "- $entry" "$config"; then
        return 0
    fi

    local tmp="$config.mig.tmp"
    awk -v entry="$entry" '
        function flush() { if (in_sk && !done) { print "    - \"" entry "\""; done = 1 } }
        { sub(/\r$/, "") }
        # Top-level key: closes any open sources/skills tracking.
        /^[A-Za-z]/ {
            flush(); in_sk = 0
            in_src = ($0 ~ /^sources:[[:space:]]*$/) ? 1 : 0
            print; next
        }
        in_src && /^  skills:[[:space:]]*$/ { print; in_sk = 1; next }
        # Another 2-space sub-key (rules/agents) ends the skills block.
        in_src && /^  [A-Za-z]/ { flush(); in_sk = 0; print; next }
        in_sk && /^    -[[:space:]]/ { print; next }   # existing skills item
        in_sk && /^[[:space:]]*$/ { flush(); in_sk = 0; print; next }
        { print }
        END { flush() }
    ' "$config" > "$tmp" && mv "$tmp" "$config"
}

# --- migrate_to_0_3_1 -------------------------------------------------------
# Pre-0.3.1: engine + meta-skills + INIT.md + docs lived flat under the
# umbrella, mixed with project content. 0.3.1: they move into the self-
# contained module subfolder <umbrella>/<module>/. Project content
# (rules/, agents/, non-meta skills/, config.yaml) is never moved or deleted.
#
# Ownership of meta-skills is by the reserved `intelligence-` prefix. A
# project skill must not use that prefix (documented in CONVENTIONS.md).
#
# migrate_to_0_3_1 <umbrella_dir> <module_name> [<upstream_module_dir>]
#   upstream_module_dir set  → authoritative content source (update.sh)
#   upstream_module_dir empty → relocate local legacy files (sync.sh, offline)
migrate_to_0_3_1() {
    local umbrella="$1" module_name="$2" upstream="${3:-}"
    local module_dir="$umbrella/$module_name"
    local s

    # Precondition: any legacy upstream-owned artifact directly under the
    # umbrella. None ⇒ already modular or fresh ⇒ idempotent no-op.
    local has_legacy=0
    [ -d "$umbrella/scripts" ] && has_legacy=1
    [ -e "$umbrella/INIT.md" ] && has_legacy=1
    [ -d "$umbrella/docs" ] && has_legacy=1
    for s in "$umbrella"/skills/intelligence-*; do
        [ -e "$s" ] && { has_legacy=1; break; }
    done
    if [ "$has_legacy" -eq 0 ]; then
        [ -d "$module_dir" ] && [ ! -f "$(_mig_stamp_file "$module_dir")" ] \
            && stamp_version "$module_dir" "0.3.1"
        return 0
    fi

    echo "  [migrate 0.3.1] legacy flat layout detected — relocating engine into '$module_name/'"
    mkdir -p "$module_dir"

    if [ -n "$upstream" ] && [ -d "$upstream" ]; then
        # update.sh: copy authoritative content from the fresh upstream clone.
        _mig_copy_dir  "$upstream/scripts" "$module_dir/scripts"
        _mig_copy_file "$upstream/INIT.md" "$module_dir/INIT.md"
        _mig_copy_dir  "$upstream/docs"    "$module_dir/docs"
        mkdir -p "$module_dir/skills"
        for s in "$upstream"/skills/intelligence-*; do
            [ -d "$s" ] || continue
            _mig_copy_dir "$s" "$module_dir/skills/$(basename "$s")"
        done
    else
        # sync.sh (offline): relocate the local legacy files.
        _mig_copy_dir  "$umbrella/scripts" "$module_dir/scripts"
        _mig_copy_file "$umbrella/INIT.md" "$module_dir/INIT.md"
        _mig_copy_dir  "$umbrella/docs"    "$module_dir/docs"
        mkdir -p "$module_dir/skills"
        for s in "$umbrella"/skills/intelligence-*; do
            [ -d "$s" ] || continue
            _mig_copy_dir "$s" "$module_dir/skills/$(basename "$s")"
        done
    fi

    # Verify sentinel BEFORE any destructive cleanup. A half-populated module
    # must never trigger legacy deletion — that is the crash-safety gate.
    if [ ! -s "$module_dir/scripts/sync.sh" ] || [ ! -s "$module_dir/scripts/lib/common.sh" ]; then
        echo "  ERROR: migration aborted — '$module_name/scripts/' incomplete; legacy left intact." >&2
        return 1
    fi

    # Remove ONLY the legacy upstream-owned locations. Meta-skills / INIT /
    # docs are never the running process, so these always succeed → no
    # duplicate intelligence-* ever survives under <umbrella>/skills/.
    rm -f  "$umbrella/INIT.md"
    rm -rf "$umbrella/docs"
    for s in "$umbrella"/skills/intelligence-*; do
        [ -e "$s" ] && rm -rf "$s"
    done
    # The legacy scripts/ dir may host the *currently running* update.sh.
    # On Linux deleting an open script is fine; some Windows shells refuse
    # it. Try, and if it lingers print a one-line manual cleanup instead of
    # failing — the new location, config, and stamp are already correct, and
    # the next sync/update run removes the dead dir.
    rm -rf "$umbrella/scripts" 2>/dev/null || true
    if [ -d "$umbrella/scripts" ]; then
        echo "  NOTE: legacy '$umbrella/scripts' still present (likely in use)." >&2
        echo "        Remove it manually once this process exits:" >&2
        echo "          rm -rf \"$umbrella/scripts\"" >&2
    fi

    # config.yaml: name-agnostic relative path under the actual umbrella base.
    _mig_add_skill_source "$umbrella/config.yaml" "$(basename "$umbrella")/$module_name/skills"

    stamp_version "$module_dir" "0.3.1"
    echo "  [migrate 0.3.1] done — engine at '$module_name/', legacy removed, no duplicates"
}

# run_migrations <umbrella_dir> <module_name> [<upstream_module_dir>]
run_migrations() {
    local umbrella="$1" module_name="$2" upstream="${3:-}"
    local v
    for v in "${MIGRATIONS[@]}"; do
        "migrate_to_$v" "$umbrella" "$module_name" "$upstream"
    done
}
