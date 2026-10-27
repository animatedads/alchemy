# General ooRexx Deployment Gopher Sphere v0.3

Authoritative continuity sphere for the shared General ooRexx Deployment component.

v0.3 aligns production dependency authority with the current Semantic Source Store:
a release represented by a QUALIFIED SSC module deployment is an immutable fixed
point whose exact transitive dependency deployment ids must not float.  Deployment
consumes the sealed SSC package/receipt and then owns deterministic target namespace
materialisation, explicit `REXX_PATH`, package-load verification and activation.

The earlier `SSC_MANIFEST` / `@source-requires ... AT_LEAST` / reachable `::requires`
resolver is retained as DEVELOPMENT/LEGACY_INTAKE authority for source not yet sealed
as an SSC module deployment. It is no longer the preferred production authority.

Current candidate:

- `oorexx_deployment_v0.1-dev4.zip`
- SHA-256 `c6f04ddc6bcb80963161d3312b773cbc4c58fdbd2f99907662aa4a0d6ad23ce2`
- SSC identity `OorexxDeployment / MAIN / sourceLevel 2`
- deterministic POSIX dependency namespace: qualified
- full ooRexx r13196 dev4 regression: pending in this environment

Last full runtime-qualified baseline:

- `oorexx_deployment_v0.1-dev3.zip`
- SHA-256 `796b4375b7abac6e13e5f23f632c8aa75f86fe777f3d7c130ea8e440ff5dbd79`
- ooRexx 5.3.0 r13196

The sphere retains reconciliation, target-loadability, Audio first-consumer,
hosted MCP/Wire lifecycle, transport/provider and concurrency doctrines.  It
keeps executable capability separate from next-revision requirements and from
current external SSC repository contracts.
