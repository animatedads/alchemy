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
