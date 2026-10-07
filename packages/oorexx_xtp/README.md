# ooRexx XTP v0.1-dev18 — receiver RATE/BURST pacing, multicast flow control, multipath and provider-aware transport

API target: `xtp/0.1`

Dev13 retains the executable XTP Revision 3.4 subset and the three proven carriers from dev3:

- `l2`: direct Ethernet XTP, EtherType `0x817D`.
- `raw36`: native XTP as IPv4 protocol `36`.
- `udp`: XTP packet encapsulated in UDP as the Level-4 interconnect/fallback carrier.

The hot packet implementation is native C++. Queue Fabric, Memory Fabric and Storage Fabric sit above this boundary.

## dev7 library transport increment

Dev7 moves the actual XTP client send path behind the reusable library boundary.
`libxtp` now provides `send_message()` plus `SocketProvider::send()`, so a caller
can name a peer and let the route graph select L2, L3 or L4. `bin/xtp-connect`
is a thin qualification client over that API.

Routes can carry `--filters zero-block,crunch`; the selected wire profile is
applied by the library before XTP packetisation. `best-paths` returns the whole
ordered eligible path set, while route `enable` / `disable` provides the first
failover/rejoin administration hook.

The ooRexx facade returns `XTPRoute` objects and exposes `bestConnect`,
`bestPaths`, route state, and `XTPWireFilterChain`. The current bridge invokes
`xtp-admin`; it is intentionally shaped so that a native ooRexx binding can
replace the bridge without changing the Rexx object API.

See `docs/ARCHITECTURE_DEV7.md` and `docs/ARCHITECTURE_DEV8.md`.

## Build and local qualification

```sh
make clean all
sudo qualification/run_environment_test.sh
```

The local environment qualification covers UDP, native protocol 36 and direct Level-2 Ethernet over a private veth pair when the host has the required capabilities.

## ED209 field qualification

Dev4 adds a controller-driven **machine-to-machine** field harness under `qualification/field/`.

```sh
qualification/field/run_field_matrix.sh
```

The operator supplies a local inventory file to the field harness through its first argument or `XTP_INVENTORY`. Host inventory is machine-specific and is not included in this public source tree.

For every enabled host, the harness deploys the exact package binary and records:

- whether native IPv4 protocol 36 sockets can be opened;
- whether AF_PACKET / EtherType `0x817D` sockets can be opened;
- a real local Level-2 XTP transaction over a temporary veth pair when `CAP_NET_ADMIN` is available;
- default interface and MAC evidence.

For every **directed pair** of enabled hosts it then performs:

- **Level 3:** native XTP/IP protocol 36, machine-to-machine;
- **Level 4:** XTP-over-UDP, machine-to-machine.

Pairwise Level-2 tests are opt-in through `l2_domain` in the inventory. Two hosts are tested at L2 only when they are explicitly declared to share the same Ethernet domain. The harness never guesses Layer-2 adjacency from IP addressing.

Results contain complete client/server evidence and two TSV matrices:

```text
host-capabilities.tsv
pair-matrix.tsv
SUMMARY.txt
```

A native protocol-36 timeout is reported as `NO_RESPONSE_OR_FILTERED`, not automatically called a firewall/provider failure. This is deliberate: provider rules can then be changed and the exact directed pair rerun without turning inference into evidence.

### Privilege model

Raw XTP and AF_PACKET need `CAP_NET_RAW`. The controller tries `sudo -n setcap cap_net_raw+ep` on the temporary field binary when passwordless sudo is available. The L2 self-test additionally needs `CAP_NET_ADMIN` to create its temporary veth pair.

Useful controls:

```sh
XTP_REMOTE_PRIV=auto     # default
XTP_REMOTE_PRIV=sudo     # require passwordless sudo
XTP_REMOTE_PRIV=none     # do not attempt privilege setup
XTP_TIMEOUT_MS=750
XTP_RETRIES=6
XTP_FIELD_OUT=/path/to/results
```

