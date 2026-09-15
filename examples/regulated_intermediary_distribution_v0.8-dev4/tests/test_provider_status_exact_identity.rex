env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-S","CUSTOMER:S","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
p=env["PRODUCT"]
bad=.RIDProviderStatusEvidence~new("S-1",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:1","DIFFERENT-PRODUCT",1,"RECEIVED",env["NOW"],"STATUS:1")
.RIDTestSupport~failCode("PROVIDER_PRODUCT_IDENTITY_MISMATCH",engine~recordProviderStatus(c~caseId,bad))
good=.RIDProviderStatusEvidence~new("S-2",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:1",p~productSemanticIdentity,1,"RECEIVED",env["NOW"],"STATUS:2")
.RIDTestSupport~ok(engine~recordProviderStatus(c~caseId,good))
/* Redelivery of the exact same provider event is an idempotent success. */
dup=engine~recordProviderStatus(c~caseId,good)
.RIDTestSupport~assertTrue(dup~ok,"exact duplicate provider event should be idempotent")
.RIDTestSupport~assertEq("PROVIDER_EVENT_DUPLICATE",dup~detail)
/* Re-use of a provider sequence for a different event is evidence conflict. */
conflict=.RIDProviderStatusEvidence~new("S-3",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:1",p~productSemanticIdentity,1,"UNDER_REVIEW",env["NOW"],"STATUS:3")
.RIDTestSupport~failCode("PROVIDER_SEQUENCE_CONFLICT",engine~recordProviderStatus(c~caseId,conflict))
/* Re-use of an event id with altered signed content is also rejected. */
idConflict=.RIDProviderStatusEvidence~new("S-2",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"PROVIDER:1",p~productSemanticIdentity,2,"UNDER_REVIEW",env["NOW"],"STATUS:4")
.RIDTestSupport~failCode("PROVIDER_EVENT_ID_CONFLICT",engine~recordProviderStatus(c~caseId,idConflict))
say "PASS provider status exact identity, idempotence and sequencing"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"
