numeric digits 30
parse arg inPath maskPath outPath
if outPath='' then do; say 'FAIL args'; exit 2; end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
p=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
p~renderMask(inPath,maskPath,outPath,8000,256,64)
if stream(inPath,'C','QUERY SIZE')<>stream(outPath,'C','QUERY SIZE') then do; say 'FAIL geometry'; exit 1; end
say 'PASS tf mask native geometry='||stream(outPath,'C','QUERY SIZE')
exit 0
::requires 'AudioV9SpatialNativeProvider.cls'
