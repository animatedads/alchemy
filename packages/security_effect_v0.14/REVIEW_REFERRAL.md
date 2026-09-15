# Security review referral boundary

Security Effect v0.11 can refer an exact action-scoped Security assessment to Relationship Case v0.2 / Relationship Case Service v0.1.

The referral boundary is intentionally asymmetric:

- Security Effect remains authoritative for the Security assessment and trace.
- `SecurityReviewReferralPolicy` is a sealed, versioned institutional algorithm deciding whether that assessment should create review work.
- Relationship Case owns the durable review workflow and information-barrier projection.
- The eventual authoritative business domain owns any account/payment/customer mutation.

The bridge attaches only opaque references:

- `SUBJECT / SECURITY_SUBJECT`
- `ASSESSMENT / SECURITY_ASSESSMENT`
- `POLICY_REFERENCE / SECURITY_REVIEW_REFERRAL_POLICY`

It never creates `DECISION` or `ACCOUNT_CONTROL` case elements. Therefore a Bouncer referral can open work but cannot satisfy a later case-policy prerequisite for execution authority.

Case and command identifiers are derived deterministically from the exact Security assessment. Exact retries are therefore handled by Relationship Case Service's existing idempotency receipts instead of creating duplicate review cases.
