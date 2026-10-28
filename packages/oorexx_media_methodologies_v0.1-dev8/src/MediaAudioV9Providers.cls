/* Audio V9 methodology provider identities and provider-result adapters.
 *
 * API: media.methodologies.audio-v9-provider/0.1
 *
 * This layer does not implement Audio V9 DSP.  It exposes exact implementation
 * identities and converts detached provider results into Media Methodologies
 * evidence/candidate objects.  Audio V9 remains authoritative for its acoustic
 * measurements; Media Methodologies remains a planner/comparison framework.
 */

::class MediaAudioV9ProviderRegistry public
::method init
  expose providerRoot profiles
  use strict arg providerRootArg=""
  providerRoot=providerRootArg
  profiles=.Directory~new
  self~add("audio-v9.candidate18r1.multipath-features/0.1","AUDIO.MULTIPATH.PATH_ESTIMATE",.array~of("MEDIA.AUDIO.F32","MEDIA.AUDIO_V9.NATIVE"),"MEASURED_PATHS")
  self~add("audio-v9.candidate18r1.multipath-spectral-track/0.1","AUDIO.MULTIPATH.SPECTRAL_TRACK",.array~of("MEDIA.AUDIO.F32","MEDIA.AUDIO_V9.NATIVE"),"TRACK_STATE")
  self~add("audio-v9.candidate18r1.motion-coherence-state/0.1","AUDIO.MULTIPATH.MOTION_COHERENCE",.array~of("MEDIA.AUDIO_V9.NATIVE","MEDIA.MEMORY_FABRIC.CONTINUATION"),"CHECKPOINTED")
  self~add("audio-v9.candidate18r1.physics-path-policy/0.1","AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY",.array~of("MEDIA.OOREXX","MEDIA.AUDIO_V9.CLASSES"),"MEASURED_PATHS")
  self~add("audio-v9.candidate18r1.echo-reconstruct-nonamp/0.1","AUDIO.RECON.MULTIPATH_VIRTUAL_MIC",.array~of("MEDIA.AUDIO.F32","MEDIA.AUDIO_V9.NATIVE"),"RECONSTRUCTABLE")

::method add
  expose profiles
  use strict arg implementationId,methodologyId,abilities,recoveryClass="RECONSTRUCTABLE"
  tags=.array~of("REFERENCE_PROVIDER","AUDIO_V9","DERIVED_ONLY")
  profile=.MediaImplementationExecutionProfile~new(implementationId,methodologyId,"NATIVE",abilities,tags,"",128,32,1,64,16,1,0,0,.true,recoveryClass)
  profiles[translate(methodologyId)]=profile
  return self

::method profiles
  expose profiles
  answer=.Array~new
  do item over profiles~allItems
    answer~append(item)
  end
  return answer

::method profile
  expose profiles
  use strict arg methodologyIdArg
  return profiles[translate(strip(methodologyIdArg))]

::method supports
  expose profiles
  use strict arg methodologyIdArg
  return profiles~hasIndex(translate(strip(methodologyIdArg)))

::method command
  expose providerRoot profiles
  use strict arg methodologyIdArg,jobPath,resultPath,audioV9Root
  methodologyId=translate(strip(methodologyIdArg))
  if methodologyId="AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY" then raise syntax 93.900 array("Physics compatibility uses the ooRexx policy bridge, not the Python native adapter")
  if \profiles~hasIndex(methodologyId) then raise syntax 93.900 array("Unsupported Audio V9 methodology",methodologyId)
  script=providerRoot
  if script<>"" then do
    if right(script,1)<>"/" then script=script||"/"
  end
  script=script||"audio_v9_reference_provider.py"
  return "python3 "||self~shellQuote(script)||" --job "||self~shellQuote(jobPath)||" --result "||self~shellQuote(resultPath)||" --audio-v9-root "||self~shellQuote(audioV9Root)

::method shellQuote
  use strict arg value
  if pos("'",value)>0 then raise syntax 93.900 array("Provider path contains unsupported apostrophe",value)
  return "'"||value||"'"

