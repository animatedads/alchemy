# Adversarial review brief — Legal Effect v0.6 verification/promotion boundary

Attack v0.19 as an authority boundary, not as a happy-path integration demo.

## Required attacks

1. Certificate omits one live source verification evidence item.
2. Certificate contains an extra verification snapshot not present in the generation closure.
3. Duplicate verification evidence IDs in certificate snapshots.
4. Source evidence subject kind changed to PROVISION.
5. Provision evidence parent source changed after binding.
6. Evidence expected digest differs from source/provision identity digest.
7. Evidence actual digest differs from expected digest while `verified=true` is forged.
8. Evidence representation/locator changed without changing digest.
9. Verifier ID changed after compilation.
10. Verification timestamp changed after compilation.
11. Live evidence and certificate snapshot disagree in only one field.
12. Source/provision verification object is replaced after compilation.
13. Retained native source object mutates after verification.
14. Retained native source object throws on STRING.
15. Native object has misleading display text but unchanged verified representation.
16. Provision parent evidence points to a different source with the same bytes.
17. Same source bytes under a different expression ID.
18. Same source bytes under a different locator/representation.
19. Manually sealed generation with no certificate.
20. Caller asserts VERIFIED but supplies no verifier evidence.
21. Certificate object has the right-looking class name but missing public contract methods.
22. Cross-package class-name collision for certificate/snapshot classes.
23. Compiler certificate input identity changes during evaluation.
24. Generation/action/context changes during evaluation.
25. Reversed ungrouped REVIEW + REQUIRES_OBLIGATION norm order.
26. Same semantic identity but different execution fingerprint.
27. Suppressed prohibition appears as effective promotion basis.
28. Resolved authority rule is omitted from basis.
29. Unresolved conflict accidentally mints BLOCKED/PERMITTED authority.
30. SQL SELECT applies promotion as a side effect.
31. SQL UPDATE mutates an existing promotion.
32. PREPARE/FETCH re-enters the promotion provider.
33. XML business evidence is flattened before Legal Effect.
34. XML legal source node is flattened and native path lost.
35. X12/XML business conflict resolves by arrival order.
36. Verification snapshot `sourceObject` is mistaken for currently verified content after drift.
37. Expected digest provenance/trust is silently assumed authoritative.
38. Digest-provider identity is confused with legal authority.
39. Runtime Registry evidence, if later present, is allowed to replace compiler/source authority rather than
    complement it.
40. Two different verification representations hash the same lexical payload and are treated as identical
    provenance.

## Mutants to kill

At minimum mutate away each of: certificate evidence count check, parent-evidence check, expected/actual digest
check, live-vs-certificate comparison, verifier ID binding, representation binding, execution identity,
ambiguous-reducer refusal, effective/suppressed distinction, explicit promotion application, and NoSQL
read-only enforcement.

## Questions reviewers should answer

- Does v0.19 ever rely on mutable native object state for authority identity?
- Can a verifier snapshot be substituted without changing promotion identity?
- Is the distinction between `semanticIdentity` and execution-observable order still necessary in v0.6?
- Is every authority-bearing fact traceable to a compiler certificate and exact verification evidence?
- Are authoritative retrieval, verifier trust roots and signed publication attestation still clearly outside the
  claims made by this package?
