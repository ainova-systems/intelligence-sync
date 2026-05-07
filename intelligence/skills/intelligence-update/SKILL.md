---
name: intelligence-update
description: "Pull latest intelligence-sync scripts from upstream"
argument-hint: "[--yes]"
---

# Update intelligence-sync

Updates only `<intel>/scripts/` and `<intel>/INIT.md` (where `<intel>` is your intelligence source folder — `intelligence/` by default, or whatever the project renamed it to). Project content (`config.yaml`, `rules/`, `agents/`, `skills/`) is never touched.

## Steps

1. Run `bash <intel>/scripts/update.sh` — clones upstream into a `mktemp -d` directory (cross-platform), shows the diff for `scripts/` and `INIT.md`, and prompts for confirmation.

2. Pass `--yes` to skip the prompt: `bash <intel>/scripts/update.sh --yes`.

3. Override the upstream URL via env var: `REPO_URL=git@github.com:fork/intelligence-sync.git bash <intel>/scripts/update.sh`.

4. After applying, run `/intelligence-sync` (or `bash <intel>/scripts/sync.sh`) to regenerate IDE outputs. If model defaults moved (e.g., `gpt-5.5 → gpt-5.6`), sync prints a drift report listing every `models:` override in `config.yaml` that no longer matches the new default — accept them by deleting the override, or pin them by leaving as-is.
