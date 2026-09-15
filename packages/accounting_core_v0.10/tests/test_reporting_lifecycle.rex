t = .AccountingTest~new
numeric digits 50

entity = "REGULATED_LAW_FIRM_LLP"
book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

call postFixture book, "REPORT:SOURCE:1", "2026-06-30", "125000"
boundary = .AccountingReportingBoundary~new("BOUNDARY-REG-2026", "LAW-SOCIETY", "ANNUAL_REGULATED_ACCOUNTS", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), .nil, "reg.report/0.1", "sha256:reg-report-policy-v1")
snapshot1 = .AccountingReportingService~sealSnapshot("SNAP-REG-2026-V1", boundary, .array~of(book), "2026-01-01", "2026-12-31", "REPORT-SEAL-REG-V1")
provider = .LifecycleFixtureProofProvider~new("KEY:PARTNER:001", "sha256:key-partner-v1")
attestation1 = .AccountingReportingEvidenceService~createAttestation("ATTEST-V1", snapshot1, "APPROVAL", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SIGN/0.1", "sha256:authority-v1", "2026-07-15T10:30:00+01:00", "REGULATORY_SUBMISSION", provider)
submission1 = .AccountingReportingEvidenceService~createSubmissionEvidence("SUBMISSION-V1", snapshot1, .array~of(attestation1), "LAW-SOCIETY", "REGULATOR-PORTAL", "2026-07-15T11:00:00+01:00", "PORTAL-SUBMISSION-1", "SUBMITTED")

filing1 = .AccountingReportingFilingVersion~new("FILING-2026-V1", "LAW-SOCIETY:ANNUAL:2026", "1", "ORIGINAL", snapshot1, .array~of(attestation1), .nil, "2026-07-15T10:45:00+01:00")
lifecycle = .AccountingReportingLifecycle~new("LAW-SOCIETY:ANNUAL:2026")
lifecycle~addFiling(filing1)

t~assertEq("accounting.reporting.filing/0.1", .AccountingBuild~REPORTING_FILING_API, "filing API explicit")
t~assertEq("accounting.reporting.lifecycle/0.1", .AccountingBuild~REPORTING_LIFECYCLE_API, "lifecycle API explicit")
t~assertEq("ORIGINAL", filing1~filingKind, "original filing kind retained")
t~assertEq(snapshot1~fingerprint, filing1~snapshotFingerprint, "filing binds exact snapshot")
t~assertEq(attestation1~fingerprint, filing1~attestationIdentities[1]["fingerprint"], "filing binds exact attestation")

submitEvent1 = .AccountingReportingLifecycleEvent~new("LIFE-001", filing1, "SUBMITTED", "2026-07-15T11:00:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SUBMIT/0.1", "sha256:submit-authority-v1", .nil, submission1)
lifecycle~appendEvent(submitEvent1)
ackEvent1 = .AccountingReportingLifecycleEvent~new("LIFE-002", filing1, "ACKNOWLEDGED", "2026-07-15T11:00:04+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-RECEIPT/0.1", "sha256:regulator-receipt-authority-v1", submitEvent1, .nil, "PORTAL-ACK-1", "sha256:portal-ack-1")
lifecycle~appendEvent(ackEvent1)
ackEvent2 = .AccountingReportingLifecycleEvent~new("LIFE-003", filing1, "ACKNOWLEDGED", "2026-07-15T11:05:00+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-VALIDATION/0.1", "sha256:validation-authority-v1", ackEvent1, .nil, "PORTAL-VALIDATION-1", "sha256:portal-validation-1")
lifecycle~appendEvent(ackEvent2)
rejectEvent = .AccountingReportingLifecycleEvent~new("LIFE-004", filing1, "REJECTED", "2026-07-16T09:00:00+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-DECISION/0.1", "sha256:decision-authority-v1", ackEvent2, .nil, "PORTAL-REJECT-1", "sha256:portal-reject-1")
lifecycle~appendEvent(rejectEvent)

t~assertEq("REJECTED", lifecycle~statusOf(filing1~filingId), "rejection is derived from lifecycle history")
t~assertEq("4", (lifecycle~eventsFor(filing1~filingId))~items, "submission plus acknowledgement/decision history retained")
t~assertEq("SUBMITTED", submission1~status, "submission evidence is immutable; later rejection does not rewrite it")

/* Correction is based on newly discovered in-period accounting.  The old
 * snapshot becomes stale but remains exactly what was signed/submitted. */
call postFixture book, "REPORT:LATE:DISCOVERY", "2026-06-29", "1"
t~assertEq("REPORT_POPULATION_STALE", .AccountingReportingService~verifySnapshot(snapshot1, boundary, .array~of(book))~errorCode, "old snapshot becomes stale after correction evidence")
t~assertTrue(.AccountingReportingEvidenceService~verifyAttestation(attestation1, snapshot1, provider)~ok, "old approval remains evidence of old snapshot")
t~assertTrue(.AccountingReportingEvidenceService~verifySubmissionEvidence(submission1, snapshot1, .array~of(attestation1))~ok, "old submission remains evidence of old filing")

snapshot2 = .AccountingReportingService~sealSnapshot("SNAP-REG-2026-V2", boundary, .array~of(book), "2026-01-01", "2026-12-31", "REPORT-SEAL-REG-V2")
attestation2 = .AccountingReportingEvidenceService~createAttestation("ATTEST-V2", snapshot2, "APPROVAL", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SIGN/0.1", "sha256:authority-v1", "2026-07-16T10:00:00+01:00", "CORRECTED_REGULATORY_SUBMISSION", provider)
submission2 = .AccountingReportingEvidenceService~createSubmissionEvidence("SUBMISSION-V2", snapshot2, .array~of(attestation2), "LAW-SOCIETY", "REGULATOR-PORTAL", "2026-07-16T10:15:00+01:00", "PORTAL-SUBMISSION-2", "SUBMITTED")
filing2 = .AccountingReportingFilingVersion~new("FILING-2026-V2", filing1~seriesRef, "2", "CORRECTION", snapshot2, .array~of(attestation2), filing1, "2026-07-16T10:05:00+01:00", "LATE_CLIENT_ACCOUNT_ENTRY")
lifecycle~addFiling(filing2)

t~assertEq(filing1~filingId, filing2~priorFilingId, "correction explicitly links prior filing")
t~assertEq(filing1~fingerprint, filing2~priorFilingFingerprint, "correction locks exact prior filing identity")

supersedeEvent = .AccountingReportingLifecycleEvent~new("LIFE-005", filing1, "SUPERSEDED", "2026-07-16T10:06:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-CORRECT/0.1", "sha256:correction-authority-v1", rejectEvent, .nil, "", "", filing2~filingId, filing2~fingerprint)
lifecycle~appendEvent(supersedeEvent)
resubmitEvent = .AccountingReportingLifecycleEvent~new("LIFE-006", filing2, "RESUBMITTED", "2026-07-16T10:15:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SUBMIT/0.1", "sha256:submit-authority-v1", supersedeEvent, submission2, "", "", submitEvent1~eventId, submitEvent1~fingerprint)
lifecycle~appendEvent(resubmitEvent)
ack2 = .AccountingReportingLifecycleEvent~new("LIFE-007", filing2, "ACKNOWLEDGED", "2026-07-16T10:15:04+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-RECEIPT/0.1", "sha256:regulator-receipt-authority-v1", resubmitEvent, .nil, "PORTAL-ACK-2", "sha256:portal-ack-2")
lifecycle~appendEvent(ack2)
accept2 = .AccountingReportingLifecycleEvent~new("LIFE-008", filing2, "ACCEPTED", "2026-07-16T11:00:00+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-DECISION/0.1", "sha256:decision-authority-v1", ack2, .nil, "PORTAL-ACCEPT-2", "sha256:portal-accept-2")
lifecycle~appendEvent(accept2)

t~assertEq("SUPERSEDED", lifecycle~statusOf(filing1~filingId), "old filing explicitly superseded without deletion")
t~assertEq("ACCEPTED", lifecycle~statusOf(filing2~filingId), "corrected filing accepted")
t~assertEq("2", lifecycle~filings~items, "both filing versions retained")
t~assertEq("8", lifecycle~events~items, "complete lifecycle history retained")
t~assertEq(filing2~filingId, lifecycle~latestFiling~filingId, "latest filing resolved without mutating old filing")
t~assertEq(submitEvent1~fingerprint, resubmitEvent~relatedIdentity, "resubmission locks exact prior submission event")
wrongChain = .AccountingReportingLifecycleEvent~new("LIFE-BAD-CHAIN", filing2, "ACKNOWLEDGED", "2026-07-16T11:05:00+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-RECEIPT/0.1", "sha256:regulator-receipt-authority-v1", resubmitEvent, .nil, "PORTAL-BAD-CHAIN", "sha256:bad-chain")
t~assertTrue(.LifecycleNegative~appendFails(lifecycle, wrongChain), "lifecycle requires exact immediately previous event identity")
wrongRelated = .AccountingReportingLifecycleEvent~new("LIFE-BAD-RELATED", filing2, "RESUBMITTED", "2026-07-16T11:06:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SUBMIT/0.1", "sha256:submit-authority-v1", accept2, submission2, "", "", "LIFE-NOT-PRESENT", "sha256:not-present")
t~assertTrue(.LifecycleNegative~appendFails(lifecycle, wrongRelated), "resubmission requires an existing exact prior submission event")
t~assertEq("accounting.reporting.lifecycle/0.1", lifecycle~projection["api"], "lifecycle projection API")
t~assertEq(lifecycle~fingerprint, lifecycle~projection["fingerprint"], "lifecycle projection deterministic fingerprint")

/* A superseded filing is historical evidence, not a mutable workflow item. */
badAfterSupersede = .AccountingReportingLifecycleEvent~new("LIFE-BAD", filing1, "ACKNOWLEDGED", "2026-07-17T09:00:00+01:00", "LAW-SOCIETY", "AUTHORITY:REGULATOR-RECEIPT/0.1", "sha256:regulator-receipt-authority-v1", accept2, .nil, "PORTAL-LATE-ACK", "sha256:late-ack")
t~assertTrue(.LifecycleNegative~appendFails(lifecycle, badAfterSupersede), "superseded filing cannot receive new lifecycle events")

/* Withdrawal is a new observation; it does not erase the filing or submission. */
snapshot3 = .AccountingReportingService~sealSnapshot("SNAP-REG-2026-V3", boundary, .array~of(book), "2026-01-01", "2026-12-31", "REPORT-SEAL-REG-V3")
attestation3 = .AccountingReportingEvidenceService~createAttestation("ATTEST-V3", snapshot3, "APPROVAL", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SIGN/0.1", "sha256:authority-v1", "2026-07-20T09:00:00+01:00", "AMENDED_REGULATORY_SUBMISSION", provider)
submission3 = .AccountingReportingEvidenceService~createSubmissionEvidence("SUBMISSION-V3", snapshot3, .array~of(attestation3), "LAW-SOCIETY", "REGULATOR-PORTAL", "2026-07-20T09:15:00+01:00", "PORTAL-SUBMISSION-3", "SUBMITTED")
filing3 = .AccountingReportingFilingVersion~new("FILING-2026-V3", filing1~seriesRef, "3", "AMENDMENT", snapshot3, .array~of(attestation3), filing2, "2026-07-20T09:05:00+01:00", "VOLUNTARY_DISCLOSURE_UPDATE")
lifecycle~addFiling(filing3)
submit3 = .AccountingReportingLifecycleEvent~new("LIFE-009", filing3, "SUBMITTED", "2026-07-20T09:15:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SUBMIT/0.1", "sha256:submit-authority-v1", accept2, submission3)
lifecycle~appendEvent(submit3)
withdraw3 = .AccountingReportingLifecycleEvent~new("LIFE-010", filing3, "WITHDRAWN", "2026-07-20T09:30:00+01:00", "PERSON:PARTNER:001", "AUTHORITY:REPORT-WITHDRAW/0.1", "sha256:withdraw-authority-v1", submit3, .nil, "WITHDRAWAL-REQUEST-3", "sha256:withdrawal-request-3")
lifecycle~appendEvent(withdraw3)
t~assertEq("WITHDRAWN", lifecycle~statusOf(filing3~filingId), "withdrawal retained as final observed state")
t~assertEq("3", lifecycle~filings~items, "withdrawn filing remains in lineage")
t~assertEq("SUBMITTED", submission3~status, "withdrawal does not rewrite original submission evidence")

say "reporting lifecycle assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

postFixture:
  use arg book, sourceRef, postingDate, amount
  draft = .AccountingJournalDraft~new(sourceRef, postingDate, "2026", "fixture/0.1", sourceRef)
  draft~addLine(.AccountingJournalLine~new("1000", "GBP", amount, 0, "cash"))
  draft~addLine(.AccountingJournalLine~new("4000", "GBP", 0, amount, "fees"))
  result = book~post(draft)
  if \result~ok then raise syntax 93.900 additional("fixture posting failed: " || result~errorCode)
  return

::class LifecycleNegative
::method appendFails class
  use arg lifecycle, event
  signal on syntax name failure
  lifecycle~appendEvent(event)
  signal off syntax
  return .false
failure:
  signal off syntax
  return .true

::class LifecycleFixtureProofProvider
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg keyRefArg, keyIdentityArg
  schemeRef = "FIXTURE-PROOF"
  digestAlgorithmRef = "FIXTURE-DIGEST"
  keyRef = keyRefArg~string
  keyIdentity = keyIdentityArg~string
::method createProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg payload
  digest = payload~length || ":" || payload~substr(1, 16)
  value = payload~reverse
  return .AccountingReportingProof~new(schemeRef, digestAlgorithmRef, digest, value, keyRef, keyIdentity)
::method verifyProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg payload, proof
  if proof~schemeRef \= schemeRef | proof~digestAlgorithmRef \= digestAlgorithmRef then return .false
  if proof~keyRef \= keyRef | proof~keyIdentity \= keyIdentity then return .false
  if proof~digestValue \= payload~length || ":" || payload~substr(1, 16) then return .false
  return proof~proofValue = payload~reverse

::options digits 50
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
