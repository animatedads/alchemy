# XTP dev21 — Operational Priority Operation

The Operational Degradation Planner is transport-neutral. XTP dev21 consumes its Decision objects.

* ALLOW -> send.
* THROTTLE -> send with class pacing and XTP SORT/DEADLINE where declared.
* SAMPLE / AGGREGATE -> fail closed until an upstream semantic transform supplies replacement payload.
* DEFER / SUSPEND / DROP / REFUSE_FORWARD -> do not transmit.
* fallback ALLOW / FORBID / REQUIRE -> controls survivor/cross-path eligibility.
* protected_path_only -> refuses weaker fallback paths.

This is selective fallback by registered operational class, not XTP-only policy. Other protocol adapters can enforce the same planner decision using their own mechanisms (for example XMPP stanza filter/refuse-forward).
