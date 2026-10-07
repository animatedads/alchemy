# XTP dev10 compatibility

Inspected supplied `oorexx_xtp_v0.1-dev10(1).zip`.

Dev10 changes the ooRexx provider boundary materially from dev9:

- sender calls native `xtpNativeSend()` in-process;
- listener opens a persistent native `xtp::Listener` handle;
- `accept()` receives through that retained handle;
- replay/carrier state remains in libxtp;
- both sender and listener are now valid SocketSelector operations.

Socket Provider dev5 therefore advertises XTP dev10 as sender+listener capable.
It does not claim to have independently exercised live native XTP traffic in this
environment; compatibility and negotiation are qualified against the supplied
source contract and fake acquisition backend.
