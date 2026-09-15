# CivicPort v0.14

CivicPort is a public-data evidence port for ooRexx.

Its rule remains:

> Preserve evidence first. Project later. Promote never by accident.

## v0.14 — durable-journal NOTAM evidence surfaces

v0.14 keeps the narrow `faa.swim.aim-fns.notam-runway-closure/0.1` grammar
unchanged and adds two read-only consumer surfaces above the already-durable
`CivicQueueJournal`.  It does **not** add a broader NOTAM parser or an
operational interpretation.

The pipeline is:

```text
SWIFT/SCDS JMS
    -> JMS Queue Bridge
    -> Queue Fabric
    -> CivicQueueJournal
    -> rich SWIM XML
    -> AIM FNS simpleText
    -> narrow NOTAM projection
       +-> read-only SQL snapshot
       `-> Runtime Registry evidence contract
```

`CivicNotamJournalProjector` scans only records that are already in the Civic
queue journal. Successful runway-closure projections and failed/unsupported
projection diagnostics are retained separately.  An unsupported taxiway or
other NOTAM shape therefore does not disappear merely because it is absent from
the typed runway-closure relation.

The NoSQLServer surface is a first-read frozen relation snapshot.  Once
`civic_notam_runway_closure` is materialized, subsequently appended journal
records do not mutate that relation instance; a new provider/table snapshot is
required to observe later evidence.  Every row retains source identity, Civic
queue journal record ID, queue evidence identity, body SHA-512, source XML path,
exact lexical NOTAM tokens, and the explicit
`EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE` disposition.

Runtime Registry generation:

```text
ability:   civic.notam.runway-closure.evidence
contract:  civic.notam.runway-closure.evidence/0.1
mapping:   faa.swim.aim-fns.notam-runway-closure/0.1
profile:   civicport-notam-runway-closure
```

The Runtime input is exactly `source_identity`.  Callers cannot supply a queue
name, journal root, JMS selector, endpoint or credential reference.  The
10-digit FAA time groups are explicitly emitted as JSON strings using the
Runtime Registry `JsonString` representation; they are never coerced to a
number and no century, timezone, `DateTime`, active/inactive state or
operational schedule is inferred.

The current consolidated JMS dependency is `0.1-dev7-fb1`.  That cut is based
on dev6 and explicitly retains the existing TEXT path, durable
`alchemy.jms.message/0.1` identity, credential handling and settlement
semantics.  CivicPort uses only that unchanged Java-neutral TEXT handoff; its
FederationBank/MapMessage additions do not enter CivicPort.

Current qualification baseline is `oorexxapis(20260828-141725).zip`, with
Alchemy Objects v0.8, Crypto v0.3, Runtime Registry v0.14, NoSQLServer v0.79,
Structured Relation v0.9 compatibility, Queue Fabric v0.9-dev4, JMS Queue
Bridge v0.1-dev7-fb1, Secret Broker v0.2 on the bridge side, and HardWorld
v0.31-work for inherited promotion regression only.  v0.14 adds no NOTAM
HardWorld promotion rule.

## v0.13 — narrow NOTAM evidence, consolidated JMS bridge, and Companies House sandbox

v0.13 builds on the durable SWIM evidence seam from v0.12.  The new NOTAM
layer starts from an already-journalled `CivicAimFnsSimpleTextProjection`; it
never connects to JMS, acknowledges Queue Fabric, resolves credentials, writes
SQL, or promotes a world fact.

The first generation is intentionally narrow:

```text
faa.swim.aim-fns.notam-runway-closure/0.1
```

It accepts only this seven-token domestic runway-closure shape:

```text
!<accountable> <NN/NNN> <location> RWY <designator> CLSD <start>-<end>
```

The deterministic fixture remains:

```text
!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001
```

and projects exact lexical evidence:

```text
accountableLocation   JYR
notamNumber           08/001
affectedLocation      JYR
keyword               RWY
runwayDesignator      17/35
condition             CLSD
effectiveStartToken   2608261100
effectiveEndToken     2608270001
endQualifier          EXACT
```

`YYMMDDHHMM`, optional `EST`, and `PERM` remain lexical source tokens.  CivicPort
does not construct an ooRexx DateTime, infer a timezone offset, compare the
times to the clock, or decide whether the closure is currently active.

The grammar is fail-closed. Taxiway notices, non-`CLSD` runway conditions,
additional body clauses, malformed NOTAM numbers, and unsupported time shapes
are rejected rather than partially interpreted.  This is not presented as a
complete FAA NOTAM parser.

The FAA NOTAM system documentation is used only as a grammar reference for the
narrow projection: FAA Order JO 7930.2 describes UTC/Zulu NOTAM times in
10-digit `YYMMDDHHMM` form, and FAA NOTAM examples use forms such as
`RWY 36 CLSD ...`.  The SWIFT/SCDS evidence classification still dominates this
package's use boundary:

```text
NOT_FOR_OPERATIONAL_USE
EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE
```

No v0.13 HardWorld promotion rule is supplied for NOTAM fields.

### Consolidated JMS bridge pin

The current roll-up contains JMS Queue Bridge `0.1-dev6`.  CivicPort v0.13 pins
that consolidated generation instead of the earlier side candidate
`0.2-dev1`.  dev6 retains the same Java-neutral durable
`alchemy.jms.message/0.1` representation and already contains the optional
Secret Broker v0.2 credential adapter introduced in its dev3 line.

CivicPort still requires only `JMSQueueBridge.cls`; it does not load BSF/JNDI,
Solace Java classes, `SecretLease`, or SWIFT credentials.

### Companies House sandbox is a separate authority domain

The previously requested Companies House sandbox support is carried forward
here rather than being lost between releases.  Live and sandbox deliberately
share only the response-shape mapping:

```text
mapping generation:
  companieshouse.company-profile/0.1
