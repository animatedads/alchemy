# Alchemy Executor v0.3

Execution semantics are unchanged from v0.2: the executor consumes a
transport-neutral materialized package and an already-resolved dependency floor,
constructs exact per-test environments through the package model, executes argv
without shell inference, and records timeout/non-zero outcomes.

v0.3 is an immutable-version cut for the Transport v0.3 / repository-lease
closure; v0.2 is not rewritten.
