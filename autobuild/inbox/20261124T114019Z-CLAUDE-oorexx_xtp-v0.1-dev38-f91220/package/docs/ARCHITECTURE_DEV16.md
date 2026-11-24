# XTP dev16 — multicast FIRST+DATA streaming

`libxtp` now carries one logical multicast object/stream across an initial XTP FIRST packet and subsequent DATA packets using the normal byte sequence space. The default information-segment size is 1200 bytes and is configurable through `MulticastOptions::segment_bytes`.

Reliable mode performs sequence-level go-back-N. A receiver maintains the next acceptable byte (`RSEQ`). Out-of-sequence packets are not buffered as gaps; the receiver returns a CNTL reject containing its current RSEQ. The sender rolls back to the segment containing the slowest reported RSEQ and replays from there. Final CNTL acknowledgements are collected until the configured receiver quorum is satisfied. Receivers suppress duplicate application delivery by XTP key.

`NOERR` uses the same FIRST+DATA segmentation but sends once and never requests retransmission. If a NOERR stream is incomplete it is not presented as a complete application object.

The implementation is carrier-independent at the packet layer and is wired for L2 EtherType `0x817D`, native IPv4 protocol `36`, and XTP-over-UDP. UDP multicast streaming is executable in the container qualification; raw36 and L2 require the existing real-host raw-socket qualification environment.

The multicast command gained binary-safe `--file` input and `--output` receive support. The Rexx/native API did not change: callers still use the same multicast sender/listener objects, so DATA streaming is an implementation upgrade below `SocketSelector`.

A failed receiver quorum no longer marks the multicast route itself DOWN. Receiver population failure is not evidence that the carrier path is unhealthy; persistent path-health transitions remain the job of explicit carrier qualification.

Not yet claimed in dev16: slowest-receiver ALLOC pacing across a long-lived stream and multicast reject-suppression between receivers. Those remain distinct XTP control-plane refinements rather than being implied by DATA segmentation.
