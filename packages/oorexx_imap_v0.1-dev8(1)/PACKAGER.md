# Preferred Packager integration

This archive is laid out for `alchemy-preferred-packager` schema `oorexx.package/0.1`.

## Authority

Installation follows the package manager authority sequence:

    PLAN -> DRY_RUN -> RUN -> COMMIT

The IMAP package does not edit a global `REXX_PATH`. Its manifest exports `src`;
COMMIT publishes the generation carrying the concrete path.

## Identity

    name:        oorexx-imap
    lineage:     MAIN
    moduleLevel: 8

`displayVersion` is `0.1-dev8`; it is descriptive rather than dependency
authority.

## Dependencies

The core parser/session model is installable without live-network integrations.
API Client, Foreign Runtime, Storage Fabric, Secret Broker and ooRexx Logging are
optional package dependencies in lineage `MAIN`. Logging module level 7 is used
only by `ImapLoggingAdapter.cls`; the core event-sink seam has no hard Logging
dependency.

The supplied Preferred Packager bootstrap prerequisites are now available in the
working set: `oorexx-compress MAIN >= 4` and `oorexx-archive MAIN >= 1`.

## Qualification before activation

Required pure-ooRexx tests use only the candidate tree and do not assume it is
active. That is important because RUN must qualify an inactive generation before
COMMIT may publish it. `test_diagnostics.rex` is part of that required set.
Optional TLS, Storage Fabric and Logging integration tests remain additional
runtime qualification evidence.

## dev5

Package identity previously advanced through dev5; dev8 is module level 8 / display version `0.1-dev8`.  The IMAP
project continues to consume the Preferred Packager contract only; it does not patch,
fork, or reimplement the packager.  The new semantic source and qualification tests
are ordinary package files/required qualifications.

## Dev6 packager boundary

No Preferred Packager source is modified or vendored. Dev6 only advances its own
manifest/module level and required qualification list. The live remote-mutation probe
is excluded from package-manager-required qualification because it is intentionally
state-changing and credentialed.


Dev7 does not invent a Preferred-Packager dependency identity for NoSQLServer v0.79; that dependency remains an explicit optional integration until NoSQLServer publishes its own package identity/lineage contract.

## Dev8 packager boundary

Package identity is `oorexx-imap / MAIN / moduleLevel 8`, display version
`0.1-dev8`. Preferred Packager remains an external authority and is neither patched
nor vendored. The new live mutation probes are excluded from mandatory package
qualification because they require credentials and intentionally modify disposable
mailboxes.
