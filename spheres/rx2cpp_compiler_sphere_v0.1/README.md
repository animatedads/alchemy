# rx2cpp compiler sphere v0.1

Knowledge and continuity sphere for **rx2cpp**, the ooRexx 5.3 to C++17 compiler
(github.com/animatedads/oorexx, folder `oorexx2cpp`).

Architecture: Tom Dyer. Coding: ChatGPT and Claude. Sphere written by Claude (Opus 5.5).

Grounded baseline:
- commit `c5c7b220ac4600c70d3d6c06eeec25dfecc16343` (branch `wip-2026-10-13`)
- artifact `rx2cpp-c5c7b22.zip`, made with
  `git archive --format=zip c5c7b22 oorexx2cpp > rx2cpp-c5c7b22.zip`
- SHA-256 `b7302645eb4caddfeb0db5be2d846d42579c000c12cb2b2a3f6c8a0d790a330f`

Every article's `provenance[]` names a member of that archive (with lines where the claim is a section).
The archive is not vendored here; regenerate it from the repository with the command above and check the digest.

This sphere is documentation/continuity, not the compiler. It inherits the shared ooRexx source-navigation
services of the `oorexx` sphere.

Start:

    gopher --profile rx2cpp context rx2cpp --full
    gopher --profile rx2cpp search 'security manager' --sphere rx2cpp

Articles: start, build-and-run, qualification, lanes, epoch, environment-symbols, security-managers,
performance, known-differences, interpreter-bugs, people-and-upstream. Corpus: rx2cpp.lessons.
