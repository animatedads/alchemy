# ooRexx Python Alchemy v0.28.0

Qualified Python/ooRexx foreign-runtime bridge POC with live dual-runtime method surgery.

Key qualification added in v0.28.0:
- Python class method P1 is visible through an existing Rexx proxy.
- Rexx object-local method R1 can shadow Python P1 without mutating Python.
- Python can replace P1 with P2 while the Rexx overlay remains active.
- Future Python instances observe P2.
- Rexx can replace R1 with R2 independently.
- Removing the Rexx overlay reveals the current Python P2, not a cached historical implementation.
- Python deletion is immediately visible through existing proxies.

Archive SHA-256:
0753fe15caaa10147e3cc4106169639d24725ae6b58e84277af5ca3730a5fafa
