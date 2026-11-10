# Scotty Computer v0.1-dev10 — process-group lifetime correction

## Scope

- The dev9 package remains the source baseline.
- `ComputerJobs.confirm` now starts ordinary and exception-observed jobs in a
  new POSIX session, recording `termination_attempt` and `termination_scope`.
- At the **job timeout**, Computer kills the POSIX process group, reaps the
  leader and records `TIMEOUT`/`child_rc=124`. The worker need not have
  registered any exception rules to benefit.
- **Exceptions never cause termination.** Threshold breaches are reported
  separately from the child's exit code.
- A detached grandchild in another process group or an already running
  remote operation cannot be guaranteed terminated; the record describes
  the attempt, not a universal outcome. On non-POSIX platforms only the
  direct child is targeted.
- `tests/test_dev10_lifecycle.py` exercises both ordinary and
  exception-observed jobs with a live spawned grandchild. The grandchild
  would create a marker if left running after the timeout.

## Authority boundary

The timeout is already an operator-reviewed part of the registered
job definition. No new privilege, unapproved kill intention, background
monitor, network port or remote process-control facility is introduced.

## Qualification

2026-10-27 full serial qualification: 88 Python tests and 6 native suites PASS.
See `docs/QUALIFICATION.txt` for the exact qualification boundary. The strict
standard is a fresh extraction with real ooRexx and the regression suite;
no offline fixture qualifies live ED209 connectivity.
