# RxSock6 Rasen Falcon coordination

Date: 2026-10-27

## Lane

- Component: `oorexx_socket_provider_rxsock6`
- Aliases: `rxsock6`, `socket6`, `ipv6-socket`
- Linked git artifacts:
  - `oorexx_socket_provider_rxsock6`
  - `oorexx_rxsock6_gopher_sphere_v0.1`
- Owner: `CHATGPT`
- Ownership: `OWN-00000692`

The lane was created only after `project_lanes_search` found the real
`packages/oorexx_socket_provider_rxsock6` artifact and reported no existing
lane.

## Open coordination

`REQ-00000695` was sent to `CODEX-PC` as an evidence-only task:

> Locate the exact RxSock6 Socket Provider v0.1-dev3 and matching rxsock6 0.1.2
> source/delivery closure, with artifact/path/hash/commit provenance.

The request explicitly says not to reconstruct source and not to amend
`SocketProvider.cls`.

## Current technical boundary

The current qualified estate remains Socket Provider v0.1-dev16, RxSock6
Socket Provider v0.1-dev3 and rxsock6 0.1.2.  TCP6 and UDP6 belong to RxSock6.
IPv6 RFC 3678 multicast membership belongs to IP Multicast v0.1-dev2. MLDv2 is
host-stack behaviour below that socket API.

The GitHub source tree remains historical dev1 until the exact dev3 source
closure is recovered and requalified. Rasen Falcon coordination does not change
that provenance status.
