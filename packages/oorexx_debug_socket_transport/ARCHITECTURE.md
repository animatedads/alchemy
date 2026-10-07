# Architecture

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


## Directional lifecycle

Debug transport state describes the **debug view**, not the carrier. Read and write
may be closed independently. A borrowed view never applies provider shutdown merely
because the debugger closes one direction; an owned view may delegate provider-native
`shutdownRead` / `shutdownWrite` when present. Provider-specific close/error semantics
remain authoritative and are not converted into protocol-labelled debugger errors.

`fromSelectedSocket()` is a handoff, not a selector. Debug Socket Transport must never
instantiate `SocketSelector` or choose a provider family itself.


## Inbound/outbound symmetry

Socket acquisition remains outside Debug Socket Transport in both directions:

```text
outbound: SocketSelector -> selected Socket ----\
                                            DebugSocketTransport
inbound:  SocketListener -> accepted Socket ----/
```

`fromSelectedSocket()` and `fromAcceptedSocket()` are handoff factories only. Neither
method selects a family, opens a listener, calls `accept`, chooses an XTP carrier, or
projects addresses into primitive host/port values. If a listener returns an address
object separately from the accepted Socket, that same object crosses the boundary.


## SocketStreamAdapter boundary (dev7)

`DebugSocketTransport` may now hold two identities at once: the complete provider
Socket object and the generic stream adapter used for byte I/O/lifecycle. This is
intentional. The adapter is not a replacement address/socket model and may not
flatten provider objects. `streamObject()`, `socketObject()` and `socketAddress()`
therefore expose the three boundaries independently.

The debugger must never bypass an supplied adapter to perform byte I/O directly
on its underlying Socket. This keeps provider-specific buffering, event integration,
QUIC stream choice, XTP receive state, TLS state and future socket mechanics below
the isolation boundary.
