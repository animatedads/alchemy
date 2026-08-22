# msqlshim v0.14 Autobuild handoff r2

This immutable Git-inbox candidate stages the live local msqlshim tree from `/home/hc3/alchemy/msqlshim`.

The prepare phase verifies that the live README identifies msqlshim v0.14, copies the source into `prepared/msqlshim_v0.14`, removes runtime debris, and validates the expected source/test files. The acceptance phase runs the package's own full `run_tests.sh` with an explicit REXX_PATH rooted in the prepared copy.

Only a passing Autobuild result may publish `prepared/msqlshim_v0.14` to `packages/msqlshim_v0.14`.
