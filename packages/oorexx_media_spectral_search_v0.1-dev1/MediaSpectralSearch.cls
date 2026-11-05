/* ooRexx owns source/track/window navigation and spectral gain rules.
 * SPASH Ogg is a replaceable bounded decoder; native FFT provides arithmetic.
 */
::options digits 30

::class MediaOggFile public
::attribute sourcePath get
::attribute sourceId get
::attribute decoder get
::attribute tracks get
::attribute cataloguePath get
::method init
  expose sourcePath sourceId decoder tracks cataloguePath
  use strict arg localPath,immutableSha256,seekBridge,privateCatalogue
  if localPath='' | immutableSha256='' | privateCatalogue='' then raise syntax 88.900 array('media source identity and private catalogue required')
  sourcePath=localPath~string
  sourceId=immutableSha256~string
  decoder=.SpashNativeOggSeek~new(seekBridge)
  cataloguePath=decoder~catalogue(sourcePath,privateCatalogue,64)
  tracks=.array~new
  f=.stream~new(cataloguePath)
  if f~open('READ')<0 then raise syntax 88.900 array('Ogg catalogue unavailable')
  do while f~lines>0
    line=f~linein
    if line='' | line~left(6)='schema' | line~left(12)='stream_index' then iterate
    if line~left(17)='local_bytes_total' then leave
    parse var line streamIndex '09'x codec '09'x channels '09'x rate '09'x startPts '09'x durationPts '09'x tbNum '09'x tbDen '09'x bitrate
    if \datatype(streamIndex,'W') then raise syntax 88.900 array('invalid logical stream catalogue')
    tracks~append(.MediaOggTrack~new(self,streamIndex,codec,channels,rate,startPts,durationPts,tbNum,tbDen,bitrate))
  end
  f~close
  if tracks~items=0 then raise syntax 88.900 array('Ogg has no supported audio tracks')
::method audioTrack
  expose tracks
  use strict arg ordinal=1
  if \datatype(ordinal,'W') | ordinal<1 | ordinal>tracks~items then raise syntax 88.900 array('audio track ordinal unavailable')
  return tracks[ordinal]
::method trackCount
  expose tracks
  return tracks~items
::method seek
  use strict arg startMs,endMs,trackOrdinal=1,channelIndex=0
  if \datatype(startMs,'W') | \datatype(endMs,'W') | endMs<=startMs then raise syntax 88.900 array('invalid media window')
  return self~audioTrack(trackOrdinal)~cursor(channelIndex)~seekTime(startMs)~window(endMs-startMs)

::class MediaOggTrack public
::attribute owner get
::attribute streamIndex get
::attribute codec get
::attribute channels get
::attribute sampleRate get
::attribute startPts get
::attribute durationPts get
::attribute timebaseNumerator get
::attribute timebaseDenominator get
::attribute declaredBitrate get
::method init
  expose owner streamIndex codec channels sampleRate startPts durationPts timebaseNumerator timebaseDenominator declaredBitrate
  use strict arg parent,index,encoding,channelCount,rate,start,duration,num,den,bitrate
  owner=parent;streamIndex=index+0;codec=encoding
  channels=channelCount+0;sampleRate=rate+0;startPts=start+0;durationPts=duration+0
  timebaseNumerator=num+0;timebaseDenominator=den+0;declaredBitrate=bitrate+0
  if channels<1 | sampleRate<1 | timebaseNumerator<1 | timebaseDenominator<1 then raise syntax 88.900 array('invalid Ogg track clock')
::method durationMs
  expose durationPts timebaseNumerator timebaseDenominator
  return durationPts*1000*timebaseNumerator%timebaseDenominator
::method cursor
  expose channels
  use strict arg channelIndex=0
  if \datatype(channelIndex,'W') | channelIndex<0 | channelIndex>=channels then raise syntax 88.900 array('physical channel unavailable')
  return .MediaCursor~new(self,channelIndex)

::class MediaCursor public
::attribute track get
::attribute channelIndex get
::attribute positionMs get
::method init
  expose track channelIndex positionMs
  use strict arg audioTrack,channel
  track=audioTrack;channelIndex=channel;positionMs=0
