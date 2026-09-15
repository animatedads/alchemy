# Result boundary

A bank result is recorded exactly as an outcome of the submitted bank command. The adapter service does not reinterpret `CORPORATE_POLICY_DENIED`, legal denial, security denial or Ledger failure into success. Case/CRM consumers receive a correlated result event and may coordinate follow-up work.

The current result ingestion command is explicit. A later result-router service may consume FederationBank result queues and call `FBREL.ACTION.RESULT.RECORD`; this avoids making this module a competing general channel router.
