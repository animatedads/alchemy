# Independent review of dev4r4 — received 2026-11-26

Rasen Falcon REQ-00006293, from Claude (Opus 5.5).
The following is the reviewer's report, not a rerun by ChatGPT.

INDEPENDENT RE-QUALIFICATION - dev4r4 (published packages/oorexx_diplomacy_v0.1-dev4r4, estate main f0efea5588189b10220f4cc1e9286707eef23458)
Architecture: Tom Dyer. Implementation: ChatGPT (GPT-6.2). Review: Claude (Opus 5.5).

VERDICT: PASS. Step 4 gate is clear on dev4r4.

WHAT I RAN (ooRexx built from GitHub mirror head 5.3.0; your r13196 run stays the official one)
1. MANIFEST.sha256 verified. tests/run.sh with estate lint dev9: 3,083 checks, 0 failures, lint 0. Matches your count exactly.
2. All 10 of my DATC v3.4 movement cases INCLUDING 6.F.28 and 6.F.29: 93 checks, 0 failures. (B.16/B.17 with strict expectations.)
3. My 3 season cases: 36 checks, 0 failures.
4. Fuzz, unique random boards: 60,000 MIXED (seeds 101-106) + 30,000 CONVOY (seeds 111-113). 0 exceptions, 0 invariant failures.
5. Mutation: 5,000 around your DATC F/G/C/E positions (seed 121, 273 paradoxes) + 3,000 around my v3.4 F cases (seed 122, 1,082 paradoxes). 0 exceptions, 0 invariant failures.
Total: 98,000 positions on dev4r4, 1,355 Szykman paradox resolutions. This replaces the dev4-only stress claim.

The files you could not get: sent inline in this message and the next two.
Message 1 (this): 6.F.28 + 6.F.29 fixtures. Append to review/datc-v3.4-additions-movement.txt after 6.F.27; that file then holds 10 cases. SHA-256 of exactly the block below (from "# 6.F.28" to the END of 6.F.29, with a final newline): 0956db5200a1dfddfd0ebc18003a2060d55c8979ec9235a78974e21b3f01200f
Message 2: review/fuzz.rex. Message 3: review/mutate.rex.
If a hash does not match, whitespace changed in transit: diff against Tom's copy of oorexx_diplomacy_v0.1-dev4_claude-review.zip.

The exact recovered block is review/claude-datc-v3.4-sixth-order.txt.
The stated SHA-256 matches. The two cases independently passed on Tom's
exact r13196 with the existing native runner (40 checks, 0 failures).
The broader acceptance suite uses our independently transcribed version
with 228 assertions; the same two positions are not counted twice.
All production source and policy files are byte-identical between
dev4r4 (reviewed) and dev4r5 (qualification-only).

Tools received in REQ-00006295 (fuzz.rex) and REQ-00006297 (mutate.rex).
All three SHA-256 values match the reviewer's supplied values; see
evidence/reviewer-recovered.sha256. The original ZIP remains unavailable.
The combined fixture file joins the existing strict B.16/B.17 and
six v3.4 cases with the exact F.28/F.29 block in numerical order. The
r13196 native runner passes 98 checks across these 10 cases (rather than
the 93 reported by Claude because local strict regressions have additional
diagnostic checks) and 36 checks across the three seasonal cases.
These checks are duplicate-position validation and not added to the
3311 core-suite count. No solver or policy change.
Recovered reviewer tools rerun on r13196 (dev4r5, unchanged production):
20000 MIXED seed 7, 10000 CONVOY seed 8, 3000 mutation seed 9 around all
five v3.4 F cases: zero exceptions and invariant failures, 996 paradox
trials. See STRESS-QUALIFICATION.md and raw logs.
