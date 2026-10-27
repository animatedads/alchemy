# XTP dev17 — multicast receiver pacing and reject suppression

Dev17 completes the two multicast control-plane refinements left explicit in dev16.

## Slowest-receiver ALLOC pacing

Reliable multicast now solicits status on information packets and records each receiver's current `RSEQ`, `DSEQ`, and `ALLOC`. Before the receiver population is known, the sender transmits only one information segment. Once the configured receiver population has answered, the sender advances only while the next segment end is within the minimum advertised `ALLOC`. The slowest receiver therefore bounds the multicast transmit window.

A receiver advertises `ALLOC = RSEQ + receive_window`; the listener's receive window is configurable through `ListenOptions::receive_window`, the multicast CLI `--receive-window`, and the ooRexx extended listener hook.

Loss remains go-back-N. If any measured receiver's current contiguous `RSEQ` is behind the transmitted high-water mark, the sender rolls back to the segment containing the slowest `RSEQ`.

## Receiver reject suppression

A receiver that detects a gap prepares a reject for its current `RSEQ`, but first waits briefly for a reject notice from another receiver on the same multicast context. A received reject covers the local request when `local RSEQ >= observed RSEQ`; in that case the local reject is suppressed because the existing request already asks the sender to roll back far enough.

When no covering reject is observed, the receiver sends the reject as a multicast control notice so peer receivers can suppress duplicates, and also sends the same control directly to the sender for the current L2/L3/L4 carrier implementation. This preserves the XTP receiver-to-receiver suppression semantics while keeping the sender control path explicit for the encapsulated carriers.

`MulticastListenerStats` exposes sent and suppressed reject counts.

## Protocol-independent boundary

No Queue/Memory/Storage Fabric caller learns these details. `SocketSelector` still selects the XTP provider; `libxtp` owns multicast sequencing, receiver windows, go-back-N, reject suppression, and L2/L3/L4 carrier behaviour.

## Qualification

Local UDP qualification covers:

- 8 KiB binary stream with 256-byte information segments and a 512-byte receiver window; the sender advances over 17 allocation rounds and reconstructs the object byte-for-byte.
- deterministic gap injection with a peer reject notice; a covered local reject is suppressed and the stream subsequently completes exactly.
- native ooRexx multicast sender/listener through the supplied 5.3.0 r13196 debug runtime.

L2 and raw protocol-36 multicast remain implementation-complete but require a raw-capable host for physical qualification.
