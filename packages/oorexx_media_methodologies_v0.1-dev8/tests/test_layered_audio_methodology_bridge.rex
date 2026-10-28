#!/usr/bin/env rexx
catalogue=.MediaMethodologyCatalogue~new
.MediaMethodologyBuiltins~populate(catalogue)
provider=.MediaMethodologyIntentionProvider~new(catalogue)
audioObject=.Directory~new; audioObject['ID']='LIVE-AUDIO-OBJECT'
context=.MediaMethodologyIntentionContext~new('AUDIO')
bridge=.MediaLayeredAudioMethodologyBridge~new
surface=bridge~surface(audioObject,provider,context)
call assertTrue surface~target==audioObject,'exact live Audio object identity preserved'
discovery=surface~discover
call assertTrue discovery~target==audioObject,'discovery retains live Audio target'
call assertTrue discovery~candidates~items>60,'audio methodologies visible through live surface'
say 'PASS Layered Audio methodology bridge preserves exact live object identity'
exit 0
assertTrue: procedure
  use arg value,label
  if value then return
  say 'FAIL' label
  exit 1
::requires 'MediaMethodologies.cls'
::requires 'MediaMethodologyBuiltins.cls'
::requires 'MediaMethodologyIntentions.cls'
::requires 'MediaLayeredAudioMethodologyBridge.cls'
