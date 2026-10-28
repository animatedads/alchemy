#!/usr/bin/env rexx
adapter=.MediaAudioV9ProviderResultAdapter~new
m=.Directory~new
m['status']='MEASUREMENT'
m['provider_id']='reference.audio-v9/0.1'
m['implementation_id']='audio-v9.candidate18r1.multipath-features/0.1'
m['methodology_id']='AUDIO.MULTIPATH.PATH_ESTIMATE'
m['source_evidence_ref']='sha256:source'
m['output_ref']='file:paths.tsv'
m['uncertainty_ref']='file:uncertainty.json'
metrics=.Directory~new; metrics['useful_path_count']=3; m['metrics']=metrics
e=adapter~evidence(m,100,200)
call assertTrue e<>.nil,'measurement adapted'
call assertEq 'AUDIO.MULTIPATH.PATH_ESTIMATE',e~methodologyId,'measurement method id'
call assertEq 'MEASURE',e~authorityEffect,'measurement authority'
call assertEq 1,e~sourceRefs~items,'source evidence preserved'

c=.Directory~new
c['status']='CANDIDATE'
c['provider_id']='reference.audio-v9/0.1'
c['implementation_id']='audio-v9.candidate18r1.echo-reconstruct-nonamp/0.1'
c['methodology_id']='AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'
c['source_evidence_ref']='sha256:source'
c['output_ref']='file:virtual.f32'
c['support_map_ref']='file:support.tsv'
c['uncertainty_ref']='file:uncertainty.json'
c['shared_foundation_ref']='file:paths.tsv'
candidate=adapter~candidate(c,'EXP-A','LINEAGE-A','WORK-1')
call assertTrue candidate<>.nil,'candidate adapted'
call assertEq 'DERIVED_RECONSTRUCTION',candidate~candidateKind,'candidate kind'
call assertEq 'FALSE',candidate~metadata['OBSERVATION_PROMOTION'],'candidate cannot become observation'
call assertEq 'file:paths.tsv',candidate~metadata['SHARED_FOUNDATION_REF'],'shared foundation retained'
say 'PASS Audio V9 result adapters preserve authority and shared foundation'
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
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaMethodologyExperiments.cls'
::requires 'MediaAudioV9Providers.cls'
