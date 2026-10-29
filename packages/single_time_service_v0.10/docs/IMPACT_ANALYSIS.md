# Change impact and explicit pull watch — v0.7

## Contracts

`TimeImpactAnalyzer~new(authorityLedger, priorTimeService [,newTimeService])` accepts
one journal and either the **same injected timezone data** for both sides, or
**two explicitly provided** timezone-service instances for rule-update impact.
It never silently substitutes the operating system's currently-installed TZif.

`compare(institution, phrase, fromDate, throughDate, fromRevision, toRevision[,maxDays=31])`
returns `single.time.impact/0.1`, including typed `changes`, `scannedDays`,
`changedDays`, `unchangedDays`, both historical journal checksum witnesses and
`ruleComparisonMode` (`SAME_PROVIDER` or `EXPLICIT_SNAPSHOTS`). The caller
identifies the institutional context and registered phrase, NOT free-text NLP.

Each changed day retains full `before` and `after` historical resolution records.
Independent reason codes distinguish status/meaning/description/local-clock/
UTC-projection/offset-selection/zone/rule-edition/duration/explanation changes.
`utcDeltaSeconds` is an integer only if exactly one POSIX instant exists on
both sides. A cancellation, gap or multi-candidate fold has no single delta.
A change of metadata alone, such as an unrelated institution's closure, does
not appear as an affected day.

No changed day is silently discarded; maximum 366 days per request, with an
explicit default of 31. Invalid dates, historical revisions and unsupported
TZif future coverage fail closed. Comparisons are read-only.

### Authority witness

`TimeAuthorityLedger~revisionWitness(revision)` returns the exact previous
committed chain checksum and revision. Like the v0.6 journal, this is only a
non-cryptographic consistency witness, not signed evidence, time attestation,
or proof of retained TZif bytes. Applications must maintain their own retained
rule datasets if they want to reconstruct historical UTC decisions faithfully.

### RPC and ConnectSelector boundary

The read-only `time.impact.analyze` request is explicitly registered as
RPC Core `time/impact.analyze` and accepted through the existing
ConnectSelector DIRECT and JSON-RPC Fabric adapters when caller policy permits.
The endpoint compares one configured rule provider against itself for two
institutional revisions. It never accepts filesystem paths or loads a TZif
from remote arguments. Only trusted local code constructs the analyzer with
separate old/new rule snapshots. An impact report is **ADVISORY_ONLY**.
No automatic scheduling, recurring job updates, queue mutation, or JMS event
is implied by an impact result.

### Local pull watch (not a push subscription)

`TimeChangeWatch~new(ledger, analyzer, id, context, phrase, fromDate,
throughDate, startingRevision [,startingHeadChecksum [,maxDays=31]])`
encapsulates an in-process consumer cursor. `poll` compares the previously
acknowledged revision to the newest committed revision and returns `IMPACT`,
`NO_EFFECT` or `NO_NEW_REVISION`. It **never acknowledges automatically**.
`acknowledge(offeredRevision, offeredHeadChecksum)` only accepts the most
recent offer with an unchanged historical head; `checkpoint` returns its
revision and chain witness for the **caller** to persist. Repeating a poll
without acknowledgement replays advisory effects (at-least-once *observation*
in this local process, not a delivery guarantee).

The watch has no durable registration, queue, socket, server push, timers or
background task. If a process crashes, only an independently saved checkpoint
can restore the cursor; otherwise it must be rebuilt from an explicit prior
revision. A caller should atomically persist its own receipt alongside any
consumer-side operation. This module must not become a parallel Queue Fabric
implementation. Future delivery subscriptions should delegate to the
ConnectSelector and Queue Fabric owners and define acknowledgement/idempotency
separately.

### Qualification scenarios

- Explicit revision comparison across a 45-minute meal move, an institutional
  closure, an event cancellation, and alias withdrawal.
- Historical reconstruction after a ledger restart; revision mismatch and
  bounded invalid-input rejection.
- Two injected timezone snapshots project an unchanged local intention to
  different UTC instants, distinguishing rule change from timetable change.
- London's autumn DST fold: same local reading, earlier vs later candidate,
  3600-second UTC shift, without a spurious local-clock change.
- Local watch repeated polls, explicit acknowledgement, irrelevant revision,
  externally checkpointed cursor, and tampered checkpoint rejection.
- ConnectSelector DIRECT, explicit RPC Core method, JSON-RPC loopback types,
  existing route policy and denied ENQUEUE.
