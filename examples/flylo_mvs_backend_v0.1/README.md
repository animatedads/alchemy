# FlyLo MVS backend validation v0.1

Source-owned home for the MVS 3.8J/TK5 backend-validation work. It does not replace the durable ooRexx/Wire UI application.

Backend chain: `FLSCHED -> FLPATH -> FLRULE -> FLFARE -> FLPNR -> FLTKT -> FLBOARD -> FLBAG -> FLCARGO -> FLCTL`.

ED209ZZ is the current reference target. The 2026-10-16 inventory proved MVS 3.8j Level 8505 Update 5, Hercules 4.9.1.1, JES2 activity, a TK5 TSO logon panel and the captured unit-record/3270 topology. It did not complete compiler/PROC qualification or load the airline backend.

Use one planned 3270 session at a time. After HERC01 login the normal blank screen is the TSO command environment; do not misclassify it as a hang and burn additional LUs.

`reference_oracle.py backend_acceptance.json` is the executable host-side behavioural reference for the currently committed acceptance vectors. It is not the production MVS implementation. The committed oracle was exercised before publication and passed 12/12 cases.

One failed job -> preserve deck/spool/listing/hash -> classify -> change one thing.
