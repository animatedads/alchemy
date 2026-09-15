# Access Permissions Gopher Sphere v0.3

Authoritative project sphere for the ooRexx Access Control / Authentication Attribution / Permissions workstream.

This sphere supersedes the inherited `access_permissions_sphere_v0.2.zip` for this project because the implementation has advanced to `oorexx_access_permissions_v0.3.zip`.

## Authority model

- **Authentication attribution** proves who/key produced exact evidence. It grants no authority.
- **Access Control** decides whether a subject may cross a protected domain boundary — *enter the building*.
- **Permissions** decides whether the subject may invoke an exact method on an exact object after Security Effect evaluation.
- **Alchemy Security Manager** remains the enforcement point for protected METHOD checkpoints.
- **Security Effect** remains a separate semantic authority whose assessment is bound into PermissionRequest.
- **Institutional Policy** remains the source of reviewed live policy lifecycle semantics.
- **Crypto proof** is evidence of a decision, never a bearer capability.

## v0.3 lifecycle doctrine

Access Control and Permission deliberately have different time semantics:

1. Access Control policy identity is pinned to the admitted session. If that policy becomes unavailable, suspended, withdrawn, ineffective, or a different identity becomes operative, the old session fails closed and fresh authenticated entry is required.
2. Permission policy is resolved live at every protected METHOD checkpoint, so a policy replacement affects the next method call in the same still-valid admitted session.
3. Explicit `session~close(reason)` is local in-process revocation checked before Security Effect or Permission evaluation.

## Grounding

Primary implementation artifact:

- `oorexx_access_permissions_v0.3.zip`
- SHA-256 `e6421888aa40e302dcd1262cc4289ff6ab8df7c8c389595491d843973d52281e`
- qualified 2026-09-01, module suite 11/11 PASS

Inherited sphere inspected:

- `access_permissions_sphere_v0.2.zip`
- SHA-256 `d146d73412e772f6d3abae5ed86b421c95b17d988623c23cde7aaf0a2cc52fad`

The structured articles carry machine-readable provenance down to source members and line ranges.
