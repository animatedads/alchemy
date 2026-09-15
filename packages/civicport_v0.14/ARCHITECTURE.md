# CivicPort v0.14 architecture

## v0.14 NOTAM evidence-surface boundary

```text
CivicQueueJournal
      |
      | read existing durable records only
      v
CivicNotamJournalProjector
      |
      +--> successful narrow runway-closure projections
      |       |
      |       +--> CivicNotamRelationProvider -- frozen SQL snapshot
      |       |
      |       `--> CivicNotamApiContract      -- source_identity API
      |
      `--> explicit diagnostics for unsupported/malformed evidence
```

Neither SQL nor Runtime Registry is a queue consumer.  They do not claim, ACK,
NACK or release Queue Fabric packages and they cannot connect to JMS.  The
journal is the semantic durability boundary inherited from v0.12.

The SQL relation freezes the journal population at first materialization.  This
prevents a long-running SELECT surface from silently changing as new SWIM
messages arrive.  A fresh relation instance can take a later snapshot.
Unsupported records remain available through provider diagnostics with exact
record/source identity and failure stage.

The Runtime contract accepts only `source_identity`; the deployment handler is
responsible for locating that identity in its pinned journal.  Storage paths,
queue names, JMS selectors and credential references are intentionally outside
the API.  Numeric-looking time tokens use `JsonString` solely to preserve the
source JSON type.  There is no numeric coercion or temporal normalization.

There is still no NOTAM-specific path to HardWorld.  The source subscription is
labelled `NOT_FOR_OPERATIONAL_USE`, and both SQL and Runtime outputs carry
`EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE` explicitly.

## v0.13 semantic boundary

```text
SWIFT/SCDS JMS
      |
      v
JMS Queue Bridge 0.1-dev6
      |
      v
Queue Fabric
      |
      v
CivicQueueJournal
      |
      v
rich SWIM XML
      |
      v
AIM FNS simpleText
      |
      v
CivicNotamRunwayClosureAdapter
      |
      v
EVIDENCE-ONLY lexical projection
```

`CivicNotam.cls` depends only on the preserved SWIM semantic layer.  Static
acceptance rejects Queue Fabric/JMS, Secret Broker, SQL/NoSQLServer and
HardWorld/promotion dependencies from that file.

The NOTAM adapter's 0.1 grammar is intentionally one exact runway-closure
shape.  It preserves the parent queue-evidence identity, simpleText identity,
rich XML source path and the exact source text.  Time fields are source tokens,
not temporal assertions.

Companies House sandbox follows a separate branch of authority:

```text
same JSON mapping generation
        |
   +----+----+
   |         |
 LIVE      SANDBOX
 host A    host B
 cred A    cred B
 API A     API B
 SQL A     SQL B
```

Sharing a JSON schema never implies sharing endpoint authority, credential
authority, cache identity, Runtime ability identity or deployment profile.


## Queue transport is not civic semantics

```text
FAA SWIFT/SCDS
     | JMS
     v
JMS Queue Bridge                 -- Java/BSF/JNDI/provider boundary
     |
     v
Queue Fabric FAA.SWIM.AIM_FNS    -- durable transport
     | claim
     v
CivicQueueIngestor               -- only bridge-envelope-aware Civic class
     |
     +--> CivicQueueJournal      -- durable semantic evidence, append first
     |
     `--> Queue Fabric ACK       -- only after journal success/duplicate
             |
             v
       CivicSwimXmlAdapter       -- no queue/JMS methods
             |
             v
       XmlDocumentContext        -- rich native XML
             |
             v
  AIM FNS simpleText projection  -- exact narrow projection only
```

CivicPort does not load the live JMS BSF/provider class.  `CivicQueueIngress`
requires only the Java-neutral bridge core type and Queue Fabric manager supplied
by the host.  `CivicSwim` depends on neither of those; it starts from frozen
`CivicQueueDocument` evidence.

Live bridge credentials are resolved by the side-by-side bridge through ooRexx
Secret Broker v0.2. No Secret Broker object, lease, username, password, JNDI
credential environment or credential materialization crosses into CivicPort.
Provider URL, connection factory, destination and Message VPN remain bridge-side
connection authority rather than Secret Broker contents.

## Append-before-ACK and recovery

This is an at-least-once handoff with idempotent local evidence, not XA.

Normal:

```text
claim -> journal append -> ACK
```

Crash window:

```text
claim -> journal append -> crash before ACK
                       |
             Queue Fabric recovery
             INFLIGHT -> READY
                       |
                     claim
                       |
            journal source identity exists
                       |
               same evidence => duplicate
                       |
                      ACK
