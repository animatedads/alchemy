/* Runtime Registry entry point for Reputation Feed v0.12.
 * Runtime API/generation labels advance to v0.12 for bounded governed-decision
 * audit evidence. Existing structured interaction, Queue Fabric, assertion
 * ancestry, acquisition, authentication, Librarian, event-hypothesis,
 * corroboration and watchset factories remain available on the Alchemy v0.8 base.
 */
::class ReputationFeedRuntimeModule subclass ReputationFeedAlchemyObject public
::attribute starts get
::attribute quiesces get
::attribute stops get

::method init
  expose starts quiesces stops
  self~initDomainAlchemy("ReputationFeedRuntimeModule", .nil)
  self~registerStateVariable("starts", "INTERNAL", "Runtime start count")
  self~registerStateVariable("quiesces", "INTERNAL", "Runtime quiesce count")
  self~registerStateVariable("stops", "INTERNAL", "Runtime stop count")
  starts = 0
  quiesces = 0
  stops = 0

::method runtimeStart
  expose starts
  self~alchemyTouch("RUNTIME_START")
  starts += 1
  return .true
::method runtimeQuiesce
  expose quiesces
  self~alchemyTouch("RUNTIME_QUIESCE")
  quiesces += 1
  return .true
::method runtimeStop
  expose stops
  self~alchemyTouch("RUNTIME_STOP")
  stops += 1
  return .true
::method generationLabel
  return "REPUTATION-FEED-V0.12"
::method apiVersion
  return .ReputationFeedBuild~API_VERSION
::method packageVersion
  return .ReputationFeedBuild~VERSION
::method alchemyBaseVersion
  return self~VERSION
::method newLineageEngine
  return .ReputationLineageEngine~new
::method newLineagePolicy
  return .ReputationLineagePolicy~new
::method newCorroborationPolicy
  return .ReputationCorroborationPolicy~new
::method newPolicySet
  return .ReputationFeedPolicySet~new
::method newCorroborationEvidencePolicy
  return .ReputationCorroborationEvidencePolicy~new
::method newCorroborationEligibilityResolver
  return .ReputationCorroborationEligibilityResolver~new
::method newEventClusterEngine
  return .ReputationEventClusterEngine~new
::method newHypothesisLedger
  return .ReputationHypothesisLedger~new
::method newWatchEngine
  return .ReputationWatchEngine~new
::method newAcquisitionRouter
  return .ReputationAcquisitionRouter~new
::method newNewsPublicationAdapter
  return .ReputationNewsPublicationAdapter~new
::method newOfficialNoticeAdapter
  return .ReputationOfficialNoticeAdapter~new
::method newPublicStreamAdapter
  return .ReputationPublicStreamAdapter~new
::method newLibrarianClaimBridge
  return .ReputationLibrarianClaimBridge~new
::method newSourceAuthenticator
  return .ReputationSourceAuthenticator~new
::method newSourceHistoryLedger
  return .ReputationSourceHistoryLedger~new
::method newDecisionTrace
  return .ReputationFeedDecisionTrace~new
::requires 'ReputationDecisionAudit.cls'
::requires 'ReputationSourceAuthentication.cls'
::requires 'ReputationAcquisition.cls'
::requires 'ReputationFeed.cls'
