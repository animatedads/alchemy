# ooRexx Process v0.1-dev1

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
