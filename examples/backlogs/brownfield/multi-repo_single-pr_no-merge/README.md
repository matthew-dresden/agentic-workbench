# Example: mpm-deps-work (multi-repo, single-PR, no-manual-merge)

A real-world Workbench backlog promoting `before/spec/mpm-list-add-lock-features-spec.md`
into **207 work units across 13 epics + 14 features** driving three target repos
in coordinated single-PR-per-repo runs with auto-finalize, auto-merge, and
CI-failure retry. `workbench validate-backlog` passes clean.

## `before/` vs `after/`

This example is laid out so you can compare **what we started with** to
**what Workbench actually produced** once the backlog ran end-to-end.

| Folder | What it holds |
|---|---|
| [`before/`](before/) | The complete authored backlog at the moment it passed `workbench validate-backlog`. 207 work-unit files, the locked spec, templates, configuration, launch commands -- everything required to kick off a Workbench run. Production code in the three target repos is unchanged from upstream `main`. |
| [`after/`](after/) | **Coming Soon.** The same backlog AFTER Workbench has executed every work unit and merged the resulting PRs. Will hold the post-run snapshot of `BACKLOG.md` (every row `done`), the three target-repo trees at the post-merge SHA, the per-task TDD cycle logs, judge verdicts, CI run summaries, and the cost report. |

When the run completes, the `after/` snapshot will live alongside `before/`
so readers can see at a glance:

- which work units `done` vs `declined` vs `materialised-as-proposals`,
- the actual diff Workbench produced in each target repo,
- the judge feedback that drove each retry,
- the total wall-clock + cost figures.

## What this example demonstrates

| Capability | How it shows up here |
|---|---|
| **Multi-repo orchestration** | `before/backlog/config/workbench.yaml` declares three repos: `matthew-dresden/mpm`, `example-org/private-mpm`, `matthew-dresden/mpm-claude-marketplaces`. Every work unit declares which repo it targets. |
| **Single PR per repo** | `git_ops.single_branch: feat/mpm-deps-work-2026-05` -- every task commits to the shared branch. `defer_pr: true` keeps commits local until `git-ops-finalize`. |
| **No manual merge gate** | `auto_finalize: true` + `auto_merge: true` + `pause_before_merge: false`. The orchestrator pushes, opens PRs, watches CI, and squash-merges automatically once CI is green and review-bot decisions settle. The operator never touches `gh pr merge`. |
| **CI-failure retry** | `ci_failure_retry: true`. When CI fails, the failing-job log is fed back to the executor as feedback for the next retry inside the executor retry budget (`max_executor_retries: 10`). |
| **PR review-comment polling** | `pr_review_resolution.enabled: true` + `decision_blocks: true`. The orchestrator polls `gh pr view` between CI-pass and merge for review-bot comments (Copilot, Amazon Q, internal services); `reviewDecision == CHANGES_REQUESTED` is a hard merge-block regardless of bot allowlist. |
| **Manifest amendment + task factory** | `manifest_amendment.enabled: true` (TDD-green production fixes), `task_factory.enabled: true` + `auto_accept_proposals: true` (the blocker-resolver decomposes out-of-scope work into proposed drafts; the orchestrator promotes them automatically). |
| **Brownfield realism** | Backlog edits THREE pre-existing repos (none of which were created for this example). Migration paths cover deprecation shims (E6 `mpm bootstrap`), bundled-content removal (E6-F2 catalog mirror), per-entry XML migration (E11), and read-only audit-only repos (E13). |
| **Validate-backlog clean** | Every work unit passes the 20 backlog-contract rules: H1 heading, status, dep DAG acyclic, manifest conflicts serialised, source/test atomicity, no em-dashes, no orphan path tokens, AC/DoD/Manifest internally consistent. |

## Mode in one phrase: single-PR + no-manual-merge

The mode name `multi-repo_single-pr_no-merge` means:
- **multi-repo**: three target repos, coordinated as siblings under one
  `WORKBENCH_WORKSPACE_ROOT`.
- **single-pr**: one PR per repo (`single_branch` + `defer_pr`).
- **no-merge**: no manual merge step required from the operator
  (`auto_finalize` + `auto_merge` ON, `pause_before_merge` OFF). Workbench does
  the entire push -> PR -> CI -> merge cycle.

