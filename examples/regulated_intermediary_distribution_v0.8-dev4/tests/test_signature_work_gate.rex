fx = .RIDWorkIntegrationFixtures~setup("MORTGAGE")
offered = .RIDWorkIntegrationFixtures~providerStatus(fx, "MTG-OFFER-30", 30, "OFFERED")
.RIDTestSupport~ok(.RIDWorkIntegrationFixtures~driveStatus(fx, offered))
item = .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~assertEq("SIGNATURE", item~completionMode)
.RIDTestSupport~assertEq("PRESENT_MORTGAGE_OFFER_AND_SIGN", item~workType)

r = fx["SERVICE"]~completeWork(item~workItemId, "ACK:NOT-A-SIGNATURE")
.RIDTestSupport~assertTrue(\r~ok)
.RIDTestSupport~assertEq("COMPLETE_SIGNATURE_REQUIRED", r~code)

envelope = .RIDSignatureEnvelope~new("ENV-WORK-1", fx["CASE"]~caseId, "MORTGAGE_OFFER", "OFFER|SEM|1", "1", "SHA-256", "0123456789abcdef", "STORE:OFFER:1", "DURABLE:OFFER:1")
req = .RIDSignatureRequirement~new("CUSTOMER-SIGN", "CUSTOMER:W", "CUSTOMER", "ACCEPT_MORTGAGE_OFFER", .true)
.RIDTestSupport~ok(envelope~addRequirement(req))
.RIDTestSupport~ok(envelope~seal)
r = fx["SERVICE"]~completeWork(item~workItemId, "", envelope)
.RIDTestSupport~assertTrue(\r~ok)
.RIDTestSupport~assertEq("SIGNATURE_NOT_COMPLETE", r~code)

keyRegistry = .RIDSigningKeyRegistry~new
before = fx["ENV"]["NOW"] - .TimeSpan~new(0,0,0,0,60)
.RIDTestSupport~ok(keyRegistry~register(.RIDSigningKey~new("CUSTOMER-W-KEY", "CUSTOMER:W", "ED25519", "dummy-public", "DOCUMENT_SIGNATURE", before, .nil, "KEY:EVIDENCE")))
svc = .RIDDigitalSignatureService~new(keyRegistry, .RIDAlwaysValidSignatureVerifier~new)
evidence = .RIDSignatureEvidence~new("SIG-WORK-1", envelope~envelopeId, req~requirementId, req~signerRef, req~signerRole, "CUSTOMER-W-KEY", "aabbcc", fx["ENV"]["NOW"], "AUTH:STRONG:1", "CONSENT:1", "SIGNATURE:EVIDENCE:1")
.RIDTestSupport~ok(svc~submitDocumentSignature(envelope, evidence))
.RIDTestSupport~assertEq("COMPLETE", envelope~state)
.RIDTestSupport~ok(fx["SERVICE"]~completeWork(item~workItemId, "", envelope))
.RIDTestSupport~assertEq("COMPLETE", item~status)
.RIDTestSupport~assertEq("SIGNATURE_ENVELOPE:ENV-WORK-1", item~completionEvidenceRef)

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS signature-required work cannot complete without a completed digital signature envelope"
exit 0

::requires "WorkTestSupport.cls"
