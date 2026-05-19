# Changelog

All notable changes to intelligence-sync are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] — 2026-05-19

### Changed

- **Modular layout.** The engine, meta-skills, `INIT.md`, and vendored docs now live in a self-contained module subfolder `<umbrella>/sync/` instead of flat under the umbrella, mixed with project content. This makes room for additional independently-updatable intelligence modules (e.g. `brain/`) alongside `sync/`. The umbrella folder name is never hardcoded — it is whatever holds `config.yaml`.
- `sync.sh` / `update.sh` — split path detection into `lib/layout.sh` (`detect_layout`, name-agnostic) and migrations into `lib/migrations.sh` (versioned registry + dispatcher). `sync.sh` re-execs from the module after staging so destructive cleanup never deletes the running process's directory.
- `update.sh` — accepts either upstream shape (modular `intelligence/sync/` or legacy `intelligence/scripts/`) via a normalized staging dir; prunes deprecated meta-skills; stamps the applied version.

### Added

- **Secure migration** `migrate_to_0_3_1` (pre-0.3.1 flat → `<umbrella>/sync/`): copy → verify sentinel → only then delete legacy; meta-skills are moved, never duplicated; an idempotent additive line is added to `config.yaml` `sources.skills`; the run is idempotent (replaying never fails or duplicates). Version-named so future migrations chain in order.
- `<umbrella>/sync/.intelligence-sync-version` stamp + `scripts/VERSION` source of truth.
- CI: migration + double-run idempotency job; legacy-upstream bridge test; bridge/canonical drift check.

### Compatibility

- Transition release: the upstream repo keeps the flat `intelligence/scripts/`, `intelligence/INIT.md`, `intelligence/skills/intelligence-*` as a **bridge** so already-deployed projects running their frozen pre-0.3.1 `update.sh` still self-update — they pull the migration-aware engine, which then relocates itself to `sync/` on the next `update`/`sync`. The bridge is removed in 0.4.0.
- Reserved prefix: project skills must not use the `intelligence-` prefix (it marks upstream-owned meta-skills).

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
