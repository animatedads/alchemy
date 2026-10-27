# Integration — v0.1-dev8

## 1. Register source-owned observations

One registry may mix current estate source shapes.  Instrumentation does not
require every service to inherit from a common base class; it requires only a
small observation protocol:

```rexx
registry=.InstrumentationRegistry~new
registry~register('ldap',ldapInstrumentationSource)     /* snapshot() */
registry~register('rexxos',gridInstrumentation)         /* snapshots() */
registry~register('https',httpsServer)                   /* instrumentationSnapshot() */
```

A source may therefore publish one service, a dynamic set of estate members, or
an existing service-owned snapshot.  Registration transfers no service,
placement, failover, queue, memory, storage or management authority.

## 2. Publish through the existing mesh

```rexx
service=.InstrumentationService~new(registry)
publisher=.InstrumentationPublisher~new('ed209a-services',service,transport,'noc-collector')
result=publisher~publish('2026-10-10T07:00:00Z',1791615600)
```

The optional numeric value is an authoritative POSIX instant supplied by the
caller.  It becomes publication-time evidence used for freshness assessment.
The Mesh never manufactures that instant by parsing a local clock string.
Single Time Service v0.4 is an appropriate authority seam: callers may pass a
`TimeInstant~ticks` value when that instant is POSIX scale.

Production uses `InstrumentationQueueRexxClientTransport` over the existing
QueueRexx `bindServiceRoute()` relationship and `MANAGEMENT` security domain.
No instrumentation-specific socket or trust system is created.

## 3. Freshness is not health

A service can truthfully report `HEALTHY` and then disappear from the observation
path.  Changing that retained service health to `FAILED` would invent a service
fact.  dev5 therefore keeps two independent dimensions:

```text
source health       service-owned fact in the retained snapshot
observation freshness   collector evidence about how recently a publication arrived
```

`InstrumentationFreshnessAssessor~assess(ref,now,freshWithin,staleAfter)` returns
`FRESH`, `LATE`, `STALE` or `UNKNOWN`.  It uses the accepted publication's
numeric POSIX evidence and a caller-supplied current POSIX instant.  Missing
numeric time remains `UNKNOWN`; future publication time also fails to `UNKNOWN`
rather than being silently normalised.

This is the intended Keynote/3D NOC behavior: show a stale green/healthy service
as **healthy but stale**, not as a fabricated failure.

## 4. Dimensional counters and gauges

Counters always preserve one series per canonical metric/dimension tuple:

```rexx
peer=.directory~new; peer['peer_id']='peer-a'
emitter~counterAdd('replication.acks.total',1,'count',peer)
```

For gauges, the original `gaugeSet()` API remains latest-value-by-name for
producer compatibility.  A producer that needs simultaneous dimensional gauge
series uses the explicit API:

```rexx
selectDim=.directory~new; selectDim['operation']='SELECT'
updateDim=.directory~new; updateDim['operation']='UPDATE'
emitter~gaugeSeriesSet('request.latency.ms',4.2,'ms',selectDim)
emitter~gaugeSeriesSet('request.latency.ms',8.1,'ms',updateDim)
```

Collector `series(ref,metric,.nil)` means all dimension series.  Passing an
explicit empty Directory selects only the dimension-free aggregate.
`InstrumentationUsageAnalyzer~counterUsage()` computes reset-aware deltas and,
when the caller supplies a trustworthy elapsed interval, a rate.

## 5. Current service adapters

### SMTP Secure Stack dev9

SMTP already owns semantic `smtp.event/0.1` events.  Inject
`SmtpInstrumentationEventSink` beside the service-owned audit sink.  The adapter
projects message/recipient counts, ingress/spool bytes and TLS/authenticated
activity.  It deliberately drops remote address, principal, sender,
certificate/signature identity and message content.

### IMAP dev13

IMAP already owns `ImapInstrumentationSource` and should publish it directly.
The current source covers session lifecycle, active/authenticated/selected
session counts, TLS/plaintext admission, safe command counts, literal bytes,
transport failures and IDLE lifecycle/update activity.  Usernames, mailbox
names, raw commands/searches, message data and credentials remain outside the
instrumentation projection.

### LDAP, HTTPS, NoSQLServer, NotNotes and MVS

LDAP Identity dev16 and HTTPS 0.4.7 expose native Mesh-shaped sources.
NoSQLServer v0.88 publishes database/query/materialisation observations from its
own authority, while NotNotes dev17 publishes application/persistence/batch
observations separately; neither duplicates the other's counters.  MVS Alchemy
pre18 provides its own source in the same way.

### Queue, Memory, Storage and RexxOS

Queue/Channel Fabric, Memory Fabric and Storage Fabric use the fabric adapters or
their native instrumentation packages.  RexxOS RTO2 Grid dev14 publishes the
estate controller and current Management Units as a plural source.  Dynamic
membership therefore naturally appears/disappears as observations without
turning Instrumentation into membership authority.

