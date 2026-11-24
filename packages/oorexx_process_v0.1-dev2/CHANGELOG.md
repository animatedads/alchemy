# Changelog

## 0.1-dev2 (2026-11-24, Claude (Opus 5.5); architecture Tom Dyer)
- Descriptor stdio (stdinDescriptor; stdoutPolicy DESCRIPTOR with stdoutDescriptor).
- Detached start returning RUNNING and the pid; reap(pid) and signal(pid, number, group).
- Every descriptor above 2 is close-on-exec in the child; signal mask cleared; SIGPIPE default.
- tests/run_dev2.sh and tests/test_dev2.rex; integration.json for autobuild.

## 0.1-dev1
- As delivered: synchronous argv-first execution with capture, inherit or discard.
