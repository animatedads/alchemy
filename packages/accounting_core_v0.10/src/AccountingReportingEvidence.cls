/*
 * Accounting Core v0.9 reporting attestation and submission evidence.
 *
 * This layer binds external approvals/signatures/receipts to an immutable
 * AccountingReportingSnapshot.  It does not decide who is authorised to sign,
 * mandate a cryptographic algorithm, submit reports, or mutate accounting.
 */

::options digits 50

::class AccountingReportingProof public
::attribute schemeRef get
::attribute digestAlgorithmRef get
::attribute digestValue get
::attribute proofValue get
::attribute keyRef get
::attribute keyIdentity get
::method init
  expose schemeRef digestAlgorithmRef digestValue proofValue keyRef keyIdentity metadata
  use arg schemeArg, digestAlgorithmArg, digestArg, proofArg, keyRefArg, keyIdentityArg, metadataArg = .nil
  schemeRef = .AccountingUtil~requireText(schemeArg, "reporting proof schemeRef")~upper
  digestAlgorithmRef = .AccountingUtil~requireText(digestAlgorithmArg, "reporting proof digestAlgorithmRef")~upper
  digestValue = .AccountingUtil~requireText(digestArg, "reporting proof digestValue")
  proofValue = .AccountingUtil~requireText(proofArg, "reporting proof proofValue")
  keyRef = .AccountingUtil~requireText(keyRefArg, "reporting proof keyRef")
  keyIdentity = .AccountingUtil~requireText(keyIdentityArg, "reporting proof keyIdentity")
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method fingerprint
  expose schemeRef digestAlgorithmRef digestValue proofValue keyRef keyIdentity metadata
  return schemeRef || "|" || digestAlgorithmRef || "|" || digestValue || "|" || proofValue || "|" || keyRef || "|" || keyIdentity || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method projection
  expose schemeRef digestAlgorithmRef digestValue proofValue keyRef keyIdentity metadata
  p = .directory~new
  p["scheme_ref"] = schemeRef
  p["digest_algorithm_ref"] = digestAlgorithmRef
  p["digest_value"] = digestValue
  p["proof_value"] = proofValue
  p["key_ref"] = keyRef
  p["key_identity"] = keyIdentity
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingAttestation public
::attribute attestationId get
::attribute snapshotId get
::attribute snapshotFingerprint get
::attribute boundaryFingerprint get
::attribute attestationType get
::attribute attestorRef get
::attribute authorityRef get
::attribute authorityIdentity get
::attribute attestedAt get
::attribute purposeRef get
::attribute proof get
::method init
  expose attestationId snapshotId snapshotFingerprint boundaryFingerprint attestationType attestorRef authorityRef authorityIdentity attestedAt purposeRef proof evidenceRefs metadata
  use arg idArg, snapshot, typeArg, attestorArg, authorityRefArg, authorityIdentityArg, attestedAtArg, purposeArg, proofArg, evidenceArg = .nil, metadataArg = .nil
  attestationId = .AccountingUtil~requireText(idArg, "reporting attestationId")
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then raise syntax 93.900 additional("AccountingReportingSnapshot required")
  snapshotId = snapshot~snapshotId
  snapshotFingerprint = snapshot~fingerprint
  boundaryFingerprint = snapshot~boundaryFingerprint
  attestationType = .AccountingUtil~requireText(typeArg, "reporting attestationType")~upper
  attestorRef = .AccountingUtil~requireText(attestorArg, "reporting attestorRef")
  authorityRef = .AccountingUtil~requireText(authorityRefArg, "reporting authorityRef")
  authorityIdentity = .AccountingUtil~requireText(authorityIdentityArg, "reporting authorityIdentity")
  attestedAt = .AccountingUtil~requireText(attestedAtArg, "reporting attestedAt")
  purposeRef = .AccountingUtil~requireText(purposeArg, "reporting purposeRef")
  if proofArg == .nil | \proofArg~isA(.AccountingReportingProof) then raise syntax 93.900 additional("AccountingReportingProof required")
  proof = proofArg
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::method payload
  expose snapshotId snapshotFingerprint boundaryFingerprint attestationType attestorRef authorityRef authorityIdentity attestedAt purposeRef proof evidenceRefs metadata
  return .AccountingReportingEvidenceService~attestationPayload(snapshotId, snapshotFingerprint, boundaryFingerprint, attestationType, attestorRef, authorityRef, authorityIdentity, attestedAt, purposeRef, proof~schemeRef, proof~digestAlgorithmRef, proof~keyRef, proof~keyIdentity, evidenceRefs, metadata)

