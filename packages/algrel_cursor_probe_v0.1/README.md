# Algorithm Relation prepared-cursor probe v0.1

A narrow integration harness for the supplied:

- Virtual RYTA / HardWorld v0.11
- msqlshim v0.10
- NoSQLServer v0.69

It proves that MySQL classic prepared-cursor traffic can cross the lazy
Algorithm Relation boundary without turning metadata discovery, cursor FETCH,
second-relation access, RESET, or re-EXECUTE into additional algorithm runs.

The harness deliberately does **not** modify msqlshim or NoSQLServer.

## v0.69 compatibility repair exposed by the probe

The supplied v0.11 `NoSQLServerAlgorithmRelationExternalEngine.cls` constructs
`.DatabaseTableMetadata` by global package name in `tableMetadata()`.  When the
adapter and NoSQLServer are loaded as separate packages this fails with:

    Object ".DATABASETABLEMETADATA" does not understand message "NEW"

The probe carries a minimal compatibility copy of that adapter method.  It
obtains `TABLE_METADATA` from the same injected NoSQL class set already used
for `TABLE_DEFINITION`, `DATABASE_ROW`, and `DATABASE_RESULT`.  The test server
supplies `.DatabaseTableMetadata` from the NoSQLServer host package.

This keeps PREPARE metadata observational: the RYTA provider invocation count
remains zero until COM_STMT_EXECUTE demands rows.

## Run

    ./run.sh /path/to/virtual_ryta_hardworld_v0.11 \
             /path/to/msqlshim_v0.10 \
             /path/to/nosqlserver_v0.69/src/NoSQLServer.cls \
             3684

The script creates only a temporary database/work tree.

## Current Structured Relation acceptance path (24 Aug 2026)

`run_structured_current.sh` is the current-stack acceptance seam. It uses the stock current
HardWorld `NoSQLServerAlgorithmRelationExternalEngine.cls`; it does **not** apply the historical
v0.69 compatibility copy in `integration_patch/`. The path is:

```text
OurLadyAir PNRGOV EDIFACT bytes
  -> Structured Relation EdiFactDocumentContext / EdiFactProjectedRow / RichBusinessFact
  -> HardWorld StructuredRelationRichEvidenceAdapter (identity-preserving bridge)
  -> AlgorithmInputRelationSnapshot (RICH_OBJECT)
  -> RichBusinessFactAlgorithmProvider / AlgorithmRelationEngine
  -> stock NoSQL Algorithm Relation external engine
  -> msqlshim prepared cursor / COM_STMT_FETCH
  -> scalar consumer rows
```

The probe selects the three G07 `SSR+NSST ... SEAT NOT PURCHASED` facts. Before materialisation it
asserts that the rich evidence object, source ref, native fact and native projected row retain object
identity. PREPARE/catalog access leaves the provider invocation count at zero. Cursor EXECUTE invokes
the provider once; batched FETCH, a second scalar relation read and provenance checks reuse the same
frozen materialisation. The consumer sees three distinct native EDIFACT source paths while the rich
input still owns the native objects.

Validated companion packages in the mounted supplied bundle: HardWorld v0.28 work, msqlshim v0.20,
NoSQLServer v0.77, Structured Relation v0.9 compatibility work, Alchemy Objects v0.8 and ooRexx
crypto v0.1, on ooRexx 5.3.0 r13196.

The current-stack runner accepts an optional ninth argument, `EXPECTED_EXTERNAL_INTEGRATION`:

```text
./run_structured_current.sh STRUCTURED HARDWORLD MSQLSHIM NOSQL ALCHEMY CRYPTO FIXTURE PORT \
  NOSQL-ALGREL-EXTERNAL-0.13
```

The probe always requires the running HardWorld engine to report a non-empty
`NOSQL-ALGREL-EXTERNAL-*` integration identity. When the ninth argument (or the environment variable
of the same name) is supplied, the identity must match exactly. This is a certification lock, not a
Structured Relation version dependency.

The next declared requalification target is HardWorld v0.31-work + NoSQLServer v0.79 + msqlshim
v0.21. See `REQUALIFICATION_20260825.md`; that target is not claimed as executed until its actual
archives are mounted and run.
