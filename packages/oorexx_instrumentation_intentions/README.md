# ooRexx Instrumentation Intentions v0.1-dev2

Read-only specialist intentions over **Instrumentation Mesh v0.1-dev8**.

Dev2 retains the dev1 latest/health/metrics/history/series/progress and privacy-preserving socket telemetry seams, and adds the Mesh dev8 read side: bounded operational events, source-supplied correlation IDs, producer-declared causation/context, observed relationships, and caller-clock publication freshness.

Correlation is never inferred from time, host, topology or severity. Stale telemetry is not rewritten as service failure. No Instrumentation Mesh command envelope is exposed.
