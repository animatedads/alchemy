# Adversarial review request — Virtual RYTA / HardWorld v0.13

Attack the NoSQLServer v0.70 provider-neutral metadata boundary. Do not redesign HardWorld semantics unless this boundary actually violates them.

## Claims to attack

1. A v0.70 Algorithm Relation binding requires only `TABLE_DEFINITION`, `DATABASE_ROW`, and `DATABASE_RESULT`.
2. NoSQLServer federation can construct complete ordinary relation metadata from `relation~definition` without invoking provider `tableMetadata()`.
3. Database Core relation discovery/metadata/describe does not execute the algorithm.
4. MySQL `PREPARE`, `SHOW` and column metadata do not execute the algorithm.
5. The optional legacy metadata callback is never called by stock v0.70 federation.
6. First data demand executes at most once per logical materialisation.
7. Multiple relations from one provider share that materialisation.
8. `COM_STMT_FETCH` is transport over already-materialised rows.
9. Explicit v0.69 compatibility with a supplied `TABLE_METADATA` class does not contaminate v0.70 native identity or behaviour.
10. No global NoSQLServer transport class name is required by the external adapter.

## Adversarial cases requested

Include at least 30 cases covering:

- malicious external `tableMetadata()` that throws;
- metadata callback with side effects;
- missing optional `TABLE_METADATA`;
- wrong optional `TABLE_METADATA` class;
- metadata queries before/while/after first materialisation;
- two prepared relations from the same provider;
- concurrent PREPARE versus first SELECT;
- schema definition mutation after registration;
- relation object replacement;
- duplicate external table names;
- geometry-capability methods appearing on a non-geometry algorithm relation;
- host class substitution for each of the three genuinely required classes;
- v0.69 direct metadata compatibility;
- v0.70 metadata path accidentally regressing to provider delegation;
- msqlshim SHOW TABLES / SHOW COLUMNS / PREPARE / FETCH;
- Database Core tables / metadata / describe / rows / query;
- cardinality requests before materialisation;
- LIMIT 0 / WHERE false plans;
- repeated catalog scans;
- prepared-statement plan/cache reuse after source-manifest drift.

## Mutants requested

Provide at least 20 mutations, especially:

- re-add `TABLE_METADATA` as mandatory;
- call provider `tableMetadata()` from federation;
- construct `.DatabaseTableMetadata` by global name in the adapter;
- make `rowCount` trigger materialisation;
- make PREPARE trigger row demand;
- make FETCH call SQL execution again;
- make second provider relation execute independently;
- ignore source/input drift between metadata and first row demand.

## Verdict format

Return:

- executive verdict;
- claims table;
- blocker / should-do-next / defer / reject list;
- adversarial corpus;
- mutation corpus;
- any boundary that still incorrectly belongs to the provider rather than federation.
