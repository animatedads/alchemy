# NoSQLServer v0.79 — Alchemy Objects v0.8 preferred construction

v0.79 rebases the v0.78 STANDARD-adopted service boundary onto **Alchemy Objects
v0.8** and migrates NoSQLServer-owned service objects from the compatibility
`initAlchemy()` path to the preferred `INIT:SUPER` construction chain.

The database semantics are unchanged. FILE/Object/JSON/native SQLite/GeoPackage/
Federated engines, the SQL executor, runtime, transaction and Database Core
adapter remain the only Alchemy-derived NoSQL objects; rows, scalar values,
geometry values, parser/expression nodes and other hot-path data stay lightweight.

`AlchemyAdoptionVerifier` proves those service objects at `STANDARD`, observes
construction provenance `INIT`, and successfully round-trips an adoption
checkpoint. `SECURE_READY` remains host-configured and is never implied.

Current house capabilities:

- `ALCHEMY_OBJECT_BASE_0_8`
- `ALCHEMY_OBJECT_STANDARD_0_8`
- `ALCHEMY_OBJECT_INIT_SUPER_CONSTRUCTION`
- `ALCHEMY_OBJECT_ADOPTION_CHECKPOINT`
- `ALCHEMY_OBJECT_EXECUTION_PROVENANCE`

NoSQLServer still keeps TUTOR Unicode optional and does not vendor either
Alchemy Objects, ooRexx Crypto, or TUTOR.

See `ALCHEMY_OBJECT_ADOPTION_v0.79.md` and `VALIDATION_v0.79.txt`.

---

# NoSQLServer v0.78 — Alchemy Objects v0.5.1 STANDARD adoption

v0.78 keeps the v0.77 service-boundary migration but now satisfies the explicit
Alchemy Objects v0.5 adoption contract. The required runtime base is
**Alchemy Objects v0.5.1**, whose reserved-surface refinement permits legitimate
business `version()` / `schema()` APIs while keeping universal security/evidence
behavior non-shadowable.

All migrated NoSQL service objects are verified at `STANDARD`; value/hot-path
objects remain lightweight. `SECURE_READY` is host-configured and never implied.
No SQL, GeoPackage/native SQLite, JSON, optional Unicode or storage semantics are
changed by this release. See `ALCHEMY_OBJECT_ADOPTION_v0.78.md` and
`VALIDATION_v0.78.txt`.

New capabilities: `ALCHEMY_OBJECT_BASE_0_5_1`,
`ALCHEMY_OBJECT_STANDARD_0_5`.

---

# NoSQLServer v0.76 — real POINT/POLYGON spatial predicates

v0.76 adds the first real spatial SQL operators over the typed GeoPackage
geometry values preserved since v0.67/v0.69 and read natively since v0.74.

The implementation decodes the actual GeoPackageBinary/WKB bytes. It supports
2D `POINT` and `POLYGON` and exposes:

```sql
ST_GEOMETRYTYPE(geometry)
ST_SRID(geometry)
ST_X(point)
ST_Y(point)
ST_WITHIN(point, polygon)
ST_INTERSECTS(point, polygon)
```

`ST_WITHIN` is strict (boundary is not within); `ST_INTERSECTS` includes the
boundary. Polygon holes and SRID mismatches are handled explicitly. Spatial
predicates are normal SQL expressions and therefore work in the generic v0.72
INNER JOIN predicate path rather than a GeoPackage-specific join engine.

v0.76 deliberately does **not** claim full Simple Features, distance,
reprojection, polygon/polygon topology, LINESTRING/MULTI* support or spatial
indexing. See `SPATIAL_SQL_v0.76.md` and `VALIDATION_v0.76.txt`.

New capabilities: `SPATIAL_POINT_POLYGON_FUNCTIONS`,
`ST_WITHIN_POINT_POLYGON`, `ST_INTERSECTS_POINT_POLYGON`,
`ST_GEOMETRY_ACCESSORS`.

---

# NoSQLServer v0.75 — optional Unicode text profile

v0.75 adds **optional** Unicode-aware text semantics using TUTOR (The Unicode
Tools Of Rexx). NoSQLServer remains classic-string-first and has no static
dependency on TUTOR.

Existing tables and columns default to:

```yaml
textMode: CLASSIC
```

A table may opt all VARCHAR/TEXT columns into Unicode semantics:

```yaml
name: people
textMode: UNICODE
columns:
  - {name: id, type: INTEGER, primaryKey: 1}
  - {name: display_name, type: VARCHAR}
```

or override an individual text column:

```yaml
columns:
  - {name: raw_protocol_text, type: TEXT, textMode: CLASSIC}
  - {name: display_name, type: VARCHAR, textMode: UNICODE}
```

Before reading/writing a UNICODE column the application explicitly enables the
optional provider:

```rexx
.NoSQLUnicodeSupport~enable("/opt/TUTOR")
```

If UNICODE is requested without TUTOR, NoSQLServer fails closed. Merely
installing or loading TUTOR does **not** change CLASSIC column behavior.

The TUTOR-backed UNICODE profile provides strict UTF-8 validation, NFC
normalization, canonical-equivalent equality/constraints, Unicode case mapping,
grapheme-aware `SUBSTR`, `CHAR_LENGTH`/`CHARACTER_LENGTH`, and LIKE `_`
semantics. `OCTET_LENGTH` remains available for the UTF-8 byte count.

NoSQLServer does **not** claim locale-aware collation in v0.75. ORDER BY for
UNICODE values is deterministic normalized Unicode/UTF-8 code-point order.

New capabilities:
`OPTIONAL_TUTOR_UNICODE`, `UNICODE_NFC_TEXT`,
`UNICODE_GRAPHEME_FUNCTIONS`.

See `COMPATIBILITY_TUTOR_UNICODE_v0.75.md` and
`tests/v075_optional_unicode_smoke.rex`.

---

## NoSQLServer v0.32

Adds a namespaced `database_core` v0.22 compatibility adapter without changing the native NoSQLServer API. `db~databaseCore` returns `.NoSQLDatabaseCoreAdapter`, which normalizes transaction `status`/`outcome`, exposes database_core row/value/metadata semantics, supports `queryWithSchema`, ordered mutation results (including per-member prepared-batch results), maps publication conflicts to `SERIALIZATIONFAILURE`, and provides whole-transaction retry plus honest read-only/serializable policy surfaces.

The adapter is deliberately namespaced because NoSQLServer and `database_core.cls` publish several identical public class names with different observable semantics; do not `::requires` both full class sets into one package namespace. Native `.DatabaseRow`, `.DatabaseValue`, `.DatabaseTransaction`, planner diagnostics, staged publication, recovery, adaptive indexes/join maps, and SQL execution remain unchanged. See `COMPATIBILITY_DATABASE_CORE_v0.22.md`.

New capabilities: `DATABASE_CORE_ADAPTER`, `RESULT_SCHEMA`, `MUTATION_RESULTS`, `PREPARED_MUTATION_RESULTS`, `TRANSACTION_RETRY`, `TRANSACTION_ISOLATION`, and `TRANSACTION_READ_ONLY`. `TRANSACTION_TIMEOUT` and `GENERATED_KEYS` are intentionally not advertised.

## NoSQLServer v0.31

Adds the Gemini five-query "Hell Corpus v2" slice as a permanent semantic/composite acceptance layer. New support includes scalar `NOT IN (SELECT ...)` with SQL NULL-trap WHERE semantics, aggregate `NULLIF`, aggregate arithmetic (`+ - * /`) over grouped results, aggregate sources based on LEFT JOIN, correlated aggregate DELETE, grouped scalar projection expressions derived from grouped columns, and nested correlated CASE subqueries.

New capabilities: `NOT_IN_SUBQUERY`, `NULLIF`, `AGGREGATE_ARITHMETIC`, `CORRELATED_DELETE_AGGREGATE`, and `NESTED_CORRELATED_CASE`.

`tests/v031_gemini_hell_smoke.rex` independently verifies all five Gemini probes plus a stronger actual `NOT IN`/NULL trap (the supplied Query 26 subquery itself cannot return NULL on the Grok seed), a zero-member LEFT JOIN aggregate bucket for `NULLIF(COUNT(...),0)`, post-DELETE table state, and exact CASE classifications.

Regression gates remain: Claude 12/12 oracle-backed, Grok feature torture 72/72, SQL-92 company smoke PASS, and Grok hell v1 24/25 with zero wrong-result/execution-error outcomes.

## NoSQLServer v0.30

