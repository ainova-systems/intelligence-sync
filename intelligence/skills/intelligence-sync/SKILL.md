---
name: intelligence-sync
description: Sync intelligence sources to all enabled IDE targets
---

Run the sync engine to transform rules, agents, and skills from the intelligence source directory to each enabled IDE's native format.

> **Folder name:** the source directory is whatever holds your `config.yaml` and `scripts/` — typically `intelligence/`, but may have been renamed (e.g. `Intelligence/`). The script is self-locating, so any spelling works as long as you point bash at the right `scripts/sync.sh` path.

## Steps

1. Run `bash <intel>/scripts/sync.sh` (where `<intel>` is your intelligence source folder; default `intelligence`).
2. Review the output — verify rule, agent, and skill counts per target.
3. If warnings about unsynced directories appear, add the missing paths to `<intel>/config.yaml` under `sources:`.