::method seekTime
  expose track positionMs
  use strict arg timeMs,mode='EXACT'
  if mode<>'EXACT' | \datatype(timeMs,'W') | timeMs<0 | timeMs>=track~durationMs then raise syntax 88.900 array('unsupported or out-of-range media seek')
  positionMs=timeMs
  return self
::method window
  expose track channelIndex positionMs
  use strict arg durationMs
  if \datatype(durationMs,'W') | durationMs<1 | durationMs>120000 | positionMs+durationMs>track~durationMs then raise syntax 88.900 array('bounded media window required')
  requested=.MediaWindow~new(track,channelIndex,positionMs,durationMs)
  positionMs+=durationMs
  return requested

::class MediaWindow public
::attribute track get
::attribute channelIndex get
::attribute startMs get
::attribute durationMs get
::method init
  expose track channelIndex startMs durationMs
  use strict arg t,c,start,duration
  track=t;channelIndex=c;startMs=start;durationMs=duration
::method endMs
  expose startMs durationMs
  return startMs+durationMs

::class MediaSpectrumRule public
::attribute lowHz get
::attribute highHz get
::attribute gainDb get
::method init
  expose lowHz highHz gainDb
  use strict arg low,high,gain
  if \datatype(low,'N') | \datatype(high,'N') | \datatype(gain,'N') | low<0 | high<=low | gain< -120 | gain>120 then raise syntax 88.900 array('invalid spectral band/gain')
  lowHz=low+0;highHz=high+0;gainDb=gain+0
::method covers
  expose lowHz highHz
  use strict arg frequency
  return frequency>=lowHz & frequency<=highHz

::class MediaSpectrumMap public
::attribute path get
::attribute coveragePath get
::attribute sourceId get
::attribute startMs get
::attribute endMs get
::attribute binCount get
::attribute windowCount get
::method init
  expose path coveragePath sourceId startMs endMs binCount windowCount
  use strict arg mapPath,coverage,identity,start,finish,bins,windows
  path=mapPath;coveragePath=coverage;sourceId=identity;startMs=start;endMs=finish;binCount=bins;windowCount=windows
::method window
  expose path windowCount
  use strict arg index
  if \datatype(index,'W') | index<0 | index>=windowCount then raise syntax 88.900 array('spectrum window unavailable')
  rows=.array~new
  f=.stream~new(path)
  f~open('READ')
  do while f~lines>0
    line=f~linein
    parse var line w '09'x rest
    if w==index then rows~append(line)
  end
  f~close
  return rows

::class MediaDenseSpectrumMap public
::attribute path get
::attribute receiptPath get
::attribute manifestPath get
::attribute sourceId get
::attribute startMs get
::attribute endMs get
::attribute binCount get
::attribute frameCount get
::attribute windowCount get
::method init
  expose path receiptPath manifestPath sourceId startMs endMs binCount frameCount rate sourceRate fftSize hop rules native
  use strict arg mapPath,receipt,manifest,identity,start,finish,fftRate,originalRate,size,step,frames,configuredRules,bridge
  path=mapPath;receiptPath=receipt;manifestPath=manifest;sourceId=identity
  startMs=start;endMs=finish;rate=fftRate;sourceRate=originalRate;fftSize=size;hop=step
  frameCount=frames;windowCount=frames;binCount=size%2+1;rules=configuredRules~copy
  native=.foreign~load(bridge)
::method frequencyHz
  expose rate fftSize binCount
  use strict arg bin
  if \datatype(bin,'W') | bin<0 | bin>=binCount then raise syntax 88.900 array('frequency bucket unavailable')
  return bin*rate/fftSize
::method frameCenterMs
  expose startMs rate fftSize hop frameCount
  use strict arg frame
  if \datatype(frame,'W') | frame<0 | frame>=frameCount then raise syntax 88.900 array('time bucket unavailable')
  return startMs+((frame*hop+fftSize%2)*1000/rate)
::method sourceStatus
  expose sourceRate
  use strict arg bin
  if self~frequencyHz(bin)>sourceRate/2 then return 'OUT_OF_SOURCE_BAND'
  return 'OBSERVED'
