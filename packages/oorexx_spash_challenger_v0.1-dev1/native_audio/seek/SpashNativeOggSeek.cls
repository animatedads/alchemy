/* Native indexed Ogg seek provider under ooRexx authority.
 * One original source remains resident at the execution MU; no source PCM
 * crosses Storage Fabric. Catalogue/extent outputs stay private on that MU.
 * Use explicit logical stream index AND physical channel index.
 */
::class SpashNativeOggSeek public
::method init
  expose native
  use strict arg bridgePath
  if bridgePath=='' then raise syntax 88.900 array('Foreign Runtime bridge required')
  native=.foreign~load(bridgePath~string)

::method catalogue
  expose native
  use strict arg localOgg,privateManifest,maxReadMb=64
  self~checkBudget(maxReadMb)
  if localOgg=='' | privateManifest=='' | localOgg==privateManifest then raise syntax 88.900 array('distinct catalogue paths required')
  rc=native~catalogue(localOgg~string,privateManifest~string,maxReadMb)
  if rc<>0 then raise syntax 88.900 array('native Ogg catalogue failed',native~last_error,rc)
  return privateManifest

::method decode
  expose native
  use strict arg localOgg,privateF32,privateReceipt,streamIndex,channelIndex,startMs,durationMs,targetRate=8000,maxReadMb=64
  do v over .array~of(streamIndex,channelIndex,startMs,durationMs,targetRate)
    if \datatype(v,'W') | v<0 then raise syntax 88.900 array('nonnegative integral seek arguments required')
  end
  if streamIndex>65535 | channelIndex>31 then raise syntax 88.900 array('logical track/channel index out of range')
  if durationMs<1 | durationMs>120000 then raise syntax 88.900 array('bounded audio read is 1..120000 milliseconds')
  if targetRate<>8000 & targetRate<>16000 & targetRate<>48000 then raise syntax 88.900 array('unsupported output rate')
  self~checkBudget(maxReadMb)
  if localOgg=='' | privateF32=='' | privateReceipt=='' | localOgg==privateF32 | localOgg==privateReceipt | privateF32==privateReceipt then raise syntax 88.900 array('distinct local input/output paths required')
  /* Direct local byte seeking is verified in the private receipt. */
  rc=native~seek_decode(localOgg~string,privateF32~string,privateReceipt~string,streamIndex,channelIndex,startMs,durationMs,targetRate,maxReadMb)
  if rc<>0 then raise syntax 88.900 array('native Ogg random seek failed',native~last_error,rc)
  return privateF32

::method checkBudget private
  use strict arg budget
  if \datatype(budget,'W') | budget<1 | budget>128 then raise syntax 88.900 array('compressed read budget 1..128 MiB required')
  return .true
::requires 'foreign.cls'
