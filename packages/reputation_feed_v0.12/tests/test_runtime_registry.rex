parse arg root
if root = '' then root = directory()
verifier=.RuntimePinnedSourceVerifier~new
kernel=.RuntimeKernel~new(verifier)
sourcePath=root||'/runtime/ReputationFeedRuntimeModule.cls'
load=.RuntimeSourceLoader~readFile(sourcePath)
call assertTrue load~ok,'runtime source loads'
artifactId='reputation:feed:v0.12'
verifier~pin(artifactId,load~value)
artifact=.RuntimeArtifact~new('reputation.feed','REPUTATION_FEED','0.12',artifactId,'ReputationFeedRuntimeModule',load~value,.ReputationFeedBuild~API_VERSION,sourcePath)
staged=kernel~stage('prod',artifact); call assertTrue staged~ok,'feed runtime stages'
activated=kernel~activate('prod','reputation.feed',staged~value~generationId); call assertTrue activated~ok,'feed runtime activates'
acquired=kernel~acquire('prod','reputation.feed'); call assertTrue acquired~ok,'feed runtime acquires'
lease=acquired~value; module=lease~module
call assertEqual 'REPUTATION-FEED-V0.12',module~generationLabel,'generation label'
call assertEqual 'reputation.feed/0.12',module~apiVersion,'api version'
call assertEqual '0.12',module~packageVersion,'package version'
call assertEqual '0.8',module~alchemyBaseVersion,'Alchemy base version'
call assertTrue module~isA(.AlchemyObject),'runtime module inherits AlchemyObject'
call assertTrue module~newLineageEngine~class == .ReputationLineageEngine,'lineage engine factory'
call assertTrue module~newEventClusterEngine~class == .ReputationEventClusterEngine,'event cluster engine factory'
call assertTrue module~newCorroborationPolicy~class == .ReputationCorroborationPolicy,'corroboration policy factory'
call assertTrue module~newPolicySet~class == .ReputationFeedPolicySet,'policy set factory'
call assertTrue module~newCorroborationEvidencePolicy~class == .ReputationCorroborationEvidencePolicy,'corroboration evidence policy factory'
call assertTrue module~newCorroborationEligibilityResolver~class == .ReputationCorroborationEligibilityResolver,'corroboration eligibility resolver factory' 
call assertTrue module~newHypothesisLedger~class == .ReputationHypothesisLedger,'hypothesis ledger factory'
call assertTrue module~newWatchEngine~class == .ReputationWatchEngine,'watch engine factory'
call assertTrue module~newAcquisitionRouter~class == .ReputationAcquisitionRouter,'acquisition router factory'
call assertTrue module~newNewsPublicationAdapter~class == .ReputationNewsPublicationAdapter,'news adapter factory'
call assertTrue module~newOfficialNoticeAdapter~class == .ReputationOfficialNoticeAdapter,'official adapter factory'
call assertTrue module~newPublicStreamAdapter~class == .ReputationPublicStreamAdapter,'public stream adapter factory'
call assertTrue module~newLibrarianClaimBridge~class == .ReputationLibrarianClaimBridge,'Librarian claim bridge factory'
call assertTrue module~newSourceAuthenticator~class == .ReputationSourceAuthenticator,'source authenticator factory'
call assertTrue module~newSourceHistoryLedger~class == .ReputationSourceHistoryLedger,'source history ledger factory'
call assertTrue module~newDecisionTrace~class == .ReputationFeedDecisionTrace,'decision trace factory'
call assertTrue lease~release~ok,'release'
say 'PASS test_runtime_registry'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationDecisionAudit.cls'
::requires 'ReputationAcquisition.cls'
::requires 'ReputationFeed.cls'
::requires 'RuntimeRegistry.cls'