## 6. Deployment/service progress

`InstrumentationOperationObserver` is the common thin facade for finite work:

```rexx
ops=.InstrumentationOperationObserver~new(identity)
ops~ready
ops~started('release-42','PREPARE',10,'steps')
ops~advanced('release-42','DEPLOY',6,10,'steps')
ops~completed('release-42',10,10,'steps')
```

Terminal progress remains visible until `retire(operationId)` so a consumer can
observe completion instead of having successful work vanish immediately.

## 7. Keynote / 3D NOC discovery

The NOC consumes the collector as a read model.  dev29.20 may discover services
by stable deployment selectors such as estate + node or estate + MI.  Explicit
`services` in the deployment catalogue are **expectations**, not a second source
of service truth.  If an expected semantic reference has no current observation
it remains visible as `unobservedServices` rather than disappearing.

Deployment geography and topology remain separately authoritative.  The Mesh
therefore does **not** invent a topology graph, geographic location, failover
relationship or service dependency merely because two observations share a
node.  Keynote joins those separate facts for presentation.

## 8. Intentions and management

Instrumentation Intentions v0.1-dev1 is the read-only semantic discovery layer
above the collector.  Management Intention Discovery dev8 can advertise and
compose that surface from authoritative objects.  Neither gains Mesh command
authority.  A remote management command still requires authenticated transport,
Mesh authorisation, and the target service's own local authority check.


## Relationship sources

Register relationship-only sources in the same `InstrumentationRegistry` as
metric sources.  A source implements `relationshipSet(observedAt)` or
`relationshipSets(observedAt)`.  The publisher collects both source families
and submits one publication, so the collector never exposes a half-accepted
metrics/relationships batch.

`InstrumentationRelationshipAdapters.cls` supplies current adapters for Queue
Channels, RexxOS Grid membership, Identity peer epoch holders and generic
Management relationships.  The generic bridge requires an explicit
`semanticRef(object)` resolver and refuses unresolved endpoints.

Consumers should use `latestRelationships()` for the current flattened view and
`relationshipSetHistory()` when reconstructing transitions.  A complete newer
set supersedes the current set for the same authority/scope; consumers must not
turn disappearance into a domain-specific failure event unless the domain itself
publishes one.

Network Transport Intentions v0.1-dev3 remains a read-only discovery authority
for transport/path relationships.  If bridged into Instrumentation, those edges
retain their original relationship authority and remain observations rather than
routing commands.

## 7. Operational events

Services with an authoritative operation boundary may use
`InstrumentationOperationObserver(identity, authority)` and register the same
object as an ordinary source. Its snapshot carries current progress while its
`events()` method exposes a bounded replay journal of lifecycle occurrences.

```rexx
ops=.InstrumentationOperationObserver~new(identity,'DEPLOYMENT_AUTHORITY')
registry~register('deployment',ops)
ops~started('release-42','DEPLOY',20,'nodes','','2026-10-10T14:00:00Z')
ops~completed('release-42',20,20,'nodes','','2026-10-10T14:05:00Z')
```

Consumers query the collector with mode `EVENTS_HISTORY`. Filtering supports
`event_id`, `kind`, `subject_ref`, `authority`, `severity`, `correlation_id`,
`operation_id` and `derived`. A derived event is observation-layer evidence only.
No consumer should turn it into mutation authority without revalidating through
the source service's own command/authority path.
## 9. Correlation, causation and external case/change context

Producers that already own a change, incident, transaction or acceptance run may
put that explicit identity on source events.  The Mesh never invents it:

```rexx
contexts=.array~of('change://CHG-42', targetServiceRef)
ops~started('release-42','DEPLOY',20,'nodes','',stamp, -
    'deploy-42','change-open',contexts)
ops~failed('release-42',12,20,'nodes','verify failed',stamp2, -
    'deploy-42','operation:release-42:STARTED',contexts)
```

For event-only authorities use `InstrumentationEventObserver`:

```rexx
change=.InstrumentationEventObserver~new(changeIdentity,'CHANGE_AUTHORITY')
change~record('change-open','CHANGE_WINDOW_OPENED','NOTICE',stamp, -
    'deploy-42','','','approved',.array~new,contexts)
registry~register('change',change)
```

Read-side grouping is explicit:

```rexx
view=.InstrumentationCorrelationView~new(collector)
groups=view~groups
one=view~byId('deploy-42')
siteGroups=view~forRefs(.array~of(targetServiceRef))
```

Events with identical timestamps but no `correlation_id` remain unrelated.
`causation_id` and `context_refs` are optional additive fields; dev7 event/1
records lacking them remain valid dev8 input.  Distributed logging may carry
run/test/transaction identifiers in its own structured payload and project the
chosen correlation id into Instrumentation; the logging record remains the
logging authority.

