# MAS transport SPI — BASE-1 candidate

MAS BASE is transport independent. Release-1 reference transport is `MASD75`, an outbound Hercules DYN75 host-socket binding for MVS 3.8j TK5.

Operations: INITIALIZE, CONNECT, SEND, RECEIVE, CLOSE, TERMINATE.

MASD75 moves bytes only. It MUST NOT parse `mvs.alchemy/1`. Partial SEND/RECEIVE is normal; one receive is not one frame. A failed SEND/RECEIVE invalidates the connected stream.

Candidate state model: CLOSED -> INITIALIZE -> READY -> CONNECT -> CONNECTED -> CLOSE -> READY -> TERMINATE -> CLOSED.

This pre1 package deliberately contains no guessed DYN75 calling convention. The actual convention must be derived from and qualified against the supplied TK5/Hercules DYN75 material before BASE-1 can pass.

## pre9 executable transport

pre9 supplies the first actual `MASD75` implementation.  It binds the transport
SPI to the EZASMI API supplied for MVS 3.8/TK5.  EZASMI uses Hercules' X'75'
host-socket facility.  `BASE/MACLIB/MASD75CB.asm` is the public transport
control block and `mvs/asm/MASD75.asm` is the executable module.

The implementation loops partial SEND and RECEIVE operations until the caller's
requested byte count is complete.  A zero/negative transfer is a transport
failure.  MASD75 remains byte-only and does not parse `mvs.alchemy/1`.

Environment qualification is performed by
`scripts/qualify_ed209c_ed209z_services.sh`; host-only tests cannot qualify this
transport.
