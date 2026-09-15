# Camera Behaviour v0.42 / Alchemy Objects v0.8 compatibility

Camera v0.42 rebases all Alchemy-derived Camera classes onto Alchemy Objects v0.8 and declares `ALCHEMY-HOUSE-OBJECT-0.8`.

Alchemy v0.8 retains bounded execution provenance and adds cooperative method interposition. Camera continues to instrument the assessment/trend pipeline; when an active compatible coordinator is present (for example ooRexx Logging v0.5), Alchemy can join that coordinator rather than replacing its physical wrapper.

`CameraProductionIdentity` binds retained assessment evidence to Camera package version, Alchemy base version, assessment contract id/revision and Camera contract-shape id, construction provenance, and initial/current inheritance-integrity fingerprints. SHA-512 is retained in full and a 96-bit prefix is used as the compact producer token.

Camera now explicitly declares ooRexx Crypto v0.4 because producer identity directly uses SHA-512. These identities are evidence, not authorization or policy authority.
