# Alchemy Package Model v0.2

Transport-neutral ooRexx domain model plus `integration.json` codec.

Schema `alchemy.autobuild.integration/0.4` adds exact dependency declarations and retains per-test environment declarations. Planning resolves exact dependency roots, composes `PATH`/`REXX_PATH`/exports, validates required variables/directories, and produces planned tests. No transport, process execution, or publication is performed here.
