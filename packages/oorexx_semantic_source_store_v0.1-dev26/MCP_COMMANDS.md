# Semantic Source Control MCP command contract

## `source.get_package`

Builds a conventional review/test package from one or more semantic source objects.
The command never edits source state.

### Request

```json
{
  "roots": [
    "oorexx://family/Family"
  ],
  "pins": {
    "oorexx://common/Relationship": "rev-00041"
  },
  "project_id": "default",
  "format": "files"
}
```

`roots` may contain one or many class/object IDs.

`pins` is optional. For every unpinned root or dependency, the resolver selects the
object's `accepted_revision_id`. A pin is exact and fail-closed: a missing revision,
or a revision belonging to another object, rejects the request.

### Dependency resolution

1. Resolve every requested root.
2. Use its pinned revision if specified; otherwise use latest accepted.
3. Follow semantic `DEPENDS_ON`, `REQUIRES`, `IMPORTS`, and `USES` relations recorded
   for the resolved revision.
4. Repeat until the dependency closure is complete.
5. Resolve every dependency using the same pin-or-latest-accepted rule.
6. Never silently substitute a candidate/unaccepted revision.
7. Detect missing accepted revisions and fail closed.

### Response

The MCP response contains:

- the materialised files (relative path -> source text), or a ZIP attachment produced
  from those files when `format=zip` is supported by the transport;
- requested roots;
- exact revision manifest for every root and dependency;
- dependency depth;
- whether each revision was `pinned` or `latest-accepted`;
- source SHA-256;
- original archive filename/hash/member provenance when applicable;
- resolution policy.

A ChatGPT session can therefore request a class, receive a complete buildable package,
review it, run qualification, and refer to the exact semantic revisions it tested.

### Examples

Latest accepted `Family` and complete latest accepted dependency closure:

```text
source.get_package roots=["oorexx://family/Family"]
```

Two classes in one package:

```text
source.get_package roots=[
  "oorexx://family/Family",
  "oorexx://family/FamilyMember"
]
```

Historical/pinned dependency while everything else remains latest accepted:

```text
source.get_package roots=["oorexx://family/Family"] \
  pins={"oorexx://common/Relationship":"rev-00041"}
```

## Ticket readiness rule

Coding workers should only receive work tickets in `READY` state. Ticket validation
must prove that every item has a target object, base revision, design record, at least
one actionable MUST rule, acceptance rule, and required evidence rule. References in
rules must resolve before release.

## `source.import_archive_begin`

Creates/resumes one authoritative ZIP import batch. The request MUST include the original
archive filename and SHA-256. Same filename with a different hash is a different source.

Required fields:

```json
{
  "source_kind": "zip",
  "archive_filename": "family_v4.zip",
  "archive_sha256": "...",
  "imported_by": "codex",
  "parser_id": "auto",
  "resume": true
}
```

Returns `import_id`. With `resume=true`, an existing batch for the same archive SHA-256 may
be resumed rather than duplicated.

## `source.import_archive_member`

Imports one source member through the MCP authority boundary. The bulk importer calls this
for every `.cls`, `.rex`, and `.py` member in deterministic archive/member order.

```json
{
  "import_id": "imp-...",
  "archive_filename": "family_v4.zip",
  "archive_sha256": "...",
  "member_path": "src/family.cls",
  "member_sha256": "...",
  "language": "oorexx",
  "source_text": "...",
  "parser_id": "auto",
  "imported_by": "codex",
  "resume": true
}
```

For structurally supported languages the client adapter parses the member **before** the
authority call and sends `source_unit`, `semantic_objects`, `projection_members`, and
`relations` with `semantic_source_authority=STRUCTURAL_GRAPH`.  `source_text` remains the
immutable carrier/provenance evidence for the archive member; it is not the semantic object.
The authority validates that the ordered projection reconstructs the carrier exactly before
persisting independent source-object revisions.  ooRexx uses `oorexx-structural-v4` and
currently emits executable package code, OPTIONS, REQUIRES, RESOURCE, ROUTINE, CLASS,
CONSTANT, ATTRIBUTE/accessor and METHOD objects. Unknown directives are retained as
lossless projection fragments.

The server attaches archive filename, archive SHA-256 and member path to every imported
revision. Idempotency is based on archive SHA-256 + member path + member SHA-256 + semantic
identity. A repeated member may return `ALREADY_IMPORTED`/`SKIPPED`; it must not create
duplicate semantic revisions.

## `source.import_archive_complete` / `source.import_archive_fail`

Closes the import batch with counts/evidence. Failure does not erase successful member
records; the batch remains resumable.

## Codex bulk importer

`SemanticSourceBulkImporter.cls` is the client-side trawler. Codex points it at a directory
of ZIP files. It:

1. discovers ZIPs recursively;
2. processes archives in deterministic filename order;
3. computes and submits original ZIP SHA-256;
4. lists archive members;
5. ignores non-source files;
6. structurally decomposes supported source before importing it through the MCP client only;
7. records member SHA-256 and archive/member provenance;
8. continues after individual member failures while recording them;
9. closes each archive as complete or failed;
10. supports resume/idempotent re-runs.

