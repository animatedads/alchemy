# Alchemy Package Model v0.1

Transport-neutral ooRexx model for Alchemy.

The model does not know whether package bytes arrived by Git branch, managed ZIP,
local directory, queue, or another transport. It models package identity,
exact-version dependencies, dependency-floor entries, package/test environments,
tests, publication intent, and the resulting per-test execution plan.

## Search path precedence

Environment composition is deliberately ordered:

1. caller/base environment;
2. resolved dependency exports and dependency Rexx paths;
3. package environment;
4. individual test environment.

A later `REXX_PATH` `prepend` therefore takes precedence over earlier layers. A
per-test `replace` discards all earlier `REXX_PATH` entries for that test only.

This permits two scripts in the same package to have different dependency search
paths without hiding the distinction in shell setup.

## Dependency floor

Dependencies are exact (`name@version`). A dependency-floor entry supplies the
canonical package root, optional environment export name, and Rexx search entries
relative to that root. Planning fails if an exact dependency is unresolved.

## Boundaries

This package plans. It does not fetch Git, unzip a submission, execute a process,
or push results. Those belong to transport/materialization/executor components
which consume the model.
