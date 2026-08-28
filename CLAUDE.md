# CLAUDE.md

## Archive status

This repository is the frozen legacy Intelligence Sync product. Development moved to [ainova-systems/intelligence](https://github.com/ainova-systems/intelligence). Do not add features, adapters, model updates, compatibility branches or new lifecycle behavior here.

The retained Bash engine exists only so old vendored projects can update to the final legacy schema and convert with the Intelligence CLI. Never remove or weaken that bridge, and never direct a new project to copy `intelligence/sync/`.

## Final layout and contract

- Final legacy version: `intelligence/sync/scripts/VERSION` (`0.10.4`).
- Public compatibility entry points: `intelligence/sync/scripts/update.sh`, `sync.sh` and `intelligence/sync/INIT.md`.
- Project-owned `config.yaml`, rules, agents, skills and adapters remain untouched by update.
- Root `docs/` and `intelligence/sync/docs/` remain byte-identical.
- Examples remain frozen compatibility fixtures stamped at the engine version.
- The supported successor and conversion commands live in `README.md` and `intelligence/sync/INIT.md`.

## Validation

For the final archive release:

```bash
find intelligence/sync/scripts -name '*.sh' -not -path '*/adapters/_template.sh' -print0 \
  | xargs -0 shellcheck --severity=warning
```

Run the GitHub Actions compatibility suite and verify a real project can follow:

```bash
bash intelligence/sync/scripts/update.sh --yes
npm install -g @ainova-systems/intelligence@latest
intelligence init --preview
intelligence init --apply
intelligence status --check
```

After `v0.10.4` is published and conversion is verified, update the GitHub metadata and archive the repository. No further release is planned.
