# Changelog

## 0.1-dev4

* Added explicit `OWNED` / `BORROWED` Socket lifetime policy; default remains `OWNED` for dev3 compatibility.
* A borrowed debug transport now closes only its debug view, never the provider/caller-owned Socket.
* Added negative-count/timeout validation.
* `JdwpSocketTransport~readPacket(timeoutMs)` now delegates readiness waiting through the generic Socket `pump`/`poll` seam.
* Added complete `qualification/run_environment_test.sh`, with an optional hook to chain the estate SocketProvider's real environment qualification.
* Retained exact Socket and SocketAddress object identity and the ban on protocol-specific debug transports.


```text
application / Wire UI / Alchemy JavaScript
                 |
          Debug Runtime objects
                 |
          DebugProvider SPI
         /        |         \
     GDB/MI      JDWP      DbgEng
                  |
          debug transport seam
             /           \
       ADB stream       Socket object
                           |
                    SocketSelector /
                    SocketProvider
                           |
                +----------+----------+---------+
                |          |          |         |
              TCP        QUIC        XTP      Unix/...
```

## Rules

1. Debug protocol nouns stop at the provider boundary.
2. Breakpoints are registered interests in execution events, not application
   strings containing debugger commands.
3. Variable names are runtime data; `DebugScope~UNKNOWN` projects them.
4. Control and observation are separate. A successful continue/step request is
   not evidence that the target is running.
5. Provider-specific facilities are advertised as capabilities; they do not
   distort the common object model.
6. ADB is a target/transport route, not a debugger object hierarchy.
7. The same semantic objects are intended to project through Alchemy bridges;
   renderers/languages must not fork debugger semantics.
8. Network transport enters Debug Runtime as a selected **Socket object** plus
   its **SocketAddress object**. Debug Runtime neither invokes RxSock directly
   nor flattens an address into host/port strings.
9. TCP, QUIC, XTP, TLS, Unix-domain and future families remain SocketProvider
   implementations. There is deliberately no `QuicDebugTransport` and no
   debugger-owned XTP carrier selection.
10. XTP L2/L3/L4 route/carrier selection and socket-layer wire filters remain
    below the SocketProvider boundary. Debug Runtime sees only the resulting
    socket object.


## Socket lifetime

A selected Socket remains a first-class object. The debug transport records whether
its view is `OWNED` or `BORROWED`; this is a lifetime decision only and never changes
provider/family semantics. Closing a borrowed debug view must not close the underlying
Socket. This permits QUIC multiplexing, XTP provider ownership, socket pools and future
shared/migratable transports without inventing a second socket model.

## 0.1-dev5

- Added `fromSelectedSocket()` handoff for an already-selected estate Socket; defaults
  to BORROWED ownership and preserves the provider SocketAddress object by identity.
- Added independent read/write lifecycle states and view-level half-close operations.
- BORROWED half-close never mutates the shared provider Socket.
- OWNED half-close delegates provider shutdown operations when they are exposed.
- Failed OWNED close no longer falsely reports the debug transport CLOSED.
- Provider errors/return values remain provider semantics; no debug-specific network
  error vocabulary or protocol branching was introduced.


## 0.1-dev7

- Added `fromAcceptedSocket()` for inbound listener-accepted Socket handoff.
- Preserves separately returned provider SocketAddress objects by identity.
- Accepted handoff defaults to BORROWED ownership, as does selector handoff.
- `JdwpSocketTransport` inherits the same accepted-Socket factory; no protocol-specific
  debugger transport classes are introduced.
- Explicitly keeps listener creation, `accept`, family selection and carrier selection
  outside the debugger component.


## 0.1-dev7

- Added `fromSocketStreamAdapter()` for the current estate SocketProvider integration.
- Preserves adapter, underlying Socket and SocketAddress identities independently.
- READ/WRITE/PUMP/CLOSE now delegate through the selected stream view.
- Keeps selector-produced and listener-accepted handoff direction-neutral.
- Added regression proving Debug Socket Transport does not bypass the adapter.
- Maintains protocol blindness: no TCP/QUIC/XTP-specific debugger transport classes.
