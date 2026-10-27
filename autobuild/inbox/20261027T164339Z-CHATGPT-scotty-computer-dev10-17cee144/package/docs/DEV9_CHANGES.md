# Scotty Computer dev9 — current-source reconciliation and script pinning

- Checked Library for a newer Computer source. dev8 remains the latest known release; actual artifact hash is `1e779ef89d938f2102c146842f2e8f8814196acf02b4dc87a3f157c06993cdd0`.
- GitHub Alchemy main has the separate Computer Gopher sphere, and the current accepted `oorexx_intention_service` is dev11; no unverified core revision was substituted.
- New executable-job authority pins automatically detected local Python, shell and ooRexx script files, not only their interpreter executable.
- Added repeatable `--pin-file ABSOLUTE_FILE` before `--` for declared local dependencies, with preview and hash revalidation at review, run preview, and execution. Remote file pins rejected. No transitive pinning claim.
- Five backend regressions cover changed scripts, changed explicit dependencies, symlink denial and inline-shell limits. Added native test for changed pinned scripts.
- Native qualification runs serially for a meaningful aggregate result, rather than background suites that were intermittent on dev8.
- Current work remains a development candidate pending complete native qualification and Autobuild acceptance.
