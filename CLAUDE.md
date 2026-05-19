# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

intelligence-sync is the sync **engine**: a zero-dependency bash + awk pipeline that transforms tool-agnostic markdown (`intelligence/rules/`, `agents/`, `skills/`) into the native format each AI coding tool reads (Claude Code, Cursor, GitHub Copilot, OpenAI Codex, `AGENTS.md`). This repo *is* the upstream that downstream projects copy and pull updates from — it also dogfoods itself (the `intelligence-*` meta-skills under `intelligence/sync/skills/` are authored here).

**Modular layout (0.3.1+).** Everything upstream-owned lives in the self-contained module `intelligence/sync/` (`scripts/`, `skills/intelligence-*`, `INIT.md`, vendored `docs/`, `scripts/VERSION`). The umbrella folder (`intelligence/`) holds only `config.yaml` + project content (`rules/ agents/ skills/<project>/`) and is **never hardcoded** — code derives it as "the dir holding config.yaml" (`detect_layout` in `lib/layout.sh`). Future modules (e.g. `brain/`) sit beside `sync/`, each updated independently. The repo also keeps a **bridge** copy at the legacy flat paths (`intelligence/scripts/`, `intelligence/INIT.md`, `intelligence/skills/intelligence-*`) so pre-0.3.1 clients can still self-update; CI asserts bridge == canonical. Bridge is removed in 0.4.0. When editing engine/skills/INIT/docs, edit the canonical `intelligence/sync/` (and repo-root `docs/`) copy — the bridge + `sync/docs/` are regenerated from it.

## Commands

```bash
# Run the full sync against this repo's config (intelligence/config.yaml — note:
# this upstream repo ships no config.yaml; sync runs in downstream projects)
bash intelligence/sync/scripts/sync.sh

# Sync / test a single adapter (the only practical "single test" — no unit harness)
bash intelligence/sync/scripts/sync.sh claude
REPO_ROOT=/path/to/test/project bash intelligence/sync/scripts/sync.sh cursor

# Lint shell (matches CI; template is intentionally excluded — `<name>` breaks the parser)
find intelligence/sync/scripts -name '*.sh' -not -path '*/adapters/_template.sh' \
  -print0 | xargs -0 shellcheck --severity=warning

# Self-update engine from upstream (clones to mktemp, diffs, prompts; --yes skips)
bash intelligence/sync/scripts/update.sh
```

There is no build step and no test framework. Correctness is verified by the CI **smoke job** (`.github/workflows/ci.yml`): it stages each `examples/*/config.yaml` as a throwaway project, runs sync, and greps the generated outputs. Reproduce a failure locally by replicating those steps against `examples/<name>/`.

## Architecture

`sync.sh` (entry point) → `lib/common.sh` (shared helpers) → `adapters/<name>.sh` (one per target tool). Flow:

1. Resolve `REPO_ROOT` (git toplevel, normalized via `cd && pwd` so Git Bash `D:/` vs `/d/` styles match) and `config.yaml`.
2. Enforce the **agents invariant**: if `cursor`/`copilot`/`codex` is enabled, `agents` must also be enabled — those tools get always-on rules *only* via `AGENTS.md` (skipped in their own channels to avoid duplication). Skipped when a single target is requested via `$1`.
3. `lint_frontmatter` every source file (warns on unquoted colons / leading tabs — strict YAML consumers like Codex CLI reject these).
4. For each enabled adapter: resolve output dir, run `validate_output_path` (refuses paths that resolve to repo root, the intelligence source tree, or any configured source — adapters `rm -rf` their output, so a misconfigured path would destroy work; `agents` is exempt as it writes a single file), then `source` the adapter and call `sync_to_<name>()`.
5. Post-sync: `warn_unsynced` (flags `rules/`/`agents/`/`skills/` dirs not in config) and `report_model_drift` (config `models:` override differs from current hardcoded default).

