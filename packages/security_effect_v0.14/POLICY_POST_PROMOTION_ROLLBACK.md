# Security Effect v0.10 post-promotion rollback

A reviewed progressive rollout may carry a separate post-promotion rollback gate. The gate is a fixed Institutional Policy artefact, not a runtime LLM decision.

The host supplies aggregate deployment observations such as evaluated-action count, false-positive rate, severe-security-incident count, latency, or another reviewed metric. These observations are governance evidence and are never inserted into a customer's `SecuritySnapshot`.

`ROLLBACK_ELIGIBLE` means the fixed degradation rule has been met and an authorized automated rollback may bind the affected deployment scope to the exact prior reviewed policy. `ROLLBACK_NOT_REQUIRED` leaves the successor in place. `ROLLBACK_INSUFFICIENT_EVIDENCE` cannot trigger automation. Stale observations are rejected from their actual recording time.

Manual authorized rollback remains independent so an institution is not trapped by metrics that failed to anticipate a novel incident.
