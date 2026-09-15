now = .DateTime~new
start = now - .InstitutionalPolicyTime~seconds(120)
during = now + .InstitutionalPolicyTime~seconds(1)
policyId = 'REPUTATION-FEED-GLOBAL'
actor = 'FEED_PLATFORM_RELEASE'

profile = .InstitutionalPolicyAuthorityProfile~new('RF-DEPLOY-GOV','1.0',start,.nil)
ignored = profile~addGrant(.InstitutionalPolicyAuthorityGrant~new('RF-DEP-GRANT',actor,'DEPLOY',policyId,start,.nil,'REPUTATION_BOARD','AUTH:RF-DEP-GRANT')~seal)
ignored = profile~seal
deployEval = .InstitutionalPolicyDeploymentAuthorityEvaluator~new(profile)
catalog = .InstitutionalPolicyCatalog~new(.nil,.nil,.nil,.nil,.nil,.nil,deployEval)
bridge = .ReputationFeedInstitutionalPolicyBridge~new(policyId)

set = makePolicySet('TOPOLOGY',2,70)~seal
release = bridge~newRelease('1.0',set,start,.nil,'FEED_AUTHOR','REPUTATION_BOARD','')
pub = catalog~publish(release)
call assertTrue pub~ok,'publish v1'

/* Historical period before any topology binding remains legacy-global. */
historicalAt = start + .InstitutionalPolicyTime~seconds(30)
historical = bridge~operative(catalog,historicalAt)
call assertTrue historical~ok,'future topology cannot rewrite pre-binding history'
historicalOutcome = historical~value~corroborate(makeHypothesis())
call assertEqual 'LEGACY_GLOBAL',historicalOutcome~deploymentSource,'historical source remains legacy global'
call assertEqual 'ACTIVE',historicalOutcome~deploymentMode,'historical policy remains active'

scopeGlobal = .InstitutionalPolicyDeploymentScope~new('RF-GLOBAL')~seal
scopeKzWeb = .InstitutionalPolicyDeploymentScope~new('RF-KZ-WEB','REPUTATION_FEED','KZ','WEB')~seal
scopePilot = .InstitutionalPolicyDeploymentScope~new('RF-KZ-WEB-PILOT','REPUTATION_FEED','KZ','WEB','*','PILOT')~seal
call deploy catalog,release,'RF-DEP-GLOBAL',scopeGlobal,'ACTIVE',now,'ordinary reputation feed surfaces','RF-REL-100',actor,now
call deploy catalog,release,'RF-DEP-KZ-STAGED',scopeKzWeb,'STAGED',now,'stage Kazakhstan web policy route','RF-REL-101',actor,now
call deploy catalog,release,'RF-DEP-KZ-PILOT',scopePilot,'CANARY',now,'pilot exact reviewed policy','RF-REL-102',actor,now

london = .InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','GB','WEB','PUBLIC','GENERAL')
kzGeneral = .InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','KZ','WEB','PUBLIC','GENERAL')
kzPilot = .InstitutionalPolicyDeploymentPoint~new('REPUTATION_FEED','KZ','WEB','PUBLIC','PILOT')

missing = bridge~operative(catalog,during)
call assertFalse missing~ok,'topology cannot be bypassed by omitting deployment point'
call assertEqual 'DEPLOYMENT_POINT_REQUIRED',missing~code,'missing deployment point fails closed'

opLondon = bridge~operativeForContext(catalog,london,during)
call assertTrue opLondon~ok,'global active route executes for London'
outLondon = opLondon~value~corroborate(makeHypothesis())
call assertEqual 'ACTIVE',outLondon~deploymentMode,'London uses active topology binding'
call assertEqual 'TOPOLOGY',outLondon~deploymentSource,'London route is topology evidence'
call assertEqual 'RF-DEP-GLOBAL',outLondon~deploymentBindingId,'exact global binding retained'
call assertEqual london~semanticIdentity,outLondon~deploymentPointIdentity,'exact London point retained'
call assertEqual 'CORROBORATED',outLondon~domainResult~status,'deployment does not alter Feed evidence semantics'

staged = bridge~operativeForContext(catalog,kzGeneral,during)
call assertFalse staged~ok,'staged route does not execute Feed policy'
call assertEqual 'POLICY_STAGED',staged~code,'staged state exposed exactly'

opPilot = bridge~operativeForContext(catalog,kzPilot,during)
call assertTrue opPilot~ok,'pilot canary route executes reviewed policy'
outPilot = opPilot~value~corroborate(makeHypothesis())
call assertEqual 'CANARY',outPilot~deploymentMode,'pilot mode retained'
call assertEqual 'RF-DEP-KZ-PILOT',outPilot~deploymentBindingId,'more-specific canary binding retained'
call assertEqual kzPilot~semanticIdentity,outPilot~deploymentPointIdentity,'exact pilot point retained'
call assertEqual outLondon~domainResult~canonicalText,outPilot~domainResult~canonicalText,'same policy and evidence give same domain result regardless deployment route'

call assertTrue .AlchemyAdoptionVerifier~verify(opPilot~value~deploymentEvidence,'STANDARD')~ok,'deployment evidence is Alchemy house object'
say 'PASS test_institutional_policy_deployment_topology active='outLondon~deploymentBindingId 'staged='staged~code 'pilot='outPilot~deploymentBindingId
exit 0

makePolicySet: procedure
  use arg id,minFamilies,minConfidence
  return .ReputationFeedPolicySet~new(id, -
    .ReputationLineagePolicy~new(78,2), -
    .ReputationCorroborationPolicy~new(minFamilies,minConfidence,1,180,.true), -
    .ReputationCorroborationEvidencePolicy~new(.true,.true,.false,.false), -
    .ReputationGeographicSaliencePolicy~new(2,5,3,10))

makeHypothesis: procedure
  h = .ReputationEventHypothesis~new('H-TOPOLOGY','AIRCRAFT_SAFETY_INCIDENT')
  h~addClaim(makeClaim('A','ASSERTION:A',92))
  h~addClaim(makeClaim('B','ASSERTION:B',84))
  return h~seal

makeClaim: procedure
  use arg id,root,confidence
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','Topology policy claim',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-TOPOLOGY')
  c~addSubject('MANUFACTURER','BOEING')
  c~addConcept('CABIN_OPENING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'topology test root')
  c~setSourceAuthentication('VERIFIED','AUTH-'id,.false,'HIST-'id)
  return c~seal

deploy: procedure
  use arg catalog,policy,id,scope,mode,effectiveFrom,reason,evidence,actor,requestedAt
  req = .InstitutionalPolicyDeploymentRequest~new(id,policy,actor,scope,mode,effectiveFrom,.nil,reason,evidence,requestedAt)
  applied = catalog~applyDeployment(policy~policyId,policy~version,req)
  if applied~ok = .false then do; say 'FAIL: deployment' id applied~code applied~detail; exit 1; end
  return

assertTrue: procedure
  use arg value,label
  if value \== .true then do; say 'FAIL:' label; exit 1; end
  return
assertFalse: procedure
  use arg value,label
  if value == .true then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'AlchemyAdoption.cls'
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
