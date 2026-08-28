# intelligence-sync (archived)

> **Intelligence Sync is archived and no longer accepts new development.**
> Its supported successor is the [Intelligence CLI](https://github.com/ainova-systems/intelligence), distributed as [`@ainova-systems/intelligence`](https://www.npmjs.com/package/@ainova-systems/intelligence).

The final vendored release is **0.10.4**. Existing projects can keep using it unchanged, but new projects should not copy this repository or bootstrap from its legacy engine.

## Install the successor

Requirements: Node.js 18+, Git, Bash and awk. On Windows, use Git Bash or WSL.

```bash
npm install -g @ainova-systems/intelligence@latest
intelligence --version
```

For a new project:

```bash
cd your-project
intelligence init --targets claude,codex
```

See the [Intelligence documentation](https://github.com/ainova-systems/intelligence#readme) for packages, adapters and the complete CLI lifecycle.

## Convert an existing Intelligence Sync project

Conversion is one-way, plan-first and transactional. Commit or stash unrelated changes first, then run from the project root:

```bash
npm install -g @ainova-systems/intelligence@latest
intelligence init --preview
intelligence init --apply
intelligence status --check
```

`intelligence init --preview` writes nothing. It detects the vendored project, stages the proposed root `intelligence.yaml`, lockfile, package store and generated output, then shows the conversion plan. `--apply` performs the already-reviewed plan and rolls back if staged verification or sync fails.

After conversion, lifecycle commands are:

```bash
intelligence sync
intelligence update
intelligence package list
intelligence adapter list
intelligence status --check
```

The CLI preserves project-owned rules, agents, skills and adapters. The vendored engine and legacy `config.yaml` are replaced by the root manifest, committed lockfile and CLI-managed package store.

### Projects older than schema 0.10.0

The CLI conversion boundary is legacy schema `0.10.0` or newer. If `intelligence init --preview` reports an older or missing `sync_version`, first tell your coding agent:

> **Update intelligence-sync to its final vendored release, then offer migration to the Intelligence CLI.**

For the conventional modular layout, the direct compatibility command is:

```bash
bash intelligence/sync/scripts/update.sh --yes
```

Very old flat-layout projects use `intelligence/scripts/update.sh`. The update flow discovers and migrates either layout without touching project-authored content. After it reaches `0.10.4`, run `intelligence init --preview` again.

An agent that started with a pre-0.10.2 update skill may need the update request a second time: the newly installed migration procedure cannot replace instructions already loaded in the active turn.

## Remaining on the legacy engine

The vendored engine remains functional and deterministic for projects that are not ready to convert:

```bash
bash intelligence/sync/scripts/sync.sh
```

It is frozen. New features, adapters, packages and lifecycle work belong in [ainova-systems/intelligence](https://github.com/ainova-systems/intelligence).

## Historical reference

- [Legacy changelog](CHANGELOG.md)
- [Legacy conventions](docs/CONVENTIONS.md)
- [Legacy adapter contract](docs/ADAPTERS.md)
- [Final migration prompt](intelligence/sync/INIT.md)
- [Final release](https://github.com/ainova-systems/intelligence-sync/releases/tag/v0.10.4)

## License

MIT License. See [LICENSE](LICENSE).
