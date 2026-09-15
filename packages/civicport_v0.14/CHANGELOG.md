# CivicPort changelog

## v0.14

- Added `CivicNotamJournalProjector`, which projects already-durable
  `CivicQueueJournal` records and retains unsupported/malformed records as
  explicit stage/error diagnostics rather than silently dropping them.
- Added read-only NoSQLServer relation `civic_notam_runway_closure` with 27
  explicit source/evidence/lexical columns.  The first SELECT freezes a journal
  snapshot; later journal appends do not mutate that materialized relation.
- Added Runtime Registry ability `civic.notam.runway-closure.evidence` and
  contract generation `civic.notam.runway-closure.evidence/0.1`; input is only
  `source_identity`, with queue/journal/JMS/endpoint/credential selectors
  forbidden by the exact schema.
- Preserved the numeric-looking FAA `YYMMDDHHMM` tokens as explicit JSON
  strings via `JsonString`; no numeric coercion, century inference, timezone
  conversion, DateTime construction or current-active calculation was added.
- Kept the existing NOTAM mapping generation
  `faa.swim.aim-fns.notam-runway-closure/0.1` and
  `EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE` disposition unchanged.
- Rebased queue-ingress dependency evidence onto consolidated JMS Queue Bridge
  `0.1-dev7-fb1`; its existing TEXT/persistence/credential/settlement path is
  explicitly unchanged from dev6 and CivicPort does not consume its
  FederationBank/MapMessage-specific additions.
- Requalified inherited integration against Alchemy Objects v0.8, Crypto v0.3,
  Runtime Registry v0.14, NoSQLServer v0.79, HardWorld v0.31-work, Structured
  Relation v0.9 compatibility, Queue Fabric v0.9-dev4 and Secret Broker v0.2
  bridge-side.
- No NOTAM HardWorld promotion rule, JMS provider code, Secret Broker lease,
  broader FAA NOTAM grammar or operational-use claim was added.

## v0.13

- Added evidence-only FAA/SWIM domestic runway-closure NOTAM projection
  generation `faa.swim.aim-fns.notam-runway-closure/0.1`.
- Preserved exact AIM FNS `simpleText`, XML source path, queue-evidence identity,
  NOTAM number/location/runway/condition tokens and lexical time-range tokens.
- Added explicit `EXACT`, `ESTIMATED`, and `PERMANENT` end qualifiers without
  converting FAA `YYMMDDHHMM` source strings into DateTime values.
- Fail-closed on unsupported NOTAM shapes: taxiway keywords, non-closure
  conditions, extra body clauses, malformed number/designator/time forms are
  not partially interpreted.
- Kept NOTAM projection `EVIDENCE_ONLY_NOT_FOR_OPERATIONAL_USE`; no NOTAM SQL,
  Runtime handler or HardWorld promotion rule was added.
- Rebasing queue ingress onto the consolidated JMS Queue Bridge `0.1-dev6`;
  durable `alchemy.jms.message/0.1` semantics remain unchanged and Secret Broker
  remains bridge-side.
- Carried forward explicit Companies House sandbox support:
  `api-sandbox.company-information.service.gov.uk`, separate credential domain,
  separate catalogue source, Runtime ability/profile family and read-only SQL
  relation while retaining shared company-profile mapping generation `0.1`.
- Added cross-host credential-domain tests proving live credentials cannot be
  used on sandbox and sandbox credentials cannot be used on live.
- Added optional sandbox live probe requiring a sandbox key and explicit sandbox
  company number; no live/sandbox credential fallback exists.
- Revalidated inherited CivicPort integration against Alchemy Objects v0.8,
  Runtime Registry v0.14, NoSQLServer v0.79, HardWorld v0.31-work,
  Structured Relation v0.9-compat, Queue Fabric v0.9-dev4 and JMS bridge
  v0.1-dev6.
- Advanced CivicPort house-base identity to 0.13.

## v0.12

