# `mpm/` -- target repo placeholder

In a live run of this example, this directory is a **symlink** to a checkout of
`matthew-dresden/mpm` (the open-source mpm CLI). Workbench reads
`backlog/config/workbench.yaml`, sees `matthew-dresden/mpm` in the `repos:`
map with `checkout_directory: mpm`, and operates against this path.

The example ships an empty placeholder directory so the backlog and the spec
can be reviewed without cloning the underlying repo. To actually execute the
backlog against the real repo:

```bash
cd <your-workspace-root>
rm -rf mpm
git clone git@github.com:matthew-dresden/mpm.git mpm
# or, if the repo is already cloned elsewhere as a sibling:
# ln -s ../mpm mpm
```

Then launch Workbench with the commands in `workbench-commands.txt`.
