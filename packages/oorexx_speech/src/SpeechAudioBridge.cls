/* SpeechAudioBridge.cls
 * Provider-neutral local PCM and authoritative-audio execution adapters.
 *
 * Speech owns speech semantics.  This file deliberately does not ::requires
 * Layered Audio, RTP, SIP, or a local audio implementation.  Adapters consume
 * narrow public protocols (localPath/identityKey, PCM source/sink methods).
 */

::class SpeechAudioBridgeBuild public
::constant VERSION '0.1-dev8'
::constant API 'speech.audio.bridge/0.1'

::class SpeechPCMSource public
::method audioFormat
  raise syntax 93.914 array('SpeechPCMSource.audioFormat must be implemented')
::method nextChunk
  use arg maximumBytes
  raise syntax 93.914 array('SpeechPCMSource.nextChunk must be implemented')
::method close
  return .true

::class SpeechPCMSink public
::method audioFormat
  raise syntax 93.914 array('SpeechPCMSink.audioFormat must be implemented')
::method putChunk
  use arg chunk
  raise syntax 93.914 array('SpeechPCMSink.putChunk must be implemented')
::method close
  return .true

::class SpeechPCMFileSource subclass SpeechPCMSource public
::method init
  expose sourcePath format chunkDirectory prefix sequence eof opened offset fileSize
  use strict arg sourcePath, format=.nil, chunkDirectory='', prefix='speech-pcm-source'
  if sourcePath == .nil then raise syntax 88.900 array('PCM source path required')
  sourcePath = sourcePath~string
  if sourcePath = '' then raise syntax 88.900 array('PCM source path required')
  if format == .nil then format = .SpeechAudioProfiles~telephonyNarrowband
  if chunkDirectory == .nil then chunkDirectory = ''
  if chunkDirectory = '' then chunkDirectory = '/tmp'
  if prefix == .nil then prefix = 'speech-pcm-source'
  sequence = 0; eof = .false; opened = .false; offset = 0
  fileSize = stream(sourcePath,'C','QUERY SIZE')
  if fileSize = '' then raise syntax 88.900 array('PCM source file does not exist: ' || sourcePath)
::method audioFormat
  expose format
  return format
::method sourcePath
  expose sourcePath
  return sourcePath
::method nextChunk
  expose sourcePath format chunkDirectory prefix sequence eof opened offset fileSize
  use strict arg maximumBytes=320
  if eof then return .SpeechAudioChunk~new('END', sequence, '', 0, format, 'pcm-file-source')
  if \datatype(maximumBytes,'W') then raise syntax 88.900 array('maximumBytes must be whole number')
  if maximumBytes <= 0 then raise syntax 88.900 array('maximumBytes must be positive')
  if offset >= fileSize then do
    eof = .true
    return .SpeechAudioChunk~new('END', sequence, '', 0, format, 'pcm-file-source')
  end
  wanted = maximumBytes
  remaining = fileSize - offset
  if remaining < wanted then wanted = remaining
  bytes = charin(sourcePath,offset + 1,wanted)
  if bytes = '' then do
    eof = .true
    return .SpeechAudioChunk~new('END', sequence, '', 0, format, 'pcm-file-source')
  end
  offset += length(bytes); sequence += 1
  ref = chunkDirectory || '/' || prefix || '-' || sequence || '.pcm'
  call stream ref,'C','OPEN WRITE REPLACE'
  call charout ref,bytes
  call stream ref,'C','CLOSE'
  return .SpeechAudioChunk~new('DATA', sequence, ref, length(bytes), format, 'pcm-file-source')
::method releaseChunk
  use strict arg chunk
  if chunk == .nil then return .false
  if \chunk~isData then return .false
  ref = chunk~ref
  if ref = '' then return .false
  return self~removeFile(ref)
::method close
  expose sourcePath opened eof
  if opened then call stream sourcePath,'C','CLOSE'
  opened = .false; eof = .true
  return .true
::method removeFile
  use strict arg path
  signal on syntax name removeFailed
  if stream(path,'C','QUERY EXISTS') = '' then return .true
  address system 'rm -f -- ' || self~shellQuote(path)
  return rc = 0
removeFailed:
  say 'Speech PCM cleanup failure' rc sigl condition('C') condition('D')
  return .false
::method shellQuote
  use strict arg value
  return "'" || changestr("'", value, "'\''") || "'"

::class SpeechPCMFileSink subclass SpeechPCMSink public
::method init
  expose outputPath format bytesWritten chunksWritten opened
  use strict arg outputPath, format=.nil
  if outputPath == .nil then raise syntax 88.900 array('PCM sink path required')
  outputPath = outputPath~string
  if outputPath = '' then raise syntax 88.900 array('PCM sink path required')
  if format == .nil then format = .SpeechAudioProfiles~azureTTS
  bytesWritten = 0; chunksWritten = 0; opened = .false
::method audioFormat
  expose format
  return format
::method outputPath
  expose outputPath
  return outputPath
::method bytesWritten
  expose bytesWritten
  return bytesWritten
::method chunksWritten
  expose chunksWritten
  return chunksWritten