- Added durable non-HTTP Civic evidence ingress from the standalone JMS Queue
  Bridge through Queue Fabric; CivicPort contains no live JMS/Java/BSF/JNDI code.
- Added `CivicQueueDocument` and append-only `CivicQueueJournal`, independently
  SHA-512 binding the stored TextMessage String, headers, properties and metadata.
- Added append-before-ACK `CivicQueueIngestor`: journal success/duplicate is
  required before Queue Fabric acknowledgement.
- Added deterministic crash-window acceptance proving Queue Fabric INFLIGHT
  recovery plus Civic journal duplicate suppression after journal-before-ACK crash.
- Added source-identity conflict handling; the same JMS source identity with
  different evidence is not treated as an update or duplicate.
- Added rich FAA SWIM XML parsing through Structured Relation v0.9.
- Added explicit SCDS `NOT_FOR_OPERATIONAL_USE` and public-release/NDRB disclosure
  metadata.
- Added narrow AIM FNS `simpleText` projection generation
  `faa.swim.aim-fns.simple-text/0.1`; no NOTAM grammar/operational parsing.
- Added synthetic deterministic JYR SWIM/AIM-FNS-shaped XML fixture.
- Added `CIVIC_QUEUE_EVIDENCE` and `CIVIC_SWIM_XML` capabilities.
- Advanced current Runtime Registry dependency evidence/guard from 0.12 to 0.14
  without changing existing Civic ability, API-contract or mapping generations.
- Validated against current Queue Fabric v0.9-dev4 and JMS Queue Bridge
  v0.2-dev1 Java-neutral core.
- Advanced the preferred live bridge credential boundary to Secret Broker v0.2;
  CivicPort still receives no JMS username/password or SecretLease.
- Made the SWIM fixture demonstration resolve its fixture relative to the script
  location rather than the caller's working directory.
- Advanced CivicPort house-base identity to 0.12.
- No SWIM SQL relation, Runtime ability, HardWorld promotion rule or live JMS
  ownership is added in this release.

## v0.11

- Added immutable `CivicSourceCatalog` over the three existing source families;
  no new network source was added.
- Added `CivicSourceDescriptor` pinning source ID, mapping generation, semantic
  kind, singular/collection shape, credential policy, endpoint/query identity,
  fixed non-secret request headers, Runtime ability ID and contract generation.
- Added caller-driven exact generation negotiation. `latest`, wildcard, empty
  and duplicate generation tokens fail closed; no semver/newest inference.
- Added closed explicit adapter selection with no reflection and no public
  mutable adapter exposure. Unknown implementation IDs return
  `ADAPTER_IMPLEMENTATION_UNAVAILABLE`.
- Added common `mapAll(document)` surface to postcode/company singular adapters;
  METAR remains genuinely zero-to-many with source pointers.
- Added immutable fixed-header metadata and rejected credential-bearing or
  transport-reserved headers from catalogue descriptors. METAR retains the
  evidence-bearing `User-Agent: CivicPort/0.10`; Companies House contains only
  `REFERENCE_REQUIRED`, never a credential value.
- Added Runtime Registry v0.12 cross-check proving source mapping generation,
  ability ID and API contract generation do not drift from the catalogue.
- Added `CIVIC_SOURCE_CATALOG` and `CIVIC_GENERATION_NEGOTIATION` capabilities.
- Advanced CivicPort house-base package identity to 0.11 without changing HTTP,
  cache, SQL mutation or HardWorld promotion semantics.

## v0.10

- Added NOAA/NWS Aviation Weather Center METAR source adapter pinned to
  `GET /api/data/metar?ids={station}&format=json`.
- Added exact query templates to the URL allow-list; extra, reordered,
  multi-station and bbox query shapes are not implicitly authorized.
- Added `CivicJsonCollectionMappingResult` and source-pointer-aware mapping for
  zero-to-many JSON arrays without choosing a preferred/latest element.
- Added mapping generation `aviationweather.metar/0.1`.
- Preserved structured/union source members (`clouds`, `wdir`, `visib`) in the
  native document rather than flattening them.
