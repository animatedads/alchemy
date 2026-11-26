# Independent review and corrective release

Architecture: Tom Dyer. Existing implementation and correction: ChatGPT (GPT-6.2).
Independent review: Claude (Opus 5.5), REQ-00006189 replying to REQ-00006149.
Baseline package SHA-256: c43c9c423a437647146f9ff7b1994281724df9d84f68b568e39181483d3bcc47.

- F1: reproduced one failure on exact r13196, CD-NAME-TIEBREAK; Claude's
  proposed name sort applied. Movement resolution unchanged; the config validator now requires the explicit NAME policy.
- F2: reproduced the two DATC-preferred support-coast disagreements
  (6 failed checks / 10) under the DATC-preferred option. Tom Dyer ruled
  "Strict." on 2026-11-26. SUPPORT_COAST=STRICT is now required by the
  rules validator. Both strict-policy fixtures check the INVALID:BAD_SUPPORT
  status, board outcomes, and dislodgement; original preferred expectations
  are preserved in review/datc-v3.4-preferred-support-coast-reference.txt
  as intentional 4.B.5 deviations. No resolution behavior changed.
- F3: the six available passing movement additions and three seasonal
  additions are incorporated from the mailbox. F.28/F.29 were not in the
  mailbox and the separate review archive was not available; no claim of
  complete v3.4 coverage. Claude reports both passed independently on dev4.
- F4: a future caller must fail closed if the solver raises syntax 93.900.
- Independent dev4 results (Claude interpreter build): 2,840 existing
  checks; 90,000 random and 8,000 mutated positions; no invariant failures,
  exceptions or trial cap exhaustion. These are reviewer-reported results,
  not results rerun for this patch.

Dev4r1 changed the English-name tie-break and qualification evidence. Dev4r2 records F2 and adds strict-policy regressions; the existing solver and parser behavior are unchanged.

Native exact r13196 post-correction: 2919 assertions / 218 positions; zero failures; 10 source/test files lint clean.

Dev4r2 exact r13196: 2934 assertions / 220 positions, zero failures, lint zero. The validator also rejected SUPPORT_COAST=PERMISSIVE with syntax 93.900, as intended.

Dev4r3: REQ-00006237 supersedes the unique/omitted-coast policy and changes
the wrong supported origin diagnostic from BAD_SUPPORT to BAD_COAST.
See LITERAL-AUDIT.md for the strict correction and remaining audit items.
Earlier results in this file apply only to their named version.
