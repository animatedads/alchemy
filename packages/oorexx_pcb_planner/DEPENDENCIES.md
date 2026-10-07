# Dependencies

- Rexx-tronics: electrical truth (Circuit, Component, Pin, ElectricalNet).
- ooRexx Intention Service v0.1-dev11: discovery freshness, transient intention surfaces, evidence ledger, decision/dispatch contract.
- Physical Manufacturing: authoritative fabrication capability; PCB Planner consumes a source-attributed projection and does not own process limits.
- Common Parts: authoritative exact part/package/pin/geometry identity as those adapters are bound.
- Materials: authoritative material properties as stack-up/material qualification is bound.
- Physics World: authoritative physical qualification as thermal/EM/mechanical adapters are bound. Library head observed during dev4 work: v0.1-dev50.

Coding Intention is deliberately not a PCB runtime dependency. It is ooRexx language knowledge, not PCB-domain intention authority.
