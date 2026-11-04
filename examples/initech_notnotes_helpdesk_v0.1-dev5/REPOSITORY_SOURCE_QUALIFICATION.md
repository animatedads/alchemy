# Standalone repository-source smoke (29 October 2026)

This is an **additive source-only qualification path** for the published Initech Help Desk. It does not replace or modify the accepted dev5 Help Desk implementation or its original retained-data environment runner.

## Run

From a checkout of `animatedads/alchemy` containing the listed packages, with ooRexx 5.3.0 r13196:

```sh
OOREXX_ROOT=/path/to/extracted/oorexx-deb \
  ./examples/initech_notnotes_helpdesk_v0.1-dev5/tools/run_github_source_smoke.sh
```

`OOREXX_ROOT` points to a directory containing `usr/local/bin/rexx`, `usr/local/bin/rexxc`, and `usr/local/lib/`. Without it, the runner uses the executable ooRexx binaries available in `PATH` or via `REXX` and `REXXC`.

The runner **does not** use `examples/.../deps/` or the uncommitted retained TPS dataset. It resolves first-class source roots:

- `packages/notnotes_mini_approval_app_v0.1-dev16` with its **pinned, patched** vendor NotNotes domain and NoSQLServer sources;
- `packages/alchemy_notnotes_v0.1-dev15` for `AlchemyNotNotesIntentions.cls` (a separate runtime from Mini's pinned patched domain);
- `packages/oorexx_intention_service`;
- `packages/oorexx_instrumentation_mesh`;
- `packages/oorexx_instrumentation_intentions`.

The preflight fails closed for missing required source and SHA-256 differences for the three historical core/patched versions. `REXX_PATH` places the intended package sources first; the current working directory is the Mini package because its `::requires` uses package-relative paths. The test data directory is temporary and deleted at exit.

## What the test exercises

On an empty disposable database: install TPS Report and TPS Report Review formats with a document reference, start Help Desk, rediscover the live semantic application/specialist surface, retrieve NotNotes instrumentation, create a Business Log document, close a SUCCESS session into TPS Report and linked TPS Report Review, reopen and query that session's process history, record an unknown request as a FAILURE session and query that failure in a third process.

This exercises **real ooRexx NotNotes objects and persisted NoSQLServer v0.87**, not a fabricated stub or a textual mock. It does not need the original management-review fixture, customers, database journals or a service connection.

## Execution evidence and limits

Local execution on 29 October 2026 used the Library `oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb` extracted with `dpkg-deb -x`: version `Open Object Rexx 5.3.0 r13196 - Internal Test Version`. The Help Desk and Mini code was staged from the retained delivery archive and the 24 October source-publication ZIP; GitHub source blob SHA matches for the published Help Desk classes and primary Mini/Alchemy classes. Historical Instrumentation Mesh, Instrumentation Intentions and Intention Service sources were staged from the **retained dev5 dependency archive**; these versions differ from today's GitHub packages. Accordingly, **this is a source-layout compatibility PASS, not yet a fresh GitHub-main full-dependency checkout PASS**.

Observed local exit status: `0`, printing `PASS Initech source-only repository smoke`. Negative preflight with `AlchemyNotNotesIntentions.cls` temporarily absent: exit `2` before interpreter dispatch.

Still not qualified: the original large TPS management-review fixture; current-main instrumentation/intention source API drift; authenticated LDAP identity, private-CA HTTPS, external transport, webmail, native CLI UI; Mini dev17/dev18 SQLite provider or the draft SQL patches; full clean-checkout product release. Maintain these boundaries when reporting to the programme coordinator.