# MVS Alchemy Services (MAS) v0.1-dev3-pre1

Unqualified BASE-1 candidate for MVS 3.8j TK5 under Hercules, built incrementally from the supplied v0.1-dev2 BASE-0.5 package.

Dev2 remains the authority for the already-qualified pre-transport frame/typed/replay reference. This pre1 adds the BASE-1 transport boundary, live-IVP gate, personality reservations, LDAP design boundary, and a deliberately failing S/370 MASIVP1 safety stub. It does **not** guess the DYN75 calling convention and does **not** claim a live Hercules crossing.

## Reference checks

From the package root:

    python3 HOST/tests/wire_reference.py
    python3 host/reference/selftest.py

Expected:

    MAS BASE-0.5 wire/typed/replay reference: PASS
    MAS dev3-pre1 wire reference: PASS

## Qualification

`qualification/BASE1/qualification.txt` is `NOT_RUN / UNQUALIFIED`. BASE-1 is reserved for the real TK5+DYN75+ooRexx endpoint evidence described in `qualification/BASE1/README.md`.

Alchemy Objects v0.8.1 and the Alchemy LDAP / Identity Directory library are external dependencies and are not vendored.
