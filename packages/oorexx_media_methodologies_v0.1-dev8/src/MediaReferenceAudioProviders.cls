/* Reference plural audio reconstruction provider registry.
 * API: media.methodologies.reference-audio-provider/0.1
 *
 * These profiles expose implementations; they do not make one algorithm the
 * preferred methodology and they cannot promote reconstructed audio to source
 * observation authority.
 */
::class MediaReferenceAudioProviderRegistry public
::method init
  expose providerRoot profiles
  use strict arg providerRootArg=""
  providerRoot=providerRootArg
  profiles=.Directory~new
  self~add("reference.scipy.spectral-subtraction/0.1","AUDIO.DENOISE.SPECTRAL_SUBTRACTION",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.SCIPY"))
  self~add("reference.scipy.wiener-stft/0.1","AUDIO.DENOISE.WIENER",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.SCIPY"))
  self~add("reference.sklearn.nmf-denoise/0.1","AUDIO.DENOISE.NMF",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.SKLEARN"))
  self~add("reference.scipy.hpss-median/0.1","AUDIO.HARMONIC_PERCUSSIVE",.array~of("MEDIA.AUDIO.PCM","MEDIA.PYTHON.SCIPY"))
  self~add("reference.scipy.spectral-repair/0.1","AUDIO.SPECTRAL.REPAIR",.array~of("MEDIA.AUDIO.PCM","MEDIA.AUDIO.DAMAGE_MASK","MEDIA.PYTHON.SCIPY"))

::method add
  expose profiles
  use strict arg implementationId, methodologyId, abilities
  tags=.array~of("REFERENCE_PROVIDER","DERIVED_CANDIDATE_ONLY","PLURAL_METHOD")
  profile=.MediaImplementationExecutionProfile~new(implementationId,methodologyId,"PYTHON3",abilities,tags,"",128,32,1,64,16,1,0,0,.true,"RECONSTRUCTABLE")
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
  use strict arg methodologyIdArg, jobPath, resultPath
  methodologyId=translate(strip(methodologyIdArg))
  if \profiles~hasIndex(methodologyId) then raise syntax 93.900 array("Unsupported reference audio methodology",methodologyId)
  script=providerRoot
  if script<>"" then do
    if right(script,1)<>"/" then script=script||"/"
  end
  script=script||"reference_audio_reconstruction.py"
  return "python3 "||self~shellQuote(script)||" --job "||self~shellQuote(jobPath)||" --result "||self~shellQuote(resultPath)

::method shellQuote
  use strict arg value
  if pos("'",value)>0 then raise syntax 93.900 array("Provider path contains unsupported apostrophe",value)
  return "'"||value||"'"

::class MediaReferenceAudioApplicabilityProvider subclass MediaMethodologyApplicabilityProvider public
::method assess
  use strict arg spec,target,context
  id=spec~id
  if id<>"AUDIO.DENOISE.SPECTRAL_SUBTRACTION" then do
    if id<>"AUDIO.DENOISE.WIENER" then do
      if id<>"AUDIO.DENOISE.NMF" then do
        if id<>"AUDIO.HARMONIC_PERCUSSIVE" then do
          if id<>"AUDIO.SPECTRAL.REPAIR" then return .nil
        end
      end
    end
  end
  attrs=context~attributes
  source=self~flag(attrs,"SOURCE_AUDIO_AVAILABLE")
  damage=self~flag(attrs,"AUDIO_DAMAGE_MASK_AVAILABLE")
  if \source then return .MediaMethodologyApplicability~new(id,"NOT_APPLICABLE","No source audio is currently available",attrs)
  if id="AUDIO.SPECTRAL.REPAIR" then do
    if damage then return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio and an explicit damage mask are available",attrs)
    return .MediaMethodologyApplicability~new(id,"UNKNOWN","Spectral repair requires an explicit damage mask; no damaged region is assumed",attrs)
  end
  return .MediaMethodologyApplicability~new(id,"APPLICABLE","Source audio is available; provider-specific assumptions still require qualification",attrs)

::method flag
  use strict arg attrs,key
  value=attrs[translate(key)]
  if value=.nil then value=attrs[key]
  if value=.nil then return .false
  if value==.true then return .true
  text=translate(strip(value~string))
  return text="TRUE" | text="YES" | text="1" | text="AVAILABLE"

::class MediaReferenceAudioProviderResultAdapter public
::method candidate
  use strict arg providerResult, experimentId, lineageId, workId=""
  if providerResult=.nil then raise syntax 93.900 array("Provider result is required")
  if translate(strip(providerResult["status"]))<>"CANDIDATE" then return .nil
  metadata=.Directory~new
  metadata["PROVIDER_ID"]=providerResult["provider_id"]
  metadata["AUTHORITY_EFFECT"]="RECONSTRUCT_CANDIDATE"
  metadata["OBSERVATION_PROMOTION"]="FALSE"
  metadata["SOURCE_AUTHORITY_UNCHANGED"]="TRUE"
  if providerResult["implementation_foundations"]<>.nil then metadata["IMPLEMENTATION_FOUNDATIONS"]=providerResult["implementation_foundations"]
  if providerResult["candidate_kind"]<>.nil then metadata["PROVIDER_CANDIDATE_KIND"]=providerResult["candidate_kind"]
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
::requires "MediaMethodologyIntentions.cls"
