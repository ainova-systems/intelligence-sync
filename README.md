# intelligence-sync

**One source of truth for AI coding rules across every IDE your team uses.**

Write standards once in plain markdown. The sync engine routes content into the format each tool actually reads — no duplication, no drift, no per-IDE rewrites.

## The problem

Teams running multiple AI coding agents (Claude Code, Cursor, GitHub Copilot, OpenAI Codex) hit three recurring pains:

1. **Rule drift.** The same coding standards live in `.claude/rules/`, `.cursor/rules/`, `.github/instructions/`, `AGENTS.md`, `CLAUDE.md`. Six copies, six chances to forget an update.
2. **Context duplication.** `AGENTS.md` is read natively by Cursor / Copilot / Codex. If `.cursor/rules/` mirrors the same content, the model sees rules twice and burns context window. Cursor users complain about this on the official forum.
3. **Format chaos.** Each tool has its own frontmatter (`paths:` vs `globs:` vs `applyTo:`), its own model naming (`opus`/`sonnet` vs `gpt-5.5`/`gpt-5.5-codex`), and its own rule-scoping rules. Migrating between tools — or supporting all of them — means manual rewrites.

## Why intelligence-sync

You author rules / agents / skills once in tool-agnostic markdown under `intelligence/`. The sync engine knows each IDE's quirks (which files it reads, which scoping it supports, which model names map where) and routes content correctly:

- **Always-on rules** are inlined into `AGENTS.md` as the single canonical source — Cursor, Copilot, Codex all pick them up natively.
- **Path-scoped rules** stay in tool-specific channels with native scoping (`.cursor/rules/*.mdc` with `globs:`, `.github/instructions/*.instructions.md` with `applyTo:`) so monorepo glob targeting actually works.
- **Claude Code** receives the full rule set in `.claude/rules/` because it does not read AGENTS.md.
- **No duplication** between AGENTS.md and IDE rule directories — the design avoids it by routing, not flagging.

Source `intelligence/` is committed; generated IDE directories (`.claude/`, `.cursor/`, `.codex/`, `.agents/`) are gitignored. `AGENTS.md` is also committed — it is the canonical artifact humans and AI tools reference.

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

**Claude Code** · **Cursor** · **GitHub Copilot** · **OpenAI Codex** · **Any IDE** (via pluggable adapter)

Skills follow the [Agent Skills open standard](https://agentskills.io). Rules and `AGENTS.md` follow each tool's native formats.

Zero dependencies. Just bash + awk. Linux, macOS, Windows (Git Bash / WSL).

## Quick Start

### 1. Copy `intelligence/` to your project

```bash
git clone https://github.com/ainova-systems/intelligence-sync.git
cp -r intelligence-sync/intelligence/ my-project/intelligence/
```

### 2. Bootstrap with your AI assistant

Copy and paste this prompt into Claude Code, Cursor, or any AI coding assistant:

```
Read intelligence/INIT.md and follow it to bootstrap rules, agents, and skills for this project.
```

### 3. Run sync

```bash
bash intelligence/scripts/sync.sh
```

Or use the `/intelligence-sync` skill directly in your AI coding assistant.

### Upgrading

To pull the latest engine (`scripts/` + `INIT.md`) without touching your `config.yaml`, `rules/`, `agents/`, or `skills/`:

```bash
bash intelligence/scripts/update.sh
```

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

| Source | Claude Code | Cursor | Copilot | Codex | AGENTS.md |
|---|---|---|---|---|---|
| Rule with `paths:` (scoped) | copy as-is | `globs:` in `.mdc` | `applyTo:` in `.instructions.md` | not supported | listed by name |
| Rule without `paths:` (always-on) | copy as-is | skipped | skipped | skipped | **inlined as canonical** |
| `tier:` | `model:` | `model:` | `model:` | `model:` | n/a |
| `access:` | `tools:` | `readonly:` | `tools:` | `sandbox_mode:` | n/a |
| skills | SKILL.md | SKILL.md | SKILL.md | SKILL.md | listed |
| agents | transformed | transformed | `.agent.md` | `.toml` | listed |

Cursor, Copilot, and Codex all read AGENTS.md natively — always-on rules are inlined there once instead of being duplicated into each tool's native channel. Path-scoped rules stay in the native channels so monorepo glob targeting still works. Claude Code does not yet read AGENTS.md, so its adapter receives the full rule set.

## Project Structure

```
intelligence-sync/
├── intelligence/                # COPY THIS FOLDER to your project
│   ├── INIT.md                  # Bootstrap prompt for AI assistants
│   ├── scripts/                 # Sync engine (bash, zero dependencies)
│   │   ├── sync.sh              # Entry point — generate IDE outputs
│   │   ├── update.sh            # Self-update from upstream
│   │   ├── lib/common.sh        # Core functions
│   │   └── adapters/            # 5 built-in + template
│   │       ├── agents.sh        # AGENTS.md (canonical)
│   │       ├── claude.sh        # .claude/
│   │       ├── cursor.sh        # .cursor/
│   │       ├── copilot.sh       # .github/
│   │       ├── codex.sh         # .agents/skills/, .codex/agents/
│   │       └── _template.sh     # Starting point for new adapters
│   ├── rules/                   # Your rules go here
│   ├── agents/                  # Your agents go here
│   └── skills/                  # Pre-installed skills + your own
├── examples/                    # config.yaml for different project types
├── docs/                        # Conventions and adapter guide
└── LICENSE                      # MIT License
```

## Examples

- [go-api](examples/go-api/) -- Single Go API service
- [dotnet-api-with-react-frontend](examples/dotnet-api-with-react-frontend/) -- .NET backend + React frontend
- [platform-with-submodules](examples/platform-with-submodules/) -- Multi-component platform with git submodules

## Documentation

- [intelligence/INIT.md](intelligence/INIT.md) -- Bootstrap prompt for AI assistants
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) -- Frontmatter formats, naming, mappings
- [docs/ADAPTERS.md](docs/ADAPTERS.md) -- How to write a new IDE adapter
- [CONTRIBUTING.md](CONTRIBUTING.md) -- How to contribute

## License

MIT License. See [LICENSE](LICENSE) for details.

---

Created by **Dmitrij Zykovic** - Fractional CTO at [Ainova Systems](https://www.ainovasystems.com)

Helping teams adopt AI automation, establish AI-First SDLC, and build fully autonomous AI engineering pipelines.

[LinkedIn](https://www.linkedin.com/in/dmitrijz/) | [Advisory & Consulting](https://www.ainovasystems.com)
