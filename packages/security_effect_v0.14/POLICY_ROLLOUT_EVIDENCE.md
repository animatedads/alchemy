# Security Effect v0.10 rollout evidence

Security policy promotion may be guarded by a fixed `InstitutionalPolicyRolloutGate`. This is the deployment equivalent of the broader platform rule that operative institutional reasoning is a reviewed artefact, not a fresh runtime LLM call.

Typical Bouncer rollout metrics include sample volume, false-positive/review overturn rate, security-incident count, latency/error rate, or other host-produced aggregates. Security Effect does not prescribe which measurements an institution must use; the reviewed rollout gate does.

The gate records thresholds, minimum sample sizes, evidence-window length and freshness. The Institutional Policy catalogue computes the promotion assessment. The host cannot provide `PROMOTION_ELIGIBLE` as an assertion.

Rollout observations are not customer evidence. They must never be inserted into `SecurityEvidenceStore` merely because they originated from customer traffic. Aggregation/provenance belongs to monitoring and operational evidence systems; Bouncer's customer-level findings remain separately governed.
