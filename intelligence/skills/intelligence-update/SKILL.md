---
name: intelligence-update
description: Pull the latest intelligence-sync scripts and INIT.md from upstream without touching project content
argument-hint: "[--yes]"
---

# Update intelligence-sync

Updates only `intelligence/scripts/` and `intelligence/INIT.md`. Project content (`config.yaml`, `rules/`, `agents/`, `skills/`) is never touched.

## Steps

1. Run `bash intelligence/scripts/update.sh` — clones upstream into a `mktemp -d` directory (cross-platform), shows the diff for `scripts/` and `INIT.md`, and prompts for confirmation.

2. Pass `--yes` to skip the prompt: `bash intelligence/scripts/update.sh --yes`.

3. Override the upstream URL via env var: `REPO_URL=git@github.com:fork/intelligence-sync.git bash intelligence/scripts/update.sh`.

4. After applying, run `/intelligence-sync` (or `bash intelligence/scripts/sync.sh`) to regenerate IDE outputs. If model defaults moved (e.g., `gpt-5.5 → gpt-5.6`), sync prints a drift report listing every `models:` override in `config.yaml` that no longer matches the new default — accept them by deleting the override, or pin them by leaving as-is.
