# Governed cross-capability relationships — dev7

A cross-domain relation is a *proposal for interaction*, not a shared data store, a permission grant, a truth migration or a live message.

## Authority sequence

1. Declare independent capability requirements (`REQUIRED`, `NOT_REQUIRED` or `UNDECIDED`) with named business authority.
2. Place every required capability at its real domain owner. NotNotes owns document semantics, Relationship Case coordinates cases, CRM owns interaction truth, and legal counsel remains the legal decision authority even if Institutional Policy publishes their rules.
3. Declare a relation with its business interaction kind: `OBSERVATION`, `REFERENCE`, `WORK_REQUEST`, `REVIEW_REQUEST`, `PUBLICATION`, or `CONTROL_CHECK`.
4. Provide a typed source-issued reference and visibility rule. Copying a payload is a separate contract; record authority never transfers automatically.
5. Describe access/classification, purpose, retention boundary and error handling. A declared control is **not** a compliance certificate.
6. Optionally bind an existing ArchitectureInterconnect edge. The engine checks that requested interaction pattern can be represented by that link, and the existing link/ConnectSelector authority checks its transport choices. Nothing is dispatched by the architect.
7. Export unresolved questions, immutable evidence references and a build request for SSC/Deployment; do not assign runtime dependencies merely because two business capabilities are related.

## Example

```rexx
r = project~capabilityRelationships
r~relate('legal-review','case_management','legal','REVIEW_REQUEST', -
  'case-id/revision','counsel','Request review, not legal advice', -
  'case://legal-workflow')
r~bind('legal-review','legal-request-link','architect','design://review-transport')
r~govern('legal-review','legal team','PRIVILEGED','counsel review', -
  'legal hold supersedes disposal','escalate ambiguous delivery', -
  'records officer','control://legal')
r~reference('legal-review','case authority','case-id/revision', -
  'counsel-only reference projection','case owner','api://case')
```

The relation references a **separately declared** `legal-request-link` whose `REQUEST_REPLY` or `COMMAND` semantics match review requests; a one-way `EVENT` is not accepted as evidence of such a request. Durable Queue Fabric enqueue means accepted work only, not a legal conclusion. JMS remains a qualified external bridge and does not become a native ConnectSelector choice.

## Export and scenario qualification

`capability-relationships.json` records source/target capability, current owner and record authority, typed reference, control, edge mapping and proposal status. Scenario comparison includes `capabilityRelationshipMatrix`, exposing changed owners between local and outsourced variants. Scenario clones preserve the project of record.

An unknown/excluded capability or unknown edge is reported; an intentionally undecided capability produces an open question, never an auto-selected component. Live identity enforcement, legal effect, legal hold, disclosure, record byte immutability, live delivery and retention remain owned by their proper authorities.
