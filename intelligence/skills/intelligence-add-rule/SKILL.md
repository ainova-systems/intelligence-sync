---
name: intelligence-add-rule
description: Create new intelligence rule
argument-hint: <name> [paths-glob]
---

# Add Rule

## Steps

1. **Determine rule name from domain** (the scope — required, never omit):
   - **Reuse existing domain names first**: list `intelligence/rules/`. If a rule file already covers the target area (e.g., `backend.md`, `frontend.md`), extend it instead of creating a new one. Do not invent new domains without clear need.
   - **If no existing rule fits**, derive the filename from repo structure:
     - Single / root project → use the project codename from `intelligence/config.yaml` → `project.name` (e.g., `<codename>.md`)
     - Backend service / API component → `backend.md`
     - Frontend / web / UI component → `frontend.md`
     - Infrastructure, IaC, CI/CD, deployment → `devops.md`
     - Shared library / common / cross-cutting code → `core.md`
     - Test suites (e2e, integration) → `tests.md`
     - Always-loaded global context → `context.md`
   - If the repo is a monorepo with named components (e.g., `apps/billing`, `services/auth`), prefer the component name as the rule name (`billing.md`, `auth.md`).
   - **Rule filenames must match the domain used by skills/agents.** If the scope is unclear, ask the user before proceeding.

2. **Check existing rules**: Read `intelligence/rules/` to avoid duplicates or overlapping scope.

3. **Determine scope**:
   - If paths glob provided — scoped rule with `paths:` frontmatter
   - If no paths — always-loaded rule (no `paths:` in frontmatter)

4. **Analyze codebase**: Read source files matching the scope to extract:
   - FORBIDDEN patterns (things that exist as anti-patterns or are explicitly avoided)
   - REQUIRED patterns (conventions consistently followed across the codebase)
   - Architecture patterns (layer dependencies, module structure)
   - Build and test commands specific to this scope

5. **Create rule**: Write `intelligence/rules/<name>.md`:
   ```yaml
   ---
   paths:
     - "<glob-pattern>"
   ---
   ```

6. **Write body** with sections: **FORBIDDEN** -> **REQUIRED** -> **Architecture** -> **Build & Test** -> **Examples**
   - Examples must come from actual codebase — reference real files
   - Every FORBIDDEN/REQUIRED must be backed by observed patterns

7. **Update config.yaml** if needed: Add source path to `sources.rules` if rule is in a new directory not yet listed.

8. **Run `/intelligence-sync`** to distribute to all enabled IDE targets.