```

Their endpoint and credential domains are separate:

```text
LIVE
  api.company-information.service.gov.uk
  credential reference convention: companieshouse-live
  environment backend example:     COMPANIES_HOUSE_API_KEY
  Runtime ability:                  civic.company.lookup/0.1

SANDBOX
  api-sandbox.company-information.service.gov.uk
  credential reference convention: companieshouse-sandbox
  environment backend example:     COMPANIES_HOUSE_SANDBOX_API_KEY
  Runtime ability:                  civic.company.lookup.sandbox/0.1
```

A credential binding remains exact-host scoped. A live credential reference
cannot authorize the sandbox host and a sandbox reference cannot authorize the
live host. URL plus non-secret credential reference remain part of cache
identity, so live and sandbox evidence cannot collide.

The source catalogue exposes sandbox as
`companieshouse.company-profile.sandbox`; the Runtime Registry contract uses a
distinct profile family `civicport-company-sandbox`; and NoSQLServer can expose
a separate read-only `civic_company_sandbox` relation.  Runtime callers still
cannot supply a URL or credential reference.

The optional sandbox network probe is disabled by default and requires both
`COMPANIES_HOUSE_SANDBOX_API_KEY` and an explicit
`CIVICPORT_COMPANIES_HOUSE_SANDBOX_COMPANY_NUMBER`.  There is no fallback from
sandbox credentials to live credentials or vice versa.

---

v0.12 extends that rule beyond HTTP: FAA SWIM messages arrive through the
separate JMS→AlchemyQueue bridge, become durable Civic queue evidence before
Queue Fabric acknowledgement, and only then enter rich XML/source projection.

## v0.12 — durable SWIM queue evidence before semantics

v0.12 adds the first non-HTTP CivicPort ingress path, but **CivicPort still does
not own JMS**.  FAA SWIM/SCDS delivery remains the responsibility of the
side-by-side `oorexx_jms_queue_bridge` package and Queue Fabric:

```text
FAA SWIFT / SCDS JMS
        |
        | JMS 1.1 / Solace (outside CivicPort)
        v
oorexx_jms_queue_bridge_v0.2-dev1
        |
        v
persistent Queue Fabric queue  FAA.SWIM.AIM_FNS
        |
        | claim
        v
CivicQueueIngestor
        |
        | append exact Java-free message evidence FIRST
        v
CivicQueueJournal
        |
        | only after durable append / duplicate recognition
        v
