# rx2cpp compiler sphere v0.3

Knowledge and continuity sphere for **rx2cpp**, the ooRexx 5.3 to C++17 compiler
(github.com/animatedads/oorexx, folder `oorexx2cpp`).

Architecture: Tom Dyer. Coding: ChatGPT and Claude. Sphere written by Claude (Opus 5.5).

Grounded baseline:
- commit `fa1179f13d417329599198805665600d42ce9336` (main: the merge of `wip-2026-10-13` after the full regression and self-build passed)
- artifact `rx2cpp-fa1179f.zip`, made with
  `git archive --format=zip fa1179f oorexx2cpp > rx2cpp-fa1179f.zip`
- SHA-256 `7c6605689c7181dc9e6d4ed17859e6703adb958acb64fbedc8a9b7ce72b62089`

Every article's `provenance[]` names a member of that archive (with lines where the claim is a section).
The archive is not vendored here; regenerate it from the repository with the command above and check the digest.

This sphere is documentation/continuity, not the compiler. It inherits the shared ooRexx source-navigation
services of the `oorexx` sphere.

Start:

    gopher --profile rx2cpp context rx2cpp --full
    gopher --profile rx2cpp search 'security manager' --sphere rx2cpp

Articles: start, build-and-run, qualification, lanes, epoch, environment-symbols, security-managers,
performance, known-differences, interpreter-bugs, people-and-upstream. Corpora: rx2cpp.lessons, rx2cpp.continuity.