::method rawDb
  expose path binCount frameCount native
  use strict arg frame,bin
  if \datatype(frame,'W') | frame<0 | frame>=frameCount then raise syntax 88.900 array('time bucket unavailable')
  if self~sourceStatus(bin)<>'OBSERVED' then return .nil
  return native~bucket_db(path,frame,bin,binCount)
::method gainDb
  expose rules
  use strict arg bin
  hz=self~frequencyHz(bin)
  gain=0
  do rule over rules
    if rule~covers(hz) then gain=rule~gainDb
  end
  return gain
::method weightedDb
  use strict arg frame,bin
  raw=self~rawDb(frame,bin)
  if raw==.nil then return .nil
  return raw+self~gainDb(bin)
::method bandProfile
  expose path rate fftSize sourceRate native
  use strict arg outputPath
  rc=native~band_profile_f32(path,outputPath,rate,fftSize,sourceRate)
  if rc<>0 then raise syntax 88.900 array('native band profile failed',native~last_error,rc)
  return outputPath

::class MediaSearch public
::attribute outputDir get
::method init
  expose bridge outputDir fftSize hopSamples windowMs rules native
  use strict arg spectrumBridge,privateDir,fft=4096,hop=2048,interval=1000
  bridge=spectrumBridge;outputDir=privateDir;fftSize=fft;hopSamples=hop;windowMs=interval
  rules=.array~new
  native=.foreign~load(bridge)
::method setSpectrum
  expose rules
  use strict arg lowHz,highHz,gainDb
  rules~append(.MediaSpectrumRule~new(lowHz,highHz,gainDb))
  return self
::method process
  expose outputDir fftSize hopSamples rules native bridge
  use strict arg requested
  track=requested~track
  source=track~owner
  if requested~durationMs>120000 | requested~durationMs<1 then raise syntax 88.900 array('bounded media window required')
  rate=48000
  if track~sampleRate<=16000 then rate=16000
  if track~sampleRate<=8000 then rate=8000
  pcm=outputDir||'/decoded.f32'; receipt=outputDir||'/decode_receipt.tsv'
  dense=outputDir||'/dense_spectrum.f32'; denseReceipt=outputDir||'/dense_receipt.tsv'
  manifest=outputDir||'/dense_manifest.tsv'
  source~decoder~decode(source~sourcePath,pcm,receipt,track~streamIndex,requested~channelIndex,requested~startMs,requested~durationMs,rate,64)
  rc=native~dense_f32(pcm,dense,denseReceipt,rate,fftSize,hopSamples)
  if rc<>0 then raise syntax 88.900 array('native dense FFT map failed',native~last_error,rc)
  samples=requested~durationMs*rate%1000
  frames=(samples-fftSize)%hopSamples+1
  f=.stream~new(manifest)
  if f~open('WRITE')<0 then raise syntax 88.900 array('dense manifest unavailable')
  tab='09'x
  f~lineout('schema'||tab||'media.spectrum.material/1')
  f~lineout('source_sha256'||tab||source~sourceId)
  f~lineout('stream_index'||tab||track~streamIndex)
  f~lineout('channel_index'||tab||requested~channelIndex)
  f~lineout('source_rate_hz'||tab||track~sampleRate)
  f~lineout('fft_rate_hz'||tab||rate)
  f~lineout('start_ms'||tab||requested~startMs)
  f~lineout('end_ms'||tab||requested~endMs)
  f~lineout('clock_authority'||tab||'AUDIO_STREAM_PTS_ONLY')
  f~lineout('frame_count'||tab||frames)
  f~lineout('bins_per_frame'||tab||(fftSize%2+1))
  f~lineout('source_nyquist_hz'||tab||(track~sampleRate/2))
  do rule over rules
    f~lineout('spectrum_gain'||tab||rule~lowHz||tab||rule~highHz||tab||rule~gainDb)
  end
  f~close
  return .MediaDenseSpectrumMap~new(dense,denseReceipt,manifest,source~sourceId,requested~startMs,requested~endMs,rate,track~sampleRate,fftSize,hopSamples,frames,rules,bridge)
