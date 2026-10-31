# BundySlam v0.2.1 — continuation precedence qualification (31 October 2026)

## Context and source authority

Candidate derived from exact BundySlam v0.2 ZIP (SHA-256 `30e1d483ea62c8805efc6c926cc07f0c5f3d29252de4d97dff7a4ff2be613ad2`), independently recovered from the Library and verified byte-for-byte against the GitHub transport manifest. No modifications were made to that v0.2 archive or to the original submission branch.

## Reproduced defect

In `BundySlam~card`, the physical-record recogniser checked the initial token `DD` *before* checking whether the prior JOB/EXEC/DD statement was awaiting a continuation. If a card with columns 3–15 blank started with `DD` in column 16, the reader erroneously created an unnamed DD; this interrupted the prior statement, issued spurious DD scope diagnostics, and could open an incorrect `DD DATA` stream. The true owner is the pending statement. This is a card-position/state error, not a spelling error.

## Fix

When columns 3–15 are blank, test `pending` before classifying `DD` as an unnamed DD statement. A new unnamed DD is still recognised when **no** statement continuation is pending. Original bytes, columns, ordered card/statement events, and provenance remain untouched. There is no automatic repair and no JES execution.

## Qualification

Environment: supplied ooRexx 5.3.0 r13196 Internal Test Version in isolated extracted .deb. `sh run_qualification.sh` reports:

- Physical-card/statement ooRexx regression: **176 / 176 PASS** (up from 166).
- SLAM store spy adapter (no SQLite): **9 / 9 PASS**.
- Acquisition auditor: **7 / 7 PASS**.
- Three supplied candidate decks remain read-only; assembler seed: 32 cards / 15 statements / exact byte round-trip / zero structural diagnostics.

Ten newly added assertions cover continuation precedence, no false DD scope, no artificial instream opening, operand and round-trip retention, and nonpending unnamed DD regression.

## Hold points

- No claim of tested actual `SlamStore` / `RexxSqlSqliteSession` integration (the required Rexx/SQL backend was not installed in the execution runtime).
- No real Hercules/JES job accepted or executed, and no observed JES return code.
- External source corpus acquisition still awaits Git/network-enabled fetch in a qualified environment.
- No production/JES/volume modification is authorised by this patch.
