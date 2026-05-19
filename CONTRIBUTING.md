# Contributing to intelligence-sync

Thank you for your interest in contributing to intelligence-sync.

## How to Contribute

### Reporting Issues

- Open an issue on GitHub with a clear description of the problem
- Include your OS, shell version, and the IDE adapter involved
- Paste the relevant part of `config.yaml` if applicable

### Submitting Changes

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test with at least one adapter (`bash intelligence/sync/scripts/sync.sh claude`) — `sync.sh` runs `lint_frontmatter` over every source file before adapters fire, so unquoted YAML colons and other parse hazards surface as warnings on stderr.
5. If the change touches model defaults, run sync against a project that overrides them under `models:` — verify the drift report fires correctly.
6. Submit a pull request.

### Testing Engine Changes Across Projects

Downstream projects pick up engine changes via `intelligence/sync/scripts/update.sh` — point its `REPO_URL` at your fork to dry-run a release before merging:

```bash
REPO_URL=https://github.com/<you>/intelligence-sync.git \
  bash intelligence/sync/scripts/update.sh --yes
```

`update.sh` clones into `mktemp -d`, replaces `intelligence/sync/scripts/` and `intelligence/sync/INIT.md`, and never touches project content (`config.yaml`, `rules/`, `agents/`, `skills/`).

### Adding a New IDE Adapter

1. Copy `intelligence/sync/scripts/adapters/_template.sh` to `intelligence/sync/scripts/adapters/<name>.sh`.
2. Replace every `<name>` placeholder with your adapter name (the template intentionally fails to parse otherwise — `<` is a bash redirection operator).
3. Implement the `sync_to_<name>()` function.
4. Use `get_model "$config_file" "<name>" "$tier"` instead of hardcoding model names — this lets users override per-tier under `models:` in `config.yaml`.
5. Add an example target entry to the docs.
6. See [docs/ADAPTERS.md](docs/ADAPTERS.md) for the full guide.

### Code Style

- Shell scripts: `set -euo pipefail`, LF line endings (enforced by `.gitattributes`).
- Use helpers from `intelligence/sync/scripts/lib/common.sh` — never duplicate frontmatter parsing, model resolution, or YAML reading logic.
- No external dependencies beyond `bash` and `awk` (`mktemp`, `find`, `cp` are POSIX-OK).
- Comments should explain "why", not "what". Skip comments where well-named identifiers already make intent obvious.

### Commit Messages

- Capital letter, past tense, one sentence
- Example: `Added Codex adapter with AGENTS.md generation`

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
