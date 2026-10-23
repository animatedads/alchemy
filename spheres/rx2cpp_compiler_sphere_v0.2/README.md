# rx2cpp compiler sphere v0.2

Knowledge and continuity sphere for **rx2cpp**, the ooRexx 5.3 to C++17 compiler
(github.com/animatedads/oorexx, folder `oorexx2cpp`).

Architecture: Tom Dyer. Coding: ChatGPT and Claude. Sphere written by Claude (Opus 5.5).

Grounded baseline:
- commit `43b440edfde0c6bc3f1a09fbb332a93786861f31` (branch `wip-2026-10-13`)
- artifact `rx2cpp-43b440e.zip`, made with
  `git archive --format=zip 43b440e oorexx2cpp > rx2cpp-43b440e.zip`
- SHA-256 `10af342e1e05f0dde36379919ea2e88b73367a2ca15163a8c3f60f4dec7d3035`

Every article's `provenance[]` names a member of that archive (with lines where the claim is a section).
The archive is not vendored here; regenerate it from the repository with the command above and check the digest.

This sphere is documentation/continuity, not the compiler. It inherits the shared ooRexx source-navigation
services of the `oorexx` sphere.

Start:

    gopher --profile rx2cpp context rx2cpp --full
    gopher --profile rx2cpp search 'security manager' --sphere rx2cpp

Articles: start, build-and-run, qualification, lanes, epoch, environment-symbols, security-managers,
performance, known-differences, interpreter-bugs, people-and-upstream. Corpora: rx2cpp.lessons, rx2cpp.continuity.
