#!/usr/bin/env rexx
adapter=.MediaSpectralIntegrityProviderResultAdapter~new
m=.Directory~new
m['status']='MEASUREMENT'; m['provider_id']='p'; m['implementation_id']='i'; m['methodology_id']='AUDIO.SPECTRAL_INTEGRITY.PHASE_SWEEP'; m['source_evidence_ref']='sha256:source'; m['output_ref']='file:phase.json'; m['uncertainty_ref']=''; m['metrics']=.Directory~new
e=adapter~evidence(m)
call assertTrue e<>.nil,'measurement adapted'
call assertEq 'MEASURE',e~authorityEffect,'measurement authority'
call assertEq 'FALSE',e~metadata['OBSERVATION_PROMOTION'],'measurement cannot promote'
call assertEq 'FALSE',e~metadata['SOURCE_SEPARATION_CLAIM'],'no source separation claim'

c=.Directory~new
c['status']='CANDIDATE'; c['provider_id']='p'; c['implementation_id']='i2'; c['methodology_id']='AUDIO.SPECTRAL_INTEGRITY.BOUNDED_PREFERENCE_VIEW'; c['source_evidence_ref']='sha256:source'; c['output_ref']='file:view.wav'; c['support_map_ref']='file:support.npy'; c['uncertainty_ref']='file:unc.json'
candidate=adapter~candidate(c,'EXP-SI','LINEAGE-PREF','WORK-1')
call assertTrue candidate<>.nil,'candidate adapted'
call assertEq 'DERIVED_LISTENING_VIEW',candidate~candidateKind,'listening-view candidate kind'
call assertEq 'FALSE',candidate~metadata['OBSERVATION_PROMOTION'],'candidate cannot promote'
call assertEq 'FALSE',candidate~metadata['ADDS_INFORMATION'],'candidate does not add information'
say 'PASS spectral-integrity result adapter preserves authority boundary'
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
::requires 'MediaMethodologyIntentions.cls'
::requires 'MediaSpectralIntegrityProviders.cls'
