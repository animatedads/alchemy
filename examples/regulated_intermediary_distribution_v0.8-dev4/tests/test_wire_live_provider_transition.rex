fx=.RIDWireUITestFixtures~setup("APPROVED")
app=.RIDWireUITestFixtures~app(fx)
.RIDTestSupport~ok(.RIDWireUITestFixtures~selectCase(app,"CASE-W"))
.RIDTestSupport~assertEq("APPROVED",app~view~instance("CASE-W")["slots"]["providerStatus"])

/* Later provider truth must replace the displayed state, not create a message-only notification. */
p=fx["PRODUCT"]; env=fx["ENV"]
e=.RIDProviderStatusEvidence~new("WIRE-STATUS-2",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:CASE:W",p~productSemanticIdentity,2,"DECLINED",env["NOW"],"PROVIDER:WIRE-STATUS-2")
signed=.RIDSignedProviderStatusEvent~new(e,fx["SIGNER"],"PROVIDER-WORK-KEY","test-signature",env["NOW"],"CHANNEL:WIRE-STATUS-2")
.RIDTestSupport~ok(fx["BRIDGE"]~enqueueProviderStatus("CASE-W",signed)); .RIDTestSupport~ok(fx["BRIDGE"]~canonicalizeOne); .RIDTestSupport~ok(fx["BRIDGE"]~projectOne); .RIDTestSupport~ok(fx["SERVICE"]~processStatusOne)
r=app~receive(.RIDWireUITestFixtures~action(app,"case-query","DASHBOARD.REFRESH",.directory~new))
.RIDTestSupport~assertTrue(r~ok)
row=app~view~instance("CASE-W")
.RIDTestSupport~assertEq("DECLINED",row["slots"]["providerStatus"])
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_DECLINE",row["slots"]["nextAction"])
.RIDTestSupport~assertEq("DECLINED",app~view~instance("case-detail")["slots"]["providerStatus"],"open detail follows same authoritative event")
.RIDTestSupport~assertEq("REVIEW_MORTGAGE_DECLINE",app~view~instance("case-detail")["slots"]["nextAction"])

/* Firm-scoped subscription does not ingest another firm's retained publication. */
foreign=.directory~new; foreign["schema"]="regulated.intermediary.case-attention/1"; foreign["case_id"]="CASE-FOREIGN"; foreign["firm_id"]="FIRM-OTHER"; foreign["representative_id"]="REP-X"; foreign["product_family"]="MORTGAGE"; foreign["workflow_state"]="OPEN"; foreign["provider_status"]="APPROVED"; foreign["provider_sequence"]="1"; foreign["provider_event_id"]="FOREIGN-1"; foreign["work_item_id"]=""; foreign["next_action"]="NONE"; foreign["priority"]="0"; foreign["overdue"]="0"; foreign["due_tick"]="0"; foreign["attention_state"]="WAITING_PROVIDER"; foreign["waiting_on"]="PROVIDER"
o=.table~new; o["subtopic"]="FIRM-OTHER/CASE-FOREIGN"; o["persistent"]=.true; o["retain"]=.true; o["publicationId"]="FOREIGN-ATTENTION-1"
.RIDTestSupport~ok(fx["BRIDGE"]~topicFabric~publish("RID.CASE.ATTENTION",foreign,o,"RID_ADMIN")); .RIDTestSupport~ok(fx["FEED"]~pump)
.RIDTestSupport~assertTrue(fx["FEED"]~attention("CASE-FOREIGN")==.nil,"firm-scoped topic subscription prevents cross-firm projection")

.RIDWorkIntegrationFixtures~cleanup(fx)
say "PASS live Wire UI follows authoritative approval/decline events and firm-scoped retained feed"
exit 0
::requires "WireUITestSupport.cls"
