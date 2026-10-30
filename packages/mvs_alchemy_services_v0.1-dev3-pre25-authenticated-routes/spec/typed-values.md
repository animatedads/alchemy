# mvs.alchemy/1 typed values — draft 0.1

BASE payloads are sequences of typed values. Each value begins with an 8-byte prefix:

| Offset | Size | Field |
|---:|---:|---|
| 0 | 1 | type |
| 1 | 1 | flags |
| 2 | 1 | ASCII tag length |
| 3 | 1 | reserved, MUST be zero |
| 4 | 4 | value length, big-endian |
| 8 | n | ASCII tag followed by value bytes |

Initial type codes are NULL=0, BYTES=1, CHAR=2, UINT32=3, SINT32=4, UINT64=5, HANDLE=6, ARRAY=7, STRUCT=8.

BYTES is opaque. CHAR begins with a 16-bit unsigned CCSID followed by encoded character bytes. The default guest CCSID negotiated in HELLO is descriptive context and never permits conversion of BYTES.
