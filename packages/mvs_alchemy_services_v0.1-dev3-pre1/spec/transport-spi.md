# MAS transport SPI — BASE-1 candidate

MAS BASE is transport independent. Release-1 reference transport is `MASD75`, an outbound Hercules DYN75 host-socket binding for MVS 3.8j TK5.

Operations: INITIALIZE, CONNECT, SEND, RECEIVE, CLOSE, TERMINATE.

MASD75 moves bytes only. It MUST NOT parse `mvs.alchemy/1`. Partial SEND/RECEIVE is normal; one receive is not one frame. A failed SEND/RECEIVE invalidates the connected stream.

Candidate state model: CLOSED -> INITIALIZE -> READY -> CONNECT -> CONNECTED -> CLOSE -> READY -> TERMINATE -> CLOSED.

This pre1 package deliberately contains no guessed DYN75 calling convention. The actual convention must be derived from and qualified against the supplied TK5/Hercules DYN75 material before BASE-1 can pass.
