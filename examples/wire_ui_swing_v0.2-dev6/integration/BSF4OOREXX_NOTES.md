# BSF4ooRexx integration notes — v0.2-dev6

Qualified stack:

- Open Object Rexx 5.3.0 r13196 from the uploaded debug-runtime `.deb`.
- BSF4ooRexx v850, 2026-03-26 refresh, using its 64-bit Linux native bridge.
- Java OpenJDK 21.0.11.
- Wire UI Server v0.17, Builder v0.11, Alchemy Objects v0.8, ooRexx Crypto v0.5 from the uploaded API roll-up.

The bridge stays narrow:

```text
ooRexx Wire access-point adapter
    -> recursively convert .Table/.Directory/.Array to java.util.Map/java.util.List
    -> WireSwingRuntime.accept(message)

transport pump
    <- WireSwingRuntime.drainOutbound()
    <- WireSwingRuntime.pollAction()
```

Application code is not given arbitrary Java Swing widget authority. `WireSwingRuntime.create()` remains an intentional static factory for reliable BSF constructor resolution.

The extracted BSF native loader needs the Java server-VM directory and extracted ooRexx libraries on `LD_LIBRARY_PATH`. Headless integration sets `BSF4Rexx_JavaStartupOptions=-Djava.awt.headless=true`; desktop integration uses `-Djava.awt.headless=false` under Xvfb.

## Executed native contracts

1. ooRexx -> BSF -> `WireSwingRuntime.create()` hello/root construction.
2. Recursive ooRexx table/array conversion plus exact definition, snapshot, and revisioned patch round trip to revision 2.
3. Actual Server v0.17 ordered/windowed collection patches, including append/move/remove and collection-window reconciliation, to renderer revision 6.
4. Actual Server v0.17 workspace action context: current context accepted; a queued event retains context A across incoming patch B; the server classifies that historical action as stale; a later action echoes B and is accepted.
5. Actual Builder v0.11 publish/compiler output -> GRID12 Swing composition with widths `12,3,5,4,12` and expected row/column placement.
6. ooRexx -> BSF -> real `WireSwingDesktopWindow` JFrame show/dispose under Xvfb.

See `scripts/run_bsf_tests.sh`, `scripts/run_bsf_desktop_tests.sh`, and `VALIDATION_TRANSCRIPT.txt`.
