# ooRexx Chromecast v0.1-dev1

First concrete Chromecast package built on the current Alchemy socket architecture instead of inventing another network stack.

## Implemented in this revision

- `CastMessage`: native ooRexx CASTV2 protobuf message object and codec.
- `CastFrameCodec`: 32-bit big-endian length framing used on the TLS stream.
- `MdnsCodec` / `CastDiscovery`: `_googlecast._tcp.local` query generation and DNS-SD response parsing for PTR, SRV, TXT, A and AAAA records, including compressed DNS names.
- `CastDiscoveredService`: retains DNS-SD/TXT/address objects rather than flattening discovery to a hostname string.
- `CastDevice`: persistent Rexx device object wrapping the discovered service and live connection object.
- `CastConnection`: stream-neutral CASTV2 transport over an injected SocketProvider/TLS endpoint.
- controllers for connection, heartbeat, receiver and media namespaces.
- deterministic codec/discovery/object tests plus a complete environment qualification script.

## Socket boundary

This package deliberately does **not** implement TCP, TLS, UDP or IP multicast. Those are supplied by Socket Provider `v0.1-dev10` and the estate TLS/IP-multicast providers. Chromecast owns only DNS-SD interpretation and CASTV2 semantics.

The canonical Socket Provider dependency used while developing this package is:

```
oorexx_socket_provider_v0.1-dev10.zip
SHA-256 972255739d5284bfdfabf657c79f0f59440606259ed73602eaa802efadd7eb12
```

This matters because other same-version repacks exist in Library; one inspected repack omitted the UDP/IP-multicast classes despite carrying the same dev10 label.

## CASTV2 connection shape

```
CastDevice
  -> CastConnection
     -> SocketProvider TLS stream endpoint
        -> TCP/TLS to device:8009
```

`CastConnection` accepts any object exposing `write/read` or `send/recv`; acquisition and security-profile policy stay outside the Chromecast component.

## Discovery shape

```
CastDiscovery~queryPacket
   _googlecast._tcp.local PTR query
       |
       v
estate UDP/IP multicast provider -> 224.0.0.251:5353
       |
       v
CastDiscovery~servicesFromPacket
       -> CastDiscoveredService objects
```

The native multicast join/listen/send loop is intentionally not duplicated here. Wire it through the Socket Provider's provider-neutral multicast membership route.

## Current boundary

This dev1 is a protocol/object implementation, not a claim of live-device qualification. A real live run needs the estate TLS engine/security profile wired to the device's port 8009 and the current UDP/IP multicast provider wired for mDNS. The environment test refuses to substitute shell `openssl`, Python, or ad-hoc raw sockets for those dependencies.