If you want a **paused-merge** variant for environments that require human
final-merge approval, flip the toggles in your copy of `workbench.yaml`:

```yaml
git_ops:
  auto_finalize: true
  auto_merge: false              # don't auto-merge
  pause_before_merge: true       # operator approves merge via `workbench check-merge`
```

## Contents

```
.
├── README.md                        # this file
├── how-it-was-made.md               # step-by-step authoring journey + lessons
├── before/                          # the validated, ready-to-run backlog
│   ├── backlog/                     # 207 work-unit files across 13 epics + 14 features
│   │   └── config/workbench.yaml     # ALL toggles explicit (no hidden defaults)
│   ├── BACKLOG.md                   # Status Summary + Full Work Unit Index
│   ├── spec/                        # Locked spec the backlog implements
│   │   └── mpm-list-add-lock-features-spec.md
│   ├── templates/                   # AC-FINAL + Code Standards block templates
│   ├── workbench-commands.txt        # 5 launch commands (start / interactive / report / hook-tail / status)
│   ├── mpm/                       # PLACEHOLDER -- real run symlinks to matthew-dresden/mpm
│   ├── private-mpm/       # PLACEHOLDER -- real run symlinks to example-org/private-mpm
│   └── mpm-claude-marketplaces/   # PLACEHOLDER -- real run symlinks to matthew-dresden/mpm-claude-marketplaces
└── after/                           # post-run snapshot (Coming Soon)
    └── README.md                    # explains what will land here
```

## Setting up the Workbench environment

Workbench has two required environment variables and a specific on-disk
workspace shape. This example follows the canonical layout.

### Environment variables

| Variable | Value used here | What it does |
|---|---|---|
| `WORKBENCH_WORKSPACE_ROOT` | absolute path to your local `mpm-deps-work/` | Tells Workbench where `BACKLOG.md` and the target-repo siblings live. Every subcommand resolves paths relative to this. |
| `WORKBENCH_CLAUDE_MODEL` | `us.anthropic.claude-opus-4-7-v1` | SDK caller's model -- governs the orchestrate skill's coordination calls. Per-agent work models live in the `agents:` block of `workbench.yaml` (ADR-25) and default to each agent's `.md` frontmatter setting. |
| `WORKBENCH_USE_BEDROCK` (optional) | unset (defaults to Anthropic API) | Set to `1` to route LLM calls through AWS Bedrock instead of the Anthropic API. |
| `GH_TOKEN` (optional) | unset | If pre-configured, the start scripts skip the interactive `gh auth login` flow. |

These are the same variables shown at the top of every command in
`before/workbench-commands.txt`.

### The symlink layout

`WORKBENCH_WORKSPACE_ROOT` is the **parent directory** that holds both
`BACKLOG.md` and the target-repo checkouts as siblings. With three target
repos cloned alongside the backlog and symlinked in, the layout looks like:

```
~/work/                                  # any parent directory
├── mpm/                               # real clone of matthew-dresden/mpm
├── private-mpm/               # real clone of example-org/private-mpm
├── mpm-claude-marketplaces/           # real clone of matthew-dresden/mpm-claude-marketplaces
└── mpm-deps-work/                     # WORKBENCH_WORKSPACE_ROOT (this is its own git repo)
    ├── .git/                            # backlog history -- tracked separately from the target repos
    ├── .gitignore                       # excludes the three symlinks + .workbench/ + logs/
    ├── BACKLOG.md                       # status summary + full work unit index
    ├── backlog/                         # 207 work-unit files (this is what Workbench mutates)
    │   └── config/workbench.yaml         # ALL toggles explicit
    ├── spec/                            # locked spec
    ├── templates/                       # AC-FINAL + code-standards templates
    ├── workbench-commands.txt            # 5 launch commands
    ├── mpm -> ../mpm                              # SYMLINK
    ├── private-mpm -> ../private-mpm  # SYMLINK
    └── mpm-claude-marketplaces -> ../mpm-claude-marketplaces  # SYMLINK
```

**Why symlinks:** Workbench's `repos:` map keys names like
`matthew-dresden/mpm` to a `checkout_directory: mpm` -- a path
**relative to `WORKBENCH_WORKSPACE_ROOT`**. Symlinks let you keep each target
repo as an independent clone (so you can `git pull` it without touching the
backlog) while still letting Workbench resolve `${WORKBENCH_WORKSPACE_ROOT}/mpm`
to the real working tree.

