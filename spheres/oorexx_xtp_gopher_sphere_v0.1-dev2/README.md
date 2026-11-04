# Update 2026-10-29 — dev2

Added `xtp.provision-ingress`, native ooRexx r13196 proof, and corrected dev34 cryptographic session versus MI identity boundaries. The source package is **not** a field-qualified provision daemon.

# ooRexx XTP Engineering Sphere v0.1-dev1

This source-qualified LLM Gopher sphere covers XTP named-service transport, endpoint ROUTE/XROUTE, operational degradation, Storage Fabric concurrency, and **proposed** secure route/service-point commissioning through `xtp.provision`.

It is documentation and continuity, **not an executable XTP routing/provisioning service**.

## Start

```sh
gopher --profile xtp context xtp --full
gopher --profile xtp search provision --sphere xtp
gopher --profile xtp search pressure --sphere xtp
```

Use a local LLM Gopher v0.21+ installation and resolve `packs/core` and `packs/oorexx` from that installation. `python3 tests/test_sphere.py` independently checks sphere shape, links, pinned source-member hashes, security boundaries and artifact-free reproducibility.

## Source/authority boundaries

- XTP v0.1-dev25 and Planner v0.1-dev5 are inspected local development artifacts, not an accepted `main` or ED209 field release claim.
- Service Descriptors v0.1-dev2 owns named service registration; applications cannot assign operational class or advertise transport addresses in service records.
- Storage Fabric v0.1-dev23 owns object/range identity, integrity and reallocation; XTP owns path reliability and per-context pacing.
- `xtp.provision` is only a proposal and offline signed-envelope contract in `xtp_route_publication_v0.1_candidate1.zip`.
- Remote authenticated XTP KEY-bound gateway sessions, durable quorum commit, atomic route activation, and ED209 raw36/L2 field qualification **are missing**.

## Integration and field safety

A publication signed by an MI is an *offer*, never approval. Controllers authorise per-target configuration; quorum must count distinct authorised signatures **over durable committed state**. File journal first; LDAP Identity Directory optional as identity/ACL projection and durable sync adapter, **not** consensus. Seed trust and recovery routes stay immutable, and no downloaded update may remove emergency access.

Release/promotion gates and exact ZIP SHA-256 source names are pinned in `packs/xtp/articles/xtp.qualification.json` and `SOURCE_MANIFEST.json`.
