# Authority Separation

FederationBank Staff Channel enforces four distinct questions.

| Question | Authority | Staff Channel treatment |
|---|---|---|
| Why is this relationship-driven action institutionally justified? | Relationship Case specialist decision + Relationship Adapter policy | exact relationship evidence only where route policy requires it |
| May this employee make/approve this exact action? | FederationBank Staff Authority | exact action envelope, maker/checker, session/branch/desk binding |
| May the bank execute it for this customer/product/legal/security context? | FederationBank Core Banking authorities | ordinary `STAFF` Core command; no bypass |
| Did money actually move? | Ledger | only committed Core/Ledger result counts |

### Structural exclusions

The channel does not accept these as authority-bearing origins:

- reputation/external signals;
- raw CRM records;
- service-treatment directives;
- customer score;
- UI state;
- a case ID without an authoritative decision.

Those may be evidence or context elsewhere, but must undergo the appropriate decision process first.
