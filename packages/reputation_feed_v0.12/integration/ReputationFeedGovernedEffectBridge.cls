/* Reputation Feed v0.12 governed Feed -> Reputation Effect promotion.
 *
 * An operative Institutional Policy execution may supply the exact Feed policy
 * bundle used to decide corroboration. Counterfactual execution is evidence for
 * comparison/replay only and is never promoted as operational observation input.
 */

::class ReputationFeedGovernedEffectPromotion subclass ReputationFeedAlchemyObject public
::attribute allowed get
::attribute reasonCode get
::attribute governedOutcome get

::method init
  expose allowed reasonCode governedOutcome observations
  use arg allowedArg, reasonArg, governedOutcomeArg, observationsArg = .nil, alchemyContextArg = .nil
  self~initDomainAlchemy("ReputationFeedGovernedEffectPromotion", alchemyContextArg)
  allowed = allowedArg
  reasonCode = reasonArg~string~upper~strip
  governedOutcome = governedOutcomeArg
  if observationsArg == .nil then observations = .array~new
  else observations = .ReputationFeedCanonical~copyArray(observationsArg)
  self~registerStateVariable("allowed", "PUBLIC", "Whether governed Feed evidence was promotable")
  self~registerStateVariable("reasonCode", "PUBLIC", "Promotion boundary reason")

::method observations
  expose observations
  return .ReputationFeedCanonical~copyArray(observations)

::method observationCount
  expose observations
  return observations~items

::method canonicalText
  expose allowed reasonCode governedOutcome observations
  ids = .array~new
  do observation over observations; ids~append(observation~observationId); end
  ids~sort
  text = "REPUTATION-FEED-GOVERNED-EFFECT-PROMOTION/1" || '0a'x
  text ||= .ReputationFeedCanonical~field("ALLOWED", allowed)
  text ||= .ReputationFeedCanonical~field("REASON", reasonCode)
  if governedOutcome <> .nil then text ||= .ReputationFeedCanonical~field("GOVERNED_OUTCOME", governedOutcome~canonicalText)
  text ||= .ReputationFeedCanonical~join("OBSERVATION", ids)
  return text


::class ReputationFeedGovernedEffectBridge subclass ReputationFeedAlchemyObject public

::method promote
  use arg observationPrefix, eventId, hypothesis, policyExecution
  self~alchemyTouch("GOVERNED_EFFECT_PROMOTION")
  if policyExecution == .nil then raise syntax 88.900 array("Governed Effect promotion requires ReputationFeedPolicyExecution")
  if \policyExecution~hasMethod("EXECUTIONCONTEXT") | \policyExecution~hasMethod("POLICYSET") then raise syntax 88.900 array("Governed Effect promotion requires ReputationFeedPolicyExecution")
  outcome = policyExecution~corroborate(hypothesis)
  if outcome~evaluationMode <> "OPERATIVE" then return .ReputationFeedGovernedEffectPromotion~new(.false, "COUNTERFACTUAL_NOT_PROMOTABLE", outcome, .array~new, self~domainAlchemyContext)
  if outcome~domainResult~status <> "CORROBORATED" then return .ReputationFeedGovernedEffectPromotion~new(.false, "HYPOTHESIS_NOT_CORROBORATED", outcome, .array~new, self~domainAlchemyContext)
  metadata = .table~new
  metadata["feed_policy_ref"] = outcome~policyId || "@" || outcome~policyVersion
  metadata["feed_policy_identity"] = outcome~policyIdentity
  metadata["feed_policy_set_identity"] = outcome~policySetIdentity
  metadata["feed_policy_evaluation_mode"] = outcome~evaluationMode
  metadata["feed_policy_assurance"] = outcome~assuranceMode
  metadata["feed_policy_deployment_identity"] = outcome~deploymentIdentity
  metadata["feed_policy_deployment_point"] = outcome~deploymentPointIdentity
  metadata["feed_policy_deployment_mode"] = outcome~deploymentMode
  metadata["feed_policy_deployment_source"] = outcome~deploymentSource
  metadata["feed_policy_deployment_binding"] = outcome~deploymentBindingIdentity
  metadata["feed_policy_deployment_binding_id"] = outcome~deploymentBindingId
  metadata["feed_policy_progressive_rollout"] = outcome~progressiveRolloutIdentity
  metadata["feed_policy_progressive_rollout_id"] = outcome~progressiveRolloutId
  set = policyExecution~policySet
  bridge = .ReputationFeedEffectBridge~new(self~domainAlchemyContext)
  observations = bridge~observationsFromHypothesis(observationPrefix, eventId, hypothesis, set~corroborationPolicy, .true, set~evidencePolicy, metadata)
  return .ReputationFeedGovernedEffectPromotion~new(.true, "OPERATIVE_POLICY_CORROBORATED", outcome, observations, self~domainAlchemyContext)

::requires 'ReputationFeedEffectBridge.cls'
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'
