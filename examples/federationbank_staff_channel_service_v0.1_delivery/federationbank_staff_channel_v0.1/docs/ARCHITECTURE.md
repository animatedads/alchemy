# Architecture

## Coordination, not authority

Staff Channel is a process coordinator between independently authoritative components.

```text
Interaction / CRM / reputation / external evidence
                     |
                     v
              Relationship Case
                     |
          specialist DECISION if needed
                     |
          Relationship Adapter policy
                     |
         exact translated bank command
                     |
                     +-------------------------+
                                               |
ordinary customer instruction ----------------+--> Staff Channel
                                                   |
                                           Staff Authority
                                                   |
                                           maker / checker
                                                   |
                                            bound STAFF command
                                                   |
                                      +------------+------------+
                                      |                         |
                               Account Authority          Payments Authority
                                      |                         |
                                      +------------+------------+
                                                   |
                                                 Ledger
```

A relationship decision is neither staff authority nor Core Banking authority. A Staff Authority envelope is neither customer/product authority nor Ledger truth. The channel keeps all evidence distinct.

## Policy-driven routing

Institutional Policy release `FB-STAFF-CHANNEL` selects a `FederationBankStaffChannelRule` by origin and operation. A rule says:

- whether Relationship Adapter evidence is required;
- which Core authority route is appropriate;
- the exact policy release and rule used.

It does not decide employee limits or product limits.

## Exact command snapshots

FederationBank Engine v0.9's `FederationBankCommand` predates Queue Fabric graph persistence. `FederationBankStaffChannelCommandSnapshot` therefore captures the command without changing Core Banking. It has a deterministic semantic identity and can reconstruct the ordinary command at the Core boundary.

This also provides an exact object against which relationship and staff authority evidence can be bound.

## Failure classes

Institutional outcomes are work states:

- employee authority denied -> `REJECTED`;
- checker required -> `APPROVAL_REQUIRED`;
- Core Banking customer/product/legal/security denial -> `CORE_REJECTED`.

Infrastructure delivery failure is different. A Core port must report transport/infrastructure errors as `CORE_PORT_*` or `CORE_DELIVERY_*`; Staff Channel leaves `READY_FOR_CORE` intact so a durable service can retry safely.
