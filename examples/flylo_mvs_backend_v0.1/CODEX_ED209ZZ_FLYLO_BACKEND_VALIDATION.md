# Codex directive — ED209ZZ FlyLo backend validation

Treat ED209ZZ as a fresh reference target. Facts from ED209C are hypotheses only.

Do not modify SYS1/SYS2 casually, install SYSCPK, weaken security, IPL/restart JES2 to cure a job failure, invent PROC names or compiler DD contracts, or repeatedly resubmit edited JCL without reading the preceding diagnostic.

## Initial sequence

1. Use the established SSH helper/workflow and identify the actual target mapping.
2. Record host, Hercules and MVS/TK5 identity.
3. Inventory console, 3270, reader, punch and printer devices from actual configuration.
4. Check JES/TSO.
5. Use one planned 3270 session at a time.
6. HERC01 -> password -> blank screen means TSO command environment; issue `TIME` to confirm.
7. Inventory BREXX/RXBATCH without installing anything.
8. Inventory exact SORT, COBOL, Assembler/IFOX00, PL/I, GCC370 and RPG PROCs/PGMs.
9. Preserve exact PROC bodies and SHA-256 evidence.
10. Qualify in order: `SORT -> COBOL -> Assembler XF/IFOX00 -> PL/I -> GCC370 -> RPG`.
11. Only then load the airline backend slices.

## Required semantic assertions

- SYD-HKG-LON may be operationally valid while the through fare is invalid.
- Zorin forwarder authority cannot become Drax operator authority.
- Coupon ruleset-at-issue is immutable.
- Skipping an OPEN prior coupon rejects unless the exact issue ruleset authorizes the explicit fictional waiver.
- Baggage profiles remain distinct ruleset/product data.
- Cargo fixture 100 x 50 x 40 cm, divisor 6000, yields 33334 g volumetric weight under the v0.1 gram-ceiling oracle.
- FLCTL must replay the same submission identity for the same workflow/node/submission key rather than launch duplicate JES work.

The original 2026-10-16 directive carried SHA-256 `62dc08cd135c2caa2e5cab84f4694eea6fdcb53be2b3982e995307331cc7d089`.