The importer itself never writes any database backend directly.

## Human Wire Code Examiner

`SemanticSourceCodeExaminer.cls` is the server-authoritative application model for a human Code Examiner rendered through Wire UI. The browser presents semantic state and sends only named actions. It does not decide revision identity, acceptance, build contents, test outcome, or finding state.

Wire actions:

- `CODE.SEARCH` — find semantic source objects, tickets or work entries.
- `CODE.OPEN` — open an exact source revision with its attached design document and findings.
- `CODE.FINDING.CREATE` — mark a code error/concern against an exact object and revision, optionally with line range, ticket and work-entry references.
- `CODE.FINDING.RESOLVE` — resolve a finding with an explicit resolution note.
- `CODE.PACKAGE.REQUEST` — invoke the existing dependency-complete `source.get_package` build path.
- `CODE.TEST.REQUEST` — request qualification of a built package through the server-side test/qualification authority.
- `WORK.ACCEPT` — human acceptance of a submitted work entry with findings/evidence.
- `WORK.REFUSE` — human refusal of a submitted work entry with findings/evidence.
- `CODE.REFRESH` — refresh the currently selected semantic element or root view.

The Examiner must be connected to an authority adapter implementing the corresponding MCP/source operations. It must not receive a direct NoSQLServer handle for mutations.

### Finding record

A finding is durable review evidence and must include:

```json
{
  "object_id": "oorexx://family/Family/instance/addChild",
  "revision_id": "rev-17",
  "work_entry_id": "work-7",
  "ticket_id": "WT-1842",
  "category": "CORRECTNESS",
  "severity": "ERROR",
  "line_start": 10,
  "line_end": 12,
  "summary": "duplicate child path",
  "detail": "second append can duplicate the child"
}
```

Findings never silently mutate code. They are evidence for the current or next work cycle.

### Package and test flow

The human can request a build from the selected classes. `CODE.PACKAGE.REQUEST` delegates to `source.get_package`; latest accepted dependencies are resolved once and pinned in the returned package manifest. The human may then request a qualification profile with `CODE.TEST.REQUEST`. The test request records the exact package request ID, so results remain attributable to the code that was tested.

### Work-entry decision

Accept/refuse decisions are explicit authority actions. A Wire client must not infer acceptance from a green test display. `WORK.ACCEPT` and `WORK.REFUSE` both require a work-entry ID, review findings and evidence.

## Signed authenticator / dogfood security flow

Semantic Source Control does not own a separate key/ACL system. Authentication is a
signed challenge layered on the existing Security Effect / Bouncer and Access Permissions
frameworks.

### `auth.challenge`

Request:

```json
{
  "key_id": "CHATGPT-SSC-001",
  "audience": "semantic-source-mcp",
  "action": "source.get_package",
  "resource_id": "oorexx://family/Family"
}
```

The server resolves `key_id` through the security framework, verifies the key is active,
creates a random one-time nonce and short expiry, and returns a
`semantic-source.auth.challenge/1` record.  A challenge may be action/resource bound.

### Local authenticator

The private key never enters chat or MCP.  On the trusted local machine:

```text
python3 tools/ssc_authenticator.py keygen \
  --key-id CHATGPT-SSC-001 \
  --private-key ~/.ssc/chatgpt-ssc-001.pem

python3 tools/ssc_authenticator.py sign \
  --private-key ~/.ssc/chatgpt-ssc-001.pem \
  --challenge challenge.json
```

`keygen` prints the raw Ed25519 public key (base64url) for registration with the existing
security framework. `sign` emits a `semantic-source.auth.response/1` object containing only
challenge ID, key ID and Ed25519 signature.

### `auth.authenticate`

The server:

1. loads the one-time challenge;
2. fails if consumed/expired;
3. re-resolves key state through the security framework (revocation therefore takes effect);
4. verifies the Ed25519 signature through Security Effect/Bouncer;
5. asks Access Permissions whether the authenticated principal may perform the bound action;
6. consumes the challenge even when authorization is denied;
7. returns verified authentication context on success;
8. writes an audit event.

Authentication and authorization are separate decisions. The token carries no caller-chosen
permissions.

### Replay/security requirements

- challenge lifetime SHOULD be 60-120 seconds;
- challenge is single-use;
- audience must match `semantic-source-mcp`;
- sensitive writes SHOULD use action/resource-bound challenges;
- revoked/unknown/inactive keys fail closed;
- caller-provided principal identity is never authoritative;
- private keys are never stored by Semantic Source Control.

## Module and deployment commands (schema v7)

### `module.create`
Create the durable logical module identity. A module is the former ZIP/package identity without a deployment number.

### `module.requirement.create`
Create a module dependency requirement at `MODULE`, `FILE`, or `METHOD` scope.