## Native Level 3 manually

Receiver:

```sh
sudo bin/xtp-local server --carrier raw36 --bind 0.0.0.0 --max 1
```

Sender on another machine:

```sh
sudo bin/xtp-local client --carrier raw36 \
    --to 192.0.2.10 --message 'hello native XTP' --key 36001
```

There is no UDP or TCP header in this path.

## Direct Level 2 manually

Receiver:

```sh
sudo bin/xtp-local server --carrier l2 --interface eth1 --max 1
```

Sender on the same Ethernet domain:

```sh
sudo bin/xtp-local client --carrier l2 --interface eth1 \
    --to-mac 02:00:00:00:36:02 --message 'hello L2 XTP'
```

No IP address participates in this transaction.

## Scope

This remains a bounded executable XTP 3.4 profile rather than a claim of complete XTP interoperability. The field harness is intended to tell us empirically which ED209 paths carry native L2, native protocol 36, and the UDP Level-4 fallback before Queue Fabric / Memory Fabric / Storage Fabric select a carrier.


## dev5 ED209 access correction

The field harness uses `sshnode.sh` from `PATH`, or the explicit `XTP_SSHNODE` setting, for remote execution and file transfer. Node-specific SSH configuration remains owned by that helper. Direct `ssh` and `scp` are intentionally absent from the harness.

## dev6 — library, route graph and socket-layer wire filters

Dev6 starts the component split required for RexxOS integration:

- `lib/libxtp.a` and `lib/libxtp.so` are the reusable userspace library surface.
- `xtp::RouteTable` owns explicit L2/L3/L4 cross-path routes and `best_connect()`.
- `xtp::SocketProvider` is the XTP-side hook for the portfolio SocketSelector; it binds route selection and the transport-independent wire-filter chain without reimplementing the generic selector.
- `bin/xtp-admin` is a thin administrator over the library, not a second configuration implementation.
- `rexx/XTP.cls` exposes route administration and best-connect to ooRexx using the same route state.
- `kernel/Kconfig`, `kernel/Makefile` and `kernel/xtp_kmod.c` establish both `CONFIG_XTP=y` and `CONFIG_XTP=m` residency forms.  **Dev6 does not yet register AF_XTP or consume packets in kernel space**; the module is deliberately labelled a provider hook rather than falsely claiming a finished kernel protocol stack.

### Explicit cross-paths

```sh
bin/xtp-admin route add ED209D --layer 3 --carrier raw36 --to 203.0.113.44
bin/xtp-admin route add ED209E --layer 4 --carrier udp --to 198.51.100.22:43601
bin/xtp-admin route list ED209D
bin/xtp-admin best-connect ED209D
```

`best_connect()` orders enabled candidates by layer first (L2, then L3, then L4) and metric within a layer.  Explicit route configuration remains authoritative; applications do not probe arbitrary networks.

### Wire filter chain

The wire-filter boundary sits above the selected carrier and below XTP packetisation.  Dev6 ships two reversible filters:

- `zero-block`: collapses long zero runs to one run record (`1x block 0's`).
- `crunch`: first bounded repeated-byte packing filter; the interface is intentionally generic so later Crunch representations can replace/extend it without changing socket/transport callers.

A small `XWF1` envelope records the ordered filter IDs and original logical length.  Receivers reverse the chain before application delivery.  Unfiltered dev5 payloads remain accepted unchanged.

```sh
bin/xtp-local client --carrier udp --to 127.0.0.1:29136 \
  --message 'AAAAAAAAAAAAAAAA' --filters zero-block,crunch
```

Retransmission/checksum operation sees the filtered wire bytes; applications see the reconstructed logical bytes.

## dev8: standard SocketSelector integration

Dev8 consumes `oorexx_socket_provider_v0.1-dev2` as the application-facing
socket abstraction. XTP is now a real provider family behind that selector:

```text
application
   -> SocketSelector / SocketProvider
   -> RexxXtpSocketBinding
   -> XtpSocketBackend
   -> xtp-connect / libxtp SocketProvider
   -> best_connect()
   -> L2 / L3 / L4
```

