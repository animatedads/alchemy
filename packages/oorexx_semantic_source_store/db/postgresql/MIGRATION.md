# NoSQLServer -> PostgreSQL migration gate

The backing change must preserve semantic identity. It is not a re-import that creates new IDs.

Before cutover record, per table:

- row count;
- primary-key set/count;
- semantic revision/source hashes where present;
- deployment manifest hashes;
- archive/member provenance hashes;
- authentication/audit records required by retention policy.

Copy rows transactionally into the PostgreSQL schema, then repeat the measurements. Do not switch the SSC authority until the source and destination agree.

Minimum cutover probes:

1. repository metadata/schema version reads correctly;
2. `CODE.CATALOG` returns the same module/object inventory;
3. exact object/revision lookup matches by ID and SHA-256;
4. `CODE.CLASS.INSPECT` returns the same condensed class graph;
5. `CODE.SEARCH` returns semantic-name and body-search results without filesystem traversal;
6. definition/find-uses/callers/callees edges agree;
7. sealed deployment dependency closure agrees;
8. bearer session lookup remains indexed and fail-closed;
9. an ordinary authorised action succeeds;
10. an unauthorised and a privileged-without-step-up action are denied.

After cutover, retain the old backing read-only until the PostgreSQL deployment has passed the qualification window.
