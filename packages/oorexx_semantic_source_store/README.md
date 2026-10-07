# ooRexx Semantic Source Store v0.1-dev14

NoSQLServer-backed persistence and package-resolution foundation for Semantic Source
Control.

The semantic source object and its immutable revisions are authoritative. Conventional
files and ZIP archives are projections. MCP is the intended mutation authority.



## Added in dev14

The browser package now contains the actual visible Code Examiner workspace rather than only a connection card.  The checked-in shell renders the agreed semantic review regions and controls immediately, while catalogue/source/review state remains server-authoritative and is never enumerated in browser source.

The rendered workspace includes semantic navigation, exact revision/source view, revision comparison, method requirements and notes, resource actions, findings, runtime class surface, semantic graph navigation, build/test evidence, module/deployment controls, branch classification/protection/conflict/build controls, and explicit work accept/refuse controls.

`test/examiner_rendered_ui_test.py` is a browser-surface acceptance guard: it fails if an agreed action or semantic slot disappears, or if somebody reintroduces hand-maintained source-file `<option>` inventory.

## Added in dev13

- Code Examiner navigation is entirely server-authoritative: no HTML/JavaScript source-file inventory.
- Browser transport configuration comes from a same-origin service descriptor; no normal deployment requires editing browser source.
- `CODE.OPEN` enforces a complete semantic-context contract covering revision history, requirements, notes, resources, branches, deployments, references, runtime surfaces, test evidence, work entries, exports and dependencies.
- The Wire Examiner design now exposes every agreed review operation: revision comparison, method requirements/notes, resource upload, module/deployment build operations, branch classification/protection/conflict handling, semantic graph navigation and runtime class surface/override inspection.
- Dedicated regression tests prevent manual inventory/configuration and feature regression.

## Added in dev2

- Attached, revisioned design documents for semantic source elements.
- First-class work tickets and ticket items.
- Stable structured work rules (`MUST`, `MUST_NOT`, `PRESERVE`, `FAILURE`,
  `ACCEPTANCE`, `EVIDENCE`, etc.).
- Multi-element work entries and review records.
- Package-request provenance tables.
- `SemanticSourcePackageService~getPackage`, which builds one or more requested
  classes/semantic objects plus their complete dependency closure.
- Dependency resolution defaults to the latest **accepted** revision unless an exact
  revision pin is supplied.
- MCP contract for `source.get_package` in `MCP_COMMANDS.md`.

## Database

`SemanticSourceStore~bootstrap` uses the existing portfolio database stack:

```rexx
engine = .FederatedDatabaseEngine~new(databaseRoot)
sql = .NoSQLServerSQL~new(engine)
```

It does not introduce SQLite or another persistence engine.

## Package review flow

```text
ChatGPT -> source.get_package(root classes, optional pins)
        -> resolve exact accepted dependency closure
        -> materialise conventional files
        -> return files/ZIP + exact revision manifest via MCP
        -> ChatGPT reviews/runs tests
```

The returned manifest makes the review reproducible even if newer revisions are
accepted later.

## Bulk ZIP import for Codex

`src/SemanticSourceBulkImporter.cls` systematically trawls a directory tree of ZIP archives.
It imports ooRexx `.cls`/`.rex` and Python `.py` members through the MCP source-import
client contract. It never bypasses MCP to write the database.

Each archive and member is content-addressed with SHA-256. Original ZIP filename, ZIP hash,
member path and member hash are retained so same-named/colliding archives remain distinct.
Imports are resumable and idempotent at the MCP layer.

## v0.1-dev4 — Human Wire Code Examiner

The package now includes `SemanticSourceCodeExaminer.cls`, a server-side semantic application model intended for Wire UI.

The examiner gives a human one review surface for:

- semantic source search and exact revision inspection;
- attached design-document inspection beside code;
- creation/resolution of durable code findings;
- dependency-complete package/build requests;
- qualification/test requests;
- work-entry accept/refuse decisions with evidence.

