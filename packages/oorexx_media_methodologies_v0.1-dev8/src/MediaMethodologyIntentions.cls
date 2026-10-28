/* Dynamic intention surface for the methodology catalogue.
 *
 * API: media.methodologies.intentions/0.1
 *
 * Like Vision and Layered Audio intention surfaces, discovery is live.  The
 * target remains the exact caller-owned media/evidence object and providers are
 * asked again on every discovery.  This file does not require IntentionService.
 */

::class MediaMethodologyApplicability public
::method init
  expose methodologyId state reason evidence
  use strict arg methodologyIdArg, stateArg="UNKNOWN", reasonArg="", evidenceArg=.nil
  methodologyId=translate(strip(methodologyIdArg))
  state=translate(strip(stateArg))
  reason=strip(reasonArg)
  evidence=evidenceArg
  if methodologyId="" then raise syntax 93.900 array("Methodology id must not be empty")
  if state<>"APPLICABLE" then do
    if state<>"NOT_APPLICABLE" then do
      if state<>"UNKNOWN" then raise syntax 93.900 array("Unknown applicability state",state)
    end
  end
::attribute methodologyId get
::attribute state get
::attribute reason get
::attribute evidence get

::class MediaMethodologyApplicabilityProvider public
::method assess abstract

::class MediaMethodologyIntentionContext public
::method init
  expose domain family policy evidence implementationProfiles attributes
  use strict arg domainArg="", familyArg="", policyArg=.nil, evidenceArg=.nil, implementationProfilesArg=.nil, attributesArg=.nil
  domain=translate(strip(domainArg))
  family=translate(strip(familyArg))
  if policyArg=.nil then policyArg=.MediaMethodologyPolicy~new
  policy=policyArg
  evidence=.Array~new
  if evidenceArg<>.nil then do item over evidenceArg
    evidence~append(item)
  end
  implementationProfiles=.Array~new
  if implementationProfilesArg<>.nil then do profile over implementationProfilesArg
    implementationProfiles~append(profile)
  end
  if attributesArg=.nil then attributesArg=.Directory~new
  attributes=attributesArg
::attribute domain get
::attribute family get
::attribute policy get
::method evidence
  expose evidence
  return evidence~copy
::method implementationProfiles
  expose implementationProfiles
  return implementationProfiles~copy
::method attributes
  expose attributes
  return attributes
::method implementationsFor
  expose implementationProfiles
  use strict arg methodologyIdArg
  wanted=translate(strip(methodologyIdArg))
  answer=.Array~new
  do profile over implementationProfiles
    if profile~methodologyId=wanted then answer~append(profile)
  end
  return answer

::class MediaMethodologyIntentionCandidate public
::method init
  expose spec applicability implementations
  use strict arg specArg, applicabilityArg, implementationsArg=.nil
  if \specArg~isA(.MediaMethodologySpec) then raise syntax 93.900 array("MediaMethodologySpec required")
  if \applicabilityArg~isA(.MediaMethodologyApplicability) then raise syntax 93.900 array("MediaMethodologyApplicability required")
  spec=specArg
  applicability=applicabilityArg
  implementations=.Array~new
  if implementationsArg<>.nil then do implementation over implementationsArg
    implementations~append(implementation)
  end
::attribute spec get
::attribute applicability get
::method implementations
  expose implementations
  return implementations~copy
::method state
  expose applicability
  return applicability~state
::method methodologyId
  expose spec
  return spec~id

::class MediaMethodologyIntentionDiscovery public
::method init
  expose generation revision target candidates context
  use strict arg generationArg, revisionArg, targetArg, candidatesArg, contextArg
  generation=generationArg
  revision=revisionArg~string
  target=targetArg
  candidates=.Array~new
  if candidatesArg<>.nil then do candidate over candidatesArg
    candidates~append(candidate)
  end
  context=contextArg
::attribute generation get
::attribute revision get
::attribute target get
::attribute context get
::method candidates
  expose candidates
  return candidates~copy
::method applicable
  expose candidates
  answer=.Array~new
  do candidate over candidates
    if candidate~state="APPLICABLE" then answer~append(candidate)
  end
  return answer
::method unresolved
  expose candidates
  answer=.Array~new
  do candidate over candidates
    if candidate~state="UNKNOWN" then answer~append(candidate)
  end
  return answer

::class MediaMethodologyIntentionProposal public
::method init
  expose discovery state goal selected reason plan
  use strict arg discoveryArg, stateArg, goalArg="", selectedArg=.nil, reasonArg="", planArg=.nil
  discovery=discoveryArg
  state=translate(strip(stateArg))
  goal=strip(goalArg)
  selected=selectedArg
  reason=strip(reasonArg)
  plan=planArg
::attribute discovery get
::attribute state get
::attribute goal get
::attribute selected get
::attribute reason get
::attribute plan get

::class MediaMethodologyIntentionProvider public
::method init
  expose catalogue applicabilityProviders generation
  use strict arg catalogueArg
  if \catalogueArg~isA(.MediaMethodologyCatalogue) then raise syntax 93.900 array("MediaMethodologyCatalogue required")
  catalogue=catalogueArg
  applicabilityProviders=.Array~new
  generation=0
