stateRoot="/tmp/rid_queue_status_" || .DateTime~new~microseconds
manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new,"RID_ADMIN")

env=.RIDTestFixtures~environment("INSURANCE","ADVISED","ALL_JAPAN_INSURANCE_CO_LTD","ALL_JAPAN_POLICY_ADMIN","HOME-COVER","2026.08","AJI-HOME|2026.08|SEM")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-Q","CUSTOMER:Q","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
p=env["PRODUCT"]

keys=.RIDSigningKeyRegistry~new
before=env["NOW"]-.TimeSpan~new(0,0,0,0,60)
signer=p~providerIdentity~authorityKey
.RIDTestSupport~ok(keys~register(.RIDSigningKey~new("AJI-QUEUE-KEY",signer,"ED25519","test-public-key","PROVIDER_EVENT",before,.nil,"TEST:KEY")))
signatures=.RIDDigitalSignatureService~new(keys,.RIDAlwaysValidSignatureVerifier~new)
bridge=.RIDQueueEventBridge~new(manager,engine,signatures,"RID_ADMIN")
.RIDTestSupport~ok(bridge~configure)

approved=.RIDProviderStatusEvidence~new("AJI-Q-10",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"AJI:CASE:Q",p~productSemanticIdentity,10,"APPROVED",env["NOW"],"AJI:Q:10")
signedApproved=.RIDSignedProviderStatusEvent~new(approved,signer,"AJI-QUEUE-KEY","test-signature",env["NOW"],"AJI:CHANNEL:1")
.RIDTestSupport~ok(bridge~enqueueProviderStatus(c~caseId,signedApproved))
.RIDTestSupport~ok(bridge~canonicalizeOne)
.RIDTestSupport~ok(bridge~projectOne)
.RIDTestSupport~assertEq("APPROVED",c~providerStatus,"event itself must project approval into case status")

rejected=.RIDProviderStatusEvidence~new("AJI-Q-11",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"AJI:CASE:Q",p~productSemanticIdentity,11,"DECLINED",env["NOW"],"AJI:Q:11")
signedRejected=.RIDSignedProviderStatusEvent~new(rejected,signer,"AJI-QUEUE-KEY","test-signature",env["NOW"],"AJI:CHANNEL:2")
.RIDTestSupport~ok(bridge~enqueueProviderStatus(c~caseId,signedRejected))
.RIDTestSupport~ok(bridge~canonicalizeOne)
.RIDTestSupport~ok(bridge~projectOne)
.RIDTestSupport~assertEq("DECLINED",c~providerStatus,"newer rejection must replace prior approval")
.RIDTestSupport~assertEq(11,c~providerSequence)

/* A late lower-sequence event is consumed/audited but cannot roll UI state back. */
late=.RIDProviderStatusEvidence~new("AJI-Q-09",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"AJI:CASE:Q",p~productSemanticIdentity,9,"UNDERWRITING",env["NOW"],"AJI:Q:09")
signedLate=.RIDSignedProviderStatusEvent~new(late,signer,"AJI-QUEUE-KEY","test-signature",env["NOW"],"AJI:CHANNEL:3")
.RIDTestSupport~ok(bridge~enqueueProviderStatus(c~caseId,signedLate))
.RIDTestSupport~ok(bridge~canonicalizeOne)
lateResult=bridge~projectOne
.RIDTestSupport~assertTrue(lateResult~ok)
.RIDTestSupport~assertEq("STALE_IGNORED",lateResult~detail)
.RIDTestSupport~assertEq("DECLINED",c~providerStatus)

/* Exact redelivery is idempotent and does not create a second live UI update. */
.RIDTestSupport~ok(bridge~enqueueProviderStatus(c~caseId,signedRejected))
.RIDTestSupport~ok(bridge~canonicalizeOne)
dupResult=bridge~projectOne
.RIDTestSupport~assertTrue(dupResult~ok)
.RIDTestSupport~assertEq("DUPLICATE_IGNORED",dupResult~detail)
wireDepth=manager~depth(bridge~wireStatusQueue,"RID_ADMIN")~value
.RIDTestSupport~assertEq(2,wireDepth["ready"],"only material status changes should reach live Wire status queue")

first=manager~get(bridge~wireStatusQueue,"RID_ADMIN")~value~payload
second=manager~get(bridge~wireStatusQueue,"RID_ADMIN")~value~payload
.RIDTestSupport~assertEq("APPROVED",first["provider_status"])
.RIDTestSupport~assertEq("DECLINED",second["provider_status"])
retained=bridge~topicFabric~retainedPublications
.RIDTestSupport~assertEq(1,retained~items,"retained topic should hold one latest case status")
.RIDTestSupport~assertEq("DECLINED",retained[1]~payload["provider_status"],"late subscribers receive actual latest state")

/* Durable queue/topic state survives manager restart.  Queue Fabric's optional
   authenticated record protector is orthogonal to the signed business event. */
manager2=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new,"RID_ADMIN")
bridge2=.RIDQueueEventBridge~new(manager2,engine,signatures,"RID_ADMIN")
.RIDTestSupport~ok(bridge2~configure)
retained2=bridge2~topicFabric~retainedPublications
.RIDTestSupport~assertEq(1,retained2~items)
.RIDTestSupport~assertEq("DECLINED",retained2[1]~payload["provider_status"])
.RIDTestSupport~assertTrue(manager2~durableStore \== .nil,"durable store must recover")
address system "rm -rf " || stateRoot
say "PASS Queue Fabric authoritative provider-status projection"
exit 0

::class RIDAlwaysValidSignatureVerifier public
::method verify
  return .true

::requires "RegulatedIntermediaryDistribution.cls"
::requires "RIDDigitalSigning.cls"
::requires "RIDQueueEventBridge.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"
