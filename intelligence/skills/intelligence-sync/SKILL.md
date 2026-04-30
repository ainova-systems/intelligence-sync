---
name: intelligence-sync
description: Sync intelligence sources to all enabled IDE targets
---

Run the sync engine to transform rules, agents, and skills from `intelligence/` to each enabled IDE's native format.

## Steps

1. Run `intelligence/scripts/sync.sh`
2. Review the output — verify rule, agent, and skill counts per target
3. If warnings about unsynced directories appear, add the missing paths to `config.yaml`
