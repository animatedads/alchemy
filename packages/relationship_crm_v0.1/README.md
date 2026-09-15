# Relationship CRM v0.1

A general policy-driven relationship-management domain for staff servicing, CRM adapters and case coordination.

This is deliberately **not a website** and deliberately **not Core Banking**.

## Owns

- servicing relationship record and ownership;
- references to interactions/correspondence;
- customer communications and delivery state;
- promises/callbacks;
- relationship tasks and hand-offs;
- complaint recognition as a relationship fact;
- policy-derived service profile/treatment.

## Does not own

- balances, postings, payment commitment, holds or overdrafts;
- account restrictions;
- sanctions/legal/security conclusions;
- source Interaction Event content;
- Relationship Case work state;
- UI definitions.

A complaint can be linked to a Relationship Case.  That does not make the CRM the Case authority.  A service profile can alter staff treatment/workflow but cannot grant banking authority.

All mutation/state-change decisions and all read projections pass through an exact Institutional Policy release.  Accepted domain events retain policy id/version/semantic identity/rule id.

See `ARCHITECTURE.md` and `SERVICE_BOUNDARY.md`.
