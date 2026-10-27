# Vanishing Dinner — synthetic Reasoned Thought countermodel benchmark v0.2

A **synthetic**, public-safe ooRexx 5.3 countermodel fixture. This is *not* the authoritative Alchemy Reasoned Thought or EvidenceCombiner engine.

The key invariant is **silence is not contradiction**. An admitted observation about a previously unmodelled field must not eliminate otherwise viable worlds; an explicit incompatible value in a modelled field must still eliminate that world. An empty survivor set is a model/evidence conflict, never proof of arbitrary conclusions.

- WorldEnsemble.cls: implementation by ChatGPT GPT-6 (v0.1), open-world repair by Claude Opus 4.8 (v0.2).
- test_vanishing_dinner.rex: 39 original checks (payment authorization vs settlement; source roots; intent; search scope; evidence contradiction).
- test_silence_openworld.rex: Claude's seven new falsifying regression checks, shown failing on unmodified v0.1 and passing after repair.
- run.sh: native portable runner. Execute: REXX_BIN=/path/to/rexx sh run.sh. It sets its own REXX_PATH.

**Limits:** the world list is never assumed exhaustive; ADMITTED and VERIFIED are synthetic caller assertions, not authentication; sourceRoot is caller-supplied; neither a test pass nor a constructed world certifies external truth. No probabilistic, legal or investigative determination is made.

No personal data or real-case evidence included. The suite is deliberately kept outside the core engine's qualification gate.
