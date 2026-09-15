fx=.RIDWireUITestFixtures~setup("APPROVED")
app=.RIDWireUITestFixtures~app(fx)
.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))

/* Add later signed provider truth and drive the work projection. */
p=fx["PRODUCT"]; env=fx["ENV"]
e=.RIDProviderStatusEvidence~new("WIRE-TL-2",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:CASE:W",p~productSemanticIdentity,2,"DECLINED",env["NOW"],"PROVIDER:TIMELINE:DECLINE")
signed=.RIDSignedProviderStatusEvent~new(e,fx["SIGNER"],"PROVIDER-WORK-KEY","test-signature",env["NOW"],"CHANNEL:WIRE-TL-2")
.RIDTestSupport~ok(fx["BRIDGE"]~enqueueProviderStatus("CASE-W",signed)); .RIDTestSupport~ok(fx["BRIDGE"]~canonicalizeOne); .RIDTestSupport~ok(fx["BRIDGE"]~projectOne); .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
.RIDTestSupport~ok(app~receive(.RIDWireUITestFixtures~action(app,"case-query","DASHBOARD.REFRESH",.directory~new)))

t=app~view~instance("case-timeline")
.RIDTestSupport~assertTrue(t<>.nil,"case timeline exists")
.RIDTestSupport~assertTrue(t["slots"]["windowTotalCount"]>=4,"timeline contains case/provider/work history")
seenApproved=.false; seenDeclined=.false; seenDeclineSource=.false
 do id over t["children"]
  row=app~view~instance(id)
  if row["slots"]["kind"]="PROVIDER" then do
    if row["slots"]["status"]="APPROVED" then seenApproved=.true
    if row["slots"]["status"]="DECLINED" then do
      seenDeclined=.true
      if row["slots"]["sourceRef"]="PROVIDER:TIMELINE:DECLINE" then seenDeclineSource=.true
    end
  end
 end
.RIDTestSupport~assertTrue(seenApproved,"timeline preserves earlier provider approval")
.RIDTestSupport~assertTrue(seenDeclined,"timeline carries later provider decline")
.RIDTestSupport~assertTrue(seenDeclineSource,"timeline carries exact provider evidence source")
.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS case timeline preserves exact provider history and work progress"
exit 0
::requires "WireUITestSupport.cls"
