---
name: Bug report
about: Sync produced wrong output, errored, or behaved unexpectedly
title: "[bug] "
labels: bug
---

## What happened

<!-- Describe the unexpected behavior. -->

## What you expected

<!-- Describe what you thought should happen. -->

## Reproduction

1. <!-- Step 1 -->
2. <!-- Step 2 -->
3. <!-- ... -->

## Environment

- OS: <!-- e.g. macOS 15.0, Ubuntu 24.04, Windows 11 + Git Bash -->
- Bash version: <!-- `bash --version` -->
- IDE adapter(s) involved: <!-- claude / cursor / copilot / codex / agents -->
- intelligence-sync commit: <!-- output of `git -C intelligence rev-parse HEAD` if cloned, or version pulled by update.sh -->

## Relevant config

```yaml
# Paste the relevant slice of intelligence/config.yaml
```

## Sync output

```
# Paste the output of `bash intelligence/scripts/sync.sh` (or the failing target only)
```
