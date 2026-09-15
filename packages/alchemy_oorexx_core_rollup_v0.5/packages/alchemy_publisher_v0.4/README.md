# Alchemy Publisher v0.3

Publication policy remains separate from execution. FAIL never publishes; PASS
may publish; an identical accepted target is a no-op; a differing existing
target is a hard collision.

Accepted-main writes are performed by `AlchemyGitMainTransaction`, which now
retains the shared repository lease through commit, push and worktree cleanup.
