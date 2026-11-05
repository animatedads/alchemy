/* ooRexx owns source choice, physical channel, extent, lineage and processing.
 * Native provider only decodes an exact bounded window into private float32.
 * Its source sample ordinal is NOT a verified wall-clock or video PTS.
 */
::class SpashNativeOggDecoder public
::method init
  expose native
  use strict arg bridgePath
  native=.foreign~load(bridgePath~string)
::method decode
  expose native
  use strict arg inputPath,outputPath,reportPath,startMs,durationMs,channelZeroBased,targetRate=8000
  if inputPath=='' | outputPath=='' | reportPath=='' then raise syntax 88.900 array('paths required')
  do v over .array~of(startMs,durationMs,channelZeroBased,targetRate)
    if \datatype(v,'W') | v<0 then raise syntax 88.900 array('nonnegative integral decode args required')
  end
  if durationMs<1 | durationMs>120000 then raise syntax 88.900 array('maximum 120-second bounded decode')
  if targetRate<>8000 & targetRate<>16000 & targetRate<>48000 then raise syntax 88.900 array('unsupported source resampling rate')
  if channelZeroBased>31 then raise syntax 88.900 array('physical channel out of range')
  rc=native~decode_ogg_f32(inputPath~string,outputPath~string,reportPath~string,startMs,durationMs,channelZeroBased,targetRate)
  if rc<>0 then raise syntax 88.900 array('native bounded Ogg audio decode failed',native~last_error,rc)
  return outputPath
::requires 'foreign.cls'
