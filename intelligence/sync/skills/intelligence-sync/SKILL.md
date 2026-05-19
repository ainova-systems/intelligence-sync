---
name: intelligence-sync
description: "Sync intelligence to enabled IDE targets"
---

Run the sync engine to transform rules, agents, and skills from the intelligence source directory to each enabled IDE's native format.

> **Folder name:** `<intel>` is whatever holds your `config.yaml` — typically `intelligence/`, but may have been renamed (e.g. `Intelligence/`). The engine lives in the module subfolder `<intel>/sync/`. The script is self-locating and migrates pre-0.3.1 flat layouts automatically, so any spelling works as long as you point bash at the right `sync/scripts/sync.sh` path.

## Steps

1. Run `bash <intel>/sync/scripts/sync.sh` (where `<intel>` is your intelligence source folder; default `intelligence`).
2. Review the output — verify rule, agent, and skill counts per target.
3. If warnings about unsynced directories appear, add the missing paths to `<intel>/config.yaml` under `sources:`.
