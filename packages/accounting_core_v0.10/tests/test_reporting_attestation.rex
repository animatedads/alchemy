t = .AccountingTest~new
numeric digits 50

entity = "REGULATED_LAW_FIRM_LLP"
book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

draft = .AccountingJournalDraft~new("REPORT:SOURCE:1", "2026-06-30", "2026", "fixture/0.1", "regulated fees")
draft~addLine(.AccountingJournalLine~new("1000", "GBP", "125000", 0, "cash"))
draft~addLine(.AccountingJournalLine~new("4000", "GBP", 0, "125000", "fees"))
t~assertTrue(book~post(draft)~ok, "fixture journal posts")

boundary = .AccountingReportingBoundary~new("BOUNDARY-REG-2026", "LAW-SOCIETY", "ANNUAL_REGULATED_ACCOUNTS", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), .nil, "reg.report/0.1", "sha256:reg-report-policy-v1")
snapshot = .AccountingReportingService~sealSnapshot("SNAP-REG-2026", boundary, .array~of(book), "2026-01-01", "2026-12-31", "REPORT-SEAL-REG-001")

t~assertEq("accounting.reporting.attestation/0.1", .AccountingBuild~REPORTING_ATTESTATION_API, "attestation API explicit")
t~assertEq("accounting.reporting.submission/0.1", .AccountingBuild~REPORTING_SUBMISSION_API, "submission API explicit")

provider = .FixtureReportingProofProvider~new("KEY:REPORTING-PARTNER:001", "sha256:key-material-reporting-partner-v1")
meta = .directory~new
meta["reporting.role"] = "responsible-partner"
evidence = .array~of("AUTHORITY:PARTNER:2026", "BOARD:MINUTE:2026-07-15")
attestation = .AccountingReportingEvidenceService~createAttestation("ATTEST-REG-2026-PARTNER", snapshot, "APPROVAL", "PERSON:PARTNER:001", "AUTHORITY:REPORT-SIGN/0.1", "sha256:authority-grant-v7", "2026-07-15T10:30:00+01:00", "REGULATORY_SUBMISSION", provider, evidence, meta)

t~assertEq(snapshot~snapshotId, attestation~snapshotId, "attestation binds snapshot id")
t~assertEq(snapshot~fingerprint, attestation~snapshotFingerprint, "attestation binds exact snapshot fingerprint")
t~assertEq("FIXTURE-PROOF", attestation~proof~schemeRef, "proof scheme retained")
t~assertEq("FIXTURE-DIGEST", attestation~proof~digestAlgorithmRef, "digest algorithm retained")
t~assertEq("sha256:authority-grant-v7", attestation~authorityIdentity, "exact authority identity is signed claim")
t~assertEq("accounting.reporting.attestation/0.1", attestation~projection["api"], "attestation projection API")
t~assertEq(attestation~fingerprint, attestation~projection["fingerprint"], "attestation projection fingerprint")

verify = .AccountingReportingEvidenceService~verifyAttestation(attestation, snapshot, provider)
t~assertTrue(verify~ok, "provider verifies own proof")
t~assertEq("VERIFIED", verify~status, "proof verification explicit")
verifier = .FixtureReportingProofProvider~new("KEY:REPORTING-PARTNER:001", "sha256:key-material-reporting-partner-v1")
verify = .AccountingReportingEvidenceService~verifyAttestation(attestation, snapshot, verifier)
t~assertTrue(verify~ok, "separate verifier validates attestation")

wrongVerifier = .FixtureReportingProofProvider~new("KEY:REPORTING-PARTNER:001", "sha256:wrong-key-identity")
verify = .AccountingReportingEvidenceService~verifyAttestation(attestation, snapshot, wrongVerifier)
t~assertEq("PROOF_KEY_IDENTITY_MISMATCH", verify~errorCode, "exact key identity cannot be substituted")

