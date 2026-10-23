# Current integration baseline checked 2026-10-15

The Library transport grid dated 2026-10-13 records:

- Socket Provider v0.1-dev16
- XTP v0.1-dev19
- Network Transport Intentions v0.1-dev3
- BOSH as an HTTP-carrier logical stream through the shared provider/selector boundary

BOSH dev5 does not hard-code those versions into its runtime API. They are qualification/integration estate facts, not a permanent provider catalogue.

Instrumentation Mesh v0.1-dev8 is the optional observation baseline for this delivery. Its explicit correlation/causation model is adopted without giving BOSH authority to infer relationships.
