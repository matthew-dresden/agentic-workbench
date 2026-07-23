# Workbench Onboarding: Chained-Skill Operator Workflow

This guide walks you through the full skill chain that takes a project idea from zero to
a running autonomous backlog:

```
create-spec -> spec-to-backlog -> configure-workbench -> bootstrap-environment -> make start
```

Each step is a Claude Code marketplace skill. The skills chain together: the output of
one step is the input to the next. By the end of this walkthrough, Workbench is
processing your backlog autonomously.

For deep-dive reference material on any individual skill, see the per-skill quickstart
docs under [`docs/skills/`](skills/).

---

## Prerequisites

Before running any skill in the chain, verify the following are in place:

1. **Claude Code CLI** -- installed and authenticated. Verify with `claude --version`.
   See [`docs/zero-to-ready.md` Step 4](zero-to-ready.md#step-4-authenticate-claude--bedrock)
   for auth options (Anthropic API or AWS Bedrock).

2. **workbench cloned** -- clone the repository and export `WORKBENCH_DIR`:

   ```bash
   git clone https://github.com/matthew-dresden/agentic-workbench.git ~/workbench
   export WORKBENCH_DIR=~/workbench
   make -C $WORKBENCH_DIR install
   ```

3. **Workbench plugin available** -- the four onboarding skills are part of the workbench
   marketplace plugin. Load the plugin per-session (recommended) or install globally:

   ```bash
   # Per-session (recommended -- avoids hook interference with other Claude sessions):
   claude --dangerously-skip-permissions \
     --plugin-dir $WORKBENCH_DIR/plugin/workbench

   # Or globally (read the warning in zero-to-ready.md Step 3 first):
   make -C $WORKBENCH_DIR plugin-install
   ```

4. **Workspace root directory** -- create the directory that will hold your backlog,
   config, and cloned target repos:

   ```bash
   mkdir -p ~/my-workspace/backlog/config
   cd ~/my-workspace && git init
   ```

---

## Step 1: create-spec -- author a rigorous engineering spec

The `create-spec` skill guides you through a structured Q&A and produces a
`spec/<project-name>.md` file that meets the mpm quality bar (1000+ lines for
non-trivial programs, 16 top-level sections, numbered and testable acceptance criteria).

**Invoke:**

```
claude run workbench:create-spec
```

Or from within a Claude Code session loaded with the plugin:

```
run workbench:create-spec
```

**What happens:**

1. The skill reads the mpm spec exemplar to internalise the 16-section structural
   skeleton and the quality bar.
2. It asks a structured question block covering: problem statement, scope, non-goals,
   functional requirements, NFRs, acceptance criteria, and resolved design decisions.
3. It authors the spec one section at a time and runs a bounded self-critique
   loop until the rubric score is zero (`SKILL_QUALITY_THRESHOLD_REACHED`
   audit) or `SKILL_MAX_ITERATIONS` is reached
   (`SKILL_MAX_ITERATIONS_REACHED` audit). The iteration counter is persisted
   in `<workspace>/.workbench/skill-state/create-spec.json` between passes; see
   `src/workbench/skill_state.py`.
4. It asks for your final sign-off, then writes `spec/<project-name>.md`.
5. It offers to invoke `spec-to-backlog` directly as the next step.

**Output:** `spec/<project-name>.md` in the current working directory.

**Reference:** [`docs/skills/create-spec.md`](skills/create-spec.md)

---

## Step 2: spec-to-backlog -- decompose the spec into a backlog

The `spec-to-backlog` skill reads `spec/<project-name>.md` and produces a complete,
validated backlog: `BACKLOG.md` plus work-unit `.md` files under `backlog/` in the
4-level hierarchy (Epic -> Feature -> Story -> Task).

**Invoke:**

```
claude run workbench:spec-to-backlog
```

The skill asks: "Which spec file should I decompose into a backlog?" Provide the path
(e.g., `spec/my-project.md`).

**What happens:**

1. The skill reads the mpm backlog exemplar to internalise the 7-column format and
   the ~50KB-per-task quality bar.
2. It decomposes every functional requirement into the 4-level hierarchy and validates
   the DAG (no cycles, no skipped levels).
3. It authors each leaf task file with all canonical sections and scores each against a
   per-task rubric, iterating until the rubric score is zero.
4. After every task file, it runs `workbench validate-backlog`. Any errors are fixed
   immediately before moving on.
5. It writes `BACKLOG.md` and runs a final `validate-backlog` pass.
6. All generated tasks default to `draft` status -- the orchestrator cannot claim them
   until you promote them with `workbench promote`.

**Output:** `BACKLOG.md` and `backlog/<epic>/.../<task>.md` work-unit files.

**Promote tasks when ready:**

```bash
# Promote a single task:
workbench promote E1-F1-S1-T1

# Promote all tasks under an epic:
workbench promote --epic E1

# Promote everything at once (no confirmation prompt):
workbench promote --all --yes
```

**Reference:** [`docs/skills/spec-to-backlog.md`](skills/spec-to-backlog.md)

---

## Step 3: configure-workbench -- author backlog/config/workbench.yaml

The `configure-workbench` skill walks you through every `RuntimeConfig` section and
produces a valid `backlog/config/workbench.yaml`. Each value is round-tripped through
`RuntimeConfig` parsing immediately after entry; invalid values are rejected with the
parser's error message and you are re-prompted.

**Invoke:**

```
claude run workbench:configure-workbench
```

**What happens:**

1. If `workbench.yaml` already exists, the skill reads it and pre-populates defaults.
   Enter a blank line to accept a shown default.
2. The skill walks through 15 sections: `repos`, top-level scalars, `timeouts`,
   `limits`, `agents`, `git_ops`, `task_factory`, `manifest_amendment`, `validate`,
   `stop_hook`, `hook_tail`, `debug`, `backlog`, `notifications`, and a final write.
3. Each section validates against `RuntimeConfig` before moving to the next.
4. The final `workbench.yaml` is written only after every section validates.

**Minimum required input:** the `repos:` section -- `org/repo` key,
`checkout_directory` (workspace-relative), and `default_branch`.

**Output:** `backlog/config/workbench.yaml` that loads without `ConfigLoader` errors.

**Reference:** [`docs/skills/configure-workbench.md`](skills/configure-workbench.md)

---

## Step 4: bootstrap-environment -- clone repos and run make validate

The `bootstrap-environment` skill prepares every target repository listed in
`backlog/config/workbench.yaml` so that `make validate` passes without manual
intervention beyond yes/no confirmations.

**Invoke:**

```
claude run workbench:bootstrap-environment
```

**What happens:**

1. Reads the `repos:` section from `backlog/config/workbench.yaml`. If the config is
   absent, the skill asks interactively.
2. For each repo: clone to `checkout_directory` if not already present; install the
   asdf toolchain from `.tool-versions` if the file exists; run `make validate` as a
   baseline check.
3. Each step (clone, asdf install, make validate) self-verifies immediately after the
   operation. On first failure the skill logs `[RETRY_*]` and retries once. On a second
   failure it escalates with a clear diagnostic and asks whether to skip this repo.
4. Prints a final summary table showing clone, toolchain, and validate status per repo.

**Output:** each `checkout_directory` has a valid `.git`, the toolchain is installed,
and `make validate` exits 0 for every non-escalated repo.

**Reference:** [`docs/skills/bootstrap-environment.md`](skills/bootstrap-environment.md)

---

## Step 5: make start -- launch the orchestrator

Once the backlog is generated, config is written, repos are bootstrapped, and draft
tasks are promoted to `in-queue`, launch Workbench:

```bash
WORKBENCH_WORKSPACE_ROOT=~/my-workspace \
WORKBENCH_CLAUDE_MODEL=us.anthropic.claude-opus-4-7-v1 \
make -C $WORKBENCH_DIR start
```

Workbench claims work units in dependency order, runs the TDD cycle, submits each result
to the review judges, and lands every passing task as a git commit (and optionally a PR).

**What `make start` does automatically:**

- Claims the next eligible `in-queue` work unit.
- Invokes the executor (implements the task under TDD).
- Runs the five review judges (code, test, doc, changes-manifest, security).
- On REVIEW_PASS: runs git-ops (commit + PR or single-branch commit).
- On REVIEW_FAIL: feeds the judge feedback back to the executor and retries.
- Between work units: checks for a drain request (`workbench drain`) and exits cleanly
  if one is found.

---

## Worked example: onboarding a new Go service

This example shows the chain applied to a real project.

**Setup:**

```bash
mkdir -p ~/payment-service-ws/backlog/config
cd ~/payment-service-ws
git init
export WORKBENCH_WORKSPACE_ROOT=~/payment-service-ws
```

**Step 1 -- create-spec:**

```bash
# Open Claude Code with the plugin loaded:
claude --dangerously-skip-permissions \
  --plugin-dir $WORKBENCH_DIR/plugin/workbench

# Within the session:
run workbench:create-spec
```

Answer the Q&A blocks; the skill produces `spec/payment-service.md`.

**Step 2 -- spec-to-backlog:**

```
run workbench:spec-to-backlog
```

Provide `spec/payment-service.md` when prompted. The skill produces `BACKLOG.md` and
work-unit files. All tasks land in `draft` status.

**Step 3 -- configure-workbench:**

```
run workbench:configure-workbench
```

Enter: `org/repo` = `myorg/payment-service`, `checkout_directory` = `payment-service`,
`default_branch` = `main`. The skill writes `backlog/config/workbench.yaml`.

**Step 4 -- bootstrap-environment:**

```
run workbench:bootstrap-environment
```

The skill clones `github.com/myorg/payment-service` to
`~/payment-service-ws/payment-service`, installs the Go toolchain, and runs
`make validate`. Reports `PASS` when done.

**Review and promote:**

```bash
# Inspect generated tasks:
uv run --project $WORKBENCH_DIR workbench status

# Promote the first epic for autonomous execution:
uv run --project $WORKBENCH_DIR workbench promote --epic E1
```

**Step 5 -- launch:**

```bash
WORKBENCH_WORKSPACE_ROOT=~/payment-service-ws \
WORKBENCH_CLAUDE_MODEL=us.anthropic.claude-opus-4-7-v1 \
make -C $WORKBENCH_DIR start
```

Workbench begins processing tasks autonomously.

---

## Key decisions in the chained workflow

### draft vs in-queue (Step 2)

All tasks generated by `spec-to-backlog` default to `draft` status. Draft tasks are
invisible to the orchestrator -- they cannot be claimed until promoted. This gives you a
review gate between generation and execution: inspect every generated task, tighten
scope, verify Manifests, then release the ones you approve.

To skip the review gate and release all tasks immediately:

```bash
workbench promote --all --yes
```

### Single-PR vs multi-PR (Step 3)

The default mode creates one branch and PR per task. To batch all tasks into one shared
branch, set `git_ops.single_branch` in `workbench.yaml` during Step 3.

### Scoping the run (Step 5)

To process only a subset of the backlog:

```bash
WORKBENCH_WORKSPACE_ROOT=~/payment-service-ws \
WORKBENCH_CLAUDE_MODEL=us.anthropic.claude-opus-4-7-v1 \
uv run --project $WORKBENCH_DIR workbench start --include "E1-E3"
```

See [`docs/zero-to-ready.md` -- Scoping a run](zero-to-ready.md#scoping-a-run) for the
full printer-pages token syntax.

### Stopping cleanly between tasks

```bash
# Request a graceful stop after the current task completes:
uv run --project $WORKBENCH_DIR workbench drain --reason "reviewing E2 tasks"
```

The orchestrator finishes the in-flight task, detects the drain marker between tasks,
and exits cleanly. See [`docs/zero-to-ready.md` -- Stopping a run cleanly](zero-to-ready.md#stopping-a-run-cleanly).

---

## Troubleshooting the chained workflow

| Symptom | Step | Fix |
|---------|------|-----|
| Skill not found in Claude Code | 1-4 | Run `claude plugin list`; if `workbench` is missing, re-run `make -C $WORKBENCH_DIR plugin-install` or use `--plugin-dir` |
| `validate-backlog` fails after Step 2 | 2 | Check the error message; common causes: em-dash in a work-unit file, orphaned file not in BACKLOG.md, dep cycle |
| `ConfigLoader` error after Step 3 | 3 | Re-run `configure-workbench`; the skill re-prompts for invalid values |
| `make validate` fails for a repo in Step 4 | 4 | Resolve the failing sub-target (lint, typecheck, test) manually, then re-run `bootstrap-environment` |
| `WORKBENCH_WORKSPACE_ROOT not set` at Step 5 | 5 | Export the variable: `export WORKBENCH_WORKSPACE_ROOT=~/my-workspace` |
| No tasks eligible after `make start` | 5 | Check `workbench status` -- tasks may still be in `draft`; run `workbench promote` |

---

## Cross-references

- [`docs/skills/create-spec.md`](skills/create-spec.md) -- per-skill quickstart for create-spec
- [`docs/skills/spec-to-backlog.md`](skills/spec-to-backlog.md) -- per-skill quickstart for spec-to-backlog
- [`docs/skills/configure-workbench.md`](skills/configure-workbench.md) -- per-skill quickstart for configure-workbench
- [`docs/skills/bootstrap-environment.md`](skills/bootstrap-environment.md) -- per-skill quickstart for bootstrap-environment
- [`docs/zero-to-ready.md`](zero-to-ready.md) -- manual step-by-step alternative (no skills required)
- [`docs/creating-specs-and-backlogs.md`](creating-specs-and-backlogs.md) -- manual spec and backlog authoring guide
- [`docs/cli-reference.md`](cli-reference.md) -- full CLI command reference
- [`docs/backlog-contract.md`](backlog-contract.md) -- validate-backlog rule set (20 rules)
