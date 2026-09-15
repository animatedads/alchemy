# Alchemy Autobuild Service v0.3

Resident ooRexx composition loop.

Discovery is owned by leased Alchemy Inbox; package materialization, accepted-main
snapshot planning, execution and publication are owned by Orchestrator; terminal
results/receipts are owned by leased Autobuild Evidence.

The service contains no dependency-resolution, `REXX_PATH`, publication or Git
merge policy of its own. PASS, FAIL and ERROR remain terminal outcomes; receipts
make subsequent cycles idempotent.