```

Same source identity with different evidence is a conflict and is never ACKed as
if it were the original message.  A thrown journal failure releases the package
back to READY; a semantic payload rejection is nacked.

`CivicQueueJournal` has its own append-only index and immutable body/header/
property/meta files.  Index records are SHA-512-bound to metadata; body, header
and property digests are independently checked on reload.  An unterminated
index tail fails closed.  Record-file publication precedes index publication,
so unindexed orphan files cannot become authoritative journal records.

## JMS TextMessage evidence definition

The bridge has already crossed the JMS/Java decoding boundary.  Therefore
`CivicQueueDocument~bodyText` is the exact ooRexx String persisted by
`JMSBridgeMessage`, not a claim about broker wire bytes.  CivicPort SHA-512
identity covers exactly the stored String plus independently canonicalized
headers/properties.  Provenance explicitly identifies `ALCHEMY_QUEUE` transport.

Source identity is:

```text
JMS:<provider>:<bridge-source>:<JMSMessageID>
```

(encoded safely in the actual identity string).  Queue package ID is retained
as transport provenance but does not replace JMS source identity.

## Rich SWIM XML and disclosure metadata

SWIM XML parsing is delegated to Structured Relation v0.9's native XML model.
The retained Civic evidence remains the queue document; `nativeDocument()`
reparses that exact text into a fresh rich tree for each caller.  Namespaces,
qNames, source paths, source lines and hierarchy remain available without
flattening.

The SCDS subscription disclosure is carried explicitly:

```text
NOT_FOR_OPERATIONAL_USE
PUBLIC_RELEASE_PREAPPROVED_NDRB
```

These are evidence/use classifications, not world-fact authority.

`CivicAimFnsSimpleTextAdapter` projects only one exact `simpleText` element and
its rich source location.  It deliberately does not interpret NOTAM grammar.

## Dependency pins for this slice

```text
Queue Fabric:          0.9-dev4
JMS Queue Bridge:      0.1-dev7-fb1
Structured Relation:   0.9
Runtime Registry:      0.14
```

The Queue/JMS dependencies are needed only for ingress acceptance.  Structured
Relation is needed only for rich SWIM XML.  Existing HTTP/SQL/HardWorld/Runtime
surfaces remain independently loadable according to their previous dependency
boundaries.

---



## Source catalogue boundary

```text
caller source ID + ordered exact accepted generations
                         |
                         v
                  CivicSourceCatalog
                         |
               exact descriptor only
                         |
           +-------------+-------------+
           |             |             |
       postcode       company        METAR
       SINGULAR       SINGULAR       COLLECTION
           |             |             |
           `-------------+-------------'
                         |
                         v
                 mapAll(document)
```

The catalogue contains source/mapping identity, endpoint/query identity,
projection kind, credential policy, fixed non-secret request headers and the
corresponding Runtime ability/contract generation. It contains no credentials
and performs no I/O.

`negotiate()` is intentionally not semver resolution: it validates the entire
caller accept list, rejects duplicates/wildcards/`latest`, then returns the
first exact registered generation in caller preference order. The catalogue
does not assign an ordering to generations.

`select()` uses a closed explicit implementation mapping for known built-in
adapters; no reflection/class-name loading is used. The internal adapter is not
publicly exposed. All selected implementations provide `mapAll(document)`, with
singular adapters returning one mapped item and collection adapters preserving
source multiplicity.

Fixed source request headers are immutable descriptor data. Credential-bearing
and transport-reserved headers cannot be catalogued. The Companies House
descriptor therefore says `REFERENCE_REQUIRED` but contains neither a key nor
an Authorization header.

The catalogue deliberately has no Runtime Registry `::requires`; a separate
integration test checks the real Runtime Registry v0.14 API contracts against descriptor pins.
Thus source discovery can operate without loading Runtime Registry, while
contract drift is still an acceptance failure when the integration is present.

## Evidence hierarchy remains unchanged

Catalogue selection occurs before mapping only. It does not fetch or promote:

