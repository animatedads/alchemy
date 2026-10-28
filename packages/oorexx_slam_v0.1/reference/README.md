# The ooRexx reference in SLAM's words

**Architecture:** Tom Dyer.
**Translation, code and tools:** Claude (Opus 5.5), 2026-10-28, with nine Claude (Opus 5.5) workers, one per part of the reference.
**Source:** *Open Object Rexx Reference* (rexxref) for ooRexx 5, read from the HTML copy at https://rexx.epbcn.com/rexxref/ (SourceForge, the original home, was not reachable from the authoring container). The rexxref is © its authors under the Common Public License 1.0.
**Interpreter used to run the examples:** ooRexx 5.3.0 r13196 (Tom Dyer's build, `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb`).

## What this is

The ooRexx reference rewritten as **facts SLAM can read**: every word outside code is a corpus word or a word
these files define first, with a `word: definition` line built only from words SLAM already knows. Names
(`SUBSTR`, `PARSE ARG`, `.String~pos`, `::CLASS`, `Error 40`) stay in code blocks, as `README_SLAM.md` does
with `FDSqrt`. Every claim the reference shows with an example carries that example in Tom's runnable form:
`the code:`, `the result:` (what ooRexx 5.3.0 printed), `the reference says:`.

| File | From the reference | Facts | Examples |
|---|---|---|---|
| `00_words.md` | the base words: string, character, argument, method, class, object, ... (280 words) | 281 | – |
| `01_concepts.md` | 1. general concepts: syntax, tokens, every operator, precedence, symbols, stems, environment symbols | 563 | 71 |
| `02_instructions_a.md` | 2. ADDRESS to LOOP; DO and LOOP in eight forms each; appendix A | 346 | 22 |
| `02_instructions_b.md` | 2. NOP to USE, with TRACE options | 326 | 16 |
| `03_directives.md` | 3. the nine directives | 278 | 8 |
| `04_objects.md` | 4, 6, 12. classes and methods, runtime objects, concurrency | 334 | 18 |
| `05_string_class.md` | 5. String (108 blocks) and MutableBuffer (52) | 924 | 441 |
| `06_classes.md` | 5. Object, Class, the collection classes, Supplier, Stream, Message, Method, Routine, Package, sorting | 1964 | 122 |
| `07_functions_a.md`, `07_functions_b.md` | 7. all 83 builtin functions | 474 + 591 | 203 + 191 |
| `08_rexxutil_a.md`, `08_rexxutil_b.md` | 8. RexxUtil: all 74 functions, and the deprecated ones (B.2.1, B.2.2, B.1.1); each Windows, Linux or Unix only function says so | 540 + 520 | 39 + 34 |
| `09_parsing.md` | 9. parsing | 105 | 26 |
| `10_numbers.md` | 10, 16, 17. numbers and arithmetic, reserved keywords, special variables | 166 | 39 |
| `11_conditions.md` | 11. conditions and condition traps | 168 | 3 |
| `14_streams.md` | 14. input and output streams | 124 | 3 |
| `19_errors.md` | C. error numbers 3 to 99 | 108 | 4 |

All files together: **1,070 words, 7,809 facts, 1,240 examples, 1,347 subjects.**
Not covered: the utility classes of 5.4 other than MutableBuffer, the security manager (13), debugging aids (15),
useful services (18).

**Platforms.** `00_words.md` defines `platform`, `windows`, `unix` (any platform that is not Windows) and `linux`.
A thing the reference gives for one platform has the fact line `this function runs only on the windows platform.`
(or linux, or unix), and each of its examples starts with `/* platform: windows */`; `run_examples.rex` runs
it only there and elsewhere writes `not run: this example is for the windows platform`.

## How to use it

From `packages/oorexx_slam_v0.1`, with the environment of `run_tests.sh`, ONE database for all files:

```
sh reference/ingest_reference.sh ref.db
rexx bin/slam.rex about ref.db SUBSTR
rexx bin/slam.rex about ref.db 'STREAM OPEN'
```

`ingest_reference.sh` loads the corpus, reads `README_SLAM.md`, then runs `facts` on each file in order and
stops at the first file SLAM can not read. Each file ends with `i know each word here. i can read all of it.`

`facts DB DOC` (new in `bin/slam.rex`) first runs `read`; only if every word is known does it store each fact
line as a FACT unit under its subject (its word sequence goes through `ingestSeq`, so facts also give word to
word edges), and each example as an EXAMPLE, a RESULT and a REFERENCE unit with the same line number.
`about DB SUBJECT` lists them.

## The examples were run

```
rexx reference/run_examples.rex reference/01_concepts.md
python3 reference/tools/differences.py
```

`run_examples.rex` runs each example alone (a new empty folder, a small environment, no input, ten seconds) and writes what it printed into
its `the result:` block (for an error, the error number only). On ooRexx 5.3.0 r13196:

| | Examples |
|---|---|
| ooRexx prints what the reference says | **802** |
| ooRexx prints something else | **205** (each one in `DIFFERENCES.md`) |
| the reference states no result | **198** |
| for another platform (not run on Linux) | **35** |

A difference is a lesson, not a verdict. Causes seen so far: a page sets a variable in its prose and not in its
code (`ARG`, `CHARIN(myfile)`); output that changes from run to run (`DATE`, `TIME`, `RANDOM`); a reference
result written as an object (`.true`) or with quotes the page lost; and some that look like real differences
between the reference and the interpreter. `test_reference.rex` (planned, in the other chat) can store each one as
a TESTED or a false lesson.

Before the run, `tools/normalize_examples.py` made three changes from the reference's own text: a `.true` /
`.false` reference result for a SAY became `1` / `0`; a SAY with a hex reference result `'hh'x` became
`say c2x(...)`; an example that uses a variable an earlier example of the same subject sets got that line first,
marked `/* setup from the example before */`. Nineteen BITAND/BITOR/BITXOR/D2C examples whose output is not
text were changed to `say c2x(...)` by hand, with the hex taken from the reference's own comments.

## What to know before you trust it

- **Syntax lines are rebuilt, not copied.** The site draws every syntax diagram as an image. Each syntax line
  is built from the argument names in the page text. The 62 builtin functions the interpreter source
  (`interpreter/expression/BuiltinFunctions.cpp`, ooRexx git head 2026-10-28) declares with fixed limits
  all match their minimum and maximum argument counts.
- **The text came through WebFetch,** which gives the facts of a page, not the page word for word. Every fact is
  from a page; facts a worker found unclear were left out (each worker listed them).
- **Same word, two definitions.** A word some file defines again (e.g. `address`, `numeric`) keeps the first
  definition; SLAM reads the later line as a fact line, and it passes because its words are known.

## Tools

| Tool | What it is for |
|---|---|
| `run_examples.rex` | Runs the examples and writes the results. ooRexx, part of the package. |
| `ingest_reference.sh` | Puts all files into one SLAM database with SLAM's own reader. |
| `FORMAT.md` | The rules a model follows to write or change a fact file. |
| `tools/slam_read_check.py` | A line-for-line copy of `readDoc` in Python. It exists because the files were written in a container with no ooRexx; SLAM's own `read` is the authority. Keep it or drop it. |
| `tools/to_runnable.py`, `tools/normalize_examples.py` | One-off rewrites of the example blocks (old `code -> result` form to Tom's form; the three fixes above). |
| `tools/subjects.py` | Shows the subjects `facts` will give a file, without ooRexx. |
| `tools/topo_defs.py` | Puts `word:` lines in an order where each uses only known words. |
| `tools/differences.py` | Writes `DIFFERENCES.md` from the run reports. |

## A finding about `read`

`readDoc` skips numerals in text lines but not in definition lines: `digit: one number from 0 to 9` fails. The
definitions here spell numbers as words. Found by Claude (Opus 5.5) in `bin/slam.rex` while writing these files;
not changed, because it is SLAM's rule to change, not this package's.
