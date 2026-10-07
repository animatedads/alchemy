# Testing

The source was syntax/runtime-loaded with the user-supplied ooRexx 5.3.0 r13196
Ubuntu package. A lightweight NoSQLServer compatibility stub is used in this sandbox
because the live current NoSQLServer package is not present here.

This validates ooRexx parsing/package loading and the bootstrap call surface. It is not
a substitute for a live persistence qualification against the portfolio NoSQLServer
engine.

`SemanticSourcePackageService` additionally needs a fixture containing semantic
objects, accepted revisions, relations, and projections for live dependency-closure
qualification.

## Bulk importer qualification

The importer should be qualified with a fake MCP client and real small ZIP fixtures covering:

- recursive discovery and deterministic ordering;
- `.cls`, `.rex`, `.py` inclusion and other-member exclusion;
- duplicate archive filename with distinct SHA-256;
- same member path in different archives;
- resume returning `ALREADY_IMPORTED`;
- one bad member without abandoning later members;
- archive close/fail reporting;
- no direct database writes from the importer.

## v0.1-dev4 Code Examiner qualification

`test/code_examiner_test.rex` exercises the human semantic action path using a fake source authority: opening exact code plus design/findings, creating a finding, requesting a package build, requesting a test, and accepting a work entry.

`test/compile_examiner.rex` confirms the Wire application model loads under ooRexx without needing browser code.

## Authenticator qualification

Required production integration cases:

- valid active Ed25519 key + permitted action -> PASS;
- modified signature -> DENY;
- wrong key -> DENY;
- unknown/inactive/revoked key -> DENY;
- expired challenge -> DENY;
- second use of consumed challenge -> DENY;
- wrong audience -> DENY;
- authenticated principal without requested permission -> DENY;
- caller-supplied principal/permission claims are ignored;
- private key material never enters SSC storage/audit.

The included Python test verifies key generation/signature canonicalization with the real
`cryptography` Ed25519 implementation. The ooRexx class is syntax-qualified separately; a
full integration run requires the current Security Effect, Access Permissions and
NoSQLServer packages.

## dev7 module/deployment qualification

Required resolver cases:

- module minimum only -> newest qualified deployment at or above minimum;
- module + file minimum -> higher deployment sequence wins;
- module + file + method minimum -> highest applicable sequence wins;
- exact satisfying minimum -> exact deployment;
- exact below minimum -> `REQUIREMENT_CONFLICT`;
- two different applicable exact deployments -> `REQUIREMENT_CONFLICT`;
- sealed deployment package -> exact recorded revisions/resources/dependency deployments, never newer compatible deployments;
- any mutation attempt after deployment is `QUALIFIED` -> fail closed.

## dev8 branch qualification

`test/branch_service_test.rex` proves:

- hard conflict creates a `CONFLICT` branch;
- both competing method editions are retained;
- subsequent module lookup reports an open conflict branch;
- intentional `ACCEPT_NON_CONFLICTING` branches adopt non-conflicting upstream changes;
- independently changed elements reject upstream as conflicts;
- method protection rejects matching upstream;
- class protection inherits to methods in that class.


### dev10 language/source-unit qualification

`test/language_service_test.rex` qualifies the common language layer and verifies ooRexx, Java, C++ and Rust profiles. It specifically proves that `.rex` and `.cls` share the same ooRexx package-source semantics, both may carry a runnable executable section, ooRexx `::OPTIONS`, `::RESOURCE`, constants and attribute GET/SET are first-class semantic kinds, and semantic/projection ownership can differ for C++/Rust.

## dev11 semantic graph qualification

`test/graph_service_test.rex` proves persistent semantic reference creation, runtime/test observation attachment, go-to-definition resolution, find-uses and caller/callee traversal. Resolution state remains explicit and does not promote `POSSIBLE`, `DYNAMIC` or `UNRESOLVED` references to certainty without evidence. `test/code_examiner_test.rex` also exercises the new navigation actions through the human authority seam.

### dev11 runtime ooRexx introspection qualification

`test/rexx_introspector_test.rex` defines a parent/child class pair whose `INIT` methods deliberately fail if an application instance is created. The test inspects only the loaded class objects and proves direct-parent discovery, inherited instance/class methods, child overrides, and shadowed parent definitions. `graph_service_test.rex` also exercises retrieval of persisted runtime class surfaces and overrides.

Package activation is not claimed to be side-effect-free: ooRexx package prolog code can run while loading. Production introspection of untrusted source must therefore happen in an isolated worker/security boundary.

## dev12 case/runtime qualification

