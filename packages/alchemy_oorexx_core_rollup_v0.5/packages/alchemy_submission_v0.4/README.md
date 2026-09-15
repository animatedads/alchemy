# Alchemy Submission v0.3

Canonical ooRexx producer-side Git submission transport.

The sender validates the package through the package model, acquires the shared
repository lease, creates a temporary detached worktree from accepted main,
commits package body, commits `ready.json` last, and publishes both commits in
one push.  The developer checkout is never switched or cleaned.
