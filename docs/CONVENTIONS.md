# intelligence-sync: Conventions

## Source Structure

```
intelligence/                         # Source of truth (committed to git)
├── rules/                            # Path-based rules (auto-loaded by context)
│   ├── context.md                    # Always-loaded (no paths:)
│   ├── backend.md                    # paths: ["src/backend/**"]
│   └── frontend.md                   # paths: ["src/frontend/**"]
├── agents/                           # Specialized agent definitions
│   ├── backend-developer.md          # tier: heavy, access: full
│   └── backend-code-reviewer.md      # tier: standard, access: readonly
└── skills/                           # Reusable skill commands
    ├── backend-add-endpoint/SKILL.md
    └── frontend-add-component/SKILL.md
```

Rule filenames, agent names, and skill names all share the same **domain prefix** (`backend-`, `frontend-`, `devops-`, `core-`, `tests-`, project codename, or monorepo component name). Pick the domain once from repo structure and reuse it — do not invent new domains without clear need.

## Agent Frontmatter

```yaml
---
name: agent-name                     # Kebab-case identifier
description: When to use this agent  # Shown in IDE agent picker
tier: heavy|standard|light           # Model capability (tool-agnostic)
access: full|readonly                # Tool permissions (tool-agnostic)
skills:                              # Optional: linked skills
  - skill-name-1
  - skill-name-2
---

Agent instructions in markdown...
```

### Tier Mappings

| Tier | Claude | Cursor | Use for |
|------|--------|--------|---------|
| heavy | opus | (default) | Developers, complex reasoning, migration |
| standard | sonnet | fast | Reviewers, validators, analysis |
| light | haiku | fast | Simple lookups, formatting |

Tier is only relevant for IDEs with agent support (Claude, Cursor). Other IDEs ignore it.

### Access Mappings

| Access | Claude | Cursor | Description |
|--------|--------|--------|-------------|
| full | tools: Read,Write,Edit,Glob,Grep,Bash,Agent | (default) | Full edit access |
| readonly | tools: Read,Grep,Glob,Bash + disallowedTools: Write,Edit | readonly: true | Analysis only |

## Rule Frontmatter

```yaml
---
paths:                               # Optional: path-based activation
  - "src/backend/**"                 # Glob patterns from repo root
  - "config/**"
---

Rule content in markdown...
```

- **With paths:** Rule auto-loads when user edits matching files
- **Without paths:** Rule applies always (context rules)

### Sync Transformations (Rules)

| Source | Claude | Cursor | Copilot | Codex / AGENTS.md |
|--------|--------|--------|---------|-------------------|
| `paths:` (scoped) | copied | `globs:` in `.mdc` | `applyTo:` in `.instructions.md` | listed in AGENTS.md |
| no `paths:` (always-on) | copied | skipped | skipped | inlined into AGENTS.md |
| extension | `.md` | `.mdc` | `.instructions.md` | inline / n/a |

Always-on rule content is inlined once into AGENTS.md (which Cursor, Copilot, and Codex read natively); the per-IDE rule channels carry only path-scoped rules to preserve monorepo glob targeting without duplicating context. Claude Code does not read AGENTS.md, so its adapter receives the full rule set.

## Skill Frontmatter

