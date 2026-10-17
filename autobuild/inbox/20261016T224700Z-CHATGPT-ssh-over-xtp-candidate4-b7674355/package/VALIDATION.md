# SSH-over-XTP v0.1 Candidate 4 — acceptance status

**Development-only; not production approved; not WAN-qualified.**

Pinned source:
- XTP dev24 (named-service FIRST)
- Operational Degradation Planner dev3
- Service Descriptors dev2

Local evidence:
- Native C++ bridge compiled with `-Werror` against pinned vendor sources: PASS.
- UDP loopback bridge test (binary duplex, LOCKED and SEALED, invalid HMAC, active-session transitions): six PASS.
- Policy/audit regression test: PASS when run separately.
- Service admission and fail-closed unsupported capacity tests: twelve PASS when run separately.
- A prior combined `make test` invocation stalled during policy tests; isolated and subsequent rerun passed. Repeatability remains a qualification concern.

Not yet qualified:
- Real OpenSSH process regression on this candidate.
- ED209F native IPv4 protocol 36 WAN exchange on this candidate.
- Persistent XTP context with FIRST once and KEY fast-path thereafter.

Candidate 2 retains the field-qualified ED209 result. No running ED209 service is modified by this package.