Queue Fabric ACK
        |
        v
CivicSwimXmlAdapter -> rich XmlDocumentContext
        |
        v
CivicAimFnsSimpleTextAdapter
```

There is no `BSF.CLS`, `javax.jms`, JNDI, Solace Java class, connection factory,
broker credential, or live JMS connection in CivicPort.  `CivicQueueIngress.cls`
knows only the Java-neutral persisted `JMSBridgeMessage` produced by the bridge.
`CivicSwim.cls` does not know even that transport envelope: it consumes an
already-journalled `CivicQueueDocument`.

### The acknowledgement boundary

Queue Fabric is durable transport; the Civic queue journal is the semantic
evidence boundary.  `CivicQueueIngestor~pumpOne` therefore performs:

1. claim one Queue Fabric package;
2. build a Java-free `CivicQueueDocument`;
3. verify SHA-512 identities and append it to `CivicQueueJournal`;
4. acknowledge Queue Fabric only after the journal append succeeds.

This is deliberately **not XA**.  If the process dies after Civic journal append
but before Queue Fabric ACK, Queue Fabric persistent recovery returns the old
INFLIGHT package to READY.  The restarted Civic journal recognizes the same
JMS source/evidence identity as a duplicate and the ingestor ACKs it without
creating a second evidence record.  The deterministic acceptance suite executes
that crash window with a real persistent `ObjectQueueManager`.

A journal exception is treated as transient: the claimed package is `release`d
back to READY without increasing its backout count.  Unsupported/corrupt message
payloads are `nack`ed rather than acknowledged.

### What "exact body" means for JMS TextMessage

The bridge currently persists JMS `TextMessage` as an ooRexx String.  CivicPort
hashes and stores **that exact Java-neutral String representation**.  It does
not claim to possess the broker's TCP bytes, JMS wire framing, or a pre-decoding
byte stream.  `CivicQueueDocument~provenance` therefore identifies the transport
as `ALCHEMY_QUEUE`, while the body SHA-512 is explicitly the digest of the
stored TextMessage representation.

Headers and message properties are independently canonicalized and SHA-512
hashed.  Source identity is pinned to provider + bridge source + JMS message ID;
reappearance of that source identity with different body/header/property
evidence is `SOURCE_IDENTITY_CONFLICT`, not an update.

### SWIM disclosure policy stays attached

The supplied SWIFT/SCDS subscription screen states that Cloud Distribution
Service data is **NOT FOR OPERATIONAL USE** and that the data has been
pre-approved for public release by the NAS Data Release Board.  v0.12 retains
those statements as explicit source policy metadata:

```text
useClassification:      NOT_FOR_OPERATIONAL_USE
releaseClassification:  PUBLIC_RELEASE_PREAPPROVED_NDRB
```

A SWIM document carrying a conflicting non-empty use classification is rejected
by the semantic adapter.  These labels are disclosure/use evidence; they are
not HardWorld authority or permission to reinterpret the payload.

### Rich XML first; NOTAM grammar later

The SWIM body is parsed through Structured Relation v0.9's native
`XmlDocumentContext`.  Namespace-qualified names, hierarchy, source paths,
lines, attributes and the original text remain available in the rich XML model.
Callers receive a fresh native tree on each `nativeDocument` request so they
cannot mutate the retained Civic queue evidence.

v0.12 has one deliberately narrow AIM FNS projection:

```text
faa.swim.aim-fns.simple-text/0.1
```

It finds exactly one XML element whose local name is `simpleText` and preserves
its text, rich source path and source line.  Zero matches, multiple matches and
empty text are explicit failures.  **It does not parse NOTAM syntax into runway,
closure, effective-time or operational fields.**

The deterministic fixture contains:

```text
!JYR 08/001 JYR RWY 17/35 CLSD 2608261100-2608270001
```

inside synthetic AIM-FNS-shaped XML.  The fixture is not a live FAA capture and
is not asserted to be a current or operational NOTAM.

### Deliberate v0.12 limits

The SWIM slice does not yet add:

- a SWIM SQL relation;
- a SWIM Runtime Registry ability;
- a SWIM source-catalog entry;
- a HardWorld promotion rule;
- direct NOTAM grammar/semantic parsing;
- live JMS connectivity tests inside CivicPort.

Those can be added after the transport-to-evidence seam is proven.  The live
JMS lifecycle, Java/BSF dependency and broker credentials belong to the
standalone JMS Queue Bridge package.  The v0.2-dev1 bridge uses ooRexx Secret
Broker v0.2 as its preferred live credential boundary: CivicPort never receives
the SWIFT/SCDS username, password, SecretLease, or credential materialization.
Provider URL, connection factory, destination and Message VPN remain bridge-side
connection authority rather than Secret Broker contents.

### v0.12 capabilities

v0.12 adds:

```text
CIVIC_QUEUE_EVIDENCE
CIVIC_SWIM_XML
```

The HTTP/postcode/company/METAR/catalogue capabilities remain unchanged.

### Runtime Registry dependency refresh

The current consolidated stack supplies Runtime Registry **v0.14**.  CivicPort
v0.12 now pins `runtime_registry` 0.14 in its external-requirement evidence and
dependency guard.  Existing Civic ability IDs, contract generations and mapping
generations do **not** change merely because the Registry implementation package
advanced.

---

## v0.11 — source catalogue and exact generation negotiation

v0.11 does not add another government source. It makes the three existing
source families discoverable through one immutable metadata/adapter-selection
surface without turning discovery into network authority.

The default catalogue contains exactly these source generations:

```text
postcodes.io.postcode
  mapping:     postcodes.io.postcode/0.2
  projection:  SINGULAR
  credential:  NONE
  ability:     civic.postcode.lookup / civic.postcode.lookup/0.1

