# Architecture Intentions — dev9 source delta

This directory contains the new dev9 read-only SSC qualification component and its offline test. It is not the complete dev8 baseline. The complete dev9 source tree (87 manifest-tracked files) is packaged as `oorexx_architecture_intentions_v0.1-dev9.zip`, generated from the prior dev8 source archive in the conversation.

**Source reconciliation remains outstanding:** import the exact preceding dev8 tree under one authoritative repo path and verify its hashes before treating this delta as an installable GitHub source tree.

Usage: add this module to the dev8 `src/`, append the test to `tests/run_environment.sh`, update SSC source level from 8 to 9, and qualify under ooRexx r13196. The new module is NOT native-tested in this GitHub commit.

Authority: SSC owns source semantics and locks; Deployment owns target execution. No automatic deployment, fabricated lock or embedded fake approval verifier in production.
