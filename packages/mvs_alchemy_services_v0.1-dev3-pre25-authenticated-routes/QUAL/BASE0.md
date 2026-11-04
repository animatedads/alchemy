# BASE-0 qualification

Implemented in this checkpoint:

- Q00 protocol constants/layout review
- Q01 frame encode/decode roundtrip
- Q02 zero-length payload
- Q03 maximum legal frame
- Q04 truncated header rejected
- Q05 impossible lengths rejected
- Q06 unknown protocol major rejected
- Q08/Q09/Q10 opaque binary including 00/FF preserved

Deferred until typed-value codec/guest execution:

- Q07 EBCDIC CHAR roundtrip
- Q11 signed/unsigned typed integer boundaries
- Q12-Q16 live handle/replay/object lifecycle qualification

BASE-1 additionally qualifies the supplied TK5/Hercules DYN75 crossing. Hercules/TK5 startup is treated as a persistent long-running qualification system, with at least four minutes allowed for startup rather than restarted for each test.