::method fingerprint
  expose attestationId proof
  return attestationId || "|" || self~payload || "|" || proof~fingerprint

::method projection
  expose attestationId snapshotId snapshotFingerprint boundaryFingerprint attestationType attestorRef authorityRef authorityIdentity attestedAt purposeRef proof evidenceRefs metadata
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_ATTESTATION_API
  p["attestation_id"] = attestationId
  p["snapshot_id"] = snapshotId
  p["snapshot_fingerprint"] = snapshotFingerprint
  p["boundary_fingerprint"] = boundaryFingerprint
  p["attestation_type"] = attestationType
  p["attestor_ref"] = attestorRef
  p["authority_ref"] = authorityRef
  p["authority_identity"] = authorityIdentity
  p["attested_at"] = attestedAt
  p["purpose_ref"] = purposeRef
  p["proof"] = proof~projection
  p["evidence_refs"] = .AccountingUtil~copyArray(evidenceRefs)
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingSubmissionEvidence public
::attribute submissionId get
::attribute snapshotId get
::attribute snapshotFingerprint get
::attribute boundaryFingerprint get
::attribute reportingAuthorityRef get
::attribute submissionChannelRef get
::attribute submittedAt get
::attribute externalSubmissionRef get
::attribute status get
::attribute receivedAt get
::attribute externalReceiptRef get
::attribute externalReceiptIdentity get
::method init
  expose submissionId snapshotId snapshotFingerprint boundaryFingerprint reportingAuthorityRef submissionChannelRef submittedAt externalSubmissionRef status receivedAt externalReceiptRef externalReceiptIdentity attestationIdentities evidenceRefs metadata
  use arg idArg, snapshot, attestationsArg, authorityArg, channelArg, submittedAtArg, externalSubmissionArg, statusArg, receivedAtArg = "", externalReceiptArg = "", externalReceiptIdentityArg = "", evidenceArg = .nil, metadataArg = .nil
  submissionId = .AccountingUtil~requireText(idArg, "reporting submissionId")
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then raise syntax 93.900 additional("AccountingReportingSnapshot required")
  snapshotId = snapshot~snapshotId
  snapshotFingerprint = snapshot~fingerprint
  boundaryFingerprint = snapshot~boundaryFingerprint
  reportingAuthorityRef = .AccountingUtil~requireText(authorityArg, "submission reportingAuthorityRef")
  submissionChannelRef = .AccountingUtil~requireText(channelArg, "submission channelRef")
  submittedAt = .AccountingUtil~requireText(submittedAtArg, "submission submittedAt")
  externalSubmissionRef = .AccountingUtil~requireText(externalSubmissionArg, "externalSubmissionRef")
  status = .AccountingUtil~requireText(statusArg, "submission status")~upper
  receivedAt = receivedAtArg~string~strip
  externalReceiptRef = externalReceiptArg~string~strip
  externalReceiptIdentity = externalReceiptIdentityArg~string~strip
  attestationIdentities = .AccountingReportingEvidenceService~attestationIdentities(attestationsArg)
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
  expose submissionId snapshotId snapshotFingerprint boundaryFingerprint reportingAuthorityRef submissionChannelRef submittedAt externalSubmissionRef status receivedAt externalReceiptRef externalReceiptIdentity attestationIdentities evidenceRefs metadata
  return submissionId || "|" || snapshotId || "|" || snapshotFingerprint || "|" || boundaryFingerprint || "|" || reportingAuthorityRef || "|" || submissionChannelRef || "|" || submittedAt || "|" || externalSubmissionRef || "|" || status || "|" || receivedAt || "|" || externalReceiptRef || "|" || externalReceiptIdentity || "|" || .AccountingUtil~canonicalArray(attestationIdentities) || "|" || .AccountingUtil~canonicalArray(evidenceRefs) || "|" || .AccountingUtil~canonicalDirectory(metadata)

