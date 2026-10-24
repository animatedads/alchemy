# Architecture Intentions → NotNotes publication boundary (dev10)

The planner produces an immutable-by-value, non-executable architecture publication **request**; only the NotNotes authority may create or revise its document record. It must authenticate the author, apply institutional policy, enforce document ACLs and revision checks, and return an independently verifiable NotNotes document/revision receipt. The SSC proof is separate evidence and confers no document-write authority.

This dev10 integration stops at the request contract. No NotNotes document has been written, no production publisher or SSC resolver is claimed, and the ooRexx r13196 native test remains pending in the present environment.

Library source anchor: `alchemy_notnotes_v0.1-dev15.zip` SHA-256 `57a7d1b09234621f20c9de5dda312b4e38140b57cb87c45f7318e59730db4488`. The Project Alchemy NotNotes v0.6.2 **corpus** documents later portfolio state but does not supersede dev15 executable source by assumption.
