# intelligence-sync: Writing a New Adapter

## Overview

An adapter transforms source prompts (from `intelligence/`) into an IDE-specific format. Each adapter is a single bash file in `intelligence/scripts/adapters/`.

## Quick Start

1. Copy `intelligence/scripts/adapters/_template.sh` to `intelligence/scripts/adapters/<name>.sh`
2. Replace `<name>` placeholders with your adapter name
3. Implement the `sync_to_<name>()` function
4. Add target to `config.yaml`:
   ```yaml
   targets:
     <name>: { enabled: true, output: ".<name>" }
   ```
5. Run `bash intelligence/scripts/sync.sh <name>` to test

## Adapter Contract

### Required Function

```bash
sync_to_<name>(repo_root, config_file, output_dir)
```

This is called by `sync.sh` for each enabled target.

Parameters:
- `repo_root` -- absolute path to the project root
- `config_file` -- absolute path to `config.yaml`
- `output_dir` -- absolute path to output directory (e.g., `/project/.cursor`)

### Available Library Functions

Source `lib/common.sh` for these utilities:

| Function | Description |
|----------|-------------|
| `normalize_file_to_lf(file)` | Convert CRLF to LF |
| `lint_frontmatter(file)` | Warn about unquoted colons / leading tabs (stderr) |
| `get_frontmatter_value(key, file)` | Extract YAML frontmatter value |
| `has_frontmatter(file)` | Check for `---` header |
| `has_paths(file)` | Check for `paths:` field |
| `get_model(config, ide, tier)` | Resolve model from `models:` override or default |
| `get_model_default(ide, tier)` | Hardcoded default for `<ide>:<tier>` |
| `map_access_to_claude_tools(access)` | Tool string for access level |
| `map_access_to_claude_disallowed(access)` | Disallowed tools string |
| `read_yaml_list(config, section)` | Read list from `config.yaml` |
| `get_target_field(config, target, field)` | Read a field from a target's config block |

### Transformation Patterns

Each adapter handles three prompt types. Here's how the built-in adapters approach each:

**Rules:**

intelligence-sync routes rule content based on **scope** (always-on vs path-scoped) and on which channels each IDE actually reads, to avoid duplicating content into multiple places.

| Source | `agents` (AGENTS.md) | `claude` | `cursor` | `copilot` | `codex` |
|--------|----------------------|----------|----------|-----------|---------|
| Always-on (no `paths:`) | inlined as canonical | copied as-is | skipped (Cursor reads AGENTS.md) | skipped (Copilot reads AGENTS.md) | skipped (Codex reads AGENTS.md) |
| Path-scoped (with `paths:`) | listed by name only | copied as-is | `paths:` → `globs:` in `.mdc` | `paths:` → `applyTo:` in `.instructions.md` | not supported by Codex |
| Listing | full table in AGENTS.md | n/a | n/a | n/a | n/a |

**Skills:**

