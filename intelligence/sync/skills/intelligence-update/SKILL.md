---
name: intelligence-update
description: "Pull latest intelligence-sync engine, meta-skills, and docs from upstream"
argument-hint: "[--yes]"
---

# Update intelligence-sync

Pulls the latest **upstream-owned** content into the local vendored module `<intel>/sync/`:

- `<intel>/sync/scripts/` — sync engine and adapter scripts
- `<intel>/sync/INIT.md` — bootstrap prompt
- `<intel>/sync/skills/intelligence-*` — meta-skills (matched by the reserved `intelligence-` prefix)
- `<intel>/sync/docs/` — vendored from upstream `docs/`

**Project content is never touched**: `config.yaml` (except one idempotent additive `sources.skills` line during pre-0.3.1 migration), `rules/`, `agents/`, and non-meta skills (any skill without the reserved `intelligence-` prefix — `backend-*`, `frontend-*`, `<project>-*`).

`<intel>` is your umbrella folder — `intelligence/` by default, or whatever the project renamed it to (never hardcoded). Pre-0.3.1 projects with the engine flat under `<intel>/` are migrated into `<intel>/sync/` automatically and idempotently: meta-skills are moved (never duplicated), the engine relocates without deleting its own running directory.

## Steps

1. Run `bash <intel>/sync/scripts/update.sh` — clones upstream into a `mktemp -d` directory (cross-platform), shows the diff for each updated area, and prompts for confirmation.

2. Pass `--yes` to skip the prompt: `bash <intel>/sync/scripts/update.sh --yes`.

3. Override the upstream URL via env var: `REPO_URL=git@github.com:fork/intelligence-sync.git bash <intel>/sync/scripts/update.sh`.

4. After applying, run `/intelligence-sync` (or `bash <intel>/sync/scripts/sync.sh`) to regenerate IDE outputs. If model defaults moved (e.g., `gpt-5.5 → gpt-5.6`), sync prints a drift report listing every `models:` override in `config.yaml` that no longer matches the new default — accept by deleting the override, or pin by leaving as-is.

## What changes between releases

- **Meta-skills** (`intelligence-*`) — added, updated, or removed by upstream. Local meta-skills no longer present upstream are removed on update (so deprecated meta-skills disappear cleanly).
- **Docs** (`docs/CONVENTIONS.md`, `docs/ADAPTERS.md`, `docs/AUTHORING.md` if introduced) — always synced from upstream.
- **Engine scripts** — adapter behavior and library functions may evolve; full rsync replace.
- **INIT.md** — bootstrap prompt may evolve.

Check `CHANGELOG.md` in the upstream repo for the release notes between your local version and the latest.
