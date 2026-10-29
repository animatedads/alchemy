## v0.4 (2026-10-29)
- Protected named-service read admission: XTP dev34 keyPrincipal, current key registry and revocation, encrypted-only.
- Added current cross-listener replay limitation and multicast group-key qualification gate.

## v0.3 (2026-10-27)
- Record identity-drift rejection during incoming memory READ admission.

# Sphere changes

## v0.2 (2026-10-27)
- Record source-side read ingress identity, ACL, replay, expiry and owner-epoch doctrine as `arch.memory-fabric.read-ingress`.
- Record unqualified production identity/ACL, native listener integration and page-data commit as remaining work.