Expands the correctness-first window surface without claiming full SQL window support. v0.30 adds `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` plus running `COUNT`, `AVG`, `MIN`, and `MAX` alongside the existing running `SUM`. Window ordering may be `ASC` or `DESC`, and ranking windows may omit `PARTITION BY` for a single global partition. Running aggregates continue to require the explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` frame so peer rows do not silently acquire default `RANGE` semantics. Multiple window expressions in one SELECT must currently share the same partition/order definition.

New capabilities: `WINDOW_ROW_NUMBER`, `WINDOW_RANK`, `WINDOW_DENSE_RANK`, `WINDOW_RUNNING_SUM`, `WINDOW_RUNNING_COUNT`, `WINDOW_RUNNING_AVG`, and `WINDOW_RUNNING_MIN_MAX`. The original v0.28 `WINDOW_RUNNING_AGGREGATE` capability remains for compatibility.

New acceptance: `tests/v030_window_extended_smoke.rex` proves peer ranking (`ROW_NUMBER` vs `RANK` vs `DENSE_RANK`), partition resets, running count/average/min/max, descending window order, and a global window with no `PARTITION BY`. Historical v0.28 running-SUM behaviour remains unchanged and retains access path `WINDOW_RUNNING_SCAN`.

## NoSQLServer v0.29

Adds bounded `WITH RECURSIVE` anchor-`UNION ALL` hierarchy execution with positional column stability and cycle guard.

# NoSQLServer v0.26

## v0.24 row-value IN and quantified subquery comparisons

- Adds multi-column/row-value membership: `(a,b) IN (SELECT x,y ...)`, with subquery arity validation and SQL NULL comparisons preserved as non-matches in WHERE.
- Adds quantified comparisons against one-column subqueries: `ALL`, `ANY`, and `SOME`. `SOME` is an `ANY` synonym.
- Empty-set semantics are tested explicitly: `x > ALL (empty)` is true; `x = ANY (empty)` / `SOME` are false.
- The implementation expands set-subquery predicates into the existing relational predicate tree before ordinary predicate parsing, so single-table and join execution reuse the established typed comparison machinery rather than creating a parallel evaluator.
- Grok hell corpus Queries 12, 13 and 14 are now independently oracle-backed PASS results. Hell baseline advances to **10 PASS / 7 UNSUPPORTED / 8 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- Adds capabilities `ROW_VALUE_IN`, `QUANTIFIED_COMPARISON`, `ANY_SOME`, and `ALL`.
- Adds `tests/v024_set_quantifier_smoke.rex`, including row-value matching, `ANY`/`SOME`, `ALL`, and empty-subquery semantics.
- Claude remains **12/12 oracle-backed**, Grok feature torture remains **72/72**, and the SQL-92 company smoke remains green.


## v0.23 hell-corpus composite hardening

- Hell corpus baseline advances from **4 PASS / 8 UNSUPPORTED / 13 PARSE_ERROR** to **7 PASS / 8 UNSUPPORTED / 10 PARSE_ERROR**, with **0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- Hell Query 6 now supports HAVING scalar subqueries correlated to the current grouping row; group correlation is bound before the scalar aggregate subquery executes.
- Hell Query 7 now supports two-level correlated scalar/aggregate subqueries in WHERE comparisons. Scalar-subquery detection is whitespace-insensitive, so multi-line statement accumulation may produce `( SELECT ...)` without changing semantics.
- Hell Query 9 adds ordinary derived-table execution over a UNION result. UNION branches are aligned by ordinal and inherit result column names from the first SELECT, matching SQL set-operation semantics instead of comparing branch-specific projection names.
- Adds version capabilities: `CORRELATED_HAVING`, `NESTED_CORRELATION`, `POSITIONAL_UNION`, and `DERIVED_UNION`.
- All new hell-corpus PASS results are independently oracle-backed.

## v0.22 hell-corpus baseline / EXISTS / self-join hardening

- Adds the Grok `hell_corpus_v1.sql` as a permanent 25-query adversarial acceptance corpus and `hell_score.rex` statement-level scorer.
- Establishes the first oracle-backed hell baseline: **4 PASS / 8 UNSUPPORTED / 13 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**. A successful query without an oracle is deliberately not trusted by the scorer.
- Adds correlated `EXISTS (...)` and `NOT EXISTS (...)` for single-table outer SELECTs, including grouped/HAVING EXISTS subqueries. New access paths are `EXISTS_CORRELATED` and `NOT_EXISTS_CORRELATED`.
- Fixes a real self-join correctness bug exposed by hell Query 8: the older two-table join path qualified both sides by the physical table name, so aliases of the same table overwrote each other and could return SUCCESS with the wrong empty result. Self-joins now reuse the alias-safe `INNER_HASH_CHAIN` relation path.
- Generalises grouped SELECTs so `GROUP BY` may project grouped columns or literals without requiring an aggregate. This is valid SQL and is required by common EXISTS forms such as `SELECT 1 ... GROUP BY ... HAVING ...`.
- Adds version capabilities `EXISTS_SUBQUERY` and `NOT_EXISTS_SUBQUERY`; `db~version` reports release/SQL level 0.22.
- Claude remains **12/12 oracle-backed** and Grok remains **72/72**. RIGHT/FULL JOIN remain clean unsupported boundaries.


## v0.21 correlated aggregate completion / COALESCE

- Adds `COALESCE(...)` to scalar projection evaluation and to aggregate projections such as `COALESCE(SUM(expr), 0)`, preserving SQL NULL-on-empty aggregate semantics before fallback.
- Completes correlated aggregate SELECT-list subqueries whose aggregate source is an INNER JOIN relation. This reuses the generalized aggregate-source execution introduced in v0.20 rather than adding a query-specific execution path.
- Allows unaliased parenthesized scalar SELECT-list subqueries; `AS` is no longer an accidental requirement for valid scalar-subquery projection.
- Adds BOOLEAN literals (`TRUE` / `FALSE`) to the shared scalar-expression evaluator.
- Unifies single-table computed `ORDER BY` with the existing relation expression sorter, so `ORDER BY CASE ...` works consistently outside joins as well as inside them.
- Adds version capabilities `COALESCE` and `CORRELATED_AGGREGATE_SUBQUERY`; `db~version` reports release/SQL level 0.21.
- Claude's fixed 12-query torture corpus is now **12 PASS / 0 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**, and all twelve queries are independently oracle-backed.
- Adds `v021_correlated_aggregate_coalesce_smoke.rex` and `sql92_company_smoke.rex`. The SQL-92 company smoke covers typed DDL/DML, predicates, multi-inner-join, LEFT JOIN, grouped aggregates, IN subquery, CASE/concat/expression ORDER BY, UNION, scalar functions, UPDATE and DELETE.
- Grok's external feature ladder remains **72/72**; only RIGHT JOIN and FULL JOIN remain clean unsupported probes in that harness.

## v0.20 HAVING / derived aggregate relations

- Aggregate execution now accepts physical tables, explicit INNER JOIN chains, and derived `FROM (SELECT ...) alias` relations.
- Adds `HAVING` over completed groups, including scalar aggregate subqueries.
- Derived aggregate columns retain usable SQL identity through `SQLDerivedRelationDefinition`; unresolved derived types are treated as `UNKNOWN` and validated at runtime where numeric aggregate semantics require it.
- Claude torture Query 6 is oracle-backed and passes; current torture score is 11/12 with zero wrong-result executions.
- New version capabilities: `HAVING`, `DERIVED_TABLES`, `AGGREGATE_JOIN_SOURCES`, `DERIVED_AGGREGATES`.


## v0.19 SELECT expression surface

- Adds SELECT-list `UPPER`, `LOWER`, and `SUBSTR` using the existing native expression evaluator.
- Adds searched CASE (`CASE WHEN predicate THEN ... ELSE ... END`) in SELECT projection while preserving the existing simple CASE/order-expression support.
- Unaliased computed projections receive their expression text as a stable result-column label rather than being rejected merely for lacking `AS`.
- Adds version capabilities `SELECT_SCALAR_FUNCTIONS` and `SELECT_CASE_EXPRESSIONS`; `db~version` reports release/SQL level 0.19.
- Grok's external feature ladder remains 72/72 and now independently reports both CASE projection and scalar UPPER projection as supported.
- Claude's fixed torture corpus remains honestly 10 PASS / 2 UNSUPPORTED / 0 wrong-result. Query 6 (HAVING/derived aggregate FROM) and Query 12 (COALESCE + joined correlated aggregate subqueries) remain explicit future work.

NoSQLServer is an ooRexx-native, file-backed relational SQL layer using native `Yaml` and `CsvStream` support. Tables remain authoritative delimited streams; YAML defines schema and per-table physical serialization, while indexes and join maps remain disposable derived structures.

## v0.18 correlated SELECT-list subqueries and aggregate expressions

- Adds scalar SELECT-list subqueries, including correlation against the current outer row. Outer references are bound from typed row values before the nested SELECT executes; text values are SQL-quoted rather than blindly concatenated.
- Adds row-by-row aggregate expressions for `SUM(...)` / `AVG(...)`, allowing forms such as `SUM(quantity * unit_price)` while preserving NULL-on-empty-set semantics.
- Corrects outer SELECT parsing to locate the top-level `FROM`, so `FROM` tokens inside SELECT-list subqueries no longer terminate the outer projection.
- Corrects aggregate detection so aggregate functions inside nested SELECT-list subqueries are not mistaken for aggregates of the outer SELECT.
- Adds `CORRELATED_SCALAR_SUBQUERY`, `SELECT_LIST_SUBQUERY`, and `AGGREGATE_EXPRESSIONS` version capabilities. Version display reports `NoSQLServer 0.18` / SQL level `0.18`.
- Claude torture Query 2, **Correlated Subqueries Instead Of A Join**, is independently oracle-backed. The fixed seed-42 score advances to **10 PASS / 2 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- Grok's feature harness remains **72/72**.
- New runtime test: `v018_correlated_subquery_smoke.rex`.

## v0.17 CASE and computed ORDER BY expressions

- Adds expression-aware ORDER BY for relational rows before projection. ORDER keys may now be simple CASE expressions, string concatenation with `||`, literals, numeric expressions already supported by the projection evaluator, or ordinary qualified columns.
- Adds simple searched-by-value CASE ordering such as `CASE o.status WHEN 'CANCELLED' THEN 3 WHEN 'RETURNED' THEN 2 ELSE 1 END`. This slice deliberately does **not** claim general CASE expressions in the SELECT list.
- Adds SQL string concatenation (`||`) to the shared scalar evaluator used by ORDER BY expressions, with NULL propagation.
- Adds `CASE_EXPRESSIONS`, `STRING_CONCAT`, and `ORDER_BY_EXPRESSIONS` version capabilities. Version display reports `NoSQLServer 0.17` / SQL level `0.17`.
- Claude torture Query 10, **CASE-Expression Sort Plus String-Concat Sort Key**, is now independently oracle-backed. The fixed seed-42 score advances to **9 PASS / 3 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- Grok's feature harness remains **72/72**. Its SELECT-list CASE probe remains a deliberate parse-error boundary because v0.17 only claims CASE in ORDER BY expressions.
- New runtime test: `v017_case_order_smoke.rex`.



## v0.16 explicit inner-join chains and projection arithmetic

- Adds explicit multi-table `JOIN` / `INNER JOIN` chains using incremental hash joins. Each newly introduced relation must expose an equality connector to the relation already built; complete ON predicates are still evaluated before a candidate row is accepted.
- Adds alias-safe N-table inner relations and the `INNER_HASH_CHAIN` diagnostic access path. Bare `JOIN` and explicit `INNER JOIN` are normalized to equivalent semantics.
- Adds simple numeric multiplication in SELECT projection expressions, e.g. `(oi.quantity * oi.unit_price) AS line_total`. SQL NULL propagates through multiplication and nonnumeric operands are rejected rather than coerced silently.
- ORDER BY for inner-join chains is resolved against source relation columns before projection, so sorting may legitimately use columns not returned by the SELECT list and may mix ASC/DESC keys.
- `db~version~supports(...)` now advertises `MULTI_INNER_JOIN` and `PROJECTION_ARITHMETIC`. Version display reports `NoSQLServer 0.16` / SQL level `0.16`.
- Claude torture Query 1, **The Kitchen Sink**, is now independently oracle-backed: the oracle rebuilds the five-table relation, recomputes line totals, and checks the full six-key mixed-direction ordering. Fixed seed-42 score advances to **8 PASS / 4 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- Grok's unchanged feature harness remains **72/72** and now reports explicit multi-`INNER JOIN` as supported.
- New runtime test: `v016_inner_join_expression_smoke.rex`.



## v0.15 transaction recovery and scalar predicates

- Adds crash-recovery intent journalling around whole-database transaction publication. The journal is a sibling of the database root and records the live, staged, backup and expected-signature paths before the first authoritative rename. Recovery infers progress from the actual directory state instead of trusting a mutable phase flag.
- `FileDatabaseEngine~init` invokes publication recovery before opening the database. If the live tree was renamed and the staged tree is intact, recovery completes publication; if the stage vanished, it restores the authoritative backup; if live changed after intent but before rename, it preserves live and discards the stale stage.
- Adds the `TRANSACTION_RECOVERY` version capability. This improves crash consistency but does not claim cross-process distributed locking; concurrent writers are still protected by signature conflict checks rather than a filesystem-wide transactional lock manager.
- Adds predicate value-expression execution for nested `UPPER`, `LOWER`, and `SUBSTR`, plus SQL `LIKE` (`%` and `_`) and inclusive `BETWEEN`. These are intentionally advertised as `PREDICATE_FUNCTIONS`, `LIKE`, and `BETWEEN`; general SELECT-list function expressions remain outside this slice.
- Claude torture Query 3, **Function-Wrapped WHERE, Wildcards Both Ends**, now executes and is independently oracle-backed. Fixed seed-42 score advances to **7 PASS / 5 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**.
- New runtime tests: `v015_transaction_recovery_smoke.rex` and `v015_scalar_predicate_smoke.rex`.

Version display now reports `NoSQLServer 0.15` / SQL level `0.15`.


## v0.14 shared database interoperability

- Preserves the native file/YAML/delimited-stream engine and adds shared abstraction aliases rather than replacing native names. `SYNTAXERROR` aliases `SQLPARSEERROR`, `UNSUPPORTED` aliases `SQLUNSUPPORTED`, `CONSTRAINTVIOLATION`/`DUPLICATEKEY` alias the existing native constraint result, and shared operation constants coexist with `CREATE_TABLE`, `SELECT`, `BUILD_INDEX`, and `BUILD_JOIN_MAP`.
- `FileDatabaseEngine~execute(sql)` and `~query(sql)` now expose the SQL facade directly; `.SQLDatabase` is also provided as a compatibility facade subclass of `.NoSQLServerSQL`.
- Adds `.DatabaseTransaction` via `db~transaction`. Transactions use a stable sibling copy-on-write database snapshot. Operations remain private until commit; commit executes the whole queue against the staged database and publishes the complete database only after all operations succeed and the live database signature is still unchanged.
- Successful commit reports `.Error~COMMITTED`. Rollback before commit reports `.Error~NOTEXECUTED`; a commit which executes staged operations and then fails reports `.Error~ROLLEDBACK`. Double commit/rollback uses `.Error~INVALIDSTATE`.
- Adds deferred transaction query objects. `tx~query(...)` returns `.DatabaseDeferredQueryResult` with `NOTEXECUTED` and no rows until successful commit. Failed commits leave the reference empty and `ROLLEDBACK`; explicit pre-commit rollback leaves it `NOTEXECUTED`.
- Adds transaction-local savepoints (`tx~savepoint(name)`, `tx~rollbackTo(sp)`) with `.Error~INVALIDSAVEPOINT` for foreign/unknown savepoints.
- Adds prepared statements and batches. Parameters are retained as objects until commit and are rendered only through `.DatabaseParameterBinder`, which counts placeholders outside quoted SQL, validates explicit integer/decimal/boolean values, quotes text safely, preserves NULL, and returns `PARAMETERCOUNT`/`INVALIDPARAMETER` rather than blindly interpolating caller strings.
- Adds `.DatabaseValue` and `.DatabaseType` (`NULL`, `BOOLEAN`, `INTEGER`, `DECIMAL`, `VARCHAR`, `DATE`, `DATETIME`, `BLOB`, `UNKNOWN`). Simple table reads preserve raw field representation, typed/coerced value, type name, and NULL state.
- Adds table metadata via `db~tableMetadata(name)` and `db~queryTable(name)`, with column name, native type, common type, nullable flag, and ordinal position. `DatabaseRow` now provides `~at`, `~rawAt`, and `~valueAt`; `DatabaseResult` provides `~rowCount`.
- `db~version~supports(...)` now advertises `TRANSACTIONS`, `SAVEPOINTS`, `PREPARED_STATEMENTS`, `PREPARED_BATCH`, `TYPED_RESULTS`, and `RESULT_METADATA`.
- Transaction publication is conflict-safe against changes detected through the authoritative catalogue/table generations. Coordination of the final publish is shared across engine objects in the same ooRexx process. This release does not claim cross-process distributed transaction locking.

Example:

```rexx
db = .FileDatabaseEngine~new("./demo")
tx = db~transaction
ignore = tx~execute("INSERT INTO people (id,name) VALUES (1,'Ada')")
q = tx~query("SELECT * FROM people")
rs = tx~commit
if rs~status = .Error~COMMITTED then say q~rows~items
```

Prepared example:

```rexx
tx = db~transaction
ps = tx~prepareStatement("insert_person", -
    "INSERT INTO people (id,name) VALUES (?, ?)")
