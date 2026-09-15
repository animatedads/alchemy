/*
 * Accounting Core v0.10 immutable regulatory filing lifecycle.
 *
 * This layer records amendment/correction lineage and append-only external
 * reporting lifecycle observations.  It never mutates accounting books,
 * sealed snapshots, attestations, or submission evidence.
 */

::options digits 50

::class AccountingReportingFilingVersion public
::attribute filingId get
::attribute seriesRef get
::attribute versionRef get
::attribute filingKind get
::attribute snapshotId get
::attribute snapshotFingerprint get
::attribute boundaryFingerprint get
::attribute priorFilingId get
::attribute priorFilingFingerprint get
::attribute createdAt get
::attribute reasonRef get

::method init
  expose filingId seriesRef versionRef filingKind snapshotId snapshotFingerprint boundaryFingerprint priorFilingId priorFilingFingerprint createdAt reasonRef attestationIdentities evidenceRefs metadata
  use arg idArg, seriesArg, versionArg, kindArg, snapshot, attestationsArg = .nil, priorFiling = .nil, createdAtArg = "", reasonArg = "", evidenceArg = .nil, metadataArg = .nil
  filingId = .AccountingUtil~requireText(idArg, "reporting filingId")
  seriesRef = .AccountingUtil~requireText(seriesArg, "reporting filing seriesRef")
  versionRef = .AccountingUtil~requireText(versionArg, "reporting filing versionRef")
  filingKind = .AccountingUtil~requireText(kindArg, "reporting filing kind")~upper
  if wordpos(filingKind, "ORIGINAL AMENDMENT CORRECTION") = 0 then raise syntax 93.900 additional("unsupported reporting filing kind: " || filingKind)
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then raise syntax 93.900 additional("AccountingReportingSnapshot required")
  snapshotId = snapshot~snapshotId
  snapshotFingerprint = snapshot~fingerprint
  boundaryFingerprint = snapshot~boundaryFingerprint
  createdAt = .AccountingUtil~requireText(createdAtArg, "reporting filing createdAt")
  reasonRef = reasonArg~string~strip
  attestationIdentities = .AccountingReportingEvidenceService~attestationIdentities(attestationsArg)
  priorFilingId = ""
  priorFilingFingerprint = ""
  if filingKind = "ORIGINAL" then do
    if priorFiling \== .nil then raise syntax 93.900 additional("original reporting filing cannot have prior filing")
    if reasonRef \= "" then nop
  end
  else do
    if priorFiling == .nil | \priorFiling~isA(.AccountingReportingFilingVersion) then raise syntax 93.900 additional("amendment/correction requires prior AccountingReportingFilingVersion")
    if priorFiling~seriesRef \= seriesRef then raise syntax 93.900 additional("reporting filing series mismatch")
    priorFilingId = priorFiling~filingId
    priorFilingFingerprint = priorFiling~fingerprint
    if reasonRef = "" then raise syntax 93.900 additional("amendment/correction reasonRef required")
  end
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method attestationIdentities
  expose attestationIdentities
  return .AccountingUtil~copyArray(attestationIdentities)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method fingerprint
  expose filingId seriesRef versionRef filingKind snapshotId snapshotFingerprint boundaryFingerprint priorFilingId priorFilingFingerprint createdAt reasonRef attestationIdentities evidenceRefs metadata
  return filingId || "|" || seriesRef || "|" || versionRef || "|" || filingKind || "|" || snapshotId || "|" || snapshotFingerprint || "|" || boundaryFingerprint || "|" || priorFilingId || "|" || priorFilingFingerprint || "|" || createdAt || "|" || reasonRef || "|" || .AccountingUtil~canonicalArray(attestationIdentities) || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method projection
  expose filingId seriesRef versionRef filingKind snapshotId snapshotFingerprint boundaryFingerprint priorFilingId priorFilingFingerprint createdAt reasonRef attestationIdentities evidenceRefs metadata
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_FILING_API
  p["filing_id"] = filingId
  p["series_ref"] = seriesRef
  p["version_ref"] = versionRef
  p["filing_kind"] = filingKind
  p["snapshot_id"] = snapshotId
  p["snapshot_fingerprint"] = snapshotFingerprint
  p["boundary_fingerprint"] = boundaryFingerprint
  p["prior_filing_id"] = priorFilingId
  p["prior_filing_fingerprint"] = priorFilingFingerprint
  p["created_at"] = createdAt
  p["reason_ref"] = reasonRef
  p["attestations"] = .AccountingUtil~copyArray(attestationIdentities)
  p["evidence_refs"] = .AccountingUtil~copyArray(evidenceRefs)
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingLifecycleEvent public
::attribute eventId get
::attribute filingId get
::attribute filingFingerprint get
::attribute eventType get
::attribute occurredAt get
::attribute actorRef get
::attribute authorityRef get
::attribute authorityIdentity get
::attribute submissionId get
::attribute submissionFingerprint get
::attribute externalRef get
::attribute externalIdentity get
::attribute relatedRef get
::attribute relatedIdentity get
::attribute previousEventId get
::attribute previousEventFingerprint get

