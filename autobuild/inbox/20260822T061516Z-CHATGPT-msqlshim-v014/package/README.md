# msqlshim v0.14 Autobuild handoff

This Git-inbox package stages the current local msqlshim source from:

`/home/hc3/alchemy/msqlshim`

The prepare step requires that source to identify itself as `msqlshim v0.14`, copies it into `prepared/msqlshim_v0.14`, removes runtime/test debris, and leaves the prepared source tree as the publication candidate.

The declared acceptance step runs the package's own `run_tests.sh` under an explicit REXX_PATH rooted in the prepared package. Only a passing run may publish the prepared tree to `packages/msqlshim_v0.14`.

This submission deliberately does not infer or replace the backend. The live msqlshim tree supplies its own bound vendor/backend state and its existing acceptance suite remains authoritative for that binding.