params = .array~of(.DatabaseValue~integer(2), -
                   .DatabaseValue~varchar("Grace"))
ignore = tx~executePrepared(ps, params)
rs = tx~commit
```


## v0.13 aggregates, GROUP BY, and version identity

- Adds grouped and ungrouped `COUNT(*)`, `COUNT(column)`, `SUM(column)`, `AVG(column)`, `MIN(column)`, and `MAX(column)` over simple column arguments. SQL NULL values are ignored by column aggregates; `COUNT(*)` counts rows.
- Adds `GROUP BY` for simple columns with validation that every non-aggregate projected column belongs to the grouping key. `HAVING`, aggregate expressions such as `SUM(qty*price)`, and correlated aggregate subqueries remain deliberately unsupported.
- Grok's external `sql_feature_torture.rex` is now included as an acceptance harness; the packaged acceptance copy tightens NULL checks to require logical `.nil` and follows NoSQLServer's established qualified result-key contract.
- Adds a public structured version contract. `db~version` returns `.NoSQLServerVersionInfo`, while `say db~version` renders a useful identity string including product release, engine/storage format, SQL level, ooRexx version/language level, platform, and architecture. `sql~version` forwards the same version object contract.
- Version information is queryable without parsing strings: `v~release`, `v~storageFormatVersion`, `v~runtimeVersion`, and `v~supports("GROUP_BY")`.

Example:

```rexx
db = .FileDatabaseEngine~new("./demo")
say db~version
v = db~version
say v~release
say v~storageFormatVersion
say v~supports("GROUP_BY")
```

Expected display under the supplied runtime:

```text
NoSQLServer 0.15 [engine=FILE; storage=YAML+DELIMITED; format=1; SQL=0.15; ooRexx=5.3.0 lang=6.06; LINUX/64]
```


Current fixed seed-42 torture score is **9 PASS / 3 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**. The aggregate slice intentionally does not claim Claude queries 6 or 12 yet because they require `HAVING`, aggregate expressions, derived/correlated subqueries, or SELECT-list subqueries beyond this release.

## v0.10 changes

- Adds chained `LEFT JOIN` execution for equality joins.
- Adds alias-qualified relation storage for self-joins so repeated references to the same base table remain distinct (`e1.*`, `e2.*`, `e3.*`).
- Adds NULL-extension for unmatched right-side rows, preserving true outer-join semantics.
- Adds a `LEFT_HASH_CHAIN` access path using per-join hash buckets rather than materialising full Cartesian products.
- Supports projection and ORDER BY over projected aliases after chained LEFT JOINs.
- Advances the progressive torture score from 2/12 to 3/12: Query 5, **Three-Level Self-Join Org Chart**, now passes alongside Queries 4 and 11.
- Query 5 is oracle-backed in `torture_score.rex`: the harness independently reconstructs each employee's manager and manager's manager from the authoritative employee table and compares the full result multiset.
- Adds `v09_left_join_selfjoin_smoke.rex`, including unmatched employees to prove NULL-extension rather than accidental inner-join behaviour.

## Current torture baseline

Using the included deterministic tiny seed-42 corpus:

```text
DDL accepted : 5/5
INSERT stmts : 3/3
rows loaded  : 14
queries      : 12
  PASS           : 9
  UNSUPPORTED    : 3
  PARSE_ERROR    : 0
  WRONG_RESULT   : 0
  EXECUTION_ERROR: 0
