# FederationBank Relationship Adapter v0.1

A deliberately narrow integration module between Relationship Case / CRM work and FederationBank Core Banking.

It answers one question: **given a typed, attributable institutional decision referenced by a Relationship Case, may that decision be translated into a normal FederationBank command, and with what provenance?**

It does not make CRM authoritative, does not interpret press/reputation evidence as banking instructions, does not share mutable database tables, and does not bypass FederationBank's Bouncer, Institutional Policy, Legal Effect or Ledger.

## Core contract

`FederationBankRelationshipDecision` is a sealed reference to an authoritative decision. `FederationBankRelationshipActionRequest` carries transaction/application data but no authority. `FederationBankRelationshipCaseDecisionVerifier` requires a matching sealed Relationship Case `DECISION` element. Institutional Policy then maps authority/action/operation/actor-role to a bank channel and submission permission.

The resulting `FederationBankCommand` carries the original case ID, decision element, authoritative decision reference, policy/legal references, adapter policy release and rule in `details`.

A `NONE` operation is first-class: a valid decision can produce `NO_BANK_ACTION` and no Core Banking command at all.

## Important negative guarantee

A `RelationshipCRMEntry`, `SERVICE_DIRECTIVE`, `EXTERNAL_SIGNAL`, reputation hypothesis or other observation cannot be passed as a bank decision. Even a valid adapter decision only creates a normal bank command; FederationBank remains free to deny that command under its own policy/legal/security rules.
