# ooRexx Process v0.1-dev2

**Architecture:** Tom Dyer. **Coding:** dev1 as delivered; dev2 by Claude (Opus 5.5), 24 November 2026. **This section written by:** Claude (Opus 5.5).

## dev2 added

What the XTP daemon (xtpd) needs to start a hook on one end of a socketpair:

- **Descriptor stdio.** `spec~stdinDescriptor = fd` gives the child that open descriptor as stdin; `spec~stdoutPolicy = 'DESCRIPTOR'` with `spec~stdoutDescriptor = fd` gives it as stdout. A closed or missing descriptor fails closed (`STDIN_FD`, `STDOUT_FD`).
- **Detached start.** `spec~detach = .true` returns at once with `termination 'RUNNING'` and the pid. An exec failure is still a start failure (`EXEC`). Detach together with captured output, stdin bytes or a timeout is refused (`DETACH_CONFLICT`), because nothing would be left to drain or time them.
- **`ProcessRunner~reap(pid)`** returns the outcome without waiting: `RUNNING`, `EXIT`, `SIGNAL` or `GONE`.
- **`ProcessRunner~signal(pid, number, group)`** sends a signal to the child or to its process group.
- **No inherited descriptors.** Every descriptor above 2 is marked close-on-exec in the child, in every mode. dev1 let the parent's descriptors reach the child: a probe child held 7 descriptors under dev1 and only its own under dev2. The signal mask is cleared and SIGPIPE restored to its default before exec.

Tests: `tests/run_dev2.sh` builds the provider in a temporary copy, runs dev1's `test_smoke.rex` and `test_contract.rex` unchanged, then `test_dev2.rex`. Removing the close-on-exec step makes `test_dev2.rex` fail.

# ooRexx Process v0.1-dev1 (as delivered)

API: `oorexx.process/0.1`

`oorexx_process` is an independent platform library for managed process execution. It is deliberately **not** part of `oorexx_posix`.

## dev1 implemented

- argv-first execution; no shell is inserted.
- synchronous `ProcessRunner~run(ProcessSpec)`.
- stdout/stderr capture, inherit or discard.
- byte-string stdin.
- cwd selection.
- timeout classification and termination.
- bounded aggregate output capture while continuing to drain child pipes.
- optional child process-group creation.
- normalized `ProcessResult` including exit, signal and timeout outcomes.
- exec/setup failure is distinguished from a child process returning non-zero.

## deliberately unavailable in dev1

- `spawn()` / durable `ProcessHandle`.
- targeted later `wait()` on a returned handle.
- streaming callback output.
- environment overlays.
- detached children.
- start-identity / PID-reuse fencing.
- graceful cancellation policy beyond the run-time timeout path.

Unsupported requested semantics fail closed rather than falling back to shell construction.

## Example

```rexx
runner = .ProcessRunner~new
spec = .ProcessSpec~new(.array~of('/usr/bin/git', 'status', '--porcelain'))
spec~timeoutMs = 5000
result = runner~run(spec)
if result~succeeded then say result~stdout
```

## Build and qualify

```sh
make -C native OOREXX_ROOT=/usr/local
OOREXX_ROOT=/usr/local tests/run.sh
```

The source package does not require or invoke `sh -c` for normal execution.
