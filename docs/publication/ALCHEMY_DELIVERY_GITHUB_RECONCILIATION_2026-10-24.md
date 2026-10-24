# Alchemy delivery-to-GitHub reconciliation — 24 October 2026

**Scope:** `animatedads/alchemy` default branch `main`; ChatGPT Library delivery archives and the associated October Alchemy workstreams. This is a **source-publication and provenance ledger**, not a declaration of Autobuild acceptance or runtime qualification.

## Method and boundary

- GitHub observed on 2026-10-24 at `31e76fc0767dc8006b66041da9dc9352969be19c` before this ledger update. Top-level repository listing contained **351 `packages/` entries, 111 `spheres/` entries and 49 `examples/` entries**. These are directory counts, not accepted-product or fully synchronized-package counts.
- Inspected the **1,000 most recently modified Library entries**, covering 2026-10-10 through 2026-10-24, and specifically the October source ZIP names. Spot-checked GitHub source versions, package README/status records and selected exact archive SHA-256s.
- GitHub listed **118 branches**, including **69 `autobuild-submit/` branches**, **59 dated 23–24 October**. Yet `autobuild/receipts/` on `main` contained only **19 receipts, all dated 22 August**. A submission branch is **not** a receipt or promotion; absence of a receipt here does not establish a test result.
- This audit does **not** assert byte-for-byte parity of all the thousands of Library files. Uninspected archive versions and dependency closure remain open. Audit statuses below use `MAIN`, `SUBMITTED/BRANCH`, `PARTIAL`, `BEHIND`, `MISSING`, and `REVIEW`; none means `ACCEPTED` unless a matching receiver receipt and test evidence have been checked.

## Verified missing, partial or lagging publication

