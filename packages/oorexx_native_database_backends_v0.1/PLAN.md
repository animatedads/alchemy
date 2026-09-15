# Native database backend plan

1. **Common contracts first** — capability/limitation/requirement publication, deterministic selection and pinned leases.
2. **PostgreSQL native primary** — libpq via Foreign Runtime; retain DatabaseProcessCommandExecutor as fallback.
3. **PostgreSQL structured results** — replace compatibility text framing with a Database Core native-result adapter once the common core exposes that seam.
4. **PostgreSQL feature increments** — prepared parameter protocol (`PQexecParams`/`PQsendQueryParams`), cancellation, async polling, COPY, pipeline mode; advertise each only when implemented and qualified.
5. **GIS formalization** — wrap the existing pure-ooRexx direct-reader as `OOREXX_NATIVE`; keep it as the portable/no-library baseline. Add an optional Foreign Runtime acceleration backend later and publish any extra pushdown/spatial-index/vectorization capabilities rather than replacing the Rexx implementation.
6. **MySQL/MariaDB outbound native** — client C API through Foreign Runtime after the PostgreSQL ownership/error model is stable; retain the existing process/client fallback. This is separate from `msqlshim`, which is an inbound MySQL server personality.
7. **Qualification matrix** — every implementation publishes implementation identity, library/ABI/runtime identity, supported/unsupported/conditional/unknown capabilities, limitations, evidence, concurrency model, security features and fallback rules.
