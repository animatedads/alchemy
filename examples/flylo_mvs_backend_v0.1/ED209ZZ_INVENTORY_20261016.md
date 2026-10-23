# ED209ZZ inventory checkpoint — 2026-10-16

Factual checkpoint, not completed qualification.

Proven: MVS 3.8j Level 8505 Update 5; Hercules 4.9.1.1-SDL-gee86c4d; JES2 activity; TCAS accepting logons; reader 000C/3505 on TCP 3505; punch 000D/3525; printers 0002/3211, 000E and 000F/1403, 030E hardcopy; VTAM pool 00C0-00C6/3270; TK5 TSO logon panel reached; later host log proved HERC01 logged on.

Operational correction: the blank post-login HERC01 screen is the TSO command environment. Use one SSH tunnel and one selected 3270 LU, keep it alive, inspect each screen, and do not open extra LUs just because the screen is blank or slow.

Not yet proven at this checkpoint: live operator-console D R,L response; BREXX/RXBATCH contract; exact compiler/tool PROCs and PGM identities; toolchain qualification; any FlyLo MVS backend slice.

The target used ED209C-named host configuration/start files. Record that as deployment naming, not as evidence that it is the ED209C machine image.