The symlinks are **`.gitignored` in the backlog repo**, so committing the
backlog never accidentally drags in code from the target repos. The target
repos manage their own git history independently.

### Why the backlog is its own local git repo

Putting `mpm-deps-work/` under its own `git init` is more than a tidiness
move -- it is the primary way the operator **observes Workbench's behaviour
in real time**.

Workbench mutates files in `mpm-deps-work/` constantly: every status
transition rewrites the matching row in `BACKLOG.md`, every TDD cycle appends
a line to the work-unit's `## TDD Cycle Log`, every judge verdict appends a
log line, every comment from agents lands in `## Comments`, every proposal
materialises a new draft `.md` file. With the directory under git, every one
of those changes shows up in:

```bash
cd mpm-deps-work
watch -n 5 'git status --short && echo --- && git diff --stat HEAD'
# or, for the running narrative:
git log --oneline --since='10 minutes ago' --all
```

That stream is the cheapest possible introspection: no extra logging
plumbing, no special viewer, no daemon. The git working tree IS the audit
trail. When the operator wants to know what Workbench changed in the last
hour, `git log` answers in milliseconds.

The `.gitignore` excludes the three target-repo symlinks AND Workbench's
runtime state (`.workbench/`, `logs/`), so the backlog repo's diff only ever
reflects backlog mutations -- never target-repo code changes (those live in
their own clones with their own history).

A useful side-effect: once the run finishes, you can `git log -p` the
backlog repo to reconstruct **every** status promotion, judge feedback,
proposal materialisation, and audit-marker addition in chronological order.
That history is what populates the `after/` snapshot when the run completes.

## To run the `before/` backlog against the real repos

```bash
# 1. Clone this example to a workspace of your choice.
git clone <your-fork-of-workbench> ~/work/workbench
cp -r ~/work/workbench/examples/backlogs/brownfield/multi-repo_single-pr_no-merge/before \
      ~/work/mpm-deps-work
cd ~/work/mpm-deps-work
git init && git add -A && git commit -m "Initial backlog snapshot from example"

# 2. Replace the three placeholder dirs with real checkouts (or symlinks).
rm -rf mpm private-mpm mpm-claude-marketplaces
cd ..
git clone git@github.com:matthew-dresden/mpm.git mpm
git clone git@github.com:example-org/private-mpm.git private-mpm
git clone git@github.com:matthew-dresden/mpm-claude-marketplaces.git mpm-claude-marketplaces
cd mpm-deps-work
ln -s ../mpm mpm
ln -s ../private-mpm private-mpm
ln -s ../mpm-claude-marketplaces mpm-claude-marketplaces

# 3. Validate the backlog locally (sanity check).
WORKBENCH_WORKSPACE_ROOT=$PWD \
WORKBENCH_CLAUDE_MODEL=us.anthropic.claude-opus-4-7-v1 \
uv run --project ~/work/workbench workbench validate-backlog

# 4. Launch Workbench. See workbench-commands.txt for the 5 standard invocations.
#    The backlog repo's `git log` will show every change Workbench makes
#    in real time -- run `watch git log --oneline -10` in a side terminal.
```

The five operator commands live in `before/workbench-commands.txt`. The same
file ships at `/path/to/mpm-deps-work/workbench-commands.txt` in any live run.

## See also

- [`how-it-was-made.md`](how-it-was-made.md) -- comprehensive step-by-step
  journey from spec lock to validated backlog (every iteration, every
  validator finding, every fix).
- [`operator-interventions.md`](operator-interventions.md) -- running log of
  every operator decision made WHILE Workbench was processing this backlog
  (recovery actions, scope authorisations, workbench bugs filed). Updated
  as the run progresses.
- [`../../../README.md`](../../../README.md) (workbench README) -- the
  canonical project README; links back to this example under "Real-world
  backlog examples".
- [`../../../docs/backlog-contract.md`](../../../docs/backlog-contract.md) --
  the 20 rules every work unit must satisfy; this example passes them all.
- [`../../../docs/creating-specs-and-backlogs.md`](../../../docs/creating-specs-and-backlogs.md) --
  the authoring guide this example follows.
