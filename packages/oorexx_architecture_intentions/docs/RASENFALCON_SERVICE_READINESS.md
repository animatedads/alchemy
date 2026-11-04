# Dev11: architecture read-only service readiness for Rasen Falcon

`ArchitectureServiceReadiness` collects explicit service readiness gates. Its verifier is injected; untrusted receipts and source tests alone cannot mark gates as complete. It only stores whitelisted public evidence references. It never deploys, constructs SSC locks or grants live production status.

`ArchitectureRasenFalconBaseline` declares separate public-site, private-office, mail and internode required evidence. Important invariants:

- Public anonymous website is **not** gated on LDAP; private Office/NOC and Wire webmail do require active LDAP and explicit rights.
- SMTP delivery, IMAP mailbox reads, active LDAP rights, own TLS, and live probes are distinct mail gates. Bind alone never implies `EMAIL_SEND`.
- Internode MI↔own MU requires exact XTP Layer 2 EtherType `0x817D`, selected named-service/session protection and live evidence; generic IP reachability is insufficient.
- Production activation is not established by evidence-complete architecture alone: `EVIDENCE_COMPLETE_OPERATOR_REVIEW_REQUIRED` is the strongest result.
- Exact package/SSC lock and target/native Deployment qualification are outside this authority.

This change lives only in Architecture Intentions and does not modify website, SMTP, IMAP, LDAP, XTP or Deployment owners. Tests use an explicitly synthetic verifier and are **not** live-host qualification.

## ConnectSelector dev8 (29 October 2026)

ConnectSelector v0.1-dev8 adds `ConnectAuthenticatedRoutePolicy` to admit remotely selected RPC, QueueFabric and RTO2 routes through externally trusted `authorizeRoute(intention, provider)` evidence; it does not authenticate a route simply because the caller sets an option. The Architecture readiness request can document an `XTP` or other route proof but cannot replace that route policy or qualify a peer/MI/MU cryptographic handshake. The underlying ConnectSelector selection is still its own authority.

## Scope and service ownership

The project-specific gate catalog is a *required-proof proposal*, not a directive to change provider implementations. It deliberately makes no deployment calls. Public content may be served anonymously; private services require separate authenticated attribution and ACL evidence. Fixed organisational private CA policy must be represented by the actual HTTPS/SMTP/TLS service evidence and its reviewer, not synthesized as an architecture planner attestation.
