---
name: intelligence-add-skill
description: Create new skill
argument-hint: <domain> <verb-noun> [description]
---

# Add Skill

## Steps

1. **Determine domain prefix** (the scope — required, never omit):
   - **Reuse existing domains first**: list `intelligence/skills/` and `intelligence/agents/`. If a domain prefix is already established for the target area (e.g., `backend-`, `frontend-`, `devops-`), reuse it. Do not invent new domains without clear need.
   - **If no existing domain fits**, derive from repo structure:
     - Single / root project → use the project codename from `intelligence/config.yaml` → `project.name`
     - Backend service / API component → `backend-`
     - Frontend / web / UI component → `frontend-`
     - Infrastructure, IaC, CI/CD, deployment → `devops-`
     - Shared library / common / cross-cutting code → `core-`
     - Test suites (e2e, integration) → `tests-`
     - Tool-internal (intelligence-sync itself) → `intelligence-`
   - If the repo is a monorepo with named components (e.g., `apps/billing`, `services/auth`), prefer the component name as the domain (`billing-`, `auth-`).
   - **Never create a skill without a domain prefix.** If the scope is unclear, ask the user before proceeding.

2. **Determine naming**: Build full name as `<domain>-<verb>-<noun>` using convention:
   - `add-` — creates a single artifact (atomic)
   - `create-` — orchestrates multiple `add-` skills (MUST use `create-`, never `add-`)
   - `update-` — modifies existing files across stack
   - `run-` — executes an operation (tests, build, sync)
   - `review-` — read-only analysis

3. **Check for existing agent**: Find an agent in `intelligence/agents/` matching the domain
   - If found — this skill will be linked to that agent
   - If not — ask user whether to create a new agent via `/intelligence-add-agent` first

4. **Analyze codebase patterns**: Read existing implementations to extract the repeatable steps this skill should automate. Each step must come from actual code patterns, not generic knowledge.

5. **Create skill**: Write `intelligence/skills/<full-name>/SKILL.md` with frontmatter:
   ```yaml
   ---
   name: <full-name>
   description: "<what it does and when to use>"
   argument-hint: "<expected arguments>"
   agent: <matching-agent-name>
   ---
   ```

   **YAML safety (required):** wrap every string value in double quotes when it contains any of `:` `#` `[` `]` `{` `}` `,` `&` `*` `!` `|` `>` `'` `"` `%` `@` ``` ` ```, starts with `-` or whitespace, or could be parsed as a boolean / number (`yes`, `no`, `true`, `1.0`). Codex CLI uses strict YAML — an unquoted colon in `description: Build retrospective: monthly` makes it parse as a nested mapping and the skill is rejected at startup.

6. **Write steps**: Numbered, concrete, executable. Include verification (build/test) at the end. For orchestrators — reference atomic skills by name.

7. **Update agent**: Add skill name to the `skills:` list in the matching agent's frontmatter.

8. **Run `/intelligence-sync`** to distribute to all enabled IDE targets.
