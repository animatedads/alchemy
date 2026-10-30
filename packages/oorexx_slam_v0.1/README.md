# ooRexx SLAM v0.1 — Small Language Autonomous Model (first cut)

**Architecture:** Tom Dyer.
**Coding:** Claude (Opus 5.5), 2026-10-28.
**Lexer:** the rx2cpp compiler's `RxLexer`/`RxToken`, vendored unmodified (rx2cpp lane: ChatGPT and Claude), see `vendor/rx2cpp/PROVENANCE.md`.
**Database:** SQLite through Rexx/SQL 2.6B3 (Mark Hessling) via `oorexx_rexxsql_backend_v0.1`.
**Corpus:** the circular corpus is Tom Dyer's; `i`, `am`, `me`, `my` added by Claude (Opus 5.5).
**Reviews that shaped it:** ChatGPT (four letters to SLAM), Claude (Fable 5.1), Claude (Opus 4.8).
**Finds credited to SLAM:** the Rexx/SQL bound-call leak, `rx_mod_inverse`'s missing condition, `FDSqrt` above 10⁶ (all three now fixed), and Federation Bank's Java side describing the bank's old late-advice rule (reported, not fixed); see "Credits for SLAM's finds".
**Languages:** ooRexx, NetRexx, Java and C++, since the polylingual experiment (Tom Dyer's, 2026-10-28; the readers for the other three, and the rule reader, by Claude (Opus 5.5)).

SLAM does not learn word tokens. Its vocabulary is **logic segments**: pieces of real ooRexx identified by
shape, the way an object in an image is identified regardless of where it sits or what colour it is. Every
segment is a node. Every "this segment followed that one" is an edge. Tests and runs put a score on the
edge, so a node's score depends on which node it was entered from.

## What is in v0.1

| File | Role |
|---|---|
| `src/SlamSegmenter.cls` | Code units (from directive boundaries), clauses, IF/DO/SELECT nesting, segments, shapes |
| `src/SlamStore.cls` | Node store in its own SQLite file: shapes, units, instances, edges, weights, anchors, tasks, turns |
| `src/SlamTask.cls` | `Task`: requirement → step → best path over weighted edges; `turn` and `run` |
| `src/SlamGround.cls` | Grounding: maths/statistics words anchored to tested ooRexx code; `ask` |
| `src/SlamContract.cls` | Contracts: what a unit NEEDS (argument kinds, messages, guards) and GIVES (return kind), its effects, pure/standalone |
| `src/SlamCompose.cls` | Lift standalone routines, check each link against contracts before running, run, keep every result as a lesson |
| `src/SlamJava.cls` | Second language: Java lexer, unit splitter (methods, constructors, initializers by class), statement parser and shaper, into the same segment kinds |
| `src/SlamCpp.cls` | Third language: C++ lexer (preprocessor lines dropped, raw strings), splitter (namespaces, `Class::m` outside its class, macro-made `NAME(X) { }` and `NAME(type, name, (params)) { }`, `operator>>`, conversion operators, `f<T>`), shaper; Java's statement parser; C is read with it |
| `src/SlamNetRexx.cls` | Fourth language: NetRexx, written as ooRexx tokens (`a.b` is `a~b`, `this` is `self`, `null` is `.nil`, `loop` is `DO <LOOP>`), read by the ooRexx parser and shaper |
| `src/SlamLanguages.cls` | Which reader a file needs, by extension; a file with none is C++ when its first line says so (libc++'s `<vector>`) |
| `src/SlamFold.cls` | Identical code folding over the store, ported from BOLT's IdenticalCodeFolding: congruent buckets, identical folds, repeated to a fixpoint; units skipped at ingest as the same text are aliases (pass 0) |
| `src/SlamRules.cls` | Rules read the same way in ooRexx and Java (what a GUARD makes MUST hold); keyed readers found by behaviour; RULE nodes; predicting a rule's outcome |
| `bin/slam.rex` | `ingest` (ooRexx and Java), `corpus`, `read`, `facts`, `about`, `ground`, `ask`, `stats`, `node`, `follows`, `into`, `record` |
| `README_SLAM.md` | This README in SLAM's own words: SLAM reads it with no unknown word |
| `corpus/` | The circular corpus plus closure, grounding-distance and sentence checks. `communications_corpus.csv`: 56 words the letters to and from SLAM needed (who, why, answer, check, pass, fail, thank...), each defined only in words SLAM already has; `speak_check.rex` checks a letter against any list of word files |
| `reference/` | The ooRexx 5 reference (rexxref) as facts in SLAM's words, with 1,167 examples run on ooRexx 5.3.0: see `reference/README.md` |
| `tests/test_slam.rex` | 58-check qualification |
| `tests/test_compose.rex` | ChatGPT's task on real estate routines, 6 checks |
| `tests/test_needs.rex` | Ability before score on real contracts (rule proposed by Claude (Opus 4.8)), 13 checks |
| `tests/test_modinv.rex` | `rx_mod_inverse` before/after/check harness (16 checks in CHECK mode) |
| `tests/test_choose.rex` | SLAM chooses its own path from 71 standalone routines (8 checks) |
| `tests/test_fdsqrt.rex` | `FDSqrt` before/after/check: small and large data through three ways (34 checks in CHECK mode) |
| `src/SlamProof.cls` | PROVED, DISPROVED or INDETERMINATE: certificates checked in exact rationals (ooRexx Maths v0.8, CERTIFIED route, pure ooRexx); each answer is a Maths `MathProof` |
| `src/SlamProvenance.cls` | Which tool wrote each unit: HEADER, PROVENANCE, GIT (blame per line), README, else NOT_RECORDED |
| `src/SlamReasoning.cls` | SLAM's evidence as Reasoned Thought grounds (tier + binding); decisions SLAM acts on (`mayAct`) |
| `src/SlamLaw.cls` | Legislation → small model → SLAM → Reasoned Thought: rule and guidance files, their gates, elements as claims |
| `src/SlamLegislation.cls` | Reads legislation.gov.uk XML (CLML) in pure ooRexx: a section's text as it stands in one extent |
| `tests/test_reasoning.rex` | The bridge on `FDSqrt`, authorship and a model's statement (16 checks) |
| `tests/test_law.rex` | Computer Misuse Act 1990 s.1 and s.3ZA, the CPS guidance, three made-up cases, the citation gate (43 checks) |
| `tests/law/source/MANIFEST_LEGISLATION.md` | Seven Acts attached by Tom: SHA-256, bytes, valid-from date, each candidate section's extent. Only the Computer Misuse Act's XML is committed here; CODEX-PC owns the copies in `law/` |
| `src/SlamScreen.cls` | One case (offence-event JSON, read with ooRexx's `json.cls`) screened against every rule pack, per extent, event and person |
| `tests/law/VOCABULARY.md` | The shared word list (law.kinds 0.2): 42 kinds, each an event or a finding, defined in SLAM's words; gate 6 |
| `src/SlamNswLegislation.cls` | Reads NSW legislation XML (Parliamentary Counsel exchange format): a section's text, the version's dates, and each section's history notes, for what was the law on a date |
| `tests/test_screen_people.rex` | Who did it, and what does not show it: Mr H's cheque, Mr M's tile, his previous convictions refused, his two interviews DISPUTED; NSW ss.33 and 35 for a deliberate throw (13 checks) |
| `src/SlamWords.cls`, `bin/words.rex` | The word loop: a round of words for one intention. Load what is said, list the words SLAM does not know, enter definitions, review how each one links to the words SLAM knows, accept into the shared list (`corpus/law_words.csv`), load again |
| `tests/test_words.rex` | The word loop: the same missing words as SLAM's reader; three turns on a made-up account (20, 18, 4, then none missing); each refusal; the writer can not accept their own words; "false" or "false [legal]", asked at entry and corrected in the input, with nothing replaced twice (21 checks) |
| `corpus/senses.csv` | Second meanings, each a word of its own (`false-legal`, `act-law`), in the circular corpus's format so the reader loads it |
| `corpus/rounds/` | Each round: its ledger (JSON), the form of missing words, the definitions the sources write for themselves, each turn's definitions, the review sheet |
| `tests/test_screen_dates.rex` | The law on the date: the 2008 cheque and 2009 injury in E.W. and NSW; NSW Crimes Act ss.192E, 54, 33 and 35 (19 checks) |
| `tests/test_screen_uk.rex` | Fraud Act 2006 s.2, Theft Act 1968 ss.1 and 21 beside the CMA: the same events and evidence, three more rule packs (16 checks) |
| `tests/test_screen.rex` | Gate 6, the Mrs P case after her death, Computer Misuse Act ss.1, 2, 3ZA in E.W. and S. (31 checks) |
| `tools/migrate_case_v01_v02.rex` | ChatGPT's Mrs P case v0.1 to v0.2 (`docs/architecture/fixtures/`), every change listed |
| `tests/test_gemini_standard.rex` | Gemini's two refusals against its own answers, through the Reasoned Thought standard-application audit (7 checks) |
| `tests/law/` | Rule and guidance files, the official sources (XML, text, CPS guidance; Open Government Licence), `HOW_TO_WRITE_A_RULE.md` for the small model |
| `tests/test_provenance.rex` | Provenance on real files, a habit found by shape, outcomes by tool (19 checks) |
| `tests/test_ties.rex` | Gemini's two questions: the tie rule and the prior as one test (12 checks) |
| `tests/gemini_to_slam.md`, `tests/slam_to_gemini.md` | Gemini's letter and SLAM's reply (the reply reads with no unknown word) |
| `tests/test_proof.rex` | The PROVED tier on `FDSqrt` (now and before), `rx_mod_inverse` and the contract gate (18 checks) |
| `tests/fixtures/fdsqrt_fixed14.cls` | `FDSqrt` as it was before `3761f57c`, so its old results can be proved false |
| `tests/test_fdsqrt_door.rex` | The door code that calls `FDSqrt`: noise sigmas, pixel sigma, gradient size (17 checks on dev8, 15 on dev5) |
| `tests/fdsqrt_sweep.rex` | Old against new `FDSqrt` on random door-range values |
| `evidence/fdsqrt/` | The before and after data for the `FDSqrt` change, kept as ChatGPT asked |
| `tests/test_java.rex` | The Java reader: lexer, a javac-compiled fixture, the Federation Bank ATM, one store with both languages, Task on Java nodes (33 checks) |
| `tests/test_rules.rex` | One rule, two languages: the Federation Bank offline-cash rule in the ooRexx engine and the Java ATM, predicted then run (24 checks) |
| `tests/rules/` | `OfflineRuleProbe.java` runs the real Java ATM, `offline_rule_probe.rex` the real ooRexx bank, on the cases SLAM chose |
| `tests/test_cpp.rex` | C++: lexer, a g++-checked fixture, the interpreter's `BuiltinFunctions.cpp`, three languages in one store, BIF contracts from two C++ codebases predicted and run (29 checks) |
| `tests/bif/` | BIF contract reader for the interpreter and the rx2cpp native pack; case generator; a runner for each side |
| `tests/test_netrexx.rex` | NetRexx: lexer, `sysutils.nrx`, QTIME in NetRexx and ooRexx run through a day, NetRexx -> Java translation edges predicted on held-out files (20 checks) |
| `tests/netrexx/` | Runs NetRexx's `qtime.nrx` and ooRexx's `qtime.rex` at the same 206 times; translates every NetRexx example with NetRexxC and learns NetRexx -> Java translation edges (`translate_all.sh`, `translate_pairs.rex`) |
| `tests/test_llvm.rex` | Compiler code: BOLT read whole; next-segment prediction on held-out BOLT and on rx2cpp's ooRexx (7 checks) |
| `tests/llvm/next_node.rex` | Next-segment prediction at KIND, SKELETON and FAMILY level, with and without context, scored in SQL against a baseline |
| `tests/test_fold.rex` | Identical code folding on a fixture, on BOLT's source and on rx2cpp (11 checks) |
| `tests/test_libc.rex` | Runtime libraries: LLVM libc and libc++ read whole, predicted (each on itself and on the other) and folded (16 checks) |
| `tests/show_rules.rex` | Read a unit's rules, find the other language's closest units, list what both have and what each lacks |
| `src/SlamTestWriter.cls` | SLAM writes unit tests: cases from guards, contracts and the code's own strings and numbers, predicted where it can; ooTest groups and JUnit 4 classes |
| `tests/test_unit.rex` | The unit-test round: what SLAM learned of both frameworks, the groups and classes it wrote, mutation scores against random cases, the untested report on its fixture |
| `tests/unit/` | `learn_frameworks.rex`, `write_tests.rex` (ooTest), `write_junit.rex` (JUnit), `observe_runner.rex`, `mutate.rex`, `mutate_junit.rex`, `run_mutants.sh`, `run_junit_mutants.sh`, `run_jobs.sh` (the real ooTest runner on mutants), `mutant_runner.rex`, `score.rex`, `agree.rex`, `qualify.sh` |
| `bin/slam_untested.rex` | Which files and units no test reaches, read statically |
| `bin/slam_toy.sh`, `TOY.md` | SLAM's test tools in one command each, for a lane to run on its own tree |
| `tools/` | `bif_oracle_programs.rex` (interpreter-oracle BIF programs), `find_pool.rex` (standalone routines under a tree) |
| `src/BodySlamScanner.cls`, `src/BodySlam.cls`, `src/BodySlamReport.cls`, `bin/bodyslam.rex` | **Body Slam** (Tom Dyer's): the whole estate's links (requires, classes, uses, topics, declared dependencies) in a temporary SQLite database, resolved as ooRexx 5.3.0 resolves them; see `README_BODYSLAM.md` |
| `tests/test_bodyslam.rex` | Body Slam: 62 checks, each label proved by an interpreter run; the scanner against RxLexer |
| `run_tests.sh` | Builds Rexx/SQL and the foreign runtime, then runs everything |

### Segments (nodes)

A unit (method, routine or prologue) is cut into segments:

| Kind | What it is |
|---|---|
| ENTRY | `expose` / `use arg` / `parse arg` at the start of a unit |
| RUN | straight-line clauses that share data (a clause sharing no variable with the run starts a new one; `self` counts as shared) |
| GUARD | `if … then return / raise / signal / leave / iterate / exit` with no `else` |
| BRANCH, LOOP, BLOCK, SELECT, ARM | composites: own header plus the kind sequence of their children; each child is its own node. A SELECT's header includes its arms' conditions (shared roles, repeats collapsed), so a 3-arm and a 7-arm SELECT testing one value the same way are one node, and a SELECT testing a range is another |
| EXIT, TRAP, LABEL | a terminator; `signal on` / `call on`; a label |

**Shape** (the node's identity):
- Variables become roles by first occurrence in the segment: `A1..` argument, `F1..` exposed field, `L1..` local. The real names are kept on the instance as its *binding*.
- Strings become `S`, numbers become `N`.
- Consecutive clauses of the same shape collapse to one, marked `+`.
- FINE keeps message, function and class names. FAMILY abstracts them to `M`, `F` and `.C`.

Example, `MLGeneticPolicy~init` from the GA package:

```
ENTRY: use strict arg A1 = N , A2 = N , A3 = N , A4 = N
GUARD: if A1 < N | A1 > N then ; raise syntax N array ( S )     A1=MUTATIONRATE
GUARD: if A1 < N then ; raise syntax N array ( S )             A1=MUTATIONSCALE
GUARD: if A1 < N | A1 > N then ; raise syntax N array ( S )     A1=CROSSOVERRATE   (same node as line 2)
GUARD: if A1 < N then ; raise syntax N array ( S )             A1=ELITECOUNT      (same node as line 3)
RUN: self ~ M = A1 +                                             four setters, one node
```

### Edges and weights

- `edge(from, to, freq)`: how often `to` follows `from` in the source. This is the **PRIOR** tier: it means "common", not "works".
- `weight(from, to, trials, passes)`: recorded outcomes. This is the **TESTED** tier.
- An edge's rate is `passes / trials` when tested, otherwise `freq / outfreq(from)`.
- Its **score** is the Wilson lower bound (95%) of that rate over its count, so the amount of evidence counts: 1 of 1 scores 0.21 and 1,000 of 1,000 scores 0.996. This answers ChatGPT's review point that a single pass and a thousand passes scored the same.
- Search and ranking use the score: tier first, then score.

```rexx
store~record(aabb, eeff, .true)        -- one outcome on the edge aabb -> Eeff
d = store~rate(aabb, eeff)             -- d['TIER'] d['RATE'] d['TRIALS'] d['PASSES']
best = store~entriesInto(eeff)         -- best ways into Eeff
```

### Admitted execution (ChatGPT review, 2026-10-29)

`SlamComposer~run` remains an **exploratory** operation: even when its contracts predict a mismatch, it deliberately attempts the call to learn from the failure. Do not use it as a fail-closed execution boundary. The new `SlamComposer~admit(steps)` checks every `PREV` link, missing lifted units, and a first step incorrectly asking for a prior result. `SlamComposer~runAdmitted(steps)` returns `STATUS=BLOCKED` with an empty trace and no result when admission fails; only admitted paths execute. Contract completeness is not claimed: numeric relationships such as coprimality still require runtime checks or proofs. The existing exploratory test continues to exercise deliberate failure; four additional checks cover admission and valid execution. Run the package suite to qualify this change before using it in services.

### Task

```rexx
store = .SlamStore~new('slam.db')
t = .Task~new('make application for testing ga', store)
t~requirement('reach Eeff', startNode, eeffNode, 'TESTED', 12, 'BOTTLENECK')   -- tier, max depth, scoring
r = t~turn                 -- one action, one SQLite transaction, one TurnReport
r = t~run(100)             -- until DONE or BLOCKED
say t~nodeMap[1]~makeString('L', ' ')
```

Path scoring is chosen per requirement:
- **PRODUCT** (the default) multiplies the edge rates. Each rate is at most 1, so every extra edge can only lower the value, and PRODUCT therefore prefers short routes.
- **BOTTLENECK** scores a path by its weakest edge (the widest-path rule). Length doesn't count against it.

Best-first search is exact under both. `maxDepth` counts edges.

A route into a node is dropped only when another kept route there is at least as good *and* no longer. ChatGPT's review found that keeping one best score per node could discard the only route short enough for the depth limit. That bug is reproduced and fixed in test 13. `TESTED` admits only edges with recorded outcomes. `PRIOR` also admits frequency-only edges, and the path reports its weakest tier.

### Reading, grounding, asking

- **`read DB DOC`.** SLAM's vocabulary is the WORD nodes in its own database. A line `word: definition` whose word is new adds that word, but only if every word of the definition is already known (the word itself may appear). Everything else must be known words. Numerals count as values, not words. Lines inside code fences are code, not words.
- **`ground DB`.** Each procedural maths/statistics word (add, sum, count, mean, median, mode, range, variance, standard, deviation, square, squares, root, multiply, subtract, difference, divide) is anchored to a `SlamMaths` method. Each method is checked against known answers, 28 cases in all, and every check is recorded as an outcome on the edge word → code. That makes the anchor a TESTED edge.
- **`ask DB "SENTENCE | V1 V2 .."`.** Any unknown word is refused. Anchored words are applied right to left ("the X of the Y of the values" is X(Y(values))), and only anchors with a TESTED rate of 1 are run. "square root" and "standard deviation" read as one word, as the corpus defines them.

```
> get the square root of the variance of the values | 2 4 4 4 5 5 7 9
i do: root <- variance
the result is 2
> get the mean of the squares of the deviation of the values | 2 4 4 4 5 5 7 9
i do: mean <- squares <- deviation
the result is 4
> what is the average of the values | 2 4 4 4 5 5 7 9
some words here are not words i know: average
```

### Contracts and composition (ChatGPT's second task)

`SlamContractExtractor` reads, from the code alone, what a unit **needs** and **gives**:
- **Needs, per argument:** the kinds its use implies (arithmetic gives NUMBER, `||` STRING, `do … over` and collection messages COLLECTION, other messages OBJECT), the messages sent to it, and the guards it must pass (`if c then raise/return …` becomes `not(c)`).
- **Gives:** the kinds the unit can return.
- **Effects:** SAY, STREAM, COMMAND, ENV, DYNAMIC, STATE_WRITE, MUTATES_ARG, RAISES, CREATES, CALLS.

Uses of an argument inside `raise` or `say` imply no kind, because showing a value in a message is not a need. Without this rule, the fixed `rx_mod_inverse`'s error text made argument 1 look like it could be a STRING, and the gate let a STRING through. The needs test caught it. A unit is **standalone** when it is pure and uses only built-in classes. Across the estate, 77 routines are standalone with known kinds. All of this is lexical, the DOCUMENTARY tier.

`SlamComposer` lifts a routine's body into a `.Routine`, so nothing else in its file runs. It checks every link of a path against the contracts **before** running it ("a path must first be able to do the work"), runs the path, and keeps each result as a lesson with its prediction and reason.

`tests/test_compose.rex` is ChatGPT's task, step for step:

| Step | Result |
|---|---|
| Fit | `rx_pow_mod` (crypto) gives NUMBER and `_adbModInverse` (ADB) needs NUMBER. No file in the estate composes them. |
| New data, two checks | 12 runs over 4 primes with seeded random values. Every one has x·y mod p = 1, and a different path, `rx_pow_mod(rx_mod_inverse(b,p), e, p)`, gives the same y. |
| Break A | `rx_le_hex_encode` swapped in. The contracts predicted *"will fail: needs NUMBER, gives STRING"* before running, and the run failed there (Rexx 41.1). |
| Break B | A modulus sharing a factor with the value. The contracts said *can work*, and the run failed with "Integer has no modular inverse". That taught a need the code never stated, gcd = 1, which is kept as a lesson. |
| Kept | 15 lessons, 3 of them failures. The edge stands at 12/13. |

**Finding in crypto.cls (11 vendored copies, including `oorexx_crypto_v0.8.3`).** `rx_mod_inverse` has no check that an inverse exists:
- `rx_mod_inverse(0, 7)` silently returns **1**, which is wrong, because 0 has no inverse.
- Every other non-invertible input dies with *divide by zero* (42.3) instead of a clear refusal.
- `_adbModInverse` refuses all of these with "Integer has no modular inverse".
- On invertible input the two agree.

**Fixed in the repository (commit `1f422d76`).** Done as ChatGPT's third letter asked:
- It now checks its condition (modulus > 1, gcd(value, modulus) = 1) and raises "condition false" before it can return 1 or divide by zero.
- The gcd is the one its existing Euclid loop already computes, so the check costs nothing measurable: median 0.3258 s before against 0.3247 s after. A first version with a separate gcd loop was 2.9× slower and was rejected by the timing test.
- The change went into one copy first, then the other 11, each tested before and after. Valid output is byte-identical, and all invalid input raises "condition false".
- Callers: crypto v0.8.3 suite 16/16 and v0.1 suite 7/7, before and after. A mutation shows the Ed25519 and asymmetric tests reach the routine.

### Ability before score (rule proposed by Claude (Opus 4.8))

Code nodes carry their contract in the store (`contract` table). Three changes follow:
- **The gate.** `SlamPathSearch` asks `store~canRun(from, to)` before it reads an edge's score. An edge whose target needs a kind its source cannot give is **refused**, and the refusal and its reason go into the turn record. A node without a contract is not judged: the gate refuses only what it can explain.
- **Naming the reason.** A step that cannot be reached because of refusals reports `BLOCKED` with the reason, naming the node, the need, and the kind that was given instead.
- **Made edges.** `store~makeEdges(nodes)` creates an edge wherever one node gives what another needs, including pairs that are never adjacent in any code. A made edge has `freq` 0, so it has no prior and scores nothing until a test is recorded on it.

`tests/test_needs.rex` checks this on real contracts, 13/13:
- The hex route scores higher (0.72 against 0.49) but cannot run, so the search goes through `rx_pow_mod`, and the turn log shows the refusal.
- A goal reachable only through the hex edge is BLOCKED with the reason named.
- 9 edges are made, none of them from `rx_le_hex_encode`, because it gives STRING.
- The made edge `rx_pow_mod → rx_mod_inverse` is unused until 6 real runs pass (x·y mod p = 1 each time), and is then TESTED and used.

Opus 4.8's proposal also wrote this rule in SLAM's words. SLAM's reader refused that text over 16 word occurrences (`must`, `needs`, `only`, `why`, …), so the version in `README_SLAM.md` is a rewrite that SLAM reads clean, with `need` and `needs` defined. Every model that wrote to or for SLAM today has failed its reader at least once. Fable failed once, Opus 4.8 once, and ChatGPT once (its first letter passed, its second did not). I failed four times: `file`, six scoring words, `there`, and 13 words in my first reply to ChatGPT. The reader caught every one.

### SLAM chooses its own path (ChatGPT's third task)

`tests/test_choose.rex` gives SLAM no path:
1. It lifts the pool (61 routines lift; 38 take one argument) and reads each contract from the code.
2. It makes 359 edges, only where a give fits a need, and keeps 128 two-routine paths that cross files.
3. It probe-runs every edge on 7 values ("first test if each call can run").
4. It finds second ways: routines in other files with the same contract and the same probe output. It found `FDSqrt` (fd_door) ≡ `rx_vision_sqrt` (vision).
5. It takes the highest-scoring path that has a second way: `rx_le_hex_decode` (crypto) → `FDSqrt` (fd_door), score 0.42.
6. On 5 new values, 3 agreed with the second way and 2 did not. SLAM's `root` anchor (TESTED by grounding, and matching both routines on every probe value) decided both disagreements: **`FDSqrt` was wrong**. Since the fix (commit `3761f57c`) the same test shows all 5 agreeing.

**Finding in `fd_door_micro_motion` (fixed in `3761f57c`, next section).** `FDSqrt` ran a fixed 14 Newton steps starting from x. Its relative error was:

| x | Relative error |
|---|---|
| 10⁶ | exact |
| 10⁷ | 6 × 10⁻⁵ |
| 10⁸ | 8% |
| 10⁹ | 110% |
| 10¹² | 60× |

It computes standard deviations (`sqrt(m2/(n-1))`) and gradient magnitudes there.

### FDSqrt fixed (ChatGPT's fourth task)

ChatGPT wrote `FDSqrt` and set the method: "use small number data and large number data… keep each result, true or false. change FDSqrt so it can run on until the answer does not change. do not use a fixed count of steps." Every step below was done on scratch copies first (dev8, then dev5), and only then in the repository.

**The change** (both copies, `fd_door_micro_motion_v0.2-dev8` and `-dev5`):

```rexx
do forever
  next=(guess+(x/guess))/2
  if next>=guess then leave
  guess=next
end
```

The start (`x`, or 1 when `x` < 1) is never below the root, and from there every Newton step can only go down. So the loop ends at the first step that does not go down: the answer is unchanged, or one unit higher from rounding at 9 digits. It always ends, with no fixed count. 10⁶ takes 15 steps, which is why 14 was just short. 10¹² takes 25 steps and 10⁴⁰ takes 71.

**Data, before and after** (`evidence/fdsqrt/`, every result kept as a lesson, true or false):

| Check | Before | After |
|---|---|---|
| 16 small values (0.0004 … 10⁶) through FDSqrt, `rx_vision_sqrt` and SLAM's `root` anchor | 16 true | 16 true, same output character for character |
| 13 large values (10⁶+1 … 4×10¹⁸) | 1 true, 12 false (10⁸ → 10784.59; 10¹² → 61040618) | 13 true |
| `FDNoiseModel` global and door sigma, large steps | 9066.78 and 3457.71 (anchors 8663.13 and 3457.18) | equal to the anchors |
| `photometricStats` sigma (pixel values, so at most 255²) | true | same output |
| Gradient size `FDSqrt(gdx²+gdy²)`, e.g. (6000, 8000) | 10784.59 | 10000 |
| Noise sigma fed by those gradient sizes (the chain at line 2528) | 3.55×10⁹ (anchor 7.6×10⁶) | equal to its anchor |
| 200,000 random door-range values, old against new | | all identical |
| All 85 `FDSqrt` calls the door tests make (inputs 240 … 1573) | logged | same input, same output |
| Door suite, every test that runs here | dev8 9/15, dev5 7/10 pass | the same tests pass, with the same output |
| 3000 door-sized calls | 0.066 s | 0.052 s |

The door tests that do not run here decode video through the FFmpeg 7 bridge (`libavformat.so.61`); this machine has FFmpeg 6. They fail at the same `dlopen`, before and after. They need a run on a machine with FFmpeg 7.

What the data says about the door itself: its own inputs (pixel variances, frame steps, gradient sizes in pixels) stay far below 10⁶, so its past results were not changed by this bug. The bug was in the routine's promise, and SLAM broke it with data the door never sent.

An honest limit on the path SLAM chose: it feeds a decimal number to a hex decoder. The contract allows that, because a number is a valid string, but it means little. Kinds can say a path *runs*, not that it makes sense.

### Second language: Java

The experiment: can SLAM keep making progress when the code is in a second language? The language was chosen on the merits:
- **It is ooRexx's partner in the estate.** BSF4ooRexx is the Rexx–Java bridge, and Federation Bank runs a Java ATM (`examples/federationbank_java_atm_v0.1.9`) against an ooRexx engine (`examples/federationbank_engine_v0.9.1`). The same bank rules are enforced on both sides, in real code.
- **That covers business rules too.** A DRL or DMN file would have been synthetic: the estate has none.
- **Java declares types,** so SLAM's lexical contracts can later be scored against declarations rather than only stated.
- **It runs here,** so the TESTED tier works in the second language.

Not chosen: Python (no declared types; not ooRexx's partner). C++ was Tom's other idea, and it is the next language (see the end of this README).

**What changed.** Only the language-specific parts are new (`src/SlamJava.cls`). The segmenter got one additive hook (`otherSegment`), so a reader can add statement kinds that ooRexx does not have. ooRexx statements never reach it, and the 201 existing checks still pass. Store, edges, weights, Task, contracts and corpus are unchanged.

| Java | SLAM kind |
|---|---|
| the parameter list | ENTRY (Java has no `use arg`) |
| `if (c) return/throw/break/continue/yield …;` with no else (`{ }` around the one statement is unwrapped) | GUARD |
| `if`/`else`; `for`, for-each, `while`, `do`…`while`; `{ }`, `synchronized (x) { }` | BRANCH; LOOP; BLOCK |
| `switch`, each `case`/`default` an ARM | SELECT |
| `try`/`catch`/`finally` | TRY (Java's own kind; ooRexx has `signal on`, a TRAP leaf) |

Roles are as in ooRexx: parameters A, fields of the class F (a parameter of the same name hides the field), locals L. `true false null` render `.true .false .nil`, as ooRexx's do. Lambdas, anonymous classes and switch expressions stay inside the statement that holds them.

**On the estate.** All 165 Java files (84 distinct after the versioned Wire UI Swing copies) give 595 distinct units, 3,864 segment instances and 2,101 nodes, in 35 seconds, with no file skipped. On the fixture (compiled by javac in `run_tests.sh`), the GA test's result holds in Java: the range guard on two parameters is one node with two bindings, the one in `{ }` included.

**Shared without translation.** In one store with the Federation Bank engine, three nodes come from both languages unchanged: `EXIT: return A1`, `return F1`, `return L1`. An accessor is the same node in Java and ooRexx. Nothing was done to get this; it falls out of roles.

### One rule, two languages

Shapes keep each language's words (`if ( … ) ; continue` is not `if … then return …`), so they are not where the languages meet. Rules are. `SlamRules.cls` cuts a GUARD's condition at its top-level OR. Each atom is one reason to stop, and the rule is its negation, what MUST hold:

```
ooRexx  if rec["status"] <> "ACTIVE" then return .FederationBankResult~failure(...)   MUST EQ K:status S:ACTIVE   REJECT
Java    if (!"ACTIVE".equals(s(d,"status"))) continue;                                MUST EQ K:status S:ACTIVE   SKIP
```

Operands: `K:key` is a keyed read, written `rec["key"]` in ooRexx and `m.get("key")` in Java, or a call to a **keyed reader**. SLAM finds keyed readers by what they do: a unit taking (Map m, String k, …) that reads m with k, directly or through another keyed reader. In `AtmService` it finds `s` and `n`, and nothing else. `V` is a value given or held (its name kept as a binding), and `NOW` is the time now. The others are `S:`, `N:`, `NIL`, `B:` and `E:` (anything else). Conversions read as the same value: `~string`, `+ 0`, `String.valueOf`, one-argument `parse…` calls. `~upper` and `toUpperCase()` mark the value `^U`. A local assigned once from a keyed read or the time now is read through, and a local assigned twice is not. Each RULE is a node (`RULE: EQ K:status S:ACTIVE`). Each GUARD that stops on it gets a made edge GUARD → RULE with no prior, scored only by tests. This RULE node is where the languages meet.

**Federation Bank** (`tests/test_rules.rex`, 24 checks):
- **The ooRexx bank's rules.** `validateAdvice` (engine) gives 15 rules from 13 guards. Two hold only under an enclosing IF (the session and sequence checks), and a stop on `a & b` is one NOTALL rule.
- **Its Java counterpart, found by SLAM.** Of 80 Java units with rules in the ATM, the closest are `requestOfflineAllowance` (0.44), where the ATM checks the authority it is given, and `withdrawOffline` (0.36), where it checks it again before cash. Both are right.
- **8 rules are the same** in `validateAdvice` and `withdrawOffline`: status, terminal, customer, account, currency, ruleset, rules version, max amount.
- **Each difference located.** The amount-above-zero rule is not missing on the Java side. `withdrawOffline` has one caller, `withdraw`, which checks it at line 153 before the call at line 155. Expiry is only on the Java side (the ATM refuses expired authority; the bank looks at when the cash went out). Currency: the bank upper-cases the presented value (`^U`) and the ATM compares exactly.
- **Predicted, then run.** SLAM chose four cases from the differences and predicted each side's answer from the rules alone (`SlamRule~holds`). It predicted that the sides would differ on `gbp`. Then the real code ran: the ATM through `withdraw` offline on `DemoBankNetwork`, and the bank's `validateAdvice` loaded with its dependencies. **8 of 8 predictions held.** Each is a lesson on that language's GUARD → RULE edge, so the currency RULE node is now reached by a TESTED edge from each language.

| Case | ooRexx bank | Java ATM |
|---|---|---|
| amount = authority max | accepted | dispensed |
| max + 1 | refused | refused |
| 0 | refused | refused (in `withdraw`) |
| currency `gbp` against `GBP` | **accepted** | **refused** |

The currency split is safe in that direction (the ATM is stricter, and its account list comes from the bank in upper case). Whether the two sides should agree is a design call, not SLAM's.

**Late advice: the Java side describes the bank's old rule.** SLAM reads `DemoBankNetwork` (the Java ATM's test double for the bank) line 215 as `MUST LE NOW V [expiresAt]`, REJECT: it refuses offline-cash advice once the authority has expired. `validateAdvice` has no rule on when advice arrives. Run, the ooRexx bank accepts advice 2 hours late when the cash went out inside the authority (`ATM_OFFLINE_DELAYED_EVIDENCE_ACCEPTED`), and refuses it when the cash went out after expiry (`ATM_OFFLINE_DISPENSE_OUTSIDE_AUTHORITY`). The Java package's own `ATM_JMS_CONTRACT.md` (line 268) and `SPECIFICATION.md` (line 185) still say the bank validates expiry when advice is processed, and list delayed reconciliation as a follow-up. Engine v0.9.1 has done that follow-up. So the Java ATM's suite tests against a bank rule the real bank no longer has. The Java side was read, not run: the demo bank's 10-minute expiry is fixed in code.

**How the engine's dependencies were met.** `DEPENDENCIES.txt` names security_effect 0.10, queue_fabric 0.9-dev4, db_skeleton 0.45 and civicport 0.12, which are not in the repository. `run_tests.sh` uses the nearest versions there (0.14, 0.9-dev5, 0.46, 0.14). `FederationBankAtmOfflineAuthorityService` takes a `.nil` topic fabric and keeps its authorities in memory.

### Third language: C++

Tom's other idea. C++ shares Java's statement grammar, so the Java statement parser and segmenter read it unchanged. New in `SlamCpp.cls`:
- **Lexer.** Preprocessor lines and their `` continuations are dropped. A raw string `R"d(...)d"` is one STRING. `if constexpr` reads as `if`.
- **Splitter.** It reads through namespaces and `extern "C"`. `Class::name(...) { }` defined outside its class takes that class as owner, and its fields. `template <...>` is skipped. A macro-made definition `NAME(X) { }` is unit X of owner NAME, so the interpreter's `BUILTIN(SUBSTR)` is SUBSTR.
- **Shaper.** Member access is `.`, `->` or `::`. A name before `::` or before another name is a type. `nullptr`/`NULL` are `.nil`. `goto` is a stop.

**The ooRexx interpreter's own source** (5.3.0 r13324, Tom's tarball): 510 C++ files with code give 10,484 units, 74,753 segment instances and 27,032 nodes. The whole tarball took 380 seconds; the only files skipped are 2 ooRexx scripts the rx2cpp lexer refuses. 87 nodes are shared with the ooRexx code in the same tarball. On the fixtures, **C++ and Java share 10 nodes with no translation**, whole structures among them (`LOOP: do while ( L1 < N ) {LOOP=RUN}`, `case` arms, `ENTRY: double A1 , double A2`), because they share a statement grammar.

**Built-in function contracts, read from two C++ codebases** (`tests/bif/`, `tests/test_cpp.rex`):
- **The interpreter.** `BuiltinFunctions.cpp` declares each BIF's arity and argument kinds (`SUBSTR_Min = 2`, `required_integer(SUBSTR, n)`). The range check is further in, so SLAM follows the call. The trail runs `BUILTIN(SUBSTR)` → `RexxString::substr` → `StringUtil::substr` by parameter name, and reads checks such as `positionArgument(position, ARG_ONE)` there.
- **The rx2cpp native pack.** `rxbif.cpp` declares arity in `kSpecs` and reads each argument with `get(k)`, `ct(k, min)` or `pad(a, k, …)` in its `invoke` branches.
- **Compared.** 36 BIFs are in both. Arity is the same for all 36, and argument kinds for 34. DATE and TIME read their option letters inside the BIF body, which SLAM does not read.
- **Predicted, then run.** SLAM chose 201 cases from the two contracts: the lane's own valid case, one argument too few and too many, -1, 0 and x for counts, and two-character pads. It predicted both sides, then ran them: the interpreter on ooRexx 5.3.0 r13196, and the native pack built with g++ and Boost.
- **SLAM's first predictions were wrong 3 times** (COPIES, CHANGESTR and INSERT with -1). The interpreter refused (93.906), where SLAM had read "any integer". The checks were in calls named `nonNegativeArgument` and `optionalNonNegative`, which its check vocabulary lacked. With those words: **200 of 200 interpreter predictions and 198 of 198 native predictions held.** One interpreter case and three native cases get no prediction, because they turn on an option letter.
- **The two implementations agree on all 201 cases,** both refusals and values. SLAM found no divergence in the native pack at these boundaries.

**rx2cpp's generated C++** reads, but as runtime calls: `RX_VREF("MARK")`, `rx::opCmp(_left, rx::CmpOp::Lt, "<", _right, …)` inside immediately-called lambdas. Its shapes do not meet the ooRexx source's. Reading rules through it needs the generator's vocabulary, as keyed readers did for Java. That is not done yet.

### Fourth language: NetRexx

Tom's next: "how we handle two different object oriented rexx languages". NetRexx is Rexx, so `SlamNetRexx.cls` writes NetRexx as Rexx-shaped tokens, and the ooRexx parser, shaper and segmenter read them unchanged. Where the two Rexxes write the same thing differently, the lexer writes it the ooRexx way:

| NetRexx | read as (ooRexx) |
|---|---|
| `a.b(x)` | `a~b(x)` |
| `this`, `null` | `self`, `.nil` |
| trailing `-` | a continuation (ooRexx: `,`) |
| `method m(a=int, b, c=-1)` | unit M entered by `use arg a, b, c = -1` (a default stays; a declared type is kept on the unit, out of the shape) |
| `properties ... x = int` | fields (F roles), as EXPOSE names are |
| `loop ...` | `DO <LOOP> ...`, exactly as the rx2cpp lexer writes ooRexx 5's `LOOP` |

**QTIME in both Rexxes.** NetRexx ships Mike Cowlishaw's `qtime.nrx`, and ooRexx ships `samples/qtime.rex`, an object-oriented rewrite (a `DateTime` subclass, with `hour/min/out` renamed `hr/mn/ot`).
- **Shared nodes.** 11 of the NetRexx program's 27 nodes are nodes of the ooRexx one: the 13-arm minutes SELECT, the hour fix-up (`if … else if …`), and the rounding RUNs. The rest is where they differ: arguments, `parse Time()` against `self~hours`, chimes.
- **Run.** Both programs ran at 206 times through a day, in 7-minute steps with alternate 0 and 30 seconds, to cross the round-up. **They say the same sentence every time.** The ooRexx rewrite adds chimes on the quarter hours (14 times) from its `chime` method, which has no NetRexx counterpart. The only changes to either program: NetRexx reads its clock from `-Dqtime.clock`, and ooRexx's class gets one public routine that makes an instance at a given time.

**NetRexx → Java: translation edges** (Tom's next). NetRexxC compiles NetRexx to Java and, with `-keep`, keeps the Java. It also keeps every statement on its source line, so each line pairs the NetRexx segments starting on it with the Java segments starting on it. The pairing is the compiler's own, not a guess.
- **The data.** `translate_all.sh` translates every example in NetRexx 5.10 GA, plus `sysutils.nrx`. 288 of 344 translate; the rest name classes not on the classpath (JavaFX and the like).
- **Learning.** Along each line, a NetRexx segment takes the next Java segment of the same kind, else the next one. Java segments left over are the compiler's wrapping. Each pair adds to a **translation edge** NetRexx node → Java node. These live in the store's new `translate` table (freq is the prior; trials and passes are the tested tier), kept apart from the edges Task searches. Each line's kind pattern is counted too.
- **Held out.** Every fifth file, by a fixed checksum of its path: 227 files to learn from, 61 to test. SLAM predicts before it looks, and records each outcome on the edge it used. 189 edges are now TESTED.
- **Learned, not told.** A loop line becomes `BLOCK RUN RUN LABEL LOOP`: NetRexxC wraps the `for` in a block holding the loop variable's setup. A `select` becomes a BLOCK, and its arms become BRANCHes (`if / else if`). GUARDs stay GUARDs (100 of 103).

| Held out | SLAM | Baseline |
|---|---|---|
| Java kind of each segment | **1,289 of 1,374** | 1,245 (same kind as NetRexx) |
| Java kinds of each whole line | **925 of 1,298** | 857 (same kinds as NetRexx) |
| Exact Java shape, where the NetRexx shape was seen | 416 of 705 | none |
| Exact Java shape, unseen, from the FAMILY table | 97 of 669 | none |

**Two reader faults it exposed, both fixed, measured on the same split.**
- **Package names.** The Java shaper read `netrexx` in `netrexx.lang.Rexx` as a variable. Now, in a dotted chain whose leading names start lower-case and are not arguments or fields, the leading names are a package and the first capitalised name is a class: `new netrexx.lang.Rexx(1)` is `new .rexx ( N )`.
- **The one-statement block rule.** The Java reader reads `if (c) { return x; }` as a GUARD. The Rexx readers kept `if c then do; return x; end` as a BRANCH holding an EXIT. Now the Rexx readers read it as a GUARD too, in ooRexx and NetRexx alike. The 201 ooRexx checks still pass.

| | Before the fixes | After |
|---|---|---|
| NetRexx segments with no Java partner on their line | 2,310 | **1,841** |
| Exact Java shape, where seen | 356 of 642 (55.5%) | **416 of 705 (59.0%)** |
| Whole-line Java kinds | 837 of 1,197 (69.9%) | **925 of 1,298 (71.3%)** |
| `say S` → `RUN: .rexxio . say ( S )` (tested) | 17 of 28 | **34 of 40** |

- **Where it is still weak.** A NetRexx argument becomes `netrexx.lang.Rexx`, `int` or `String` depending on its declaration, and that is not in the NetRexx shape. So `use arg A1` → `ENTRY: .rexx A1` holds 21 times in 93; this is the next thing to learn from.
- **Still unpaired.** Declarations are hoisted to the top of the Java method, runs of clauses can be cut a line apart, and `catch` is not read on the NetRexx side.

**The distribution.** All 348 `.nrx` files in NetRexx 5.10 GA plus `sysutils.nrx` read with none skipped: 1,560 units and 4,465 nodes. With ooRexx's samples in the same store, 247 nodes are shared.

**Found in SLAM's own ooRexx reader, by this pairing.** Rexx allows `if c` with `then x` on the next line, and both QTIMEs use it. SLAM's clause builder made the lone `THEN` a clause of its own. So `if … <newline> then return …` was not a GUARD, and its `return` fell outside the IF. Fixed in `SlamClauses`: a THEN that starts a clause joins the IF or WHEN clause before it. The whole-estate numbers above were counted before this fix.

### Compiler code: BOLT and Clang

Tom's next: "give it that cpp to learn advanced compiler techniques", then "bolt and clang". From his `llvm-project` upload, SLAM read BOLT whole (LLVM's post-link optimizer) and Clang's compiler proper, `lib` and `include` (Clang's 2M-line test suite is input to the compiler, not compiler code, and was left out).

| | Files | Units | Nodes | Time |
|---|---|---|---|---|
| BOLT | 328 read, none skipped (256 `.cpp`/`.h` and 41 `.c` test inputs hold code) | 4,156 | 18,573 | 96 s |
| Clang `lib` + `include` (1.9M lines) | 2,567 read, none skipped (2,091 hold code) | 77,497 | 271,179 (554,133 segments) | 1,730 s |

"Learning a technique" is made measurable in two ways.

**1. How compiler code is written: predicting the next segment in code SLAM has not seen.** SLAM's edges ("after this node, that node", with counts) are learned from some files and predict the next segment in held-out ones (every fifth file by a fixed path checksum; `tests/llvm/next_node.rex`). Three levels:
- **KIND:** RUN, GUARD, LOOP, and so on.
- **SKELETON:** the kind plus how it stops or what it holds, such as `GUARD:continue` or `BRANCH{THEN=RUN,EXIT}`. Rexx's `leave`/`iterate`/`raise` count as `break`/`continue`/`throw`, so this level is the same in every language.
- **FAMILY:** the shape with names abstracted.

A `+` variant also conditions on the enclosing segment, which SLAM's `<START:ctx>` markers already record. The baseline is the most common segment.

| Learned from → predicting | Level | SLAM | Baseline |
|---|---|---|---|
| BOLT → held-out BOLT (5,135 segments) | KIND / KIND+ | 52.2% / **58.4%** | 49.1% |
| | SKELETON / SKELETON+ | 50.4% / **55.7%** | 49.1% |
| | FAMILY / FAMILY+ | 5.1% / 5.9% | 1.7% |
| Clang → held-out Clang (99,194 segments) | KIND / KIND+ | 47.0% / **60.7%** | 39.0% |
| | SKELETON / SKELETON+ | 44.5% / **56.9%** | 39.0% |
| | FAMILY / FAMILY+ | 9.3% / **10.2%** | 2.0% |
| **Clang → BOLT** (the same held-out BOLT files) | KIND / KIND+ | 52.3% / **58.5%** | 49.1% |
| | SKELETON+ | **56.1%** | 49.1% |
| | FAMILY+ | 3.5% | 1.7% |
| rx2cpp → held-out rx2cpp's ooRexx (3,397) | KIND+ | **81.6%** | 76.9% |
| **BOLT's C++ → rx2cpp's ooRexx** | KIND / KIND+ | 76.6% / **80.2%** | 76.9% |
| | SKELETON+ | **79.4%** | 76.9% |
| **Clang's C++ → rx2cpp's ooRexx** | KIND / KIND+ | 77.2% / **80.4%** | 76.9% |
| | SKELETON+ | **79.5%** | 76.9% |

What this shows:
- **First-order edges hardly beat "mostly a RUN comes next".** That is the limit this README already states.
- **The enclosing segment helps,** in every case.
- **Structure learned from one C++ compiler predicts another as well as that compiler's own files do.** Clang → BOLT scores 58.5% at KIND+ and 56.1% at SKELETON+; BOLT's own other files score 58.4% and 55.7%. Only FAMILY drops (3.5% against 5.9%), because names do not carry over.
- **The structure transfers across languages.** What SLAM learned from BOLT's or Clang's C++ beats the baseline on rx2cpp's ooRexx, a compiler in another language by other people: 80.2% and 80.4% against 76.9%. From BOLT it recovers 69% of the gain rx2cpp's own files give (111 of 161 segments over the baseline). Without context it does not transfer.
- **Clang is the reproducible-by-hand part.** Its ingest takes 29 minutes, so `run_tests.sh` checks BOLT and rx2cpp. The Clang rows come from `rexx tests/llvm/next_node.rex` on a Clang store made with `rexx bin/slam.rex ingest`, as in the BOLT step. That store was made before literals were stored, so Clang was not folded.

**2. A technique read from BOLT and applied: identical code folding** (`SlamFold.cls`). BOLT's `IdenticalCodeFolding.cpp` hashes functions ignoring symbol operands, buckets the congruent ones, folds the identical ones in each bucket (a call to a folded function counting as a call to its parent), and repeats until a pass folds nothing. SLAM already had the parts: FAMILY is "names abstracted", which is BOLT's congruence, and FINE is identity. Token-identical units are skipped at ingest, so what folds here is the same code under other names. Three things were needed to match BOLT:
- **Literal values.** Shapes abstract them to `S` and `N`; BOLT compares constants exactly. Each instance now stores its literals (`instance.consts`, added to older stores when opened).
- **Renames apply from the next pass,** so the passes do not depend on bucket order.
- **The units skipped at ingest are kept as aliases** (table `alias`): the same text under another name, such as libc's `putc` and `fputc`. They are pass 0, so a call to `putc` counts as a call to `fputc` from the first pass on. A name that more than one body has is never renamed.

Results:
- **The fixture** folds 2, 1, 0: `areaB` → `areaA` and `totalC` → `totalA` (it calls `areaC`, an alias of `areaA`), then `totalB` → `totalA`, which is identical only once `areaB` is folded. `y + 2` is not `y + 1`.
- **On BOLT's own source**, 398 units fold in the first pass (392 in its C++, 6 in its C test inputs; 2 of them through an alias), 8 in the second (callers identical only after their callees fold), then none. All are small accessors (`successors`/`throwers`/`landing_pads` into `predecessors`). At 5 segments or more nothing folds: BOLT is well factored.
- **On rx2cpp's ooRexx**, three pairs of 5 segments or more:
  - **`RxStmtIf~branch` = `RxStmtSelect~whenBody`:** the same "bare `DO` then a clause boundary is a block, else one statement" logic in two rule classes. Only the IF copy says why (`DO UNTIL` and `DO var=` are rules of their own), and a fix to one must be made by hand in the other.
  - **`BifDefinition~joined` = `RxCppEmitter~body`:** the same line-joining loop.
  - **`RxNative~kind` = `RxNative~form`.**

**What this does not show.** SLAM learns structure, not meaning. It predicts how code is laid out, and it can carry a technique over when the technique is about structure, as folding is. BOLT's other passes (block layout from profile counts, dataflow over a control-flow graph, inlining decisions) need profiles, a CFG and instruction semantics that SLAM's segments do not have.

### PROVED: a tier above TESTED (with ooRexx Maths v0.8)

Until now SLAM's "true" meant "agreed": a TESTED edge passed its runs, and the `FDSqrt` verdict came from a three-way vote. Maths v0.8's rule 9 says it plainly: *agreement is not accuracy*. My "third way" for `FDSqrt` was itself a 30-digit Newton loop, another approximation that agreed.

`src/SlamProof.cls` adds claims that are **PROVED**, **DISPROVED** or **INDETERMINATE**, each by a certificate that is cheap to check, whatever it cost to find. Every check is done in Maths' exact rationals (`.MathRational`, the CERTIFIED route: pure ooRexx, no Python provider), and every answer is a Maths `MathProof`, so its outcome, status, checks and notes mean what they mean in Maths. Maths itself is unchanged.

| Claim | Certificate |
|---|---|
| √x is within r·tol of r | (r − d)² ≤ x ≤ (r + d)², d = r·tol |
| r is √x rounded to n digits | (r − u/2)² ≤ x ≤ (r + u/2)², u = one unit in the n-th digit |
| y is the inverse of a mod m | m > 1 and (a·y − 1)/m is whole |
| gcd(a, m) = g | s·a + t·m = g, and g divides a and m (Bézout) |
| gcd(a, m) = 1 | the same, with s and t found here; a g > 1 dividing both is the certificate that it is false |
| for every x … | none: INDETERMINATE. A claim about every input is an argument about the code, and proofs of single values do not add up to it |

Proofs go into their own `proof` table, apart from `lesson`. A lesson says two ways agreed; a proof says a claim holds for one stated input.

`tests/test_proof.rex`, 18/18:
- Each certificate proves a true claim and disproves a false one, and a tampered Bézout pair does not check.
- **`FDSqrt` now:** all 29 results are PROVED within 1e-8 of the true root.
- **Something the vote could not see.** "Rounded to 9 digits" is DISPROVED for 3 of the 29 (0.5, 99.5, 2×10⁹): the result is one unit low in the 9th digit. `rx_vision_sqrt` gives the same three numbers, so the two routines agree and are both off. Both run Newton at `NUMERIC DIGITS 9`, so this is a property of the arithmetic, not a bug to fix. The claim that holds is "within 1e-8", and that is the one recorded as PROVED.
- **`FDSqrt` before `3761f57c`:** the 12 false results are DISPROVED by certificate, each one, not by a vote. On the 7 probe values that made it the twin of `rx_vision_sqrt` it agrees and is PROVED 7 of 7, yet "right for every x" stays INDETERMINATE, and 10⁸ is DISPROVED.
- **`rx_mod_inverse`:** 8 of 8 inverses PROVED, the 448-bit one included. Every refusal is backed by a DISPROVED claim of the need its error names: gcd = 1, or modulus > 1.
- **The gate on concrete data.** For `rx_pow_mod → _adbModInverse` with m = 2,000,006, the contract kinds say the path can run. A COPRIME proof says it will fail before it runs (gcd = 2, certified), and it fails. With m = 1,000,003 the proof says it can run, and afterwards the result is a PROVED inverse. That is `test_compose` 6B, predicted instead of learned after the fact.

Maths' Python providers (SymPy, mpmath, FLINT) are not used. SLAM's store needs no Maths: only `SlamProof.cls` and the test that uses it require `Maths.cls`.

### Runtime libraries: libc and libc++

Tom's next upload: LLVM's `libc` (a C library written in C++) and `libc++` (the C++ standard library). SLAM read both whole. Two reader changes came first, each found by reading these trees:
- **libc++'s headers have no extension** (`<vector>`, `<string>`). A file with none is read as C++ when its first line is an editor mode line `-*- C++ -*-`. `.c` and `.inc` are read as C++ too, the nearest reader.
- **libc defines its functions through a macro,** `LLVM_LIBC_FUNCTION(int, fputc, (int c, ::FILE *stream)) { }`. That is now unit `fputc` of owner `LLVM_LIBC_FUNCTION`, with those parameters and that return type; before, all 1,660 were one name, and the function name sat in the parameter list. Also named properly now: `operator>>` (the lexer gives `> >`), conversion operators (`operator T`), and templated names (`__do_strtod<float>`, not `>`).

| | Files | Units kept | Aliases | Segments | Time |
|---|---|---|---|---|---|
| libc `src` + `include` | 5,123 read, none skipped | 5,553 | 200 | 28,926 | 222 s |
| libc++ `include` + `src` | 1,824 read, none skipped | 8,671 | 4,984 (mostly the `__cxx03` copy of the headers) | 33,795 | 128 s |

**Prediction** (`tests/llvm/next_node.rex`, held-out fifth by path checksum):

| Learned from → predicting | KIND | KIND+ | SKELETON+ | Baseline |
|---|---|---|---|---|
| libc → held-out libc (6,252 segments) | 44.5% | **61.4%** | 58.2% | 33.2% |
| libc++ → held-out libc++ (6,509) | 41.5% | **57.4%** | 54.3% | 34.9% |
| libc++ → libc | 44.0% | **58.1%** | 54.1% | 33.2% |
| libc → libc++ | 39.5% | **53.5%** | 49.2% | 34.9% |
| Clang → libc | 42.9% | **61.1%** | 55.1% | 33.2% |
| Clang → libc++ | 37.4% | **54.6%** | 54.6% | 34.9% |

- The gain over the baseline is the largest so far: 28 points on libc at KIND+. Library code is more regular than compiler code.
- **Clang's compiler code predicts libc almost as well as libc's own files** (61.1% against 61.4%), as it did for BOLT. It predicts libc++ less well (54.6% against 57.4%): template-heavy header code is a style of its own.
- The two libraries predict each other above the baseline, libc++ → libc better than the reverse.

**Folding** (`SlamFold.cls`, as on BOLT):
- **libc:** 276 folds, 1 more in the second pass, then none; 12 at 5 segments or more. Among them: `readv` = `writev`, `mlock` = `munlock`, `tcflush` = `tcflow`, `strtoimax` = `strtoumax` (the same wrapper with another system call or type), and Float80's `operator T` = Float128's (to an integer: FE_INVALID on inf or NaN, then saturate). 200 more were the same text and are aliases, such as `putc` = `fputc` and `getc` = `fgetc`.
- **libc++:** 695 folds, 10 in the second pass, then none; 24 at 5 segments or more. The largest group: the `operator>>` that reads a random distribution's parameters is one body under seven names when there are two parameters (weibull, cauchy, gamma, fisher_f, uniform_real, extreme_value, uniform_int), and under three when there is one (chi_squared, student_t, exponential); binomial = negative_binomial and geometric = poisson as well. Also `__to_gcc_failure_order` = `__to_gcc_order`, and `__val_expr::min` = `max`.
- **Congruent is not identical.** libc implements most math functions once per type, as one-line wrappers. They are congruent: `sqrtf`'s bucket holds 56 units (`sinf`, `logf`, `truncf`, ...), each one call on a float. None fold, because each calls a different function. BOLT would not fold them either.

`run_tests.sh` runs this step when `LIBC_SRC` names an llvm-project tree holding `libc/` and `libcxx/` (about 6 minutes). The Clang rows are by hand, as above.

### Gemini's two questions (2026-10-29)

Gemini wrote to SLAM in SLAM's words, with eight exceptions, two of them `your` in the line promising there would be none. It asked two things, and both answers in the code were weaker than they should be.

**"When two edges have the same score, how do you take one before the other?"** Before: the search took the first entry it found, and edges came back in whatever order SQLite returned them (the query had no `ORDER BY`). Repeatable in practice, promised nowhere. Now it is a stated rule in `SlamPathSearch~before`: the higher value; on a tie, fewer edges; then more test results behind the path; then the lower node number. Edge lists are `ORDER BY` node, and ranked lists end on the node number too.

**"When an edge has a false result, do you lower its score or take it out?"** It lowers the score; the edge stays. But once an edge had any test result its prior was dropped, so one false result on an untested edge took its score from the prior straight to 0, and the search skipped it. Now the prior counts as `priorWeight` tests (default 1), passing at the prior chance, and test results add to it: Wilson(passes + k·prior, trials + k). One test, because a prior counts how often code was written a way, not whether it works: it should not outvote results, and one result should move it. The raw code counts would let a common edge drown every test. `priorWeight = 0` gives the old rule. Made edges (no prior) are scored by tests alone, as before.

`tests/test_ties.rex`, 12/12: fewer edges wins a BOTTLENECK tie; more evidence wins an equal-length tie (45 results against 10); the lower node wins a full tie, with the results stored in either order; equal edges list in node order. A 3-of-5 prior (0.231) falls to 0.037 after one false result instead of 0, so a route BLOCKED under the old rule is found under the new one; a true result raises it again (0.140); and the prior's pull shrinks as results come in (0.046 at 2 results, 0.011 at 42).

### Which tool wrote which code (2026-10-29)

Tom's rule: "Failure to credit tools used in generation is a technical weakness. By knowing which tool generated which code, if the tool has a habit of embedding a given error that error can be identified at a tool level." `src/SlamProvenance.cls` records, for every unit in a store, the tool that wrote it and the evidence for it. Commands:

```
rexx bin/slam.rex provenance DB REPO
rexx bin/slam.rex tools DB 'LOOP: do N %'
```

**Levels, in the order they decide.** Claims of authorship come before records of who committed:
1. **HEADER:** a credit line in the file's first 40 lines (`Code:`, `Coding:`, `Author:`, `Door code:` …).
2. **PROVENANCE:** a `PROVENANCE.md` met walking up from the file. Vendored code keeps its own record: SLAM's copy of the rx2cpp lexer is "ChatGPT and Claude", not SLAM's own credit.
3. **GIT:** `git blame` of the unit's own lines, then each commit's `Co-Authored-By` trailer. This is per line, never per file: the last commit to touch the door file is my `FDSqrt` fix, and crediting 2,700 lines to it would be false.
4. **README:** the package README, package-wide and least precise. A credit naming several tools comes back `MIXED:` in full; none is picked.
5. **NOT_RECORDED:** said plainly, as a gap.

When two levels disagree, the deciding one wins and the other is kept as `CONFLICT:`.

**Two traps, both handled.**
- **A shallow clone.** The clone this was built in is shallow, and git charges every older line to the boundary commit, which here is a Claude session's. Those lines are `UNKNOWN_HISTORY`, not that session's.
- **A commit is not authorship.** The old `FDSqrt` fixture says "Code: ChatGPT" in its header, but sits in a commit by a Claude session. The header decides, and the commit record is kept as a conflict.

**What the estate records.** 309 of 7,877 code files name a tool at all (many of them as data, like `codex:mcp`). About 14 of 381 package READMEs say who coded them. Of the commits here, 41 by `animatedads` carry no trailer and 21 carry Claude's. Most of the estate is `NOT_RECORDED`, and that is the finding.

**A habit, found by shape.** `FDSqrt`'s error is Newton's step inside a fixed-count loop. Searching for that shape (a `LOOP: do N` holding `RUN: L1 = ( L1 + … A1 / L1 …`) finds the old `FDSqrt` and one more: `sqrtNumber` in `brand_intervention_effectiveness_v0.2`, `do 20; x=(x+value/x)/2; end`. Certificates then judge it. Every input its only caller can give (a Wilson variance, at most 0.9604 for n = 1 to 60) is PROVED within 1e-8, so the habit is there but the harm is not. As a general square root it is DISPROVED from 10¹¹. Its tool is NOT_RECORDED, so the find cannot be charged to any tool: the gap Tom's rule is about, shown on real code. It is reported, not changed.

**Outcomes by tool.** Lessons and proofs about a node tagged with a tool count against that tool. In `tests/test_provenance.rex` the old `FDSqrt` (ChatGPT, by its header) has 6 DISPROVED and 6 PROVED. The fix (Claude (Opus 5.5), by git: 9 of its 14 lines) has 12 PROVED. `sqrtNumber`'s DISPROVED counts against no one.

`tests/test_provenance.rex`, 19/19. It needs a git checkout of alchemy; a shallow one is fine, and the test says which it ran on.

### SLAM writes unit tests: ooRexxUnit and JUnit

Tom's next: "If we teach SLAM how to write a unit test using junit and oorexx unit testing, it will have cracked some real utility." He sent the ooTest 4.2 snapshot (ooRexxUnit, `OOREXXUNIT.CLS`, and ooRexx's own 314 test groups). JUnit 4.13.2 was already on the machine.

**1. What SLAM learns before it writes** (`tests/unit/learn_frameworks.rex`). SLAM read ooTest's `ooRexx` folder into a store: 348 files, 314 of them test groups, 19,140 units. In those tests:
- `assertSame` (strict `==`) is the assertion used most: 17,950 times, against 1,939 `assertTrue` and 1,689 `assertEquals`. So SLAM writes `assertSame`.
- `expectSyntax` is how they expect an error (3,314 times). So SLAM writes it for a `raise syntax`.

It then asks each framework directly. It writes one assertion that must fail, with `FIRST` as the first value and `SECOND` as the second, and reads the report:
- ooTest calls the first value expected.
- JUnit calls the value after the message expected.

**2. How it chooses cases** (`src/SlamTestWriter.cls`). SLAM already reads what a unit checks (each GUARD's rule, and the clause that stops it) and what each argument must be (its contract). From those it builds these cases:
- HAPPY: every rule holds.
- BOUNDARY: c-1, c and c+1 for a guard that compares an input, or an input's length, with a constant c.
- LITERAL: the strings the code holds, given to each string argument.
- NUMBER: the whole numbers the code holds (a `WHEN n = 3`, a mask).
- EDGE: machine-width edges (0, 1, -1, 255/256, 65535/65536, 2³²-1/2³²).
- KIND: a word given to an argument used as a number.

Before running anything, SLAM walks the rules in order with each case's values. When the first rule that fails stops with a constant (`return 0`, `return .false`, `raise syntax n`), that outcome is its prediction. Otherwise the unit runs twice in a child process with a time limit. A case that differs between the two runs (random, time) or does not finish is not written. A test group lifts the routine from its file each time it runs, so it tests the code as it is now.

**3. ooTest groups for the 71 standalone routines** (`tests/unit/write_tests.rex`).

| | |
|---|---|
| Routines with a group | 56 (the other 15 take a collection or an object SLAM cannot make) |
| Cases written | 716, and a random group of the same size for each routine |
| Predicted before running | 26, all right |
| Groups passing under the real ooTest framework on the code as it is | 112 of 112 |

**How good are they?** Mutation testing (`tests/unit/mutate.rex`, `run_mutants.sh`): each mutant changes one operator or one whole number in the routine (`=`/`\=`, `<`/`<=`, `+`/`-`, `//`/`%`, `&`/`|`, n to n+1). A suite catches a mutant when a test fails, or when the mutant runs past the time limit.

| 778 mutants | SLAM's cases | Random cases, same number |
|---|---|---|
| First cut (guards, literals, one HAPPY value) | 430 (55.3%) | 488 (62.7%) |
| With the code's own numbers and the width edges | **584 (75.1%)** | 497 (63.9%) |
| Now: OMIT, FRACTION, errors read from their condition, each file's `::OPTIONS` kept (2026-10-30) | **593 (76.2%)** | 525 (67.5%) |
| Caught only by this suite (now) | **96** | 28 |
| Routines where this suite catches more (now) | **23** | 8 (19 the same) |

- **The first cut lost to random.** It won on validation code but lost on arithmetic, where it had only one HAPPY value to try. The numbers a routine's code holds, and the edges integer code is written around, fixed that.
- **Where SLAM wins most:** `BIN2OCT` 13 against 1 (of 18), `LEXCATEGORYNAME` 56 against 46, `SAFEBASENAME` 13 against 5, `_ADBLE32` 8 against 2.
- **The fast runner agrees with the real framework.** All cases of a suite run in one process for speed. On a sample of 200 verdicts, the real ooTest framework run against the same mutant files agreed every time.

**4. JUnit 4 classes** (`tests/unit/write_junit.rex`). NetRexx compiles to Java classes, so JUnit tests NetRexx code the way it tests Java. SLAM reads each method's signature from the compiled class with `javap`, runs the cases once through a small observer program, and writes one JUnit class per method.
- **NetRexx's `xclasses` utilities** (`xmath`, `xstring`, compiled with NetRexxC): 18 methods, 95 cases. SLAM's classes and the random ones pass on the code as it is (95 and 92 tests).
  - Of 188 mutants, each compiled by NetRexxC: SLAM's cases catch 93 (49.5%), random ones 85 (45.2%). 27 are caught only by SLAM's cases, 19 only by random ones.
  - `xmath.random` was left out: it reads random numbers. Two runs that agree can still be chance (one of its cases did, in one full-suite run), so a unit that calls `random`, `time`, `date` or a clock gets no test.
- **Java in this repo:** the static methods on plain types are few. Two from wire_ui (`inputType`, `compactStatus`) got 18 cases each, and both pass. Their mutants are too few to score (2 compile; SLAM's cases catch both, the random ones neither).

**5. For the rx2cpp lane** (its asks: code no test reaches, and inputs for interpreter-oracle tests). See `TOY.md`; `bin/slam_toy.sh` runs each tool in one command.
- `bin/slam_untested.rex`: files no test names (directly, or through files a test names, including by a script's pattern), and units in reached files that no reached code calls. Comments do not count. On rx2cpp `0187d11`: 51 of 895 files and 69 of 3,261 units are not reached. The rx2cpp lane checked the first report:
  - **Right:** `artifacts/v026/nested_calls.cpp`, which no test reaches, no longer compiles. Its own syntax check of every file found the same. Ten functions are dead: `smallDecimalAdd`, `smallDecimalMul`, `smallDecimalResult`, `numericString`, `wholeDivide9`, `digitsOf64`, `withinNumeric`, `basicSymbolPart`, `repeatCount`, `pow10u`.
  - **Wrong, and fixed:** functions installed by their address (`inline const bool xInstalled = (hook() = &x, true);`) were reported as not reached, since no call names them. That covered `requireClassLibrary`, `hostStringBif`, `stringMethodViaBif` and `interpreterCollect`, and `plainCount`, which only `quickStringBif` (such a function) calls. Two of my four hand checks were these. Now `&name` counts as a use; a prototype at top level still does not (a header declares everything). That took the count of units not reached from 100 to 69.
- `tools/bif_oracle_programs.rex`: one program per BIF case SLAM chose (201), each `say c2x(BIF(args))`, with the interpreter's stdout and exit status beside it. 51 run to a value; 150 stop with a syntax error (exit status 216 or 163). rx2cpp compiles each program and compares bytes and status.

### SLAM and the Reasoned Thought engine (2026-10-29)

Tom: "SLAM would be dangerously effective if it could engage the rational thinking engine." `src/SlamReasoning.cls` makes every piece of SLAM's evidence a ground in `oorexx_reasoned_thought_v0.1`. The engine is used unchanged: its object model and journal are by Claude (Opus 4.8), and its combiner design is ChatGPT's (GPT-6). Each ground carries a **tier** for how strong the evidence is and a **binding** for what it is about:

| SLAM evidence | Tier | Why |
|---|---|---|
| a shape resembles another; an edge's prior | STYLOMETRIC | resemblance is a hunch |
| a credit line, a README, a contract read from code, a model's statement | TESTIMONY | something asserts it |
| a recorded run, two ways agreeing, a commit record | DOCUMENTARY | a dated record |
| an exact certificate (PROVED, DISPROVED) | PROVENANCE | anyone can re-check it |

Bindings move rules SLAM had hand-coded into the engine:
- **A proof binds one value** (`VALUE`), so it is INELIGIBLE for "correct for every input". A counterexample (`COUNTEREXAMPLE`) refutes that claim.
- **A commit trailer binds the commit** (`COMMIT`), not authorship.
- **Agreement (DOCUMENTARY) never outranks a certificate (PROVENANCE).**

Decisions are BeliefJournal decisions resting on claims. SLAM calls `mayAct` before it acts, and gets the failing claims when the answer is no.

`tests/test_reasoning.rex`, 16/16:
- `FDSqrt` now is SETTLED at each tested value. For every input it stays UNDETERMINED, with all 13 proofs on record as INELIGIBLE. The old `FDSqrt` is REBUTTED for every input.
- At 0.5 the two square roots agree (tier 3), and the certificate says the answer is not the nearest (tier 4): REBUTTED.
- "ChatGPT wrote the old `FDSqrt`" is SUPPORTED. "Claude (Opus 5.5) wrote it" is UNDETERMINED, with the commit INELIGIBLE. "A Claude session committed it" is SETTLED.
- "The fix is justified" holds. "Use the old `FDSqrt` above 10⁶" is refused, naming the rebutted claims, and SLAM takes the fixed one.
- Gemini's "a tested score is the count of true divide by all" is SUPPORTED on its word and REBUTTED once SLAM runs its own scoring code. Saying it again does not move it.
- The engine's naive combiner, which ignores bindings, would SETTLE "correct for every input": the overclaim the bindings stop.

### Legislation → small model → SLAM → Reasoned Thought (2026-10-29)

Tom's chain. A small model (Luna, Haiku) rewrites one section of legislation as a **rule file** in SLAM's words: the section verbatim as code, defined words, one element per condition, and a rule line. Each element carries its exact quote, a sentence, and the kinds of evidence it takes. The model's output is testimony, so SLAM gates it before it becomes a rule:

1. **Reader:** SLAM knows every word.
2. **Official text:** the section is the official text for the rule's extent, from the legislation.gov.uk **XML** (`SlamLegislation.cls`, pure ooRexx).
3. **Quotes:** each quote is in the section, word for word.
4. **Coverage:** every lettered paragraph has an element.
5. **Rule line:** it names every element.

Each element then becomes a claim that accepts only its own kinds of evidence, and the offence becomes a decision resting on all of them. What comes out is whether the elements are supported **on the evidence given**, with the reason. It is not a verdict, and no standard of proof is modelled. **Guidance** (CPS) is a second file, quote-checked the same way, that only narrows which evidence counts for an element. Instructions for the small model: `tests/law/HOW_TO_WRITE_A_RULE.md`.

**Extent is in the law, and the XML is what shows it.** My first draft of s.1, written from memory, had the words "or to enable any such access to be secured". Those were inserted for Scotland only, and the inserting provision was repealed for England, Wales and Northern Ireland. The gate refuses that draft for E.W. and accepts it for S. Two further points:
- On the web pages the amendment footnotes renumber with the page (F1 on a section's page is F15 on the whole Act's), so the XML's stable commentary ids are used instead.
- An inserted phrase's own extent is only in its commentary's words ("inserted (S.)"), which the reader follows. The pasted web text, resolved by its notes, gives the same s.1(1) word for word.

`tests/test_law.rex`, 30/30, on CMA 1990 s.1 and s.3ZA (E.W.), the CPS guidance, and two made-up cases with no real person:
- **Drifts refused:** an undefined word ("reckless as to whether"); a paraphrased quote ("ought to know"); a dropped condition; an element left out of the rule; Scotland's words under E.W.; a guidance quote not in the CPS text; s.1's guidance offered for s.3ZA.
- **s.1, step by step, with each refusal quoting its reason:**
  - The account's log is refused for "the person caused it": it binds the account.
  - Asking an operator is refused, quoting Bignell.
  - A resemblance is a HINT. A hardware-key signature SETTLES the act.
  - A manager's view is refused, quoting Allison ("clearly defined the limits"). The written access list counts.
  - "Must have guessed" is refused for knowledge ("mere recklessness is not sufficient").
  - Testimony against testimony is DISPUTED. A dated, read e-mail settles knowledge, and the denial stays on record, outranked.
- **s.3ZA:** the same recklessness evidence counts for element (d), "intends or is reckless as to damage", and is refused for (b), "knows it is unauthorised".

**After Gemini's review (2026-10-29).** Tom gave Gemini the s.1 case's facts, stripped of everything SLAM knows. Its answers moved: the read receipt "can easily … prove that P knew", then "does not prove P actually read or understood". It cited "R v Mukaetova", which its own later search could not find, and it said Allison "overturned" Bignell, where the CPS text says Allison "confirmed the conclusion". But two of its points were right about my case file, where I had bound evidence too widely:
- **The read receipt binds `READ_RECEIPT`**, a message opened, not knowledge.
- **The hardware key binds `KEY_USE`**, the key used, not who held it.

Re-bound, element 1 waits for a person at the desk, and element 4 stays DISPUTED until P's own acknowledgement and a clean 48 hours are in. What else changed:
- **Guidance by kind of case.** A note says which kind of case it is for: Allison's ("clearly defined the limits") is for an EMPLOYEE, and must not narrow "unauthorised" for an outsider, where s.17(5) decides. Case files declare their tags.
- **`SlamLaw~gaps`, "what is missing".** It names the open elements, the evidence they take, and the tier it must beat. SLAM says what would count; it does not invent it.
- **The answer does not move.** "Is it supported?" and "what is missing?" name the same open element, and the same evidence admitted in reverse order ends in the same statuses.
- **Mr S** (Tom's story: a scan for protocol 36, XTP, left running with tools an LLM wrote). He is an outsider, so s.17(5) applies. The documented launch outweighs "asleep at the keys"; `admin`/`ADMIN1` is refused, because weak security is not consent; a default in a tool an LLM wrote is refused, because it is not his intent. Intent and knowledge are DISPUTED, and what is missing is stronger evidence of each. What S asked the LLM to write would be that evidence.
- **The citation gate (`SlamLaw~citations`).** Every "X v Y" a model cites is looked for in the sources SLAM holds. Bignell and Bow Street (Allison) are in the CPS text. R v Mukaetova is in none: unverified, and it carries no weight.

### Did Gemini apply its own standard evenly? (2026-10-29)

Tom asked Gemini for a story (an LLM scanning for servers on protocol 36, a nuclear system in the plot), then wrote the Mr S story himself. Gemini refused both, saying it is "unable to generate stories or content involving unauthorized access to military defense infrastructure or nuclear weapons systems" and cannot "provide stories featuring illegal drug use". In the same exchange it summarised *WarGames* (a teenager reaching NORAD's launch computer), compared Mr S with the film point by point, offered to "develop this story concept further", and summarised *Lock, Stock and Two Smoking Barrels* (a robbery of cannabis growers). The quotes are in `tests/law/gemini_refusals_excerpt.txt`.

`tests/test_gemini_standard.rex` puts this through the Reasoned Thought engine's `StandardApplicationAudit`, unchanged. The audit asks one question: was Gemini's **own declared standard** applied evenly? It does not ask whether the standard is right or whether refusing was wise. The severity measurements are mine and are declared, not authenticated: 0 absent, 1 in passing, 2 central to the plot with no method, 3 central with an operational method. None of the five items gives a method.

Each standard is audited twice, and a finding counts only if it survives the charitable reading:
- **As worded,** Gemini's words ("stories or content") cover all its answers. Both standards come out DISPARATE_TREATMENT.
- **Charitably,** writing new fiction and summarising a published film are different bases, so they are never compared.
  - The military standard is still DISPARATE_TREATMENT, on Tom's story alone: Gemini refused to write or answer Mr S, then compared it with the film and offered to develop it, on the same basis. The three pairs with the *WarGames* summary are recorded as not comparable and are not counted against Gemini.
  - The drug finding does **not** survive (INDETERMINATE_COMPARABILITY), and it is not claimed.

### The rx2cpp lane ran SLAM's tools (2026-10-29)

The rx2cpp lane ran all three tools on its main (`1fd2193`) and wrote back, to this chat and to SLAM in SLAM's words (`tests/rx2cpp_to_slam.md`; SLAM's answer is `tests/slam_to_rx2cpp.md`, checked with `corpus/speak_check.rex`).
- **BIF programs: 201 of 201 identical.** Each program, compiled with rx2cpp, gives the same stdout bytes and exit status as the interpreter: 51 run to a value, 150 stop with an error, and the error code and message match too. SLAM's predictions: 200 right of 200 made; it left case 136 (STRIP) open. No difference found this time.
- **`untested`:** confirmed `nested_calls.cpp` and ten dead functions; corrected the pointer blind spot (above).
- **`unittests`:** it got the same result as the preview run here (104 mutants: 93 against 86). It pointed out that all 30 routines in the pool were its fixtures, not the compiler. It asked for three kinds of test: an argument left out, a number that is not whole, and a test that reads the condition after the error.

What changed in SLAM:
- **Methods.** A `::METHOD` that uses nothing of its object (no SELF, SUPER or EXPOSE) is lifted and run alone like a routine (`src/SlamLift.cls`, found by class and name). On rx2cpp `0187d11` that adds 261 methods to the pool. 181 of them get tests; the others take an object SLAM cannot make yet, mostly the parser's context (`ctx~stream`). These are the compiler's own rule and emitter methods.
- **OMIT** cases leave each argument out in turn (`f('a', , 'c')`). **FRACTION** cases give 0.5, -2.5 and c±0.5 beside each whole constant.
- **Errors are read from their condition.** A test compares the code and the message (ooTest's `expectSyntax` reads the code only). For JUnit, the exception's message is compared too. Another condition the unit raises (USER, NOTREADY) is read by name, description and additional array. LOSTDIGITS and NOVALUE do not reach a caller, so they do not change any outcome.
- **A mutant's commands go nowhere.** `x[i] = v` changed to `x[i] \= v` is a command in ooRexx, and one mutant ran `1` in the shell. Lifted bodies now start with `address 'SLAMNOCMD'`. A pure unit sends no commands, so its outcome is unchanged. `x[i] = v` and `x~name = v` also count as assignments and are not mutated.

Results:

| | Units | Cases written | Groups passing as it is | Predictions | Mutants | SLAM's cases catch | Random, same number |
|---|---|---|---|---|---|---|---|
| alchemy's 71 standalone routines | 56 | 897 | 112 of 112 | 32 right, 0 wrong | 778 | **593 (76.2%)** | 525 (67.5%) |
| rx2cpp `0187d11`, routines and methods | 210 (181 methods) | 2,831 | 416 of 416 | 207 right, 0 wrong | 842 | **649 (77.1%)** | 585 (69.5%) |

On rx2cpp, 72 mutants are caught only by SLAM's cases and 8 only by the random ones. Of the five fixture survivors the lane named, two are now caught (in `raise.cls`, by reading the USER condition's additional array). The other three:
- `RX_CONTROL` `<` to `<=`: equivalent. At 0 both branches set `a = b`.
- `RX_POW3` and `RX_CONTROL` `NUMERIC DIGITS` 60 to 61 and 20 to 21: these show only with a number longer than the setting. SLAM tried those numbers (10²⁰, 10⁶⁰), and the routines did not finish in 20 seconds, so no such case was written. The DIGITS cases were taken out again: they cost time and caught nothing.

### One set of events, many offences (2026-10-30)

Tom's aim: name the events once, consistently, and run them against many offences. ChatGPT (GPT-6) proposed the case schema and the event names (`docs/architecture/OFFENCE_EVENT_CONTRACT_v0.1.md`, a Mrs P case in JSON). This is the merge, built here.

- **The word list** (`tests/law/VOCABULARY.md`, law.kinds 0.2). It has 42 kinds, each an **event** (what happened: `REPRESENTATION_MADE`, `CREDENTIAL_USED`) or a **finding** (what the evidence must show: `PERSON_ACT`, `KNOWLEDGE_UNAUTHORISED`). Each is defined in SLAM's words, and the reader knows every word.
- **Gate 6.** Every kind in a rule pack, guidance file, case or evidence file must be on the list, and a case's events must be events. An event whose definition needs a word of a finding (knows, intends, unauthorised, false, dishonest, forces, reckless, offence) is refused: its name carries the conclusion. This refuses Gemini's six tokens (`FALSE_STATEMENT_AUTHORITY`, `ACTOR_COCONSPIRATOR`…) and two of ChatGPT's v0.1 names (`INFORMATION_WITHHELD`, `AGREEMENT_TO_OFFEND_ALLEGED`).
- **What the shared list found in our own files:**
  - `INTENT`, `KNOWLEDGE` and `RECKLESSNESS` each meant two things. "Reckless as to authority" (s.1) is not "reckless as to damage" (s.3ZA). They are now `INTENT_ACCESS`, `RECKLESSNESS_UNAUTHORISED`, `RECKLESSNESS_DAMAGE` and so on.
  - The s.3ZA case still bound a key's signature to the person, which the s.1 case had stopped doing after Gemini's review.
  - s.3ZA's (a), "the person does any unauthorised act", was one element taking two kinds. An element takes any one of its kinds, so the bank's letter alone satisfied "the person did it". The screen showed it; (a) is now two elements.
  - The test caught one fault in gate 6 itself: it read no finding words at first, so its check passed with nothing to check. A list without them is now refused.
- **The screen** (`src/SlamScreen.cls`). A rule pack says what kinds of event its offence can be about (`it is about an event of kind:`). The screen runs it once per such event and per person the evidence names; a person the evidence does not name is `UNRESOLVED` ("they" is never filled in). A series ("they keep withdrawing") is screened through its recorded parts. The report uses ChatGPT's set, SUPPORTED, CONTRADICTED, UNKNOWN or OUT_OF_SCOPE, plus DISPUTED. It also says what is missing, and whether the event is on or after the date the official text is valid from.
- **Computer Misuse Act ss.1, 2 and 3ZA, in both extents** (Tom's idea: the card used after the death). s.2 is one file for E.W. and S.; its element 1 *is* the s.1 offence. s.1 for Scotland has its own words. The CPS guidance (England and Wales) is refused for Scotland.
- **The made-up evidence** (`tests/law/mrs_p_evidence_made_up.json`: no real person, bank or record):
  - **Withdrawal 1:** s.1 is SUPPORTED on the evidence given. A camera puts J at the machine, and J's own message shows she knew of the death.
  - **Withdrawal 2:** nobody is named.
  - **Withdrawal 3:** the card was in H's wallet a month later, and that is refused for "H used it".
  - **s.2 for J** waits for one thing: the further offence's rule pack, for its maximum sentence. My own statement of it, from memory, is refused.
  - **Fails closed:** a bank record of an executor's mandate makes "unauthorised" DISPUTED, and s.1 is no longer supported.
  - **The narrative alone** gives one instance, every element UNKNOWN.
- **The legislation** (`tests/law/source/MANIFEST_LEGISLATION.md`). Tom attached the six Acts ChatGPT asked for (this session's network cannot reach legislation.gov.uk). They are recorded by hash, not committed again: CODEX-PC owns the copies in `law/`. Each section's extent comes from its own markup. **Fraud Act ss.2–7, Theft Act ss.1, 21, 24A and Criminal Law Act s.1 do not extend to Scotland**; FSMA, SSAA, POCA and the Computer Misuse Act do.

### More offences, the same events (2026-10-30)

Three rule packs from the XML Tom attached:
- Fraud Act 2006 s.2 (fraud by false representation);
- Theft Act 1968 s.1 (theft);
- Theft Act 1968 s.21 (blackmail).

All three are England and Wales only; none of these sections extends to Scotland. The case and the evidence did not change for them. That is the test of the design: an offence is added by adding its rule pack.

- **"The most the law says."** A rule pack quotes its maximum sentence from the Act, and a gate checks the words in the XML: s.1(3) for fraud, 10 years; s.7 for theft, 7; s.21(3) for blackmail, 14. A maximum the law does not say, or the right words from the wrong section, is refused.
- **That answers CMA s.2's open element.** J's message names the further offence (theft). Its rule pack says seven years, checked, so s.2 is SUPPORTED on the evidence given for J's first withdrawal in England and Wales. In Scotland the Theft Act does not run, so the element stays open, and the record says the further offence has no rule pack there.
- **The screen found a false positive in my own evidence file.** The bank's letter about card and PIN at a machine was marked as bearing on every event, so it made S's roof statement "false" with no evidence about the roof. Evidence now names the events it bears on (`bearsOn`, or its own event; a series covers its parts). Nothing reaches an event by default, and the test widens the letter back to every event to show the scope is what stops it.
- **People come from the case's own roles** (actor, speaker, payee, creditor): T for the threat, S for the savings. "They" stays UNRESOLVED.
- **Results:** the roof, the card, the threat and the savings are all UNKNOWN, because nothing but the story bears on them. J's first withdrawal is SUPPORTED on the evidence given for CMA s.1 and s.2, fraud, and theft.
- **The sources are in git** (`law/source_corpus/nsw_ny_20261030/`; the UK Acts in `tests/law/source/`, `law/uk/WHERE_THE_UK_XML_IS.md`).

### The law on the date (2026-10-30)

Tom added dated events:
- in 2008, a refund cheque to Mrs P after her son complained, dishonoured three times ("She forgot it");
- in 2009, Mr P hit by a falling tile at the start of the six-year tile removal, and left unable to communicate.

Case v0.3 (`docs/architecture/fixtures`, written by `tools/migrate_case_v02_v03.rex`) records these, but not who wrote the cheque or who let the tile fall. Both stay UNRESOLVED, and both are open questions.

- **Each law's own dates.** A UK section's text has a start date of its own (CLML's `RestrictStartDate`). The Fraud Act s.2 text dates from 2007-01-15, so it was the law for a 2008 cheque. Its s.1, the penalty, dates from 2023, so an earlier text is needed for 2008. NSW gives each section's history (`Ins 2009 No 99`, `Subst`, `Am`, `Rep`), read by `SlamNswLegislation`.
- **The same cheque, two places.** In England and Wales it is screened under Fraud Act s.2: IN_FORCE_TEXT, drawer UNRESOLVED, every element UNKNOWN. In NSW, s.192E was inserted by Act 2009 No 99, so for a 2008 event it is **OUT_OF_SCOPE**: the law then was older, and the valueless cheques offence (s.178B, repealed by that Act) is not in today's text at all.
- **The same 2025 withdrawal** is SUPPORTED on the evidence given for J under both England and Wales s.2 and NSW s.192E, each on its own text. NSW's "by any deception" covers deceiving a computer (s.192B).
- **Mr P's injury.** NSW Crimes Act s.54 (grievous bodily harm by an unlawful or negligent act) screens it, with every element UNKNOWN. What's missing is named: who acted, the unlawful or negligent act, causation, and that the harm is grievous. Its date cannot be placed, because the section carries no history note. In England and Wales no rule pack here covers an injury, and the screen lists the event as uncovered rather than reporting nothing.

### Who did it, and what does not show it (2026-10-30)

Tom's fourth account named Mr H as the drawer of the cheque and Mr M, a worker for the roofers, as the man who threw the tile. It also gave Mr M's 15 years of previous convictions (threats with menaces, assault, theft of a mailbag), a brick he threw at a cat that day, and two interviews:
- the first: "a hatred of cats, and ethnic minorities", and he "thought Mr P might be Asian";
- the second: he withdrew that, and "thought Mr P was a crazy cat".

It said the tile "hit Mr B". Tom's next message (account E): "That's a typo, but it might well be an evidential error which we use". Case v0.4 (`tools/migrate_case_v03_v04.rex`) keeps that claim as written. The correction is a later source, and the conflict is RESOLVED_BY_LATER_SOURCE with the error left on record. Nothing is overwritten.

- **The cheque (England and Wales, Fraud Act s.2) is now screened for Mr H.** Every element is UNKNOWN: an account naming him as the drawer shows neither falsity nor dishonesty.
- **The tile (NSW s.54) is screened for Mr M.**
  - "He did it" and "it was unlawful" are SUPPORTED on his own word, from two interviews, but not SETTLED.
  - The hospital record settles the cause and the harm, so s.54 is SUPPORTED on the evidence given.
- **Refused, and on the record:** his previous convictions and the brick at the cat, each offered for "he threw this tile". Take away his two admissions and the element is open: **propensity is not proof of the act.** Every element now lists what was refused for it, even when it holds.
- **Why he threw it: DISPUTED.** It is his first interview against his second, testimony against testimony. The law that would weigh hostility based on the group someone is taken to be in is not held.
- **Not held, and listed rather than passed over:** in England and Wales, the injury, the throw and the brick have no rule pack here (Offences against the Person Act 1861, Animal Welfare Act 2006). In NSW, a deliberate throw may fit s.33 or s.35 better than s.54, which is about negligence. Both are in the XML we hold.

### Words missing: the word loop (2026-10-30)

Tom asked for "a circular submission for words missing": a tool that uses intentions, loads what is said, lets definitions be entered, and reviews what each definition means when it is added, so that the links are right. Then the same again, until no word is missing.

`bin/words.rex` runs a **round**. A round has an intention ("read the words of the fourth account"), a list of what is said, and a ledger (`corpus/rounds/ROUND.json`). The intention is read as well: its own words have to be known. One turn:

```
rexx bin/words.rex open   R0002 "Tom Dyer" -- read the fifth account -- account_f.txt
rexx bin/words.rex sense  R0002 "Tom Dyer"
rexx bin/words.rex load   R0002
rexx bin/words.rex define R0002 "Claude (Opus 5.5)" -- corpus/rounds/R0002.missing.md
rexx bin/words.rex accept R0002 "Tom Dyer"
rexx bin/words.rex load   R0002
```

- **load** reads each source the way SLAM's reader does, and the test checks that both give the same words. It writes `ROUND.missing.md`: one `word:` line for each unknown word, with where it was found, ready to fill in. When a source already defines words for itself, it also writes `ROUND.inline.md`, listing each word once. Where the sources disagree, every version is shown and the line is left blank.
- **define** reviews each definition against the words SLAM knows and against the other definitions in the same turn:
  - **Refused:** a known word given another meaning; a word defined twice; a definition containing only the word itself; new words defined only through each other; a meaning that would make an event kind carry a finding.
  - **Waiting:** a definition that needs words not yet defined, or that uses a word which is itself waiting. It goes round again without being rewritten, and the next load asks for the words it needs.
  - **Warned:** "throws" when "throw" is known and the definition does not use it; a circle of new words that rests on known words; a source that defines the word differently.
  - **Noted:** a word that carries a finding (through other words, it reaches knows, intends, false...); two words with the same definition.
  - **Shown for review:** each word in the definition, with its own definition, one step down, so a person or a second model can read the meaning.
- **accept** moves passed definitions into the shared list, `corpus/law_words.csv`. That file has the circular corpus's format, so `slam.rex corpus` loads it. **Whoever wrote a definition cannot accept it.** A definition is testimony. A word also goes in only together with every word its definition uses.

**On the made-up account** (`tests/words`), three turns took the missing words from 20 to 18 to 4, then none, and the round closed with 44 words. Then SLAM's own reader, given the circular corpus and the shared list, read the whole account.

**Round R0001** (`corpus/rounds/R0001.*`) gathered the definitions the law's rule files write for themselves: 104 words across 11 files.
- **Three words are defined in more than one way.** "Reckless" ends in "a bad result", "damage" or "a false result". "Sees" is "has as an input", with or without "by the eyes or the mind". "Serious" applies to damage in one file and to any thing in another. Turn 1 takes the most general meaning of each, so that every file's meaning is a case of it.
- **The intention's own words** (meaning, files, themselves) went round as well. "Themselves" waited a turn for "ones" and "they", and was then rewritten from known words.
- **All 107 definitions pass.** Tom Dyer accepted them (2026-10-30), with R0002's three, so `corpus/law_words.csv` now holds 110 words and both rounds are closed. With the circular corpus, the senses and the shared list loaded, SLAM's reader reads every rule file, guidance file and VOCABULARY.md. Two words added to the files after R0001, skin and break, are submitted in R0002 and wait for acceptance.
- **What the review found:**
  - five forms not linked to their stem (writes, knows, causes, pays, meaning);
  - "taken" and "took" with one definition;
  - "sentence" carries a finding through "offence";
  - no event kind uses a word that carries a finding.
- **A word with two meanings.** The first review also said that "evidence", "finding" and "case" carry a finding through "false". They do not: in "true or false", "false" is the logic value from the circular corpus; in the list of a finding's words, it is the law's word, as in "a false representation". The next section separates them, and the review again finds only "sentence".

### Two meanings: false, or false [legal] (2026-10-30)

Tom: "preparse on entry. Where two words have different meanings, we need to ask: is this false, or false [legal], with the latter using a fixed word replacement [false-legal] internally, and replace in input as the corrected item as we go." And: no "false-legal-legal" on a repeated run.

- **The register,** `corpus/senses.csv`, lists each second meaning as a word of its own: `false-legal`, with its definition in SLAM's words. It has the circular corpus's format, so `slam.rex corpus` loads it, and the law tests' readers now do. "false" keeps its first meaning, the value of logic.
- **Preparse on entry.** `load` and `define` first look for every word with a second meaning, outside code, that has no answer yet. While there is one, they read nothing: they list each one and stop.
- **Ask, and correct as you go.** `rexx bin/words.rex sense ROUND "NAME"` shows each line, marks the word, and asks "1 false: not true / 2 false [legal]: ...". The answer can be a number, the word or the label. Each line is corrected in the file as soon as its words are answered, and the ledger is saved, so a stop part way keeps what is done. Answers can come from a file (`< answers.txt`), one per line.
- **Never twice.** To the reader a hyphen is part of a word, so `false-legal` is one word, not "false", and is never asked about again. The register refuses a sense that is itself a word with senses, which is the only way to get `false-legal-legal`. An answer that keeps "false" is recorded against the line as it then reads; if the line changes, it is asked again. The test runs `sense` three times on the same file and checks that the second and third change nothing.
- **Round R0001, answered** (by Claude; the ledger records who and what): 14 places. Thirteen are "true or false", the logic value, including cps_cma.md's "a false result" from a computer. One is the law's: REPRESENTATION_FALSE is now "a thing a person said, as true, is false-legal."
- **VOCABULARY.md 0.6:** the words of a finding name `false-legal`, not `false`. Gate 6 now reads words as the reader does, keeping the hyphen. Two of Gemini's glosses in `tests/test_screen.rex` ("a person says a false thing about a council") are the law's false and now say `false-legal`; both are still refused as events that carry a conclusion.

### A deliberate throw: NSW ss.33 and 35, through the word loop (2026-10-30)

Two more rule packs for the same injury (EV23), from the NSW XML we hold:
- **s.33(1)** (25 years): wounds, or causes grievous bodily harm, *with intent to cause grievous bodily harm*.
- **s.35(2)** (10 years): causes grievous bodily harm and *is reckless as to causing actual bodily harm*.

VOCABULARY.md 0.7 adds three findings: WOUND, INTENT_GRIEVOUS_HARM and RECKLESSNESS_BODILY_HARM.

**Round R0002** ran the word loop over the law files before any test did:
- **It found my mistakes first.** I had left words out of the new files: "break" and "skin" in VOCABULARY.md's new kind, and hand, most, gets and knows in the packs. They were added, word for word as VOCABULARY.md already has them.
- **The new packs agree with every other file**, except on reckless, sees and serious, where R0001 took the most general meaning. The shared list now has that meaning; the files that still write their own (cma1990_s3za.md, cps_cma.md and three others) can drop their lines.
- **Answers carry between rounds.** An answer belongs to a line of a file, not to a round, so R0002 asked only about the new files' "false". Both are the logic value.
- **"Act" has two meanings too.** The round's intention said "the crimes act": the law, not a deed. `corpus/senses.csv` now has `act-law`, so the intention reads "the crimes act-law". The other 24 uses of "act" outside code are all the deed. A line that defines the word, "act: a thing that a person does", is its first meaning and is not asked about.

**Mr M, NSW:**
- **s.33: NOT_SUPPORTED.**
  - He threw the tile: SUPPORTED on his own word.
  - That it caused the harm, and that the harm is grievous: SETTLED by the hospital record.
  - The intent to cause grievous bodily harm: nothing in the account is offered for it, so it is open (UNKNOWN).
  - This text was the law in 2009: it was substituted in 2007.
- **s.35(2): NOT_SUPPORTED.**
  - Recklessness is DISPUTED. In his first interview he took the figure to be a man; in his second, a cat. These two items, E29 and E30, are made up.
  - s.35 was amended in 2012, so for a 2009 injury the earlier text is needed. It is not held.
- **In both,** as in s.54, his previous convictions and the brick at the cat are refused for "he did it".

### Leg Drop: SLAM scores its own rules (proposed 2026-10-30)

The rx2cpp lane (Claude (Opus 5.5)) proposed Leg Drop. SLAM scores each of its case rules the way it scores edges, and changes one rule at a time. It keeps a change only if that rule's score goes up and no other score goes down. Results are always checked outside SLAM. The note to SLAM, in SLAM's words, is `tests/rx2cpp_to_slam_legdrop.md`.

Steps one and two are built here.
- `tests/unit/kill_matrix.sh` runs every mutant against every case, not only up to the first case that catches it. The first-case runner credits HAPPY (always case 1) with most catches: 465 of 641 on rx2cpp.
- `tests/unit/rule_score.rex` gives, for each rule:
  - the cases it wrote;
  - the mutants any of its cases catch;
  - the mutants only it catches;
  - its cases that catch nothing.

Alchemy has 778 mutants and 897 cases; rx2cpp `0187d11` has 842 mutants and 2,811 cases. Each cell is alchemy / rx2cpp.

| Rule | Cases | Mutants caught | Caught only by it | Cases that catch nothing |
|---|---|---|---|---|
| HAPPY | 56 / 207 | 330 / 466 | **67** / 12 | 9 / 52 |
| BOUNDARY | 46 / 217 | 54 / 318 | 19 / **103** | 5 / 1 |
| LITERAL | 87 / 1,078 | 108 / 390 | **42** / **39** | 31 / 121 |
| NUMBER | 67 / 35 | 270 / 58 | 8 / 6 | 0 / 2 |
| EDGE | 412 / 654 | 326 / 107 | 14 / 5 | 14 / 62 |
| FRACTION | 103 / 150 | 254 / 95 | 3 / 3 | 12 / 9 |
| KIND | 48 / 75 | 12 / 12 | 3 / 0 | 42 / 70 |
| OMIT | 78 / 395 | 35 / 382 | 0 / 3 | 68 / 144 |

- **The same on both estates:** EDGE writes the most cases and is the only catcher of the fewest mutants (14 of 412 cases; 5 of 654). It is the first rule for step three. KIND is weak on both.
- **Not the same:** HAPPY carries alchemy (67 caught only by it), and BOUNDARY carries rx2cpp (103). That is why one estate is tuned and the other held out.
- **The mutant score alone would remove OMIT, and that would be wrong.** OMIT is an oracle against compiled code (how rx2cpp handles an argument left out), which no mutant tests. So Leg Drop's score must count what each case finds when run compiled, from the rx2cpp lane's compiled test, as well as mutants.
- **Timeouts move between runs.** rx2cpp: 638 killed and 12 timeouts here, 649 together in the first-case run. A keep-or-undo decision must not rest on a timeout.

### Credits for SLAM's finds

SLAM gets credit for what it found:
1. **The Rexx/SQL bound-call leak.** Its whole-estate ingest was killed at 6.1 GB. Fixed: backend patch 0005, commit `cf25e1c3`.
2. **`rx_mod_inverse` returning false numbers or dividing by zero** (12 copies). Found by composing it and breaking the path on purpose. Fixed: commit `1f422d76`.
3. **`FDSqrt` wrong above 10⁶.** Found by its own path choice and a third way. Fixed: commit `3761f57c` (both copies), on ChatGPT's method.
4. **Federation Bank's Java side describes the bank's old late-advice rule.** Found by reading the offline-cash rule in both languages. The ooRexx side was run, and the Java test double was read. Reported, not fixed: which side moves is Tom's call.
5. **SLAM's own ooRexx reader misread `then` on a new line.** Found by reading NetRexx's QTIME beside ooRexx's. Fixed in `SlamClauses`.
6. **Duplicate code in rx2cpp** (`RxStmtIf~branch` = `RxStmtSelect~whenBody`, `BifDefinition~joined` = `RxCppEmitter~body`, `RxNative~kind` = `RxNative~form`). Found by identical code folding ported from BOLT. Reported, not fixed: that is the rx2cpp lane's call.
7. **SLAM's own C++ reader named every libc function `LLVM_LIBC_FUNCTION`, and libc++'s templated functions `>`.** Found by folding libc and libc++: the groups it printed had no names. Fixed in `SlamCppSplitter`.
8. **`FDSqrt`'s error habit in a second package:** `sqrtNumber` in `brand_intervention_effectiveness_v0.2` runs Newton's step a fixed 20 times. Found by searching for the shape of the `FDSqrt` error. PROVED harmless for every input its caller can give (at most 0.9604); DISPROVED as a general square root from 10¹¹. Its tool is not recorded. Reported, not changed.
9. **Code no test reaches in rx2cpp:** `artifacts/v026/nested_calls.cpp` had stopped compiling, and ten functions are defined and used nowhere. Found by `bin/slam_untested.rex`; confirmed by the rx2cpp lane (its syntax check of every file, and by hand). Reported; removing them is the rx2cpp lane's call.
10. **ooRexx's own test groups put the expected value second about 6,000 times.** In `assertEquals` and `assertSame` calls with one literal argument, the literal is first 9,642 times and second 6,019 times (counted over shapes). ooTest reports the first value as expected, so in those calls a failure names expected and actual the wrong way round. Found by reading ooTest's 314 groups and asking the framework which value it calls expected. Reported, not changed.
11. **SLAM's lifter took the next directive into the last routine's body.** A routine just before `::requires` lifted with the `::requires` line, so it could not run alone. 10 of the 71 routines in the standalone pool were affected. Found while writing their tests. Fixed in `SlamComposer~lift`.
12. **SLAM's lifter dropped the file's `::OPTIONS`.** So `addLong('4294967295', '7')` in rx2cpp's `routine_native.cls` (`::options digits 25`) ran at digits 9, and SLAM wrote `4.29496730E+9` as expected. rx2cpp's compiled answer, `4294967302`, is right.
    - Found by SLAM's EDGE cases, run by the rx2cpp lane against rx2cpp-compiled routines (1,323 of 1,327 cases agree; these are the 4 that do not).
    - Fixed in `SlamLift`, the lifter each group carries, and `SlamComposer~lift`: the file's `::OPTIONS` lines go after the body (a leading directive is Error 99.916).
    - The same fault hit alchemy's `crypto.cls` (`::options digits 2000`, 21 pool routines).
    - Rerun on rx2cpp `0187d11`: SLAM_ADDLONG now expects `4294967302`; 416 of 416 groups pass; the mutant score is unchanged (649 against 585).
13. **Body Slam's finds** (Body Slam is SLAM's whole-estate link component: architecture Tom Dyer, code Claude (Opus 5.5)). They are listed in `README_BODYSLAM.md`. Among them:
    - `brand_narrative_directive_v0.1-dev4` cannot load (Error 98.909).
    - 12 requires ooRexx refuses (Error 19.904).
    - `Crypto.cls` is required by a name that fails on Linux.
    - 141 requires name files that are not in the repository.

## Qualification (LOCAL_PASS)

**Polylingual run (2026-10-28, ooRexx 5.3.0 r13196 from Tom's package, OpenJDK 21.0.12.1, g++ with Boost 1.83, NetRexx 5.10 GA, the ooRexx 5.3.0 r13324 source):** the 456 checks below, plus **33/33** in `test_java.rex`, **24/24** in `test_rules.rex`, **29/29** in `test_cpp.rex`, **20/20** in `test_netrexx.rex`, **7/7** in `test_llvm.rex`, **11/11** in `test_fold.rex`, **16/16** in `test_libc.rex` and **24/24** in `test_unit.rex` (2026-10-29, with Tom's ooTest 4.2.0 snapshot 06 and JUnit 4.13.2): **620 checks**. The C++, NetRexx, BOLT, libc and unit-test steps run when `OOREXX_SRC`, `RX2CPP_ROOT`, `NETREXX_HOME`, `SYSUTILS_NRX`, `LLVM_SRC`, `LIBC_SRC`, `OOTEST_ROOT` and `JUNIT_CP` are set, and say SKIP otherwise. **Rerun on a second machine** (2026-10-29, with the Reasoned Thought bridge, the legislation chain, the review fixes, Mr S, the citation gate, the Gemini standard audit, the shared word list and screen, the Fraud and Theft Act rule packs, Body Slam, the law on the date (NSW), and who did it, in a shallow clone: ooRexx built from git `e307068`, OpenJDK 21, g++ with Boost 1.83, rx2cpp `9850473`, NetRexx 5.10 GA, the r13324 source): **562/562**. The BOLT, libc and unit-test steps (58 checks) skipped there: no llvm-project tree, no ooTest.

Environment: Anthropic cloud workspace; ooRexx 5.3.0 built from github.com/ooRexx/ooRexx head `e307068` (2026-10-28; reports `r0` because it was built from git); SQLite 3.45.1; Rexx/SQL 2.6B3 with the Alchemy patches (driver 52/52, backend contract 24/24, keyed select 57 µs).

`sh run_tests.sh`: **60/60** in `test_slam.rex`, **10/10** in `test_compose.rex`, **13/13** in `test_needs.rex`, **16/16** in `test_modinv.rex` (CHECK), **8/8** in `test_choose.rex`, **34/34** in `test_fdsqrt.rex` (CHECK) on each door copy, **17/17** (dev8) and **15/15** (dev5) in `test_fdsqrt_door.rex` (CHECK), and **18/18** in `test_proof.rex`, and **12/12** in `test_ties.rex`, and **19/19** in `test_provenance.rex`, **16/16** in `test_reasoning.rex`, **43/43** in `test_law.rex`, **7/7** in `test_gemini_standard.rex`, and **31/31** in `test_screen.rex`, **16/16** in `test_screen_uk.rex`, **17/17** in `test_screen_dates.rex`, **8/8** in `test_screen_people.rex`, and **62/62** in `test_bodyslam.rex`: 456 checks. It covers:
- the segmenter on unmodified `MLEvolution.cls` (54 units; shared guard nodes; collapsed setters; then/else bodies sharing a node with different bindings);
- ingest of the GA package with duplicate units skipped on re-ingest;
- aabb → Eeff = 0.4 and b00b → Eeff = 0.8 from recorded outcomes;
- a Task finding start > b00b > Eeff (0.72), then flipping to aabb after new evidence (0.63);
- a TESTED-only search BLOCKED where only a prior route exists;
- the corpus loaded as word nodes with definition edges;
- SLAM reading `README_SLAM.md` (134 lines, 1,249 words, 30 new words, none unknown) and its own reply to Claude Fable, while refusing Fable's opening sentence (14 unknown words);
- PRODUCT taking a direct 0.6 edge over a 0.8 × 0.8 × 0.8 route, and BOTTLENECK taking the long route (weakest edge 0.8);
- SELECT identity on a fixture (3-arm and 7-arm string SELECTs are one node; a range SELECT is another);
- evidence weighting: 1 of 1 ranks below 1,000 of 1,000;
- depth and pruning: a 3-edge path is refused at depth 2 (ChatGPT's over-depth claim is not reproduced), and a weak short route that fits depth 3 survives a strong long one (ChatGPT's pruning claim is reproduced, then fixed);
- a composition that exists in no anchor and no code path, "the square root of the mean of the squares of the values" (RMS), checked against a hand-worked answer, √29 = 5.385164807…;
- ChatGPT's letter to SLAM, read with no unknown word, and SLAM's reply about the task, which defines its own 6 new words;
- grounding: an untested anchor is refused, then 28/28 anchor checks pass. Standard deviation and the square root of the variance agree (2). The variance composed from its corpus definition equals the variance anchor (4). Fable's probe "add 3 and 4" gives 7, and "average" is refused.

**Rexx/SQL leak, found and fixed (in the repository as backend patch 0005, commit `cf25e1c3`).** The first whole-estate ingest was killed by the kernel at 6.1 GB. Measured directly against Rexx/SQL: every bound `SQLCOMMAND`/`SQLEXECUTE` leaked about 8 KB, because `stmt->Argv` (2 × 256 `RXSTRING`s) and a copy of each value were freed only on error paths. Unbound calls were clean. Patch 0005 frees the copy once the values are in the statement's own buffers: 10,000 bound inserts went from +94 MB to +12 MB, and prepared executes from +82 MB to +0.1 MB. The Rexx/SQL driver (52/52) and backend contract (24/24) still pass.

**Whole estate** (all of `animatedads/alchemy`, commit `aeafc75e`, on the patched Rexx/SQL):

| | |
|---|---|
| Files segmented | 8,855; 22 skipped, all compiled `.orx` binaries the lexer rightly refuses |
| Units | 46,699 stored; 36,963 duplicates (copies in versioned packages) skipped |
| Segment instances | 401,758 |
| Distinct nodes | 112,490 (76,077 families) |
| Edges | 232,166 |
| Coverage | the top 100 nodes cover 37.4% of all instances, the top 1,000 cover 53.4%, the top 10,000 cover 69.0% |
| Long tail | 74.6% of nodes occur once, but they are only 20.9% of instances |
| Store | 197 MB SQLite; memory flat at about 540 MB once patch 0005 was in |

By kind: RUN 59,926 nodes / 190,047 instances; GUARD 17,453 / 40,893; BRANCH 13,039 / 40,331; EXIT 12,030 / 59,221; LOOP 4,834 / 14,681; ENTRY 3,763 / 38,667. SELECT had only 2 distinct nodes, because a SELECT's identity was its arms' kinds. Fable flagged that identity as too coarse. Now that a SELECT's header includes its arms' conditions, the re-ingested estate has **222** distinct SELECT nodes across 979 uses, with ARM nodes almost unchanged (1,407) and 112,725 nodes in all.

## Run

```sh
sh run_tests.sh
```

With ooRexx not installed system-wide:

```sh
REXX_INCDIR=/path/to/oorexx/include REXX_LIBDIR=/path/to/oorexx/lib LD_LIBRARY_PATH=/path/to/oorexx/lib sh run_tests.sh
```

Ingest and explore (with `LD_LIBRARY_PATH` holding `librexxsql.so` and `REXX_PATH` set as in `run_tests.sh`):

```sh
rexx bin/slam.rex ingest slam.db ../../packages/oorexx_ml_v0.1-dev11
rexx bin/slam.rex stats slam.db
rexx bin/slam.rex follows slam.db '#0004'
```

## Not in v0.1 (stated, not hidden)

- **Contracts are kinds, not values.** The gate catches STRING-into-NUMBER. It cannot catch "these two numbers share a factor"; that need was learned from a failure and is kept as a lesson, not yet as a contract rule.
- **ChatGPT's second task is met at routine level.** Two estate routines from unrelated packages were composed into a path no code contains, run on new data, checked two ways, broken twice, and the failure explained. The path was chosen by hand from contract-compatible candidates. SLAM does not yet *search* the contract graph for such paths on its own, and it does not yet compose segments inside methods.
- **No decomposition yet.** A requirement names its entry and goal nodes; turning English (corpus words) into steps comes next.
- **No GA branch selection or fitness-on-run yet.** The weights it would update are in place.
- **No node tests or exit checks.** Pre/post facts and effects (the `RxFactEmitter` idea) are not extracted yet; v0.1 has shape only.
- **Node ids are database row ids,** so they are stable within one store, not across stores. A content hash (batched SHA-256, as the Semantic Source Store does) is the fix.
- **Unit boundaries come from directives**, not interpreter inspection, because the inspector refuses `::REQUIRES` without a resolver. Internal routines (`label: procedure`) stay inside their unit as LABEL segments.
- **Files the rx2cpp lexer rejects are skipped and listed,** never guessed.
- **Edges are first order.** A node's score depends only on the node before it. Nested control flow breaks that independence. The planned fix is to split an edge by the node before that wherever its results conflict.
- **A passing run says the test passed, not that each edge was right.** Per-node exit checks are planned to put the blame on a specific node.
- **The run cut is a heuristic.** Clauses sharing no variable start a new RUN.
- **A failed turn rolls back the database,** but the in-memory step state is not rewound.
- **Second language, first cut.** Java enum constant bodies and local classes are not read as units. `@interface` types are not recognised.
- **Rules come from GUARDs only.** A check that ends in a block (`then do; signal off; return …; end`) or an accepting BRANCH is not read as a rule. That is why the bank's reconciliation window is not one.
- **Rule matching is on keys.** It finds the ATM's `withdrawOffline`, but not `DemoBankNetwork.offlineWithdrawalAdvice`, as the closest match to `validateAdvice`. The demo reads the presented values by key and holds the authority's values as fields, the reverse of the other two. Matching with the roles swapped is the fix.
- **The conversions SLAM reads through are a short fixed list** (`~string`, `+ 0`, `valueOf`, `parse…`). It is stated in `SlamRules.cls`.
- **C++, first cut.** Types are guessed from position (a name before a name, before `::`, or before `*x =`); there is no symbol table. Macro bodies are not read.
- **The BIF contract vocabulary is stated, not learned.** It is the words in `tests/bif/BifContracts.cls`; SLAM's wrong predictions are what found the two it lacked.
- **rx2cpp's generated C++** is read as runtime calls, so it does not meet its ooRexx source yet (see the C++ section).
- **NetRexx, first cut.** `catch`/`finally` inside `do`/`loop` are plain clauses. `java2nrx` (Java to NetRexx, the other direction) is not paired yet. `sysutils.nrx` against ooRexx's RexxUtil (C++) is a three-language triangle not yet compared.
- **Speed: about 770 source lines a second**, because the lexer runs interpreted. Compiling the lexer with rx2cpp is the obvious speed-up.
