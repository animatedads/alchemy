# ooRexx D-Bus connector — Gopher sphere v0.1

This sphere preserves a user-approved engineering boundary: **modernise the existing native dbusoorexx binding rather than reimplementing it or routing through BSF4ooRexx**.

The native ooRexx package MUST operate independently of Alchemy, ConnectSelector, RPC, Queue Fabric and Instrumentation Mesh. Those integrations are optional external adapters. Explicitly registered object/method signatures control inbound D-Bus dispatch.

## Begin with

- `ref.oo-rexx-dbus.architecture`
- `ref.oo-rexx-dbus.source-authority`
- `ops.oo-rexx-dbus.qualification`
- `ops.oo-rexx-dbus.archive-audit`

## Current evidence as of 2026-10-23

The historical 2015 release is known; a later 2026 SVN `dbusoorexx.zip` is a *reported* source lead, not a verified or promoted source baseline. GitHub contains an ooRexx D-Bus *qualification tool*, not native C++ connector source. Archive-auditor unit tests ran locally (14 PASS). Native C++/ooRexx, 2015–2026 comparison, and Gopher engine loading remain NOT_RUN.

This is a knowledge sphere, not an executable connector distribution. Archive metadata inspection is not source/ABI qualification.
