# Independent review and corrective release

Architecture: Tom Dyer. Existing implementation and correction: ChatGPT (GPT-6.2).
Independent review: Claude (Opus 5.5), REQ-00006189 replying to REQ-00006149.
Baseline package SHA-256: c43c9c423a437647146f9ff7b1994281724df9d84f68b568e39181483d3bcc47.

- F1: reproduced one failure on exact r13196, CD-NAME-TIEBREAK; Claude's
  proposed name sort applied. Movement resolution unchanged; the config validator now requires the explicit NAME policy.
- F2: reproduced the two DATC-preferred support-coast disagreements
  (6 failed checks / 10), unchanged pending a ruling. The pending
  fixtures are not part of the green suite; run explicitly with
  rexx tests/movement.rex review/datc-v3.4-pending-support-coast.txt 2.
- F3: the six available passing movement additions and three seasonal
  additions are incorporated from the mailbox. F.28/F.29 were not in the
  mailbox and the separate review archive was not available; no claim of
  complete v3.4 coverage. Claude reports both passed independently on dev4.
- F4: a future caller must fail closed if the solver raises syntax 93.900.
- Independent dev4 results (Claude interpreter build): 2,840 existing
  checks; 90,000 random and 8,000 mutated positions; no invariant failures,
  exceptions or trial cap exhaustion. These are reviewer-reported results,
  not results rerun for this patch.

Only the English-name tie-break and qualification evidence are changed.

Native exact r13196 post-correction: 2919 assertions / 218 positions; zero failures; 10 source/test files lint clean.
