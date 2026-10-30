# BASE-0.5 qualification

This checkpoint closes additional pre-transport qualification before DYN75 is introduced.

Passed by `HOST/tests/wire_reference.py`:
- fixed 48-byte frame encode/decode and 32K ceiling
- malformed/truncated/version/length rejection
- opaque 00/FF/C1 binary preservation
- explicit EBCDIC-037 CHAR representation (`HELLO` = C8 C5 D3 D3 D6)
- UINT32 and SINT32 boundary representation
- replay semantic fingerprint equality/conflict reference behavior

Not claimed in this checkpoint:
- live ooRexx socket endpoint
- Hercules DYN75 binding
- resident MAS STC/local IPC
- live handle table/replay ledger
- MQ/DB2 personalities
