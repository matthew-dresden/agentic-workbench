# `private-mpm/` -- target repo placeholder

In a live run of this example, this directory is a **symlink** to a checkout
of `example-org/private-mpm` (the private manifest repo holding
`*-marketplace.xml` entries). Workbench reads `backlog/config/workbench.yaml`,
sees `example-org/private-mpm` in the `repos:` map with
`checkout_directory: private-mpm`, and operates against this path.

The example ships an empty placeholder directory so the backlog and the spec
can be reviewed without cloning the underlying repo. To actually execute the
backlog against the real repo:

```bash
cd <your-workspace-root>
rm -rf private-mpm
git clone git@github.com:example-org/private-mpm.git private-mpm
# or, if the repo is already cloned elsewhere as a sibling:
# ln -s ../private-mpm private-mpm
```

Then launch Workbench with the commands in `workbench-commands.txt`.