**The central design decision — rule routing, not flagging:** always-on rules (no `paths:`) are inlined *once* into `AGENTS.md`, which Cursor/Copilot/Codex read natively, so their adapters skip always-on rules entirely (no duplicated context burning the window). Path-scoped rules stay in per-IDE channels with native scoping (`.cursor/rules/*.mdc` `globs:`, `.github/instructions/*.instructions.md` `applyTo:`) so monorepo glob targeting works. Claude Code does not read `AGENTS.md`, so `claude.sh` receives the *full* rule set. Understanding this requires reading `agents.sh`, `claude.sh`, and the routing tables in `docs/CONVENTIONS.md` together.

**Adapter contract:** each adapter is one file defining `sync_to_<name>(repo_root, config_file, output_dir)`, discovered by filename (`_template.sh` excluded). The tool-agnostic source vocabulary — `tier: heavy|standard|light`, `access: full|readonly` — is mapped per-tool inside adapters via `lib/common.sh` helpers (`get_model`, `map_access_to_claude_tools`, etc.). Model defaults live in `get_model_default()`; bumping them is intentionally surfaced downstream via the drift report. See `docs/ADAPTERS.md`.

**Migration engine:** `lib/layout.sh` (`detect_layout` → `LS_LAYOUT`/`LS_UMBRELLA_DIR`/`LS_MODULE_DIR`/`LS_CONFIG_FILE`) and `lib/migrations.sh` (`MIGRATIONS=(...)` registry + `run_migrations` dispatcher + version-named `migrate_to_<v>`). Each `migrate_to_*` is self-guarding and idempotent (silent no-op once applied), runs in version order, and uses **copy → verify sentinel → only then delete legacy** so a crash never destroys the engine. `migrate_to_0_3_1` relocates pre-0.3.1 flat layout into `sync/`, moving (never duplicating) meta-skills and adding one idempotent line to `config.yaml` `sources.skills`. `sync.sh` runs it offline (relocate local files) and re-execs from the module so it never deletes its own running dir; `update.sh` runs it with the fresh upstream clone as authoritative source. Applied version is stamped at `<umbrella>/sync/.intelligence-sync-version`.

## Conventions for engine code

- **Zero dependencies beyond bash + awk.** `mktemp`/`find`/`cp` are POSIX-OK. No `jq`, no Python, no gawk extensions — awk must be **POSIX** (no 3-arg `match()`; see the inline-vs-block parsing in `get_target_field`).
- **Never duplicate parsing logic.** All frontmatter extraction, YAML reading, and model resolution go through `lib/common.sh`. Adding a parser elsewhere is the main thing to push back on.
- **Cross-platform awk hygiene.** Every awk program strips `\r` (`sub(/\r$/, "")`) because source files may be CRLF on Windows. Frontmatter parsers are scoped to the first `--- ... ---` block so body content (e.g. a code sample mentioning `paths:`) is never miscounted.
- `set -euo pipefail` in every script. Shell scripts are forced to LF via `.gitattributes` (`*.sh text eol=lf`) — critical for bash on all platforms; do not let an editor reintroduce CRLF.
- Comments explain *why*, not *what*; skip them where names already carry intent.
- `intelligence/sync/scripts/` and `intelligence/sync/INIT.md` are the only files `update.sh` overwrites downstream — treat them as the public engine API. Project content (`config.yaml`, `rules/`, `agents/`, `skills/`) is never touched by updates.

## Authoring artifacts (skills/rules/agents in `intelligence/`)

When editing the `intelligence-*` skills or any rule/agent, follow `docs/CONVENTIONS.md`: rule = constraint the LLM respects (auto-loaded), skill = procedure the LLM performs (explicit `/name`), agent = persona the LLM adopts. Names are `<domain>-<verb>-<noun>`; `description` fields share a global token budget (keep short — 4–8 words if unique, ≤250 chars with a distinguishing trigger if there are siblings). Update `CHANGELOG.md` for user-facing changes.

## Commit messages

Capitalized, past tense, one sentence (e.g. `Added Codex adapter with AGENTS.md generation`) — matches existing history.