The browser remains deliberately non-authoritative. It renders server-authored projections and sends semantic actions. Every mutation goes through an injected source/MCP authority adapter rather than directly to NoSQLServer.

Schema v4 adds `ssc_code_finding` and `ssc_test_request`.

## v0.1-dev5 — Human Wire UI browser surface

Adds the actual browser access point under `web/` and a Wire UI design source under
`wire/`. The UI is for the human reviewer: three-pane navigation/code/context layout,
revision pinning, findings, build/test and accept/refuse controls. The browser contains
no source authority and no fallback review data.

## Security dogfood authenticator

`src/SemanticSourceAuthenticator.cls` adds the SSC challenge lifecycle while delegating
key resolution, signature verification, revocation and authorization to the existing
Security Effect/Bouncer + Access Permissions stack.  SSC persists only challenge/session
and audit evidence.  `tools/ssc_authenticator.py` is the local Ed25519 authenticator; its
private key stays local and only the public identity and one-time signed responses leave the
trusted machine.

## v0.1-dev7: modules and qualified deployments

Schema v7 introduces the version model used by Semantic Source Control:

- **Module** is the durable logical software identity, independent of version labels.
- **Deployment** is an immutable qualified fixed point of a module: a point at which the exact code/resource/dependency closure is asserted to work.
- Module requirements may be attached at module, file, or method scope.
- Minimum requirements accumulate and the highest fixed point wins.
- Exact requirements are pins; conflicting exact pins or a pin below the effective minimum fail closed.
- Deployment ordering uses the monotonic integer `deployment_sequence`, not lexical comparison of labels such as `0.10`, `dev46`, or `safety30-candidate10`.
- Development resolution may float to the newest qualified deployment satisfying the effective requirement.
- Sealed deployment builds use the exact dependency deployment ids recorded in `ssc_deployment_dependency`.

This makes a deployment stronger than a Git tag: it freezes semantic revisions, non-code resources, exports, qualification evidence, and the dependency closure that was actually qualified together.

## v0.1-dev8 — semantic branches

A hard conflict now creates a sparse semantic branch automatically instead of producing a line-oriented merge conflict. Branches begin as `CONFLICT` and must be explicitly retained as conflict or confirmed `INTENTIONAL`.

Intentional branches have an upstream policy (`ACCEPT_NON_CONFLICTING` or `REJECT_NON_CONFLICTING`). Protections may be placed at module, file, class, attribute or method scope; matching upstream changes are rejected automatically. Branches store only overrides/protections/events, not cloned source trees.


## Language adapters and source units (dev10)

The semantic store no longer assumes that source identity is a file. Languages are admitted through rebuildable adapters. The common semantic model covers module/package or namespace scope, types, constants, attributes/properties, methods/functions, implementations, resources, dependencies and exports. Semantic ownership is distinct from projection ownership so C++ out-of-class definitions and Rust `impl` blocks can bind to the same semantic member while remaining in their native textual location.

Qualified adapters in this build:

- **ooRexx** (`.rex`, `.cls`) — both extensions are the same `PACKAGE_SOURCE` species. Either may contain a first-class runnable `EXECUTABLE_SECTION` plus `::OPTIONS`, `::REQUIRES`, `::RESOURCE`, `::ROUTINE`, `::CLASS`, `::CONSTANT`, `::ATTRIBUTE` (`GET`/`SET`) and `::METHOD` objects.
- **Java** (`.java`) — package/import/type/member structure.
- **C++** (`.cpp`, `.cc`, `.cxx`, headers) — namespace/C++20 module, types, members, declarations/definitions, includes/imports and method qualifiers.
- **Rust** (`.rs`) — crate/module, struct/enum/trait, `impl`, associated items, receiver mutability and re-exports.

A language may only be marked rebuildable if every source byte is represented either by an editioned semantic object or by ordered projection/interstitial text.

## v0.1-dev11 — semantic navigation graph