The generic selector does not choose an XTP carrier. `libxtp` remains the sole
XTP path-selection authority. The XTP SocketAddress is deliberately opaque and
carries the XTP peer identity; routes are administered through the XTP route
API/CLI.

`xtp-connect` now accepts `--hex`, so the Rexx provider can carry arbitrary
byte strings rather than only shell-safe text.

The receive/listener side fails closed in this development revision. It will be
implemented against a real libxtp receive/socket API rather than faking stream
semantics around the older test server.


## dev10: receive/acknowledge moves into libxtp

Dev9 removes the receive-side dependence on the older `xtp-local` test server.
`libxtp` now owns a persistent `xtp::Listener` for every implemented carrier:

- L2 EtherType `0x817D` on a selected interface;
- L3 native IPv4 protocol `36`;
- L4 XTP-over-UDP.

The listener validates XTP framing/checksums, acknowledges FIRST transactions,
keeps KEY replay state across receives, suppresses duplicate application
delivery, and reverses the self-describing wire-filter envelope before exposing
application bytes.  This means retry/replay behaviour remains a transport
property rather than being recreated by each application listener.

`xtp::SocketProvider::listen(peer)` selects the configured listener route via
the same route graph used by `best_connect()`. `bin/xtp-listen` is a thin
qualification/admin client over that library API, including binary-safe
`--hex` output.

Example:

```sh
export XTP_ROUTE_FILE=/tmp/xtp-routes.tsv
bin/xtp-admin route add LOCALRX --layer 4 --carrier udp \
  --to 127.0.0.1:29609 --filters zero-block,crunch
bin/xtp-listen LOCALRX --count 1 --hex
```

The ooRexx `SocketSelector` listener binding remains fail-closed in dev10.  The
native receive endpoint now exists underneath it, but a persistent native
Rexx binding (rather than spawning one process per `accept`) is required to
preserve listener lifetime and replay state correctly.  Dev9 deliberately does
not fake that semantic boundary.


## dev10
Native ooRexx external binding (`liboorexx_xtp_native.so`) now provides binary-safe in-process sender and persistent listener support through the standard SocketSelector XTP binding. The listener keeps the same `libxtp::Listener` alive across accepts, so replay state is not lost at a process boundary.

## dev13 multipath increment

Dev11 makes `best_paths()` executable transport policy. `libxtp` now provides a dual/multi-path engine which stripes XMP1 chunks across the ordered route set and replays work assigned to a failed path over a surviving path. The receiving `MultipathListener` owns one persistent XTP listener per route and reassembles a single logical byte stream independent of arrival carrier.

The XMP1 frame carries transfer identity, generation, chunk index/count, total logical size and chunk size. The route's existing wire filter profile is applied outside that frame, then normal XTP carrier framing is applied. This found and repaired a real dev10 filter-chain defect: intermediate decoding of `zero-block,crunch` could legitimately be larger than the final logical object and was incorrectly bounded by final logical length.

`XtpSocketBackend` now has `multipathSender()` and `multipathListener()` hooks backed by persistent in-process ooRexx native routines. No carrier-specific address structure is introduced into Rexx.

The generation in dev13 is a transfer/path-set fence. A path that fails is not reintroduced into that in-flight transfer. Persistent requalification and generation advancement across transfers are intentionally left for the next control-plane increment.


## dev13 persistent path health

The recent Socket Provider work makes transport availability dynamically discoverable rather than a permanent catalogue, and adds NORM as a sibling provider. XTP remains one provider behind the same SocketSelector boundary; it does not absorb or special-case NORM. This package vendors the current Socket Provider dev8 contract for qualification.

Dev12 adds the missing cross-transfer multipath control plane:

```text
configured RouteTable
        |
        +--> PathHealthTable (UP / DOWN / PROBING, generation)
                         |
                         +--> SocketProvider best path set
                                      |
                                      +--> XMP1 stripe / survivor replay
```

