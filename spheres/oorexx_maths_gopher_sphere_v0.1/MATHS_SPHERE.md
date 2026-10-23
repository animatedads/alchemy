# ooRexx Maths Gopher sphere

**Sphere identity:** \`maths\`  
**Documentation revision:** 0.2  
**Current executable baseline:** ooRexx Maths v0.19  
**Baseline archive SHA-256:** \`cf92eac71498450fb688569328833b33b122942de89450a4022d9d824c778f40\`

This sphere is the continuity and architecture authority for ooRexx Maths. It documents the mathematical contracts and evidence boundaries that must survive implementation changes; it does not replace the executable package.

## Current shape

Maths is now both a numerical mathematics system and the beginning of a general mathematical object system. The public contract preserves exact domains, explicit precision transitions, provider-neutral numerical execution, claim/proof separation, revision-bearing theorem evidence, and executable algebraic structures.

The v0.18 theoretical foundation added finite sets, maps and relations; finite operations, monoids, groups, rings and fields; group homomorphisms; mathematical statement classes; revision-bound proof artifacts; theorem lifecycle states; and a version-retaining theory catalogue.

The v0.19 exact-algebra increment added the rational field, exact univariate polynomial rings over Q, formal differentiation and Horner evaluation, Euclidean quotient/remainder and gcd, finite-dimensional rational vector spaces, and exact linear maps/composition.

These are generic mathematics. Physics, Rexx-tronics, ML, graph and other consumers retain their own domain semantics.

## Proof and authority rules

A mathematical result is not established merely because two floating-point providers agree. Exact equality, numerical reproduction, enclosure, independent checking and formal proof are different evidence classes.

A proof artifact is admissible only for the exact statement identity and revision it names. Revisions do not silently inherit proof. \`PROPOSED\`, \`PROVED\`, \`INDEPENDENTLY_CHECKED\`, \`FORMALIZED\`, \`DISPROVED\`, \`SUPERSEDED\` and \`WITHDRAWN\` are distinct lifecycle states. Research/manuscript catalogues may be imported as claims and provenance, never as unquestioned mathematical truth.

## Current qualification

The v0.19 delivery was freshly qualified under ooRexx 5.3.0 r13196: 489 core/reference/RxMath assertions and 177 enabled Foreign Runtime/provider assertions, for 666 fresh PASS assertions. The standards gate reported zero errors and default PASS with 134 reviewed warnings. FLINT-ARB remained a capability skip because python-flint was absent. Crypto sealing remained \`NOT_RUN\` because the exact Crypto/Runtime Reference executable closure was not present; historical results were not promoted into the current receipt.

## Continuation

The next mathematical layers should extend the same executable object model rather than add decorative taxonomy: modules/submodules and ideals; rational functions and quotient constructions; polynomial factorisation; algebraic extensions and algebraic numbers; sequences, limits and convergence; metric/topological spaces; measure/probability; broader theorem-aware named constants and special functions; and formal-system adapters (Lean first) whose receipts remain bound to exact statement revisions.

Provider acceleration remains implementation, never mathematical authority. Workload-aware selection is required: bridge overhead can make tiny native jobs slower than pure ooRexx, while larger linear/state-space workloads benefit substantially.

## Coordination note

The project catalogue exposes component \`sphere:maths\`. At this documentation update it had no recorded owner. This session could inspect it but could not write a coordinator ownership lease because the coordinator requires an authenticated HTTPS principal. GitHub changes therefore use the current repository head and conflict-safe commit/ref checks instead of claiming a lease that does not exist.
