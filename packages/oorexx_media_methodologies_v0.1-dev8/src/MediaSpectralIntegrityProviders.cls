/* Audio Spectral Integrity methodology provider identities and adapters.
 *
 * API: media.methodologies.spectral-integrity-provider/0.1
 *
 * This layer wraps the provider-neutral Audio Spectral Integrity reference
 * implementation.  Alternating spectral views remain transforms of ONE
 * captured waveform.  They are not source separation, speaker attribution,
 * provenance inference, or historical multiplexing evidence.
 */

::class MediaSpectralIntegrityProviderRegistry public
::method init
  expose providerRoot profiles
  use strict arg providerRootArg=""
  providerRoot=providerRootArg
  profiles=.Directory~new
  self~add("audio-spectral-integrity.numpy-complementary/0.2","AUDIO.SPECTRAL_INTEGRITY.COMPLEMENTARY_BUCKET_VIEWS",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.NUMPY","MEDIA.PYTHON.SOUNDFILE"),"MEASURED_VIEW")
  self~add("audio-spectral-integrity.numpy-phase-sweep/0.2","AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.NUMPY"),"MEASURED_VIEW")
  self~add("audio-spectral-integrity.numpy-preference/0.2","AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.NUMPY","MEDIA.PYTHON.SOUNDFILE"),"RECONSTRUCTABLE")
  self~add("audio-spectral-integrity.numpy-harmonics/0.2","AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.NUMPY","MEDIA.EXTERNAL_F0"),"MEASURED_VIEW")
  self~add("audio-spectral-integrity.numpy-interleave-control/0.2","QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL",.array~of("MEDIA.AUDIO.CONTROL_SOURCES","MEDIA.PYTHON.NUMPY","MEDIA.PYTHON.SOUNDFILE"),"QUALIFICATION_ONLY")

::method add
  expose profiles
  use strict arg implementationId,methodologyId,abilities,recoveryClass
  tags=.array~of("REFERENCE_PROVIDER","SPECTRAL_INTEGRITY","DERIVED_ONLY","PLURAL_METHOD")
  profile=.MediaImplementationExecutionProfile~new(implementationId,methodologyId,"PYTHON3",abilities,tags,"",96,32,1,48,16,1,0,0,.true,recoveryClass)
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
  use strict arg methodologyIdArg,jobPath,resultPath,upstreamRoot
  methodologyId=translate(strip(methodologyIdArg))
  if \profiles~hasIndex(methodologyId) then raise syntax 93.900 array("Unsupported spectral-integrity methodology",methodologyId)
  script=providerRoot
  if script<>"" then do
    if right(script,1)<>"/" then script=script||"/"
  end
  script=script||"spectral_integrity_provider.py"
  return "python3 "||self~shellQuote(script)||" --job "||self~shellQuote(jobPath)||" --result "||self~shellQuote(resultPath)||" --upstream-root "||self~shellQuote(upstreamRoot)

::method shellQuote
  use strict arg value
  if pos("'",value)>0 then raise syntax 93.900 array("Provider path contains unsupported apostrophe",value)
  return "'"||value||"'"

::class MediaSpectralIntegrityApplicabilityProvider subclass MediaMethodologyApplicabilityProvider public
::method assess
  use strict arg spec,target,context
  id=spec~id
  if pos("AUDIO.SPECTRAL_INTEGRITY.",id)<>1 then do
    if id<>"QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL" then return .nil
  end
  attrs=context~attributes
  source=self~flag(attrs,"SOURCE_AUDIO_AVAILABLE")
  f0=self~flag(attrs,"EXTERNAL_F0_AVAILABLE")
  controlA=self~flag(attrs,"CONTROL_SOURCE_A_AVAILABLE")
  controlB=self~flag(attrs,"CONTROL_SOURCE_B_AVAILABLE")
  select
    when id="QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL" then do
      if controlA then do
        if controlB then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Two declared control sources are available",attrs)
      end
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","Known independent A and B control sources are required",attrs)
    end
    when id="AUDIO.SPECTRAL_INTEGRITY.HARMONIC_OBSERVATION" then do
      if \source then return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
      if f0 then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio and independently supplied f0 are available",attrs)
      return .MediaMethodologyApplicability~new(id,"UNKNOWN","An independently supplied f0 hypothesis is required",attrs)
    end
    otherwise do
      if source then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio is available; transform parameters remain explicit",attrs)
      return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
    end
  end

::method flag
  use strict arg attrs,key
  value=attrs[translate(key)]
  if value=.nil then value=attrs[key]
  if value=.nil then return .false
  if value==.true then return .true
  text=translate(strip(value~string))
  return text="TRUE" | text="YES" | text="1" | text="AVAILABLE"

::class MediaSpectralIntegrityProviderResultAdapter public
::method evidence
  use strict arg providerResult,timeStart=.nil,timeEnd=.nil
  if providerResult=.nil then raise syntax 93.900 array("Provider result is required")
  if translate(strip(providerResult["status"]))<>"MEASUREMENT" then return .nil
  methodologyId=translate(strip(providerResult["methodology_id"]))
  sourceRefs=self~providerSourceRefs(providerResult)
  metadata=.Directory~new
  metadata["PROVIDER_ID"]=providerResult["provider_id"]
  metadata["IMPLEMENTATION_ID"]=providerResult["implementation_id"]
  metadata["OBSERVATION_PROMOTION"]="FALSE"
  metadata["SOURCE_AUTHORITY_UNCHANGED"]="TRUE"
  metadata["SOURCE_SEPARATION_CLAIM"]="FALSE"
  if providerResult["metrics"]<>.nil then metadata["METRICS"]=providerResult["metrics"]
  authority="MEASURE"
  if methodologyId="QUAL.AUDIO.SPECTRAL_INTERLEAVE_POSITIVE_CONTROL" then authority="PRESERVE"
  return .MediaDerivedEvidence~new(methodologyId,sourceRefs,providerResult["output_ref"],timeStart,timeEnd,authority,providerResult["uncertainty_ref"],metadata)

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
  metadata["ADDS_INFORMATION"]="FALSE"
  workIds=.Array~new
  if workId<>"" then workIds~append(workId)
  provenance=self~providerSourceRefs(providerResult)
  candidateId=strip(experimentId)||":"||strip(lineageId)||":"||translate(providerResult["methodology_id"])
  return .MediaExperimentCandidate~new(candidateId,experimentId,lineageId,providerResult["methodology_id"],providerResult["implementation_id"],"DERIVED_LISTENING_VIEW",workIds,providerResult["output_ref"],providerResult["support_map_ref"],providerResult["uncertainty_ref"],provenance,metadata)

::method providerSourceRefs
  use strict arg providerResult
  refs=.Array~new
  seen=.Directory~new
  many=providerResult["source_evidence_refs"]
  if many<>.nil then do item over many
    value=strip(item~string)
    if value<>"" then do
      if \seen~hasIndex(value) then do; refs~append(value); seen[value]=.true; end
    end
  end
  one=providerResult["source_evidence_ref"]
  if one<>.nil then do
    value=strip(one~string)
    if value<>"" then do
      if \seen~hasIndex(value) then refs~append(value)
    end
  end
  return refs

::requires "MediaMethodologyExecution.cls"
::requires "MediaMethodologyExperiments.cls"
::requires "MediaMethodologyIntentions.cls"
::requires "MediaMethodologies.cls"