::method init
  expose eventId filingId filingFingerprint eventType occurredAt actorRef authorityRef authorityIdentity submissionId submissionFingerprint externalRef externalIdentity relatedRef relatedIdentity previousEventId previousEventFingerprint evidenceRefs metadata
  use arg idArg, filing, typeArg, occurredAtArg, actorArg, authorityRefArg, authorityIdentityArg, previousEvent = .nil, submission = .nil, externalRefArg = "", externalIdentityArg = "", relatedRefArg = "", relatedIdentityArg = "", evidenceArg = .nil, metadataArg = .nil
  eventId = .AccountingUtil~requireText(idArg, "reporting lifecycle eventId")
  if filing == .nil | \filing~isA(.AccountingReportingFilingVersion) then raise syntax 93.900 additional("AccountingReportingFilingVersion required")
  filingId = filing~filingId
  filingFingerprint = filing~fingerprint
  eventType = .AccountingUtil~requireText(typeArg, "reporting lifecycle eventType")~upper
  if wordpos(eventType, "SUBMITTED RESUBMITTED ACKNOWLEDGED ACCEPTED REJECTED WITHDRAWN SUPERSEDED") = 0 then raise syntax 93.900 additional("unsupported reporting lifecycle eventType: " || eventType)
  occurredAt = .AccountingUtil~requireText(occurredAtArg, "reporting lifecycle occurredAt")
  actorRef = .AccountingUtil~requireText(actorArg, "reporting lifecycle actorRef")
  authorityRef = .AccountingUtil~requireText(authorityRefArg, "reporting lifecycle authorityRef")
  authorityIdentity = .AccountingUtil~requireText(authorityIdentityArg, "reporting lifecycle authorityIdentity")
  previousEventId = ""
  previousEventFingerprint = ""
  if previousEvent \== .nil then do
    if \previousEvent~isA(.AccountingReportingLifecycleEvent) then raise syntax 93.900 additional("previous AccountingReportingLifecycleEvent required")
    previousEventId = previousEvent~eventId
    previousEventFingerprint = previousEvent~fingerprint
  end
  submissionId = ""
  submissionFingerprint = ""
  if submission \== .nil then do
    if \submission~isA(.AccountingReportingSubmissionEvidence) then raise syntax 93.900 additional("AccountingReportingSubmissionEvidence required")
    submissionId = submission~submissionId
    submissionFingerprint = submission~fingerprint
    if submission~snapshotId \= filing~snapshotId | submission~snapshotFingerprint \= filing~snapshotFingerprint | submission~boundaryFingerprint \= filing~boundaryFingerprint then -
      raise syntax 93.900 additional("reporting submission is not bound to filing snapshot")
    if .AccountingUtil~canonicalArray(submission~attestationIdentities) \= .AccountingUtil~canonicalArray(filing~attestationIdentities) then -
      raise syntax 93.900 additional("reporting submission attestation set differs from filing")
  end
  if wordpos(eventType, "SUBMITTED RESUBMITTED") > 0 & submissionId = "" then raise syntax 93.900 additional(eventType || " requires submission evidence")
  if wordpos(eventType, "ACKNOWLEDGED ACCEPTED REJECTED") > 0 then do
    if externalRefArg~string~strip = "" | externalIdentityArg~string~strip = "" then raise syntax 93.900 additional(eventType || " requires exact external acknowledgement/decision evidence")
  end
  externalRef = externalRefArg~string~strip
  externalIdentity = externalIdentityArg~string~strip
  relatedRef = relatedRefArg~string~strip
  relatedIdentity = relatedIdentityArg~string~strip
  if wordpos(eventType, "RESUBMITTED SUPERSEDED") > 0 then do
    if relatedRef = "" | relatedIdentity = "" then raise syntax 93.900 additional(eventType || " requires exact related identity")
  end
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method fingerprint
  expose eventId filingId filingFingerprint eventType occurredAt actorRef authorityRef authorityIdentity submissionId submissionFingerprint externalRef externalIdentity relatedRef relatedIdentity previousEventId previousEventFingerprint evidenceRefs metadata
  return eventId || "|" || filingId || "|" || filingFingerprint || "|" || eventType || "|" || occurredAt || "|" || actorRef || "|" || authorityRef || "|" || authorityIdentity || "|" || submissionId || "|" || submissionFingerprint || "|" || externalRef || "|" || externalIdentity || "|" || relatedRef || "|" || relatedIdentity || "|" || previousEventId || "|" || previousEventFingerprint || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method projection
  expose eventId filingId filingFingerprint eventType occurredAt actorRef authorityRef authorityIdentity submissionId submissionFingerprint externalRef externalIdentity relatedRef relatedIdentity previousEventId previousEventFingerprint evidenceRefs metadata
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_LIFECYCLE_API
  p["event_id"] = eventId
  p["filing_id"] = filingId
  p["filing_fingerprint"] = filingFingerprint
  p["event_type"] = eventType
  p["occurred_at"] = occurredAt
  p["actor_ref"] = actorRef
  p["authority_ref"] = authorityRef
  p["authority_identity"] = authorityIdentity
  p["submission_id"] = submissionId
  p["submission_fingerprint"] = submissionFingerprint
  p["external_ref"] = externalRef
  p["external_identity"] = externalIdentity
  p["related_ref"] = relatedRef
  p["related_identity"] = relatedIdentity
  p["previous_event_id"] = previousEventId
  p["previous_event_fingerprint"] = previousEventFingerprint
  p["evidence_refs"] = .AccountingUtil~copyArray(evidenceRefs)
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingLifecycle public
::attribute seriesRef get

