/* Static public-code contract: ooRexx may not spawn Python for media video.
 * Reads only generic tracked source; never reads a video or derived material.
 */
runner='tools/run_reference_video_provider.rex'
registry='src/MediaReferenceVideoProviders.cls'
bridge='src/MediaForeignVideoInvoker.cls'
runText=translate(charin(runner,1,chars(runner)))
regText=translate(charin(registry,1,chars(registry)))
bridgeText=translate(charin(bridge,1,chars(bridge)))
call check pos('ADDRESS SYSTEM',runText)=0,'no ADDRESS SYSTEM in ooRexx video runner'
call check pos('PYTHON3 ',runText)=0,'no Python3 shell launcher in ooRexx video runner'
call check pos('PYTHON3 ',regText)=0,'no Python3 command in video provider registry'
call check pos('OOREXX_FOREIGN_PYTHON',regText)>0,'profiles declare Foreign Runtime'
call check pos('.FOREIGNPYTHON~IMPORT',bridgeText)>0,'bridge uses resident ForeignPython import'
call check pos('ADDRESS SYSTEM',bridgeText)=0,'bridge has no shell escape'
say 'PASS video no-subprocess source audit 6/6'
exit 0

::routine check
  use strict arg condition, label
  if \condition then raise syntax 93.900 array('FAIL',label)
