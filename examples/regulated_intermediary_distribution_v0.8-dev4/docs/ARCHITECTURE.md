# Regulated Intermediary Distribution v0.7 architecture

## Authority planes

```text
trusted authentication attribution (upstream)
          |
          v
Access Control: enter RID protected domain
          |
          v
Permission + Security Effect: exact subject/object/method
          |
          v
Wire UI command authority: exact current workspace/result
          |
          v
RID regulated distribution authority
          |
     +----+----------------------+----------------------+
     |                           |                      |
provider status truth     digital execution truth    work/SLA truth
     |                           |                      |
mortgage / investment /   immutable signed document  durable Queue Fabric
All Japan provider         envelope + evidence         projection/recovery
```

These planes are correlated but not conflated. The production authentication adapter is upstream of this package in v0.7. Authentication attribution does not imply platform entry; platform entry does not imply method Permission; method Permission does not imply regulated product authority; browser state never substitutes for any of them.

## Access Control and Permission

`RIDWireSecurityContext` uses Access Permissions v0.1.

Access Control is the coarse protected-domain decision for `FEDERATION_RID_INTERMEDIARY`. Permission is independently evaluated for every semantic action using an exact object ID/class/method and a bound Security Effect assessment.

Examples:

```text
CASE.OPEN
  object = RID.CASE:<caseId>
  class  = RIDDISTRIBUTIONCASE

WORK.ACK
  object = RID.WORK:<workItemId>
  class  = RIDINTERMEDIARYWORK

SIGNATURE.PREPARE / SIGNATURE.SUBMIT
  object = RID.WORK:<workItemId>
  class  = RIDSIGNINGCEREMONY
```

Policies are default-deny. UI action availability uses policy preview for presentation, but invocation repeats the authoritative Permission decision. A compromised/stale renderer therefore cannot confer authority by making a button visible.

Access and Permission envelopes can carry cryptographic proof; RID exposes proof references in the security context and qualifies a proved exact method/object permission.

## Wire UI command/result authority

`RID.CASES` owns server query, scope, order, semantic selection and result state. Wire UI Server v0.17 introduces a result revision distinct from query state.

A command context is bound to:

```text
queryRevision / scopeRevision / orderRevision / selectionRevision
resultRevision / resultQueryRevision / resultScopeRevision / resultOrderRevision
```

After any authoritative dashboard refresh, RID republishes the current result. If provider/work truth changes while filter/sort/selection stays the same, `resultRevision` still advances. Commands carrying the previous result revision fail closed.

This prevents time-of-check/time-of-use drift between “the selected row was CASE-X” and “CASE-X still has the business state on which this action was prepared.”

## Provider event projection

The signed provider pipeline remains:

`RID.PROVIDER.INGRESS -> RID.CASE.CANONICAL -> RID.CASE.AUDIT -> RID.CASE.STATUS`.

Provider sequence is business-ordering evidence. Queue arrival order is not. Exact redelivery is idempotent; stale lower-sequence events cannot roll the case backwards.

## Work projection and deadlines

`RIDIntermediaryWorkService` keeps durable work authority in `RID.WORK.AUDIT`. Case-status consumption and resulting work/deadline writes are joined by Queue Fabric UOW semantics.

Retained delivery projections remain firm-scoped:

- `RID.WORK.STATUS`, `<firmId>/<workItemId>`;
- `RID.CASE.ATTENTION`, `<firmId>/<caseId>`.

SLA work has persistent TTL shadows in `RID.WORK.SLA`; `EXPIRE` produces durable `OVERDUE`. Restart recovery preserves the original due point rather than resetting the clock.

## Signing plane

`SIGNATURE.PREPARE` is both workspace/result-authorised and exact Permission-gated before a one-time server challenge is created. The challenge freezes case/work/envelope, signer, role, purpose, immutable document identity/version/digest/storage/durable-medium references, authentication/consent evidence and server signing time.

`SIGNATURE.SUBMIT` is again exact Permission-gated against the challenge's work item and only supplies cryptographic response material. The existing digital-signature authority verifies and seals evidence. Challenge replay is rejected.

If signing is not configured, submission fails closed before challenge lookup.

## Staff institutional authority seam

FederationBank Intermediary Staff Authority v0.1 is intentionally a different plane. It composes a positive INSTITUTIONAL Federation Staff Authority envelope with an effective employee-to-RID representative binding and an exact regulated `INTRODUCE`/`ADVISE`/`ARRANGE` request. It explicitly preserves RID's independent regulatory authority.

v0.7 does not turn this into generic UI Permission. It should be called when a Federation employee actually performs one of those regulated business operations.

## All Japan

All Japan Insurance v0.9 is current provider authority. Group ownership remains separate from insurer legal/product authority. RID's adapter maps exact AJI decision/quote/policy identities into the signed provider-event boundary; it does not permit Federation to self-assert insurer outcomes.