::method init
  expose seriesRef filings filingOrder events eventIds
  use arg seriesArg
  seriesRef = .AccountingUtil~requireText(seriesArg, "reporting lifecycle seriesRef")
  filings = .directory~new
  filingOrder = .array~new
  events = .array~new
  eventIds = .directory~new

::method addFiling
  expose seriesRef filings filingOrder
  use arg filing
  if filing == .nil | \filing~isA(.AccountingReportingFilingVersion) then raise syntax 93.900 additional("AccountingReportingFilingVersion required")
  if filing~seriesRef \= seriesRef then raise syntax 93.900 additional("reporting filing series mismatch")
  if filings~hasIndex(filing~filingId) then raise syntax 93.900 additional("duplicate reporting filingId: " || filing~filingId)
  if filing~filingKind = "ORIGINAL" then do
    if filingOrder~items > 0 then raise syntax 93.900 additional("reporting series already has an original filing")
  end
  else do
    if \filings~hasIndex(filing~priorFilingId) then raise syntax 93.900 additional("prior reporting filing not present in lifecycle")
    prior = filings[filing~priorFilingId]
    if prior~fingerprint \= filing~priorFilingFingerprint then raise syntax 93.900 additional("prior reporting filing fingerprint mismatch")
  end
  filings[filing~filingId] = filing
  filingOrder~append(filing~filingId)
  return filing