A real send failure persistently fences the path `DOWN`. Subsequent transfers do not keep paying the failure timeout. Requalification is explicit: `path probe` keeps the route excluded while it is tested; `path up` admits it and increments the path generation. Multipath sends with generation 0 derive the generation from the selected path set, so a returned path cannot rejoin an old stripe generation.

Administrative examples:

```sh
xtp-admin path list ED209D
xtp-admin path down ED209D --layer 3 --carrier raw36 --error 'qualification failure'
xtp-admin path probe ED209D --layer 3 --carrier raw36
# perform the real carrier/provider qualification
xtp-admin path up ED209D --layer 3 --carrier raw36
```

The same hooks are present in `XTPPeer` as `pathHealth`, `pathDown`, `beginPathRequalification`, and `pathRequalified`.


## dev13: provider-aware live path requalification

A path can no longer return from `DOWN` to normal selection merely because an
administrator changed a state flag. `path qualify` performs a live XTP
FIRST/CNTL transaction through the configured carrier before generation is
advanced and the path becomes `UP`.

The qualification packet is transport-internal and is acknowledged by a normal
`libxtp` Listener but is never returned to the application.  Qualification is
therefore carrier-specific without leaking special probe messages into Queue,
Memory, Storage, or other socket consumers.

Current qualification providers are:

* L2 `l2`: EtherType `0x817D`
* L3 `raw36`: IPv4 protocol 36
* L4 `udp`: XTP/UDP encapsulation

`path force-up` remains an explicit administrative escape hatch. It is named
accordingly and is not used by the Rexx `pathRequalified` method.

Example:

```
xtp-admin path down ED209D --layer 3 --carrier raw36 --to 203.0.113.4
xtp-admin path probe ED209D --layer 3 --carrier raw36 --to 203.0.113.4
xtp-admin path qualify ED209D --layer 3 --carrier raw36 --to 203.0.113.4
```

## dev15 capability status

XTP multicast is now implemented for libxtp's current FIRST-transaction profile and is advertised by `CAPABILITIES.json`. Reliable MULTI uses whole-message go-back-N retransmission to an acknowledgement quorum; NOERR provides one-way multicast without acknowledgements. L2, native IP protocol 36 and UDP multicast carriers are implemented.

## dev15: XTP MULTI

Dev15 implements multicast rather than merely exposing group-shaped addresses. A multicast route is explicit (`--multicast`) and is excluded from ordinary `best_connect()`, so a group can never be selected accidentally for unicast traffic.

```sh
bin/xtp-admin route add MEMORY-GROUP --layer 4 --carrier udp \
  --to 239.192.0.36:29360 --multicast --filters zero-block,crunch

bin/xtp-multicast listen MEMORY-GROUP
bin/xtp-multicast send MEMORY-GROUP --message 'snapshot-ready' --expected 3
```

Reliable mode keeps a receiver acknowledgement set and retransmits the current logical message until the configured receiver quorum is reached. This is the go-back-N behaviour appropriate to libxtp's current one-message FIRST transaction profile. Duplicate retransmissions are acknowledged by receivers but are not redelivered to the application. `--noerr` sets XTP `NOERR`, transmits once, and requires no acknowledgement.

The MULTI bit is the XTP 3.4 common-header OPTIONS byte 3, bit 3 (`0x08`); NOERR is bit 4 (`0x10`). Wire filters remain above XTP packetisation, so multicast uses the same zero-block/Crunch representation path as unicast.

The ooRexx native binding now carries multicast all the way through `XtpSocketBackend`: a multicast-marked `SocketAddress` selects native multicast sender/listener objects, while ordinary XTP addresses retain unicast semantics.


## dev16: multicast FIRST+DATA streaming

The multicast data plane now advances beyond dev15's one-FIRST transaction profile. Logical wire payloads are segmented into one FIRST packet followed by zero or more DATA packets, all sharing the XTP byte sequence space. Reliable receivers reject gaps with their current RSEQ and the sender's go-back-N engine rolls back to the corresponding segment. The final status/close acknowledgement remains quorum based.