companieshouse.company-profile
  mapping:     companieshouse.company-profile/0.1
  projection:  SINGULAR
  credential:  REFERENCE_REQUIRED
  ability:     civic.company.lookup / civic.company.lookup/0.1

aviationweather.metar
  mapping:     aviationweather.metar/0.1
  projection:  COLLECTION
  credential:  NONE
  fixed header: User-Agent: CivicPort/0.10
  ability:     civic.metar.lookup / civic.metar.lookup/0.1
```

The catalogue is deliberately not a client factory. It never creates a
`CivicClient`, `CivicCache`, transport, credential provider, SQL relation,
Runtime handler or HardWorld object. A selected descriptor may reconstruct its
exact allow-list endpoint and fixed **non-secret** request headers; credentials
remain deployment-owned and represented only by the existing non-secret
credential reference. `Authorization`, `Proxy-Authorization`, `Cookie` and
transport-reserved headers are forbidden in catalogue header metadata.

### Negotiation means exact caller preference

There is no implicit newest generation. Callers provide a source ID and an
ordered Array of exact acceptable mapping generations:

```rexx
accepted = .array~of("postcodes.io.postcode/9.9", -
                     "postcodes.io.postcode/0.2")
choice = catalog~select("postcodes.io.postcode", accepted)
```

The first exact generation in the **caller supplied order** that exists in the
catalogue is selected. Empty lists, duplicate tokens, `latest`, wildcard `*`
and semantic-version guessing fail closed. A metadata generation may exist
without executable adapter code; in that case selection returns
`ADAPTER_IMPLEMENTATION_UNAVAILABLE` rather than using reflection or guessing a
class name.

### One generic mapping surface

All selected adapters expose `mapAll(document)`. The singular postcode and
company adapters wrap their existing successful mapping as a one-item
`CivicJsonCollectionMappingResult`; METAR retains its real zero-to-many source
array and source pointers. This normalizes the *call surface*, not the source
shape.

The selection does not expose its internal adapter object, so a caller cannot
mutate `CivicJsonMapping~fields` after choosing a pinned generation.

### Runtime generation cross-check

The catalogue itself has no Runtime Registry dependency. When Runtime Registry
v0.14 integration is enabled, acceptance constructs the three real Civic API
contracts and proves that their ability ID, contract generation and mapping
generation exactly match the catalogue descriptors in both directions. This
prevents the catalogue and OpenAPI/profile surfaces from drifting silently.

### Capabilities

v0.11 adds:

```text
CIVIC_SOURCE_CATALOG
CIVIC_GENERATION_NEGOTIATION
```

### Transport behaviour deliberately unchanged

v0.11 is a metadata/selection release. The METAR fixed User-Agent therefore
remains exactly `CivicPort/0.10`, as introduced by the v0.10 source request
contract. Bumping that evidence-bearing header merely to mirror the package
number would create a new request/cache identity and would make this a transport
behaviour release.

---

## Inherited v0.10 source behaviour

### METAR observations, not weather facts

The source contract is pinned to the NOAA/NWS Aviation Weather Center Data API:

```text
host:                  aviationweather.gov
resource:              GET /api/data/metar?ids={station}&format=json
mapping generation:    aviationweather.metar/0.1
Runtime ability:       civic.metar.lookup
contract generation:   civic.metar.lookup/0.1
Runtime Registry:      0.12
```

The official API describes METAR as worldwide terminal-observation data,
supports JSON, and documents the `/api/data/metar` endpoint. It also documents
HTTP 204 for a valid request with no data and HTTP 429 for rate limiting.

The bundled EGLL data is **synthetic deterministic test data shaped like the
AviationWeather.gov v4.0 METAR JSON response**. It is not a live capture and is
not asserted to describe current weather at Heathrow or anywhere else.

## Exact query authority

Earlier CivicPort endpoint templates distinguished only "query forbidden" from
"query allowed". That is too broad for this API. `CivicEndpointTemplate` now
supports an exact query template, and the METAR source permits only:

```text
ids={station}&format=json
```

For the v0.10 station lookup, all of these are outside that authority:

```text
format=json&ids=EGLL
ids=EGLL&format=json&hours=24
ids=EGLL,KJFK&format=json
bbox=...&format=json
```

The four-character station selector is normalized by the adapter before URL
construction. Runtime Registry callers receive only `station_icao`; they cannot
supply the URL or extra API selectors.

## Collection mapping

The METAR JSON root is an array. A one-station response may contain zero, one,
or multiple source observations. v0.10 therefore adds
`CivicJsonCollectionMappingResult` and source-relative mapping:

```text
CivicDocument
  parsed Array
     |
     +-- /0 -> CivicJsonMappingResult(sourcePointer="/0")
     +-- /1 -> CivicJsonMappingResult(sourcePointer="/1")
     `-- ...
```

