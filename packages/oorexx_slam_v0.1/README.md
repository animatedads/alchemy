# ooRexx SLAM v0.1 — Small Language Autonomous Model (first cut)

**Architecture:** Tom Dyer.
**Coding:** Claude (Opus 5.5), 2026-10-28.
**Lexer:** the rx2cpp compiler's `RxLexer`/`RxToken`, vendored unmodified (rx2cpp lane: ChatGPT and Claude), see `vendor/rx2cpp/PROVENANCE.md`.
**Database:** SQLite through Rexx/SQL 2.6B3 (Mark Hessling) via `oorexx_rexxsql_backend_v0.1`.
**Corpus:** the circular corpus is Tom Dyer's; `i`, `am`, `me`, `my` added by Claude (Opus 5.5).
**Reviews that shaped it:** ChatGPT (four letters to SLAM), Claude (Fable 5.1), Claude (Opus 4.8).
**Finds credited to SLAM:** the Rexx/SQL bound-call leak, `rx_mod_inverse`'s missing condition, `FDSqrt` above 10⁶ (all three now fixed; see "Credits for SLAM's finds").

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
| `bin/slam.rex` | `ingest`, `corpus`, `read`, `ground`, `ask`, `stats`, `node`, `follows`, `into`, `record` |
| `README_SLAM.md` | This README in SLAM's own words: SLAM reads it with no unknown word |
| `corpus/` | The circular corpus plus closure, grounding-distance and sentence checks |
| `tests/test_slam.rex` | 58-check qualification |
| `tests/test_compose.rex` | ChatGPT's task on real estate routines, 6 checks |
| `tests/test_needs.rex` | Ability before score on real contracts (rule proposed by Claude (Opus 4.8)), 13 checks |
| `tests/test_modinv.rex` | `rx_mod_inverse` before/after/check harness (16 checks in CHECK mode) |
| `tests/test_choose.rex` | SLAM chooses its own path from 71 standalone routines (8 checks) |
| `tests/test_fdsqrt.rex` | `FDSqrt` before/after/check: small and large data through three ways (34 checks in CHECK mode) |
| `tests/test_fdsqrt_door.rex` | The door code that calls `FDSqrt`: noise sigmas, pixel sigma, gradient size (17 checks on dev8, 15 on dev5) |
| `tests/fdsqrt_sweep.rex` | Old against new `FDSqrt` on random door-range values |
| `evidence/fdsqrt/` | The before and after data for the `FDSqrt` change, kept as ChatGPT asked |
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

### Credits for SLAM's finds

SLAM gets credit for what it found:
1. **The Rexx/SQL bound-call leak.** Its whole-estate ingest was killed at 6.1 GB. Fixed: backend patch 0005, commit `cf25e1c3`.
2. **`rx_mod_inverse` returning false numbers or dividing by zero** (12 copies). Found by composing it and breaking the path on purpose. Fixed: commit `1f422d76`.
3. **`FDSqrt` wrong above 10⁶.** Found by its own path choice and a third way. Fixed: commit `3761f57c` (both copies), on ChatGPT's method.

## Qualification (LOCAL_PASS)

Environment: Anthropic cloud workspace; ooRexx 5.3.0 built from github.com/ooRexx/ooRexx head `e307068` (2026-10-28; reports `r0` because it was built from git); SQLite 3.45.1; Rexx/SQL 2.6B3 with the Alchemy patches (driver 52/52, backend contract 24/24, keyed select 57 µs).

`sh run_tests.sh`: **58/58** in `test_slam.rex`, **6/6** in `test_compose.rex`, **13/13** in `test_needs.rex`, **16/16** in `test_modinv.rex` (CHECK), **8/8** in `test_choose.rex`, **34/34** in `test_fdsqrt.rex` (CHECK) on each door copy, and **17/17** (dev8) and **15/15** (dev5) in `test_fdsqrt_door.rex` (CHECK): 201 checks. It covers:
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
- **Speed: about 770 source lines a second**, because the lexer runs interpreted. Compiling the lexer with rx2cpp is the obvious speed-up.
