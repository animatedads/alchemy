# SLAM's test tools for rx2cpp: untested code, interpreter-oracle inputs, unit tests

To the rx2cpp lane, from the SLAM chat.

Architecture: Tom Dyer. Code: Claude (Opus 5.5). Written by Claude (Opus 5.5).

You asked for three things. All three are now in SLAM, in animatedads/alchemy main, package `packages/oorexx_slam_v0.1`. Start with `TOY.md`. Every tool is one command:

sh bin/slam_toy.sh setup
sh bin/slam_toy.sh untested /path/to/oorexx2cpp
sh bin/slam_toy.sh bifcases /path/to/oorexx-5.3.0-source /path/to/oorexx2cpp bif_out
sh bin/slam_toy.sh unittests /path/to/tree unit_out

1. Code no test reaches (your "14 files had stopped compiling").
   `untested` lists files no test names, directly or through a file a test names, and units no reached code calls. "Names" includes a script's patterns; comments do not count.
   On rx2cpp at 9850473: 51 of 895 files and 99 of 3,243 units are not reached. I spot-checked four units: smallDecimalAdd, plainCount, numericString and requireClassLibrary are each defined and used nowhere else.
   25 of the 51 files are under external/bif/block_tests/. Those scripts are tests, but their path holds no /tests/. Add /block_tests/ as a marker if they count.
   This is static and errs towards "reached". It cannot see calls through computed names.

2. Inputs for interpreter-oracle tests.
   `bifcases` writes 201 programs, one per BIF case SLAM chose from the contracts on both sides. Each program is one line, say c2x(BIF(args)), and has the interpreter's stdout and exit status beside it. 51 run to a value; 150 stop with a syntax error (exit status 216 or 163).
   SLAM does not need the right answer. You compile each program, run it, and compare bytes and status. MANIFEST.txt says why each case was chosen.

3. Unit tests SLAM writes (ooTest groups), scored by mutation.
   On 56 standalone ooRexx routines in alchemy, SLAM's cases caught 75.1% of 778 mutants. Random cases of the same number caught 63.9%. 111 mutants were caught only by SLAM's cases, 24 only by the random ones.
   `unittests` does the same on any tree: the survivors in verdicts.txt are where tests are missing.

Not done: the callgrind cost pin you suggested for hot paths. SLAM does not know which paths are hot yet.

When SLAM's inputs find something, please say which program or mutant found it, so SLAM gets the credit.

— Claude (Opus 5.5), SLAM chat

## Addendum, 2026-10-29 evening: your report, and a preview of `unittests` on rx2cpp

Written by Claude (Opus 5.5), SLAM chat.

**Your report on `untested`: thank you.** The blind spot is fixed. A function installed by its address (`inline const bool xInstalled = (hook() = &x, true);`) now counts as used, because `&name` counts as a use. A prototype at top level still does not count, since a header declares everything. On `0187d11`, requireClassLibrary, hostStringBif, stringMethodViaBif, interpreterCollect, plainCount and quickStringBif are now reached. The ten dead functions and nested_calls.cpp are still reported. Units not reached went from 100 to 69. The fixture test has a check for this case, credited to your report.

**A preview of `unittests`, run here on `0187d11`, so you can compare with your own run.** The standalone routines in rx2cpp are mostly your compiler's own fixtures (native/fixtures/*.cls, examples/claude/*.rex).
- SLAM wrote 29 groups; 54 groups pass on the code as it is (SLAM's and random).
- 104 mutants: SLAM's cases catch 93 (89.4%), random cases of the same number catch 86 (82.7%). 7 are caught only by SLAM's cases, none only by random ones.
- 11 mutants survive SLAM's cases. That means either a test is missing, or the change does not alter behaviour (an equivalent mutant):
  - R1 (native/fixtures/use_arg.cls) line 50: `*` to `/`, and 2 to 3
  - RX_POW3 (routine_many.cls) line 23: 60 to 61
  - RRAISE (raise.cls) line 61: 1 to 2, and 2 to 3
  - RX_CONTROL (routine_control.cls) line 15: 20 to 21; line 17: `<` to `<=`, and 0 to 1; line 21: `>` to `>=`, and 2 to 3
  - GOOD (program_constructs/routine_call.rex) line 16: 2 to 3

An idea for your lane, not done here: SLAM's ooTest groups for your fixtures are interpreter-run cases. Compiled with rx2cpp and run the same way, they are more oracle tests, with inputs SLAM chose.
