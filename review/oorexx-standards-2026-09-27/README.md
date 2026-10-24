# ooRexx coding-standards review evidence — 2026-09-27

The September audio/Physics review used two user-supplied aids: Claude's `oorexx_standards_enforcer.py` and Grok's `family.rex`. The original contributed files remain in user Library/conversation evidence; this Git tree records engineering conclusions rather than silently claiming authorship of those tools.

Key conclusions:
- `+0` is method dispatch, not coercion; check numeric inputs instead.
- `&`, `|`, and `&&` require deliberate evaluation semantics; use nested guards where later evaluation depends on earlier validation.
- `Array~remove` leaves sparse slots; `delete` compacts; `Queue~pull` is FIFO.
- `RESULT` is special state and should not be reused casually.
- activity/message boundaries require explicit method-visibility review.
