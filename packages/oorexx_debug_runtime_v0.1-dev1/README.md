# ooRexx Debug Runtime v0.1-dev1

A provider-neutral semantic debugging model for ooRexx applications.

The application talks about processes, threads, frames, variables, breakpoints,
execution and exceptions. It does **not** talk GDB/MI records, JDWP command sets,
DbgEng COM interfaces or JavaScript debugger protocol messages.

## Application shape

```rexx
session = debugger~attach(target)

session~when(
    .Execution~enters('calculateInvoice')
)~fire(inspector, 'inspectInvoice')

session~continue
```

A control request does not mutate observed execution state. `continue` asks the
provider to continue; `session~state` changes to RUNNING only after the provider
reports that state.

Runtime variables are data-defined and are exposed through `UNKNOWN`:

```rexx
frame~locals~customer
frame~arguments~filename
```

No methods are generated for those names.

## dev1 contents

* `DebugRuntime.cls` — semantic targets, sessions, threads, frames, scopes,
  values, breakpoint registrations, provider SPI and deterministic provider.
* `GdbMi.cls` — GDB/MI record parser and semantic event projector. GDB itself is
  not installed in the qualification environment, so this is transcript-qualified.
* `JdwpWire.cls` — JDWP handshake and packet framing codec.
* `AdbJdwp.cls` — transport seam that opens `jdwp:<pid>` through an existing
  ooRexx ADB session. ADB remains transport/device authority; JDWP remains the
  debug protocol.

The common API is intentionally suitable for projection through Alchemy into
JavaScript or another language without inventing another debugger object model.
