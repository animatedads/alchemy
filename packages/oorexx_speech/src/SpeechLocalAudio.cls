/* SpeechLocalAudio.cls
 * Local PCM controller seams for live playback/capture.
 *
 * This package does not implement ALSA/Pulse/PipeWire.  Device-specific COTS
 * processes attach to FIFO endpoints; ooRexx owns speech/channel orchestration.
 */
::class SpeechLocalAudioBuild public
::constant VERSION '0.1-dev10'
::constant API 'speech.local.audio/0.1'

::class SpeechFifoPCMSink subclass SpeechPCMSink public
::method init
  expose fifoPath format opened bytesWritten chunksWritten
  use strict arg fifoPath, format=.nil
  if fifoPath == .nil then raise syntax 88.900 array('playback FIFO path required')
  fifoPath = fifoPath~string
  if fifoPath = '' then raise syntax 88.900 array('playback FIFO path required')
  if format == .nil then format = .SpeechAudioProfiles~azureTTS
  opened = .false; bytesWritten = 0; chunksWritten = 0
::method audioFormat
  expose format
  return format
::attribute bytesWritten get
::attribute chunksWritten get
::method putChunk
  expose fifoPath format opened bytesWritten chunksWritten
  use strict arg chunk
  if chunk == .nil then return .false
  if chunk~isEnd then return .true
  if \chunk~isData then return .false
  self~requireSameFormat(format, chunk~audioFormat)
  if \opened then do
    state = stream(fifoPath,'C','OPEN WRITE')
    if left(translate(state),5) \= 'READY' then raise syntax 88.900 array('unable to open playback FIFO: ' || fifoPath || ' status=' || state)
    opened = .true
  end
  payload = charin(chunk~ref,1,chunk~byteCount)
  call stream chunk~ref,'C','CLOSE'
  unwritten = charout(fifoPath,payload)
  if unwritten \= 0 then raise syntax 88.900 array('playback FIFO rejected PCM bytes: ' || unwritten)
  bytesWritten += length(payload); chunksWritten += 1
  return .true
::method close
  expose fifoPath opened
  if opened then call stream fifoPath,'C','CLOSE'
  opened = .false
  return .true
::method requireSameFormat
  use strict arg wanted,supplied
  if supplied == .nil then raise syntax 88.900 array('PCM chunk format required')
  if wanted~sampleRate \= supplied~sampleRate then raise syntax 88.900 array('playback sample rate mismatch')
  if wanted~channels \= supplied~channels then raise syntax 88.900 array('playback channel mismatch')
  if translate(wanted~sampleFormat) \= translate(supplied~sampleFormat) then raise syntax 88.900 array('playback sample format mismatch')
  if translate(wanted~encoding) \= translate(supplied~encoding) then raise syntax 88.900 array('playback encoding mismatch')
  return .true

::class SpeechFifoPCMSource subclass SpeechPCMSource public
::method init
  expose fifoPath format chunkDirectory prefix opened sequence ended
  use strict arg fifoPath, format=.nil, chunkDirectory='/tmp', prefix='speech-capture'
  if fifoPath == .nil then raise syntax 88.900 array('capture FIFO path required')
  fifoPath = fifoPath~string
  if fifoPath = '' then raise syntax 88.900 array('capture FIFO path required')
  if format == .nil then format = .SpeechAudioProfiles~telephonyWideband
  if chunkDirectory == .nil then chunkDirectory='/tmp'
  if chunkDirectory = '' then chunkDirectory='/tmp'
  if prefix == .nil then prefix='speech-capture'
  if prefix = '' then prefix='speech-capture'
  opened=.false; sequence=0; ended=.false
::method audioFormat
  expose format
  return format
::method nextChunk
  expose fifoPath format chunkDirectory prefix opened sequence ended
  use strict arg maximumBytes=640
  if ended then return .SpeechAudioChunk~new('END',sequence,'',0,format,'fifo-capture')
  if \datatype(maximumBytes,'W') then raise syntax 88.900 array('maximumBytes must be positive whole number')
  if maximumBytes <= 0 then raise syntax 88.900 array('maximumBytes must be positive whole number')
  if \opened then do
    state=stream(fifoPath,'C','OPEN READ')
    if left(translate(state),5) \= 'READY' then raise syntax 88.900 array('unable to open capture FIFO: ' || fifoPath || ' status=' || state)
    opened=.true
  end
  payload=charin(fifoPath,,maximumBytes)
  if payload = '' then do
    ended=.true
    return .SpeechAudioChunk~new('END',sequence,'',0,format,'fifo-capture')
  end
  sequence += 1
  ref=chunkDirectory || '/' || prefix || '-' || sequence || '.pcm'
  call stream ref,'C','OPEN WRITE REPLACE'; call charout ref,payload; call stream ref,'C','CLOSE'
  return .SpeechAudioChunk~new('DATA',sequence,ref,length(payload),format,'fifo-capture')
::method releaseChunk
  use strict arg chunk
  if chunk == .nil then return .false
  if \chunk~isData then return .false
  ref=chunk~ref
  if stream(ref,'C','QUERY EXISTS') = '' then return .true
  address system 'rm -f -- ' || self~shellQuote(ref)
  return rc = 0
::method close
  expose fifoPath opened ended
  if opened then call stream fifoPath,'C','CLOSE'
  opened=.false; ended=.true
  return .true
::method shellQuote
  use strict arg value
  return "'" || changestr("'",value,"'\''") || "'"

::class SpeechLocalAudioController public
::method playSynthesis unguarded
  use strict arg synthesisStream, sink, timeoutMs=1000
  return .SpeechAudioPump~synthesisToSink(synthesisStream,sink,timeoutMs)
::method feedRecognition unguarded
  use strict arg source, recognitionStream, maximumBytes=640
  return .SpeechAudioPump~sourceToRecognition(source,recognitionStream,maximumBytes)
::method playSynthesisAsync unguarded
  use strict arg synthesisStream, sink, timeoutMs=1000
  return self~start('PLAYSYNTHESIS',synthesisStream,sink,timeoutMs)
::method feedRecognitionAsync unguarded
  use strict arg source, recognitionStream, maximumBytes=640
  return self~start('FEEDRECOGNITION',source,recognitionStream,maximumBytes)

::requires 'SpeechCore.cls'
::requires 'SpeechAudioBridge.cls'
