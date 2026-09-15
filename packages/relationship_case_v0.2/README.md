# Relationship Case v0.2

A general policy-driven case/relationship domain module intended to sit beneath CRM, complaint handling, escalations, specialist review and cross-system staff work.

This is deliberately the **non-website end** of the problem.

## Why it exists

CRM can be a lifetime of work.  FederationBank nevertheless needs a stable place in the architecture for relationship work that spans Core Banking, customer interactions, policy, legal/compliance/security decisions, reputation observations and human tasks.  This package establishes that seam without trying to build an entire CRM suite.

## v0.2 capabilities

- multiple concurrent cases per subject/customer;
- policy-driven case opening and initial state;
- policy-driven typed element attachment;
- policy-driven state transitions with required evidence/assessment/decision element prerequisites;
- append-only case event history with exact Institutional Policy release identity;
- policy-driven information-barrier projections;
- in-memory repository/index for module qualification;
- optional real Interaction Event v0.3 reference bridge;
- optional Reputation Feed hypothesis reference bridge;
- FederationBank example policy fixture including complaint and external-pressure cases;
- Runtime Registry-shaped module entry point;
- neutral durable object-graph persistence contract for case, element and event objects;
- Queue Fabric v0.9-dev4 restore-factory integration without making Queue Fabric a core-domain dependency;
- restart-safe domain event sequencing after durable recovery.

## Authority rule

Relationship Case coordinates authority; it is not itself the authority for banking, legal, security or reputation facts.

An external signal can cause work to be opened.  It cannot itself become an account restriction.  A complaint can refer to ledger/payment evidence without copying or redefining that evidence.  A staff UI can project a case without owning the case policy.

See `ARCHITECTURE.md` and `SERVICE_BOUNDARY.md`.
