numeric digits 50

entity = "REGULATED_LAW_FIRM_LLP"
book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
draft = .AccountingJournalDraft~new("DEMO:REPORT:1", "2026-06-30", "2026", "demo/0.1", "fees")
draft~addLine(.AccountingJournalLine~new("1000", "GBP", "10000", 0, "cash"))
draft~addLine(.AccountingJournalLine~new("4000", "GBP", 0, "10000", "fees"))
book~post(draft)

boundary = .AccountingReportingBoundary~new("DEMO-BOUNDARY", "PROFESSIONAL-REGULATOR", "ANNUAL_ACCOUNTS", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), .nil, "demo.report/0.1", "sha256:demo-report-policy")
snapshot = .AccountingReportingService~sealSnapshot("DEMO-SNAPSHOT", boundary, .array~of(book), "2026-01-01", "2026-12-31", "DEMO-SEAL")

/* This fast provider is deliberately qualification/demo-only. Production can
 * use AccountingEd25519ReportingProofProvider from AccountingReportingCrypto.cls. */
provider = .DemoProofProvider~new("KEY:PARTNER", "sha256:key-v1")
attestation = .AccountingReportingEvidenceService~createAttestation("DEMO-ATTESTATION", snapshot, "APPROVAL", "PERSON:PARTNER", "AUTHORITY:REPORT-SIGN/0.1", "sha256:authority-v1", "2026-07-15T10:30:00+01:00", "REGULATORY_SUBMISSION", provider)
submission = .AccountingReportingEvidenceService~createSubmissionEvidence("DEMO-SUBMISSION", snapshot, .array~of(attestation), "PROFESSIONAL-REGULATOR", "REGULATOR-PORTAL", "2026-07-15T11:00:00+01:00", "PORTAL-123", "ACCEPTED", "2026-07-15T11:00:03+01:00", "RECEIPT-123", "sha256:receipt-v1")

say "snapshot=" snapshot~snapshotId
say "snapshot fingerprint retained=" snapshot~fingerprint \= ""
say "attestation=" attestation~attestationId
say "attestation verified=" .AccountingReportingEvidenceService~verifyAttestation(attestation, snapshot, provider)~ok
say "submission=" submission~submissionId "status=" submission~status
say "submission verified=" .AccountingReportingEvidenceService~verifySubmissionEvidence(submission, snapshot, .array~of(attestation))~ok
exit 0

::class DemoProofProvider
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg keyRefArg, keyIdentityArg
  schemeRef = "DEMO-PROOF"
  digestAlgorithmRef = "DEMO-DIGEST"
  keyRef = keyRefArg
  keyIdentity = keyIdentityArg
::method createProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg payload
  return .AccountingReportingProof~new(schemeRef, digestAlgorithmRef, payload~length, payload~reverse, keyRef, keyIdentity)
::method verifyProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg payload, proof
  return proof~schemeRef = schemeRef & proof~digestAlgorithmRef = digestAlgorithmRef & proof~keyRef = keyRef & proof~keyIdentity = keyIdentity & proof~digestValue = payload~length & proof~proofValue = payload~reverse

::requires "AccountingEngine.cls"
