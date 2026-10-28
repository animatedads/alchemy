#!/usr/bin/env rexx
catalogue=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)
registry=.MediaAudioV9ProviderRegistry~new('providers')
attrs=.Directory~new
attrs['SOURCE_AUDIO_AVAILABLE']=.true
attrs['EVENT_ONSET_AVAILABLE']=.true
context=.MediaMethodologyIntentionContext~new('AUDIO','',.nil,.nil,registry~profiles,attrs)
provider=.MediaMethodologyIntentionProvider~new(catalogue)
provider~registerApplicabilityProvider(.MediaAudioV9ApplicabilityProvider~new)
target=.Directory~new; target['ID']='LIVE-AUDIO'
d1=provider~surface(target,context)~discover
call assertEq 'APPLICABLE',stateOf(d1,'AUDIO.MULTIPATH.PATH_ESTIMATE'),'path estimate applicable with onset'
call assertEq 'UNKNOWN',stateOf(d1,'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'),'virtual mic waits for measured path support'
attrs['MULTIPATH_PATHS_AVAILABLE']=.true
d2=provider~surface(target,context)~discover
call assertEq 'APPLICABLE',stateOf(d2,'AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'),'virtual mic becomes applicable when measured path support appears'
call assertTrue d2~target==target,'live audio identity preserved across rediscovery'
say 'PASS Audio V9 live applicability rediscovery'
exit 0
stateOf: procedure
  use arg discovery,id
  do c over discovery~candidates
    if c~methodologyId=id then return c~state
  end
  return 'MISSING'
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
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyIntentions.cls'
::requires 'MediaMethodologyExecution.cls'
::requires 'MediaAudioV9Providers.cls'