::method processCoarse
  expose outputDir fftSize hopSamples windowMs rules native
  use strict arg requested
  track=requested~track
  source=track~owner
  if requested~durationMs>120000 | requested~durationMs//windowMs<>0 then raise syntax 88.900 array('window must comprise exact spectrum intervals, <=120 seconds')
  rate=48000
  if track~sampleRate<=16000 then rate=16000
  if track~sampleRate<=8000 then rate=8000
  pcm=outputDir||'/decoded.f32'; receipt=outputDir||'/decode_receipt.tsv'
  raw=outputDir||'/raw_spectrum.tsv'
  source~decoder~decode(source~sourcePath,pcm,receipt,track~streamIndex,requested~channelIndex,requested~startMs,requested~durationMs,rate,64)
  rc=native~map_f32(pcm,raw,rate,fftSize,hopSamples,windowMs)
  if rc<>0 then raise syntax 88.900 array('native FFT map failed',native~last_error,rc)
  return self~weightRaw(raw,source~sourceId,track~streamIndex,requested~channelIndex,requested~startMs,requested~endMs,track~sampleRate,rate)
::method weightRaw
  expose outputDir fftSize windowMs rules
  use strict arg raw,sourceId,streamIndex,channelIndex,startMs,endMs,sourceRate,fftRate
  mapped=outputDir||'/spectrum_map.tsv'; coverage=outputDir||'/band_coverage.tsv'
  fin=.stream~new(raw);fout=.stream~new(mapped);fcov=.stream~new(coverage)
  if fin~open('READ')<0 | fout~open('WRITE')<0 | fcov~open('WRITE')<0 then raise syntax 88.900 array('private spectrum files unavailable')
  fout~lineout('schema'||'09'x||'media.spectrum.weighted-map/1')
  fout~lineout('source_sha256'||'09'x||sourceId)
  fout~lineout('stream_index'||'09'x||streamIndex)
  fout~lineout('channel_index'||'09'x||channelIndex)
  fout~lineout('clock_authority'||'09'x||'AUDIO_STREAM_PTS_ONLY')
  fout~lineout('start_ms'||'09'x||startMs)
  fout~lineout('end_ms'||'09'x||endMs)
  fout~lineout('sample_rate_hz'||'09'x||sourceRate)
  fout~lineout('fft_rate_hz'||'09'x||fftRate)
  fout~lineout('fft_size'||'09'x||fftSize)
  fout~lineout('window_ms'||'09'x||windowMs)
  tab='09'x
  fout~lineout('window_index'||tab||'absolute_start_ms'||tab||'bin_index'||tab||'frequency_hz'||tab||'raw_dbfs'||tab||'gain_db'||tab||'weighted_dbfs'||tab||'source_status')
  nyquist=sourceRate/2
  do while fin~lines>0
    line=fin~linein
    parse var line w '09'x localStart '09'x bin '09'x hz '09'x db
    if \datatype(w,'W') | \datatype(bin,'W') then iterate
    applied=0
    do rule over rules
      if rule~covers(hz+0) then applied=rule~gainDb
    end
    absolute=startMs+localStart
    if hz+0>nyquist then
      fout~lineout(w||tab||absolute||tab||bin||tab||hz||tab||'NA'||tab||applied||tab||'NA'||tab||'OUT_OF_SOURCE_BAND')
    else
      fout~lineout(w||tab||absolute||tab||bin||tab||hz||tab||db||tab||applied||tab||(db+0+applied)||tab||'OBSERVED')
  end
  fin~close;fout~close
  fcov~lineout('low_hz'||'09'x||'high_hz'||'09'x||'gain_db'||'09'x||'observed_to_hz'||'09'x||'status')
  do rule over rules
    status='OBSERVED'
    if rule~lowHz>=nyquist then status='OUT_OF_SOURCE_BAND'
    else if rule~highHz>nyquist then status='PARTIAL_SOURCE_BAND'
    observed=rule~highHz
    if observed>nyquist then observed=nyquist
    fcov~lineout(rule~lowHz||'09'x||rule~highHz||'09'x||rule~gainDb||'09'x||observed||'09'x||status)
  end
  fcov~close
  return .MediaSpectrumMap~new(mapped,coverage,sourceId,startMs,endMs,fftSize%2+1,(endMs-startMs)%windowMs)

::requires 'SpashNativeOggSeek.cls'
::requires 'foreign.cls'
