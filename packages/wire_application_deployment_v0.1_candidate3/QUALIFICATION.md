# Local qualification — 2026-10-27

Full Candidate 3 ZIP passed eight ooRexx executable tests and seven source-compilation checks using the supplied 5.3.0 r13196 debug interpreter.

The GitHub test fixtures reproduce requestId deduplication and permanent Queue Fabric restart recovery; the complete test transcript, strict malformed-envelope tests, overlays and baseline pins are distributed with Candidate 3 ZIP (SHA-256 8aa156951a6f2326ef7c8df944a04a3afcb9929ce1f89d5ce347ba4fed87dbe9).

Not production-qualified: signed .wapp verifier and Storage Fabric fetch; Intentions target confirmation; single-writer lease/split-brain fencing; fsync and power-loss crash testing; HTTPS TLS/WSS authenticated semantic event; session draining; RexxOS delivery.
