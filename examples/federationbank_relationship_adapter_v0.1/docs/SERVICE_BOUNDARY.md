# Service boundary for the next cut

The module is intentionally transport-free. A service wrapper should add:

- durable idempotent action submission;
- Queue Fabric ingress/egress;
- a bank submission port routing commands only to Account/Payments queues, never Ledger;
- durable correlation of case/decision/request/bank command/result;
- result references emitted back toward Relationship Case and CRM;
- Runtime Registry lifecycle;
- outbox retry rather than coupling bank commit to CRM/case availability.

Suggested commands: `FBREL.ACTION.SUBMIT`, `FBREL.ACTION.RESULT.RECORD`, `FBREL.ACTION.GET`.
