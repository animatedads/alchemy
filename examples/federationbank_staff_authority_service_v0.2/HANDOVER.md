# Handover — FederationBank Staff Authority Service v0.2

Accepted continuation state: 9/9 executable service tests green and all package `.cls` files compile under ooRexx 5.3.0 r13196.

The service preserves CUSTOMER / INSTITUTIONAL scope through action, decision, authority envelope, durable authority record, event payload and restart. State format is `/2`; legacy `/1` state and action/decision/envelope graph types remain registered for recovery.

It still has no Ledger ingress and does not execute Core Banking commands.