Fields:
- `requiring_module_id`
- `scope_kind`: `MODULE | FILE | METHOD`
- `scope_id`: module id, module-relative file path, or semantic method object id
- `target_module_id`
- `constraint_kind`: `MINIMUM | EXACT`
- `required_deployment_id`
- `reason`

Resolution rule:
1. gather applicable module + file + method requirements;
2. highest `deployment_sequence` among `MINIMUM` requirements wins;
3. all applicable `EXACT` requirements must identify the same deployment;
4. an `EXACT` deployment below the effective minimum is a hard conflict;
5. development builds choose the highest/latest `QUALIFIED` deployment satisfying the result.

### `deployment.create`
Create a draft deployment fixed point for a module. Add exact semantic object revisions, resources, and resolved dependency deployments before sealing.

### `deployment.seal`
Qualify and seal a deployment. After sealing it is immutable. The deployment manifest records exact source revisions, resource revisions, and dependency deployment ids.

### `source.get_deployment_package`
Reconstruct a sealed deployment and its exact dependency closure. This command never floats to newer dependency deployments.

Development `source.get_package` and deployment `source.get_deployment_package` therefore have intentionally different resolution semantics.

## Branch operations (schema v8)

Hard semantic conflicts do not fail as text-merge errors. The write authority creates a sparse branch automatically.

### `branch.notice`
Returns open branches for a module. Every module/package lookup should include this notice. An unresolved conflict branch must be visible to callers.

### `branch.classify`
Classifies an automatically-created branch as either:

- `CONFLICT` — unresolved accidental divergence; or
- `INTENTIONAL` — deliberate development line.

An intentional branch requires one upstream policy:

- `ACCEPT_NON_CONFLICTING`
- `REJECT_NON_CONFLICTING`

### `branch.protect`
Adds `REJECT_UPSTREAM` protection at one semantic scope:

- `MODULE`
- `FILE`
- `CLASS`
- `ATTRIBUTE`
- `METHOD`

Protection is inherited downward. A protected class therefore protects its methods/attributes; module protection covers the whole module.

### `branch.conflict.resolve`
Resolves one branch conflict to an explicit accepted semantic revision. Competing candidate editions remain historical evidence; neither is silently overwritten.

### `source.get_branch_package`
Builds a conventional source package from an upstream deployment plus sparse branch overrides. It MUST fail closed while an unresolved conflict has multiple candidate revisions for the same semantic element.

### Automatic hard-conflict rule
`source.revise` MUST invoke the branch authority if the submitted parent revision is no longer the accepted parent and the competing semantic revision cannot be trivially accepted as a different element. The response returns the new `branch_id` rather than asking the client to perform a text merge.


## Language/source-unit metadata (dev10)

Source import requests may include `language_adapter_id`, `semantic_granularity` and `source_unit_kind`. Current rebuildable adapters are `oorexx-structural-v2`, `java-structural-v2`, `cpp-structural-v1` and `rust-structural-v1`. For ooRexx, `.rex` and `.cls` are projection extensions only; both map to `PACKAGE_SOURCE` and may contain an editioned `EXECUTABLE_SECTION`. Importers must preserve directive order and all unclassified source text losslessly.

## Semantic graph operations (dev11)

The source authority should expose semantic graph operations corresponding to the Code Examiner actions:

- `source.definition(reference_id)`
- `source.find_uses(object_id)`
- `source.callers(object_id)`
- `source.callees(object_id)`
- `source.reference_explain(reference_id)`

References carry explicit `resolution_state` (`RESOLVED`, `POSSIBLE`, `DYNAMIC`, `UNRESOLVED`) plus exact source revision/span and optional target module/revision. Runtime/test observations are evidence attached to the edge, not a replacement for its static provenance.

### `source.class_surface`
Returns a captured runtime-effective ooRexx class surface for a specific introspection snapshot: direct parents, effective and shadowed instance/class methods, declaration origins, and override relations. The snapshot is evidence from a named ooRexx runtime and exact source revision.

Input: `snapshot_id`.

### `source.class_overrides`
Returns only override edges from a runtime class snapshot, including the child implementation and the nearest overridden ancestor definition.

Input: `snapshot_id`.

Runtime capture is performed by a worker that loads the package under the security/sandbox policy and calls `SemanticSourceRexxIntrospector`; the MCP handler does not instantiate the application class.

## Case-correct semantic identity (dev12)

All source-object and runtime-surface identities expose separate `source_spelling`, `runtime_spelling` and `lookup_key` values.  Clients must display source spelling where available and must not reconstruct source from the lookup key.

Python source (`.py`, `.pyi`) is admitted through the `python-structural-v1` adapter and uses exact case-sensitive identity.

### `CODE.CLASS.INSPECT`
Default token-efficient class inspection.

Input: `class_id`, optional `revision_id`, optional `since` ISO timestamp.

Returns `semantic-source.class-inspection/1` with `class_tree`, `since`, `as_of`, and compact `methods[]`. Each method contains `name`, `from`, `exposes[]`, and `returns { kind, class }`. Method bodies are excluded and fetched separately only when required.
