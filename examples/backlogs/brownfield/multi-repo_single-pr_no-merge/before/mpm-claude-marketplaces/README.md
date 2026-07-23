# `mpm-claude-marketplaces/` -- target repo placeholder

In a live run of this example, this directory is a **symlink** to a checkout
of `matthew-dresden/mpm-claude-marketplaces` (a sibling catalog repo audited
read-only by epic E13). Workbench reads `backlog/config/workbench.yaml`, sees
`matthew-dresden/mpm-claude-marketplaces` in the `repos:` map with
`checkout_directory: mpm-claude-marketplaces`, and operates against this
path.

The example ships an empty placeholder directory so the backlog and the spec
can be reviewed without cloning the underlying repo. To actually execute the
backlog against the real repo:

```bash
cd <your-workspace-root>
rm -rf mpm-claude-marketplaces
git clone git@github.com:matthew-dresden/mpm-claude-marketplaces.git mpm-claude-marketplaces
# or, if the repo is already cloned elsewhere as a sibling:
# ln -s ../mpm-claude-marketplaces mpm-claude-marketplaces
```

Then launch Workbench with the commands in `workbench-commands.txt`.
