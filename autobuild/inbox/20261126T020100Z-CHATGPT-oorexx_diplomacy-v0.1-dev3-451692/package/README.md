# ooRexx Diplomacy v0.1-dev3 — movement adjudication

Architecture: Tom Dyer. Implementation: ChatGPT (GPT-6.2).
Controlling brief REQ-00006103; addenda 1–6 REQ-00006105, 06117, 06119,
06121, 06123, 06125. Independent reviewer: Claude.

## Implemented

Retains dev2 board and parser (official Autobuilder PASS). Map 75 provinces,
34 centres, six split-coast graph nodes, 22 initial units; static order
validation and duplicate handling. Dev3 adds DiplomacyAdjudicator,
DiplomacyMovementCalculation, DiplomacyGuessTrial and DiplomacyMovement.

`judge = .DiplomacyAdjudicator~new(board, 'data/rules.conf')`
`movement = judge~movement(units, submitted)`

Units: directory keyed by province; values are DiplomacyUnit objects.
Submitted: directory keyed by power, values arrays of original order lines.
The referee validates and resolves simultaneously; no player legal-order API.
The result exposes units, dislodged (original unit, attacker origin), outcomes,
standoffs, paradoxes and published (power, original line, status) records.
Board input and raw order arrays are unchanged. Missing/invalid orders hold;
physically impossible convoy routes are distinguished from unmatched convoy
orders on a route that could physically exist. Army/fleet coast geometry,
support matching/cutting, self-dislodgement, head-to-head strength, circular
movement, multi-route convoys, Szykman paradox backup, and published outcomes
are included. Final decisions are checked against the equations except for
explicit paradox overrides. A bounded unresolved calculation fails closed.

## Qualification

Run `sh tests/run.sh` with rexx on PATH and ALCHEMY_REPO_ROOT pointing to the
estate checkout; uses hash-pinned estate SourceLinter before the native suites.
Interpreter: ooRexx 5.3.0 r13196 supplied debug build. Dev2 board 513,
reference 933, parser 180 checks; dev3 32 original movement positions (147
assertions), 130 DATC v3.0-derived movement positions (582 assertions).
Total 2355 checks. The DATC runner prints all active policies and verifies
unique case IDs and expected case count. All positions also test conservation
and reversed-input insertion replay. See evidence/DATC-PROVENANCE.md for
policy choices, source licenses and qualification limitations.

The 130 positions span sections 6.A–G, excluding adjustment test B.14,
plus an explicit convoy variant of G.11. Outcome assertions are selective;
full DATC compliance is NOT established. Full retreat options and builds,
civil disorder, broad stress testing and independent review are outstanding.
No game loop, press, prompt evolution or tournament code is present.

## Next gate

Step 4: retreat options/collisions, builds/disbands, civil disorder and
post-Fall ownership. Qualify DATC sections H onward and remaining movement
retreat expectations, then stop and submit to Claude for independent review
before game loop. No competitive prompts are included.
