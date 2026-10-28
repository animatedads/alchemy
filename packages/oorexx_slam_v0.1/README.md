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
| `src/SlamCpp.cls` | Third language: C++ lexer (preprocessor lines dropped, raw strings), splitter (namespaces, `Class::m` outside its class, macro-made `NAME(X) { }`), shaper; Java's statement parser |
| `src/SlamNetRexx.cls` | Fourth language: NetRexx, written as ooRexx tokens (`a.b` is `a~b`, `this` is `self`, `null` is `.nil`, `loop` is `DO <LOOP>`), read by the ooRexx parser and shaper |
| `src/SlamLanguages.cls` | Which reader a file needs, by extension |
| `src/SlamFold.cls` | Identical code folding over the store, ported from BOLT's IdenticalCodeFolding: congruent buckets, identical folds, repeated to a fixpoint |
| `src/SlamRules.cls` | Rules read the same way in ooRexx and Java (what a GUARD makes MUST hold); keyed readers found by behaviour; RULE nodes; predicting a rule's outcome |
| `bin/slam.rex` | `ingest` (ooRexx and Java), `corpus`, `read`, `facts`, `about`, `ground`, `ask`, `stats`, `node`, `follows`, `into`, `record` |
| `README_SLAM.md` | This README in SLAM's own words: SLAM reads it with no unknown word |
| `corpus/` | The circular corpus plus closure, grounding-distance and sentence checks |
| `reference/` | The ooRexx 5 reference (rexxref) as facts in SLAM's words, with 1,167 examples run on ooRexx 5.3.0: see `reference/README.md` |
| `tests/test_slam.rex` | 58-check qualification |
| `tests/test_compose.rex` | ChatGPT's task on real estate routines, 6 checks |
| `tests/test_needs.rex` | Ability before score on real contracts (rule proposed by Claude (Opus 4.8)), 13 checks |
| `tests/test_modinv.rex` | `rx_mod_inverse` before/after/check harness (16 checks in CHECK mode) |
| `tests/test_choose.rex` | SLAM chooses its own path from 71 standalone routines (8 checks) |
| `tests/test_fdsqrt.rex` | `FDSqrt` before/after/check: small and large data through three ways (34 checks in CHECK mode) |
| `src/SlamProof.cls` | PROVED, DISPROVED or INDETERMINATE: certificates checked in exact rationals (ooRexx Maths v0.8, CERTIFIED route, pure ooRexx); each answer is a Maths `MathProof` |
| `tests/test_proof.rex` | The PROVED tier on `FDSqrt` (now and before), `rx_mod_inverse` and the contract gate (18 checks) |
| `tests/fixtures/fdsqrt_fixed14.cls` | `FDSqrt` as it was before `3761f57c`, so its old results can be proved false |
| `tests/test_fdsqrt_door.rex` | The door code that calls `FDSqrt`: noise sigmas, pixel sigma, gradient size (17 checks on dev8, 15 on dev5) |
| `tests/fdsqrt_sweep.rex` | Old against new `FDSqrt` on random door-range values |
| `evidence/fdsqrt/` | The before and after data for the `FDSqrt` change, kept as ChatGPT asked |
| `tests/test_java.rex` | The Java reader: lexer, a javac-compiled fixture, the Federation Bank ATM, one store with both languages, Task on Java nodes (33 checks) |
| `tests/test_rules.rex` | One rule, two languages: the Federation Bank offline-cash rule in the ooRexx engine and the Java ATM, predicted then run (24 checks) |
| `tests/rules/` | `OfflineRuleProbe.java` runs the real Java ATM, `offline_rule_probe.rex` the real ooRexx bank, on the cases SLAM chose |
| `tests/test_cpp.rex` | C++: lexer, a g++-checked fixture, the interpreter's `BuiltinFunctions.cpp`, three languages in one store, BIF contracts from two C++ codebases predicted and run (24 checks) |
| `tests/bif/` | BIF contract reader for the interpreter and the rx2cpp native pack; case generator; a runner for each side |
| `tests/test_netrexx.rex` | NetRexx: lexer, `sysutils.nrx`, QTIME in NetRexx and ooRexx run through a day, NetRexx -> Java translation edges predicted on held-out files (20 checks) |
| `tests/netrexx/` | Runs NetRexx's `qtime.nrx` and ooRexx's `qtime.rex` at the same 206 times; translates every NetRexx example with NetRexxC and learns NetRexx -> Java translation edges (`translate_all.sh`, `translate_pairs.rex`) |
| `tests/test_llvm.rex` | Compiler code: BOLT read whole; next-segment prediction on held-out BOLT and on rx2cpp's ooRexx (7 checks) |
| `tests/llvm/next_node.rex` | Next-segment prediction at KIND, SKELETON and FAMILY level, with and without context, scored in SQL against a baseline |
| `tests/test_fold.rex` | Identical code folding on a fixture, on BOLT's source and on rx2cpp (10 checks) |
| `tests/show_rules.rex` | Read a unit's rules, find the other language's closest units, list what both have and what each lacks |
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
- **Lexer.** Preprocessor lines and their `\` continuations are dropped. A raw string `R"d(...)d"` is one STRING. `if constexpr` reads as `if`.
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
| BOLT | 274 read, none skipped (257 hold code) | 4,060 | 18,470 | 82 s |
| Clang `lib` + `include` (1.9M lines) | 2,567 read, none skipped (2,091 hold code) | 77,497 | 271,179 (554,133 segments) | 1,730 s |

"Learning a technique" is made measurable in two ways.

**1. How compiler code is written: predicting the next segment in code SLAM has not seen.** SLAM's edges ("after this node, that node", with counts) are learned from some files and predict the next segment in held-out ones (every fifth file by a fixed path checksum; `tests/llvm/next_node.rex`). Three levels:
- **KIND:** RUN, GUARD, LOOP, and so on.
- **SKELETON:** the kind plus how it stops or what it holds, such as `GUARD:continue` or `BRANCH{THEN=RUN,EXIT}`. Rexx's `leave`/`iterate`/`raise` count as `break`/`continue`/`throw`, so this level is the same in every language.
- **FAMILY:** the shape with names abstracted.

A `+` variant also conditions on the enclosing segment, which SLAM's `<START:ctx>` markers already record. The baseline is the most common segment.

| Learned from → predicting | Level | SLAM | Baseline |
|---|---|---|---|
| BOLT → held-out BOLT (5,084 segments) | KIND / KIND+ | 52.4% / **58.4%** | 49.4% |
| | SKELETON / SKELETON+ | 50.6% / **55.7%** | 49.4% |
| | FAMILY / FAMILY+ | 5.0% / 5.8% | 1.7% |
| Clang → held-out Clang (99,194 segments) | KIND / KIND+ | 47.0% / **60.7%** | 39.0% |
| | SKELETON / SKELETON+ | 44.5% / **56.9%** | 39.0% |
| | FAMILY / FAMILY+ | 9.3% / **10.2%** | 2.0% |
| **Clang → BOLT** (the same held-out BOLT files) | KIND / KIND+ | 52.4% / **58.6%** | 49.4% |
| | SKELETON+ | **56.1%** | 49.4% |
| | FAMILY+ | 3.5% | 1.7% |
| rx2cpp → held-out rx2cpp's ooRexx (3,397) | KIND+ | **81.6%** | 76.9% |
| **BOLT's C++ → rx2cpp's ooRexx** | KIND / KIND+ | 76.6% / **80.2%** | 76.9% |
| | SKELETON+ | **79.4%** | 76.9% |
| **Clang's C++ → rx2cpp's ooRexx** | KIND / KIND+ | 77.2% / **80.4%** | 76.9% |
| | SKELETON+ | **79.5%** | 76.9% |

What this shows:
- **First-order edges hardly beat "mostly a RUN comes next".** That is the limit this README already states.
- **The enclosing segment helps,** in every case.
- **Structure learned from one C++ compiler predicts another as well as that compiler's own files do.** Clang → BOLT scores 58.6% at KIND+ and 56.1% at SKELETON+; BOLT's own other files score 58.4% and 55.7%. Only FAMILY drops (3.5% against 5.8%), because names do not carry over.
- **The structure transfers across languages.** What SLAM learned from BOLT's or Clang's C++ beats the baseline on rx2cpp's ooRexx, a compiler in another language by other people: 80.2% and 80.4% against 76.9%. From BOLT it recovers 69% of the gain rx2cpp's own files give (111 of 161 segments over the baseline). Without context it does not transfer.
- **Clang is the reproducible-by-hand part.** Its ingest takes 29 minutes, so `run_tests.sh` checks BOLT and rx2cpp. The Clang rows come from `rexx tests/llvm/next_node.rex` on a Clang store made with `rexx bin/slam.rex ingest`, as in the BOLT step. That store was made before literals were stored, so Clang was not folded.

**2. A technique read from BOLT and applied: identical code folding** (`SlamFold.cls`). BOLT's `IdenticalCodeFolding.cpp` hashes functions ignoring symbol operands, buckets the congruent ones, folds the identical ones in each bucket (a call to a folded function counting as a call to its parent), and repeats until a pass folds nothing. SLAM already had the parts: FAMILY is "names abstracted", which is BOLT's congruence, and FINE is identity. Token-identical units are skipped at ingest, so what folds here is the same code under other names. Two things were needed to match BOLT:
- **Literal values.** Shapes abstract them to `S` and `N`; BOLT compares constants exactly. Each instance now stores its literals (`instance.consts`, added to older stores when opened).
- **Renames apply from the next pass,** so the passes do not depend on bucket order.

Results:
- **The fixture** folds 1, 1, 0: `areaB` → `areaA`, then `totalB` → `totalA`, which is identical only once `areaB` is folded. `y + 2` is not `y + 1`.
- **On BOLT's own source**, 392 units fold in the first pass, 8 in the second (callers identical only after their callees fold), then none. All are small accessors (`successors`/`throwers`/`landing_pads` into `predecessors`). At 5 segments or more nothing folds: BOLT is well factored.
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

### Credits for SLAM's finds

SLAM gets credit for what it found:
1. **The Rexx/SQL bound-call leak.** Its whole-estate ingest was killed at 6.1 GB. Fixed: backend patch 0005, commit `cf25e1c3`.
2. **`rx_mod_inverse` returning false numbers or dividing by zero** (12 copies). Found by composing it and breaking the path on purpose. Fixed: commit `1f422d76`.
3. **`FDSqrt` wrong above 10⁶.** Found by its own path choice and a third way. Fixed: commit `3761f57c` (both copies), on ChatGPT's method.
4. **Federation Bank's Java side describes the bank's old late-advice rule.** Found by reading the offline-cash rule in both languages. The ooRexx side was run, and the Java test double was read. Reported, not fixed: which side moves is Tom's call.
5. **SLAM's own ooRexx reader misread `then` on a new line.** Found by reading NetRexx's QTIME beside ooRexx's. Fixed in `SlamClauses`.
6. **Duplicate code in rx2cpp** (`RxStmtIf~branch` = `RxStmtSelect~whenBody`, `BifDefinition~joined` = `RxCppEmitter~body`, `RxNative~kind` = `RxNative~form`). Found by identical code folding ported from BOLT. Reported, not fixed: that is the rx2cpp lane's call.

## Qualification (LOCAL_PASS)

**Polylingual run (2026-10-28, ooRexx 5.3.0 r13196 from Tom's package, OpenJDK 21.0.12.1, g++ with Boost 1.83, NetRexx 5.10 GA, the ooRexx 5.3.0 r13324 source):** the 219 checks below, plus **33/33** in `test_java.rex`, **24/24** in `test_rules.rex`, **24/24** in `test_cpp.rex`, **20/20** in `test_netrexx.rex`, **7/7** in `test_llvm.rex` and **10/10** in `test_fold.rex`: **337 checks**. The C++, NetRexx and BOLT steps run when `OOREXX_SRC`, `RX2CPP_ROOT`, `NETREXX_HOME`, `SYSUTILS_NRX` and `LLVM_SRC` are set, and say SKIP otherwise. **Rerun on a second machine** (2026-10-28, with the PROVED tier, after merging the BOLT commit: ooRexx built from git `e307068`, OpenJDK 21, g++ with Boost 1.83, rx2cpp `9850473`, NetRexx 5.10 GA, the r13324 source): **320/320**. The BOLT steps (17 checks) skipped there: no llvm-project tree.

Environment: Anthropic cloud workspace; ooRexx 5.3.0 built from github.com/ooRexx/ooRexx head `e307068` (2026-10-28; reports `r0` because it was built from git); SQLite 3.45.1; Rexx/SQL 2.6B3 with the Alchemy patches (driver 52/52, backend contract 24/24, keyed select 57 µs).

`sh run_tests.sh`: **58/58** in `test_slam.rex`, **6/6** in `test_compose.rex`, **13/13** in `test_needs.rex`, **16/16** in `test_modinv.rex` (CHECK), **8/8** in `test_choose.rex`, **34/34** in `test_fdsqrt.rex` (CHECK) on each door copy, **17/17** (dev8) and **15/15** (dev5) in `test_fdsqrt_door.rex` (CHECK), and **18/18** in `test_proof.rex`: 219 checks. It covers:
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
