# Changelog

All notable changes to intelligence-sync are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Upgrading** — paste this to your AI agent:

```
Update intelligence-sync: fetch the latest engine from https://github.com/ainova-systems/intelligence-sync and run its update flow to migrate this project to the newest version. Leave my rules, agents, and project skills untouched. If it fails, read the CHANGELOG "### Breaking" entries between my version and the latest, base your fix plan on them, make sure you are running the latest scripts, and retry; ask me only if it still fails.
```

## [Unreleased]

### Added

- Pi adapter (`pi.sh`) — reuses `AGENTS.md` for always-on rules, copies skills into the shared Agent Skills open-standard location (`.agents/skills/`), generates `.pi/prompts/intelligence-agent-*.md` prompt templates from source agents, and emits a small Pi extension (`.pi/extensions/intelligence-sync-rules.ts`) plus `.pi/intelligence-sync/rules/*.md` for path-scoped rules. This keeps Pi support additive and non-conflicting with existing Cursor/Copilot/Codex routing.
- `sync_open_skill_dirs()` shared helper in `lib/common.sh` so Codex and Pi can write the same strict-YAML-safe skill copy without duplicating logic. The helper now owns the full lifecycle of its destination (clean per-skill subdirs + `mkdir -p` + populate), so adapters writing to a shared open-standard dir stay symmetric and future adapters cannot drift on cleanup semantics.
- `sync.sh` AGENTS.md invariant extended to Pi — enabling `targets.pi` now also requires `targets.agents`, because Pi receives always-on project rules via `AGENTS.md`. The invariant loop carries an explicit "add new adapters here" comment for future contributors.
- `docs/ADAPTERS.md` "Cleanup Contract" section codifying the three rules every adapter follows: clean only owned subpaths, use shared helpers for shared dirs, declare owned paths in `.gitignore`.
- Docs and INIT guidance for Pi as an optional adapter, including project-safe `.gitignore` patterns that ignore only adapter-owned `.pi/` outputs while preserving `.pi/settings.json` and hand-authored Pi resources.

## [0.3.2] — 2026-05-22

### Fixed

