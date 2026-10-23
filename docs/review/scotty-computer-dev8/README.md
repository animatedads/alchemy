# Scotty Computer v0.1-dev8 — review handoff

This branch is a **partial review handoff**. It is not a complete Autobuild submission and contains no ready marker.

Full candidate archive: scotty_computer_v0.1-dev8.zip
SHA-256: 1e779ef89d938f2102c146842f2e8f8814196acf02b4dc87a3f157c06993cdd0
Baseline: dev7 ZIP SHA-256 5f9fd22791816c9e3f7d275e6749a9ac12f0075f79b7aba1e19c5f21d2ca1123

Changes: job-scoped output_contains exception observation drains stdout/stderr at completion, checks matches crossing read boundaries, and reports incomplete observation only when receipt access or a 64 MiB per-rule/per-stream budget prevents full inspection. It never starts a daemon or silently terminates the child.

Qualification: 81 Python regressions PASS. Four native ooRexx suites PASS in parallel. Native dev7 exception suite failed during concurrent wrapper execution and PASS on independent retry. The single combined wrapper is NOT claimed fully passing. Archive internal SHA-256 manifest verifies. Interpreter: ooRexx 5.3.0 r13196.

No live SSH, GitHub push, cloud/firewall or XTP tests claimed for the source.

The extracted source package contains integration.json. From an authenticated local clone of animatedads/alchemy, submit the complete package using:

python3 tools/alchemy_submit.py --repo . --package /path/to/scotty_computer_v0.1-dev8 --submitted-by CHATGPT --dry-run --json
python3 tools/alchemy_submit.py --repo . --package /path/to/scotty_computer_v0.1-dev8 --submitted-by CHATGPT --json

The canonical sender creates a separate autobuild-submit/* branch with package tree followed by ready.json. This review branch must not be merged to main or mistaken for such a submission.
