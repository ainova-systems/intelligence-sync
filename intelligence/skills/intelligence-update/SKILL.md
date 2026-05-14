---
name: intelligence-update
description: "Pull latest intelligence-sync engine, meta-skills, and docs from upstream"
argument-hint: "[--yes]"
---

# Update intelligence-sync

Pulls the latest **upstream-owned** content into the local vendored copy:

- `<intel>/scripts/` — sync engine and adapter scripts
- `<intel>/INIT.md` — bootstrap prompt
- `<intel>/skills/intelligence-*` — meta-skills (matched by `intelligence-` prefix)
- `<intel>/docs/` — vendored from upstream `docs/`

**Project content is never touched**: `config.yaml`, `rules/`, `agents/`, and non-meta skills (any skill without `intelligence-` prefix — `backend-*`, `frontend-*`, `<project>-*`).

`<intel>` is your intelligence source folder — `intelligence/` by default, or whatever the project renamed it to.

## Steps

1. Run `bash <intel>/scripts/update.sh` — clones upstream into a `mktemp -d` directory (cross-platform), shows the diff for each updated area, and prompts for confirmation.

2. Pass `--yes` to skip the prompt: `bash <intel>/scripts/update.sh --yes`.

3. Override the upstream URL via env var: `REPO_URL=git@github.com:fork/intelligence-sync.git bash <intel>/scripts/update.sh`.

4. After applying, run `/intelligence-sync` (or `bash <intel>/scripts/sync.sh`) to regenerate IDE outputs. If model defaults moved (e.g., `gpt-5.5 → gpt-5.6`), sync prints a drift report listing every `models:` override in `config.yaml` that no longer matches the new default — accept by deleting the override, or pin by leaving as-is.

## What changes between releases

- **Meta-skills** (`intelligence-*`) — added, updated, or removed by upstream. Local meta-skills no longer present upstream are removed on update (so deprecated meta-skills disappear cleanly).
- **Docs** (`docs/CONVENTIONS.md`, `docs/ADAPTERS.md`, `docs/AUTHORING.md` if introduced) — always synced from upstream.
- **Engine scripts** — adapter behavior and library functions may evolve; full rsync replace.
- **INIT.md** — bootstrap prompt may evolve.

Check `CHANGELOG.md` in the upstream repo for the release notes between your local version and the latest.