- `copy_md_with_quoted_frontmatter` (strict-YAML adapters — Codex `.agents/skills/`) — when wrapping an **unquoted** `description` / `argument-hint` value in double quotes, literal inner `"` (and `\`) are now escaped (`\"`, `\\`). Previously a value such as `Use as a quick "what do we have" view` was wrapped verbatim into `description: "… "what do we have" …"`, which strict YAML parsers reject (`did not find expected key`) — Codex CLI silently skipped the skill at load. Claude's adapter was unaffected (it copies skills verbatim). `lint_frontmatter` now also flags literal double quotes inside unquoted free-text values, and the YAML-safety guidance (`INIT.md`, `intelligence-add-skill`, `intelligence-add-agent`) documents escaping / single-quoting such values.

## [0.3.1] — 2026-05-19

### Changed

- Engine, meta-skills, `INIT.md`, and docs moved into one self-contained module `<umbrella>/sync/`. Project content stays at the umbrella level.
- Versioned migration chain with a `sync_version` key in `config.yaml`; `sync.sh` only syncs, `update.sh` migrates. See `docs/CONVENTIONS.md`.

## [0.2.1] — 2026-05-14

### Fixed

- `intelligence-extract-skill` and `intelligence-review-skills` — quoted `argument-hint` values containing literal colons (`[target: skill|rule|agent]`, `[target: rules|skills|agents|all]`). Unquoted, strict YAML parsers (Codex CLI) interpreted the inner colon as a nested mapping and rejected the skill at load time. Brings both files in line with the project's own YAML-safety rule.

## [0.2.0] — 2026-05-13

### Added

- Three new pre-installed skills:
  - `/intelligence-extract-skill` — extract an observed session workflow into a reusable skill, rule, or agent.
  - `/intelligence-learn-from-context` — capture session lessons and apply them to `intelligence/` after approval; two-phase analyze → apply flow with negative-to-positive translation.
  - `/intelligence-review-skills` — audit `intelligence/` for duplicates, stale artifacts, size violations, and discipline issues; uses git history when available.
- `docs/CONVENTIONS.md`:
  - `Choosing artifact type` section — decision matrix and rule of thumb for rule vs skill vs agent, plus common mistakes to avoid.
  - `Authoring Discipline` section — description sizing (unique vs sibling cases, 250-char cap), size budgets per artifact type (SKILL.md target <500, cap 1000), writing principles (imperative form, positive defaults, explain why, lean prompts, ALL-CAPS only for true invariants).

### Changed

- Rule body template reordered to lead with positive defaults: `REQUIRED → Invariants → Architecture → Build & Test → Examples → Patterns to recognize and replace` (was `FORBIDDEN → REQUIRED → Architecture → Build & Test → Examples`). Anti-patterns now sit at the end as reference documentation rather than as LLM-facing instructions.
- `intelligence-add-rule`, `intelligence-add-skill`, `intelligence-add-agent` step instructions rewritten in positive framing ("Reuse the existing domain when one fits" instead of "Do not invent new domains").
- `intelligence/INIT.md` — Phase 3.3 component-rule template and Rule-body reference reordered to positive-first.
- `update.sh` — expanded default scope to pull meta-skills (`intelligence/skills/intelligence-*`) and `docs/` from upstream, alongside existing `scripts/` and `INIT.md`. Project content (`config.yaml`, `rules/`, `agents/`, non-meta skills) remains untouched. Local meta-skills no longer present upstream are removed on update.
- `intelligence-update` SKILL.md — updated to document the expanded scope.

## [0.1.1] — 2026-05-07

### Changed

- Shortened skill descriptions to fit Claude Code listing budget and prevent truncation.
- Enforced YAML quoting in Codex adapter.

## [0.1.0] — Initial release

First public release.

### Engine

- Single-source-of-truth design: author rules / agents / skills once under `intelligence/`; the sync engine routes content into each IDE's native format.
- Five built-in adapters: `agents` (AGENTS.md), `claude` (`.claude/`), `cursor` (`.cursor/`), `copilot` (`.github/`), `codex` (`.agents/skills/` + `.codex/agents/`).
- Pluggable adapter contract — drop a `<name>.sh` into `intelligence/scripts/adapters/` and it becomes available as a target.
- Zero runtime dependencies beyond `bash` and `awk`.

### Routing

- AGENTS.md is the canonical project doc — Cursor, Copilot, and Codex all read it natively. Always-on rules (no `paths:`) are inlined here once.
- Path-scoped rules stay in tool-specific channels (`.cursor/rules/*.mdc` with `globs:`, `.github/instructions/*.instructions.md` with `applyTo:`) so monorepo glob targeting still works.
- Claude Code receives the full rule set in `.claude/rules/` because it does not read AGENTS.md natively.
- No duplication between AGENTS.md and IDE rule directories.

### Helpers

- `lint_frontmatter` warns on unquoted YAML colons and leading tabs in frontmatter — runs automatically before adapters fire (catches issues that strict consumers like Codex CLI reject silently).
- `get_model` resolves model names from `config.yaml` `models:` overrides, falling back to bundled defaults. Sync prints a drift report when an override no longer matches the current default.
- `update.sh` self-update — clones upstream into a `mktemp -d` directory, shows a diff, and replaces only `intelligence/scripts/` and `intelligence/INIT.md`. Project content (`config.yaml`, `rules/`, `agents/`, `skills/`) is never touched.

### Pre-installed skills

- `/intelligence-sync` — run sync
- `/intelligence-update` — pull latest engine
- `/intelligence-install-adapter` — enable an IDE target
- `/intelligence-uninstall-adapter` — disable and clean up an IDE target
- `/intelligence-add-rule` — create a rule with conventions
- `/intelligence-add-agent` — create an agent with conventions
- `/intelligence-add-skill` — create a skill with conventions

### Examples

- `examples/go-api/` — single-component Go service.
- `examples/dotnet-api-with-react-frontend/` — multi-component project, shared intelligence at root + per-component sources.
- `examples/platform-with-submodules/` — monorepo with git submodules excluded from parent sync.

### Documentation

- `README.md` — problem / why / how positioning.
- `intelligence/INIT.md` — bootstrap prompt for AI assistants (4 phases: discovery, recommendation, generation, verification).
- `docs/CONVENTIONS.md` — frontmatter formats, naming, sync transformations.
- `docs/ADAPTERS.md` — adapter contract, library function reference, distribution via `update.sh`.
- `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue / PR templates.