::class MediaAudioV9ApplicabilityProvider subclass MediaMethodologyApplicabilityProvider public
::method assess
  use strict arg spec,target,context
  id=spec~id
  if pos("AUDIO.MULTIPATH.",id)<>1 then do
    if id<>"AUDIO.RECON.MULTIPATH_VIRTUAL_MIC" then return .nil
  end
  attrs=context~attributes
  source=self~flag(attrs,"SOURCE_AUDIO_AVAILABLE")
  onset=self~flag(attrs,"EVENT_ONSET_AVAILABLE")
  timerange=self~flag(attrs,"TIME_RANGE_AVAILABLE")
  paths=self~flag(attrs,"MULTIPATH_PATHS_AVAILABLE")
  trajectories=self~flag(attrs,"MULTIPATH_TRAJECTORY_OBSERVATIONS_AVAILABLE")
  spectral=self~flag(attrs,"MULTIPATH_SPECTRAL_TRAJECTORY_AVAILABLE")
  select
    when id="AUDIO.MULTIPATH.PATH_ESTIMATE" then do
      if source then do
        if onset then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio and explicit event onset are available",attrs)
      end
      if \source then return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","An explicit event onset is still required",attrs)
    end
    when id="AUDIO.MULTIPATH.SPECTRAL_TRACK" then do
      if source then do
        if timerange then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio and explicit time range are available",attrs)
      end
      if \source then return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","A time range is still required",attrs)
    end
    when id="AUDIO.MULTIPATH.MOTION_COHERENCE" then do
      if trajectories then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Measured multipath trajectory observations are available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","Measured trajectory observations are required",attrs)
    end
    when id="AUDIO.MULTIPATH.PHYSICS_COMPATIBILITY" then do
      if spectral then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Measured spectral trajectory evidence is available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","Measured spectral trajectory evidence is required",attrs)
    end
    when id="AUDIO.RECON.MULTIPATH_VIRTUAL_MIC" then do
      if source then do
        if paths then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio and measured coherent path support are available",attrs)
      end
      if \source then return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","Measured coherent path support is required before reconstruction",attrs)
    end
    otherwise return .nil
  end

::method flag
  use strict arg attrs,key
  value=attrs[translate(key)]
  if value=.nil then value=attrs[key]
  if value=.nil then return .false
  if value==.true then return .true
  text=translate(strip(value~string))
  return text="TRUE" | text="YES" | text="1" | text="AVAILABLE"

::class MediaAudioV9ProviderResultAdapter public
::method evidence
  use strict arg providerResult,timeStart=.nil,timeEnd=.nil
  if providerResult=.nil then raise syntax 93.900 array("Provider result is required")
  if translate(strip(providerResult["status"]))<>"MEASUREMENT" then return .nil
  sourceRefs=.Array~new
  if providerResult["source_evidence_ref"]<>.nil then do
    if providerResult["source_evidence_ref"]<>"" then sourceRefs~append(providerResult["source_evidence_ref"])
  end
  metadata=.Directory~new
  metadata["PROVIDER_ID"]=providerResult["provider_id"]
  metadata["IMPLEMENTATION_ID"]=providerResult["implementation_id"]
  metadata["OBSERVATION_PROMOTION"]="FALSE"
  metadata["SOURCE_AUTHORITY_UNCHANGED"]="TRUE"
  if providerResult["metrics"]<>.nil then metadata["METRICS"]=providerResult["metrics"]
  return .MediaDerivedEvidence~new(providerResult["methodology_id"],sourceRefs,providerResult["output_ref"],timeStart,timeEnd,"MEASURE",providerResult["uncertainty_ref"],metadata)

::method candidate
  use strict arg providerResult,experimentId,lineageId,workId=""
  if providerResult=.nil then raise syntax 93.900 array("Provider result is required")
  if translate(strip(providerResult["status"]))<>"CANDIDATE" then return .nil
  metadata=.Directory~new
  metadata["PROVIDER_ID"]=providerResult["provider_id"]
  metadata["IMPLEMENTATION_ID"]=providerResult["implementation_id"]
  metadata["AUTHORITY_EFFECT"]="RECONSTRUCT_CANDIDATE"
  metadata["OBSERVATION_PROMOTION"]="FALSE"
  metadata["SOURCE_AUTHORITY_UNCHANGED"]="TRUE"
  if providerResult["shared_foundation_ref"]<>.nil then metadata["SHARED_FOUNDATION_REF"]=providerResult["shared_foundation_ref"]
  workIds=.Array~new
  if workId<>"" then workIds~append(workId)
  provenance=.Array~new
  if providerResult["source_evidence_ref"]<>.nil then do
    if providerResult["source_evidence_ref"]<>"" then provenance~append(providerResult["source_evidence_ref"])
  end
  candidateId=strip(experimentId)||":"||strip(lineageId)||":"||translate(providerResult["methodology_id"])
  return .MediaExperimentCandidate~new(candidateId,experimentId,lineageId,providerResult["methodology_id"],providerResult["implementation_id"],"DERIVED_RECONSTRUCTION",workIds,providerResult["output_ref"],providerResult["support_map_ref"],providerResult["uncertainty_ref"],provenance,metadata)

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaMethodologies.cls"
::requires "MediaMethodologyIntentions.cls"
