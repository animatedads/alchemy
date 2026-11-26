# ooRexx Diplomacy v0.1-dev2 — board and order parser

Architecture: Tom Dyer. Framework/implementation: ChatGPT (GPT-6.2).
Controlling brief: REQ-00006103; addenda 1–6: REQ-00006105, 06117,
06119, 06121, 06123, 06125. Independent adjudicator review: Claude.

## Implemented gates

1. Data-driven standard map: 75 provinces, 34 supply centres, 6 extra
   split-coast nodes. Army and fleet graphs are distinct; provinceOf maps
   coast nodes to occupancy keys. Board queries return copies. Initial
   1901 units are supplied as data (22 units); the game loader is later.
2. Referee-only line order parser: movement, hold, support, convoy, retreat,
   disband, build and waive. Original lines retained. Case and spacing only
   are normalized. Static validity and duplicate unit orders are handled
   against supplied state; all 12 specified invalid reason codes exercised.

Adjudication is NOT implemented. A syntactically valid order or one passing
static validation is not necessarily successful or executable. Non-adjacent
coast-to-coast army moves remain candidates for convoy resolution; matching
support orders, actual convoy routes, paradoxes, combat, retreat collisions,
mandatory adjustment counts, civil disorder and builds at the same site
must be settled by later gates. No legal-order API is exposed to players.

All rulebook/DATC policy choices are recorded in data/rules.conf; gate 3 must
load and print it. The data file is not yet consumed by an adjudicator.
Last order for a recognizable owned unit wins, even if malformed; an order
without a recognizable unit does not replace a previous order. Multiple
builds in one province are not treated as duplicate *unit* orders here.

## Verification

The independent graph reference transcription in evidence/reference-edges.txt
comes from the factual adjacency data in diplomacy/diplomacy standard.map,
Git blob 620fa3a81acb4c0021bd2cd5aec3628b66b373a3:
https://github.com/diplomacy/diplomacy/blob/master/diplomacy/maps/standard.map
The original reference distinguishes fleet edges by case; Switzerland is
impassable. The native cross-check compares every graph node and typed edge,
all supply-centre home codes, and initial unit occupancy. The initial setup
also matches the reference's power/unit list by inspection.

Native baseline: supplied ooRexx 5.3.0 r13196 x86_64 internal debug build.
Tests: 513 board, 933 reference, 180 parser = 1,626 assertions, zero failures.
All six ooRexx source/test files lint clean using the estate SourceLinter,
P1–P4, P7 and P9, and exact Git blobs:
* PitfallChecker.cls e6ee19c34dd441170d8dcc023277b4042819463d
* SourceLint.cls 7295efb10e6ff0b53315900eb26c9d747182c11c

Run `sh tests/run.sh` from a package extraction with rexx on PATH and
ALCHEMY_REPO_ROOT pointing to a checkout of the estate. For the local run,
only those two lint files were retrieved from Git and hash-verified in a
minimal mirror; a full estate checkout and field autobuild receipt were
not available. No substitute interpreter or Python game orchestration.

## Remaining gates and decisions

Gate 3: Kruijswijk adjudicator including guessing/backup and Szykman rule;
DATC section 6 runner loading the policy file. Gate 4: retreats and
adjustments; then stop for independent Claude review before gate 5.
Later: deterministic game loop/replay; per-player per-round shuffled press;
Haiku/Sol runtime adapters; dossiers and sealed prompt revisions; regex
control guard and removal notice; rotation, sum-of-squares scoring and
exact-score token/centre tie-break; saved-position recovery test.

All seven designer identities and their exact model versions must be logged
with each prompt version and SHA-512 hash. No competition prompts are included.