::method projection
  expose submissionId snapshotId snapshotFingerprint boundaryFingerprint reportingAuthorityRef submissionChannelRef submittedAt externalSubmissionRef status receivedAt externalReceiptRef externalReceiptIdentity attestationIdentities evidenceRefs metadata
  p = .directory~new
  p["api"] = .AccountingBuild~REPORTING_SUBMISSION_API
  p["submission_id"] = submissionId
  p["snapshot_id"] = snapshotId
  p["snapshot_fingerprint"] = snapshotFingerprint
  p["boundary_fingerprint"] = boundaryFingerprint
  p["reporting_authority_ref"] = reportingAuthorityRef
  p["submission_channel_ref"] = submissionChannelRef
  p["submitted_at"] = submittedAt
  p["external_submission_ref"] = externalSubmissionRef
  p["status"] = status
  p["received_at"] = receivedAt
  p["external_receipt_ref"] = externalReceiptRef
  p["external_receipt_identity"] = externalReceiptIdentity
  p["attestations"] = .AccountingUtil~copyArray(attestationIdentities)
  p["evidence_refs"] = .AccountingUtil~copyArray(evidenceRefs)
  p["metadata"] = .AccountingUtil~copyDirectory(metadata)
  p["fingerprint"] = self~fingerprint
  return p

::class AccountingReportingEvidenceService public
::method createAttestation class
  use arg idArg, snapshot, typeArg, attestorArg, authorityRefArg, authorityIdentityArg, attestedAtArg, purposeArg, proofProvider, evidenceArg = .nil, metadataArg = .nil
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then raise syntax 93.900 additional("AccountingReportingSnapshot required")
  if proofProvider == .nil then raise syntax 93.900 additional("reporting proof provider required")
  schemeRef = .AccountingUtil~requireText(proofProvider~schemeRef, "proof provider schemeRef")~upper
  digestAlgorithmRef = .AccountingUtil~requireText(proofProvider~digestAlgorithmRef, "proof provider digestAlgorithmRef")~upper
  keyRef = .AccountingUtil~requireText(proofProvider~keyRef, "proof provider keyRef")
  keyIdentity = .AccountingUtil~requireText(proofProvider~keyIdentity, "proof provider keyIdentity")
  evidenceRefs = .AccountingUtil~copyArray(evidenceArg)
  metadata = .AccountingUtil~copyDirectory(metadataArg)
  payload = self~attestationPayload(snapshot~snapshotId, snapshot~fingerprint, snapshot~boundaryFingerprint, typeArg~string~upper, attestorArg, authorityRefArg, authorityIdentityArg, attestedAtArg, purposeArg, schemeRef, digestAlgorithmRef, keyRef, keyIdentity, evidenceRefs, metadata)
  proof = proofProvider~createProof(payload)
  if proof == .nil | \proof~isA(.AccountingReportingProof) then raise syntax 93.900 additional("proof provider must return AccountingReportingProof")
  if proof~schemeRef \= schemeRef | proof~digestAlgorithmRef \= digestAlgorithmRef | proof~keyRef \= keyRef | proof~keyIdentity \= keyIdentity then raise syntax 93.900 additional("reporting proof provider identity mismatch")
  return .AccountingReportingAttestation~new(idArg, snapshot, typeArg, attestorArg, authorityRefArg, authorityIdentityArg, attestedAtArg, purposeArg, proof, evidenceRefs, metadata)