- `language_service_test.rex` proves exact source/runtime/lookup spelling separation and Python language admission.
- `python_case_introspection_test.py` proves `speak`, `Speak` and `SPEAK` remain distinct and that override resolution is case-correct.
- `rexx_introspector_test.rex` remains green with runtime spelling/lookup metadata added to the persisted surface model.

## dev13 Examiner authority/UI completeness qualification

The Code Examiner is now qualified against two maintainability invariants:

- `test/examiner_no_manual_inventory_test.py` rejects hard-coded module/source-file options in browser assets and rejects editable browser transport configuration; the browser must bootstrap from the server service descriptor and catalog.
- `test/examiner_feature_contract_test.py` requires every agreed Examiner action and panel to be present in the Wire design, including revision compare, method requirements/notes, resource upload, module/deployment operations, branch/protection/conflict operations, semantic graph navigation, and runtime class surfaces.
- `CODE.OPEN` validates that server authority returns a complete semantic context bundle. Missing revision history, requirements, notes, resources, branch/deployment state, references, runtime surfaces, test evidence, work entries, exports or dependencies fails closed rather than silently degrading the UI.


## dev14 rendered Examiner surface

```bash
python3 test/examiner_rendered_ui_test.py
python3 test/examiner_no_manual_inventory_test.py
python3 test/examiner_feature_contract_test.py
node --check web/bootstrap.mjs
```

These checks distinguish a visible Examiner from a design-only contract.  The rendered UI test requires the agreed semantic controls/slots to be present in `web/index.html` and rejects hand-maintained source inventory.

- `code_examiner_test.rex` verifies `CLASS_INSPECTION` is the default view and `CODE.CLASS.INSPECT` returns class tree/time cursor, method origin, exposed state and return-class metadata without requiring source bodies.

### dev18 Examiner deployment checks

```bash
python3 test/examiner_deployment_contract_test.py
python3 test/examiner_live_shell_test.py
python3 test/examiner_rendered_ui_test.py
python3 test/examiner_security_contract_test.py
python3 test/examiner_feature_contract_test.py
python3 test/examiner_no_manual_inventory_test.py
bash -n deploy/stage_code_examiner.sh deploy/generate_service_descriptor.sh deploy/smoke_code_examiner.sh
```

The deployed-route smoke additionally requires a real HTTPS/WSS deployment and the exact Alchemy Wire UI JS package. It proves served assets and the secure descriptor contract. It does not by itself prove the authenticated Wire/Queue Fabric action round-trip.

## PostgreSQL backing contract

```bash
python3 test/postgresql_backing_contract_test.py
```

This checks that schema v13 accepts an injected database executor, that the PostgreSQL schema contains the same 47 semantic tables as the portable bootstrap, that hot-path/full-text/security indexes are present, and that SSC service classes do not instantiate private NoSQLServer engines behind the store boundary.

## MySQL / MariaDB backing contract

```bash
python3 test/mysql_backing_contract_test.py
```

This proves that the MySQL-family schema contains exactly the same 47 semantic tables as the PostgreSQL projection, uses MySQL-valid sized text types/InnoDB/utf8mb4, retains the hot-path/security indexes, and provides a FULLTEXT source index plus the optional MySQL-8 ngram profile. It also repeats the backend-neutrality guard that prevents SSC service classes from creating private NoSQLServer engines.

The package does not claim live MySQL/PostgreSQL performance qualification until both executors are pointed at the same imported corpus and benchmarked on the same workload.

## Bulk package materialisation

`test/bulk_package_materialisation_contract_test.py` guards the high-volume package path. It requires set-oriented revision/relation/projection retrieval and the provider-owned `querySet()->asArray` fast path when available. A 1,400-file package must not regress to one revision/projection SQL round-trip per file.

The reference PostgreSQL provider is `oorexx_native_database_backends_v0.2_bulk_results.zip`; its isolated qualification reports 1,400 x 12 fields materialised in about 0.52 s and one completed-Array JSON serialization in about 1.14 s. Those figures are provider qualification evidence, not a live SSC end-to-end timing claim.

## dev25 additions

With ooRexx 5.3.0 r13196 and Intention Service v0.1-dev11 on `REXX_PATH`:

```sh
rexx test/oorexx_structural_adapter_test.rex
rexx test/oorexx_structural_tree_test.rex
rexx test/bulk_importer_test.rex
rexx test/intention_service_test.rex
python3 test/structural_import_contract_test.py
python3 test/examiner_intention_contract_test.py
python3 test/examiner_rendered_ui_test.py
```

The structural tree test must reconstruct every package `.cls` byte-for-byte.
The intention test proves all 28 Examiner actions are dynamically advertised
and that a changed capability snapshot replaces stale discovery surfaces.
