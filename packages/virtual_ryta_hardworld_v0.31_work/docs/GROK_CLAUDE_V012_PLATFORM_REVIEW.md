# Virtual RYTA / HardWorld v0.12 — NoSQLServer v0.69 / msqlshim v0.10 adversarial review

## Mission

Attack the new platform boundary.  Do not re-review the already-frozen HardWorld rule language unless a platform behavior can violate it.

Try to disprove:

> Metadata/protocol operations cannot accidentally execute or re-execute a read-only deterministic Algorithm Relation.

## Claims to attack

C1. Missing host transport classes fail binding before provider execution.

C2. No global `.DatabaseTableMetadata` or other NoSQLServer public-class lookup remains in the external adapter.

C3. `databaseCore()~relationalSource~tables` does not execute the provider.

C4. `tableSource~metadata` and `~describe` do not execute the provider.

C5. First `tableSource~rows` executes at most once.

C6. Reading a second relation from the same Algorithm Result does not execute again.

C7. `COM_STMT_PREPARE` never executes the provider, including two prepared statements over two relations from one provider.

C8. `COM_STMT_EXECUTE` with a read-only cursor materialises at most once.

C9. Arbitrarily many `COM_STMT_FETCH` calls never re-enter the backend/provider.

C10. Cursor reset/re-execute recreates protocol cursor state without forcing a fresh Algorithm Relation execution.

C11. Cursor close / connection reset cannot corrupt the underlying Algorithm Relation materialisation identity.

C12. Two concurrent prepared statements on one connection cannot cross-contaminate cursor state or cause duplicate provider execution.

C13. Two concurrent connections cannot cause duplicate first materialisation of the same lazy external-engine instance.

C14. Prepared result metadata type changes cannot coerce Algorithm Relation values silently.

C15. A DB-Core namespaced class collision cannot cause the adapter to instantiate the wrong metadata/row/result class.

C16. `LIMIT 0`, `WHERE 1=0`, EXPLAIN-like metadata operations and prepared metadata probes do not become covert execution paths.

C17. A prepared cursor over relation A and ordinary SQL over relation B still share one provider materialisation.

C18. Errors/cancellation while fetching cursor rows cannot mark a non-executed provider as executed or vice versa.

C19. Rebinding msqlshim to a newer NoSQLServer does not require algorithm-specific shim logic.

C20. Database Core facade values such as `PROHIBITED` remain data and do not acquire transport-level authority behavior.

## Required adversarial corpus

Provide at least 35 cases, including:

- missing each host class-set member separately;
- deliberately wrong-but-callable host class objects;
- two package namespaces exporting the same public class name;
- prepare two relations, execute in reverse order;
- prepare without execute then disconnect;
- execute cursor then fetch 1 row repeatedly;
- fetch zero rows;
- fetch past exhaustion;
- reset before first fetch;
- close before first fetch;
- reset then re-execute repeatedly;
- two open cursors from one provider;
- two clients racing first execute;
- metadata request while first materialisation is guarded;
- provider error during cursor execute;
- client disconnect during provider materialisation;
- client disconnect after materialisation before fetch;
- query/metadata schema drift between prepare and execute;
- source-manifest drift between prepare and execute;
- input drift between prepare and execute;
- prepared action relation plus text-protocol trace query;
- text-protocol action relation plus prepared trace cursor;
- DB-Core `describe` before and during materialisation;
- row-count/cardinality requests before materialisation;
- LIMIT 0 / WHERE false / empty projection probes;
- binary BOOLEAN/INTEGER/DECIMAL/TEXT/OID values;
- NULL values through binary rows;
- cursor reset after provider materialisation;
- server-side statement ID reuse after close;
- COM_RESET_CONNECTION with materialised Algorithm Relation;
- table removed/rebound after prepare;
- host metadata class changed after external engine construction;
- malicious `TABLE_METADATA` class returning incompatible metadata;
- msqlshim FIFO gate fairness with a slow first Algorithm Relation materialisation;
- a second unrelated client reading an already-materialised Algorithm Relation while first client fetches slowly.

## Required mutants

Provide at least 25 mutants.  High-value examples:

M1 remove `TABLE_METADATA` from required class-set validation;
M2 restore global `.DatabaseTableMetadata~new`;
M3 make DB-Core `describe` call `rows`;
M4 make table row-count probe materialise;
M5 make PREPARE run SELECT for metadata;
M6 make every FETCH re-run SELECT;
M7 make cursor RESET request FRESH execution;
M8 make second relation use a separate Algorithm Relation engine;
M9 remove lazy first-read guard;
M10 release guard before materialisation commits;
M11 cache only one provider relation;
M12 clear Algorithm Relation materialisation on statement CLOSE;
M13 tie materialisation identity to MySQL statement ID;
M14 tie materialisation identity to connection ID;
M15 coerce BOOLEAN to TEXT in binary cursor only;
M16 omit source-manifest recheck at first execute;
M17 omit canonical-input recheck at first execute;
M18 allow missing DATABASE_ROW class to fall back globally;
M19 let prepared metadata invent nullable/type information;
M20 make DB-Core relation discovery call `rowCount` and then execute on unknown count;
M21 make protocol cursor retain backend gate across FETCH;
M22 make cursor fetch ask NoSQLServer for the next page instead of using materialised rows;
M23 allow provider side effects behind prepared SELECT;
M24 materialise independently for `ryta_actions` and `ryta_trace`;
M25 treat `COM_STMT_PREPARE` as an audit invocation that changes materialisation identity.

## Desired verdict

Classify findings as BLOCKER / SHOULD_DO_NEXT / DEFER / REJECT and distinguish:

- Algorithm Relation semantic defects;
- NoSQLServer facade defects;
- msqlshim protocol/cursor defects;
- package/class-namespace binding defects.
