clock=.RIDManualTimeSource~new(1000000)
fx=.RIDWireUITestFixtures~setup("OFFERED","MORTGAGE",clock)
item=fx["SERVICE"]~workItemsForCase("CASE-W")[1]
.RIDTestSupport~assertEq("SIGNATURE",item~completionMode)
env=.RIDSignatureEnvelope~new("ENV-WIRE-1","CASE-W","MORTGAGE_OFFER","OFFER|WIRE|1","1","SHA-256","deadbeef","STORE:OFFER:WIRE","DURABLE:OFFER:WIRE")
req=.RIDSignatureRequirement~new("CUSTOMER-SIGN","CUSTOMER:W","CUSTOMER","ACCEPT_MORTGAGE_OFFER",.true)
.RIDTestSupport~ok(env~addRequirement(req)); .RIDTestSupport~ok(env~seal)
registry=.RIDWireSigningRegistry~new(fx["SERVICE"],clock,300); .RIDTestSupport~ok(registry~bindEnvelope(item~workItemId,env))
keys=.RIDSigningKeyRegistry~new
before=fx["ENV"]["NOW"]-.TimeSpan~new(0,0,0,0,60)
.RIDTestSupport~ok(keys~register(.RIDSigningKey~new("CUSTOMER-W-KEY","CUSTOMER:W","ED25519","dummy","DOCUMENT_SIGNATURE",before,.nil,"KEY:EVIDENCE")))
sigsvc=.RIDDigitalSignatureService~new(keys,.RIDAlwaysValidSignatureVerifier~new)
app=.RIDWireUITestFixtures~app(fx,registry,sigsvc)
.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))
ctx=app~workspaceContext("RID.CASES")

d=.directory~new; d["caseId"]="CASE-W"; d["requirementId"]="CUSTOMER-SIGN"; d["authenticationRef"]="AUTH:PASSKEY:1"; d["consentRef"]="CONSENT:OFFER:1"
r=app~receive(.RIDWireUITestFixtures~action(app,"signing","SIGNATURE.PREPARE",d,ctx))
.RIDTestSupport~assertTrue(r~ok)
challenge=r~value
.RIDTestSupport~assertEq("CUSTOMER:W",challenge["signer_ref"],"signer identity is server-owned")
.RIDTestSupport~assertTrue(challenge["canonical_message"]~pos("ENV-WIRE-1")>0,"challenge binds exact envelope")

/* the browser submits only the signature/key against the server-issued challenge */
d=.directory~new; d["caseId"]="CASE-W"; d["challengeId"]=challenge["challenge_id"]; d["keyId"]="CUSTOMER-W-KEY"; d["signatureHex"]="aabb"; d["evidenceRef"]="DEVICE:SIG:1"
r=app~receive(.RIDWireUITestFixtures~action(app,"signing","SIGNATURE.SUBMIT",d,app~workspaceContext("RID.CASES")))
.RIDTestSupport~assertTrue(r~ok)
.RIDTestSupport~assertEq("COMPLETE",env~state)
.RIDTestSupport~assertEq("COMPLETE",item~status)
.RIDTestSupport~assertEq("SIGNATURE_ENVELOPE:ENV-WIRE-1",item~completionEvidenceRef)

/* replay is not a second signature or completion */
r=app~receive(.RIDWireUITestFixtures~action(app,"signing","SIGNATURE.SUBMIT",d,app~workspaceContext("RID.CASES")))
.RIDTestSupport~assertTrue(\r~ok)
.RIDTestSupport~assertEq("SIGNING_CHALLENGE_ALREADY_USED",r~code)
.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS Wire UI digital signing uses one-time server-owned challenge and completes exact work"
exit 0
::requires "WireUITestSupport.cls"