::method verifyAttestationBinding class
  use arg attestation, snapshot
  if attestation == .nil | \attestation~isA(.AccountingReportingAttestation) then return .AccountingReportingEvidenceVerification~failure("ATTESTATION_REQUIRED", "AccountingReportingAttestation required")
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then return .AccountingReportingEvidenceVerification~failure("SNAPSHOT_REQUIRED", "AccountingReportingSnapshot required")
  if attestation~snapshotId \= snapshot~snapshotId then return .AccountingReportingEvidenceVerification~failure("ATTESTATION_SNAPSHOT_ID_MISMATCH", attestation~snapshotId)
  if attestation~snapshotFingerprint \= snapshot~fingerprint then return .AccountingReportingEvidenceVerification~failure("ATTESTATION_SNAPSHOT_MISMATCH", attestation~snapshotId)
  if attestation~boundaryFingerprint \= snapshot~boundaryFingerprint then return .AccountingReportingEvidenceVerification~failure("ATTESTATION_BOUNDARY_MISMATCH", attestation~snapshotId)
  return .AccountingReportingEvidenceVerification~success("BOUND")

::method verifyAttestation class
  use arg attestation, snapshot, proofVerifier
  binding = self~verifyAttestationBinding(attestation, snapshot)
  if \binding~ok then return binding
  if proofVerifier == .nil then return .AccountingReportingEvidenceVerification~failure("PROOF_VERIFIER_REQUIRED", attestation~attestationId)
  proof = attestation~proof
  signal on syntax name proofFailure
  if proofVerifier~schemeRef~string~upper \= proof~schemeRef then return .AccountingReportingEvidenceVerification~failure("PROOF_SCHEME_MISMATCH", proof~schemeRef)
  if proofVerifier~digestAlgorithmRef~string~upper \= proof~digestAlgorithmRef then return .AccountingReportingEvidenceVerification~failure("PROOF_DIGEST_ALGORITHM_MISMATCH", proof~digestAlgorithmRef)
  if proofVerifier~keyRef~string \= proof~keyRef then return .AccountingReportingEvidenceVerification~failure("PROOF_KEY_REF_MISMATCH", proof~keyRef)
  if proofVerifier~keyIdentity~string \= proof~keyIdentity then return .AccountingReportingEvidenceVerification~failure("PROOF_KEY_IDENTITY_MISMATCH", proof~keyIdentity)
  valid = proofVerifier~verifyProof(attestation~payload, proof)
  signal off syntax
  if \valid then return .AccountingReportingEvidenceVerification~failure("PROOF_INVALID", attestation~attestationId)
  return .AccountingReportingEvidenceVerification~success("VERIFIED")
proofFailure:
  signal off syntax
  return .AccountingReportingEvidenceVerification~failure("PROOF_VERIFICATION_FAILED", condition("D"))

::method createSubmissionEvidence class
  use arg idArg, snapshot, attestationsArg, authorityArg, channelArg, submittedAtArg, externalSubmissionArg, statusArg, receivedAtArg = "", externalReceiptArg = "", externalReceiptIdentityArg = "", evidenceArg = .nil, metadataArg = .nil
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then raise syntax 93.900 additional("AccountingReportingSnapshot required")
  if attestationsArg \== .nil then do attestation over attestationsArg
    binding = self~verifyAttestationBinding(attestation, snapshot)
    if \binding~ok then raise syntax 93.900 additional("submission attestation is not bound to snapshot: " || binding~errorCode)
  end
  return .AccountingReportingSubmissionEvidence~new(idArg, snapshot, attestationsArg, authorityArg, channelArg, submittedAtArg, externalSubmissionArg, statusArg, receivedAtArg, externalReceiptArg, externalReceiptIdentityArg, evidenceArg, metadataArg)