Skills follow the [Agent Skills open standard](https://agentskills.io). All four IDEs read `SKILL.md` directly — no transformation needed.

| Pattern | Used by | Output location |
|---------|---------|-----------------|
| Copy SKILL.md dirs as-is | Claude, Cursor, Copilot, Codex | `.claude/skills/`, `.cursor/skills/`, `.github/skills/`, `.agents/skills/` |

**Agents:**

| Pattern | Used by |
|---------|---------|
| Transform frontmatter | Claude (`tier`→`model` via `get_model`, `access`→`tools`/`disallowedTools`), Cursor (`tier`→`model` via `get_model`, `access: readonly`→`readonly: true`) |
| Transform to `.agent.md` | Copilot (`tier`→`model`, `access: readonly`→restricted `tools` array) |
| Transform to `.toml` | Codex (`name`, `description`, `model`, `model_reasoning_effort` from tier, `sandbox_mode` from access, `developer_instructions`) |

Model names come from `get_model(config_file, ide, tier)` in `lib/common.sh`. Defaults are baked into `get_model_default()`; users override per-IDE/tier under `models:` in `config.yaml`. Sync prints a drift report when an override no longer matches the current default.

## Example: Minimal Adapter

```bash
#!/bin/bash
source "$(dirname "$0")/../lib/common.sh"

sync_to_myide() {
    local repo_root="$1"
    local config_file="$2"
    local output_dir="$3"

    echo "=== MyIDE ==="
    mkdir -p "$output_dir/rules"

    # Copy rules, strip frontmatter
    while IFS= read -r src; do
        [ -z "$src" ] && continue
        local dir="$repo_root/$src"
        [ -d "$dir" ] || continue
        for f in "$dir"/*.md; do
            [ -f "$f" ] || continue
            awk '
                BEGIN { in_fm=0; past_fm=0 }
                { sub(/\r$/, "") }
                /^---$/ {
                    if (!past_fm) { in_fm = !in_fm; if (!in_fm) { past_fm=1 }; next }
                }
                past_fm || !in_fm { print }
            ' "$f" > "$output_dir/rules/$(basename "$f")"
            normalize_file_to_lf "$output_dir/rules/$(basename "$f")"
        done
    done < <(read_yaml_list "$config_file" "rules")
}
```

## Testing

Test your adapter by creating a temporary project with `config.yaml` and running:

```bash
REPO_ROOT=/path/to/test/project bash intelligence/scripts/sync.sh <name>
```

Verify the output directory contains correctly transformed files. The sync entry point also runs `lint_frontmatter` over every source file before adapters fire — unquoted YAML colons and leading tabs surface as warnings on stderr.

## Distributing changes

When you ship a new adapter, downstream projects pick it up by running:

```bash
bash intelligence/scripts/update.sh
```

`update.sh` clones the upstream repo into a `mktemp -d` directory, shows the diff for `intelligence/scripts/` and `intelligence/INIT.md`, and prompts before overwriting. Project content (`config.yaml`, `rules/`, `agents/`, `skills/`) is never touched. Pass `--yes` for non-interactive runs; set `REPO_URL=<fork>` to use a fork.

## Built-in Adapters Reference

| Adapter | Output | Rules | Skills | Agents |
|---------|--------|-------|--------|--------|
| `agents.sh` | `AGENTS.md` (committed) | Always-on inlined; scoped listed | Listed in table | Listed in table |
| `claude.sh` | `.claude/` | Copy as-is (Claude does not read AGENTS.md) | SKILL.md dirs | tier/access → model/tools |
| `cursor.sh` | `.cursor/` | Scoped only → `.mdc` + globs | Copy as-is | tier → model |
| `copilot.sh` | `.github/` | Scoped only → `.instructions.md` | SKILL.md dirs | `.agent.md` |
| `codex.sh` | `.codex/` + `.agents/skills/` | None (AGENTS.md handles) | SKILL.md dirs in `.agents/skills/` | `.toml` in `.codex/agents/` |

### Notes on `agents.sh`

Unlike IDE adapters, `agents.sh` emits a single committed markdown file intended for humans and generic LLM tooling. It reads a static `header` block from `config.yaml` (under `targets.agents.header`) and appends auto-generated tables (agents, skills) and a list of rules derived from frontmatter. The output carries a "do not edit manually" marker and is regenerated on every sync.

#### Why AGENTS.md inlines always-on rules

AGENTS.md is the canonical project doc — Cursor, Copilot, and Codex read it natively. Always-on rule content is inlined automatically so all three tools see the same context from one source. Path-scoped rules are NOT inlined (would balloon AGENTS.md in monorepos); they live in tool-specific channels with native scoping (`.cursor/rules/*.mdc` with `globs:`, `.github/instructions/*.instructions.md` with `applyTo:`).

Claude Code does not read AGENTS.md natively (per [open feature request](https://github.com/anthropics/claude-code/issues/6235)) — its adapter copies all rules into `.claude/rules/`. There is no duplication because Claude does not consume AGENTS.md.
