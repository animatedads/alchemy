# NotNotes dev17 compatibility repair — 29 October 2026

## Defect
The Project Alchemy v0.5 corpus stores legacy field specifications with ten colon-separated slots; slot ten is an empty reserved field. GitHub dev17 decoded nine named slots and allowed the remaining colon to reach `x2c()`.

## Repair
The compat checkpoint parses slots explicitly, accepts the current nine-slot format and the known ten-slot empty-tail form, and fails closed on malformed hex or non-empty unknown trailing data.

## Executed evidence
- ooRexx 5.3.0 r13196.
- field-spec compatibility regression: PASS.
- actual Project Alchemy v0.5 corpus reload: PASS, 872 documents / 8 user formats.
- exact Library Single Time Service v0.10 + ConnectSelector dev8 DIRECT temporal-field regression: PASS.

## Authority boundary
NotNotes owns temporal fields and retained evidence. Single Time Service owns civil/timezone meaning. ConnectSelector owns route selection/admission. No live LDAP/HTTPS/XTP-authenticated remote route is asserted here.

## Lineage
Library dev18 Archive/Compress remains a separate patch lineage. It is intentionally not disguised as merged into this repair checkpoint.
