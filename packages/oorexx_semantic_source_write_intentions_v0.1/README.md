# ooRexx Semantic Source Control write-side intentions v0.1

**Architecture:** Tom Dyer. **Coding:** Claude (Opus 4.8), 2026-10-24.

The twin of the SSC Examiner's intention classes, for the **write authority** (import / accept /
propose-edit). It makes the SSC write operations drivable by the "Computer" / Scotty intention
front end: you talk to the black box, and IntentionService resolves meaning while this package
supplies live feasibility and dispatches into the authority.

The SSC Examiner side was already registered with IntentionService; the write side was reachable
only by direct MCP dispatch. This closes that gap, following the NotNotes dynamic-discovery
pattern and the Computer boundary rules exactly:

- **Meaning is registered once.** The vocabulary (accept / refuse / propose-edit) is registered
  with IntentionService at install.
- **Feasibility is discovered every turn from live store state.** "Accept the import" is
  advertised only while an import actually has PROPOSED (not-yet-accepted) revisions; "propose an
  edit" only while editable semantic objects exist. Understood-but-impossible is INFEASIBLE, not
  UNKNOWN. The discovery revision changes when feasibility could change, so IntentionService
  re-discovers.
- **Dispatch goes through the authority.** A READY decision is routed into
  `SemanticSourceMcpOperations~dispatch`; the repository authorizer still gates acceptance. A
  refused intention is never a bypass — it never writes directly.

It lives outside the backend-neutral store core and outside the store package itself, depending
only on the store's public classes, so it collides with neither.

## Classes (`src/SemanticSourceWriteIntentions.cls`)

| Class | Role |
|---|---|
| `SemanticSourceWriteIntentionCatalog` | The write vocabulary (action/phrase/aliases/verbs/nouns/side_effect) |
| `SemanticSourceWriteCapabilitySource` | Per-turn feasibility from the live store (pending imports, editable objects) |
| `SemanticSourceWriteDiscoveryProvider` / `...SurfaceProvider` | Advertise only currently-feasible actions to IntentionService |
| `SemanticSourceWriteIntentionInstaller` | Register vocabulary + discovery provider with an IntentionService |
| `SemanticSourceWriteIntentionDispatcher` | READY decision -> MCP write authority, authorizer gating |

## Evidence (LOCAL_PASS)

`tests/test_write_intentions.rex` (13 checks), on a real store built by the Rexx/SQL SQLite
provider with the real IntentionService (pure-ooRexx crypto, no Foreign Runtime): accept is INFEASIBLE with no import, FEASIBLE once one is
pending (with the live import id as the discovered target), dispatch is denied without a session
principal and accepts as the authorized principal, the revision really becomes ACCEPTED, and
accept is INFEASIBLE again afterwards — feasibility is live, not a static catalogue.

## Tests

```
sh run_tests.sh
```
Builds librexxsql.so from the repository, then runs the test on pure-ooRexx crypto (no native
Foreign Runtime build is needed). Needs gcc, make, patch, SQLite 3 and ooRexx headers.
