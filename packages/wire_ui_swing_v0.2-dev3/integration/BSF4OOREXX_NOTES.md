# BSF4ooRexx integration notes

Target exercised during v0.2-dev3 development: BSF4ooRexx v850 (2026-03-26 refresh) with Open Object Rexx 5.3.0 r13196.

The bridge is deliberately narrow:

```text
ooRexx Wire access point adapter
    -> convert .Table/.Directory/.Array recursively to java.util.Map/java.util.List
    -> WireSwingRuntime.accept(message)

transport pump
    <- WireSwingRuntime.drainOutbound()
    <- WireSwingRuntime.pollAction()
```

Do not expose every `JButton`, `JPanel`, or `JTextField` as an ooRexx application object. If `.AwtGuiThread` is used by a launcher/window shell, it is an additional safety layer; `WireSwingRuntime` still marshals all component work onto the EDT itself.

## Interoperability findings

BSF v850 constructor resolution rejected the otherwise ordinary Java 21 default constructor in this environment. `WireSwingRuntime.create()` is therefore an intentional static factory at the bridge boundary rather than an accidental convenience.

The supplied BSF native loader required the Java 21 server VM directory to be available on `LD_LIBRARY_PATH`. Headless validation also sets:

```text
BSF4Rexx_JavaStartupOptions=-Djava.awt.headless=true
```

These are launcher/environment concerns; they do not change the Wire renderer contract.

## Executed validation

The following are tested, not merely proposed:

1. ooRexx -> BSF -> `WireSwingRuntime.create()` -> Java 21 headless Swing hello/root construction.
2. Recursive ooRexx `.Table/.Array` conversion, definition + snapshot + revisioned patch round trip; final revision 2.
3. Actual Wire UI Server v0.11 `.WireUIElementDefinition`, `.WireUIDefinitionManifest`, `.WireUIProtocol`, and `.WireUIView` objects passed through the bridge into Swing; final revision 1.
4. Actual Wire UI Builder v0.8.3 project publish and compiler output passed through the bridge; compiled GRID12 children render at widths 12/3/5/4/12 with expected rows/columns.

The desktop seam is additionally exercised by `scripts/run_bsf_desktop_tests.sh`, which creates and disposes a real JFrame under Xvfb while keeping the JFrame private inside `WireUISwingBridge`.

See `scripts/run_bsf_tests.sh`, `scripts/run_bsf_desktop_tests.sh`, and `VALIDATION_TRANSCRIPT.txt`.
