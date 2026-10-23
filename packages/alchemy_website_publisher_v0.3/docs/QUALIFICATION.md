# Website Publisher v0.3 qualification, 2026-10-23

**Source dependencies:** ooRexx 5.3.0 r13196 debug, Alchemy Objects v0.8, Crypto v0.8.3, NoSQLServer v0.90 WAL read/write candidate.

**Passed**
- 46 browser/editor assertions in Chromium (full separately delivered ZIP).
- 36 native-handoff and source contract assertions.
- Native ooRexx class compilation, SQLite create/append/reopen/exact byte preservation, revision parent-chain `verify`.
- Rebuilt native SQLite writer from NoSQLServer source against extracted ooRexx headers (C++17).
- WAL-mode read, append and reopen; independent SQLite `integrity_check` and parent tuples `[(1,0),(2,1),(3,2)]`.
- ZIP integrity and SHA-256 manifest verification.

**Not qualified:** load/soak, fault injection, production RexxOS confinement, multi-writer predicate serializability, external publishing, site release, institutional approval, Connect Selector service integration. A compliant authenticated service is still to be developed.

**GitHub status:** This is a **partial source sync** (native integration + tests + pin). Front-end source and Rasenfalcon reference materials still need to be imported into the repository from the v0.3 release. Do not mark complete.
