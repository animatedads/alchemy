# Validation

Qualified on ooRexx 5.3.0 r13196 against the current FederationBank/API component closure.

Acceptance evidence:

- 8/8 core Staff Authority executable tests pass.
- 1/1 full Relationship Case -> Relationship Adapter -> Staff Authority -> Core Banking -> Ledger integration test passes.
- Maker/checker separation rejects self-approval and validates independent checker role/context.
- Branch, desk and session scope participate in authority.
- Delegation remains bounded and cannot enlarge policy authority.
- Temporary elevation is explicit, bounded and evidence-backed.
- Positive authority is bound to the exact Core Banking command; tampering is rejected.
- Staff authority and customer/product Core Banking policy are independently enforced.
- Full relationship/staff/core chain preserves relationship and staff authority evidence into the ordinary Core Banking command.
- All 6 package `.cls` files pass `rexxc` (source, fixtures, integration bridges, runtime and test support).

See `VALIDATION_TRANSCRIPT.txt` for the executed test/compile evidence.