Source references are now persistent semantic graph edges instead of review-time text searches. `ssc_semantic_reference` records dependency, class/type and call/member references together with explicit resolution state: `RESOLVED`, `POSSIBLE`, `DYNAMIC` or `UNRESOLVED`. `ssc_reference_observation` can attach runtime/test evidence without rewriting the static edge.

`SemanticSourceGraphService.cls` provides definition lookup, find-uses, callers, callees and reference explanation. The Code Examiner exposes these as semantic actions, allowing expressions such as ooRexx `::requires`, `.Class` and `instance~method` to become graph navigation targets when the language adapter can resolve them.

### Runtime-effective ooRexx class graph

`SemanticSourceRexxIntrospector.cls` complements the static reference graph with runtime class metadata. It inspects already-loaded `Package`/`Class` objects without constructing application instances. For each class it records immediate parents, the full inherited class chain, locally declared methods, inherited methods, overrides, shadowed parent definitions, and both instance- and class-method surfaces.

The service deliberately does not call `.Package~new`: package activation may execute the package prolog. Untrusted package loading therefore belongs in an isolated worker, after which the resulting Package/Class objects can be inspected. Runtime evidence is stamped with the ooRexx version and exact source/module revision when persisted.

## v0.1-dev12 — case fidelity and Python runtime semantics

Semantic names now preserve exact source spelling, exact runtime spelling and a separate language-specific lookup key.  Normalisation is never used as a projection spelling.  ooRexx uses an uppercase lookup key while retaining source case; Java, C++, Rust and Python use exact case-sensitive lookup keys.

Python is now a rebuildable language profile.  Its runtime introspection adapter derives the effective callable surface from `__mro__` and each class `__dict__`, preserving dispatch order, override chains and exact case.  `classmethod`, `staticmethod` and `property` are distinct semantic member kinds.


## Token-efficient class examination
Class selection now defaults to a condensed semantic inspection: hierarchy, method origin, exposed state and return type/class, with an ISO `since` cursor for incremental refresh. Source bodies and full runtime graphs are explicit drill-downs.

## dev17 live Examiner/security repair

- The browser bootstrap no longer deletes the Examiner workspace when the Wire service or vendor runtime is unavailable. The actual human workspace remains visible while connection failure is reported separately.
- The service descriptor must explicitly declare `authenticationRequired: true`.
- `SemanticSourceAuthenticator` now has opaque bearer-session lifecycle methods; only the token hash is stored.
- `SemanticSourceSecureExaminer` derives principal identity from the verified bearer session and re-authorises every semantic action.
- WORK.ACCEPT, WORK.REFUSE, BRANCH.CLASSIFY, BRANCH.PROTECT and BRANCH.CONFLICT.RESOLVE require a matching action-bound step-up proof.

## dev18 deployment-facing Examiner integration

- Makes condensed class inspection the visible primary class view; exact source/method bodies are explicit drill-down.
- Adds `SemanticSourceWireActionAdapter.cls` so Wire actions consume server-resolved opaque session authority and never browser-selected identity.
- Adds deployment staging, service-descriptor generation, and deployed-route smoke scripts under `deploy/`.
- The production service descriptor now fail-closes unless it declares verified-session principal authority, opaque bearer sessions, and the complete privileged step-up action set.
- The browser shell remains visible when the Wire service is unavailable; connection state is separate from the semantic workspace.
- Static/deployment smoke is deliberately not treated as proof of an authenticated semantic action round-trip.

## dev19 — PostgreSQL high-volume backing

The semantic persistence contract is no longer physically tied to the native NoSQLServer engine. `SemanticSourceStore` accepts an injected shared SQL executor while retaining NoSQLServer as the compatibility default. The intended large-corpus production backing is Database Core's native PostgreSQL/libpq route.

The semantic schema remains one model: `db/postgresql/schema.sql` is generated from the same 47 table declarations used by `SemanticSourceStore~bootstrap`. PostgreSQL-specific performance material is isolated under `db/postgresql/`.