```

Queries 1, 3, 4, 5, 7, 8, 9, 10 and 11 are independently oracle-backed. The remaining three remain deliberately `SQLUNSUPPORTED`; unsupported syntax is not silently simplified.

## Reproduce

```sh
cd tests
python3 sql_torture_generator.py --target-mb 0.001 --customers 4 --employees 5 --products 5 --seed 42 --no-fk --outfile torture_tiny.sql
rexx torture_score.rex torture_tiny.sql
```

or score the included deterministic fixture:

```sh
rexx torture_score.rex torture_tiny_seed42.sql
```

## Deliberate boundaries

v0.10 supports chained equality `LEFT JOIN`s, including self-joins. Extra ON-clause predicates such as `LEFT JOIN ... ON a.id=b.id AND b.status <> 'X'` remain `SQLUNSUPPORTED`; therefore torture Query 7 is intentionally not accepted yet. RIGHT/FULL JOIN, explicit multi-inner-JOIN chains, GROUP BY, aggregates, subqueries, UNION, CASE and SQL functions remain future surfaces.

## v0.10 — LEFT JOIN ON predicates and anti-join semantics

- `LEFT JOIN ... ON` now accepts conjunctions containing one equality connector plus additional predicates.
- Additional ON predicates are evaluated during match formation, before NULL extension.
- `WHERE right_column IS NULL` therefore has proper anti-join semantics.
- Torture query 07 is independently oracle-checked and now passes.
- Torture baseline: 4/12 PASS, 8/12 UNSUPPORTED, 0 PARSE_ERROR, 0 WRONG_RESULT, 0 EXECUTION_ERROR.
- New smoke: `tests/v010_left_join_on_antijoin_smoke.rex`.

## v0.11 UNION + simple IN-subquery

v0.11 adds top-level `UNION` (distinct set semantics), final global `ORDER BY`, and a reusable simple `IN (SELECT one_column FROM one_table WHERE predicate)` execution path. The UNION executor runs each branch independently, deduplicates across the combined row set, and only then applies the final ORDER BY.

The torture corpus now earns Query 8 with an independent oracle. Current fixed seed-42 score: 5 PASS / 7 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR.


## v0.12 recursive IN-subqueries

v0.12 generalises the v0.11 one-level `IN (SELECT ...)` executor into a recursive set-membership path. Each subquery is executed through the same SELECT engine and must project exactly one column; its non-NULL values become the membership set for the enclosing level. There is no fixed nesting depth in the executor.

The progressive torture corpus now earns Query 9, **Four-Deep Nested IN Subqueries**, with an independent oracle reconstructed directly from `customers`, `orders`, `order_items`, and `products`. The dedicated `v012_recursive_in_subquery_smoke.rex` also tests a non-empty four-level chain and a deeper recursive chain to guard against a hard-coded depth-four implementation.

Current fixed seed-42 score: **6 PASS / 6 UNSUPPORTED / 0 PARSE_ERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR**. Queries 4, 5, 7, 8, 9 and 11 are oracle-backed.

Correlated SELECT-list subqueries and aggregate subqueries remain outside this slice; Query 2 and Query 12 continue to be rejected through their unsupported aggregate/expression surfaces rather than silently simplified.

## v0.25 composite SQL semantics

v0.25 advances the Grok hell corpus from 10/25 to 14/25 oracle-backed PASS with zero wrong results. It adds:

- nested searched CASE with correlated scalar subqueries in SELECT expressions;
- ORDER BY expressions that may reference projection aliases;
- COUNT(DISTINCT column) in grouped aggregates;
- GROUP BY scalar expressions such as SUBSTR(date,1,4);
- LEFT JOIN against a derived aggregate relation while preserving NULL extension;
- ordinal/qualified output ORDER BY fallback when an unqualified projected name is uniquely identifiable.

`db~version` / `sql~version` report release and SQL level 0.25 and advertise `GROUP_BY_EXPRESSIONS`, `COUNT_DISTINCT`, `ORDER_BY_PROJECTION_ALIAS`, and `NESTED_CASE_SUBQUERY`.

The current hell-corpus score is 14 PASS / 4 SQLUNSUPPORTED / 7 SQLPARSEERROR / 0 WRONG_RESULT / 0 EXECUTION_ERROR. Every PASS has an explicit oracle.



## v0.26 outer joins and SQL set operators

v0.26 closes the outer-join symmetry gap and adds the remaining basic SQL set operators:

- `RIGHT JOIN` / `RIGHT OUTER JOIN`, implemented by preserving the right side through the mature left-outer machinery;
- `FULL JOIN` / `FULL OUTER JOIN`, preserving unmatched rows from both inputs with explicit NULL extension;
- `INTERSECT` with distinct set semantics;
- `EXCEPT` with distinct set semantics;
- positional set-column alignment and `ORDER BY` ordinal support for the new set operators.

`db~version` / `sql~version` report release and SQL level 0.26 and advertise `RIGHT_JOIN`, `FULL_OUTER_JOIN`, `INTERSECT`, and `EXCEPT`.

The dedicated outer-join smoke includes unmatched rows on both sides; this is stronger than hell-corpus Query 2's fixture, whose current data happens to have no unmatched employee/project departments despite its comment. The hell scorer nevertheless carries exact independent oracles for Queries 1 and 2 as generated by the supplied fixture.

Current external gates:

- Claude torture corpus: 12/12 PASS, every query oracle-backed.
- Grok feature torture: 72/72 checks, 0 failures, 0 clean unsupported cases remaining in that original ladder.
- SQL-92 company smoke: PASS.
- Grok hell corpus: 18/25 PASS, 2 SQLUNSUPPORTED, 5 SQLPARSEERROR, 0 WRONG_RESULT, 0 EXECUTION_ERROR; every PASS has an explicit oracle.

The remaining hell frontier is deliberately not folded into this release: window functions, recursive CTEs, correlated UPDATE/DELETE shapes, DISTINCT/aggregate ordering interactions, aggregate-filtered cross joins, and CAST/date-expression syntax remain later work.

## v0.27 mutation/composition checkpoint

v0.27 extends the native SQL surface with correlated expression UPDATE, scalar-IN
subquery DELETE, scalar aggregate subqueries in cross-join predicates, and typed
`CAST(... AS VARCHAR)` value expressions.  These are advertised through
`db~version` as `CORRELATED_UPDATE`, `SUBQUERY_DELETE`,
`CROSS_JOIN_SCALAR_FILTER`, and `CAST_VARCHAR`.

The Grok hell corpus is 22/25 oracle-backed PASS at this checkpoint.  The
remaining deliberate frontiers are the window-function query, recursive CTE,
and the corpus's intentionally contentious DISTINCT/aggregate ORDER BY shape.


## v0.27.1 diagnostic preservation repair

The SQL top-level SYNTAX safety net and native constraint catches now preserve ooRexx condition messages from `condition("O")["MESSAGE"]`, with the attached `ADDITIONAL` data as fallback. This prevents deliberate parser diagnostics and unexpected ooRexx SYNTAX conditions from being flattened into blank SQLPARSEERROR/CONSTRAINT messages. No SQL feature semantics changed from v0.27.


## v0.28 running window aggregates

NoSQLServer v0.28 adds a correctness-first running window surface for the SQL form:

```sql
SUM(value) OVER (
  PARTITION BY partition_column
  ORDER BY order_column
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

The implementation materializes the selected source, orders it by partition/order keys, and computes a partition-local running SUM. It advertises `WINDOW_RUNNING_AGGREGATE`, `WINDOW_PARTITION_BY`, and `WINDOW_ORDER_BY`. This is deliberately narrower than a claim of general SQL window-function support; ranking functions, arbitrary frames, multiple incompatible windows, and window aggregates beyond this running SUM surface remain future work.

Grok hell-corpus Query 19 is independently oracle-backed in `tests/hell_score.rex`; v0.28 moves the hell score to 23/25 with zero wrong results.


## v0.33 — Hell Corpus v2 baseline

Adds `tests/hell_corpus_v2.sql` and `tests/hell_v2_score.rex`. The initial oracle-backed score is 3/30 PASS, 14 clean SQLUNSUPPORTED, 13 SQLPARSEERROR, 0 wrong results, 0 execution errors. `DELETE ... USING` and `MERGE` are now classified as clean unsupported frontier SQL instead of leaking misleading lower-level errors.


## v0.34 — derived-window composition

Window execution can now consume a derived aggregate relation, allowing patterns such as `RANK() OVER (ORDER BY total DESC)` over `FROM (SELECT key, SUM(...) ... GROUP BY key) x`. Grok Hell Corpus v2 Q09 is independently oracle-backed.


## v0.35 — partition-wide windows and derived window filters

Adds whole-partition window aggregates (`OVER ()` / `OVER (PARTITION BY ...)`) alongside ordered ranking/running windows, fixes top-level ORDER BY detection around derived/window queries, normalizes derived output column names, and supports arithmetic comparison predicates over derived/window outputs. Grok Hell Corpus v2 is 6/30 oracle-backed PASS with 0 wrong results.


## v0.36 — LAG / LEAD / NTILE

Adds partition-aware `LAG` and `LEAD` with explicit integral offsets and literal defaults, plus SQL-style `NTILE`. The window executor now precomputes ordered partition boundaries so navigation/distribution functions can inspect peer rows without corrupting running aggregate state. Grok Hell Corpus v2 reaches 8/30 oracle-backed PASS with 0 wrong results.


## v0.37 — aggregate FILTER

Adds SQL `FILTER (WHERE ...)` semantics to aggregate projections and HAVING. The filter predicate is parsed and normalized once, then applied to each aggregate bucket before COUNT/SUM/AVG/MIN/MAX evaluation. Grok Hell Corpus v2 reaches 10/30 oracle-backed PASS with 0 wrong results.


## v0.38 — named windows and NULL ordering

Adds a reusable named `WINDOW name AS (...)` clause for the currently supported window surface, plus explicit `NULLS FIRST` / `NULLS LAST` ordering. Explicit NULL placement is kept independent from ASC/DESC direction so `NULLS FIRST, salary DESC` cannot be inverted accidentally. Grok Hell Corpus v2 reaches 12/30 oracle-backed PASS with 0 wrong results.


## v0.39 — INSERT grammar compatibility

Adds the standard positional `INSERT INTO table VALUES (...)` form and removes an accidental dependence on one-line/ASCII-space formatting in the INSERT parser. Explicit-column and positional forms now accept SQL grammar whitespace including tabs, LF and CRLF without modifying whitespace inside quoted values. The change is native to NoSQLServer; wire-protocol adapters do not rewrite SQL.


## v0.40 — SQL grammar whitespace normalization

Normalizes SQL grammar whitespace once at the native SQL façade: spaces, tabs,
LF and CRLF outside quoted strings collapse to one grammar space before normal
dispatch and parsing. Quoted data is not modified. This fixes ordinary external
client statements such as `SELECT *` newline `FROM ...` newline `WHERE ...`
without teaching the MySQL wire shim to rewrite SQL.


## v0.41 — LIMIT / OFFSET

Adds native `LIMIT count`, `LIMIT count OFFSET offset`, and MySQL-style
`LIMIT offset,count` to SELECT execution. LIMIT is applied only after the
complete query result, including ORDER BY and set-operation semantics, so it
cannot accidentally limit an unordered intermediate result. This remains core
SQL functionality; MySQL metadata commands such as DESCRIBE and SHOW COLUMNS
remain wire/personality-layer concerns.


## v0.42 — FETCH FIRST ... WITH TIES

Adds SQL-style `FETCH FIRST n ROWS WITH TIES` on top of the established final
ORDER BY result. Boundary peers are retained using the complete final sort key,
so this is not implemented as a synonym for LIMIT. This release also adds an
explicit composition smoke proving v0.41 LIMIT/OFFSET behaves correctly through
joins, grouped aggregates, derived relations, UNION and window queries.


## v0.44 — database events and foreign-key RESTRICT

Introduces a native object event registry for mutation events. Synchronous
`BEFORE_*` handlers can veto before authoritative publication; `AFTER_*`
listeners observe committed table mutations. Foreign keys are implemented as
privileged rules on this substrate rather than as a separate mutation engine.

The first FK surface is intentionally strict: inline single-column
`REFERENCES`, parent PRIMARY KEY/UNIQUE targets, parent-existence validation,
and `RESTRICT`/`NO ACTION` for parent delete/key-update. Cascading actions are
not emulated with nested immediate writes; they remain unsupported until the
staged multi-table mutation graph can publish the entire cascade atomically.


## v0.45 — staged mutation graph and atomic FK cascades

Adds `DatabaseMutationGraph`, backed by the existing stable-clone and atomic
tree-publication machinery. Privileged FK rules and user object handlers can add
dependent mutations to the staged clone, and the entire graph publishes as one
unit or is discarded.

Delivered FK actions now include `ON DELETE CASCADE`, `ON DELETE SET NULL`,
`ON UPDATE CASCADE`, and `ON UPDATE SET NULL`, alongside the existing
RESTRICT/NO ACTION surface. UPDATE cascades deliberately expand after the new
parent key exists in staged storage, while still before graph publication.

`DatabaseEvent~mutationGraph` lets an ooRexx object registered for a mutation
event add ordinary SQL to the same graph. `BEFORE_COMMIT` can veto the complete
graph; `AFTER_COMMIT` fires only once publication has succeeded. SET DEFAULT is
still cleanly unsupported.


## v0.46 — ORDER BY execution rewrite

A real MariaDB/PyMySQL workload exposed a quadratic ORDER BY hot path:
`ORDER BY name DESC LIMIT 50` took 60.887 seconds over 5,007 rows while
`COUNT(*)` took 0.358 seconds.

The old stable insertion sort is replaced by a stable iterative merge sort, and
ORDER BY specifications are compiled once rather than tokenized on every row
comparison. For ordinary SELECT with LIMIT/OFFSET, the executor retains only
`offset + limit` best rows in a bounded max-heap and sorts that retained set,
giving approximately O(n log k) behavior instead of sorting the entire result.

A direct-storage 5,007-row local benchmark isolates sort cost at about 1.07
seconds for the full ordered result and about 0.58 seconds for the LIMIT 50
path. Existing multi-key, NULL ordering, stable peer, LIMIT/OFFSET, window and
FETCH WITH TIES semantics remain regression-tested.


## v0.47 — VALUES table sources

Adds SQL `VALUES` constructors as virtual relational sources, including use as
the base side of a LEFT JOIN with explicit table/column aliases. The executor
feeds VALUES rows into the same alias-relation and null-extension machinery as
physical and derived sources rather than creating fake storage objects.

Grok Hell Corpus v2 Q17 is now independently oracle-backed, moving the score to
14/30 PASS with zero wrong results.

Some general recursive-CTE expression groundwork was also explored while
pursuing Q13, but that case still exposes an ooRexx-level condition and is
deliberately not promoted or advertised as supported.


## v0.48 — append-only single-row INSERT

Single-row INSERT no longer rewrites the complete delimited table. The native
`CsvStream` is opened with `WRITE APPEND`, and its `csvLineOut()` method retains
all delimiter/qualifier escaping before using stream LINEOUT. Multi-row INSERT
continues to use whole-file publication to preserve statement atomicity.

This removes unnecessary write amplification but deliberately does not yet
claim that inserts are O(1): PK/UNIQUE/FK validation still consults existing
rows, and the next write-performance step is to route constraint checks through
the existing index/generation machinery.


## v0.49 — append/tombstone UPDATE and DELETE

Adds a table-specific physical tombstone contract for delimited storage. The
default reserved tombstone byte is `FD`, configurable per table via
`storage.tombstoneHex`. Large-table single-row UPDATE appends the replacement
record and byte-overwrites the old physical record with the configured
tombstone; single-row DELETE byte-overwrites the old record directly.

The implementation deliberately uses byte-positioned `CHAROUT`, not numbered
`LINEOUT`: live testing against the installed ooRexx stream showed that the
numbered LINEOUT path inserted an additional line terminator, whereas CHAROUT
preserved exact file length and every following physical row.

Readers recognize tombstones before column coercion. Multiline CSV records,
multi-row mutations, and small files continue to use the existing whole-file
rewrite path. The default switch-over is 64 KiB and is configurable with
`storage.tombstoneThresholdBytes`.

A pending physical-mutation intent provides append-first UPDATE recovery, and
`compactTable(name)` rewrites only live rows to reclaim tombstone space.
UPDATE constraint validation was also narrowed to changed rows, eliminating the
previous O(n^2) revalidation of thousands of untouched rows for a one-row
UPDATE.


## v0.50 — runtime PK locator cache and SQL single-insert dispatch

Corrects the SQL INSERT dispatcher so a one-tuple `INSERT ... VALUES (...)`
reaches the append-only single-row storage path rather than `insertMany()`.
Multi-row INSERT retains the atomic whole-file path.

Adds a disposable generation-aware runtime primary-key cache for single-column
PK tables. The cache maps PK signatures to rows and physical line locators,
letting repeated single-row PK UPDATE/DELETE work avoid table materialisation.
Successful append/tombstone mutations maintain the cache; whole-file rewrites
and compaction invalidate it. The cache is never authoritative and is rebuilt
from storage after restart or generation mismatch.

A direct-engine loop of 5,000 ordinary SQL INSERT statements completed in about
41.4 seconds; the v0.49 SQL path could not complete even the 500-statement
baseline inside the execution ceiling because it still rewrote via insertMany.

## v0.51 — SQL/table storage isolation

Phase 0 only. The SQL executor no longer reaches through table objects into the
file storage implementation. FileDatabaseTable exposes the read-row/table port
used by NoSQLServerSQL, and a static isolation check confirms the SQL class has
no storage/YAML/CsvStream/SysFile/path references. Behaviour is unchanged.

## v0.52 — live object tables, SELECT only

Adds explicit ObjectTableMapping, ObjectTableStorage, ObjectDatabaseTable and a
minimal ObjectDatabaseEngine. Ordinary ooRexx collections can be registered as
live SQL tables through explicit getter mappings. SELECT/WHERE/projection/
ORDER BY use the existing SQL executor. Mutations and DDL are deliberately
unsupported in this release.

## v0.53 — object-object joins and aggregates

Live object tables now participate in INNER JOIN and aggregate/GROUP BY queries
through the same SQL executor used by file tables. No mutation surface is added.

## v0.54 — object UPDATE and events

Explicit mapped setters can now be targeted by SQL UPDATE. The original live
objects are mutated; table generation advances only after setter application.
BEFORE_UPDATE/AFTER_UPDATE use the existing database event registry, with AFTER
emitted only after successful setters. Object transactions remain unsupported.

## v0.55 — federated FILE + OBJECT catalog

Completes the first object-database programme. FederatedDatabaseEngine presents
persistent FileDatabaseTable and live ObjectDatabaseTable instances through the
same table port. Ordinary SQL can join a persisted file table to a live ooRexx
object collection; the SQL executor does not know which storage kind supplied
the rows.

Object mutations continue to use explicit mapped setters. Cross-backend/object
transactions are deliberately not advertised and return SQLUNSUPPORTED until a
real unit-of-work model exists. msqlshim requires no change: federated/object
tables are normal engine metadata/query surfaces.


## v0.56 — explicit object INSERT factory and DELETE removal policy

Live object tables can now accept a single-row SQL INSERT only when the mapping
declares an explicit factory object/message. The factory receives a fully typed
`DatabaseRow` and returns the object to append. Identity collisions and mapped
getter availability are checked before collection mutation.

DELETE is enabled only when the mapping explicitly declares `ARRAY_DELETE`.
Targets are removed by descending array index, with the existing BEFORE/AFTER
event semantics. Multi-row INSERT remains unsupported until an atomic
factory-batch contract exists.


## v0.57 — frozen object-table snapshots

Adds an explicit read-only snapshot mode for live object tables.
`ObjectTableStorage~freeze()` captures mapped values once into ordinary
`DatabaseRow` copies. Snapshots can be registered directly with
`ObjectDatabaseEngine~registerSnapshot(...)` or created from an already
registered live table with `snapshotTable(...)`.

Snapshots use the same SQL/JOIN/aggregate machinery as live and file-backed
tables, but later changes to the original ooRexx objects are not visible.
INSERT, UPDATE and DELETE against snapshots are explicitly SQLUNSUPPORTED.
This is deliberately not presented as transaction support; a real object
transaction still requires a unit-of-work implementation.


## v0.58 — recursive CTE predicate/projection correctness repair

Repairs Grok Hell Corpus v2 Q13 rather than treating its prior `PARSE_ERROR` as
a frontier boundary. The original raw ooRexx `NIL object` exception came from an
implicit `.nil` expression-success flag inside a recursive-only predicate
fallback.

The expression contract is now explicit, `NOT LIKE` and `||` are handled by the
shared predicate parser, and the recursive-only NOT LIKE fallback has been
removed. Recursive projection alias parsing now distinguishes top-level
`expr AS alias` from `CAST(expr AS type)`, and recursive outer projection
qualifies CTE rows consistently with the normal alias-relation contract.

Q13 now has an independent hierarchy/path oracle and passes. Grok Hell Corpus
v2 moves from 14/30 to 15/30 with zero wrong results.


## v0.59 — correlated scalar subquery in JOIN ON

Repairs Grok Hell Corpus v2 Q20. The inner join-chain executor previously used
a raw `WHERE` substring search and therefore mistook a subquery-local WHERE for
the outer SELECT WHERE boundary.

JOIN-chain boundary detection is now nesting-aware. When an ON clause contains
a scalar subquery, the hash/equality connector is identified independently from
top-level non-subquery conjuncts, and the complete ON predicate is evaluated
per candidate joined row after correlated scalar binding.

Q20 is independently oracle-backed and passes. Grok Hell Corpus v2 moves from
15/30 to 16/30 with zero wrong results.


## v0.60 — UPDATE ... FROM

Adds a conservative one-source `UPDATE ... FROM` surface. Target and source
aliases are resolved through the ordinary multi-relation definition, WHERE is
evaluated against the joined row, and SET expressions reuse the existing
expression evaluator. Mutation still occurs through the target table's primary
key.

If one target row matches more than one source row the statement is rejected
instead of silently selecting an arbitrary source row.

Grok Hell Corpus v2 Q21 is now independently verified and passes. Because the
hell corpus runs sequentially, its later Q27 oracle also now reflects the salary
mutation performed by Q21. Overall v2 moves from 16/30 to 17/30 with zero wrong
results.


## v0.61 — DELETE ... USING

Adds a conservative one-source `DELETE ... USING` surface. Target and source
aliases are resolved through the ordinary multi-relation definition and the
WHERE predicate is evaluated against combined rows.

A target row is deleted once if any source row satisfies the predicate.
Duplicate source matches therefore do not inflate the affected-row count.
Candidate discovery completes before mutation, and actual deletes are routed
through the target table primary key.

Grok Hell Corpus v2 Q22 is independently oracle-backed and passes. Overall v2
moves from 17/30 to 18/30 with zero wrong results.


## v0.62 — journal UTC timestamps and UNION CORRESPONDING

Authoritative table mutation journal files now include a precise UTC ISO-8601
`timestamp` generated by ooRexx `.DateTime~new~utcIsoDate`. Pending physical
mutations also carry their timestamp so crash recovery can preserve the
original operation time when it has to reconstruct a missing journal record.

Adds top-level two-branch `UNION CORRESPONDING`: columns are matched by output
name, normalized to the common shape, deduplicated with UNION semantics and
then ordered. Grok Hell Corpus v2 Q19 is independently oracle-backed and now
passes, taking the corpus to 19/30 with zero wrong results.


## v0.63 — INTERSECT / EXCEPT CORRESPONDING BY

Extends the set-operation executor with name-based `CORRESPONDING` semantics
and explicit `CORRESPONDING BY (column,...)`.

Normal INTERSECT/EXCEPT continue to align by ordinal. CORRESPONDING aligns by
output column name, while BY selects the exact common columns exposed by the
result. Missing or duplicate BY names are rejected.

Grok Hell Corpus v2 Q28 is independently oracle-backed and now passes:
`EXCEPT CORRESPONDING BY (id)` returns exactly ids 3, 4 and 9, with only the
`id` column in the result. Overall v2 reaches 20/30 PASS with zero wrong results.


## v0.64 — non-recursive multi-CTE dependency resolution

Adds statement-local materialized CTEs for ordinary `WITH` queries. CTE bodies
are executed through the normal SQL facade, materialized into temporary table
objects, and exposed to later CTEs and the outer query through an engine overlay.
This keeps joins, aggregation, filtering, and ordering on the existing executor.

CTE declaration order is authoritative: later CTEs may depend on earlier ones;
forward references are rejected rather than guessed. Temporary CTE tables do
not enter the persistent database catalog.

Grok Hell Corpus v2 Q25 is independently oracle-backed and passes. Overall v2
moves from 20/30 to 21/30 with zero wrong results.


## v0.65 — NATURAL JOIN and DISTINCT aggregate-order semantic lock

Adds a conservative one-link `NATURAL JOIN`. Common columns are discovered by
name, all participate in the equality key, NULL never matches NULL, and
`SELECT *` emits each common column exactly once. With no common columns the
operation is a cross join.

Grok Hell Corpus v2 Q18 is independently oracle-backed and passes.

The Q23 survivor is intentionally not made to pass by inventing grouping
semantics. `SELECT DISTINCT x ORDER BY AVG(y)` without GROUP BY or a projected
aggregate now receives an explicit SQLPARSEERROR explaining that DISTINCT does
not imply GROUP BY.

Overall Hell v2 reaches 22/30 PASS with zero wrong results.


## v0.66 — GROUPING SETS, ROLLUP and CUBE

Adds OLAP grouping by compiling all three surfaces into ordinary grouping-set
passes over the aggregate executor's filtered source rows.

`ROLLUP` expands to successive grouping prefixes and `CUBE` to every subset.
Dimensions omitted from a set project NULL, while the empty grouping set emits
the grand-total aggregate row. Duplicate grouping sets remain duplicate rows.

Grok Hell Corpus v2 Q6, Q7 and Q8 now have independent oracles and pass.
Overall Hell v2 moves from 22/30 to 25/30 with zero wrong results.


## v0.67 — GeoPackage as a native federated table source

NoSQLServer can now open a GeoPackage directly as a read-only database backend.
Tables and columns are discovered from GeoPackage/SQLite metadata and exposed
through the ordinary NoSQLServer table contract.

Geometry BLOBs are not flattened: they become typed `GeoPackageGeometry`
values carrying the GeoPackage geometry type and SRID. Spatial SQL predicates
are intentionally the next layer rather than being faked in this release.

`FederatedDatabaseEngine~addEngine()` generalises federation beyond FILE and
OBJECT providers. The live acceptance run joined the supplied OS Functional
Areas Retail Area Minor related-entity table in one GeoPackage directly to
16,508 Built Address rows in a second GeoPackage. The OS `Within` relationships
produced 54 linked built addresses across 13 Inverness postcodes.

The SQLite transport is isolated behind `tools/gpkg_bridge.c`; source and a
rebuild script are included so the backend contract is not tied to the bundled
Linux x86_64 test binary.


## v0.68 — federated engine facade parity

`FederatedDatabaseEngine` now presents the same ordinary read/query facade as
the file engine: `execute`, `query`, `databaseCore`, `tableMetadata`,
`queryTable`, and `readCatalog`.

The catalog is genuinely federated. It merges persistent FILE tables, live and
frozen OBJECT tables, and tables supplied by arbitrary external engines such as
the v0.67 GeoPackage provider. Consumers such as Database Core and msqlshim no
longer need to know which provider owns a table.

The federated-facade regression supplied by the Virtual RYTA Algorithm Relation
work passes unchanged against v0.68. A new current-surface smoke additionally
proves FILE + SNAPSHOT + GeoPackage metadata/query/catalog operation through one
facade.

Algorithm Relation remains an integration concern: a materialised algorithm
result can be registered as a native frozen object snapshot; NoSQLServer itself
does not acquire algorithm-provider semantics.

## v0.69 — Database Core v0.34 relational-source and geometry compatibility

The namespaced Database Core facade now follows the concrete v0.34 relational
source/table-source contract shape. `databaseCore()~relationalSource` exposes
source identity, endpoint identity, capabilities, discovered relation
descriptors and table bindings; `tableSource(name)` exposes metadata, rows,
query and describe operations over the existing database facade.

The facade remains deliberately namespaced. NoSQLServer and `database_core.cls`
still publish overlapping public class names with different historical
semantics, so v0.69 does not pretend that loading both complete packages into
one ooRexx package namespace is safe. The compatibility target is the v0.34
observable contract, not false class identity.

Geometry now survives the complete metadata/value route. `GEOMETRY` is a common
database type, column metadata retains geometry subtype and SRID, and GeoPackage
values reaching Database Core retain raw GeoPackage geometry bytes plus
`geometryType`, `srid`, and `GPKGBLOBHEX` encoding. Federated metadata lookup
now delegates to the owning provider where that provider supplies metadata, so
POINT/POLYGON and SRID information are not erased by the federation facade.

`SPATIALTYPES` is advertised when the backing engine exposes typed geometry.
`SPATIALFUNCTIONS` is intentionally not advertised: v0.69 does not invent
`ST_WITHIN`, `ST_INTERSECTS`, `ST_DISTANCE`, or an index-backed spatial
predicate implementation.

A latent GeoPackage facade bug was also exposed by the new identity path:
`GeoPackageDatabaseEngine~version` attempted to construct a nonexistent
`.DatabaseVersion`. It now returns the same native `NoSQLServerVersionInfo`
shape as the other NoSQLServer engines.

Acceptance is in `tests/v069_dbcore_v034_compat_smoke.rex`; it exercises a FILE
relation and the bundled GeoPackage fixture through one federated relational
source and proves POINT / SRID 27700 / GPKGBLOBHEX preservation through both
direct and federated Database Core paths.

## v0.70 — provider-neutral federation metadata boundary

v0.69 correctly preserved GeoPackage geometry metadata, but did so by asking an
external engine to construct and return NoSQLServer `DatabaseTableMetadata`.
That was an abstraction leak across ooRexx package boundaries.  The supplied
Virtual RYTA / HardWorld v0.11 external engine demonstrated the failure: its
relation contract remained usable, but its independent package could not
resolve NoSQLServer's `.DatabaseTableMetadata` class when federation invoked
that optional adapter method.

v0.70 restores metadata ownership to federation.  `FederatedDatabaseEngine`
builds neutral metadata from the relation's ordinary `definition`; optional
relation capabilities `geometryColumn`, `geometryType`, and `srid` enrich that
metadata when present.  There are no provider-class tests and no special cases
for GeoPackage, Algorithm Relation, Camera, Librarian, or msqlshim.

This preserves the v0.69 geometry result while restoring v0.68 external-adapter
compatibility.  The release advertises `FEDERATED_PROVIDER_NEUTRAL_METADATA`.

Acceptance includes:

- a self-contained external-package regression whose legacy `tableMetadata()`
  would fail if federation called it;
- Virtual RYTA / HardWorld v0.11 lazy Algorithm Relations through federation;
- Librarian v0.11 lazy evidence relations through the same external-engine
  contract;
- Camera Behaviour v0.26 immutable materialized state registered as ordinary
  NoSQLServer OBJECT/SNAPSHOT relations, including a SQL join between frozen
  Camera regime and regime-class rows;
- the existing Camera Algorithm Relation adapter running unchanged against the
  newer Camera package as a backwards-compatibility probe;
- msqlshim v0.10 rebound to v0.70, including text protocol, compression,
  prepared statements, read-only prepared cursors / `COM_STMT_FETCH`, mixed
  transport concurrency, and FIFO backend fairness.

Camera and Algorithm Relation semantics remain outside NoSQLServer.  In
particular, NoSQLServer does not translate Camera state into policy truth and it
does not execute an algorithm merely because SQL scans a materialized relation.

## v0.71 — provider-neutral external mutation dispatch

v0.70 fixed metadata ownership at the federation boundary, but mutation
routing still contained an older provider assumption.  `INSERT`, `UPDATE` and
`DELETE` were dispatched to OBJECT when the table was an object relation and
to FILE for every other table.  As a result, a mutation against an external
relation was reported as `NOTFOUND` by the file engine even though federation
had already resolved that relation from an external provider.  It also meant a
future writable external provider could never receive the ordinary mutation
messages.

v0.71 resolves the owning provider first, using the same OBJECT -> FILE ->
external precedence as table lookup.  Mutation dispatch is then capability
shaped:

- if no provider owns the relation, the result remains `NOTFOUND`;
- if the owning provider does not implement the requested mutation message,
  the result is `SQLUNSUPPORTED` and names the real relation;
- if the owning provider implements the message, federation delegates to it
  and preserves its normal `DatabaseResult`.

The same provider resolution is now used by `selectWhere` and index-candidate
estimation, removing another implicit "non-object means FILE" assumption.  No
provider class tests were added and no external provider is required to expose
NoSQLServer implementation classes merely to be discovered.

`FEDERATED_PROVIDER_NEUTRAL_MUTATION_DISPATCH` advertises the repaired
boundary.

Acceptance is in `tests/v071_external_mutation_dispatch_smoke.rex`.  Its
read-only external relation intentionally has no mutation API and must return
`SQLUNSUPPORTED`.  A second independently packaged provider implements the
standard `insert`, `insertMany`, `updateWhere`, and `deleteWhere` messages; SQL
must delegate each operation exactly once and return the provider result.

The stock Virtual RYTA / HardWorld v0.11 external engine remains unmodified.
Its Algorithm Relations still materialize only on first row read, execute once,
and now reject attempted SQL mutation as `SQLUNSUPPORTED` instead of the
misleading file-table `NOTFOUND` diagnostic.  Librarian and the existing Camera
Algorithm Relation adapter continue to pass through the same generic external
engine boundary.

## v0.72 — general INNER JOIN ON predicate evaluation

v0.71 still had an older specialised two-table JOIN parser that located the
first `=` in the ON text and treated everything on either side as a column
reference.  A valid predicate such as:

    ON e.order_id = x.order_id
   AND e.product  = x.product

therefore attempted to resolve `x.order_id AND e.product=x.product` as the
right-hand column and failed with `Unknown or ambiguous JOIN right column`.

v0.72 makes the existing SQL predicate parser authoritative for INNER JOIN ON
semantics.  The dedicated two-table engine path is retained only for one plain
column-equality predicate.  Other predicates enter the alias-aware join path.
If an equality term connecting the new relation to an already joined relation
is available, it is used only as a hash candidate generator and the complete
ON predicate is evaluated on the combined row.  If no such equality term is
safe, INNER JOIN falls back to candidate-pair predicate evaluation.

This means equality is now an access-path optimisation rather than an INNER
JOIN grammar restriction.  Supported examples include compound AND/OR
predicates, non-equality column predicates, and expression predicates already
understood by the SQL predicate evaluator.

The release advertises:

    INNER_JOIN_GENERAL_ON_PREDICATE

`INNER_HASH_CHAIN` identifies joins where a safe equality connector was used.
`INNER_PREDICATE_CHAIN` identifies the general predicate fallback.

This release does not broaden LEFT/RIGHT/FULL JOIN semantics and does not add
provider-specific logic for XML, EDIFACT, X12, Algorithm Relations, Camera, or
any other relation provider.  The cross-format experiment that exposed the
bug can therefore use its original compound relational ON predicate without
changing either structured-source adapter.

Acceptance is in `tests/v072_general_join_on_smoke.rex`.  It covers the
original compound-equality failure shape, mixed boolean residual predicates,
a top-level OR, a non-equality column join, and a function-expression join.

## v0.73 — explicit JSON relation projections

v0.73 adds a read-only JSON relation provider without making JSON an implicit
flattening format.  A caller registers one or more explicit projections over a
JSON document.  Each projection declares a row path and the exact columns that
cross into the relational model; nested arrays/objects may be projected as
canonical JSON text, but are never recursively exploded by the provider.

Example:

```rexx
json = .JsonDatabaseEngine~new("orders.json")
cols = .array~new
cols~append(.JsonColumnProjection~new("order_id", "$.order_id", "VARCHAR"))
cols~append(.JsonColumnProjection~new("buyer_id", "$.buyer.id", "VARCHAR"))
cols~append(.JsonColumnProjection~new("product", "$.items[0].product", "VARCHAR"))
json~registerProjection("json_orders", "$.orders[*]", cols)

federated~addEngine(json)
r = federated~execute("SELECT * FROM json_orders WHERE buyer_id='123456';")
```

The provider uses ooRexx 5.3.0's shipped `json.cls` parser directly; no external JSON helper is required.  The path surface is intentionally small and deterministic: `$`, dotted object
members, numeric array indexes and `[*]` in row paths.  v0.73 performs a full
document scan for each read and advertises no JSON indexing or predicate
pushdown.  Mutation is unsupported.  This is an explicit relational projection
boundary, not a replacement for a rich/native JSON document model.

## v0.74 — native ooRexx SQLite binary storage and GeoPackage transport

v0.74 removes the runtime C/SQLite dependency from the GeoPackage provider.
NoSQLServer now reads SQLite 3 database files directly in ooRexx and projects
those decoded rows through the existing relational engine.

The storage layer is deliberately below SQL. `.SQLiteNativeDatabase` decodes
SQLite pages, b-trees, varints, record headers, serial types and overflow
chains; `.SQLiteDatabaseEngine` exposes ordinary rowid tables as read-only
NoSQL relations; `.GeoPackageDatabaseEngine` adds GeoPackage catalog and typed
geometry semantics on top. No second SQL parser or evaluator was introduced.

The native reader is page-oriented. It reads the 100-byte SQLite file header,
then fetches individual database pages with absolute `CHARIN` offsets rather
than loading the complete database into one Rexx string. Supported storage
surfaces include:

- SQLite page sizes from 512 through 65536 bytes, including reserved bytes
- table b-tree interior (`0x05`) and leaf (`0x0d`) pages
- SQLite 1..9 byte varints and signed 64-bit rowids
- record serial types NULL, signed integers, IEEE-754 REAL, TEXT and BLOB
- INTEGER PRIMARY KEY rowid aliases
- table-level primary-key metadata
- payload overflow-page chains
- UTF-8 database text encoding
- ordinary rowid tables discovered directly from `sqlite_schema`

`.SQLiteNativeBlob` preserves BLOB bytes as a binary object and exposes hex
only at a requested string/projection boundary. The GeoPackage provider
promotes only the declared geometry column into `GeoPackageGeometry`, retaining
the original GeoPackageBinary bytes, geometry type and SRID.

The old `GeoPackageDatabaseEngine~new(path, bridge)` second argument remains
accepted so existing v0.67+ callers do not break, but it is now inert. v0.74
never shells to it. `tools/gpkg_bridge`, `tools/gpkg_bridge.c` and
`tools/build_gpkg_bridge.sh` are not present in the release.

New capabilities:

- `SQLITE_NATIVE_BINARY_READ`
- `SQLITE_NATIVE_RELATION_PROVIDER`
- GeoPackage storage identity `SQLITE_GPKG_NATIVE_READONLY`
- generic SQLite storage identity `SQLITE_NATIVE_READONLY`
- access paths `GEOPACKAGE_NATIVE_SQLITE_SCAN` and `SQLITE_NATIVE_SCAN`

The intentionally explicit current boundaries are also part of the contract.
The native reader does not mutate SQLite files, replay WAL/journal state,
execute SQLite bytecode, expose virtual tables, read `WITHOUT ROWID` table
payloads, or decode UTF-16 database text. `WITHOUT ROWID` is detected and
reported as a storage error rather than being misread as an ordinary table.
These are future storage surfaces, not guessed compatibility claims.

`tests/v074_sqlite_native_smoke.rex` exercises a 512-byte-page fixture with an
interior b-tree, 400 rows, 64-bit signed extremes, IEEE-754 REALs, NULL, UTF-8,
BLOBs, TEXT/BLOB overflow payloads, composite primary-key metadata and a
`WITHOUT ROWID` rejection boundary. The same test opens the bundled GeoPackage
with a deliberately nonexistent bridge path and successfully queries it,
proving that the compatibility argument is not executed.
