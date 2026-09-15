# Recovery roll-up v0.22

This work tree reconstructs the post-v0.19 RYTA/HardWorld work on top of the
canonical `current/` set supplied in `oorexx-libs.zip`.

The bundle is a recovery anchor, not a rollback of later RYTA work.

## Layering

```text
bundled virtual_ryta_hardworld_v0.19
  + v0.20 Legal Effect v0.7 / Structured diagnostic integration
  + v0.21 Queue Fabric v0.5 authority-execution boundary
  + v0.22 current-stack compatibility replay
```

No upstream source is vendored or edited. `CURRENT_STACK_LOCK.sha256` identifies
the exact recovery bundle members used for this replay.

## Current bundle compatibility established

The carried RYTA work was replayed against:

```text
camera_behaviour_oorexx_v0.33
structured_relation_plugin_v0.9
legal_effect_v0.7
runtime_registry_v0.8       sha256 6b4f4c8e...42df5
oorexx_queue_fabric_v0.5
nosqlserver_v0.73
oorexx_db_skeleton_v0.39
msqlshim_v0.10
algrel_cursor_probe_v0.1
ooRexx 5.3.0 r13196
```

Green compatibility paths include Camera -> Algorithm Relation, Structured
Relation rich evidence, Structured Relation -> NoSQL projection, Structured
Relation Git/code evidence -> Legal Effect v0.7 -> HardWorld, Legal Effect v0.7
promotion -> NoSQLServer v0.73, Queue Fabric authority execution, and Runtime
Registry <-> Queue Fabric ability HTTP integration.

## Deliberate fail-closed boundary

The canonical bundled Runtime Registry v0.8 has no
`RuntimeLease~executionEvidence` method. Legal Effect v0.7 explicitly requires
that public evidence surface for runtime-bound legal acquisition.

Therefore the current-stack contract is:

```text
non-runtime Legal Effect v0.7 authority path      supported
runtime-bound Legal Effect v0.7 acquisition       LEGAL_RUNTIME_EVIDENCE_REQUIRED
```

RYTA does not fabricate execution evidence from generation labels, artifact IDs,
or object identities. Those public values do not prove the verifier/source
closure that Legal Effect intends to retain. This limitation is therefore a
capability gap in the current companion stack, not permission for a compatibility
shim.

## Queue authority replay

The v0.21 boundary is retained unchanged. Queue Fabric transfer insertion can be
idempotent by `transferId`, but HardWorld mutation plus queue ACK is not represented
as an XA transaction. RYTA records START before application and COMPLETE after
application; recovered START-without-COMPLETE is refused as
`PREVIOUS_EXECUTION_UNCERTAIN`, while COMPLETE-without-ACK suppresses application
and completes only the ACK.

`claimToken` remains excluded from canonical evidence, durable ledger material,
and retained RYTA result objects.
