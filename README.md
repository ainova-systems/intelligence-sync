# intelligence-sync

**One source of truth for AI coding rules across every IDE your team uses.**

Write standards once in plain markdown. The sync engine routes content into the format each tool actually reads — no duplication, no drift, no per-IDE rewrites.

## The problem

Teams running multiple AI coding agents (Claude Code, Cursor, GitHub Copilot, OpenAI Codex, Pi, opencode) hit three recurring pains:

1. **Rule drift.** The same coding standards live in `.claude/rules/`, `.cursor/rules/`, `.github/instructions/`, `AGENTS.md`, `CLAUDE.md`. Six copies, six chances to forget an update.
2. **Context duplication.** `AGENTS.md` is read natively by Cursor / Copilot / Codex / Pi / opencode. If `.cursor/rules/` mirrors the same content, the model sees rules twice and burns context window. Cursor users complain about this on the official forum.
3. **Format chaos.** Each tool has its own frontmatter (`paths:` vs `globs:` vs `applyTo:`), its own model naming (`opus`/`sonnet` vs `gpt-5.5`/`gpt-5.5-codex`), and its own rule-scoping rules. Migrating between tools — or supporting all of them — means manual rewrites.

## Why intelligence-sync

You author rules / agents / skills once in tool-agnostic markdown under `intelligence/`. The sync engine knows each IDE's quirks (which files it reads, which scoping it supports, which model names map where) and routes content correctly:

- **Always-on rules** are inlined into `AGENTS.md` as the single canonical source — Cursor, Copilot, Codex, Pi, and opencode all pick them up natively.
- **Path-scoped rules** stay in tool-specific channels with native scoping (`.cursor/rules/*.mdc` with `globs:`, `.github/instructions/*.instructions.md` with `applyTo:`) so monorepo glob targeting actually works.
- **Claude Code** receives the full rule set in `.claude/rules/` because it does not read AGENTS.md.
- **No duplication** between AGENTS.md and IDE rule directories — the design avoids it by routing, not flagging.

Source `intelligence/` is committed; generated IDE directories (`.claude/`, `.cursor/`, `.codex/`, `.agents/`) and adapter-owned Pi files under `.pi/` are gitignored. `AGENTS.md` is also committed — it is the canonical artifact humans and AI tools reference.

## How

| Step | You do | intelligence-sync does |
|------|--------|-----------------|
| 1. Define | Write rules / agents / skills in plain markdown | — |
| 2. Sync | Run one command | Transforms to every IDE's native format |
| 3. Code | Open any IDE | Rules are already there, correctly formatted and scoped |

```
intelligence/                  AGENTS.md   .claude/    .cursor/    .github/         .codex/ + .agents/
├── rules/context.md      -->  inlined     rules/      —           —                —
├── rules/backend.md      -->  listed      rules/      rules/*.mdc instructions/    —
├── agents/developer.md   -->  listed      agents/     agents/     agents/          agents/*.toml
└── skills/*/SKILL.md     -->  listed      skills/     skills/     skills/          .agents/skills/
```

## Works with

**Claude Code** · **Cursor** · **GitHub Copilot** · **OpenAI Codex** · **Pi** · **opencode** · **Any IDE** (via pluggable adapter)

