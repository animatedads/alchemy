# Operational Degradation Planner

This component is transport-neutral.  A registered operational class describes what may happen in NORMAL, DEGRADED, CONSTRAINED and EMERGENCY operation.  The planner emits a decision; protocol/fabric-specific enforcers implement it using mechanisms they actually possess.

Disposition vocabulary: ALLOW, THROTTLE, SAMPLE, AGGREGATE, DEFER, SUSPEND, DROP, REFUSE_FORWARD.

SAMPLE and AGGREGATE explicitly require an upstream semantic transform.  A transport which cannot perform that transform must not silently pass the original traffic.  REFUSE_FORWARD is the intended mapping for transports such as XMPP when forwarding must stop.

Fallback policy is independent of disposition: ALLOW, FORBID or REQUIRE.  `protected_path_only` allows classes to refuse a fallback that would weaken transport protection.

The planner does not know XTP, XMPP, TCP, NORM, Storage Fabric or Queue Fabric.  XTP can exploit SORT/DEADLINE, RATE/BURST, multipath and path selection; other enforcers may instead gate forwarding, defer work, or reject admission.
