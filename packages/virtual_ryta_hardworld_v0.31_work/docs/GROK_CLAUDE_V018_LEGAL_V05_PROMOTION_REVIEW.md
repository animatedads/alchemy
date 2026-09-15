# Grok / Claude adversarial review — Legal Effect v0.5 promotion boundary v0.18

Attack the following claims rather than reviewing style.

1. A manually sealed but uncertified `LegalRuleGeneration` can never mint an AUTHORIZED promotion.
2. A caller-created `verificationState=VERIFIED` identity cannot pass the v0.5 authority boundary.
3. Mutating source/provision bytes after verifier issuance cannot be laundered into a newly compiled legal
   generation without an identity change or verifier failure.
4. Compiler certificate identity is bound independently of legal semantic identity.
5. Cross-package certificate class-name confusion cannot bypass or incorrectly reject the public certificate
   contract.
6. Same semantic graph + different evaluator-observable order gets a different execution identity.
7. Reversed ungrouped REVIEW/REQUIRES_OBLIGATION generations remain fail-closed even when semantic identities
   are equal.
8. An effective permission that defeats a prohibition does not leave the suppressed prohibition as controlling
   promotion basis.
9. The exact controlling `LegalAuthorityRule` survives into normalized promotion basis.
10. Unresolved authority conflicts cannot become BLOCKED/PERMITTED merely because one norm arrived first.
11. Mutation of generation/action/context during evaluation is detected before an authority envelope is issued.
12. Opaque evidence without an explicit canonical contract cannot enter authority closure by falling back to
    `STRING`.
13. SQL SELECT/PREPARE/FETCH over promotion relations never applies a promotion.
14. NoSQLServer mutation attempts remain `SQLUNSUPPORTED` and cannot rewrite promotion status.
15. Duplicate/conflicting promotions retain the existing HardWorld conflict behaviour.
16. Structured Relation v0.7 native XML/X12 objects remain reachable after legal evaluation and promotion.
17. Business-source evidence and legal-source verification identities cannot be accidentally conflated.
18. Certificate `compiledAt` or verifier wall-clock provenance does not accidentally destabilize semantic
    identity where the canonical contract intentionally excludes it.
19. A dishonest object implementing certificate-like methods cannot obtain publication eligibility unless the
    actual generation was certified by Legal Effect's compiler authority token.
20. A future Legal Effect API change which starts observing metadata/order not included in v0.18's closure must
    fail tests rather than silently preserve old authority identity.

Suggested mutants:
- delete `publicationEligible` gate;
- replace cryptographic verification check with `verificationState == "VERIFIED"`;
- remove certificate hash from generation canonical text;
- remove execution identity;
- sort norm order inside execution fingerprint;
- use `afterMatches` rather than `effectiveMatches` for basis;
- add suppressed norm as controlling basis;
- remove resolved authority-rule basis;
- allow `STRING` fallback for opaque evidence;
- make SELECT call `EvidencePromotionApplier`.
