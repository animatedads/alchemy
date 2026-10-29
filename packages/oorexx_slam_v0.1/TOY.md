# SLAM's test tools, to run on your own code

Architecture: Tom Dyer. Code: Claude (Opus 5.5). Written by Claude (Opus 5.5), 2026-10-29.

SLAM reads code into nodes and edges, and can now pick test inputs and write unit tests. This page is for a lane (for example rx2cpp) that wants to run that on its own tree. Every step is one command. Run the commands from this package's directory (`packages/oorexx_slam_v0.1` in the alchemy repo).

## What you need

- ooRexx 5 with `rexx` on PATH, plus gcc, make, patch and the SQLite 3 development files.
- For `unittests`: an unzipped ooTest snapshot (the folder holding `ooTest.frm` and `framework/`). Set `OOTEST_ROOT` to it.
- For `bifcases`: an ooRexx source tree (holding `interpreter/`) and an rx2cpp tree (holding `external/bif/`).

## Step 1: build the database library (once)

```sh
sh bin/slam_toy.sh setup
```

This puts `librexxsql.so` in `$HOME/.slam_toy/lib`. To put it somewhere else, set `SLAM_TOY_LIB` first.

## Step 2: what no test reaches

```sh
sh bin/slam_toy.sh untested /path/to/oorexx2cpp > untested.txt
```

The report lists files that no test names, directly or through a file a test names (`FILE` lines). It then lists routines, methods and C++ functions in reached files whose name no reached code uses (`UNIT` lines).

- A test is any file whose path holds `/tests/`, `/test/`, `/ootest/`, `test_` or `.testGroup`. To use other markers, give them after the root: `sh bin/slam_toy.sh untested /path/to/tree /qualification/ run_`
- The report errs towards "reached": a name two units share reaches both.
- It cannot see calls made through a computed name (interpret, function pointers). Check those `UNIT` lines by hand.
- On rx2cpp `0187d11`: 895 files, 51 not reached; 3,261 units in reached files, 69 not reached. The rx2cpp lane confirmed `artifacts/v026/nested_calls.cpp` (it no longer compiles) and ten dead functions. It also found that functions installed by address (`hook() = &x`) were wrongly reported; `&name` now counts as a use.
- 25 of the 51 are under `external/bif/block_tests/`, whose own scripts are tests but whose path does not hold `/tests/`. To count them, add the marker: `sh bin/slam_toy.sh untested /path/to/oorexx2cpp /tests/ /test/ /ootest/ test_ .testGroup /block_tests/`

## Step 3: inputs for interpreter-oracle tests

```sh
sh bin/slam_toy.sh bifcases /path/to/oorexx-5.3.0-source /path/to/oorexx2cpp bif_out
```

SLAM reads the BIF contracts on both sides (the interpreter's `BuiltinFunctions.cpp` and the native pack's `rxbif.cpp`). It then chooses 201 cases: the lane's own case, one argument too few and one too many, -1, 0 and a word for counts, and two-character pads. It writes one program per case, `bif_out/programs/slam_bif_NNN.rex`, each one line: `say c2x(BIF(args))`. Each program's interpreter stdout and exit status are in `bif_out/programs/expected/`.

The test: compile each program with rx2cpp, run it, and compare stdout bytes and exit status with `expected/`. SLAM does not know the right answers; it picks the inputs. `bif_out/programs/MANIFEST.txt` says why each case was chosen and what SLAM predicted.

## Step 4: unit tests SLAM writes, and how good they are

```sh
export OOTEST_ROOT=/path/to/ooTest-4.2.0-snapshot06
sh bin/slam_toy.sh unittests /path/to/your/tree unit_out
```

1. It finds the standalone ooRexx routines (pure, builtin classes only, at least one argument). The list goes to `unit_out/pool.txt`.
2. For each routine it writes an ooTest group, `unit_out/groups/SLAM_<NAME>.testGroup`, with these cases:
   - HAPPY: every rule SLAM can work out holds.
   - BOUNDARY: c-1, c and c+1 for each guard that compares an input with a constant c; for a string constant, the constant and one other string.
   - LITERAL: each string the routine's code holds, given to each string argument.
   - KIND: a word given to an argument used as a number.
3. Where a guard stops with a constant (`return 0`, `return .false`, `raise syntax n`), SLAM predicts the outcome before running. Otherwise it runs the routine twice and records what it does. A case that differs between the two runs is not written.
4. Each group also gets a random-input group of the same size, `RAND_<NAME>.testGroup`, for comparison.
5. Every group must pass on the code as it is; the command says how many do.
6. It then makes mutants: one changed operator or number each, in a copy of the file. It runs both suites on each mutant and writes `unit_out/score.txt`:
   - `KILLED SLAM n` and `KILLED RAND n`: how many mutants each suite catches.
   - `ONLY SLAM n`: mutants only SLAM's tests catch.
   - `grep SURVIVED unit_out/verdicts.txt`: mutants neither suite catches. These are where tests are missing.

A group tests the file as it is now: it lifts the routine from its file each time it runs. To run one group by hand:

```sh
cd unit_out/groups
REXX_PATH=$OOTEST_ROOT:$OOTEST_ROOT/framework rexx SLAM_<NAME>.testGroup
```

## What to send back

When SLAM's inputs find something (a native output that is not byte-identical, or a mutant that survives where it should not), please say which case or mutant found it. SLAM gets the credit for its finds.