`xtp-multicast send` now accepts `--segment-bytes` and binary-safe `--file`; `listen` accepts binary-safe `--output`. A 12 KiB non-compressible qualification payload is forced through 24 XTP information packets and compared byte-for-byte after reassembly. A delayed receiver additionally proves segmented replay rather than merely replaying a single FIRST packet.

Multicast quorum failure is now separated from carrier health. A missing receiver no longer poisons the route's persistent `PathHealthTable`.

See `docs/ARCHITECTURE_DEV16.md` for the exact implemented boundary.


## dev17: slowest-receiver ALLOC pacing and reject suppression

Dev17 completes the multicast control-plane items left explicit in dev16. Reliable multicast now measures receiver `ALLOC` and advances only inside the minimum receiver allocation after the configured receiver population has responded. The first reliable information segment is therefore conservative; subsequent FIRST/DATA bursts are bounded by the slowest receiver's advertised window.

Receivers now implement XTP reject suppression. A receiver that detects a gap waits briefly for a multicast reject notice from another receiver. If the observed reject's `RSEQ` is at or before the receiver's own required rollback, the local reject is suppressed. Otherwise it multicasts a reject notice for peer suppression and sends the control to the sender.

The CLI exposes `--receive-window` and `--reject-suppression-ms`; sender results expose `slowest_alloc`, `allocation_rounds`, and `allocation_stalls`. Extended ooRexx native hooks expose segment size, timeout/retries, allocation pacing, receive window, and reject-suppression delay without changing the protocol-independent `SocketSelector` boundary.

The package vendors Socket Provider dev12 from the current Library and is qualified against the supplied ooRexx 5.3.0 r13196 debug package `20261007-174859`. See `docs/ARCHITECTURE_DEV17.md`.

### Current Socket Provider / ooRexx qualification

The current Library common selector baseline checked for this delivery is
`oorexx_socket_provider_v0.1-dev12`.  It keeps transport capability fields
protocol-independent; an XTP multicast-stream request is represented by the
existing conjunction `requireStream=true` plus `requireMulticast=true`.
Dev17 does not add an XTP-specific selector capability bit.

Native ooRexx qualification was performed against the supplied
`oorexx-5.3.0-13196.ubuntu1604debug.x86_64(20261007-174859).deb` runtime.
The userspace environment used here denies `CAP_NET_RAW`, so raw protocol 36
and direct L2 runtime qualification remain real-host/ED209 qualification items,
not local passes.


## dev18 — XTP RATE/BURST sender pacing

Dev18 consumes the XTP RATE and BURST values already carried in receiver CNTL packets rather than treating them as decorative fields. Reliable multicast keeps the per-receiver RATE/BURST state alongside RSEQ/DSEQ/ALLOC and constrains the sender to the slowest advertised receiver.

- `RATE` is bytes/second. `0xffffffff` is the executable profile's representation of XTP `RATE=-1` and disables rate pacing.
- `BURST` is the maximum bytes admitted in one sender burst.
- before receiver status exists the sender uses its configured default RATE/BURST; defaults are disabled, matching the previous behaviour.
- once the configured receiver population has replied, the minimum receiver RATE and BURST become authoritative.
- ALLOC and RATE/BURST are independent: ALLOC bounds how far the sequence may advance, RATE/BURST bounds how fast legal data is emitted.

The receiver advertisement is configurable through `ListenOptions`, `xtp-multicast listen --rate/--burst`, and the native ooRexx multicast listener. The Rexx multicast sender exposes rate-pacing enable/disable without reimplementing timing in Rexx.

`SocketSelector` remains protocol independent. RATE/BURST is an XTP transport implementation detail below the selected XTP endpoint.

Current vendored protocol-independent Socket Provider core is v0.1-dev13 from the Library; XTP-specific rate control remains below that common selector boundary.