::method appendEvent
  expose filings events eventIds
  use arg event
  if event == .nil | \event~isA(.AccountingReportingLifecycleEvent) then raise syntax 93.900 additional("AccountingReportingLifecycleEvent required")
  if eventIds~hasIndex(event~eventId) then raise syntax 93.900 additional("duplicate reporting lifecycle eventId: " || event~eventId)
  if \filings~hasIndex(event~filingId) then raise syntax 93.900 additional("reporting lifecycle event filing is not registered")
  filing = filings[event~filingId]
  if filing~fingerprint \= event~filingFingerprint then raise syntax 93.900 additional("reporting lifecycle event filing fingerprint mismatch")
  if events~items = 0 then do
    if event~previousEventId \= "" | event~previousEventFingerprint \= "" then raise syntax 93.900 additional("first reporting lifecycle event cannot have previous event")
  end
  else do
    previous = events[events~items]
    if event~previousEventId \= previous~eventId | event~previousEventFingerprint \= previous~fingerprint then raise syntax 93.900 additional("reporting lifecycle chain mismatch")
  end
  self~validateSemanticTransition(event)
  events~append(event)
  eventIds[event~eventId] = event
  return event

::method validateSemanticTransition private
  expose filings events eventIds
  use arg event
  type = event~eventType
  if wordpos(type, "ACKNOWLEDGED ACCEPTED REJECTED WITHDRAWN") > 0 then do
    if \self~hasSubmissionFor(event~filingId) then raise syntax 93.900 additional(type || " requires prior submitted/resubmitted filing")
  end
  if type = "RESUBMITTED" then do
    if \eventIds~hasIndex(event~relatedRef) then raise syntax 93.900 additional("resubmission related event not present")
    related = eventIds[event~relatedRef]
    if wordpos(related~eventType, "SUBMITTED RESUBMITTED") = 0 then raise syntax 93.900 additional("resubmission related event must be a submission")
    if related~fingerprint \= event~relatedIdentity then raise syntax 93.900 additional("resubmission related event fingerprint mismatch")
  end
  if type = "SUPERSEDED" then do
    if \filings~hasIndex(event~relatedRef) then raise syntax 93.900 additional("superseding filing not present")
    successor = filings[event~relatedRef]
    if successor~fingerprint \= event~relatedIdentity then raise syntax 93.900 additional("superseding filing fingerprint mismatch")
    if successor~priorFilingId \= event~filingId | successor~priorFilingFingerprint \= event~filingFingerprint then raise syntax 93.900 additional("superseding filing does not explicitly descend from superseded filing")
  end
  if self~statusOf(event~filingId) = "SUPERSEDED" then raise syntax 93.900 additional("cannot append lifecycle event to superseded filing")

::method hasSubmissionFor private
  expose events
  use arg filingIdArg
  do event over events
    if event~filingId = filingIdArg~string & wordpos(event~eventType, "SUBMITTED RESUBMITTED") > 0 then return .true
  end
  return .false

::method filing
  expose filings
  use arg filingIdArg
  return filings[filingIdArg~string]

::method filings
  expose filings filingOrder
  rows = .array~new
  do id over filingOrder
    rows~append(filings[id])
  end
  return rows

::method events
  expose events
  return .AccountingUtil~copyArray(events)

::method eventsFor
  expose events
  use arg filingIdArg
  rows = .array~new
  id = filingIdArg~string
  do event over events
    if event~filingId = id then rows~append(event)
  end
  return rows

::method statusOf
  expose filings events
  use arg filingIdArg
  id = filingIdArg~string
  if \filings~hasIndex(id) then return "UNKNOWN"
  status = "SEALED"
  do event over events
    if event~filingId = id then status = event~eventType
  end
  return status

::method latestFiling
  expose filings filingOrder
  if filingOrder~items = 0 then return .nil
  return filings[filingOrder[filingOrder~items]]

::method fingerprint
  expose seriesRef filings filingOrder events
  filingRows = .array~new
  do id over filingOrder
    filingRows~append(filings[id]~projection)
  end
  eventRows = .array~new
  do event over events
    eventRows~append(event~projection)
  end
  return seriesRef || "|" || .AccountingUtil~canonicalArray(filingRows) || "|" || .AccountingUtil~canonicalArray(eventRows)

::method projection
  expose seriesRef filings filingOrder events
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_LIFECYCLE_API
  p["series_ref"] = seriesRef
  filingRows = .array~new
  do id over filingOrder
    filingRows~append(filings[id]~projection)
  end
  eventRows = .array~new
  do event over events
    eventRows~append(event~projection)
  end
  p["filings"] = filingRows
  p["events"] = eventRows
  p["fingerprint"] = self~fingerprint
  return p

::requires "AccountingReportingEvidence.cls"
