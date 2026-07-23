# Migration: workbench 0.3.0 → 0.4.0 (plugin split, issue #224)

## What changed

`workbench@workbench` v0.3.0 was a single plugin that shipped both the
spec / backlog authoring skills AND the orchestrate execution path.
The two audiences have opposing policies for `backlog/*.md`: the
authoring skills MUST write fresh work-unit files; the executor sub-
agents MUST NOT.  The `guard-work-unit-write.sh` PreToolUse hook
correctly blocked the executor and incorrectly blocked the authoring
skill as collateral damage.

Issue #224 splits the single plugin into two:

| New plugin | Lives at | Use during |
|---|---|---|
| `workbench-orchestrate` | `plugin/workbench-orchestrate/` (orchestrate marketplace at `plugin/`) | Autonomous execution phase |
| `workbench-authoring` | `plugin-authoring/workbench-authoring/` (authoring marketplace at `plugin-authoring/`) | Spec / backlog authoring phase |

Both ship from the same `matthew-dresden/agentic-workbench` repo (two
marketplaces nested at sibling directory roots in one repo — same
pattern as `matthew-dresden/mpm-claude-marketplaces`).

## Migration steps

### Step 1 — Uninstall the old plugin at every scope

The pre-split plugin slug was `workbench@workbench`.  Check and remove
it at every enablement scope:

```bash
# Show every installed plugin entry (user scope):
cat ~/.claude/plugins/installed_plugins.json | jq -r '.plugins | keys[]'
# If "workbench@workbench" appears, uninstall:
claude plugin uninstall workbench@workbench --scope user 2>/dev/null

# Check every workspace settings.json for enablement:
grep -rln '"workbench@workbench"' \
  ~/.claude/settings.json \
  /workspaces/*/.claude/settings.json \
  /workspaces/*/*/.claude/settings.json 2>/dev/null

# For each match, remove the line manually (the plugin no longer exists;
# Claude Code will warn on session start otherwise). Or delete the file
# if it contains only the enablement entry.
```

### Step 2 — Register the new marketplace(s)

Decide which phase you're working in and register the matching
marketplace.  **Use project scope, not user scope** (a user-scope
install means the plugin loads in every Claude Code session on this
machine, including unrelated sessions for the other phase, re-creating
the conflict the split was designed to eliminate).

#### Authoring workspace

```bash
cd /path/to/your/spec-authoring-workspace
claude plugin marketplace add /path/to/workbench/plugin-authoring
claude plugin install workbench-authoring@workbench-authoring --scope project
```

Or by git source (sparse-checkout):

```bash
claude plugin marketplace add matthew-dresden/agentic-workbench --sparse plugin-authoring
claude plugin install workbench-authoring@workbench-authoring --scope project
```

#### Orchestrate workspace

```bash
cd /path/to/your/execution-workspace
claude plugin marketplace add /path/to/workbench/plugin
claude plugin install workbench-orchestrate@workbench --scope project
```

Or by git source:

```bash
claude plugin marketplace add matthew-dresden/agentic-workbench
claude plugin install workbench-orchestrate@workbench --scope project
```

### Step 3 — Verify the install landed at the right scope

```bash
# Project scope: should contain the new plugin entry, NOT the old one:
cat .claude/settings.json | jq '.enabledPlugins'

# User scope: should NOT contain any workbench-* enablement
# (per the concurrency rule above):
cat ~/.claude/settings.json | jq '.enabledPlugins // {}'
```

### Step 4 — Restart Claude Code

Plugin install / uninstall does not take effect in an active session.
Quit and re-launch `claude` to pick up the new plugin index.

### Step 5 — Invoke the renamed skill

Skill invocations now use the new plugin name:

| Old (v0.3.0) | New (v0.4.0) |
|---|---|
| `Skill(skill="workbench:spec-to-backlog", ...)` | `Skill(skill="workbench-authoring:spec-to-backlog", ...)` |
| `Skill(skill="workbench:create-spec", ...)` | `Skill(skill="workbench-authoring:create-spec", ...)` |
| `Skill(skill="workbench:configure-workbench", ...)` | `Skill(skill="workbench-authoring:configure-workbench", ...)` |
| `Skill(skill="workbench:bootstrap-environment", ...)` | `Skill(skill="workbench-authoring:bootstrap-environment", ...)` |
| `Skill(skill="workbench:orchestrate", ...)` | `Skill(skill="workbench-orchestrate:orchestrate", ...)` |

## Concurrency scenarios

| Scenario | Workspace A install | Workspace B install | Outcome |
|---|---|---|---|
| Author backlog in A, orchestrate executes a different backlog in B (concurrent) | `workbench-authoring` at project scope in A | `workbench-orchestrate` at project scope in B | Each session sees only its own plugin.  Authoring's writes to `A/backlog/*.md` are unblocked. Orchestrate's guard hooks fire only in B. No cross-talk. |
| Author backlog and immediately run orchestrate against it in the same workspace | First install authoring at project scope, materialise the backlog, then uninstall authoring at project scope and install orchestrate at project scope. | -- | Sequential, not concurrent.  The authoring plugin is gone before orchestrate runs. |
| Install at user scope to "avoid having to install per workspace" | DON'T. | DON'T. | The plugin whose hooks fire most broadly (orchestrate) blocks writes in any session that legitimately needs them (authoring, ad-hoc backlog edits, even manual backlog tweaks via Claude Code).  This is exactly the failure mode the split was designed to prevent. |

## What didn't change

- The `workbench` Python CLI in `src/workbench/` is unchanged
  apart from two narrow constant edits noted in the CHANGELOG.
  All `uv run workbench ...` invocations work identically.
- The orchestrate skill's runtime behaviour is unchanged.
- Every agent prompt, hook script, and guard's allow / block logic
  is unchanged.  Three new regression tests
  (`tests/test_plugin/test_orchestrate_isolation.py`,
  `test_executor_guard_unchanged.py`,
  `test_work_unit_write_block_message.py`) pin the exact PreToolUse
  hook list and the guard-work-unit-write error format so future
  drift fails locally.
- ADRs and historical CHANGELOG entries are NOT rewritten — the
  pre-split paths in those entries are accurate snapshots of the
  state at the time those changes landed.

## Troubleshooting

**Q: `claude plugin install workbench-orchestrate@workbench` says
"plugin not found".**

A: Run `claude plugin marketplace update workbench` first to refresh
the marketplace cache, then retry the install.  If the marketplace was
registered before the v0.4.0 split landed, its cached manifest still
lists the OLD plugin name `workbench`.

**Q: Spec-to-backlog still says "Unknown skill: workbench:spec-to-
backlog".**

A: The skill is now `workbench-authoring:spec-to-backlog` (and ships
from the authoring marketplace).  Either invoke it with the new name
or, if Claude Code itself is using the old slug, restart your session.

**Q: My orchestrate runs fail at `cmd_start` with
"plugin not found at plugin/workbench/...".**

A: You're running an old `workbench` Python build.  Pull the v0.4.0
source — `DEFAULT_PLUGIN_SUBPATH` was updated to
`plugin/workbench-orchestrate` in the same commit as the rename.
