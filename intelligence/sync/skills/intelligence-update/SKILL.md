---
name: intelligence-update
description: "Update or migrate intelligence-sync: discover engine, read changelog, run migration chain, verify"
argument-hint: "[--yes]"
---

# Update intelligence-sync

You are the **intelligent driver** of an update. The bash engine is
deterministic and fail-closed — it never guesses; on any state it cannot
resolve it prints `IS_STATUS=<code>` and stops. Your job: discover the engine,
understand what is changing (read the CHANGELOG across the version gap), run
the migration chain, branch on the status, and **verify afterward**. Ask the
user only when genuinely ambiguous.

Trigger: the user says something like *"update / migrate intelligence-sync"*.
They never run shell commands by hand — you do.

## Key facts

- **Umbrella** = whatever directory holds `config.yaml` (`intelligence/`,
  `Intelligence/`, …). Never assume the name — find it.
- **Engine = a module discovered by ROLE, not by name**: a directory under
  the umbrella whose `scripts/sync.sh` **and** `scripts/VERSION` both exist
  (conventionally `sync/`, but never assume the folder name).
- **Applied schema version** is the frozen contract key
  `intelligence_sync_version` in `config.yaml` (a permanent top-level scalar;
  absent ⇒ pre-0.3.1). **Engine version** is `<module>/scripts/VERSION`.
  The gap between them is the set of breaking changes to apply.
- Pre-0.3.1 projects have the engine flat at `<umbrella>/scripts/` and **no**
  `intelligence_sync_version` key. Their frozen `update.sh` fails closed
  against the modular upstream (changes nothing) — you bootstrap the first hop.
- The `intelligence-` skill prefix is **reserved** for upstream meta-skills.

## Steps

### 1. Locate the umbrella & discover the engine
Find the dir containing `config.yaml` → `<umbrella>`. Then find the engine by
role: search `<umbrella>` (one level deep) for a directory `<M>` with both
`<M>/scripts/sync.sh` and `<M>/scripts/VERSION`.

- Several candidates → pick the one with the highest `scripts/VERSION`.
- A module engine exists → use it; **never** fall back to a flat
  `<umbrella>/scripts/` even if present (that's stale legacy).
- No module engine, only flat `<umbrella>/scripts/` (or nothing) → this is a
  pre-0.3.1 / un-bootstrapped project; go to step 2's bootstrap.
- No `config.yaml` at all → not bootstrapped; point the user at upstream
  `INIT.md` and stop.

### 2. Fetch upstream & ensure a current engine is present
Clone upstream into a temp dir (default
`https://github.com/ainova-systems/intelligence-sync`, or the user's
`REPO_URL`/fork). The upstream module is always `intelligence/sync/`.

Place/refresh it so a current, migration-aware engine exists locally even on
a pre-0.3.1 project:

```
git clone --depth=1 <repo> <tmp>
mkdir -p <umbrella>/sync
cp -r <tmp>/intelligence/sync/. <umbrella>/sync/
```

(Idempotent and authoritative — `update.sh` re-clones internally.)

### 3. Understand what is changing (changelog-aware)
Read `<tmp>/CHANGELOG.md`. Determine the project's current version (the
`intelligence_sync_version` value in `config.yaml`, or "pre-0.3.1" if the key
is absent) and the engine version (`<tmp>/intelligence/sync/scripts/VERSION`).

For every release **strictly between** the project version and the engine
version, read its entry. Pay special attention to any **`### Breaking`**
subsection (the machine-distinguishable marker for breaking changes). Build a
short list of: breaking items, new migrations, and anything the user must know
or that you must verify afterward. Surface this to the user before applying
(and, without `--yes`, let them confirm).

### 4. Run the engine
```
bash <umbrella>/sync/scripts/update.sh --yes   # omit --yes to confirm the diff
```
Capture stdout; find the last `IS_STATUS=<code> [IS_DETAIL=...]` line.

### 5. Branch on `IS_STATUS`

| Code | Meaning | Action |
|---|---|---|
| `ok` | Already current | Go to step 6. |
| `migrated` | Migration chain applied | Go to step 6; note the relocation/changes. |
| `aborted-incomplete` | Staged module incomplete; legacy intact (safe) | Re-run step 2–4 once (clone hiccup). Persists → show output, stop, don't hand-fix. |
| `ahead-of-engine` | Project schema newer than this engine | Do **not** downgrade. Point `REPO_URL` at the correct/newer upstream, or accept it's already ahead. Stop. |
| `needs-update` | Pending breaking changes (sync refused) | Expected pre-migration; proceed — `update.sh` is the migrator. If it persists *after* update, investigate. |
| `config-missing` | No `config.yaml` | Not bootstrapped — direct user to `<umbrella>/sync/INIT.md`. Stop. |
| `error` | Engine couldn't proceed | Show message; check `REPO_URL`. Stop. |
| *(no status)* | Engine crashed before contract | Show full output; don't modify the tree. Stop. |

Genuinely **ambiguous** tree (e.g. both a legacy flat `<umbrella>/scripts/`
and a populated module, no clear `intelligence_sync_version`): inspect both,
summarize the difference, ask the user which is authoritative, apply their
choice. Never guess.

### 6. Verify (always, after `ok`/`migrated`)

Structural — always:
- No `intelligence-*` directory directly under `<umbrella>/skills/`
  (meta-skills live only in the module's `skills/`).
- Project content intact: `<umbrella>/{rules,agents}/` and any
  non-`intelligence-` skills untouched.
- `config.yaml` has `intelligence_sync_version` equal to the engine
  `scripts/VERSION`, and `sources.skills` includes the module skills path
  exactly once.

Changelog-driven — per release crossed:
- For each **`### Breaking`** item in the crossed range, verify its stated
  post-condition actually holds (e.g. a removed/renamed file is gone, a
  config-schema change is reflected). If a breaking item has no verifiable
  post-condition, state that you could not auto-verify it.

Then regenerate IDE outputs:
```
bash <umbrella>/sync/scripts/sync.sh
```
Relay any model-drift report. Finally summarize: versions before→after, the
breaking changes applied, verification result, anything the user must act on.
Clean up the temp clone.

## Notes

- Everything is **idempotent**. Re-running on a current project is a safe
  no-op (`IS_STATUS=ok`).
- Correctness rests on the engine's idempotent structural preconditions, not
  on the version stamp — a missing/wrong `intelligence_sync_version` cannot
  cause a needed migration to be skipped; it only weakens the
  `ahead-of-engine` guard until re-stamped.
- Never touch `config.yaml` beyond what the engine does (the idempotent
  `sources.skills` line and the `intelligence_sync_version` key). Never
  move/delete project skills, rules, or agents.
- Sibling modules beside the engine module are independent — only operate on
  the discovered engine module.