Skills follow the [Agent Skills open standard](https://agentskills.io). Rules and `AGENTS.md` follow each tool's native formats.

Zero dependencies. Just bash + awk. Linux, macOS, Windows (Git Bash / WSL).

## Quick Start

From inside your project, paste this prompt into Claude Code, Cursor, or any AI coding assistant:

```
Set up intelligence-sync in this repository from https://github.com/ainova-systems/intelligence-sync:
clone it into a temp directory, copy its `intelligence/` folder into my project root, then read
`intelligence/sync/INIT.md` and follow it to bootstrap rules, agents, and skills. Finish by running
`bash intelligence/sync/scripts/sync.sh`.
```

The assistant clones the engine, copies it in, interviews you about your stack, generates
`intelligence/rules`, `intelligence/agents`, and `intelligence/skills`, and runs the first sync —
you never run a `git clone` or `cp` yourself.

### Upgrading

Tell your AI coding agent:

> **Update intelligence-sync**

The `intelligence-update` skill fetches the latest engine, drives any layout migration, resolves issues, and verifies the result. Your project-authored content — `rules/`, `agents/`, project `skills/`, and everything you wrote in `config.yaml` — is left intact; the only managed `config.yaml` edits are the engine's own keys: the `sync_version` schema stamp and the additive `sources.skills` module entry a migration adds. Idempotent and safe to repeat.

Directly, if you prefer: `bash intelligence/sync/scripts/update.sh`.

**Pre-0.3.1 projects** (engine flat under `intelligence/`): there is no manual procedure and no deadline. The old frozen `update.sh` fails closed (changes nothing, no data loss, however long it sits). Run the agent instruction above once — it migrates the engine into `intelligence/sync/` (meta-skills moved, never duplicated; one additive `config.yaml` line). Everything is automatic thereafter.

The script clones upstream into a temp dir (cross-platform `mktemp`), shows a diff, and prompts before applying. Pass `--yes` to skip the prompt, or `REPO_URL=<your-fork>` to use a fork.

## How It Works

### Source format (tool-agnostic)

Agents use `tier` and `access` instead of IDE-specific fields:

```yaml
---
name: developer
tier: heavy          # heavy | standard | light
access: full         # full | readonly
---
```

Rules use `paths:` for context-based auto-loading:

```yaml
---
paths:
  - "src/backend/**"
---
```

### What each adapter does

| Source | Claude Code | Cursor | Copilot | Codex | Pi | opencode | AGENTS.md |
|---|---|---|---|---|---|---|---|
| Rule with `paths:` (scoped) | copy as-is | `globs:` in `.mdc` | `applyTo:` in `.instructions.md` | not supported | extension + on-demand rule files | not supported (use `instructions:` in `opencode.json`) | listed by name |
| Rule without `paths:` (always-on) | copy as-is | skipped | skipped | skipped | skipped | skipped | **inlined as canonical** |
| `tier:` | `model:` | `model:` | `model:` | `model:` | prompt template | `model:` | n/a |
| `access:` | `tools:` | `readonly:` | `tools:` | `sandbox_mode:` | prompt guidance | `permission.edit`/`permission.bash` | n/a |
| skills | SKILL.md | SKILL.md | SKILL.md | SKILL.md | SKILL.md via `.agents/skills/` | SKILL.md via `.agents/skills/` + `/<name>` in `.opencode/commands/` | listed |
| agents | transformed | transformed | `.agent.md` | `.toml` | `.pi/prompts/*.md` | `.opencode/agents/*.md` (subagent) | listed |

Cursor, Copilot, Codex, Pi, and opencode all read AGENTS.md natively — always-on rules are inlined there once instead of being duplicated into each tool's native channel. Path-scoped rules stay in native per-tool channels where those exist; Pi gets a generated extension that lists scoped rules and tells the model to `read` them on demand. opencode has no first-class scoped-rule channel; users who need scoped rules can opt in via `instructions:` globs in `opencode.json`. Claude Code does not yet read AGENTS.md, so its adapter receives the full rule set.

## Project Structure

```
intelligence-sync/
├── intelligence/                # COPY THIS FOLDER to your project
│   ├── config.yaml              # Sync configuration (you create via INIT)
│   ├── rules/                   # Your rules go here          ← project content
│   ├── agents/                  # Your agents go here         ← project content
│   ├── skills/                  # Your skills go here         ← project content
│   └── sync/                    # intelligence-sync MODULE (upstream-owned, self-update)
│       ├── INIT.md              # Bootstrap prompt for AI assistants
│       ├── docs/                # Vendored conventions + adapter guide
│       ├── scripts/             # Sync engine (bash, zero dependencies)
│       │   ├── sync.sh          # Entry point — generate IDE outputs
│       │   ├── update.sh        # Self-update from upstream
│       │   ├── VERSION          # Module version (drives migrations)
│       │   ├── lib/             # common.sh, layout.sh, migrations.sh
│       │   └── adapters/        # 6 built-in + template
│       └── skills/intelligence-*  # Pre-installed meta-skills
├── examples/                    # config.yaml for different project types
├── docs/                        # Conventions and adapter guide (source)
└── LICENSE                      # MIT License
```

Each `intelligence/<module>/` (e.g. `sync/`, future `domain/`) is self-contained and updated independently. The umbrella folder name (`intelligence/`) is never hardcoded — it is whatever holds `config.yaml`.

## Examples

- [go-api](examples/go-api/) -- Single Go API service
- [go-api-with-pi-and-codex](examples/go-api-with-pi-and-codex/) -- Go API with Pi + Codex sharing AGENTS.md and `.agents/skills/`
- [go-api-with-opencode](examples/go-api-with-opencode/) -- Go API with opencode (subagents in `.opencode/agents/`, skills via `.agents/skills/`)
- [dotnet-api-with-react-frontend](examples/dotnet-api-with-react-frontend/) -- .NET backend + React frontend
- [platform-with-submodules](examples/platform-with-submodules/) -- Multi-component platform with git submodules

## Documentation

- [intelligence/sync/INIT.md](intelligence/sync/INIT.md) -- Bootstrap prompt for AI assistants
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) -- Frontmatter formats, naming, mappings
- [docs/ADAPTERS.md](docs/ADAPTERS.md) -- How to write a new IDE adapter
- [CONTRIBUTING.md](CONTRIBUTING.md) -- How to contribute

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Created by **Dmitrij Zykovic** - Fractional CTO at [Ainova Systems](https://www.ainovasystems.com)

Helping teams adopt AI automation, establish AI-First SDLC, and build fully autonomous AI engineering pipelines.

[LinkedIn](https://www.linkedin.com/in/dmitrijz/) | [Advisory & Consulting](https://www.ainovasystems.com)
