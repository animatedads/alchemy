# oorexx_logging_stream_target v0.1

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), 14 Nov 2026
- **Written by:** Claude (Opus 5.5)

This package lets an estate tool show its run as it happens, through oorexx_logging rather than ad hoc `say` lines.

oorexx_logging v0.7 ships memory and queue targets only. `LogStreamTarget` is an ordinary v0.7 target, with `NAME` and `ACCEPT`, that writes one line per event to a stream (`.error` by default). Every event still passes through `LogService`, `LogRule` levels and scopes. v0.7 is not modified. This target belongs in oorexx_logging v0.8.

`ToolProgress` sets up a service, a stream target and a rule for one tool object:

```rexx
progress = .ToolProgress~new("python-gate", gate, "RUN")   -- INFO and up, to stderr
gate~useLogger(progress~logger)
```
```
20261114T20:53:58.677643 WARN  python-gate: UNJUSTIFIED python-call main.rex
```

`progress~quiet` turns it off. Users today: `oorexx_python_gate_v0.1`, plus `corpus_inventory.rex` and `verify_release_archives.rex` in `oorexx_rc_executable_tree`.

Test:

```
rexx packages/oorexx_logging_stream_target_v0.1/tests/test_log_stream_target.rex
```
