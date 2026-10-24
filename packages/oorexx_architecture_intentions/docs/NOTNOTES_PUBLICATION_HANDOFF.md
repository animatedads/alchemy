# NotNotes publication boundary — dev10

`ArchitectureNotNotesPublication` turns a frozen promotion handoff into a
non-executable `alchemy.architecture.notnotes-publication-request/0.1` object.
It never calls NotNotes to create/edit/publish a document. It does not invent
API methods, version tokens or write permission.

The external adapter must resolve the exact authoritative Alchemy NotNotes
source/API version and call its actual document/revision method under an
authenticated principal, applying document authorization, institutional
policy, CAS revision, retention and attachments. It must return a separately
verified document identity/revision receipt. **No document was published** by
the dev10 planner. SSC closure evidence, when present, remains a distinct
attached reference and cannot authorize a document mutation.

A recipient may include the architecture selection and all rejected or
deferred alternatives, requirements, ground rules, capability placements and
provenance only as source-grounded data from the frozen handoff. Any missing
policy or authority returns an open question, not a guessed publication.

Source baseline observed in Library: `alchemy_notnotes_v0.1-dev15.zip`, SHA-256
`57a7d1b09234621f20c9de5dda312b4e38140b57cb87c45f7318e59730db4488`.
Newer v0.6.2 Project Alchemy NotNotes *corpus* is documentary and is not
silently substituted for that executable source package.