```text
selected descriptor/adapter
          |
          v
 supplied CivicDocument ----> exact mapping
                                  |
                     +------------+------------+
                     |            |            |
                  SQL tourist  Runtime view  CivicObservation
                                                |
                                      explicit promotion grant
```

---

## Inherited v0.10: third source, same evidence hierarchy

```text
AviationWeather.gov
        |
        v
exact endpoint + exact query template
        |
        v
CivicRequest (including evidence-bearing User-Agent)
        |
        v
immutable CivicDocument
  exact response bytes / headers / SHA-512
  parsed JSON Array
        |
        v
CivicJournal / CivicCache
        |
        v
CivicJsonCollectionMappingResult
        |
        +-- /0 CivicJsonMappingResult
        +-- /1 CivicJsonMappingResult
        `-- ...
             |
             +-- read-only NoSQL rows
             +-- Runtime Registry observations[]
             `-- explicitly selected CivicObservation
                         |
                         v
                 CivicPromotionGrant
                         |
                         v
                 HardWorld applier
```

No array member is implicitly preferred. No network source becomes authority.

## Query-template boundary

`CivicEndpointTemplate` now optionally pins query shape as well as
scheme/host/port/path. A dynamic query placeholder is segment-like and does not
accept reserved/encoded widening. The Aviation Weather adapter uses:

```text
https://aviationweather.gov/api/data/metar?ids={station}&format=json
```

The station builder accepts one four-character alphanumeric ICAO-style station
identifier and constructs the URL. It does not accept an arbitrary URL, bbox,
history window, or multi-station selector.

## Collection validity boundary

`CivicJsonMapping~mapAt()` and `mapTree()` separate source location from field
pointer. `CivicJsonMappingResult~sourcePointer` is empty for historical
single-object mappings and `/N` for collection items.

`CivicAviationWeatherAdapter~mapAll()` requires:

- HTTP 204, which yields a valid empty collection; or
- parseStatus `OK`;
- pinned source URL/query;
- JSON Array root;
- every item satisfies `aviationweather.metar/0.1`;
- every item's `icaoId` matches the requested station.

One invalid/mixed source member invalidates the collection. CivicPort does not
return a trusted subset from an internally contradictory response.

## Structured/union data remains native

The v0.10 mapping does not project `wdir`, `visib`, or `clouds`. These remain
part of `CivicDocument~parsed`. The relation and Runtime API never invent a
scalar representation for them. Future generations can add an explicit rich or
union-aware contract without changing the source evidence already journalled.

## Cache-keyed User-Agent

AWC asks API consumers to use a custom User-Agent. CivicCache permits one
explicit caller header in v0.10: `User-Agent`. It is:

- retained in CivicRequest evidence;
- persisted by the journal request-header record;
- included exactly in `CivicCacheKey`;
- replayed alongside cache-owned ETag/Last-Modified validators.

All other caller request headers remain rejected by the cached GET API. This is
a narrow source-operability addition, not a general relaxation of representation
identity.

## SQL boundary

`defineMetarRelation()` owns URL construction from station identity and the
fixed source User-Agent. Metadata contains 31 explicit columns: normal access
state, `source_pointer`, 17 named scalar METAR fields, and source/journal
identity. Discovery performs zero HTTP; UPDATE/DELETE/etc. remain
`SQLUNSUPPORTED` before materialization.

A source document containing N valid reports produces N frozen rich rows. A 204
produces zero rows. Every rich row still reaches the same native source document
and its own mapping result/source pointer.

## Runtime Registry boundary

`CivicMetarApiContract` input accepts `station_icao` only. It does not expose
URL/query construction. Its output is an evidence envelope plus
`observations[]`, not a singular "latest weather" object. The profile canonical
identity pins both:

```text
civic.metar.lookup/0.1
aviationweather.metar/0.1
```

Runtime Registry describes/pins the handler contract; it does not own HTTP.

## HardWorld boundary

Collection source pointer is now frozen into `CivicObservation` identity and
full JSON pointer provenance. The generic observation factory has
`observeMapped()` for a caller that explicitly selects one already-mapped item.
That selection alone does not promote anything. The normal explicit grant and
HardWorld promotion machinery remains the only world-write path.

## House-base identity

All Civic application objects continue through `CivicAlchemyObject`. v0.10
corrects its `CIVICPORT_VERSION` from the stale `0.8` value to `0.10`. The
Alchemy Objects external requirement remains a minimum of 0.4.3; acceptance is
run against v0.5.
