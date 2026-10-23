# XTP route/service-point publication — v0.1 candidate1

This is a **review candidate with a testable security/authority contract**, not a production XTP node-commissioning daemon.

- `docs/ARCHITECTURE.md`: proposal, authority model, DHCP-like lifecycle, exact integration boundaries, paired/multicontroller behaviour, security and acceptance gates.
- `reference/provision_contract.py`: standalone *offline* Ed25519 envelope verifier for ownership/quorum/scope/class/replay/lease validation; no native XTP calls, persistence or route mutations.
- `tests/test_contract.py`: negative and positive contract tests.
- `examples/`: public, illustrative records only; example underlay addresses are RFC5737 documentation values.

Run: `python -m unittest discover -s tests -v`

Requires Python 3 and `cryptography` for the **offline independent reference tester**. Production target is the existing ooRexx/XTP/Service Registry/LDAP/Crypto stack; Python is not an architectural dependency.

### Source reconciliation reviewed

- `oorexx_xtp_v0.1-dev25.zip`: named-service FIRST, route TSV and sender pacing; does not evidence remote mutual authentication.
- `oorexx_service_descriptors_v0.1-dev2.zip`: service->operational class->logical peer->service point; disallows IP addresses in descriptors.
- `oorexx_ldap_identity_v0.1-dev18.zip`: identity/ACL resources, fenced peer epochs, outbox/ACK model and persistence; LDAP Bind != authorisation, replication != consensus.
- `oorexx_crypto_v0.8.3.zip`: Ed25519 primitives via ooRexx Runtime Reference/native implementations.
- `xtp_gateway_v0.1-dev1_candidate.zip`: one gateway and local UID registration proof; **unauthenticated remote XTP dev-only switch**, not field safe.

This package does not alter any of those baselines.
