# Scotty Computer dev10: foreground execution lifetime

## Delivered

- Use `subprocess.Popen(..., start_new_session=True)` for POSIX local
  execution, including the local `sshnode.sh` helper process.
- On registered wall-time timeout (1–1800 s), signal the isolated process
  group with SIGTERM; after a short grace period, attempt SIGKILL if the group
  still exists; reap the immediate child where possible.
- Preserve 124/TIMEOUT and record termination metadata as evidence.
- Registered `runaway_space`, `runtime_overrun`, and `output_contains` rules
  only report conditions; none triggers termination.
- Remote processes, detached sessions, Linux uninterruptible processes,
  orphan reaping and other external effects are **not** proven terminated.
- New regression tests exercise a shell-equivalent child spawn and timeout,
  including registered output exception, plus a healthy fast exit.

## Qualification

Run `python3 -m unittest discover -s tests -p 'test_*.py'` and
`bash tools/qualify.sh` with a real ooRexx interpreter.
The currently running Autobuilder is unavailable; publication of the source
tree is not an Autobuild acceptance receipt.
