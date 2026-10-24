# Alchemy Autobuild Gopher sphere v0.1

**Architecture:** Tom Dyer. **Autobuild coding:** ChatGPT (v0.1 to v0.5), Claude (Opus 5.5) (v0.5.1).
**Sphere written by:** Claude (Opus 5.5), 2026-10-24.

For any model working on Alchemy. It answers: how do I get my work into `animatedads/alchemy`, what does
autobuild check, what counts as evidence, and how has autobuild failed before.

Start with `autobuild.start-here`, then `autobuild.current-state`.

| Article | Answers |
|---|---|
| `autobuild.start-here` | What autobuild is and the rules that never change |
| `autobuild.current-state` | Is it running? (As of 2026-10-24: no; v0.5.1 is on main, not installed) |
| `autobuild.submit-git` | Submitting with `tools/alchemy_submit.py` |
| `autobuild.submit-zip` | Submitting a ZIP that Tom downloads |
| `autobuild.integration-contract` | Writing `integration.json` and tests that work under autobuild |
| `autobuild.evidence-and-receipts` | What a receipt proves, and what does not count |
| `autobuild.failure-modes` | Seven ways it has failed, each with evidence |
| `autobuild.operations` | Running and checking the service on the build host |

`autobuild.current-state` goes stale. Update it (new sphere version) when v0.5.1 is installed and writes its
first PASS receipt.

Tests: `sha256sum --check MANIFEST.sha256`, `rexx tests/check_sphere_json.rex .`, and in a live Gopher
environment `bash tests/run_alchemy_autobuild_sphere.sh <sphere zip>`.
