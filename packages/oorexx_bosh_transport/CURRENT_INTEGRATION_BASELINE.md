# Current integration baseline checked 2026-10-24

Current externally evidenced authorities:

- Socket Provider **v0.1-dev16**
  - SHA-256 `fe2fa086bd4f1e072b8d455e6adb4475482b8db6a35118329f6b3f6e6253c8c2`
- Network Transport Intentions **v0.1-dev3**
  - SHA-256 `d90dc49e4799f929761e75b302ab141a3bab481efdf951cdd508491a9b18c64b`
- Instrumentation Mesh **v0.1-dev8**
  - SHA-256 `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624`
- XTP development head **v0.1-dev25**
  - SHA-256 `7f6ab3d1167d5fd3131c7e6d6e9ea8d8c6115106ea9df89d41357ef56773b80b`

BOSH remains an HTTP-carrier logical stream through the shared provider/selector boundary. None of these versions is hard-coded into the BOSH core API.

## Source-publication boundary

The Library identifies Socket Provider dev16 as the current common isolation authority, but the first-class GitHub source tree at `packages/oorexx_socket_provider/` still identifies itself as dev14. Do not rewrite or relabel that tree as dev16 without the exact dev16 source archive/revision. Qualification against dev16 therefore requires the exact external dev16 source package until upstream source publication is reconciled.

Instrumentation Mesh has the same publication constraint: dev8 is the current qualified observation baseline, while its sphere records that the exact first-class dev8 runtime source still needs publication. BOSH dev6 fails closed when the required exact source roots are absent.

XTP dev25 is recorded as current development context only. BOSH has no XTP dependency and does not select XTP carriers.
