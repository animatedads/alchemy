# oorexx.process/0.1

## ProcessSpec

Required: `argv` Array.

Mutable fields: `cwd`, `environment`, `stdinBytes`, `stdoutPolicy`, `stderrPolicy`, `timeoutMs`, `maxOutputBytes`, `detach`, `processGroup`.

Policies in dev1: `CAPTURE`, `INHERIT`, `DISCARD`. `STREAM` is reserved and fails closed.

`maxOutputBytes` is an aggregate retained-output bound across captured stdout and stderr. Pipes continue to be drained after the bound is reached; `ProcessResult~outputTruncated` records the loss.

## ProcessRunner

- `run(spec) -> ProcessResult`
- `provider`
- `capabilities`

## ProcessResult

Distinguishes provider/setup failure (`started == .false`) from process failure (`started == .true`, non-zero exit/signal/timeout).

Important fields: `started`, `pid`, `termination`, `exitCode`, `termSignal`, `timedOut`, `stdout`, `stderr`, `outputTruncated`, `durationMs`, provider/error fields.
