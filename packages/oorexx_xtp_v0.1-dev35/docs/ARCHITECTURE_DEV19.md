# XTP v0.1-dev19 — SORT / DEADLINE prioritization

Dev19 implements the XTP 3.4 prioritization fields described in the supplied XTP tutorial.

## Wire contract

The 24-byte common header now carries the 32-bit SORT field at bytes 8..11. OPTIONS byte 3 uses the documented bits:

- bit 1 (`0x02`) — SORT
- bit 0 (`0x01`) — DEADLINE

Static priority sets SORT and clears DEADLINE. Lower SORT values are higher priority. Deadline priority sets both SORT and DEADLINE; the SORT value is treated as a synchronized-clock deadline in 100 microsecond units. A DEADLINE flag without SORT is rejected as malformed.

Priority metadata is carried by FIRST, DATA and corresponding CNTL packets, and is surfaced in `ReceiveResult`.

## Sender scheduling

`PriorityScheduler` is carrier-independent and orders queued work before carrier dispatch. It supports disabled, static SORT, and dynamic deadline disciplines. Static and deadline disciplines cannot coexist in one scheduler, matching the XTP network rule. Expired deadlines are demoted to the lowest priority rather than discarded.

The convenience deadline encoder uses synchronized wall-clock time expressed as Unix epoch 100-us ticks modulo 2^32. Deployments with a different synchronized XTP clock can supply the raw 32-bit SORT value directly.

## Carrier independence

The priority header is created before carrier selection, so the same semantics apply to Ethernet 0x817D, native IPv4 protocol 36, and XTP/UDP. SocketSelector remains protocol-independent.

## Qualification

`tests/test_priority.sh` proves static queue ordering, deadline ordering, expired-deadline demotion, static/deadline discipline exclusion, and real XTP/UDP header round-trip for both static and deadline modes.
