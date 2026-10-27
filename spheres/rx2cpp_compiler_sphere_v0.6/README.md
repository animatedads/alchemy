# rx2cpp compiler sphere v0.6

Knowledge and continuity sphere for **rx2cpp**, the ooRexx 5.3 to C++17 compiler
(github.com/animatedads/oorexx, folder `oorexx2cpp`).

Architecture: Tom Dyer. Coding: ChatGPT and Claude. Sphere written by Claude (Opus 5.5).

Grounded baseline:
- commit `e3d8d0024943565eb3d247b2c02a8a955f6a7f01` (main: the merge of `wip-2026-10-13` after the full regression and self-build passed)
- artifact `rx2cpp-e3d8d00.zip`, made with
  `git archive --format=zip e3d8d00 oorexx2cpp > rx2cpp-e3d8d00.zip`
- SHA-256 `1f97f04319128f03bfba1139ba0e8e67c505823223352e605a55c8063947e16e`

Every article's `provenance[]` names a member of that archive (with lines where the claim is a section).
The archive is not vendored here; regenerate it from the repository with the command above and check the digest.

This sphere is documentation/continuity, not the compiler. It inherits the shared ooRexx source-navigation
services of the `oorexx` sphere.

Start:

    gopher --profile rx2cpp context rx2cpp --full
    gopher --profile rx2cpp search 'security manager' --sphere rx2cpp

Articles: start, build-and-run, qualification, lanes, epoch, environment-symbols, security-managers,
performance, known-differences, interpreter-bugs, people-and-upstream. Corpora: rx2cpp.lessons, rx2cpp.continuity.
