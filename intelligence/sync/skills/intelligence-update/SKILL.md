---
name: intelligence-update
description: "Update or migrate intelligence-sync: fetch latest engine, drive layout migration, resolve issues"
argument-hint: "[--yes]"
---

# Update intelligence-sync

You are the **intelligent driver** of an update/migration. The bash engine is
deterministic and fail-closed — it never guesses; on any state it cannot
safely resolve it prints a machine-readable `IS_STATUS=<code>` line and stops.
Your job: detect the project's state, run the engine, read its status, and
resolve whatever it hands back — asking the user only when genuinely
ambiguous.

Trigger: the user says something like *"update intelligence-sync"* / *"migrate
intelligence-sync"*. They should never need to run shell commands by hand —
you run them.

## Key facts

- The **umbrella** is whatever directory holds `config.yaml` (`intelligence/`,
  `Intelligence/`, `prompts/`, …). Never assume the name — find it.
- 0.3.1+ layout is modular: the engine lives in `<umbrella>/sync/`
  (`scripts/`, `skills/intelligence-*`, `INIT.md`, `docs/`,
  `.intelligence-sync-version`). Project content (`rules/`, `agents/`,
  non-meta `skills/`, `config.yaml`) stays at the umbrella level.
- Pre-0.3.1 projects had the engine flat under the umbrella. Their frozen
  `update.sh` fails **closed** against the modular upstream (exit ≠ 0,
  destroys nothing) — so the first hop must be bootstrapped by you, not by
  the old script.
- The `intelligence-` skill prefix is **reserved** for upstream meta-skills.

## Steps

### 1. Locate the umbrella
Find the directory containing `config.yaml` (search the repo; typically
`intelligence/` but honor any rename). Call it `<umbrella>`. If none exists,
the project is not bootstrapped — point the user at `<upstream>/INIT.md` and
stop.

### 2. Ensure a migration-capable engine is present
Clone upstream into a temp dir (default
`https://github.com/ainova-systems/intelligence-sync`, or the user's
`REPO_URL`/fork):

```
git clone --depth=1 <repo> <tmp>
```

Copy the upstream module into place so a current, migration-aware engine
exists locally even on a pre-0.3.1 project:

```
mkdir -p <umbrella>/sync
cp -r <tmp>/intelligence/sync/. <umbrella>/sync/
```

(This is the bootstrap that replaces the dead manual instructions. It is safe
and idempotent — `update.sh` re-clones internally and is authoritative.)

### 3. Run the engine
```
bash <umbrella>/sync/scripts/update.sh --yes      # or without --yes to let the user confirm the diff
```
Capture stdout. Find the last `IS_STATUS=<code> [IS_DETAIL=...]` line.

### 4. Branch on `IS_STATUS`

| Code | Meaning | What you do |
|---|---|---|
| `ok` | Up to date / no migration needed | Go to step 5. |
| `migrated` | Legacy → modular migration performed | Go to step 5; in the summary, note the relocation. |
| `aborted-incomplete` | Staged module incomplete; legacy left intact (safe) | Re-run step 2–3 once (network/clone hiccup). If it persists, show the engine output and stop — do **not** hand-fix the tree. |
| `ahead-of-engine` | Project stamped newer than this engine | Do **not** downgrade. The local/forked upstream is older than the project. Tell the user to point `REPO_URL` at the correct/newer upstream, or accept they're already ahead. Stop. |
| `config-missing` | No `config.yaml` | Project not bootstrapped — direct the user to `<umbrella>/sync/INIT.md`. Stop. |
| `error` (e.g. `upstream-layout-unrecognized`) | Engine couldn't proceed | Show the message; check `REPO_URL` points at a real intelligence-sync repo. Stop. |
| *(no status line)* | Engine crashed before contract | Show full output; do not modify the tree. Stop. |

If the engine reports a genuinely **ambiguous** tree (e.g. both a legacy flat
`<umbrella>/scripts/` and a populated `<umbrella>/sync/scripts/` with
differing content, no clear stamp): inspect both, summarize the difference to
the user, ask which is authoritative, then apply their choice (keep the
authoritative one, remove the other). Never guess.

### 5. Verify and report
After a successful `ok`/`migrated`:

- No `intelligence-*` directory remains directly under `<umbrella>/skills/`
  (meta-skills live only in `<umbrella>/sync/skills/`). If any survive,
  something is wrong — investigate, don't delete blindly.
- Project content is intact: `<umbrella>/{rules,agents}/` and any non-`intelligence-`
  skills untouched.
- `<umbrella>/sync/.intelligence-sync-version` exists and equals the engine
  version.
- `config.yaml` `sources.skills` includes the module skills path
  (`<base>/sync/skills`) exactly once.

Then run sync to regenerate IDE outputs:
```
bash <umbrella>/sync/scripts/sync.sh
```
If sync prints a model drift report, relay it: each `models:` override that
no longer matches the new default — accept by removing the override, or keep
to pin.

Finally, summarize: what changed, version before/after, anything the user
must act on. Clean up the temp clone.

## Notes

- Everything here is **idempotent**. Re-running on an already-modular project
  is a safe no-op (`IS_STATUS=ok`).
- Never touch `config.yaml` beyond the engine's own idempotent additive
  `sources.skills` line. Never move/delete project skills, rules, or agents.
- Multi-module umbrellas (e.g. a `domain/` module beside `sync/`) are fine —
  this skill only owns `sync/`. Don't touch sibling modules.
- Check upstream `CHANGELOG.md` for release notes between the stamped version
  and the engine version; include relevant highlights in your summary.
