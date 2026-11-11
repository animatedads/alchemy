/* Operate only on approved resident original Ogg and private output dir.
 * No shell media DSP. Requires bridge with nearby host-compiled shared object.
 * Inputs: BRIDGE LOCAL_OGG PRIVATE_DIR TRACK CHANNEL DEEP_START_MS
 * Select a deep location at least 80 percent into the observed duration.
 * This is native execution/IO-budget qualification, not a speech test.
 */
parse arg bridgePath sourcePath workDir track channel deepMs
if bridgePath='' | sourcePath='' | workDir='' | track='' | channel='' | deepMs='' then do
  say 'usage: rexx qualify_seek.rex bridge.json local_original.ogg existing_private_dir stream_index channel_zero_based deep_start_ms'
  exit 2
end
if \datatype(track,'W') | \datatype(channel,'W') | \datatype(deepMs,'W') then do
  say 'BLOCKED invalid numeric stream/channel/deep time'
  exit 3
end
p=.SpashNativeOggSeek~new(bridgePath)
manifest=p~catalogue(sourcePath,workDir||'/stream_catalogue.tsv',64)
say 'CATALOGUED logical streams; confidential metadata stays local'
originalView=p~decode(sourcePath,workDir||'/start.f32',workDir||'/start.receipt.tsv',track,channel,0,6000,8000,64)
deepView=p~decode(sourcePath,workDir||'/deep.f32',workDir||'/deep.receipt.tsv',track,channel,deepMs,6000,8000,64)
/* Parse native receipts independently; a native success response alone is not
 * enough to establish random-access or exact sample geometry. */
call validate workDir||'/start.receipt.tsv',48000,0
call validate workDir||'/deep.receipt.tsv',48000,deepMs
say 'NATIVE_SEEK_EXCERPTS_READY_FOR_INDEPENDENT_VALIDATION'
exit 0

validate: procedure
  use arg path,expectedSamples,expectedStart
  f=.stream~new(path)
  if f~open('READ')<0 then raise syntax 88.900 array('private native seek receipt unreadable',path)
  fields=.directory~new
  do while f~lines>0
    line=f~linein
    parse var line key '09'x val
    if key<>'' then fields[key]=val
  end
  f~close
  if fields~at('output_samples')==.nil | fields~at('compressed_bytes_fetched')==.nil then raise syntax 88.900 array('missing native seek fields')
  if fields['output_samples']<>expectedSamples then raise syntax 88.900 array('exact target samples not returned')
  if fields['start_ms']<>expectedStart then raise syntax 88.900 array('native audio time not preserved')
  if fields['source_io']<>'LOCAL_PREAD_ONLY' then raise syntax 88.900 array('not a resident-file source')
  if fields['compressed_bytes_fetched']>=67108864 then raise syntax 88.900 array('exceeded bounded 64MiB of source data')
  if expectedStart>0 & fields['local_seeks']<1 then raise syntax 88.900 array('deep range did not use source seeking')
  say 'QUALIFIED_WINDOW candidate_only start_ms='expectedStart 'samples='expectedSamples 'local_bytes='fields['compressed_bytes_fetched']
  return
::requires 'SpashNativeOggSeek.cls'