::method putChunk
  expose outputPath format bytesWritten chunksWritten opened
  use strict arg chunk
  if chunk == .nil then return .false
  if chunk~isEnd then return .true
  if \chunk~isData then return .false
  supplied = chunk~audioFormat
  self~requireSameFormat(format,supplied)
  ref = chunk~ref
  if stream(ref,'C','QUERY EXISTS') = '' then raise syntax 88.900 array('PCM chunk artifact missing: ' || ref)
  if \opened then do
    status = stream(outputPath,'C','OPEN WRITE REPLACE')
    if status \= 'READY:' then raise syntax 88.900 array('unable to open PCM sink: ' || outputPath || ' status=' || status)
    opened = .true
  end
  call stream ref,'C','OPEN READ'
  bytes = charin(ref,,chunk~byteCount)
  call stream ref,'C','CLOSE'
  call charout outputPath,bytes
  bytesWritten += length(bytes); chunksWritten += 1
  return .true
::method close
  expose outputPath opened
  if opened then call stream outputPath,'C','CLOSE'
  opened = .false
  return .true
::method requireSameFormat
  use strict arg wanted,supplied
  if supplied == .nil then raise syntax 88.900 array('PCM chunk format required')
  if wanted~sampleRate \= supplied~sampleRate then raise syntax 88.900 array('PCM sink sample rate mismatch')
  if wanted~channels \= supplied~channels then raise syntax 88.900 array('PCM sink channel mismatch')
  if translate(wanted~sampleFormat) \= translate(supplied~sampleFormat) then raise syntax 88.900 array('PCM sink sample format mismatch')
  if translate(wanted~encoding) \= translate(supplied~encoding) then raise syntax 88.900 array('PCM sink encoding mismatch')
  return .true

::class SpeechAuthoritativeAudioInput public
::method init
  expose execution format mediaType authorityObject
  use strict arg execution, format=.nil, mediaType='audio/*', authorityObject=.nil
  if execution == .nil then raise syntax 88.900 array('audio execution binding required')
  if \execution~hasMethod('LOCALPATH') then raise syntax 88.900 array('audio execution binding must expose localPath')
  if format == .nil then format = .SpeechAudioProfiles~telephonyWideband
  if mediaType == .nil then mediaType = 'audio/*'
::method artifact
  expose execution format mediaType authorityObject
  metadata = .Directory~new
  if execution~hasMethod('IDENTITYKEY') then metadata['storage_identity'] = execution~identityKey
  if authorityObject \= .nil then metadata['authority_object'] = authorityObject
  return .SpeechAudioArtifact~new(execution~localPath, mediaType, format, 'authoritative-audio', metadata)
::method pcmSource
  expose execution format
  use strict arg chunkDirectory='', prefix='speech-authoritative-pcm'
  return .SpeechPCMFileSource~new(execution~localPath, format, chunkDirectory, prefix)
::method release
  expose execution
  if execution~hasMethod('RELEASE') then return execution~release
  return .false

::class SpeechAuthoritativeAudioOutput public
::method init
  expose outputBinding format sink
  use strict arg outputBinding, format=.nil
  if outputBinding == .nil then raise syntax 88.900 array('audio output binding required')
  if \outputBinding~hasMethod('LOCALPATH') then raise syntax 88.900 array('audio output binding must expose localPath')
  if format == .nil then format = .SpeechAudioProfiles~azureTTS
  if outputBinding~hasMethod('MARKWRITING') then outputBinding~markWriting
  sink = .SpeechPCMFileSink~new(outputBinding~localPath, format)
::method sink
  expose sink
  return sink
::method close
  expose sink
  return sink~close
::method outputBinding
  expose outputBinding
  return outputBinding

::class SpeechAudioPump public
::method sourceToRecognition class unguarded
  use strict arg source, recognitionStream, maximumBytes=320
  if source == .nil then raise syntax 88.900 array('PCM source required')
  if recognitionStream == .nil then raise syntax 88.900 array('recognition stream required')
  count = 0
  do forever
    if recognitionStream~hasMethod('STATE') then do
      if recognitionStream~state = 'CANCELLED' then leave
      if recognitionStream~state = 'ENDED' then leave
    end
    chunk = source~nextChunk(maximumBytes)
    if chunk~isEnd then leave
    accepted = recognitionStream~pushChunk(chunk)
    if \accepted then do
      if source~hasMethod('RELEASECHUNK') then source~releaseChunk(chunk)
      if recognitionStream~hasMethod('STATE') then do
        if recognitionStream~state = 'CANCELLED' then leave
        if recognitionStream~state = 'ENDED' then leave
      end
      raise syntax 88.900 array('recognition stream rejected PCM chunk')
    end
    count += 1
    if source~hasMethod('RELEASECHUNK') then source~releaseChunk(chunk)
  end
  source~close
  if recognitionStream~hasMethod('STATE') then do
    if recognitionStream~state = 'OPEN' then recognitionStream~endInput
  end
  else recognitionStream~endInput
  return count
::method synthesisToSink class unguarded
  use strict arg synthesisStream, sink, timeoutMs=1000
  if synthesisStream == .nil then raise syntax 88.900 array('synthesis stream required')
  if sink == .nil then raise syntax 88.900 array('PCM sink required')
  count = 0
  do forever
    if synthesisStream~hasMethod('STATE') then do
      if synthesisStream~state = 'CANCELLED' then leave
      if synthesisStream~state = 'ENDED' then leave
    end
    chunk = synthesisStream~nextChunk(timeoutMs)
    if chunk == .nil then iterate
    if chunk~isEnd then leave
    sink~putChunk(chunk)
    synthesisStream~releaseChunk(chunk)
    count += 1
  end
  sink~close
  return count

::requires 'SpeechCore.cls'
