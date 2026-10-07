# ooRexx Debug Socket Transport v0.1-dev7

A socket-isolated transport component for provider-neutral ooRexx debugging.

This delivery retains the supporting debugger-core sources used by its qualification tests,
but the component boundary introduced here is `DebugSocketTransport`: it consumes a
selected estate Socket and preserves the provider's complete SocketAddress object.

The application talks about processes, threads, frames, variables, breakpoints,
execution and exceptions. It does **not** talk GDB/MI records, JDWP command sets,
DbgEng COM interfaces or JavaScript debugger protocol messages.

## dev7 — consume the estate SocketStreamAdapter

The current SocketProvider line now exposes a generic `SocketStreamAdapter` with
`READ`, `WRITE`, `PUMP` and `CLOSE`. Debug Socket Transport consumes that adapter
directly via `fromSocketStreamAdapter()`. The adapter is the byte-stream/lifecycle
view; `socketObject()` still returns the exact underlying estate Socket and
`socketAddress()` still returns the exact provider address object. No address or
protocol information is flattened or reconstructed.

The handoff is direction-neutral: selector-produced outbound sockets and
listener-accepted inbound sockets use the same adapter contract. Debug code does
not instantiate `SocketSelector`, `SocketProvider`, listeners, QUIC, XTP or TCP.

This is the Spiral-1 access-class pattern: standard/debug protocol code ->
`DebugSocketTransport` -> estate `SocketStreamAdapter` -> isolated provider.


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

## dev2 socket-isolation increment

`DebugSocketTransport.cls` adds the network transport seam using the estate socket model.
The debugger receives the already-selected **Socket object** and the complete
**SocketAddress object**. It does not create RxSock sockets, parse host/port
strings, choose TCP/QUIC/XTP, or select an XTP carrier.

```text
DebugProvider / JDWP
        |
DebugSocketTransport
        |
    Socket object + SocketAddress object
        |
SocketSelector / SocketProvider
        |
 TCP / QUIC / XTP / Unix / ...
```

This is intentionally object-preserving: Rexx keeps the provider's actual
address/socket object available, rather than flattening it into a Python-style
transport dictionary or primitive tuple.

QUIC is therefore a **socket family/provider implementation**, not a separate
debugger transport architecture. XTP likewise remains behind its SocketProvider;
its L2/L3/L4 route choice and `zero-block` / `crunch` wire filters stay below the
application/debug semantics.

`JdwpSocketTransport` layers JDWP handshake and packet framing over the selected
Socket without acquiring or replacing it. The existing `AdbJdwpTransport`
remains valid for Android: ADB owns the stream, JDWP owns the debug protocol.

## Contents

* `DebugRuntime.cls` — semantic targets, sessions, threads, frames, scopes,
  values, breakpoint registrations, provider SPI and deterministic provider.
* `GdbMi.cls` — GDB/MI record parser and semantic event projector.
* `JdwpWire.cls` — JDWP handshake and packet framing codec.
* `AdbJdwp.cls` — ADB/JDWP transport seam.
* `DebugSocketTransport.cls` — generic selected-Socket seam and JDWP-over-Socket adapter.

The common API is intentionally suitable for projection through Alchemy into
JavaScript or another language without inventing another debugger object model.


## dev4 lifecycle/ownership hardening

`DebugSocketTransport` now makes Socket ownership explicit. `OWNED` remains the
default for compatibility with dev3; `BORROWED` lets a debugger release its view
without closing a Socket owned by a selector, pool, multiplexing layer, or another
consumer. The exact Socket and SocketAddress objects are still retained by identity.

Input validation now rejects negative read/poll timeouts. `JdwpSocketTransport`
uses the generic socket pump/poll seam when a packet read timeout is requested; it
does not create protocol-specific timeout logic.

`qualification/run_environment_test.sh` is the complete host qualification entry
point. It performs package checks and all ooRexx tests and can chain the estate's
real SocketProvider environment qualification through `SOCKET_PROVIDER_ENV_TEST`.


## dev5 selector handoff and directional lifecycle

Dev5 makes the selected-Socket seam usable as a long-lived runtime boundary rather
than only a byte delegation wrapper.

`DebugSocketTransport~fromSelectedSocket(socket)` accepts an estate-selected Socket
without invoking `SocketSelector` itself. When the Socket exposes `socketAddress` (or
`address`), the exact provider-owned address object is retained by identity. The handoff
defaults to `BORROWED`, because selection/acquisition and ownership remain the
SocketProvider's responsibility.

The debug view now tracks read and write directions independently: `OPEN`,
`READ_CLOSED`, `WRITE_CLOSED`, and `CLOSED`. `shutdownRead` / `shutdownWrite` are
view-local for borrowed sockets. For owned sockets they delegate matching provider
shutdown operations when the Socket provides them. There is still no TCP/QUIC/XTP
branching in this component.

Provider return values and exceptions are deliberately not translated into a second
network error vocabulary. A failed owned `close` does not falsely mark the transport
closed. This keeps provider failure semantics authoritative at the socket boundary.


## dev6 accepted-socket handoff

Dev6 makes the socket isolation boundary symmetric for inbound and outbound use.
`fromAcceptedSocket(socket, address)` accepts a Socket that an estate listener has
already accepted. The debugger does not instantiate a listener, call `accept`, infer a
family, or reinterpret a peer endpoint. The exact Socket and SocketAddress objects are
retained by identity.

The address argument is optional only for providers whose accepted Socket already
exposes `socketAddress` or `address`. Where the listener returns the peer address as a
separate object, that object is passed directly and remains intact. The handoff defaults
to `BORROWED`, matching selector handoff: acquisition and ownership are provider/listener
concerns unless the caller explicitly transfers ownership.

Because the factory is inherited, `JdwpSocketTransport~fromAcceptedSocket(...)` creates
a JDWP transport over the already-accepted Socket without a QUIC-, XTP- or TCP-specific
debug class.
