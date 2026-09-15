/* Compact v0.10 lifecycle demonstration: rejected original -> corrected resubmission -> accepted. */
numeric digits 50

entity = "DEMO_REGULATED_LAW_FIRM_LLP"
book = .AccountingBook~new(entity, "STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Fees", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
call post book, "DEMO:1", "2026-06-30", "10000"

boundary=.AccountingReportingBoundary~new("DEMO-BOUNDARY", "DEMO-REGULATOR", "ANNUAL", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("STAT"), .nil, "demo.report/0.1", "sha256:demo-report-policy")
s1=.AccountingReportingService~sealSnapshot("SNAP-V1", boundary, .array~of(book), "2026-01-01", "2026-12-31", "SEAL-V1")
p=.DemoProof~new
a1=.AccountingReportingEvidenceService~createAttestation("ATTEST-V1", s1, "APPROVAL", "PARTNER-1", "AUTH:REPORT", "sha256:auth-v1", "2026-07-01T09:00:00Z", "FILE", p)
sub1=.AccountingReportingEvidenceService~createSubmissionEvidence("SUB-V1", s1, .array~of(a1), "DEMO-REGULATOR", "PORTAL", "2026-07-01T10:00:00Z", "EXT-SUB-1", "SUBMITTED")
f1=.AccountingReportingFilingVersion~new("FILING-V1", "DEMO:ANNUAL:2026", "1", "ORIGINAL", s1, .array~of(a1), .nil, "2026-07-01T09:30:00Z")
life=.AccountingReportingLifecycle~new(f1~seriesRef); life~addFiling(f1)
e1=.AccountingReportingLifecycleEvent~new("LIFE-1", f1, "SUBMITTED", "2026-07-01T10:00:00Z", "PARTNER-1", "AUTH:SUBMIT", "sha256:submit-auth", .nil, sub1); life~appendEvent(e1)
e2=.AccountingReportingLifecycleEvent~new("LIFE-2", f1, "REJECTED", "2026-07-02T09:00:00Z", "DEMO-REGULATOR", "AUTH:DECISION", "sha256:decision-auth", e1, .nil, "REJECT-1", "sha256:reject-1"); life~appendEvent(e2)

call post book, "DEMO:LATE", "2026-06-29", "1"
s2=.AccountingReportingService~sealSnapshot("SNAP-V2", boundary, .array~of(book), "2026-01-01", "2026-12-31", "SEAL-V2")
a2=.AccountingReportingEvidenceService~createAttestation("ATTEST-V2", s2, "APPROVAL", "PARTNER-1", "AUTH:REPORT", "sha256:auth-v1", "2026-07-02T10:00:00Z", "CORRECTED_FILE", p)
sub2=.AccountingReportingEvidenceService~createSubmissionEvidence("SUB-V2", s2, .array~of(a2), "DEMO-REGULATOR", "PORTAL", "2026-07-02T10:30:00Z", "EXT-SUB-2", "SUBMITTED")
f2=.AccountingReportingFilingVersion~new("FILING-V2", f1~seriesRef, "2", "CORRECTION", s2, .array~of(a2), f1, "2026-07-02T10:15:00Z", "LATE_ENTRY")
life~addFiling(f2)
e3=.AccountingReportingLifecycleEvent~new("LIFE-3", f1, "SUPERSEDED", "2026-07-02T10:16:00Z", "PARTNER-1", "AUTH:CORRECT", "sha256:correct-auth", e2, .nil, "", "", f2~filingId, f2~fingerprint); life~appendEvent(e3)
e4=.AccountingReportingLifecycleEvent~new("LIFE-4", f2, "RESUBMITTED", "2026-07-02T10:30:00Z", "PARTNER-1", "AUTH:SUBMIT", "sha256:submit-auth", e3, sub2, "", "", e1~eventId, e1~fingerprint); life~appendEvent(e4)
e5=.AccountingReportingLifecycleEvent~new("LIFE-5", f2, "ACCEPTED", "2026-07-02T11:00:00Z", "DEMO-REGULATOR", "AUTH:DECISION", "sha256:decision-auth", e4, .nil, "ACCEPT-2", "sha256:accept-2"); life~appendEvent(e5)

say "old snapshot verification=" .AccountingReportingService~verifySnapshot(s1, boundary, .array~of(book))~errorCode
say "filing V1 status=" life~statusOf(f1~filingId)
say "filing V2 status=" life~statusOf(f2~filingId)
say "lifecycle events=" life~events~items
exit 0

post:
  use arg b, ref, d, amount
  j=.AccountingJournalDraft~new(ref,d,"2026","demo/0.1",ref)
  j~addLine(.AccountingJournalLine~new("1000","GBP",amount,0,"cash"))
  j~addLine(.AccountingJournalLine~new("4000","GBP",0,amount,"fees"))
  r=b~post(j); if \r~ok then raise syntax 93.900 additional(r~errorCode)
  return

::class DemoProof
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  schemeRef="FIXTURE"; digestAlgorithmRef="FIXTURE"; keyRef="DEMO-KEY"; keyIdentity="sha256:demo-key"
::method createProof
  expose schemeRef digestAlgorithmRef keyRef keyIdentity
  use arg payload
  return .AccountingReportingProof~new(schemeRef,digestAlgorithmRef,payload~length,payload~reverse,keyRef,keyIdentity)
::method verifyProof
  use arg payload, proof
  return proof~proofValue=payload~reverse

::options digits 50
::requires "AccountingEngine.cls"
