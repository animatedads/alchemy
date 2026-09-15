# Relationship Case v0.2 architecture

## Purpose

Relationship Case is the domain module beneath a CRM/case service.  It models durable work that may outlive a single customer interaction, screen, account, employee or system session.

It deliberately does **not** own authoritative banking state, legal conclusions, security findings, reputation observations or interaction content.  A case coordinates them using typed, provenance-bearing references.

## The core distinction

A case is not a customer status and it is not an account status.

A customer can have several simultaneous cases.  Core Banking remains authoritative for accounts/payments/holds.  Interaction Event remains authoritative for captured communication.  Reputation Feed remains authoritative for external observations/hypotheses.  Legal/Security/Policy modules remain authoritative for their decisions.

Relationship Case owns only:

- case identity/classification;
- policy-controlled work state;
- case ownership/priority/information classification;
- links to authoritative elements;
- immutable case events recording who did what under which exact policy release;
- policy-governed projections/information barriers.

## Policy boundary

All opening, element-attachment, state-transition and projection decisions are resolved from an Institutional Policy release.  The domain engine contains no hard-coded complaint workflow or bank escalation path.

The example FederationBank fixture is therefore explicitly an example **policy payload**.  A different institution can publish different case types, states, roles and evidence requirements without replacing the engine.

Every accepted case transition/attachment event records policy id, version and semantic identity so historical reconstruction does not silently apply today's policy to yesterday's work.

## Case elements

`RelationshipCaseElement` is a typed reference.  Important fields are:

- `elementType`: SUBJECT, INTERACTION, EXTERNAL_SIGNAL, EVIDENCE, ASSESSMENT, DECISION, ACCOUNT_CONTROL, COMMUNICATION, etc.;
- `semanticKind`: domain-specific controlled kind;
- `relationship`: how it relates to the case;
- `sourceSystem` + opaque `sourceRef`: where authoritative detail lives;
- `authorityClass`: whether this is evidence, an observation, professional assessment, authoritative decision, identity reference, etc.;
- `visibilityClass`: PUBLIC/CUSTOMER/INTERNAL/RESTRICTED/SECRET.

This keeps the case rich without flattening source objects into strings or making CRM a second banking ledger.

## External political/reputation example

A public statement about a bank customer can enter a case as:

`EXTERNAL_SIGNAL / POLITICAL_TRADE_PRESSURE / REPUTATION_FEED / OBSERVATION_NOT_DECISION`.

That element does not have Core Banking authority.  The example policy requires separate ASSESSMENT and DECISION elements before a case can move to `ACTION_REQUIRED`, and requires an `ACCOUNT_CONTROL` reference before it can record execution.  The test fixture proves the external signal alone cannot cross that boundary.

## Complaint example

A complaint is a case classification plus policy, not a special screen.  The example policy requires an originating Interaction Event reference before investigation, an assessment before an outcome, and a customer-communication reference before resolution.

## Information barriers

Projection rules are policy.  A teller can receive a restricted-case shell (`RESTRICTED_CASE`) showing that specialist work exists without seeing its classification/evidence.  Compliance can receive the richer projection.  This is semantic authorization, not CSS hiding.

## What v0.1 intentionally does not do

- network/service API;
- SQL/NoSQL persistence;
- Queue Fabric command handling;
- complaint regulatory clocks;
- legal effect evaluation;
- sanctions/security evaluation;
- Core Banking commands;
- free-text note storage;
- Wire UI definitions.

Those belong to later service/adaptor layers.  The absence of UI is deliberate.
