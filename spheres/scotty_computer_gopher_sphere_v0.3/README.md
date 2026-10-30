# Scotty Computer — Gopher sphere v0.3

Current development source: `scotty_computer_v0.1-dev10.zip`; SHA-256 `fcbcfc50a66f22536298087fe49b60220f842989a95f600a7b304068bfa703ec`. This sphere supersedes v0.2 for development continuity, without deleting historical spheres.

Published [full source submission](https://github.com/animatedads/alchemy/tree/autobuild-submit/20261029T162900Z-CHATGPT-scotty-computer-dev10-fcbcfc50) on GitHub, package commit `4c8a921c682cedf98bcfc226efeb3b389d20f970`, ready commit `4f42af9bc78ffc5e18798b1b8e7fef9cf264f72a`. **Autobuilder is stopped:** no acceptance receipt or deployed Computer service is claimed.

Qualification on 2026-10-29 from the dev10 source: **105/105 Python tests, 7/7 native ooRexx 5.3.0 r13196 suites PASS in the complete serial `tools/qualify.sh` run**, plus verified ZIP integrity and 79 SHA-256 manifest entries.

Dev10 foreground jobs start a new POSIX session and process group. On their *registered timeout*, Computer requests SIGTERM of the group, followed by SIGKILL if it remains. A structured receipt records attempted signals and direct-child reaping without inventing termination proof for detached or remote work. Registered exceptions remain report-only; they **do not terminate jobs**.

Existing boundaries remain: Intention Service dev11 owns semantic READY/dispatch; Git/SSH own identity, `sshnode.sh` owns ED209 mapping; machine-local search scopes fail closed; dev9 script/file pins are not transitive; bearer confirmation tokens are not human identity proof. No live XTP, LDAP, HTTPS or mail deployment is claimed. Independent LLM Gopher validation/ingestion is pending.