/* Same snapshot id but changed seal evidence creates a different immutable snapshot. */
changedSnapshot = .AccountingReportingService~sealSnapshot("SNAP-REG-2026", boundary, .array~of(book), "2026-01-01", "2026-12-31", "DIFFERENT-SEAL")
verify = .AccountingReportingEvidenceService~verifyAttestation(attestation, changedSnapshot, verifier)
t~assertEq("ATTESTATION_SNAPSHOT_MISMATCH", verify~errorCode, "signature cannot move to different snapshot contents")

/* Proof tampering is detected after structural binding succeeds. */
proof = attestation~proof
badValue = "tampered:" || proof~proofValue
badProof = .AccountingReportingProof~new(proof~schemeRef, proof~digestAlgorithmRef, proof~digestValue, badValue, proof~keyRef, proof~keyIdentity)
badAttestation = .AccountingReportingAttestation~new(attestation~attestationId, snapshot, attestation~attestationType, attestation~attestorRef, attestation~authorityRef, attestation~authorityIdentity, attestation~attestedAt, attestation~purposeRef, badProof, attestation~evidenceRefs, attestation~metadata)
verify = .AccountingReportingEvidenceService~verifyAttestation(badAttestation, snapshot, verifier)
t~assertEq("PROOF_INVALID", verify~errorCode, "tampered signature rejected")

submission = .AccountingReportingEvidenceService~createSubmissionEvidence("SUBMIT-REG-2026", snapshot, .array~of(attestation), "LAW-SOCIETY", "REGULATOR-PORTAL", "2026-07-15T11:00:00+01:00", "PORTAL-SUBMISSION-7781", "ACCEPTED", "2026-07-15T11:00:04+01:00", "PORTAL-RECEIPT-7781", "sha256:portal-receipt-bytes-v1", .array~of("EVIDENCE:PORTAL-RECEIPT:7781"))
t~assertEq("accounting.reporting.submission/0.1", submission~projection["api"], "submission projection API")
t~assertEq(snapshot~fingerprint, submission~snapshotFingerprint, "submission binds exact snapshot")
t~assertEq("1", submission~attestationIdentities~items, "submission retains exact attestation set")
t~assertEq(attestation~fingerprint, submission~attestationIdentities[1]["fingerprint"], "submission binds exact attestation fingerprint")
t~assertEq("sha256:portal-receipt-bytes-v1", submission~externalReceiptIdentity, "external receipt identity retained")
verify = .AccountingReportingEvidenceService~verifySubmissionEvidence(submission, snapshot, .array~of(attestation))
t~assertTrue(verify~ok, "submission evidence verifies against snapshot and attestation set")
verify = .AccountingReportingEvidenceService~verifySubmissionEvidence(submission, snapshot, .array~new)
t~assertEq("SUBMISSION_ATTESTATION_SET_MISMATCH", verify~errorCode, "attestation cannot be removed from submitted evidence")

/* Discovery of a later/backdated journal makes the report population stale,
 * but the old signature and receipt remain valid evidence of what was filed. */
late = .AccountingJournalDraft~new("REPORT:LATE", "2026-06-29", "2026", "fixture/0.1", "late discovery")
late~addLine(.AccountingJournalLine~new("1000", "GBP", "1", 0, "cash"))
late~addLine(.AccountingJournalLine~new("4000", "GBP", 0, "1", "fees"))
t~assertTrue(book~post(late)~ok, "late discovered journal posts")
snapshotVerify = .AccountingReportingService~verifySnapshot(snapshot, boundary, .array~of(book))
t~assertEq("REPORT_POPULATION_STALE", snapshotVerify~errorCode, "old report population becomes stale")
t~assertTrue(.AccountingReportingEvidenceService~verifyAttestation(attestation, snapshot, verifier)~ok, "attestation remains proof of immutable old snapshot")
t~assertTrue(.AccountingReportingEvidenceService~verifySubmissionEvidence(submission, snapshot, .array~of(attestation))~ok, "receipt remains proof of what was actually submitted")

say "reporting attestation assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::class FixtureReportingProofProvider
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
