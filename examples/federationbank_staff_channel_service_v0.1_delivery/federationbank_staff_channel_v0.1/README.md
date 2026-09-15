# FederationBank Staff Channel v0.1

Backend orchestration semantics for FederationBank employee-originated banking work.

This package is intentionally **not a staff UI**. It defines what a staff-channel journey means after a staff workstation, branch process, CRM/case flow or other producer has formed a banking instruction. Wire UI can later project these semantics; it is not an authority in this layer.

## Why this component exists

FederationBank now has deliberately separate authorities for:

1. relationship/case decisions — why the bank may consider a relationship-driven action;
2. staff authority — whether an identified employee may request or approve an exact action;
3. Core Banking — whether the bank may actually execute the action for this customer/product/legal/security context;
4. Ledger — committed monetary truth.

The Staff Channel coordinates those authorities without collapsing them.

```text
customer instruction OR Relationship Case decision
                    |
                    v
             Staff Channel policy
          origin / route / evidence shape
                    |
                    v
              Staff Authority
        exact actor + session + action
                    |
             maker/checker if needed
                    |
                    v
            READY_FOR_CORE
        exact bound command snapshot
                    |
                    v
             Core Banking route
          Account or Payments authority
                    |
                    v
                  Ledger
```

## Origin classes

v0.1 distinguishes two policy-visible origins:

- `CUSTOMER_INSTRUCTION` — ordinary staff-assisted customer banking work. It must not carry relationship authority as a hidden substitute for its origin.
- `RELATIONSHIP_DECISION` — an action already translated by the FederationBank Relationship Adapter from an authoritative Relationship Case `DECISION`.

An `EXTERNAL_SIGNAL`, CRM record or reputation observation has no routing rule and cannot become a Core Banking command directly.

## Exact relationship binding

`FederationBankStaffChannelRelationshipEvidence` is created from an already-authoritative Relationship Adapter translation. For a banking action it retains:

- case ID;
- relationship decision ID and semantic identity;
- adapter policy provenance;
- the exact translated banking command semantic identity.

If the banking amount/account/operation/details are changed after translation, Staff Channel rejects the request with `RELATIONSHIP_COMMAND_IDENTITY_MISMATCH` rather than replaying the old relationship authority onto new work.

`NO_BANK_ACTION` is also a first-class coordinated outcome. It produces neither a Staff Action nor a Core Banking submission.

## Staff authority

The channel creates an exact `FederationBankStaffActionIntent` and asks a `FederationBankStaffChannelStaffAuthorityPort` for authority. v0.1 includes an in-process port over FederationBank Staff Authority v0.1. The service package adds the real Staff Authority Service adapter.

An `APPROVAL_REQUIRED` decision becomes durable/resumable work rather than a UI-only state. A later checker approval must still bind the same immutable Staff Action identity.

## Core route separation

Policy selects a route independently of staff authority:

- `ACCOUNT` — account opening and beneficiary maintenance;
- `PAYMENTS` — transfer work;
- `NONE` — explicit no-bank-action outcomes.

The supplied engine port validates the operation/route pair before giving the ordinary `STAFF` command to FederationBank Engine v0.9. Core Banking policy/legal/security checks remain final.

## Work lifecycle

`FederationBankStaffChannelWorkItem` uses states such as:

- `RECEIVED`
- `APPROVAL_REQUIRED`
- `STAFF_AUTHORISED`
- `READY_FOR_CORE`
- `COMPLETED`
- `CORE_REJECTED`
- `REJECTED`
- `NO_BANK_ACTION`

`READY_FOR_CORE` contains the exact staff-authority-bound command snapshot and exists specifically so the service layer can persist it **before** Core submission.

## Optional Relationship Adapter bridge

`integration/FederationBankRelationshipStaffChannelBridge.cls` converts an existing Relationship Adapter translation plus a sealed staff context into a Staff Channel request. The bridge carries relationship authority forward; it does not manufacture Staff Authority.

## Validation

Eight executable domain/integration tests pass under ooRexx 5.3.0 r13196, including:

- direct customer instruction;
- maker/checker resume;
- Relationship Case decision chain;
- altered-command rejection;
- durable `NO_BANK_ACTION` semantics;
- external signal rejection;
- Core Banking final authority;
- Runtime Registry-shaped module boundary.

See `VALIDATION.md` and `VALIDATION_TRANSCRIPT.txt`.
