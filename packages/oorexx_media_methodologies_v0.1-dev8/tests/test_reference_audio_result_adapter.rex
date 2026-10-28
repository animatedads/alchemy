#!/usr/bin/env rexx
r=.Directory~new
r['status']='CANDIDATE'
r['provider_id']='reference.audio-reconstruction/0.1'
r['implementation_id']='reference.scipy.spectral-subtraction/0.1'
r['methodology_id']='AUDIO.DENOISE.SPECTRAL_SUBTRACTION'
r['source_evidence_ref']='sha256:source'
r['output_ref']='file:candidate.wav'
r['support_map_ref']='file:support.npy'
r['uncertainty_ref']='file:uncertainty.json'
r['candidate_kind']='FULL_WAVEFORM_CANDIDATE'
r['implementation_foundations']=.array~of('STFT_HANN_V1','LOW_ENERGY_NOISE_PROFILE_V1')
a=.MediaReferenceAudioProviderResultAdapter~new~candidate(r,'EXP-A','LINEAGE-A','WORK-1')
call assertTrue a<>.nil,'candidate adapted'
call assertEq 'DERIVED_RECONSTRUCTION',a~candidateKind,'candidate authority class'
call assertEq 'FALSE',a~metadata['OBSERVATION_PROMOTION'],'no observation promotion'
call assertEq 2,a~metadata['IMPLEMENTATION_FOUNDATIONS']~items,'foundations retained'
call assertEq 1,a~provenanceRefs~items,'source ref retained'
say 'PASS plural audio result adapter preserves provenance and independence metadata'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
assertEq: procedure
  use arg expected,actual,label
  if expected==actual then return
  say 'FAIL' label 'expected='expected 'actual='actual
  exit 1
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaMethodologyExperiments.cls'
::requires 'MediaReferenceAudioProviders.cls'
