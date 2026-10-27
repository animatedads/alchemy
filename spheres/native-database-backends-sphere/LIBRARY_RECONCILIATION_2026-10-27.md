# Native Database Backends Library/Git reconciliation — 2026-10-27

## Scope

This note records an observed publication/version gap. It does not promote a Library
archive, replace qualification evidence, or claim that the current Git tree is byte-identical
to an archive that has not been inspected.

Rasen Falcon lane: `oorexx_native_database_backends`
Authenticated owner at the time of this reconciliation: `CHATGPT`
Ownership id: `OWN-00000574`.

## Exact Library observations

Direct Library metadata listing on 2026-10-27 found:

- `/oorexx sql things/oorexx_native_database_backends_v0.3.4.zip`
  - created: 2026-10-23 17:44:51 UTC
  - size: 42,519 bytes
  - Library file id: `file_00000000873081f4930eea804e698250`
- `/oorexx sql things/native_database_backends_gopher_sphere_v0.2.zip`
  - created: 2026-10-23 17:44:53 UTC
  - size: 22,781 bytes
  - Library file id: `file_0000000076c882438364c0b75109147d`

The Project Alchemy Package Register v0.4 still records Native Database Backends
v0.3.1 as CURRENT_LIBRARY. Therefore the register and the raw Library inventory are
not at the same publication point.

The current tool session could not materialize either ZIP's raw bytes: Library returned
"does not have an authorized raw-byte materialization path". No content claim about
v0.3.4 or sphere v0.2 is made here beyond their observed metadata.

## Current Git/Rasen observations

Rasen Falcon lane search resolves:

- package artifact stem `oorexx_native_database_backends`
  - Git catalogue path currently `packages/oorexx_native_database_backends_v0.1`
- sphere artifact stem `native-database-backends-sphere`
  - Git catalogue path currently `spheres/native-database-backends-sphere`

Git package README currently labels itself v0.1. The Git sphere README currently labels
itself v0.1 and says its grounded implementation baseline is
`oorexx_native_database_backends_v0.2.zip` SHA-256
`c87731ff59d378a1bbe9470b103fe36f96e4d0a7f808c2fcdc7ac53dd9ff066b`.

This is a continuity/versioning gap, not evidence that one side should silently supersede
another.

## Selector work already present on Git main

The current Git package contains the runtime `DatabaseBackendSelector` package-isolation
boundary, the PostgreSQL provider package, selector collision regression, and the
configuration-only provider rule used by Semantic Source Store. Those changes must be
preserved during any v0.3.4 intake/republication.

In particular:

1. Neutral consumers must not statically load NoSQLServer and Database Core public class
   sets into the same package namespace.
2. `DatabaseBackendSelector` loads only the configured provider package.
3. Backend selection is configuration-only and fails closed.
4. Existing provider/session semantics are not silently replayed through another backend
   after acquisition.
5. The previously qualified SSC PostgreSQL deployment variable family
   (`SSC_DB_*`, `SSC_POSTGRESQL_BRIDGE`) remains an accepted configuration surface.

## Required reconciliation

Before publishing a Git directory/version as v0.3.4 or a sphere as v0.2:

- obtain/read the exact Library archive bytes;
- compare manifests and source against current Git;
- preserve newer Git selector/package-isolation work if it is absent from the Library
  archive;
- preserve Library v0.3.4 work if it is absent from Git;
- run the package-owned selector/capability/backend tests against ooRexx 5.3.0 r13196;
- record exact hashes and qualification boundaries;
- then publish one explicit reconciled development head rather than relabelling either
  side without evidence.

No approval, promotion, or qualification is implied by this note.