No array-order semantic is invented. Source order is preserved, but CivicPort
does not label element zero "latest" or silently discard later elements. Every
returned item must match the requested station; a mixed-station collection is
`INVALID` as a whole rather than partially trusted.

HTTP 204 is an evidence document that maps to an **OK empty collection**. It is
not an error and does not fabricate a row.

## METAR scalar projection

Mapping generation `aviationweather.metar/0.1` projects a deliberately narrow
set of scalar fields:

```text
station_icao
receipt_time
report_time
temperature_c
dewpoint_c
wind_speed_kt
wind_gust_kt
altimeter_hpa
sea_level_pressure_hpa
present_weather
metar_type
raw_observation
latitude
longitude
elevation_m
station_name
flight_category
```

The source members `wdir`, `visib`, and `clouds` are deliberately **not** in
this generation. The source schema permits shapes for those fields that are
not one simple scalar contract (`wdir` may be lexical such as `VRB`; visibility
may have lexical forms such as `10+`; clouds are structured arrays). They remain
reachable in the complete parsed `CivicDocument`. v0.10 does not comma-join,
choose a preferred representation, or flatten them for convenience.

Numeric JSON members such as `21.0` continue to be parser-native ooRexx Strings.
CivicPort does not apply `+0` or any other number-conversion policy.

## User-Agent is evidence and cache identity

The Aviation Weather Center recommends a custom User-Agent. v0.10 does not hide
one inside the transport. `CivicAviationWeatherAdapter~requestHeaders()` returns
an explicit:

```text
User-Agent: CivicPort/0.10
```

CivicCache now permits this one caller header, retains it in `CivicRequest` and
the journal, and incorporates its exact lexical bytes into the cache key.
Different User-Agent values cannot silently share cache identity. Other caller
headers remain refused by the cached GET path, so the old "do not cache an
unkeyed representation variant" rule is not weakened.