::method verifySubmissionEvidence class
  use arg submission, snapshot, attestationsArg = .nil
  if submission == .nil | \submission~isA(.AccountingReportingSubmissionEvidence) then return .AccountingReportingEvidenceVerification~failure("SUBMISSION_REQUIRED", "AccountingReportingSubmissionEvidence required")
  if snapshot == .nil | \snapshot~isA(.AccountingReportingSnapshot) then return .AccountingReportingEvidenceVerification~failure("SNAPSHOT_REQUIRED", "AccountingReportingSnapshot required")
  if submission~snapshotId \= snapshot~snapshotId then return .AccountingReportingEvidenceVerification~failure("SUBMISSION_SNAPSHOT_ID_MISMATCH", submission~snapshotId)
  if submission~snapshotFingerprint \= snapshot~fingerprint then return .AccountingReportingEvidenceVerification~failure("SUBMISSION_SNAPSHOT_MISMATCH", submission~snapshotId)
  if submission~boundaryFingerprint \= snapshot~boundaryFingerprint then return .AccountingReportingEvidenceVerification~failure("SUBMISSION_BOUNDARY_MISMATCH", submission~snapshotId)
  expected = submission~attestationIdentities
  supplied = self~attestationIdentities(attestationsArg)
  if .AccountingUtil~canonicalArray(expected) \= .AccountingUtil~canonicalArray(supplied) then return .AccountingReportingEvidenceVerification~failure("SUBMISSION_ATTESTATION_SET_MISMATCH", submission~submissionId)
  do attestation over .AccountingUtil~copyArray(attestationsArg)
    binding = self~verifyAttestationBinding(attestation, snapshot)
    if \binding~ok then return binding
  end
  return .AccountingReportingEvidenceVerification~success("VERIFIED")

::method attestationIdentities class
  use arg attestationsArg
  rows = .array~new
  if attestationsArg == .nil then return rows
  if \attestationsArg~isA(.Array) then raise syntax 93.900 additional("attestations array required")
  seen = .directory~new
  do attestation over attestationsArg
    if attestation == .nil | \attestation~isA(.AccountingReportingAttestation) then raise syntax 93.900 additional("AccountingReportingAttestation required")
    if seen~hasIndex(attestation~attestationId) then raise syntax 93.900 additional("duplicate reporting attestationId: " || attestation~attestationId)
    seen[attestation~attestationId] = .true
    row = .directory~new
    row["attestation_id"] = attestation~attestationId
    row["fingerprint"] = attestation~fingerprint
    rows~append(row)
  end
  return rows

::method attestationPayload class
  use arg snapshotId, snapshotFingerprint, boundaryFingerprint, typeArg, attestorArg, authorityRefArg, authorityIdentityArg, attestedAtArg, purposeArg, schemeArg, digestAlgorithmArg, keyRefArg, keyIdentityArg, evidenceArg = .nil, metadataArg = .nil
  return "accounting.reporting.attestation.payload/0.1" || "|" || .AccountingUtil~requireText(snapshotId, "snapshotId") || "|" || .AccountingUtil~requireText(snapshotFingerprint, "snapshotFingerprint") || "|" || .AccountingUtil~requireText(boundaryFingerprint, "boundaryFingerprint") || "|" || .AccountingUtil~requireText(typeArg, "attestationType")~upper || "|" || .AccountingUtil~requireText(attestorArg, "attestorRef") || "|" || .AccountingUtil~requireText(authorityRefArg, "authorityRef") || "|" || .AccountingUtil~requireText(authorityIdentityArg, "authorityIdentity") || "|" || .AccountingUtil~requireText(attestedAtArg, "attestedAt") || "|" || .AccountingUtil~requireText(purposeArg, "purposeRef") || "|" || .AccountingUtil~requireText(schemeArg, "schemeRef")~upper || "|" || .AccountingUtil~requireText(digestAlgorithmArg, "digestAlgorithmRef")~upper || "|" || .AccountingUtil~requireText(keyRefArg, "keyRef") || "|" || .AccountingUtil~requireText(keyIdentityArg, "keyIdentity") || "|" || .AccountingUtil~canonicalArray(.AccountingUtil~copyArray(evidenceArg)) || "|" || .AccountingUtil~canonicalDirectory(.AccountingUtil~copyDirectory(metadataArg))

::class AccountingReportingEvidenceVerification public
::attribute ok get
::attribute status get
::attribute errorCode get
::attribute message get
::method success class
  use arg statusArg
  return self~new(.true, statusArg, "", "")
::method failure class
  use arg codeArg, messageArg
  return self~new(.false, "INVALID", codeArg, messageArg)
::method init
  expose ok status errorCode message
  use arg okArg, statusArg, codeArg, messageArg
  ok = okArg
  status = statusArg~string
  errorCode = codeArg~string
  message = messageArg~string

::requires "AccountingScopes.cls"
