# XTP dev22 source-level integration review (2026-10-16)

**Pinned input:** `oorexx_xtp_v0.1-dev22.zip` SHA-256
`0dff97f7f26e0cd6c6b2929604fced46c871763ad30ca9fdf4cced72c510fed4`.
No modifications to XTP core are included in SSH Candidate 3.

## Confirmed delivered surface

- `SendOptions::service_name` and `ListenOptions::allowed_services` exist in C++.
- Private FIRST address segment format `0xA11C` encodes named service and non-cryptographic FNV token. It is **not** the standard ISO NSAP+TSAP address format.
- `Listener::Impl::receive()` rejects a FIRST whose service is not in the nonempty allowlist **before CNTL ACK**.
- ooRexx has `XtpNamedServiceManager`, `XtpNamedServiceListener`, and native send/listen routines.
- Local Service Descriptors bind `name -> operational class -> logical peer -> service point`; underlying IP remains in the XTP route table.
- Native XTP named-service/operational tests passed locally.

## Upstream action 1: ooRexx object-scope regression

`rexx/XtpNamedServices.cls`, `::method listener`, currently starts:

    expose registry backend

but reads `planner` and `operatingState`. Change it to:

    expose registry backend planner operatingState

Otherwise the listener cannot reliably evaluate its registered class/degradation state. This is an upstream bug report, not a modification shipped to dev22.

## Upstream action 2: malformed FIRST exceptions

`decode_named_service()` may throw for malformed length, token or service-name content. `parse_payload_packet()` calls it and `Listener::Impl::receive()` does not catch malformed-FIRST decode exceptions before returning to the service process. A well-checksummed but malformed packet may therefore terminate a daemon unless the caller catches/restarts. The native listener should discard malformed FIRST and continue without acknowledging it, and add a regression test. Do not mask resource/system errors broadly.

## Upstream action 3: context lifecycle

The existing unicast `send_message()` transmits a FIRST per transaction and the listener acknowledges each. The SSH candidate generates a different XTP KEY for each application bridge frame. Dev22's named FIRST is **not evidence** that one persistent SSH session has a native XTP context with DATA/KEY-only fast-path traffic. This requires a separate libxtp context/socket API and tests.

## Upstream action 4: dynamic degradation / admission

`XtpNamedServiceManager~listener` computes the permitted service set at listener creation. Changes to operating state are not automatically applied to a resident native listener. Define an atomic, fail-closed transition/re-evaluation path for future long-lived contexts, together with explicit outcomes for already admitted sessions. Empty `allowed_services` presently means compatibility accept-any; new restricted callers must never pass an empty set.

## Security distinction

A named FIRST can receive transport ACK based on a registered service name alone. Client cryptographic authorization remains in the SSH bridge's challenge/HMAC layer in this candidate, after native FIRST admission. Do not describe XTP FIRST admission itself as peer authentication or claim a fully authorized native context yet.