| Workstream and exact Library delivery | Library archive SHA-256 if byte-verified | Observed GitHub state | Publication work required |
| --- | --- | --- | --- |
| Single Time Service `single_time_service_v0.9.zip` (82 files) | `914e99e944fcd2e6d4f20c47e0850ca207318d7641c5f432d2d4aa10bd172038` | **MISSING complete source**; `packages/single_time_change_publication_v0.9` is only the additive change component. [Issue #25](../../issues/25) already records the distinction. | Import complete owned source/tests/TZif fixtures and dependency locks; submit as a whole managed package. |
| ConnectSelector `oorexx_connect_selector_v0.1-dev6.zip` (24 files) | `6ea919552264a8d50db77b2a513990226a869ebbf3ed930e98c055c8175184ae` | **PARTIAL**: `packages/oorexx_connect_selector_v0.1-dev6` contains a README and dev5-to-dev6 patches, while `spheres/connect_selector_gopher_sphere_v0.1` is present. The README expressly says full standalone source is missing. | Admit all 24 owned files; preserve JMS ACCEPTED/REJECTED/UNKNOWN semantics; qualify real transports separately. |
| Instrumentation Mesh `oorexx_instrumentation_mesh_v0.1-dev8.zip` | `47402459e658da6ddb17c65c98010c0acd0e35d43b3a0b01c8c13c835f65d624` (recorded in [Issue #34](../../issues/34); archive not byte-rechecked here) | **MISSING first-class dev8 runtime**; Gopher sphere on `main` and Storage Fabric Instrumentation Mesh dev5 are not that package. | Recover exact dev8 archive, publish executable code/tests and update the sphere evidence. |
| Rust native `oorexx_rust_native_v0.1-dev30.zip` (45 files) | `fa4a04da499564af05a79ce1b8a2a31834e45f05905fef9923e5d008fa55f5f4` | **MISSING first-class source package** under `packages/oorexx_rust_native`; `spheres/rust_alchemy_bridge_sphere_v0.1` documents dev30 but is not code admission. | Submit standalone Rust crates/shim, exclude generated build artifacts, keep PC/Android qualifications distinct. |
| Terminal Machine `oorexx_terminal_machine_v0.22-candidate12.zip` (131 files) | `e57dcf302070380a6e714ab0a5e8d1adb65b8c27974c34115712dc6314b00f8a` | **BEHIND**: generic `packages/oorexx_terminal_machine` README reports v0.21; latest separately named source tree visible is candidate3, not candidate12. | Reconcile candidate12 exact source/test/qualification files without overwriting earlier candidate history. |
| Ruby Alchemy `oorexx_ruby_alchemy_v0.1-dev19-source.zip` (26 files) | `9049fc611f8fa1be34aa9c7ff8ee880258493281e6783f302a11ac1cfebeaad5` | **BEHIND**: `packages/oorexx_ruby_alchemy/README.md` announces dev17. | Verify dev18/dev19 source delta, submit native source and tests; omit packaged `.so` from source, retain hash/provenance. |
| Odoo CRM provider `oorexx_odoo_crm_provider_v0.1-dev11.zip` (31 files) | `d27ecf896b551e1923e52be20d990423c6f79cc7093e61ab96e6c5a50d714479` | **BEHIND**: `packages/oorexx_odoo_crm_provider/VERSION.txt` is dev7.1.1. Gopher sphere present. | Admit dev11 source with dynamic Odoo discovery, relation/cache and callback regression evidence. |
| LDAP Identity `oorexx_ldap_identity_v0.1-dev19.zip` (115 files) | `14d41d9c1cd339ccd99bc1a344b182fdb86ef2b5c30ee6454dd2fbfe1525d8ec` | **BEHIND**: `packages/oorexx_ldap_identity/VERSION.txt` says dev14; separate dev19 sphere was committed on a branch. | Close package-version mismatch, source/test/parity review and strict lint errors before declaring qualified. |
| Native Database Backends `oorexx_native_database_backends_v0.3.4.zip` | Not byte-materialized: Library raw-byte access refused for this particular file. | **BEHIND, provisional**: `packages/oorexx_native_database_backends/README.md` announces v0.3.1; v0.3.4 archive appears in Library. | Obtain authorized archive bytes; compare source and native PostgreSQL contract; include updated sphere v0.2. |
| Vision `oorexx_vision_v0.1-dev20-keyframe-ownership.zip` (43 files) | `3f35f3337e14d0539435db21224c2f206e7d67b7c57869a82a140e53ba919cf7` | **PARTIAL/UNVERIFIED**: `packages/oorexx_vision/VERSION` says dev20, but `DEV20_PUBLICATION_STATUS.md` explicitly warns the complete dev20 source was **not** synchronized by that handoff. | Member-by-member diff, apply missing code/tests, rerun ownership regression; do not mistake a version marker for parity. |
| Storage Fabric Gopher sphere `storage_fabric_gopher_sphere_v0.8.zip` (35 files) | `b137dd128ee9bfe16759c5db4cabfa651b773870eb5d69c58b7e67559d4123e3` | **BEHIND/REVIEW**: `spheres/storage_fabric_gopher_sphere_v0.3` on `main`; service-admission notes exist on a review branch. | Reconcile current v0.8 sphere in its owning lineage, lint/resolve with LLM Gopher, then promote after review. |
| Wire Direct Linux `wire_direct_linux_v0.1-dev39.zip` | Not byte-rechecked | **BEHIND to verify**: `packages/wire_direct_linux_v0.1-dev30` is the highest explicitly named package directory on `main`. | Compare dev39 to main/current review sources and enforce Wire UI semantic parity. |
| Job-to-Node `job_node_allocator_v0.6-network6.zip` | Not byte-rechecked | **REVIEW/BRANCH**: network6 integration branch exists; default branch has allocator and network1 plus an integration note, not proof of complete network6 parity. | Reconcile exact code on branch, tests, authority and lease/checkpoint behaviour; review admission. |
| NotNotes Windows client `notnotes_windows_client_v0.1-dev5.zip` | Not byte-rechecked | **MISSING/REVIEW**: existing [Issue #18](../../issues/18) explicitly requests source import and qualification. | First-class client source and test admission; do not mistake published Alchemy/Mini NotNotes for Windows client. |
| ooDialog Linux `oodialog_linux_dev12_native_listener.zip` | Not byte-rechecked | **MISSING likely**: no matching top-level `packages/` entry in observed listing. | Identify source authority, independently inspect delivery and submit if not present under another canonical tree. |
| Generalized Architecture/GA Intentions `oorexx_ga_intentions_v0.1-dev1.zip` | Not byte-rechecked | **MISSING likely**: no named `packages/oorexx_ga_intentions` entry in observed listing; distinct from `oorexx_generalized_compute_intentions` dev5. | Check for alternate source location; preserve intention ownership and avoid overwriting actively developed Coding Intentions. |

**Interpretation:** “behind” means the observed canonical package metadata or naming lags the Library delivery; it is not proof every corresponding code file is absent. Exact file/member comparisons and receipt inspection decide the final delta.

## GitHub work already present — avoid duplicate publishing

The following workstreams have a source, sphere or explicit candidate footprint on `main` (not necessarily fully accepted): NotNotes/Mini NotNotes/Help Desk source closure, Dynamic Story dev2 and sphere, Architecture Intentions dev10 and sphere, LLM Coding Workbench dev14 and sphere, Generalized Compute Intentions dev5, Virtual USB (generic package version dev9) and sphere, Speech dev11, D-Bus qualification and sphere, RPC portfolio and RPC sphere, Source Editor dev5 and sphere, SIP/RTP and SIP sphere, Font Manager/PDF, Social Media dev6 and sphere, Wire UI runtime sphere v0.2 and renderer conformance, Wire UI Swing dev11, Web/website publisher, MVS Services PRE22, Virtual UPS v0.2, Memory Fabric XTP candidate2, Cloud Economics dev8, Service Video Playout dev3, XTP dev25, Operational Planner dev5, Prolog dev19, Plan42 bridge dev4, ED209 RTO2 candidate2, Librarian dev8, and Storage Fabric dev23.

Specific cautions:
- `packages/oorexx_connect_selector_v0.1-dev6` is patch-only, **not** the full ConnectSelector source.
- `packages/single_time_change_publication_v0.9` is an additive slice, **not** complete Single Time Service.
- `packages/oorexx_vision/VERSION` says dev20; `DEV20_PUBLICATION_STATUS.md` disclaims full sync.
- `spheres/rust_alchemy_bridge_sphere_v0.1` records dev30; no runtime package is thereby committed.
- NotNotes source closure received direct main updates on 24 October, but [Issue #42](../../issues/42) has not yet been reconciled against clean-checkout qualification and should not be silently closed.

## Source branches/submissions to reconcile with receiver state

Visible `autobuild-submit/` refs include: Scotty Computer dev9, Queue Fabric/XTP sphere, XTP dev25, Storage Fabric dev23, Memory Fabric candidate2, Plan42 bridge, Social Media dev6, Service Video Playout dev3, Prolog dev19, Cloud Economics dev8, ED209 20-MI candidate2, RasenFalcon delivery and sphere, and multiple Wire UI source/sphere submissions. Other code/sphere review refs include Pharo dev16, Storage Fabric service-admission sphere, Perception portable compute, LDAP sphere and Job-to-Node network6. This proves Git branch presence only, **not** receiver PASS/FAIL, acceptance or clean main merge.

Before resubmitting, compare the exact branch tree and full source SHA with Library; do not create duplicate immutable inbox IDs for already transmitted bytes. For still-missing packages use [GIT_SUBMISSION.md](../../GIT_SUBMISSION.md): `tools/alchemy_submit.py`, complete root `integration.json`, two commits with `ready.json` last, and a single push from an execution-capable checkout. Receiver acceptance and promotion belong to its own process. Never merge `autobuild-submit/` branches directly into `main`, fabricate receipts, or treat documentation as executable code.

## Priority closure queue

1. **Recover complete sources:** Single Time Service v0.9; ConnectSelector dev6; Instrumentation Mesh dev8; Rust native dev30.
2. **Resolve exact new heads:** Terminal candidate12; Ruby dev19; Odoo dev11; LDAP dev19; Native DB v0.3.4; Vision dev20; Wire Direct Linux dev39.
3. **Reconcile knowledge/clients:** Storage Fabric sphere v0.8; Job-to-Node network6; NotNotes Windows dev5; ooDialog Linux dev12; GA Intentions dev1.
4. **Close transport-to-acceptance gap:** inventory October `ready.json` objects and receiver receipts/results, qualify missing items, merge/promote only after formal acceptance, and update catalogue/version evidence.

## Important capability limit in this reconciliation

The available project checkout environment here had **no network DNS access to github.com**, so it could not run the canonical `alchemy_submit.py` sender and push the complete ZIP-derived source trees. Connected GitHub APIs can commit this audit, but do not expose the locally materialized ZIP members directly for a safe whole-package submission. Consequently this ledger is **not a claim that the listed missing packages were imported**. Its function is to prevent “delivery exists in Library” from being incorrectly recorded as “complete source admitted and accepted on GitHub.”

Owners should mark each row closed only after exact source-tree comparison, two-commit submission if needed, receiver receipt and tests, and authoritative promotion evidence.