The PostgreSQL profile adds B-tree indexes for semantic identity/revision/graph/deployment/runtime/security paths, built-in GIN full-text indexing over source revisions, and an optional `pg_trgm` profile for arbitrary code substring searches. This is intended to make source discovery over an ~800,000-line corpus an indexed query rather than a materialised-file scan.

## dev20 — PostgreSQL and MySQL/MariaDB peer backings

The high-volume backing is now deliberately database-neutral at the SSC boundary. PostgreSQL and MySQL-family profiles carry the same 47 semantic tables and use the same injected Database Core executor seam. No Examiner, graph, deployment, branch, work, or security service changes its persistence API when the backend changes.

`db/mysql/` adds a MySQL 8 / MariaDB physical projection: InnoDB, `utf8mb4_bin`, sized indexed identifiers, `LONGTEXT` for source/document/evidence bodies, B-tree indexes for the same semantic hot paths, and InnoDB FULLTEXT for source revisions. An optional MySQL-8 ngram FULLTEXT profile is included for fragment-style searching where available.

For this particular source-code workload PostgreSQL remains the stronger default candidate because `pg_trgm` gives a clean indexed path for arbitrary punctuation-heavy substrings. MySQL is nevertheless a first-class candidate and should be chosen or rejected by loading the same corpus and measuring the same semantic/reference/full-text/literal queries rather than by architecture preference.


## dev23 registered database-provider composition

SSC no longer loads or selects NoSQLServer/PostgreSQL/MySQL itself.  The registered `DatabaseBackendSelector` framework is the sole provider-selection boundary.  The service composition root resolves `OOREXX_DATABASE_PROVIDER`, opens the provider, and injects the returned common executor into `SemanticSourceStore`.  Neutral SSC classes contain no `NoSQLServer.cls` requirement and no backend implementation class references.  This is the one-time integration change; subsequent backend changes are configuration only.

## dev24 bulk package path

The package resolver now consumes the PostgreSQL v0.2 bulk-result contract when the selected executor exposes `querySet()`. Package/deployment materialisation is set-oriented: revisions are fetched in batches, dependency relations are fetched per frontier, deployment objects join directly to source revisions, and all projection members for the resolved closure are fetched in one query. This removes the previous 1+N revision and 1+N projection-query pattern that becomes dominant around 1,400 files.

## dev25 — structural ooRexx intake + dynamic Examiner intentions

This cut closes two previously documented gaps.

### ooRexx source is decomposed before import

`SemanticSourceOorexxStructuralAdapter` (`oorexx-structural-v4`) parses `.rex`
and `.cls` package source into an ordered semantic graph containing executable
package code, options, requirements, resources, routines, classes, constants,
attributes and methods.  Class ownership, class-side method identity, declared
class ancestry, `EXPOSE` names and return expressions are retained as compact
semantic evidence.

The original archive member remains carrier/provenance evidence, but
`SemanticSourceBulkImporter` now marks `STRUCTURAL_GRAPH` as semantic authority
and submits `source_unit`, `semantic_objects`, `projection_members` and
`relations`.  The adapter reconstructs the exact original CR/LF/CRLF byte string
before the request is accepted.  Unknown directives are retained as
`PROJECTION_FRAGMENT` objects rather than discarded.

Qualification includes byte-exact reconstruction of every `.cls` in this
package, not only a synthetic fixture.

### Examiner intentions

The Code Examiner now publishes semantic intention definitions for all 28
Examiner actions.  `SemanticSourceIntentionDiscoveryProvider` plugs into
Intention Service v0.1-dev11 dynamic discovery.  Current surfaces are refreshed
for every fresh intention turn; discovery does not become a permanent static
command catalogue.

The browser contains an `Ask Examiner` entry surface using `INTENTION.SUBMIT`.
`SemanticSourceWireActionAdapter` routes this only when an Intention controller
is configured.  Any READY intention that executes is sent back through
`SemanticSourceSecureExaminer`, preserving opaque bearer identity, per-action
Access Permissions, and privileged step-up requirements.
