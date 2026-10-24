# Alchemy notNotes v0.1-dev14

An executable ooRexx prototype for an offline-first replicated document/application system inspired by the parts of Lotus Notes that mattered: flexible versioned documents, local views, linked objects, disconnected business processing, replication, replayable clustered state, and now provider-neutral semantic intentions.

## Dev14: Intention Service hard-lifting integration

Dev14 proves that language recognition and application execution remain separate concerns. `AlchemyNotNotesIntentionRuntime` binds Intention Service v0.1-dev6 to an ordinary NotNotes node through a `NOTNOTES` language/domain sphere. The sphere may recognise a purpose deterministically, through another NLP provider, or through an LLM-backed provider; all accepted routes resolve to the same canonical intention registrations and therefore the same NotNotes operations.

The new qualification deliberately includes an LLM-shaped provider fixture without an LLM. It proposes the same canonical `REFER_DOCUMENT` intention as the deterministic domain interrogator. Both paths are subject to the same Intention Service write policy and confirmation step, and both dispatch through the same durable NotNotes referral/save/tray implementation.

Dev14 also adds a read-only semantic introspection surface to the existing application model: installed document-definition identities, field definitions, installed view identities, and detached view-column definitions. Intention interrogation therefore consumes authoritative NotNotes design metadata instead of maintaining a duplicate schema.

The integration probe covers:

- `what views are available` -> installed NotNotes view definitions;
- `what fields does sales order have` -> exact installed field metadata;
- `show me sales orders` -> ordinary NotNotes document selection;
- `refer order SO-3001 to Bob Manager` -> confirmation then a real committed referral revision;
- an LLM-shaped provider proposing `REFER_DOCUMENT` for Carol -> the same confirmation, plan builder, event object, save path and referral tray semantics.

No LLM is required for those operations. An LLM may supply recognition evidence, but it does not replace NotNotes hard lifting.

## RTO dependency boundary


The clustered layer is qualified against sealed `alchemy_rto_cluster_v0.1-dev4.zip`, SHA-256 `2d8b680c2b106ccc5e1d4162eb9d09b8906e318639cf56a9228b8e12085dcec9`.

Dev13 depends only on its transport-neutral `AlchemyClusteredApp` contract. Queue Fabric remains below `AlchemyClusterTransport`; NotNotes contains no Queue Fabric-specific application logic. The separately qualified `queue.transport/2` socket carrier and the still-unclaimed socket-level cluster failover remain RTO transport concerns, not NotNotes code dependencies.

## Security boundary

Travelling handler source is compiled into a `Method`, attached to the receiving node's Alchemy Object `RTOSecurityManager`, and executed by `ControllerSandbox` through a temporary active `Directory` entry. Document behaviour travels; host authority does not. The exact external security dependency is locked in `DEPENDENCY_LOCK.json`.

## Existing architecture retained

Documents are real ooRexx `Directory` objects with dynamic fields and active relationships. `FromReference(DocumentType)` and `FromExternalDocument(mediaTypePrefix)` are first-class field sources. External image/video payloads remain separate replicated dependencies. Document, application and view definitions retain exact versions; views remain local projections over the object-store population rather than relational rows.

## Runtime qualification

Qualified on Open Object Rexx 5.3.0 r13196. The full 11-probe contract suite passes. The clustered probe now includes explicit attempts to mutate REPLAY state through `document()`, `documents()`, `referralTray()`, and a resolved relationship; each returned object graph is detached from authoritative replay state. See `QUALIFICATION.md` and `DEPENDENCY_LOCK.json`.

## dev15 — intention-addressable fields and plan feasibility

Dev15 strengthens the NotNotes/Intention Service boundary introduced in dev14.  Field
definitions now expose semantic metadata independently from their ooRexx dynamic member
name: semantic type, cardinality, natural-language aliases, intention read/write/search
flags, computed status, and the owning domain operation for process-controlled state.
These properties survive application-definition snapshot/install and are therefore
available from the exact authoritative application model installed on a node.

The NotNotes intention adapter now consumes Intention Service dev7 plan assessment.
`SET_FIELD` plans are assessed against the real document, its installed definition,
field semantics, and caller authority before dispatch.  An understood request may be
`INFEASIBLE` without becoming `UNKNOWN`: computed fields and process-owned fields are
reported as structured violated preconditions, while missing write authority is
reported separately.  The NotNotes runtime refuses to dispatch an assessment already
known to be infeasible.

This remains provider-neutral.  Deterministic, NLP, learned-path, or LLM recognition
may propose the same canonical intention; NotNotes owns plan construction, feasibility,
authority evidence, mutation, revisioning, referrals, and replication.
