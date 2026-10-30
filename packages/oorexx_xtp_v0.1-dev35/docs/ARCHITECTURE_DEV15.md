# XTP dev15 — multicast data plane

`libxtp` now implements XTP Revision 3.4 multicast for the executable transaction profile already used by this component.

## Packet semantics

- FIRST packets set OPTIONS `MULTI` (byte 3 bit 3, mask `0x08`).
- `NOERR` mode additionally sets byte 3 bit 4 (`0x10`) and sends once without CNTL acknowledgement.
- Reliable mode collects CNTL acknowledgements from distinct network receivers and retransmits the complete current message until the configured acknowledgement quorum is reached. Because the current libxtp data plane is a one-message FIRST transaction rather than a multi-DATA streaming implementation, this is whole-message go-back-N.
- Receivers ACK replayed keys but suppress duplicate application delivery.

## Carriers

- L2: multicast destination MAC, EtherType `0x817D`, `PACKET_MR_MULTICAST` membership.
- L3: IPv4 multicast destination with native IP protocol `36`, `IP_ADD_MEMBERSHIP`.
- L4: IPv4 multicast group/port carrying XTP packets over UDP, `IP_ADD_MEMBERSHIP`.

Multicast routes are explicit and are excluded from unicast `best_connect()` / `best_paths()`. The same wire-filter chain is applied before multicast XTP packetisation.

## Socket / Rexx boundary

`SocketProvider::send_multicast()` and `listen_multicast()` are the native library surface. The ooRexx native extension holds persistent multicast listener handles, and `XtpSocketBackend` selects multicast objects when `SocketAddress~multicast` is true. Socket Provider dev10 advertises this only through the current dev15 capability profile; historical dev9/dev10 profiles remain non-multicast.
