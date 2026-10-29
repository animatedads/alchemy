# Plan42 ↔ Alchemy ↔ RX2CPP: accepted boundaries

## Responsibilities

- Application semantics: inspectable ooRexx objects, methods, intentions and services.
- Plan42: semantic/portability compilation requests and generated ooRexx source with hashes and compatibility receipts.
- RX2CPP: interpreter-derived object inventory, `RxWhenDealingWith` code-unit scope, common rule resolver and qualified native C++ lowerings. Compiler itself is authored in ooRexx.
- Alchemy Semantic Source Store/Runtime Registry: ownership of accepted revisions and generations, not usurped by compiler plans.

## Dev6 incremental evidence (2026-10-29)

`plan42.native.plan` rejects generated-source and receipt paths with symlinked ancestors or traversal. The compiler checkout must have all seven required interfaces identical to Git HEAD and a clean visible `oorexx2cpp` subtree; changed rules and untracked compiler helpers refuse a native build proposal. 66/66 scoped Python tests pass. There is no live ooRexx execution, C++ build, interpreter-parity, service deployment, CODELET:DEFINE or registry publication claim.

The original compiler pin is still `9047f0e` (2026-10-15). An observed later RX2CPP head is not an automatic authorisation to repin. The 2026-10-29 GitHub `oorexx` main head was `1fd2193` (2026-10-29); it is an observation, not an accepted baseline.

## Constraints and operational priorities

- Hosted/native routes are distinct: they cannot be silently conflated.
- Do not allow the Plan42 scope inventory to become a parallel ooRexx parser.
- The downstream source must not be admitted as a native binary before ooRexx/GCC/Clang differential acceptance and rollback/load-order tests.
- The website, mail, LDAP, HTTPS and XTP MU↔MI estate remain independently owned and are **not** qualified or deployed by this Plan42 delivery.
- Autobuilder was reported stopped on October 29: source publication is direct and versioned, not evidence of an Autobuild receipt.
