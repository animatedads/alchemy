# FederationBank Staff Authority v0.1

Policy-driven business authority for FederationBank employees acting through the `STAFF` channel.

This module answers a deliberately narrow question:

> Given an externally identified employee, an authenticated work session, effective role/delegation/elevation facts, an exact proposed banking action and any independent approvals, is that employee institutionally entitled to request that exact action now?

It does **not** authenticate passwords, own HR/IAM truth, make Relationship Case decisions, decide customer/product limits, determine legal effect, post to the Ledger, or turn a staff workstation into a privileged Core Banking bypass.

## Domain model

The main immutable/effective-dated concepts are:

- `FederationBankStaffPrincipalRef` — reference to authoritative HR/IAM identity and employment evidence.
- `FederationBankStaffSessionContext` — authenticated branch/desk/workstation session context.
- `FederationBankStaffRoleAssignment` — organizational role fact; policy assigns its consequences.
- `FederationBankStaffDelegation` — bounded delegated authority with explicit grant/evidence and expiry.
- `FederationBankStaffElevation` — bounded temporary/break-glass authority, separate from normal delegation.
- `FederationBankStaffContextSnapshot` — sealed principal/session/assignment/delegation/elevation snapshot.
- `FederationBankStaffActionIntent` — the exact action the member of staff proposes to perform.
- `FederationBankStaffApproval` — exact-action-bound independent approval.
- `FederationBankStaffAuthorityRule` / `Policy` — role, operation, branch, maker/checker and elevation policy.
- `FederationBankStaffAuthorityDecision` — policy/evidence-rich result.
- `FederationBankStaffAuthorityEnvelope` — positive, exact-action-bound authority evidence.
- `FederationBankStaffCommandBinder` — proves an ordinary `FederationBankCommand` is the same `STAFF` action that was authorised.

All durable domain objects have deterministic semantic identities and Queue Fabric persistence forms where required.

## Maker/checker and separation of duties

Policy may authorize a maker directly up to a limit and require one or more checker approvals above it. Checker approval is bound to the exact semantic identity of the action and validated against the checker's own active staff context. Policies can require maker and checker to be different people.

A supervisor's role does not make an earlier teller action retrospectively theirs, and an approval for one amount/account/action cannot be replayed for another.

## Delegation and temporary elevation

Delegation and elevation are separate concepts:

- a delegation must be effective-dated, evidence-backed and bounded;
- it cannot enlarge the ceiling set by Institutional Policy;
- a temporary elevation is an explicit policy requirement (for example a cash override) with its own authorizer, evidence, scope and expiry;
- neither object modifies the underlying HR/IAM role assignment.

## Three independent authorities

The module deliberately keeps three questions separate:

1. **Relationship/case authority** — why the bank may be considering an action.
2. **Staff authority** — whether this employee may request/approve the action in this work context.
3. **Core Banking authority** — whether the customer's/product's/legal/security/banking policy permits the resulting banking command.

Passing one gate never implies passing either of the others.

The integration fixture `FederationBankStaffCorePolicyFixtures.cls` therefore contains explicit `STAFF`-channel Core Banking policy as a separate catalog from staff employment authority. It is test infrastructure for that separation, not an attempt to merge the policies.

## Relationship integration

`FederationBankRelationshipStaffAuthorityBridge.cls` can convert an already successful Relationship Adapter translation into an exact `FederationBankStaffActionIntent`. It does not confer staff authority; it merely preserves that the relationship-authorized banking request and the employee action are the same proposed operation.

The full executable chain is:

```text
Relationship Case DECISION
        |
Relationship Adapter
        |
ordinary FederationBankCommand (STAFF)
        |
Staff Action Intent
        |
Staff Authority + approvals
        |
exact command binding
        |
Core Banking STAFF policy / Legal / Security
        |
Ledger (only through Core Banking)
```

There is no Staff Authority -> Ledger path.

## Policy fixtures

The supplied fixture policy is intentionally illustrative. It includes teller and supervisor transfer limits, maker/checker requirements, beneficiary operations, account-opening approval and a sample temporary elevation requirement. Production deployments must publish institution-approved policy rather than treating these sample limits as banking policy.

## Validation

See `VALIDATION.md` and `VALIDATION_TRANSCRIPT.txt`. The qualified cut has eight core module tests plus one full Relationship -> Staff -> Core integration test, and all module `.cls` files compile with `rexxc` on ooRexx 5.3.0 r13196.
