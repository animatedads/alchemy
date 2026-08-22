# alchemy_autobuild v0.5

v0.5 extends v0.4.2 with branch-tree Git intake.

Remote AI branches are transport envelopes. The runner fetches refs, finds newly-added
`autobuild/inbox/<id>/ready.json` markers relative to each branch merge base, and
materializes only the referenced package subtree using `git archive`. It never
checks out, merges, or rebases a submission branch into `main`.

The canonical producer helper is repository-root `tools/alchemy_submit.py`. It uses
two commits (package body, then ready marker) and one push.
