# Adversarial review request — v0.16 structured-source rich-evidence bridge

Review this as an evidence/identity boundary, not as an XML parser review.

The core claim is:

> An externally owned rich structured-source fact can cross into Algorithm Relation / HardWorld while preserving native object identity and provenance; deterministic identity comes from an explicit canonical evidence contract; SQL flattening occurs only at a deliberate scalar projection boundary.

Please attack at least the following.

## Identity / provenance

1. Can two materially different source objects produce the same canonical evidence identity?
2. Can absolute-path relocation create inappropriate cache misses or, conversely, hide source identity?
3. Is hashing source bytes + parser name sufficient, or must parser implementation/source manifest also participate?
4. Are processing-event timestamps correctly excluded from semantic identity, or can event time be decision-relevant?
5. Can annotations change after capture and mutate identity/output?
6. Can the original projected row mutate after capture while the frozen context remains stable?
7. Does preserving the runtime object create hidden dependence on object lifetime/closed documents?

## No-flattening boundary

8. Find any path that calls native source `STRING` implicitly.
9. Can diagnostic/detail/history objects trigger hidden display coercion?
10. Can a `RICH_OBJECT` reach NoSQL/MySQL as VARCHAR through any fallback mapping?
11. Can nil/empty/multi/invalid states collapse to one SQL NULL state prematurely?

## Cross-format combination

12. Is `combineFacts()` truly bag/order independent?
13. Are duplicate identical source facts preserved as multiplicity?
14. Does `PRESENT` for two equal values accidentally imply corroboration/authority?
15. Is string equality sufficient for typed numeric/date/currency equivalence?
16. Can `50`, `50.0`, `050`, and decimal-typed `50` produce dishonest conflicts/equivalence?
17. Should conflicting lexical values with equal typed values remain a separate evidence state?
18. What should happen when one source is INVALID and another is PRESENT?
19. What should happen for mixed consistency grades across source facts?

## Source package trust

20. The bridge is duck typed. Can a malicious object lie about `sourceProvenance`, parserName, sourceText, path, or semantic type?
21. Should the structured plugin's source manifest/fingerprint become part of the evidence identity?
22. Is document SHA-256 enough when namespace bindings, partner profile, validation rules or mapping definitions affect projection?
23. Should mapping/projection definition identity be stronger than relation name alone?
24. Can source validation findings exist at document level but fail to ride on the individual fact?

## HardWorld separation

25. Verify no evidence state or source type is implicitly promoted to authority.
26. Can an annotation such as `hardworldRule=...` be mistaken for an executable HardWorld rule?
27. Should promotion itself produce a separate provenance relation/object recording policy id, authority and source evidence identity?

## Required response

Please return:

- blocker / should-do-next / defer classification;
- a closure table covering every output-affecting structured-source artefact/object;
- at least 40 adversarial cases;
- at least 30 mutation proposals;
- a proposed typed equivalence model for cross-format scalar comparison;
- a recommendation on whether promotion should become its own first-class Algorithm Relation / HardWorld object.