## Read-only METAR relation

`CivicRelationProvider~defineMetarRelation(tableName, stationIcao, ...)` defines
a zero-to-many read-only relation. Catalog/metadata discovery is network-free,
mutation remains `SQLUNSUPPORTED`, and the first read fetches one HTTP document.
Each mapped source array member becomes one row carrying `source_pointer` plus
scalar METAR and normal Civic evidence columns.

A 204 response materializes zero rows without error. Rich rows continue to
return to the one native `CivicDocument`, where unprojected `clouds`, `wdir`,
and `visib` remain intact.

## Runtime Registry METAR contract

`CivicMetarApiContract` publishes the read-only ability:

```text
input:  { station_icao }
output: evidence metadata + observations[]
```

Each output observation contains:

```text
source_pointer
evidence_identity
values
field_states
```

The output is a collection because the source is a collection. Runtime Registry
does not pick a preferred report. `PRESENT`, `PRESENT_NULL`, and `ABSENT` remain
explicit for every mapped field.

## HardWorld

The generic Civic observation/promotion bridge was extended only enough to make
source pointer part of collection evidence identity. Two items from the same
HTTP body therefore remain distinct observations:

```text
...:SOURCE:/0
...:SOURCE:/1
```

Rich evidence source paths include the full pointer (for example `/0/temp`).
Observation construction changes no world state. A selected METAR field can be
promoted only through an explicit `CivicPromotionGrant`, and the HTTP host never
becomes promotion authority merely because it supplied the document.

## Capabilities

v0.10 advertises the inherited capabilities plus:

```text
CIVIC_JSON_COLLECTION
CIVIC_METAR_OBSERVATION
```

## Current integration targets

The deterministic v0.12 suite is executed with the current consolidated stack:

- Alchemy Objects v0.8 (CivicPort house-base minimum remains 0.4.3)
- ooRexx Crypto v0.1
- Runtime Registry v0.14
- NoSQLServer v0.77
- Virtual RYTA HardWorld v0.28 work
- Structured Relation v0.9
- Queue Fabric v0.9-dev4
- JMS Queue Bridge v0.2-dev1 (Java-neutral core only)
- ooRexx 5.3.0 r13196

`CivicAlchemyObject` reports the current CivicPort package identity `0.12`.

## Running the suite

```sh
ALCHEMY_OBJECTS_ROOT=/path/to/alchemy_objects_v0.8 \
OOREXX_CRYPTO_ROOT=/path/to/oorexx_crypto_v0.1 \
RUNTIME_REGISTRY_ROOT=/path/to/runtime_registry_v0.14 \
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.77 \
HARDWORLD_ROOT=/path/to/virtual_ryta_hardworld_v0.28_work \
STRUCTURED_RELATION_ROOT=/path/to/structured_relation_plugin_v0.9 \
QUEUE_FABRIC_ROOT=/path/to/oorexx_queue_fabric_v0.9-dev4 \
JMS_QUEUE_BRIDGE_ROOT=/path/to/oorexx_jms_queue_bridge_v0.2-dev1 \
./run_tests.sh
```

`run_tests.sh` continues to support the user's normal `/usr/bin/rexx` by finding
`rexx` in `PATH`, or accepts explicit `REXX` / `OOREXX_ROOT` overrides.

Three live probes are independent and opt-in:

```text
CIVICPORT_LIVE_TEST=1
CIVICPORT_COMPANIES_HOUSE_LIVE_TEST=1
CIVICPORT_AVIATIONWEATHER_LIVE_TEST=1
```

The Aviation Weather live probe uses the adapter's explicit User-Agent and an
optional `CIVICPORT_AVIATIONWEATHER_STATION` (default `EGLL`). Live network
success is not part of deterministic package acceptance.

## Source documentation used for the METAR contract

- https://aviationweather.gov/data/api/
- https://aviationweather.gov/help/data/

The source API contract defines the public endpoint/data behaviour. CivicPort's
query pinning, collection evidence identity, cache-keyed User-Agent, SQL
projection and explicit HardWorld promotion are stricter local design rules.