Skills follow the [Agent Skills open standard](https://agentskills.io) (adopted by Claude Code, Cursor, GitHub Copilot, OpenAI Codex, Gemini CLI, OpenCode, Goose, Junie, and 30+ others). Required fields: `name` + `description`.

```yaml
---
name: <domain>-<verb>-<noun>         # e.g., backend-add-endpoint
description: What the skill does     # Shown in IDE skill picker
argument-hint: <arg1> [arg2]         # Optional: usage hint
---

# Skill Title

## Steps
1. First step...
2. Second step...
```

Standard optional fields (`license`, `compatibility`, `metadata`, `allowed-tools`) and IDE-specific extensions (Claude's `disable-model-invocation`, `model`, `effort`, `context: fork`, `hooks`, `paths`, `shell`) pass through unchanged — adapters do not strip them. Each tool ignores fields it does not understand.

### Naming Conventions

Skill names are `<domain>-<verb>-<noun>`. Both parts are required.

**Domain prefix** (the scope — required, never omit):

| Source | Domain |
|--------|--------|
| Single / root project | Project codename from `config.yaml` → `project.name` |
| Backend service / API | `backend-` |
| Frontend / web / UI | `frontend-` |
| Infrastructure / IaC / CI/CD | `devops-` |
| Shared library / common code | `core-` |
| Test suites (e2e, integration) | `tests-` |
| Monorepo named components | Component name (e.g., `billing-`, `auth-`) |
| Tool-internal (intelligence-sync) | `intelligence-` |

Reuse an existing domain whenever possible. Do not invent new domains without clear need.

**Verb prefix** (the action):

| Verb | Type | Description |
|------|------|-------------|
| `add-` | Atomic | Creates/updates a single artifact |
| `create-` | Orchestrator | Invokes multiple `add-` skills in sequence |
| `update-` | Meta-orchestrator | Discovers existing components, updates selectively |
| `run-` | Execution | Runs an operation (tests, sync, build) |
| `review-` | Read-only | Analyzes code without changes |
| `test-` | Testing | Manual or automated test verification |
| `remove-` | Deletion | Safely removes an artifact |

Agents follow the same domain prefix rule: `<domain>-<role>` (e.g., `backend-developer`, `frontend-code-reviewer`). Rule filenames use the domain without a verb: `<domain>.md` (e.g., `backend.md`).

### Skill Tiers

- **Atomic** (`add-`): Full implementation details, code patterns, examples
- **Orchestrator** (`create-`): Thin wrapper — discovery logic + calls to atomic skills. NO pattern duplication
- **Meta-orchestrator** (`update-`): Discovers existing components, invokes atomic skills for gaps

## Generated Output

| Target | Rules output | Skills location | Agents location | Git-ignored |
|--------|--------------|-----------------|-----------------|-------------|
| `agents` | inlined into `AGENTS.md` (always-on); listed (scoped) | n/a | listed in `AGENTS.md` | No (committed) |
| Claude Code | `.claude/rules/` (full) | `.claude/skills/` | `.claude/agents/` | Yes |
| Cursor | `.cursor/rules/*.mdc` (scoped only) | `.cursor/skills/` | `.cursor/agents/` | Yes |
| GitHub Copilot | `.github/instructions/*.instructions.md` (scoped only) | `.github/skills/` | `.github/agents/` | Partial |
| OpenAI Codex | none (reads `AGENTS.md`) | `.agents/skills/` | `.codex/agents/*.toml` | Yes |

Skill locations all comply with the Agent Skills open standard. Cursor reads from `.cursor/skills/` and `.agents/skills/`; Copilot reads from `.github/skills/`, `.claude/skills/`, and `.agents/skills/`; Codex reads from `.agents/skills/` exclusively. Claude Code reads from `.claude/skills/`.

**Rule routing rationale:** AGENTS.md is canonical for Cursor/Copilot/Codex (all read it natively), so always-on rule content is inlined there once and the per-IDE rule directories carry only path-scoped rules — no duplication. Claude Code does not read AGENTS.md, so its adapter receives the full rule set.

`AGENTS.md` is always enabled and regenerated on every sync. The static header (`targets.agents.header` in `config.yaml`) is the only hand-authored part; everything below it is rebuilt from frontmatter — agents/skills tables, the rules list, and the inlined content of every always-on rule (those without `paths:`). Path-scoped rules are listed by name only so AGENTS.md does not balloon in monorepos.

## .gitignore Pattern

```
# AI IDE tools (generated by intelligence-sync, local preferences)
CLAUDE.md
.cursorrules
.agents/
.codex/

# Claude Code: ignore everything except project-shared settings.
.claude/*
!.claude/settings.json

# Cursor: same pattern.
.cursor/*
!.cursor/settings.json
```

The inverse pattern (`.claude/*` + `!.claude/settings.json`) ignores every generated subdir (`rules/`, `skills/`, `agents/`) plus any per-machine state Claude writes (`settings.local.json`, `*.lock`, `scheduled_tasks.*`, `sessions/`, `cache/`, etc.) without having to enumerate filenames Claude may add later. Only `.claude/settings.json` (project-shared bash allowlist, tool permissions) is tracked. Same logic for `.cursor/`. If a project needs to track another file (e.g., a hand-authored `.claude/commands/<name>.md`), add another `!<path>` line.

## Project Entry Points

| File | Role | Git status |
|------|------|-----------|
| `AGENTS.md` | Auto-generated canonical project doc for LLMs (do not edit manually) | Tracked |
| `CLAUDE.md` | Local user preferences (gitignored) | Ignored |
| `config.yaml` | Sync configuration (committed) | Tracked |
| `intelligence/` | Source of truth for rules/agents/skills | Tracked |
