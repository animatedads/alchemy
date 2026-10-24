# Business and institutional capability placement — dev6

## Aim

A customer saying “We need CRM, legal, cases, documents and user accounts”
requires an authority map, not a default enterprise deployment. The architecture
planner first determines **business scope**, then **authoritative truth**, then
**where enforcement and communication occur**, and only afterward the
corresponding qualified package/target closure.

| Capability | Candidate Alchemy authority | Explicit boundary / why-not-default |
|---|---|---|
| CRM | Relationship CRM | Relationship truth, not legal or case outcomes |
| Cases | Relationship Case | Case coordination; case service adapter only if qualified and necessary |
| Documents | Alchemy NotNotes | Semantics, graph, editing; byte persistence and legal effect separate |
| Legal | Institutional Policy | Versioned rule/evidence publication; qualified counsel owns legal interpretation |
| Reputation | Brand Interaction Effect / Brand Intervention Governance | Evidence and intervention governance; external reputation remains independent |
| Authentication | Customer/enterprise identity provider (EXTERNAL) | Per-principal, per-interface trust; not `Secret Broker` |
| Authorisation | Institutional Policy and/or external PDP | Entitlements and enforcement after authentication, not inferred from identity |
| Privacy | Institutional Policy/external compliance authority | Source obligations and control verification still required |
| Records | NotNotes + policy, if selected | Retention, evidential hold, byte storage and lawful disposal remain separate |
| Secrets | Secret Broker | Secret lease/rotation; not MFA, login or legal consent |
| Payments | External verified owner until qualified | Ledger, regulated payment, tax and reconciliation not guessed |
| Communications | External channel connector until qualified | Opt-in, attribution, delivery and approval vary per channel |

All names are **candidates** discovered in the portfolio, not exact SSC artifact
locks. The planner's component catalog includes expected capability identities
and observed versions solely as requests; SSC must resolve the authoritative
package, source level and dependency closure. A discovery `UNDECIDED` is never
silently promoted to `REQUIRED`.

## Recommended conversation with the customer

1. What outcomes and actors exist, which records are authoritative, and what
   must interoperate with a legacy application?
2. Which legal, reputational, financial, customer, document and case-management
   capabilities are required, explicitly excluded, or genuinely undecided?
3. For each required capability: who owns authoritative truth and who may make
   the relevant decision? Where is its domain/service boundary?
4. Which actor/principal authenticates at which component link? Which individual
   links have attributable exemptions, and do ground rules permit these?
5. Which interface semantics are needed? DirectCall, JSON-RPC, Queue Fabric
   via ConnectSelector, or explicit JMS bridge in either direction?
6. Which data and physical storage, deployment scenario, operational cost and
   recovery paths satisfy these answers without inflating runtime dependencies?

## API sketch (real ooRexx class)

```rexx
p~capabilities~discover('business architect','Scope the business platform')
p~capabilities~assess('crm','REQUIRED','customer','Customer relationships')
p~capabilities~place('crm','DOMAIN','relationship_crm', -
   'sales owner','customer relationship record','architect', -
   'Existing candidate service','catalog://crm')
p~capabilities~assess('authentication','REQUIRED','security owner','Owner login')
p~capabilities~place('authentication','SECURITY','EXTERNAL', -
   'identity owner','customer IdP','architect', -
   'Do not infer from Secret Broker','contract://identity')
p~capabilities~protect('customer-api','owner','owner-principal', -
   'cat-profile','read','SERVICE','customer IdP', -
   'security architect','Verify token and session on API', -
   'contract://customer-api')
plan = planner~plan(p)
```

An unknown selected owner is rejected, even where a coincidentally named ZIP
might exist. A domain not required creates no package request. A selected
external owner is represented as `businessCapabilityRequirements` with
`status=UNRESOLVED`, separate from ConnectSelector `externalIntegrationRequirements`.

## Governed comparisons

A scenario may change `case_management` from Relationship Case to an external
case vendor while preserving the stated business requirement. Its `businessCapabilityMatrix`
reports the differing owner/layer for each scenario. Ground rules are inherited
and cannot be overwritten by scenario changes. The selected plan remains
non-executable until SSC and Deployment provide authoritative locks and probes.
