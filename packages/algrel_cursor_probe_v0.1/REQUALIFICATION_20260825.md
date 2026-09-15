# Current-stack requalification gate — 25 Aug 2026

This probe deliberately does not own or predict HardWorld, NoSQLServer, or msqlshim release identities.
Its job is to prove the narrow evidence/materialisation/cursor seam against whichever externally supplied
stack has been declared authoritative.

## Target stack from the current certification ledger

- Structured Relation: `v0.9-compat` (owned here)
- Algorithm Relation cursor probe: `v0.1 current` (owned here)
- HardWorld / Virtual RYTA: `v0.31-work` (external owner)
- NoSQLServer: `v0.79` (external owner)
- msqlshim: `v0.21` (external owner)
- ooRexx: `5.3.0 r13196`

The executable `v0.31-work`, `v0.79`, and `v0.21` archives were not mounted in the working runtime for
this requalification update. Their release identities are therefore targets, not locally executed claims.
Do not certify that stack from hashes or chat metadata alone.

## Foreign integration-version handling

`structured_client.py` no longer hard-codes HardWorld's external-engine identity. It always requires a
non-empty `NOSQL-ALGREL-EXTERNAL-*` identity reported by the running server. For a release certification,
pass the externally declared exact identity as argument 9 to `run_structured_current.sh` (or via
`EXPECTED_EXTERNAL_INTEGRATION`). The client then requires an exact match.

This prevents an unrelated HardWorld integration-version bump from being misreported as a Structured
Relation semantic defect while still allowing a certification run to be hash/version locked.

## Required release run

When the three target archives are mounted, run the existing current-stack acceptance unchanged except
for the external package roots and the exact expected HardWorld integration identity. Required invariants:

1. native EDIFACT source objects remain reachable through Structured Relation evidence;
2. PREPARE/catalog causes zero Algorithm Relation provider executions;
3. first cursor EXECUTE materialises exactly once;
4. FETCH batches reuse the frozen materialisation;
5. the three G07 NSST facts retain three distinct native source paths;
6. scalar consumer visibility does not replace the server-side rich evidence objects;
7. any SQL/query/federation, HardWorld materialisation, or wire-protocol failure is routed to its owning package.