- Added truthful HTTP-204 -> OK empty collection behaviour.
- Added one cache-keyed caller header, `User-Agent`, to follow Aviation Weather
  API guidance without introducing an unkeyed representation variant. Other
  caller headers remain refused by CivicCache.
- Added fixed evidence-bearing `User-Agent: CivicPort/0.10` for METAR relation
  requests.
- Added read-only zero-to-many NoSQLServer METAR relation with `source_pointer`;
  mutation remains `SQLUNSUPPORTED`.
- Added Runtime Registry ability `civic.metar.lookup` generation
  `civic.metar.lookup/0.1`, outputting `observations[]` rather than a guessed
  singular latest observation.
- Extended generic Civic/HardWorld observation identity with collection source
  pointer and full JSON pointer provenance; promotion remains explicit.
- Added deterministic synthetic two-report EGLL fixture and separate opt-in AWC
  live probe.
- Corrected stale `CivicAlchemyObject` package-version metadata from 0.8 to
  current 0.10.
- Continued validation against Alchemy Objects v0.5, Runtime Registry v0.12,
  NoSQLServer v0.77 and HardWorld v0.25 work.

## v0.9

- Added transport-only credential architecture with non-secret
  `credentialRef` retained as evidence.
- Added sealed environment-backed Basic API-key provider with exact host binding.
- Curl credentials are materialized into a mode-0600 temporary config; secrets
  are not placed in curl argv or CivicRequest headers.
- Kept caller `Authorization`, `Proxy-Authorization`, and `Cookie` headers
  forbidden.
- Partitioned cache identity by non-secret credential reference.
- Credential/local-policy failures cannot fall back to cached stale success.
- Advanced journal writer to `CIVICPORT-JOURNAL-RECORD-2`; retained reader
  compatibility with v0.8-era record v1.
- Added a pinned old-format journal fixture produced by sealed CivicPort v0.8.1.
- Added Companies House company-profile adapter and mapping generation
  `companieshouse.company-profile/0.1`.
- Added fixed Companies House endpoint builder for `/company/{company_number}`.
- Deliberately left structured `sic_codes` unflattened in native JSON evidence.
- Added read-only NoSQLServer `civic_company` relation; discovery remains
  network-free and mutation remains `SQLUNSUPPORTED`.
- Added Runtime Registry ability `civic.company.lookup` generation
  `civic.company.lookup/0.1` and profile ID `civicport-company`.
- Runtime company input permits `company_number` only; URL and credential
  selection remain deployment-owned.
- Preserved string-typed JSON wrapper identity for numeric-looking company
  numbers such as `01234567`.
- Verified existing generic HardWorld evidence/promotion semantics with company
  evidence; source host does not become promotion authority.
- Added opt-in live Companies House probe using `COMPANIES_HOUSE_API_KEY` from
  environment only.
- Added `CIVIC_CREDENTIAL_PORT` and `CIVIC_COMPANY_PROFILE` capabilities.
- Validated against Alchemy Objects v0.5, Runtime Registry v0.12,
  NoSQLServer v0.77 and HardWorld v0.25 work.

## v0.8.1

- Made `AbilitySchema.cls` a direct Runtime Registry requirement.
- Added clear Runtime Registry generation/dependency guard.
- Made interpreter discovery installation-prefix neutral and compatible with
  `/usr/bin/rexx`.

## v0.8

- Added Runtime Registry postcode API contract/profile pin without network
  authority in the registry.

## v0.7

- Added first-class access/degradation evidence.

## v0.6

- Adopted the shared `AlchemyObject` house base.

## v0.5

- Added generic frozen Civic observations and explicit HardWorld promotion.

## v0.4

- Added read-only NoSQLServer relation projection.

## v0.3

- Added append-only cache journal and conditional revalidation.

## v0.2

- Added declared JSON parsing, explicit pointers and postcode mapping.

## v0.1

- Added allow-listed GET, exact bytes/headers and SHA-512 evidence.