::method registerApplicabilityProvider
  expose applicabilityProviders
  use strict arg provider
  if provider=.nil then raise syntax 93.900 array("Applicability provider is required")
  applicabilityProviders~append(provider)
  return self
::method surface
  use strict arg target, context=.nil
  return .MediaMethodologyIntentionSurface~new(target,self,context)
::method discover
  expose catalogue applicabilityProviders generation
  use strict arg target, context=.nil
  if target=.nil then raise syntax 93.900 array("Methodology intention target is mandatory")
  if context=.nil then context=.MediaMethodologyIntentionContext~new
  if \context~isA(.MediaMethodologyIntentionContext) then raise syntax 93.900 array("MediaMethodologyIntentionContext required")
  generation+=1
  catalogue~refreshProviders
  specs=catalogue~candidates(context~domain,context~family,context~policy)
  candidates=.Array~new
  revision=""
  do spec over specs
    assessment=self~assess(spec,target,context,applicabilityProviders)
    implementations=context~implementationsFor(spec~id)
    candidate=.MediaMethodologyIntentionCandidate~new(spec,assessment,implementations)
    candidates~append(candidate)
    revision=revision||spec~id||":"||assessment~state||":"||implementations~items||";"
  end
  return .MediaMethodologyIntentionDiscovery~new(generation,revision,target,candidates,context)

::method assess
  use strict arg spec, target, context, providers
  sawApplicable=.false
  sawNotApplicable=.false
  evidence=.Array~new
  reasons=.Array~new
  do provider over providers
    assessment=provider~assess(spec,target,context)
    if assessment=.nil then iterate
    evidence~append(assessment~evidence)
    if assessment~reason<>"" then reasons~append(assessment~reason)
    if assessment~state="APPLICABLE" then sawApplicable=.true
    if assessment~state="NOT_APPLICABLE" then sawNotApplicable=.true
  end
  state="UNKNOWN"
  if sawApplicable then state="APPLICABLE"
  if sawNotApplicable then do
    if \sawApplicable then state="NOT_APPLICABLE"
  end
  reason="No applicability provider made a determination"
  if reasons~items>0 then reason=reasons[1]
  return .MediaMethodologyApplicability~new(spec~id,state,reason,evidence)

/* Select by explicit methodology identity.  Discovery is re-run by the caller
 * before dispatch; this proposal object never confers execution authority. */
::method proposeMethodology
  use strict arg discovery, methodologyIdArg
  wanted=translate(strip(methodologyIdArg))
  do candidate over discovery~candidates
    if candidate~methodologyId=wanted then do
      if candidate~state="NOT_APPLICABLE" then return .MediaMethodologyIntentionProposal~new(discovery,"CLARIFY",wanted,candidate,"Current evidence marks this methodology not applicable")
      if candidate~state="UNKNOWN" then return .MediaMethodologyIntentionProposal~new(discovery,"CLARIFY",wanted,candidate,"Applicability is not yet established")
      return .MediaMethodologyIntentionProposal~new(discovery,"READY",wanted,candidate,"Methodology is applicable to current evidence")
    end
  end
  return .MediaMethodologyIntentionProposal~new(discovery,"CLARIFY",wanted,.nil,"Methodology is not present in current discovery")

/* Build a plural experiment definition rather than selecting one winner. */
::method proposeExperiment
  use strict arg discovery, experimentId, goal, methodologyIds, sourceRefs=.nil
  definition=.MediaExperimentDefinition~new(experimentId,goal,sourceRefs)
  unresolved=.Array~new
  do methodologyId over methodologyIds
    proposal=self~proposeMethodology(discovery,methodologyId)
    if proposal~state<>"READY" then do
      unresolved~append(methodologyId)
      iterate
    end
    candidate=proposal~selected
    implementations=candidate~implementations
    if implementations~items=0 then do
      unresolved~append(methodologyId)
      iterate
    end
    profile=implementations[1]
    definition~addMethod(.MediaExperimentMethodSelection~new(candidate~methodologyId,profile))
  end
  if unresolved~items>0 then return .MediaMethodologyIntentionProposal~new(discovery,"CLARIFY",goal,unresolved,"One or more methodologies lack current applicability or an execution implementation")
  return .MediaMethodologyIntentionProposal~new(discovery,"READY",goal,definition,"Plural experiment definition built without choosing a methodological winner",definition)

::class MediaMethodologyIntentionSurface public
::method init
  expose target provider context
  use strict arg targetArg, providerArg, contextArg=.nil
  if targetArg=.nil then raise syntax 93.900 array("Methodology intention surface target is mandatory")
  if providerArg=.nil then raise syntax 93.900 array("Methodology intention provider is mandatory")
  target=targetArg
  provider=providerArg
  context=contextArg
::attribute target get
::attribute provider get
::attribute context get
::method discover
  expose target provider context
  return provider~discover(target,context)

::requires "MediaMethodologies.cls"
::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
